local _, Skada = ...

--[[
	NativeAPI.lua - WoW 12.0.0+ C_DamageMeter API wrapper
	
	This module provides integration with Blizzard's native damage meter API.
	WoW 12.0.0+ ONLY - no legacy combat log support.
	
	Official API Functions:
	- C_DamageMeter.GetAvailableCombatSessions()
	- C_DamageMeter.GetCombatSessionFromID(sessionID)
	- C_DamageMeter.GetCombatSessionFromType(sessionType, type)
	- C_DamageMeter.GetCombatSessionSourceFromID(sessionID)
	- C_DamageMeter.GetCombatSessionSourceFromType(sessionType, type)
	- C_DamageMeter.IsDamageMeterAvailable()
	- C_DamageMeter.ResetAllCombatSessions()
]]

local NativeAPI = {}
Skada.NativeAPI = NativeAPI

-- Cache and state for performance optimization
-- TTL must be <= the Skada Tick interval (default 0.25s) so the UI never
-- shows stale snapshots between ticks. We also explicitly invalidate on
-- DAMAGE_METER_*_UPDATED events from Skada.lua, which is the authoritative
-- signal that Blizzard's snapshot has changed.
NativeAPI.cache = {
	results = {},
	available = true, -- Is C_DamageMeter currently responsive?
	ttl = 0.1,        -- Cache TTL in seconds (100ms) - smaller than Tick interval
	lastCheck = 0     -- Last time we checked availability
}

--[[
	Invalidate all cached session/source views.
	Called from DAMAGE_METER_COMBAT_SESSION_UPDATED and
	DAMAGE_METER_CURRENT_SESSION_UPDATED so the next read returns fresh data
	instead of the previous tick's snapshot.
]]
function NativeAPI:InvalidateCache()
	if self.cache and self.cache.results then
		wipe(self.cache.results)
	end
	wipe(self.sessionFrameCache)
	self.availableFrameCache = nil
end

function NativeAPI:BeginTick()
	self.tickSerial = (self.tickSerial or 0) + 1
	wipe(self.sessionFrameCache)
	self.availableFrameCache = nil
end

-- Persistent cache for discovered session types
NativeAPI.sessionTypeCache = {
	current = nil,
	total = nil,
	currentDamageType = 0,
	totalDamageType = 0
}

-- Last known good native sessions. The API can return an empty list or nil
-- current session briefly around combat boundaries; keep the last valid data.
NativeAPI.lastSessions = nil
NativeAPI.lastCurrentSession = nil
NativeAPI.sessionByIDCache = {}
NativeAPI.knownSessions = {}
NativeAPI.lastKnownSessionID = nil
NativeAPI.lastKnownDamageType = 0
NativeAPI.tickSerial = 0
NativeAPI.sessionFrameCache = {}
NativeAPI.availableFrameCache = nil

local function sessionHasSources(set)
	if type(set) ~= "table" then return false end
	-- A secret table cannot be inspected; keep it and let the display layer
	-- decide how to represent it.
	if issecretvalue(set) then return true end
	local sources = set.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return false end
	return #sources > 0
end

function NativeAPI:ClearSessionCache()
	self.lastSessions = nil
	self.lastCurrentSession = nil
	self.lastTotalSession = nil
	self.sessionByIDCache = {}
	self.knownSessions = {}
	self.lastKnownSessionID = nil
	self.lastKnownDamageType = 0
	wipe(self.sessionFrameCache)
	self.availableFrameCache = nil
end

function NativeAPI:TrackSession(sessionID, damageType)
	if type(sessionID) ~= "number" or issecretvalue(sessionID) or sessionID == 0 then
		return
	end
	local entry = self.knownSessions[sessionID]
	if not entry then
		entry = {sessionID = sessionID, name = "Combat " .. tostring(sessionID), startedAt = time()}
		self.knownSessions[sessionID] = entry
	end
	if type(damageType) == "number" and not issecretvalue(damageType) then
		entry.damageType = damageType
	end
	self.lastKnownSessionID = sessionID
	self.lastKnownDamageType = entry.damageType or 0
