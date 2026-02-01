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

-- Cache for discovered session types
NativeAPI.sessionTypeCache = {
	current = nil,  -- Cache for current session type
	total = nil,    -- Cache for total session type
	currentDamageType = 0, -- Cache for working damage type (current)
	totalDamageType = 0    -- Cache for working damage type (total)
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

local function sanitizeNumber(val)
	if not val then return nil end
	if type(val) ~= "number" then return val end
	
	-- Try to strip secret status by string round-trip
	local success, s = pcall(string.format, "%f", val)
	if success then
		return tonumber(s)
	end
	return 0 -- Failed to sanitize, return 0 to prevent crashes
end

--[[
	Get detailed session source data (spells, etc.)
]]
function NativeAPI:GetSessionSource(sourceGUID, sessionType, damageType)
	if not sourceGUID then return nil end
	
	-- Try standard arguments first
	local success, result = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, damageType, sourceGUID)
	if success and result then return result end
	
	return nil
end

--[[
	Update spells for a player from session source
]]
local function updateSpells(player, sessionSource, statType)
	if not sessionSource or not sessionSource.combatSpells then return end
	
	local spellTable, valueKey
	if statType == "damage" then
		player.damagespells = player.damagespells or {}
		spellTable = player.damagespells
		valueKey = "damage"
	elseif statType == "healing" then
		player.healingspells = player.healingspells or {}
		spellTable = player.healingspells
		valueKey = "healing"
	elseif statType == "damagetaken" then
		player.damagetakenspells = player.damagetakenspells or {}
		spellTable = player.damagetakenspells
		valueKey = "damage"
	elseif statType == "dispels" then
		player.dispellspells = player.dispellspells or {}
		spellTable = player.dispellspells
		valueKey = "count"
	elseif statType == "interrupts" then
		player.interruptspells = player.interruptspells or {}
		spellTable = player.interruptspells
		valueKey = "count"
	else
		return
	end

	for _, spellData in pairs(sessionSource.combatSpells) do
		local amount = sanitizeNumber(spellData.totalAmount)
		local spellID = spellData.spellID
		
		if spellID and amount > 0 then
			local spellInfo = C_Spell.GetSpellInfo(spellID)
			local spellName = spellInfo and spellInfo.name or ("Spell " .. spellID)
			
			local spell = spellTable[spellName]
			if not spell then
				spell = {id = spellID, name = spellName}
				spell[valueKey] = 0
				spellTable[spellName] = spell
			end
			
			spell[valueKey] = amount
		end
	end
end

--[[
	Check if damage meter is currently available
]]
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
function NativeAPI:GetCurrentSession()
	-- According to documentation:
	-- sessionType = 1 (Current)
	-- type = 0 (DamageDone) - most common for damage meters
	
	local args = {
		sessionType = self.sessionTypeCache.current or 1,  -- Current session
		type = self.sessionTypeCache.currentDamageType or 0 -- DamageDone or discovered type
	}
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success and result then
		return result
	else
		-- Try with Enum values if they exist
		if Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current then
			local enumArgs = {
				sessionType = Enum.DamageMeterSessionType.Current,
				type = Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0
			}
			
			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumArgs.sessionType, enumArgs.type)
			if success and result then
				return result
			end
		end
		
		return nil
	end
end

--[[
	Get total/overall session (shorthand)
	According to documentation: sessionType = 0 for Overall
]]
function NativeAPI:GetTotalSession()
	-- According to documentation:
	-- sessionType = 0 (Overall)
	-- type = 0 (DamageDone) - most common for damage meters
	
	local args = {
		sessionType = self.sessionTypeCache.total or 0,  -- Overall session
		type = self.sessionTypeCache.totalDamageType or 0 -- DamageDone or discovered type
	}
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success and result then
		return result
	else
		-- Try with Enum values if they exist
		if Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall then
			local enumArgs = {
				sessionType = Enum.DamageMeterSessionType.Overall,
				type = Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0
			}
			
			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumArgs.sessionType, enumArgs.type)
			if success and result then
				return result
			end
		end
		
		return nil
	end
end

