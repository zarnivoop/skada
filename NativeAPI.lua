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
-- Using TTL-based caching instead of per-frame wipes
NativeAPI.cache = {
	results = {},
	available = true, -- Is C_DamageMeter currently responsive?
	ttl = 0.5,        -- Cache TTL in seconds (500ms)
	lastCheck = 0     -- Last time we checked availability
}

-- Persistent cache for discovered session types
NativeAPI.sessionTypeCache = {
	current = nil,
	total = nil,
	currentDamageType = 0,
	totalDamageType = 0
}

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
function NativeAPI:GetSessionSource(sourceGUID, sessionType, damageType)
	if not sourceGUID then return nil end
	
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
		cache.available = C_DamageMeter.IsDamageMeterAvailable()
		
		-- Clean up expired cache entries
		for key, entry in pairs(cache.results) do
			if entry.expires and now > entry.expires then
				cache.results[key] = nil
			end
		end
	end
	
	if not cache.available then return nil end
	
	-- Only cache if sourceGUID is not secret (concatenating secrets makes the key secret)
	local isSecret = issecretvalue and issecretvalue(sourceGUID)
	local cacheKey
	if not isSecret then
		cacheKey = "source_" .. tostring(sessionType) .. "_" .. tostring(damageType) .. "_" .. tostring(sourceGUID)
		local cached = cache.results[cacheKey]
		if cached and now < cached.expires then
			return cached.value
		end
	end

	-- 3. Try FromType
	local success, result = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, damageType, sourceGUID)
	if success and result then 
		if not isSecret then 
			cache.results[cacheKey] = {value = result, expires = now + cache.ttl}
		end
		return result 
	end
	
	-- 4. Try FromID if sessionID is available
	local viewKey = "view_" .. tostring(sessionType) .. "_" .. tostring(damageType)
	local cachedView = cache.results[viewKey]
	local view
	
	if cachedView and now < cachedView.expires then
		view = cachedView.value
	else
		local success_view, res_view = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, damageType)
		view = success_view and res_view or false
		cache.results[viewKey] = {value = view, expires = now + cache.ttl}
	end
	
	if view and view.sessionID then
		local success_id, res_id = pcall(C_DamageMeter.GetCombatSessionSourceFromID, view.sessionID, sourceGUID)
		result = success_id and res_id or nil
	end

	if not isSecret then 
		cache.results[cacheKey] = {value = result, expires = now + cache.ttl}
	end
	return result
end

--[[
	Update spells for a player from session source
]]

--[[
	API Methods used by modules
]]

function NativeAPI:GetSessionView(set, damageType)
	if not set then return nil end
	
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
		cache.available = C_DamageMeter.IsDamageMeterAvailable()
		
		-- Clean up expired entries
		for key, entry in pairs(cache.results) do
			if entry.expires and now > entry.expires then
				cache.results[key] = nil
			end
		end
	end
	
	if not cache.available then return set end
	
	local cacheKey = "view_"..tostring(sessionType).."_"..tostring(damageType)
	local cached = cache.results[cacheKey]
	if cached and now < cached.expires then
		return cached.value or set
	end

	-- 3. Try FromType
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, damageType)
	if success and result then
		cache.results[cacheKey] = {value = result, expires = now + cache.ttl}
		return result
	end
	
	cache.results[cacheKey] = {value = false, expires = now + cache.ttl}
	return set
end

function NativeAPI:GetPlayerRate(set, player, rateType)
	if not player then return 0 end
	return player.amountPerSecond or player.rate or 0
end

function NativeAPI:GetRaidRate(set, rateType)
	if not set then return 0 end
	
	local val = set.amountPerSecond or set.rate
	if val then
		return val
	end
	
	-- Fallback: sum up participants
	local totalRate = 0
	local sources = set.combatSources or set.participants or {}
	for _, p in pairs(sources) do
		local prate = p.amountPerSecond or p.rate
		if not prate then
			-- Try to get it from GetPlayerRate
			prate = self:GetPlayerRate(set, p, rateType)
		end
		
		if issecretvalue and issecretvalue(prate) then
			return prate -- Any secret makes total secret
		end
		totalRate = totalRate + (tonumber(prate) or 0)
	end
	
	return totalRate
end

-- Separate debug helper to keep hot path clean
local function DebugLogSource(source)
	Skada:Debug("GetPlayerSpells source type:", type(source))
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