end

function NativeAPI:GetKnownSessions()
	local list = {}
	for _, entry in pairs(self.knownSessions) do
		tinsert(list, entry)
	end
	table.sort(list, function(a, b) return a.sessionID > b.sessionID end)
	return list
end

-- Verify C_DamageMeter is available
if not C_DamageMeter then
	error("Skada: C_DamageMeter API not available! This version requires WoW 12.0.0+")
	return
end

-- Helper to get keys from a table for debugging
local function getKeys(t)
	local keys = {}
	if type(t) == "table" then
		for k, _ in pairs(t) do
			table.insert(keys, tostring(k))
		end
	end
	return table.concat(keys, ", ")
end

-- sanitizeNumber removed (was a no-op - returned the value unchanged)

--[[
	Get detailed session source data (spells, etc.)
]]
local DAMAGE_METER_TYPE_NAMES = {
	[0] = "DamageDone",
	[2] = "HealingDone",
	[4] = "Absorbs",
	[5] = "Interrupts",
	[6] = "Dispels",
	[7] = "DamageTaken",
	[8] = "AvoidableDamageTaken",
	[10] = "EnemyDamageTaken",
}

function NativeAPI:ResolveDamageMeterType(damageType)
	if Enum and Enum.DamageMeterType then
		local name = DAMAGE_METER_TYPE_NAMES[damageType]
		if name and Enum.DamageMeterType[name] ~= nil then
			return Enum.DamageMeterType[name]
		end
	end
	return damageType
end

function NativeAPI:GetSessionSource(sourceGUID, set, damageType, sourceCreatureID)
	if type(sourceGUID) == "nil" and type(sourceCreatureID) == "nil" then return nil end

	-- 1. Try simulation
	if Skada.Simulation and Skada.Simulation.active then
		return Skada.Simulation:GetMockSource(sourceGUID, damageType)
	end

	-- 2. Check Frame Cache with TTL
	local now = GetTime()
	local cache = self.cache

	-- Only check availability periodically, not every frame
	if now - cache.lastCheck > cache.ttl then
		cache.lastCheck = now
		local ok, available = pcall(C_DamageMeter.IsDamageMeterAvailable)
		cache.available = ok and available == true

		-- Clean up expired cache entries
		for key, entry in pairs(cache.results) do
			if entry.expires and now > entry.expires then
				cache.results[key] = nil
			end
		end
	end

	if not cache.available then return nil end

	local sessionID, sessionType
	if type(set) == "table" and not issecretvalue(set) then
		sessionID = set.sessionID
		sessionType = set.sessionType or (set == Skada.total and 0 or 1)
	else
		sessionType = 1
	end

	-- Only cache if sourceGUID is not secret (concatenating secrets makes the key secret)
	local isSecret = issecretvalue(sourceGUID) or issecretvalue(sourceCreatureID)
	local cacheKey
	if not isSecret then
		cacheKey = "source_"
			.. tostring(sessionID or sessionType) .. "_"
			.. tostring(damageType) .. "_"
			.. tostring(sourceGUID) .. "_"
			.. tostring(sourceCreatureID or "")
		local cached = cache.results[cacheKey]
		if cached and now < cached.expires then
			local value = cached.value
			if type(value) == "table" then
				return value
			end
		end
	end

	-- 3. Current and total sessions should use the type query, matching
	-- Details. Session-ID queries can fail when the source GUID is secret even
	-- though the equivalent type query succeeds. Historical sessions still
	-- prefer their ID.
	local result
	local preferType = not sessionID or not sessionType or (not issecretvalue(sessionType) and sessionType <= 1)
	local resolvedType = self:ResolveDamageMeterType(damageType)
	local tryType = function()
		local ok, value = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, resolvedType, sourceGUID, sourceCreatureID)
		if ok and type(value) == "table" then result = value end
	end
	local tryID = function()
		if not sessionID then return end
		local ok, value = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessionID, resolvedType, sourceGUID, sourceCreatureID)
		if ok and type(value) == "table" then result = value end
	end

	if preferType then
		tryType()
		if not result then tryID() end
	else
		tryID()
		if not result then tryType() end
	end

	if result then
		if not isSecret then
			cache.results[cacheKey] = {value = result, expires = now + cache.ttl}
		end
		return result
	end

	-- 4. Last resort: locate the session by type, then query its source by ID.
	if not sessionID then
		local viewKey = "view_" .. tostring(sessionType) .. "_" .. tostring(damageType)
		local cachedView = cache.results[viewKey]
		local view

		if cachedView and now < cachedView.expires then
			view = cachedView.value
		else
			local okView, resView = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, damageType)
			if okView and type(resView) == "table" then
				view = resView
				cache.results[viewKey] = {value = view, expires = now + cache.ttl}
			end
		end

		if type(view) == "table" and not issecretvalue(view) and view.sessionID then
			local okID, resID = pcall(C_DamageMeter.GetCombatSessionSourceFromID, view.sessionID, damageType, sourceGUID, sourceCreatureID)
			if okID and type(resID) == "table" then
				result = resID
			end
		end
	end

	if type(result) == "table" then
		if not isSecret then
			cache.results[cacheKey] = {value = result, expires = now + cache.ttl}
		end
		return result
	end

	return nil