--[[
	Get damage taken session
	According to documentation: type = 7 for DamageTaken
]]
function NativeAPI:GetDamageTakenSession()
	-- According to documentation:
	-- sessionType = 1 (Current)
	-- type = 7 (DamageTaken)
	
	local args = {
		sessionType = 1,  -- Current session
		type = 7          -- DamageTaken
	}
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success and result then
		return result
	else
		-- Try with Enum values if they exist
		if Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current then
			local enumArgs = {
				sessionType = Enum.DamageMeterSessionType.Current,
				type = Enum.DamageMeterType and Enum.DamageMeterType.DamageTaken or 7
			}
			
			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumArgs.sessionType, enumArgs.type)
			if success and result then
				return result
			end
		end
		
		return nil
	end
end

--[[
	Get dispels session
	According to documentation: type = 6 for Dispels
]]
function NativeAPI:GetDispelsSession()
	-- According to documentation:
	-- sessionType = 1 (Current)
	-- type = 6 (Dispels)
	
	local args = {
		sessionType = 1,  -- Current session
		type = 6          -- Dispels
	}
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success and result then
		return result
	else
		-- Try with Enum values if they exist
		if Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current then
			local enumArgs = {
				sessionType = Enum.DamageMeterSessionType.Current,
				type = Enum.DamageMeterType and Enum.DamageMeterType.Dispels or 6
			}
			
			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumArgs.sessionType, enumArgs.type)
			if success and result then
				return result
			end
		end
		
		return nil
	end
end

--[[
	Get interrupts session
	According to documentation: type = 5 for Interrupts
]]
function NativeAPI:GetInterruptsSession()
	-- According to documentation:
	-- sessionType = 1 (Current)
	-- type = 5 (Interrupts)
	
	local args = {
		sessionType = 1,  -- Current session
		type = 5          -- Interrupts
	}
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success and result then
		return result
	else
		-- Try with Enum values if they exist
		if Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current then
			local enumArgs = {
				sessionType = Enum.DamageMeterSessionType.Current,
				type = Enum.DamageMeterType and Enum.DamageMeterType.Interrupts or 5
			}
			
			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumArgs.sessionType, enumArgs.type)
			if success and result then
				return result
			end
		end
		
		return nil
	end
end

