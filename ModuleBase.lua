--[[
	ModuleBase.lua
	
	Common patterns and utilities for Skada modules.
	This module provides reusable functions to eliminate DRY violations
	across different Skada modules.
]]

local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)
local SecretHelper = Skada.SecretHelper

local ModuleBase = {}
Skada.ModuleBase = ModuleBase

local pairs = pairs
local ipairs = ipairs

--[[
	Update a player list view (main module view)
	This handles the common pattern for Damage, Healing, DamageTaken, etc.
	
	@param win - Window object
	@param set - Current set
	@param options - Table with configuration:
		- damageType: NativeAPI damage type constant
		- valueKey: Key for the main value (e.g., "totalAmount", "healing")
		- rateKey: Key for the rate value (e.g., "amountPerSecond", "rate")
		- columns: Table with column keys (e.g., {Damage = true, DPS = true, Percent = true})
		- rateType: Rate type for NativeAPI GetPlayerRate (optional)
		- getRateFunc: Custom function to get rate (optional, takes set, player)
		- formatRate: Function to format rate value (optional, default is FormatNumber)
		- includePercent: Whether to include percentage column (default true)
]]
function ModuleBase:UpdatePlayerList(win, set, options)
	if not set then return end
	
	local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
	if not view then return end
	
	local sources = view.combatSources or {}
	local hasSecretAPI = SecretHelper:HasSecretAPI()
	
	-- Detect secrets and calculate total (using cached detection)
	local cacheKey = "playerlist_" .. tostring(set.sessionType or 0) .. "_" .. tostring(options.damageType)
	local hasSecretValues = SecretHelper:DetectSecretsCached(cacheKey, sources, options.valueKey or "totalAmount")
	
	-- Calculate total (only for non-secrets)
	local totalValue = 0
	if not hasSecretValues then
		for _, player in pairs(sources) do
			local value = player[options.valueKey] or player.totalAmount
			if value then
				totalValue = totalValue + (tonumber(value) or 0)
			end
		end
	end
	
	-- Update window metadata for secret state
	SecretHelper:UpdateWindowMetadata(win, hasSecretValues)
	
	local max = 0
	local nr = 1
	
	if hasSecretValues then
		-- SLOW PATH: Multi-mode handling for protected data
		for _, player in pairs(sources) do
			local playerName = SecretHelper:GetPlayerName(player)
			if playerName then
				local rawValue = player[options.valueKey] or player.totalAmount
				local rawRate = player[options.rateKey] or player.rate
				local rate = 0
				
				if not (hasSecretAPI and issecretvalue(rawRate)) then
					rate = tonumber(rawRate) or 0
				elseif options.getRateFunc then
					rate = options.getRateFunc(set, player)
				end
				
				local d = self:ReuseDatasetEntry(win.dataset, nr)
				d._is_nodata = nil
				d.id = "combat_" .. nr
				d.label = playerName
				d.class = SecretHelper:GetPlayerClass(player)
				d.role = player.role
				d.order = nr
				d.value = SecretHelper:GetDisplayValue(rawValue, nr)
				
				local valueText = Skada:FormatNumberSecret(rawValue)
				local rateText = Skada:FormatNumberSecret(rawRate or rate)
				
				if options.columns then
					Skada:FormatValueText(d, valueText, options.columns[1], rateText, options.columns[2], "", options.columns[3])
				else
					d.valuetext = valueText
				end
				nr = nr + 1
			end
		end
		win.metadata.maxvalue = 1000 - 1
	else
		-- FAST PATH: Standard arithmetic and comparisons (no secrets)
		for _, player in pairs(sources) do
			local playerName = player.name or player.unitName
			if playerName then
				local value = tonumber(player[options.valueKey] or player.totalAmount) or 0
				local rate = tonumber(player[options.rateKey] or player.rate) or 0
				
				if rate == 0 and options.getRateFunc then
					rate = options.getRateFunc(set, player)
				end
				
				local d = self:ReuseDatasetEntry(win.dataset, nr)
				d._is_nodata = nil
				d.id = player.sourceGUID or playerName
				d.label = playerName
				d.class = player.class or player.classFilename
				d.role = player.role
				d.order = nr
				d.value = value
				
				if value > max then max = value end
				
				local valueText = Skada:FormatNumber(value)
				local rateText = options.formatRate and options.formatRate(rate) or Skada:FormatNumber(rate)
				local percentText = (options.includePercent and totalValue > 0) and string.format("%02.1f%%", (value / totalValue) * 100) or nil
				
				if options.columns then
					Skada:FormatValueText(d, valueText, options.columns[1], rateText, options.columns[2], percentText, options.columns[3])
				else
					d.valuetext = valueText
				end
				nr = nr + 1
			end
		end
		win.metadata.maxvalue = (max > 0 and max or 1)
	end