end

--[[
	Update spells for a player from session source
]]

--[[
	API Methods used by modules
]]

function NativeAPI:GetSessionView(set, damageType)
	if type(set) ~= "table" then return nil end
	-- A secret session cannot be indexed; callers that have a source GUID can
	-- query that source directly by type instead.
	if issecretvalue(set) then return set end

	local sessionID = set.sessionID
	local sessionType = set.sessionType or (set == Skada.total and 0 or 1)

	-- 1. Try simulation (safety: only out of combat)
	if Skada.Simulation and Skada.Simulation.active and not InCombatLockdown() then
		return Skada.Simulation:GetMockSession(sessionType, damageType)
	end

	-- 2. Check Frame Cache with TTL
	local now = GetTime()
	local cache = self.cache

	-- Only check availability periodically
	if now - cache.lastCheck > cache.ttl then
		cache.lastCheck = now
		local ok, available = pcall(C_DamageMeter.IsDamageMeterAvailable)
		cache.available = ok and available == true

		-- Clean up expired entries
		for key, entry in pairs(cache.results) do
			if entry.expires and now > entry.expires then
				cache.results[key] = nil
			end
		end
	end

	if not cache.available then return nil end

	local cacheKey
	if sessionID then
		cacheKey = "view_id_" .. tostring(sessionID) .. "_" .. tostring(damageType)
	else
		cacheKey = "view_" .. tostring(sessionType) .. "_" .. tostring(damageType)
	end

	local cached = cache.results[cacheKey]
	if cached and now < cached.expires then
		local value = cached.value
		if type(value) == "table" then
			return value
		end
		return set
	end

	-- 3. Current and total sessions should use the type query, matching
	-- Details. Session-ID queries can resolve to the wrong mode for sessions
	-- such as EnemyDamageTaken. Historical sessions still prefer their ID.
	local resolvedDamageType = self:ResolveDamageMeterType(damageType)
	local preferType = not sessionID or not sessionType or (not issecretvalue(sessionType) and sessionType <= 1)
	local result
	local triedTypes = {}
	local tryType = function(candidate)
		if candidate == nil or triedTypes[candidate] then return end
		triedTypes[candidate] = true
		local ok, value = pcall(C_DamageMeter.GetCombatSessionFromType, candidate, resolvedDamageType)
		if ok and type(value) == "table" then result = value end
	end
	local tryID = function()
		if not sessionID then return end
		local ok, value = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, resolvedDamageType)
		if ok and type(value) == "table" then result = value end
	end
	if preferType then
		tryType(sessionType)
		if not result then tryID() end
	else
		tryID()
		if not result then tryType(sessionType) end
	end
	if not result then
		for _, candidate in ipairs({1, 0, 2}) do
			tryType(candidate)
			if result then break end
		end
	end

	if type(result) == "table" then
		pcall(function()
			if sessionID then
				result.sessionID = sessionID
			else
				result.sessionType = sessionType
			end
		end)
		cache.results[cacheKey] = {value = result, expires = now + cache.ttl}
		return result
	end

	cache.results[cacheKey] = {value = false, expires = now + cache.ttl}
	return nil