function NativeAPI:GetPlayerSpells(playerID, set, damageType)
	local sessionType = set and set.sessionType or 1
	local source = self:GetSessionSource(playerID, sessionType, damageType)

	if not source then
		if Skada.db.profile.debug then
			Skada:Debug("GetPlayerSpells: No source found for", playerID, "damageType", damageType)
		end
		return nil
	end

	if Skada.db.profile.debug then
		DebugLogSource(source)
	end
	
	-- Try to find spells in various possible locations
	-- Common field names based on WoW API patterns
	local spellFields = {"combatSpells", "spells", "abilities", "damageSpells", "healingSpells"}
	
	for _, field in ipairs(spellFields) do
		local val = source[field]
		if val and (type(val) == "table" or (issecretvalue and issecretvalue(val))) then
			if Skada.db.profile.debug then
				Skada:Debug("Found spells in field:", field)
			end
			return val
		end
	end
	
	-- If source itself looks like a spells array
	local itemCount = 0
	local success, isSecret = pcall(function() return issecretvalue and issecretvalue(source) end)
	if success and isSecret then
		-- If the whole source is secret, we assume it's an iterable secret collection
		return source
	end
	
	if type(source) ~= "table" then
		return nil
	end
	
	local looksLikeSpellsArray = true
	for _, v in pairs(source) do
		itemCount = itemCount + 1
		local isVTable = type(v) == "table"
		local isVSecret = issecretvalue and issecretvalue(v)
		
		if not isVTable and not isVSecret then
			looksLikeSpellsArray = false
			break
		end
		
		-- If it's a table, check for expected fields. If it's secret, we can't check fields but assume it's data.
		if isVTable and (not v.spellID and not v.abilityID and not v.totalAmount) then
			looksLikeSpellsArray = false
			break
		end
	end
	
	if looksLikeSpellsArray and itemCount > 0 then
		if Skada.db.profile.debug then
			Skada:Debug("Source appears to be spells array with", itemCount, "items")
		end
		return source
	end
	
	-- No spells found
	if Skada.db.profile.debug then
		Skada:Debug("No spells found in source")
	end
	return nil
end

function NativeAPI:GetPlayerSpell(playerID, set, damageType, spellID)
	local spells = self:GetPlayerSpells(playerID, set, damageType)
	if spells then
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.spellID == spellID then
				return spell
			end
		end
	end
	return nil
end
function NativeAPI:IsAvailable()
	local available = C_DamageMeter.IsDamageMeterAvailable()
	return available
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
		local success, result = pcall(C_DamageMeter.GetAvailableCombatSessions)
	if success and result then
		return result
	else
		return {}
	end
end

--[[
	Get combat session info by sessionID
	Returns: DamageMeterCombatSessionInfo
]]
function NativeAPI:GetSessionByID(sessionID)
	if not sessionID then return nil end
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID)
	if success then
		return result
	else
		return nil
	end
end

--[[
	Get combat session info by session type
	DEPRECATED: Use GetCurrentSession() or GetTotalSession() instead
	This function is kept for backward compatibility but may not work correctly
]]
function NativeAPI:GetSessionByType(sessionType)
	if not sessionType then 
		return nil 
	end
	
	-- Try to convert old-style single argument to new-style table argument
	-- If sessionType is a number, assume it's a sessionType value
	-- Default to DamageDone (type = 0) which is most common
	
	local args = {}
	
	if type(sessionType) == "number" then
		args.sessionType = sessionType
		args.type = 0  -- Default to DamageDone
	elseif type(sessionType) == "table" then
		-- Already in correct format
		args = sessionType
	else
		-- Unknown format, try as-is
		return nil
	end
	
	-- Try to get the session using GetCombatSessionFromType
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success then
		return result
	else
		return nil
	end
end

--[[
	Test all possible session types to find the correct one
]]
function NativeAPI:TestSessionTypes()
	-- According to documentation:
	-- Enum.DamageMeterSessionType values:
	-- 0 = Overall
	-- 1 = Current
	-- 2 = Expired
	
	-- Enum.DamageMeterType values:
	-- 0 = DamageDone
	-- 1 = Dps
	-- 2 = HealingDone
	-- 3 = Hps
	-- 4 = Absorbs
	-- 5 = Interrupts
	-- 6 = Dispels
	-- 7 = DamageTaken
	-- 8 = AvoidableDamageTaken
	
	-- Test session types (0=Overall, 1=Current, 2=Expired)
	local sessionTypes = {0, 1, 2}
	
	for i, sessionType in ipairs(sessionTypes) do
		-- Try with different damage meter types
		for damageType = 0, 8 do
			-- Create args table as documented
			local args = {
				sessionType = sessionType,
				type = damageType
			}
			
			local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
			
			if success and result then
				-- Cache successful values
				if sessionType == 1 then -- Current
					self.sessionTypeCache.current = sessionType
					self.sessionTypeCache.currentDamageType = damageType
				elseif sessionType == 0 then -- Overall
					self.sessionTypeCache.total = sessionType
					self.sessionTypeCache.totalDamageType = damageType
				end
				
				break -- Found working damage type for this session
			end
		end
	end
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
	-- Prioritize simulation (safety: only out of combat)
	if Skada.Simulation and Skada.Simulation.active and not InCombatLockdown() then
		return Skada.Simulation:GetMockSession(sessionType, damageType)
	end

	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, damageType)
	if success and result then
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
			if success and result then
				return result
			end
		end
	end

	return nil
end

function NativeAPI:GetCurrentSession()
	return self:GetSessionByParams(self.sessionTypeCache.current or 1, self.sessionTypeCache.currentDamageType or 0)
end

function NativeAPI:GetTotalSession()
	return self:GetSessionByParams(self.sessionTypeCache.total or 0, self.sessionTypeCache.totalDamageType or 0)
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