end

--[[
	Update a simple player list without rates (for Dispels, Interrupts, etc.)
	
	@param win - Window object
	@param set - Current set
	@param options - Table with configuration:
		- damageType: NativeAPI damage type constant
		- valueKey: Key for the value (default "totalAmount")
]]
function ModuleBase:UpdateSimpleList(win, set, options)
	if not set then return end
	
	local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
	if not view then return end
	
	local sources = view.combatSources or {}
	local hasSecretAPI = SecretHelper:HasSecretAPI()
	
	-- Detect secrets (using cached detection)
	local cacheKey = "simplelist_" .. tostring(set.sessionType or 0) .. "_" .. tostring(options.damageType)
	local hasSecretValues = SecretHelper:DetectSecretsCached(cacheKey, sources, options.valueKey or "totalAmount")
	
	-- Update window metadata
	SecretHelper:UpdateWindowMetadata(win, hasSecretValues)
	
	local max = 0
	local nr = 1
	
	if hasSecretValues then
		-- SLOW PATH
		for _, player in pairs(sources) do
			local playerName = SecretHelper:GetPlayerName(player)
			if playerName then
				local rawValue = player[options.valueKey] or player.totalAmount
				local isSecret = hasSecretAPI and rawValue and issecretvalue(rawValue)
				local value = SecretHelper:SafeNumber(rawValue)
				
				if value > 0 or isSecret then
					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = "combat_" .. nr
					d.label = playerName
					d.class = SecretHelper:GetPlayerClass(player)
					d.role = player.role
					d.order = nr
					d.value = SecretHelper:GetDisplayValue(rawValue, nr)
					d.valuetext = Skada:FormatNumberSecret(rawValue)
					nr = nr + 1
				end
			end
		end
	else
		-- FAST PATH
		for _, player in pairs(sources) do
			local playerName = player.name or player.unitName
			if playerName then
				local value = tonumber(player[options.valueKey] or player.totalAmount) or 0
				
				if value > 0 then
					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = player.sourceGUID or playerName
					d.label = playerName
					d.class = player.class or player.classFilename
					d.role = player.role
					d.order = nr
					d.value = value
					d.valuetext = Skada:FormatNumber(value)
					
					if value > max then max = value end
					nr = nr + 1
				end
			end
		end
		max = (max > 0 and max or 1)
	end
	
	win.metadata.maxvalue = hasSecretValues and (1000 - 1) or max
end