end

function NativeAPI:GetSessionDurationSeconds(sessionType)
	if type(C_DamageMeter.GetSessionDurationSeconds) == "function" then
		local ok, duration = pcall(C_DamageMeter.GetSessionDurationSeconds, sessionType)
		if ok then
			return duration
		end
	end
	return nil
end

function NativeAPI:GetPlayerRate(set, player, rateType)
	if type(player) ~= "table" then return 0 end

	local rate = player.amountPerSecond
	if issecretvalue(rate) then return rate end
	if type(rate) ~= "number" then
		rate = player.rate
	end
	if issecretvalue(rate) then return rate end
	return tonumber(rate) or 0
end

function NativeAPI:GetRaidRate(set, rateType)
	if type(set) ~= "table" then return 0 end

	local val = set.amountPerSecond
	if issecretvalue(val) then return val end
	if type(val) == "number" then
		return val
	end

	-- Fallback: sum up participants
	local totalRate = 0
	local sources = set.combatSources
	if type(sources) ~= "table" then
		sources = set.participants
	end
	if type(sources) ~= "table" or issecretvalue(sources) then return 0 end

	for _, p in pairs(sources) do
		if type(p) == "table" and not issecretvalue(p) then
			local prate = p.amountPerSecond
			if issecretvalue(prate) then
				return prate -- Any secret makes total secret
			end
			if type(prate) ~= "number" then
				prate = p.rate
			end
			if issecretvalue(prate) then
				return prate
			end
			totalRate = totalRate + (tonumber(prate) or 0)
		end
	end

	return totalRate
end

-- Separate debug helper to keep hot path clean
local function DebugLogSource(source)
	Skada:Debug("GetPlayerSpells source type:", type(source))

	-- Don't try to iterate secret values — pairs() crashes on them
	if issecretvalue and issecretvalue(source) then
		Skada:Debug("GetPlayerSpells source is SECRET — cannot inspect fields")
		return
	end

	if type(source) ~= "table" then return end

	Skada:Debug("GetPlayerSpells source keys:", getKeys(source))

	for k, v in pairs(source) do
		if type(v) == "table" then
			Skada:Debug("  "..k.." (table) keys:", getKeys(v))
			local count = 0
			for _, item in pairs(v) do
				count = count + 1
				if count <= 3 then
					Skada:Debug("    Item "..count.." type:", type(item))
					if type(item) == "table" then
						Skada:Debug("    Item "..count.." keys:", getKeys(item))
					end
				else
					break
				end
			end
		else
			Skada:Debug("  "..k..":", type(v), v)
		end
	end
end