--[[
	Get healing done session
	According to documentation: type = 2 for HealingDone
]]
function NativeAPI:GetHealingDoneSession()
	-- According to documentation:
	-- sessionType = 1 (Current)
	-- type = 2 (HealingDone)
	
	local args = {
		sessionType = 1,  -- Current session
		type = 2          -- HealingDone
	}
	
	local success, result = pcall(C_DamageMeter.GetCombatSessionFromType, args.sessionType, args.type)
	
	if success and result then
		return result
	else
		-- Try with Enum values if they exist
		if Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current then
			local enumArgs = {
				sessionType = Enum.DamageMeterSessionType.Current,
				type = Enum.DamageMeterType and Enum.DamageMeterType.HealingDone or 2
			}
			
			success, result = pcall(C_DamageMeter.GetCombatSessionFromType, enumArgs.sessionType, enumArgs.type)
			if success and result then
				return result
			end
		end
		
		return nil
	end
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
function NativeAPI:UpdateSkadaFromSession(set, sessionData)
	if not sessionData then
		return
	end
	
	-- Update set metadata
	if sessionData.encounterName then
		set.mobname = sessionData.encounterName
		set.gotboss = true
	elseif not set.mobname then
		set.mobname = "Combat" -- Fallback name to ensure segment saves
	end
	
	if sessionData.encounterID then
		set.encounterID = sessionData.encounterID
	end
	
	local offset = time() - GetTime()
	
	if sessionData.startTime then
		local sTime = sessionData.startTime
		-- If startTime looks like GetTime() (small number) instead of epoch, convert it
		if sTime < 1000000000 then
			sTime = offset + sTime
		end
		set.starttime = sTime
	end
	
	if sessionData.endTime then
		local eTime = sessionData.endTime
		-- If endTime looks like GetTime() (small number) instead of epoch, convert it
		if eTime < 1000000000 then
			eTime = offset + eTime
		end
		set.endtime = eTime
		-- Calculate duration
		set.time = set.endtime - set.starttime
	end
	
	-- Update player data from combatSources or participants
	local sources = sessionData.combatSources or sessionData.participants or sessionData.players or sessionData.units or sessionData.members or {}
	
	if Skada.db.profile.debug then
		local count = 0
		for _ in pairs(sources) do count = count + 1 end
		
		if count == 0 then
			Skada:Debug("NativeAPI: Session data keys: " .. getKeys(sessionData))
		end
	end
	
	local loggedMissing = false

	for _, sourceData in pairs(sources) do
		-- Try to get player GUID and name from source data
		local playerGuid = sourceData.sourceGUID or sourceData.guid or sourceData.playerGUID or sourceData.unitGUID or sourceData.id or sourceData.unitID
		local playerName = sourceData.name or sourceData.playerName or sourceData.unitName
		
		-- Sanitize restricted/secret values
		if playerGuid then playerGuid = string.format("%s", playerGuid) end
		if playerName then playerName = string.format("%s", playerName) end

		if not (playerGuid and playerName) and not loggedMissing and Skada.db.profile.debug then
			Skada:Debug("NativeAPI: Missing GUID/Name in source. Keys: " .. getKeys(sourceData))
			loggedMissing = true
		end
		
		if playerGuid and playerName then
			local playerClass = sourceData.class or sourceData.classFilename
			local player = Skada:get_player(set, playerGuid, playerName, playerClass)
			if player then
				-- Update core stats - native API uses totalAmount for damage/healing
				if sourceData.damage then
					player.damage = sanitizeNumber(sourceData.damage)
				elseif sourceData.totalAmount then
					-- For DamageDone session type, totalAmount is damage
					player.damage = sanitizeNumber(sourceData.totalAmount)
				elseif sourceData.amount then
					player.damage = sanitizeNumber(sourceData.amount)
				elseif sourceData.value then
					player.damage = sanitizeNumber(sourceData.value)
				end
				
				if sourceData.amountPerSecond then
					player.native_dps = sanitizeNumber(sourceData.amountPerSecond)
				end
				
				-- Fetch detailed spell data if available
				if sourceData.sourceGUID then
					local sessionType = NativeAPI.sessionTypeCache.current
					if set == Skada.total then sessionType = NativeAPI.sessionTypeCache.total end
					if not sessionType then sessionType = 1 end
					
					-- 0 = DamageDone
					local sessionSource = NativeAPI:GetSessionSource(sourceData.sourceGUID, sessionType, 0)
					if sessionSource then
						updateSpells(player, sessionSource, "damage")
					end
				end

				-- Healing would come from a HealingDone session type
				if sourceData.healing then
					player.healing = sanitizeNumber(sourceData.healing)
				elseif sourceData.totalAmount and set.type == "healing" then -- Context aware? No, simplified
					-- If we knew this was a healing session...
					-- But we rely on separate calls for healing.
					-- For now, UpdateHealingFromSession handles this.
				end
				
				-- Damage taken would come from a DamageTaken session type
				if sourceData.damageTaken then
					player.damagetaken = sanitizeNumber(sourceData.damageTaken)
				end
				
				-- Update class
				if sourceData.class or sourceData.classFilename then
					player.class = sourceData.class or sourceData.classFilename
				end
				
				-- Initialize empty spell tables (no spell details available from native API)
				player.damagespells = player.damagespells or {}
				player.healingspells = player.healingspells or {}
				player.damaged = player.damaged or {}
				
				-- Mark player as updated
				player.last = time()
			end
		end
	end
	
	-- Recalculate set totals from players
	set.damage = 0
	set.healing = 0
	for _, player in ipairs(set.players) do
		set.damage = set.damage + (player.damage or 0)
		set.healing = set.healing + (player.healing or 0)
	end
	
	-- Mark setasas updated
	set.last_action = time()
end