--[[
	Update a spell list view (detail view)
	This handles the common pattern for spell breakdowns
	
	@param win - Window object
	@param playerid - Player ID
	@param set - Current set
	@param damageType - NativeAPI damage type constant
	@param options - Optional table with configuration:
		- valueKey: Key for spell value (default "totalAmount")
]]
function ModuleBase:UpdateSpellList(win, playerid, set, damageType, options)
	options = options or {}
	local valueKey = options.valueKey or "totalAmount"

	local view = Skada.NativeAPI:GetSessionView(set, damageType)
	local player = Skada:find_player_in_session(view, playerid)

	if not player then
		player = Skada:find_player(set, playerid)
	end

	if not player then return end

	local realID = player.sourceGUID or player.guid or player.unitGUID or player.id or playerid
	local spells = Skada.NativeAPI:GetPlayerSpells(realID, view or set, damageType)

	if not spells then
		return
	end

	local hasSecretAPI = SecretHelper:HasSecretAPI()

	-- If the spells collection itself is a secret value, we cannot iterate
	-- it with pairs() or index it. The C_DamageMeter API marks spell source
	-- data as SecretWhenInCombat — this is a Blizzard restriction that
	-- prevents addons from reading spell details during active combat.
	if hasSecretAPI and issecretvalue(spells) then
		local d = self:ReuseDatasetEntry(win.dataset, 1)
		d._is_nodata = nil
		d.id = "secret_spells"
		d.label = L["Spell details available after combat"]
		d.value = 999
		d.valuetext = "?"
		win.metadata.maxvalue = 1000 - 1
		return
	end

	-- Detect secrets and calculate total (using cached detection)
	local cacheKey = "spelllist_" .. tostring(set.sessionType or 0) .. "_" .. tostring(damageType)
	local hasSecretValues = SecretHelper:DetectSecretsCached(cacheKey, spells, valueKey)

	-- Calculate total (only for non-secrets)
	local totalValue = 0
	if not hasSecretValues then
		for _, spell in pairs(spells) do
			if type(spell) == "table" then
				local value = spell[valueKey]
				if value and type(value) == "number" then
					totalValue = totalValue + value
				end
			end
		end
	end

	local max = 0
	local nr = 1

	if hasSecretValues then
		-- SLOW PATH: spell values are secret; we cannot do arithmetic or
		-- comparisons on them, but we CAN pass them to string.format and
		-- FontString:SetText for display.
		for _, spell in pairs(spells) do
			if type(spell) == "table" then
				local rawValue = spell[valueKey]
				-- Check type() before any comparison — type() is safe on
				-- secrets, but ~= crashes on them.
				local isSecret = hasSecretAPI and rawValue and issecretvalue(rawValue)
				local isNonZeroNumber = (type(rawValue) == "number") and (rawValue ~= 0)
				if isSecret or isNonZeroNumber then
					local spellID = spell.spellID or 0
					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = spellID

					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					d.label = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))

					d.value = SecretHelper:GetDisplayValue(rawValue, nr)
					d.valuetext = Skada:FormatNumberSecret(rawValue)
					d.icon = Skada:GetSpellIcon(spellID)
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = 1000 - 1
	else
		-- FAST PATH
		for _, spell in pairs(spells) do
			if type(spell) == "table" then
				local value = tonumber(spell[valueKey]) or 0
				if value ~= 0 then
					local spellID = spell.spellID or 0
					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = spellID

					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					d.label = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))

					d.value = value
					if value > max then max = value end

					if totalValue > 0 then
						d.valuetext = Skada:FormatNumber(value) .. string.format(" (%02.1f%%)", (value / totalValue) * 100)
					else
						d.valuetext = Skada:FormatNumber(value)
					end
					d.icon = Skada:GetSpellIcon(spellID)
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = (max > 0 and max or 1)
	end
end

--[[
	Calculate total for a set
	
	@param set - The set
	@param damageType - NativeAPI damage type constant
	@param options - Optional table:
		- valueKey: Key to use (default "totalAmount")
		- sourcesKey: Key for sources table (default "combatSources")
	@return number - Total value (or secret value if any found)
]]
function ModuleBase:GetSetTotal(set, damageType, options)
	if not set then return 0 end
	
	options = options or {}
	local valueKey = options.valueKey or "totalAmount"
	local sourcesKey = options.sourcesKey or "combatSources"
	
	local view = Skada.NativeAPI:GetSessionView(set, damageType)
	if not view then return 0 end
	
	local total = 0
	local sources = view[sourcesKey] or view.combatSources or {}
	local hasSecretAPI = SecretHelper:HasSecretAPI()
	
	for _, p in pairs(sources) do
		local value = p[valueKey] or p.totalAmount
		if value then
			if hasSecretAPI and issecretvalue(value) then
				return value -- Return secret value if found
			end
			total = total + (tonumber(value) or 0)
		end
	end
	
	return total
end