-- Extract spell data from a source object without making an API call.
-- Returns the spells collection (table or secret value) or nil.
local function ExtractSpellsFromSource(source)
	if type(source) == "nil" then return nil end

	-- If the source itself is a secret value, we cannot index or iterate it.
	if issecretvalue(source) then
		return source
	end

	if type(source) ~= "table" then return nil end

	-- Try to find spells in various possible locations
	local spellFields = {
		"combatSpells", "combatSpellDetails", "spellDetails", "spellData",
		"spells", "abilities", "damageSpells", "healingSpells", "damageAbilities", "healingAbilities",
	}
	for _, field in ipairs(spellFields) do
		local val = source[field]
		if issecretvalue(val) then
			return val
		elseif type(val) == "table" then
			return val
		end
	end

	-- Check if source itself looks like a spells array
	local itemCount = 0
	for _, v in pairs(source) do
		itemCount = itemCount + 1

		if issecretvalue(v) then
			return source
		end
		if type(v) ~= "table" then
			return nil
		end
		local spellID = v.spellID
		local abilityID = v.abilityID
		local totalAmount = v.totalAmount
		if issecretvalue(spellID) or issecretvalue(abilityID) or issecretvalue(totalAmount) then
			return source
		end
		if spellID == nil and abilityID == nil and totalAmount == nil then
			return nil
		end
	end

	if itemCount > 0 then
		return source
	end

	-- Native source layouts have changed between builds. If a plain table
	-- contains a per-spell collection under an unexpected name, accept it when
	-- its first entry has a spell identifier.
	for _, value in pairs(source) do
		if type(value) == "table" and not issecretvalue(value) then
			local first = value[1]
			if type(first) == "table" and not issecretvalue(first)
				and (first.spellID or first.abilityID) then
				return value
			end
		end
	end

	return nil
end

function NativeAPI:GetSpellsFromSource(source)
	if type(source) ~= "table" or issecretvalue(source) then return nil end
	return ExtractSpellsFromSource(source)
end

function NativeAPI:GetPlayerSpells(playerID, set, damageType, sourceCreatureID)
	local source = self:GetSessionSource(playerID, set, damageType, sourceCreatureID)

	if type(source) == "nil" then
		if Skada.db.profile.debug then
			Skada:Debug("GetPlayerSpells: No source found for", playerID, "damageType", damageType)
		end
		return nil
	end

	if Skada.db.profile.debug then
		DebugLogSource(source)
	end

	return ExtractSpellsFromSource(source)
end

function NativeAPI:GetPlayerSpell(playerID, set, damageType, spellID)
	local spells = self:GetPlayerSpells(playerID, set, damageType)
	if type(spells) ~= "table" or issecretvalue(spells) then
		return nil
	end

	for _, spell in pairs(spells) do
		if type(spell) == "table" and not issecretvalue(spell) and spell.spellID == spellID then
			return spell
		end
	end
	return nil
end

function NativeAPI:IsAvailable()
	local ok, available = pcall(C_DamageMeter.IsDamageMeterAvailable)
	return ok and available == true
end

--[[
	Get list of available combat sessions
	Returns: DamageMeterAvailableCombatSession[]
	
	Structure (from API):
	{
		sessionID = number,
		sessionType = Enum.DamageMeterCombatSessionType,
		-- More fields TBD from actual API
	}
]]
function NativeAPI:GetAvailableSessions()
	if self.availableFrameCache and self.availableFrameCache.tick == self.tickSerial then
		return self.availableFrameCache.value
	end
	local success, result = pcall(C_DamageMeter.GetAvailableCombatSessions)
	if success and type(result) == "table" then
		if #result > 0 then
			self.lastSessions = result
			for _, available in ipairs(result) do
				local known = available.sessionID and self.knownSessions[available.sessionID]
				if known and known.startedAt and not available.startedAt then
					pcall(function() available.startedAt = known.startedAt end)
				end
			end
			self.availableFrameCache = {tick = self.tickSerial, value = result}
			return result
		end
		if self.lastSessions then
			self.availableFrameCache = {tick = self.tickSerial, value = self.lastSessions}
			return self.lastSessions
		end
	end

	-- Some clients populate the session list only through events, not this
	-- endpoint. Synthesize a list from the IDs we have seen.
	local known = self:GetKnownSessions()
	if #known > 0 then
		self.availableFrameCache = {tick = self.tickSerial, value = known}
		return known
	end
	local empty = self.lastSessions or {}
	self.availableFrameCache = {tick = self.tickSerial, value = empty}
	return empty