--[[
	Update Skada's damage taken data from native API session data
]]
function NativeAPI:UpdateDamageTakenFromSession(set, sessionData)
	if not sessionData then
		return
	end
	
	-- Update player data from combatSources or participants
	local sources = sessionData.combatSources or sessionData.participants or sessionData.players or sessionData.units or sessionData.members or {}
	
	for _, sourceData in pairs(sources) do
		-- Try to get player GUID and name from source data
		local playerGuid = sourceData.sourceGUID or sourceData.guid or sourceData.playerGUID
		local playerName = sourceData.name or sourceData.playerName
		
		-- Sanitize restricted/secret values
		if playerGuid then playerGuid = string.format("%s", playerGuid) end
		if playerName then playerName = string.format("%s", playerName) end
		
		if playerGuid and playerName then
			local playerClass = sourceData.class or sourceData.classFilename
			local player = Skada:get_player(set, playerGuid, playerName, playerClass)
			if player then
				-- Update damage taken - could be in totalAmount or damageTaken field
				if sourceData.damageTaken then
					player.damagetaken = sanitizeNumber(sourceData.damageTaken)
				elseif sourceData.totalAmount then
					player.damagetaken = sanitizeNumber(sourceData.totalAmount)
				end
				
				-- Update class
				if sourceData.class or sourceData.classFilename then
					player.class = sourceData.class or sourceData.classFilename
				end
				
				-- Mark player as updated
				player.last = time()
				
				-- Fetch damage taken spells
				if sourceData.sourceGUID then
					local sessionType = NativeAPI.sessionTypeCache.current
					if set == Skada.total then sessionType = NativeAPI.sessionTypeCache.total end
					if not sessionType then sessionType = 1 end
					
					-- 7 = DamageTaken
					local sessionSource = NativeAPI:GetSessionSource(sourceData.sourceGUID, sessionType, 7)
					if sessionSource then
						updateSpells(player, sessionSource, "damagetaken")
					end
				end
			end
		end
	end
	
	-- Recalculate set total damage taken from players
	set.damagetaken = 0
	for _, player in ipairs(set.players) do
		set.damagetaken = set.damagetaken + (player.damagetaken or 0)
	end
	
	-- Mark set as updated
	set.last_action = time()
end

--[[
	Update Skada's dispels data from native API session data
]]
function NativeAPI:UpdateDispelsFromSession(set, sessionData)
	if not sessionData then
		return
	end
	
	-- Update player data from combatSources or participants
	local sources = sessionData.combatSources or sessionData.participants or sessionData.players or sessionData.units or sessionData.members or {}
	
	for _, sourceData in pairs(sources) do
		-- Try to get player GUID and name from source data
		local playerGuid = sourceData.sourceGUID or sourceData.guid or sourceData.playerGUID
		local playerName = sourceData.name or sourceData.playerName
		
		-- Sanitize restricted/secret values
		if playerGuid then playerGuid = string.format("%s", playerGuid) end
		if playerName then playerName = string.format("%s", playerName) end
		
		if playerGuid and playerName then
			local playerClass = sourceData.class or sourceData.classFilename
			local player = Skada:get_player(set, playerGuid, playerName, playerClass)
			if player then
				-- Update dispels - could be in totalAmount or count field
				if sourceData.dispels then
					player.dispells = sanitizeNumber(sourceData.dispels)
				elseif sourceData.count then
					player.dispells = sanitizeNumber(sourceData.count)
				elseif sourceData.totalAmount then
					-- For non-damage metrics, totalAmount might be the count
					player.dispells = sanitizeNumber(sourceData.totalAmount)
				end
				
				-- Update class
				if sourceData.class or sourceData.classFilename then
					player.class = sourceData.class or sourceData.classFilename
				end
				
				-- Mark player as updated
				player.last = time()
				
				-- Fetch dispels spells
				if sourceData.sourceGUID then
					local sessionType = NativeAPI.sessionTypeCache.current
					if set == Skada.total then sessionType = NativeAPI.sessionTypeCache.total end
					if not sessionType then sessionType = 1 end
					
					-- 6 = Dispels
					local sessionSource = NativeAPI:GetSessionSource(sourceData.sourceGUID, sessionType, 6)
					if sessionSource then
						updateSpells(player, sessionSource, "dispels")
					end
				end
			end
		end
	end
	
	-- Recalculate set total dispels from players
	set.dispells = 0
	for _, player in ipairs(set.players) do
		set.dispells = set.dispells + (player.dispells or 0)
	end
	
	-- Mark set as updated
	set.last_action = time()