--[[
	Get player rate (DPS/HPS/DTPS) from NativeAPI
	
	@param set - The set
	@param player - Player table
	@param rateType - NativeAPI rate type constant
	@return number - Rate value
]]
function ModuleBase:GetPlayerRate(set, player, rateType)
	return Skada.NativeAPI:GetPlayerRate(set, player, rateType)
end

--[[
	Get raid rate from NativeAPI
	
	@param set - The set
	@param rateType - NativeAPI rate type constant
	@return number - Raid rate value
]]
function ModuleBase:GetRaidRate(set, rateType)
	return Skada.NativeAPI:GetRaidRate(set, rateType)
end

--[[
	Create a standard tooltip handler for player tooltips with top spells
	
	@param options - Table with configuration:
		- damageType: NativeAPI damage type constant
		- valueKey: Key for player value (default "totalAmount")
		- rateKey: Key for rate value (default "amountPerSecond")
		- labelDamage: Label for damage/healing (e.g., L["Damage done"])
		- labelRate: Label for rate (e.g., L["DPS"])
		- spellValueKey: Key for spell values (default "totalAmount")
	@return function - Tooltip handler function
]]
function ModuleBase:CreatePlayerTooltip(options)
	return function(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		
		local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
		if not view then return end
		
		-- Resolve player (crucial for artificial IDs)
		local player = Skada:find_player_in_session(view, id)
		if not player then
			player = Skada:find_player(set, id)
		end
		
		if not player then return end
		
		local totaltime = Skada:GetSetTime(view)
		local rawValue = player[options.valueKey] or player.totalAmount or 0
		local rawRate = player[options.rateKey] or player.amountPerSecond or 0
		
		tooltip:AddLine((player.name or label) .. " - " .. options.labelRate)
		tooltip:AddDoubleLine(L["Segment time"], totaltime .. "s", 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(options.labelDamage, Skada:FormatNumberSecret(rawValue), 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(options.labelRate, Skada:FormatNumberSecret(rawRate), 1, 1, 1, 1, 1, 1)
		
		-- Add top spells
		local realID = player.sourceGUID or player.guid or player.unitGUID or player.id or id
		local spells = Skada.NativeAPI:GetPlayerSpells(realID, view, options.damageType)
		if spells then
			local sorted = {}
			local spellValueKey = options.spellValueKey or "totalAmount"

			for _, s in pairs(spells) do
				-- Only index if it's a real table; indexing a secret crashes
				if type(s) == "table" then
					local rawAmount = s[spellValueKey]
					if rawAmount then
						table.insert(sorted, s)
					end
				end
			end
			
			table.sort(sorted, function(a, b)
				return SecretHelper:SafeNumber(a[spellValueKey]) > SecretHelper:SafeNumber(b[spellValueKey])
			end)
			
			if #sorted > 0 then
				tooltip:AddLine(" ")
				tooltip:AddLine(L["Top Spells"])
				
				for i = 1, math.min(3, #sorted) do
					local s = sorted[i]
					
					-- Data access
					do
						local spellID = s.spellID or 0
						local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
						local name = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))
						
						local rawVal = s[spellValueKey] or 0
						
						if SecretHelper:HasSecretAPI() and issecretvalue(rawVal) then
							tooltip:AddDoubleLine(name, Skada:FormatNumberSecret(rawVal), 1, 1, 1, 1, 1, 1)
						else
							local val = tonumber(rawVal) or 0
							local playerVal = SecretHelper:SafeNumber(rawValue)
							local percent = playerVal > 0 and (val / playerVal) * 100 or 0
							tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1, 1, 1, 1, 1, 1)
						end
					end
				end
			end
		end
	end
end

--[[
	Create a simple tooltip handler without top spells
	
	@param labelTotal: Label for total line
	@return function - Tooltip handler
]]
function ModuleBase:CreateSimpleTooltip(labelTotal)
	return function(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		
		local player = Skada:find_player(set, id)
		if player then
			local rawValue = player.totalAmount or 0
			tooltip:AddDoubleLine(labelTotal, Skada:FormatNumberSecret(rawValue), 1, 1, 1, 1, 1, 1)
		end
	end
end

--[[
	Create a damage share tooltip handler (post-tooltip)
	Shows what percentage of total damage/healing the player contributed
	
	@param options - Table with configuration:
		- damageType: NativeAPI damage type constant
		- labelShare: Label for share line (e.g., L["Damage share"])
	@return function - Tooltip handler function
]]
function ModuleBase:CreateDamageShareTooltip(options)
	return function(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		
		local player = Skada:find_player(set, id)
		if not player then return end
		
		local rawPlayerValue = player.totalAmount or 0
		if SecretHelper:HasSecretAPI() and issecretvalue(rawPlayerValue) then
			return
		end
		
		local playerValue = tonumber(rawPlayerValue) or 0
		local totalValue = 0
		
		local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
		if view then
			local sources = view.combatSources or view.participants or {}
			for _, p in pairs(sources) do
				totalValue = totalValue + SecretHelper:SafeNumber(p.totalAmount)
			end
		end
		
		if totalValue > 0 then
			local percent = (playerValue / totalValue) * 100
			tooltip:AddDoubleLine(options.labelShare, ("%02.1f%%"):format(percent), 255, 255, 255, 255, 255, 255)
		end
	end
end

--[[
	Format set summary with value and optional rate
	
	@param datasetItem - Dataset item to format
	@param set - The set
	@param options - Table with:
		- damageType: NativeAPI damage type constant
		- valueKey: Key for value (default "totalAmount")
		- rateType: Rate type for GetRaidRate (optional)
		- columns: Table with column keys
]]
function ModuleBase:FormatSetSummary(datasetItem, set, options)
	local total = self:GetSetTotal(set, options.damageType, {valueKey = options.valueKey})
	
	if options.rateType then
		local rate = self:GetRaidRate(set, options.rateType)
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumberSecret(total), options.columns[1],
			Skada:FormatNumberSecret(rate), options.columns[2]
		)
	else
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(total), true)
	end
end

--[[
	Add standard feeds for a module (Personal rate and Raid rate)
	
	@param feedNamePersonal: Name for personal feed
	@param feedNameRaid: Name for raid feed
	@param rateType: NativeAPI rate type constant
	@param label: Label suffix (e.g., "DPS", "HPS")
	@param labelRaid: Raid label suffix (e.g., "RDPS", "RHPS")
]]
function ModuleBase:AddStandardFeeds(feedNamePersonal, feedNameRaid, rateType, label, labelRaid)
	Skada:AddFeed(feedNamePersonal, function()
		if Skada.current then
			local player = Skada:find_player(Skada.current, UnitGUID("player"))
			if player then
				local rate = self:GetPlayerRate(Skada.current, player, rateType)
				-- Use string.format to avoid concatenation crimes with secret values
				return string.format("%s %s", Skada:FormatNumberSecret(rate), label or "")
			end
		end
	end)
	
	Skada:AddFeed(feedNameRaid, function()
		if Skada.current then
			local rate = self:GetRaidRate(Skada.current, rateType)
			-- Use string.format to avoid concatenation crimes with secret values
			return string.format("%s %s", Skada:FormatNumberSecret(rate), labelRaid or "")
		end
	end)
end

--[[
	Remove standard feeds
	
	@param feedNamePersonal: Name for personal feed
	@param feedNameRaid: Name for raid feed
]]
function ModuleBase:RemoveStandardFeeds(feedNamePersonal, feedNameRaid)
	Skada:RemoveFeed(feedNamePersonal)
	Skada:RemoveFeed(feedNameRaid)
end

--[[
	Clear and reuse a dataset entry instead of creating new tables
	This reduces garbage collection pressure in high-update scenarios
]]
function ModuleBase:ReuseDatasetEntry(dataset, index)
	local entry = dataset[index]
	if entry then
		-- Clear all fields but keep the table
		for k, v in pairs(entry) do
			entry[k] = nil
		end
		return entry
	else
		-- Create new only if necessary
		entry = {}
		dataset[index] = entry
		return entry
	end
end