end

--[[
	Get combat session info by sessionID.
	The API requires a DamageMeterType, so callers pass the type they intend
	to display; DamageDone is the default for set-list lookups.
]]
function NativeAPI:GetSessionByID(sessionID, damageType)
	if type(sessionID) == "nil" then return nil end

	damageType = damageType or 0
	local cacheKey = tostring(sessionID) .. ":" .. tostring(damageType)
	local result

	-- Try the requested type first, then the remaining documented damage types.
	-- GetCombatSessionFromID requires a type and may return nil for a mismatch.
	local types = {damageType}
	for i = 0, 10 do
		if i ~= damageType then tinsert(types, i) end
	end
	for _, dtype in ipairs(types) do
		local success, candidate = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, self:ResolveDamageMeterType(dtype))
		if success and type(candidate) == "table" then
			result = candidate
			pcall(function()
				result.sessionID = sessionID
			end)
			break
		end
	end

	if result then
		-- C_DamageMeter sessions do not expose their display name; attach it.
		local sessions = self:GetAvailableSessions()
		for _, available in ipairs(sessions) do
			if available.sessionID == sessionID then
				pcall(function()
					if type(available.name) == "string" then
						result.name = available.name
					end
					if type(available.durationSeconds) ~= "nil" then
						result.durationSeconds = available.durationSeconds
					end
				end)
				break
			end
		end
		self.sessionByIDCache[cacheKey] = result
		return result
	end

	return self.sessionByIDCache[cacheKey]
end

--[[
	Get combat session info by session type
	DEPRECATED: Use GetCurrentSession() or GetTotalSession() instead
	This function is kept for backward compatibility but may not work correctly
]]
function NativeAPI:GetSessionByType(sessionType)
	if type(sessionType) == "nil" then
		return nil
	end

	local args = {}

	if type(sessionType) == "number" then
		args.sessionType = sessionType
		args.type = 0  -- Default to DamageDone
	elseif type(sessionType) == "table" then
		args = sessionType
	else
		return nil
	end

	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	if success and type(result) == "table" then
		return result
	end
	return nil
end

--[[
	Test all possible session types to find the correct one
]]
function NativeAPI:TestSessionTypes()
	-- Documented values: sessionType 0=Overall, 1=Current, 2=Expired;
	-- damage type 0=DamageDone. Do not probe other damage types here: an empty
	-- session for an unrelated type would otherwise become the cached current.
	self.sessionTypeCache.current = 1
	self.sessionTypeCache.currentDamageType = 0
	self.sessionTypeCache.total = 0
	self.sessionTypeCache.totalDamageType = 0
end


--[[
	Get current active session (shorthand)
	According to documentation: sessionType = 1 for Current
]]
--[[
	Shared session retrieval helper
	All Get*Session() methods delegate to this.
]]
function NativeAPI:GetSessionByParams(sessionType, damageType)
	local cacheKey = tostring(sessionType) .. ":" .. tostring(damageType)
	local cached = self.sessionFrameCache[cacheKey]
	if cached then
		return cached.value
	end
	-- Prioritize simulation (safety: only out of combat)
	if Skada.Simulation and Skada.Simulation.active and not InCombatLockdown() then
		return Skada.Simulation:GetMockSession(sessionType, damageType)
	end

	local resolvedDamageType = self:ResolveDamageMeterType(damageType)
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, resolvedDamageType)
	if success and type(result) == "table" then
		self.sessionFrameCache[cacheKey] = {value = result}
		return result
	end

	-- Fallback: try Enum values if they exist
	if Enum and Enum.DamageMeterSessionType then
		local enumSessionType
		if sessionType == 1 and Enum.DamageMeterSessionType.Current then
			enumSessionType = Enum.DamageMeterSessionType.Current
		elseif sessionType == 0 and Enum.DamageMeterSessionType.Overall then
			enumSessionType = Enum.DamageMeterSessionType.Overall
		end

		if enumSessionType then
			local enumDamageType = damageType
			if Enum.DamageMeterType then
				local typeMap = {
					[0] = Enum.DamageMeterType.DamageDone,
					[2] = Enum.DamageMeterType.HealingDone,
					[5] = Enum.DamageMeterType.Interrupts,
					[6] = Enum.DamageMeterType.Dispels,
					[7] = Enum.DamageMeterType.DamageTaken,
				}
				enumDamageType = typeMap[damageType] or damageType
			end

			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumSessionType, enumDamageType)
			if success and type(result) == "table" then
				self.sessionFrameCache[cacheKey] = {value = result}
				return result
			end
		end
	end

	self.sessionFrameCache[cacheKey] = {value = false}
	return nil