end

--[[
	Update Skada's interrupts data from native API session data
]]
function NativeAPI:UpdateInterruptsFromSession(set, sessionData)
	if not sessionData then
		return
	end
	
	-- Update player data from combatSources or participants
	local sources = sessionData.combatSources or sessionData.participants or sessionData.players or sessionData.units or sessionData.members or {}
	
	for _, sourceData in pairs(sources) do
		-- Try to get player GUID and name from source data
		local playerGuid = sourceData.sourceGUID or sourceData.guid or sourceData.playerGUID
		local playerName = sourceData.name or sourceData.playerName
		
		-- Sanitize restricted/secret values
		if playerGuid then playerGuid = string.format("%s", playerGuid) end
		if playerName then playerName = string.format("%s", playerName) end
		
		if playerGuid and playerName then
			local playerClass = sourceData.class or sourceData.classFilename
			local player = Skada:get_player(set, playerGuid, playerName, playerClass)
			if player then
				-- Update interrupts - could be in totalAmount or count field
				if sourceData.interrupts then
					player.interrupts = sanitizeNumber(sourceData.interrupts)
				elseif sourceData.count then
					player.interrupts = sanitizeNumber(sourceData.count)
				elseif sourceData.totalAmount then
					-- For non-damage metrics, totalAmount might be the count
					player.interrupts = sanitizeNumber(sourceData.totalAmount)
				end
				
				-- Update class
				if sourceData.class or sourceData.classFilename then
					player.class = sourceData.class or sourceData.classFilename
				end
				
				-- Mark player as updated
				player.last = time()
				
				-- Fetch interrupts spells
				if sourceData.sourceGUID then
					local sessionType = NativeAPI.sessionTypeCache.current
					if set == Skada.total then sessionType = NativeAPI.sessionTypeCache.total end
					if not sessionType then sessionType = 1 end
					
					-- 5 = Interrupts
					local sessionSource = NativeAPI:GetSessionSource(sourceData.sourceGUID, sessionType, 5)
					if sessionSource then
						updateSpells(player, sessionSource, "interrupts")
					end
				end
			end
		end
	end
	
	-- Recalculate set total interrupts from players
	set.interrupts = 0
	for _, player in ipairs(set.players) do
		set.interrupts = set.interrupts + (player.interrupts or 0)
	end
	
	-- Mark set as updated
	set.last_action = time()
end

--[[
	Update Skada's healing data from native API session data
]]
function NativeAPI:UpdateHealingFromSession(set, sessionData)
	if not sessionData then
		return
	end
	
	-- Update player data from combatSources or participants
	local sources = sessionData.combatSources or sessionData.participants or sessionData.players or sessionData.units or sessionData.members or {}
	
	for _, sourceData in pairs(sources) do
		-- Try to get player GUID and name from source data
		local playerGuid = sourceData.sourceGUID or sourceData.guid or sourceData.playerGUID
		local playerName = sourceData.name or sourceData.playerName
		
		-- Sanitize restricted/secret values
		if playerGuid then playerGuid = string.format("%s", playerGuid) end
		if playerName then playerName = string.format("%s", playerName) end
		
		if playerGuid and playerName then
			local playerClass = sourceData.class or sourceData.classFilename
			local player = Skada:get_player(set, playerGuid, playerName, playerClass)
			if player then
				-- Update healing - could be in totalAmount or healing field
				if sourceData.healing then
					player.healing = sanitizeNumber(sourceData.healing)
				elseif sourceData.totalAmount then
					-- For HealingDone session type, totalAmount is healing
					player.healing = sanitizeNumber(sourceData.totalAmount)
				end
				
				-- Update class
				if sourceData.class or sourceData.classFilename then
					player.class = sourceData.class or sourceData.classFilename
				end
				
				-- Mark player as updated
				player.last = time()
				
				-- Fetch healing spells
				if sourceData.sourceGUID then
					local sessionType = NativeAPI.sessionTypeCache.current
					if set == Skada.total then sessionType = NativeAPI.sessionTypeCache.total end
					if not sessionType then sessionType = 1 end
					
					-- 2 = HealingDone
					local sessionSource = NativeAPI:GetSessionSource(sourceData.sourceGUID, sessionType, 2)
					if sessionSource then
						updateSpells(player, sessionSource, "healing")
					end
				end
			end
		end
	end
	
	-- Recalculate set total healing from players
	set.healing = 0
	for _, player in ipairs(set.players) do
		set.healing = set.healing + (player.healing or 0)
	end
	
	-- Mark set as updated
	set.last_action = time()
end

--[[
	Poll the native API for updates
	Called on a timer to refresh Skada's data
]]
function NativeAPI:PollForUpdates()
	-- Always try to get current session data, even outside combat
	local currentSession = self:GetCurrentSession()
	if currentSession then
		local isActive = not currentSession.endTime
		
		-- If we have active session data but no current combat, start one
		if not Skada.current and isActive then
			-- Check if there's actual combat data
			local sources = currentSession.combatSources or currentSession.participants or currentSession.players or currentSession.units or currentSession.members or {}
			local count = 0
			for _ in pairs(sources) do count = count + 1 end
			
			if count > 0 then
				Skada:StartCombat()
			end
		end
		
		-- Update current combat if it exists
		if Skada.current then
			self:UpdateSkadaFromSession(Skada.current, currentSession)
			
			-- Also update specialized modules
			-- Damage Taken
			local damageTakenSession = self:GetDamageTakenSession()
			if damageTakenSession then
				self:UpdateDamageTakenFromSession(Skada.current, damageTakenSession)
			end
			
			-- Dispels
			local dispelsSession = self:GetDispelsSession()
			if dispelsSession then
				self:UpdateDispelsFromSession(Skada.current, dispelsSession)
			end
			
			-- Interrupts
			local interruptsSession = self:GetInterruptsSession()
			if interruptsSession then
				self:UpdateInterruptsFromSession(Skada.current, interruptsSession)
			end
			
			-- Healing
			local healingSession = self:GetHealingDoneSession()
			if healingSession then
				self:UpdateHealingFromSession(Skada.current, healingSession)
			end
			
			-- If the session has ended, end the Skada segment
			if not isActive then
				Skada:EndSegment()
			end
		end
	end
	
	-- Get total session data
	if Skada.total then
		local totalSession = self:GetTotalSession()
		if totalSession then
			self:UpdateSkadaFromSession(Skada.total, totalSession)
			
			-- Also update specialized modules for total session
			-- Damage Taken
			local damageTakenSession = self:GetDamageTakenSession()
			if damageTakenSession then
				self:UpdateDamageTakenFromSession(Skada.total, damageTakenSession)
			end
			
			-- Dispels
			local dispelsSession = self:GetDispelsSession()
			if dispelsSession then
				self:UpdateDispelsFromSession(Skada.total, dispelsSession)
			end
			
			-- Interrupts
			local interruptsSession = self:GetInterruptsSession()
			if interruptsSession then
				self:UpdateInterruptsFromSession(Skada.total, interruptsSession)
			end
			
			-- Healing
			local healingSession = self:GetHealingDoneSession()
			if healingSession then
				self:UpdateHealingFromSession(Skada.total, healingSession)
			end
		end
	end
	
	-- Trigger display update if we have data
	if currentSession or (Skada.total and self:GetTotalSession()) then
		Skada:UpdateDisplay(false)
	end
end

--[[
	Start polling for native API updates
]]
function NativeAPI:StartPolling()
	if self.pollingTimer then
		return -- Already polling
	end
	
	-- Poll every 1 second for updates
	self.pollingTimer = Skada:ScheduleRepeatingTimer(function()
		self:PollForUpdates()
	end, 1.0)
end

--[[
	Stop polling for updates
]]
function NativeAPI:StopPolling()
	if self.pollingTimer then
		Skada:CancelTimer(self.pollingTimer)
		self.pollingTimer = nil
	end
end

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