end

function NativeAPI:GetCurrentSession()
	local set = self:GetSessionByParams(1, 0)
	if type(set) == "table" then
		if sessionHasSources(set) then
			self.lastCurrentSession = set
		end
		return set
	end
	if self.lastCurrentSession then return self.lastCurrentSession end
	return self:GetSessionByParams(self.sessionTypeCache.current or 1, self.sessionTypeCache.currentDamageType or 0)
end

function NativeAPI:GetTotalSession()
	local set = self:GetSessionByParams(0, 0)
	if type(set) == "table" then
		if sessionHasSources(set) then
			self.lastTotalSession = set
		end
		return set
	end
	return self.lastTotalSession or self:GetSessionByParams(self.sessionTypeCache.total or 0, self.sessionTypeCache.totalDamageType or 0)
end

function NativeAPI:GetDamageTakenSession()
	return self:GetSessionByParams(1, 7)
end

function NativeAPI:GetDispelsSession()
	return self:GetSessionByParams(1, 6)
end

function NativeAPI:GetInterruptsSession()
	return self:GetSessionByParams(1, 5)
end

function NativeAPI:GetHealingDoneSession()
	return self:GetSessionByParams(1, 2)
end

--[[
	Reset all damage meter sessions
]]
function NativeAPI:ResetAllSessions()
	local success, result = pcall(C_DamageMeter.ResetAllCombatSessions)
	return success
end


--[[
	Update Skada's data structures from native API session data
	
	Expected session structure (to be verified):
	{
		sessionID = number,
		sessionType = Enum.DamageMeterCombatSessionType,
		startTime = number,
		endTime = number?,
		encounterID = number?,
		encounterName = string?,
		participants = {
			{
				guid = string,
				name = string,
				class = string,
				damage = number,
				healing = number,
				damageTaken = number,
				-- more fields TBD
			},
			...
		}
	}
]]
-- Update*FromSession functions removed - modules query Native API directly

--[[
	Diagnostic function to dump native API structure
]]
function NativeAPI:DumpAPI()
	print("=== C_DamageMeter API Dump ===")
	
	-- Check if available
	print("IsDamageMeterAvailable():", self:IsAvailable())
	
	-- List available sessions
	print("\nAvailable Sessions:")
	local sessions = self:GetAvailableSessions()
	for i, session in ipairs(sessions) do
		print("  Session", i, ":")
		for k, v in pairs(session) do
			print("    " .. tostring(k) .. ":", tostring(v))
		end
	end
	
	-- Dump current session
	print("\nCurrent Session:")
	local current = self:GetCurrentSession()
	if current then
		for k, v in pairs(current) do
			if type(v) == "table" then
				print("  " .. k .. ": (table with", #v, "entries)")
			else
				print("  " .. k .. ":", tostring(v))
			end
		end
	else
		print("  No current session")
	end
	
	print("=== End Dump ===")
end

return NativeAPI
