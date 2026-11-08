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
	if type(set) ~= "table" then return end

	local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
	if type(view) ~= "table" then return end

	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return end

	local valueKey = options.valueKey or "totalAmount"
	local rateKey = options.rateKey or "amountPerSecond"

	-- Detect secrets and calculate total (using cached detection)
	local cacheKey = "playerlist_" .. tostring(set.sessionType or 0) .. "_" .. tostring(options.damageType)
	local hasSecretValues = SecretHelper:DetectSecretsCached(cacheKey, sources, valueKey)

	-- Calculate total (only for non-secrets)
	local totalValue = 0
	if not hasSecretValues then
		for _, player in ipairs(sources) do
			if type(player) == "table" then
				local value = player[valueKey]
				if type(value) == "nil" then
					value = player.totalAmount
				end
				if type(value) ~= "nil" then
					totalValue = totalValue + (tonumber(value) or 0)
				end
			end
		end
	end

	-- Update window metadata for secret state
	SecretHelper:UpdateWindowMetadata(win, hasSecretValues)

	local max = 0
	local nr = 1
	local sourceCount = 0
	for _, player in ipairs(sources) do
		if type(player) == "table" and not issecretvalue(player) then
			sourceCount = sourceCount + 1
		end
	end

	if hasSecretValues then
		-- SLOW PATH: values are protected. Use synthetic order values for the
		-- bars and let FormatNumberSecret produce display text.
		for _, player in ipairs(sources) do
			if type(player) == "table" and not issecretvalue(player) then
				local rawValue = player[valueKey]
				if type(rawValue) == "nil" then
					rawValue = player.totalAmount
				end
				local rawRate = player[rateKey]

				if type(rawValue) ~= "nil" or type(rawRate) ~= "nil" then
					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = "combat_" .. nr
					d.sourceGUID = player.sourceGUID
					d.sourceCreatureID = player.sourceCreatureID
					d.label = SecretHelper:GetPlayerLabel(player, nr)
					d.class = SecretHelper:GetPlayerClass(player)
					d.role = player.role
					d.order = nr
					d.value = SecretHelper:GetDisplayValue(rawValue, nr, sourceCount)

					local valueText = Skada:FormatNumberSecret(rawValue)
					local rateText = Skada:FormatNumberSecret(rawRate)

					if options.columns then
						Skada:FormatValueText(d, valueText, options.columns[1], rateText, options.columns[2], "", options.columns[3])
					else
						d.valuetext = valueText
					end
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = SecretHelper:GetMaxValue(true, 0, sourceCount)
	else
		-- FAST PATH: Standard arithmetic and comparisons (no secrets)
		for _, player in ipairs(sources) do
			if type(player) == "table" then
				local playerName = player.name
				if type(playerName) ~= "string" then
					playerName = player.unitName
				end
				if type(playerName) ~= "string" then
					playerName = "Combat " .. nr
				end

				local value = player[valueKey]
				if type(value) == "nil" then
					value = player.totalAmount
				end
				value = tonumber(value) or 0

				local rate = player[rateKey]
				if type(rate) == "nil" then
					rate = player.rate
				end
				rate = tonumber(rate) or 0

				if rate == 0 and options.getRateFunc then
					rate = options.getRateFunc(set, player)
				end

				local guid = player.sourceGUID
				local id
				if type(guid) == "string" and not issecretvalue(guid) then
					id = guid
				else
					id = "player_" .. nr
				end

				local d = self:ReuseDatasetEntry(win.dataset, nr)
				d._is_nodata = nil
				d.id = id
				d.sourceGUID = player.sourceGUID
				d.sourceCreatureID = player.sourceCreatureID
				d.label = playerName
				d.class = SecretHelper:GetPlayerClass(player)
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
	if type(set) ~= "table" then return end

	local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
	if type(view) ~= "table" then return end

	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return end

	local valueKey = options.valueKey or "totalAmount"

	-- Detect secrets (using cached detection)
	local cacheKey = "simplelist_" .. tostring(set.sessionType or 0) .. "_" .. tostring(options.damageType)
	local hasSecretValues = SecretHelper:DetectSecretsCached(cacheKey, sources, valueKey)

	-- Update window metadata
	SecretHelper:UpdateWindowMetadata(win, hasSecretValues)

	local max = 0
	local nr = 1
	local sourceCount = 0
	for _, player in ipairs(sources) do
		if type(player) == "table" and not issecretvalue(player) then
			sourceCount = sourceCount + 1
		end
	end

	if hasSecretValues then
		-- SLOW PATH
		for _, player in ipairs(sources) do
			if type(player) == "table" and not issecretvalue(player) then
				local rawValue = player[valueKey]
				if type(rawValue) == "nil" then
					rawValue = player.totalAmount
				end

				if type(rawValue) ~= "nil" then
					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = "combat_" .. nr
					d.sourceGUID = player.sourceGUID
					d.sourceCreatureID = player.sourceCreatureID
					d.label = SecretHelper:GetPlayerLabel(player, nr)
					d.class = SecretHelper:GetPlayerClass(player)
					d.role = player.role
					d.order = nr
					d.value = SecretHelper:GetDisplayValue(rawValue, nr, sourceCount)
					d.valuetext = Skada:FormatNumberSecret(rawValue)
					nr = nr + 1
				end
			end
		end
	else
		-- FAST PATH
		for _, player in ipairs(sources) do
			if type(player) == "table" then
				local playerName = player.name
				if type(playerName) ~= "string" then
					playerName = player.unitName
				end
				if type(playerName) ~= "string" then
					playerName = "Combat " .. nr
				end

				local value = player[valueKey]
				if type(value) == "nil" then
					value = player.totalAmount
				end
				value = tonumber(value) or 0

				if value > 0 then
					local guid = player.sourceGUID
					local id
					if type(guid) == "string" and not issecretvalue(guid) then
						id = guid
					else
						id = "player_" .. nr
					end

					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = id
					d.sourceGUID = player.sourceGUID
					d.sourceCreatureID = player.sourceCreatureID
					d.label = playerName
					d.class = SecretHelper:GetPlayerClass(player)
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

	win.metadata.maxvalue = hasSecretValues and SecretHelper:GetMaxValue(true, 0, sourceCount) or max
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

	local sourceGUID = win._drillSourceGUID
	local sourceCreatureID = win._drillSourceCreatureID
	local hasDirectSource = type(sourceGUID) ~= "nil" or type(sourceCreatureID) ~= "nil"
	local view, player

	if not hasDirectSource then
		view = Skada.NativeAPI:GetSessionView(set, damageType)
		player = Skada:find_player_in_session(view, playerid)
		if type(player) ~= "table" then
			player = Skada:find_player(set, playerid)
		end
		if type(player) ~= "table" then return end
	end

	local realID
	if hasDirectSource then
		realID = sourceGUID
	else
		realID = SecretHelper:GetPlayerID(player, playerid)
	end
	local viewSet
	if type(view) ~= "nil" then viewSet = view else viewSet = set end
	local spells = Skada.NativeAPI:GetPlayerSpells(realID, viewSet, damageType, sourceCreatureID)


	if type(spells) == "nil" then
		return
	end

	-- If the spells collection itself is a secret value, we cannot iterate
	-- it with pairs() or index it.
	if issecretvalue(spells) then
		local d = self:ReuseDatasetEntry(win.dataset, 1)
		d._is_nodata = nil
		d.id = "secret_spells"
		d.label = L["Spell details available after combat"]
		d.value = 1
		d.valuetext = "?"
		win.metadata.maxvalue = 1
		return
	end

	-- Detect secrets and calculate total (using cached detection)
	local sessionType = 0
	if type(set) == "table" and not issecretvalue(set) then
		sessionType = set.sessionType or 0
	end
	local cacheKey = "spelllist_" .. tostring(sessionType) .. "_" .. tostring(damageType)
	local hasSecretValues = SecretHelper:DetectSecretsCached(cacheKey, spells, valueKey)

	-- Calculate total (only for non-secrets)
	local totalValue = 0
	if not hasSecretValues then
		for _, spell in ipairs(spells) do
			if type(spell) == "table" then
				local value = spell[valueKey]
				if type(value) == "number" then
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
		for _, spell in ipairs(spells) do
			if type(spell) == "table" and not issecretvalue(spell) then
				local rawValue = spell[valueKey]
				local isSecret = issecretvalue(rawValue)
				local isNonZeroNumber = false

				if not isSecret then
					isNonZeroNumber = (type(rawValue) == "number") and (rawValue ~= 0)
				end

				if isSecret or isNonZeroNumber then
					local rawSpellID = spell.spellID
					local secretSpellID = issecretvalue(rawSpellID)
					local plainSpellID
					if not secretSpellID and type(rawSpellID) == "number" then
						plainSpellID = rawSpellID
					end

					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					-- A secret value cannot be a table key. Use a stable synthetic
					-- id and keep the real id only when it is safe to read.
					d.id = "spell_" .. nr
					d.spellid = nil

					local spellName
					if secretSpellID then
						local ok, name = pcall(function() return C_Spell.GetSpellName(rawSpellID) end)
						if ok and type(name) == "string" then spellName = name end
						local okInfo, info = pcall(function() return C_Spell.GetSpellInfo(rawSpellID) end)
						if type(spellName) ~= "string" and okInfo and type(info) == "table" then
							spellName = info.name
						end
					elseif plainSpellID and plainSpellID > 0 then
						local info = C_Spell.GetSpellInfo(plainSpellID)
						spellName = info and info.name
						d.id = plainSpellID
						d.spellid = plainSpellID
					end
					if type(spellName) == "string" then
						d.label = spellName
					else
						d.label = "Spell " .. tostring(nr)
					end

					d.value = SecretHelper:GetDisplayValue(rawValue, nr, #spells)
					d.valuetext = Skada:FormatNumberSecret(rawValue)
					d.icon = Skada:GetSpellIcon(rawSpellID)
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = SecretHelper:GetMaxValue(true, 0, #spells)
	else
		-- FAST PATH
		for _, spell in ipairs(spells) do
			if type(spell) == "table" then
				local value = tonumber(spell[valueKey]) or 0
				if value ~= 0 then
					local spellID = 0
					if type(spell.spellID) == "number" then
						spellID = spell.spellID
					end

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
	if type(set) ~= "table" then return 0 end

	options = options or {}
	local valueKey = options.valueKey or "totalAmount"
	local sourcesKey = options.sourcesKey or "combatSources"

	local view = Skada.NativeAPI:GetSessionView(set, damageType)
	if type(view) ~= "table" then return 0 end

	local total = 0
	local sources = view[sourcesKey]
	if type(sources) ~= "table" then
		sources = view.combatSources
	end
	if type(sources) ~= "table" or issecretvalue(sources) then return 0 end

	for _, p in ipairs(sources) do
		if type(p) == "table" and not issecretvalue(p) then
			local value = p[valueKey]
			if type(value) == "nil" then
				value = p.totalAmount
			end
			if type(value) ~= "nil" then
				if issecretvalue(value) then
					return value -- Return secret value if found
				end
				total = total + (tonumber(value) or 0)
			end
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
		if type(set) ~= "table" then return end

		local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
		if type(view) ~= "table" then return end

		-- Resolve player (crucial for artificial IDs)
		local player = Skada:find_player_in_session(view, id)
		if type(player) ~= "table" then
			player = Skada:find_player(set, id)
		end

		if type(player) ~= "table" then return end

		local totaltime = Skada:GetSetTime(view)
		local rawValue = player[options.valueKey]
		if type(rawValue) == "nil" then
			rawValue = player.totalAmount
		end
		local rawRate = player[options.rateKey]
		if type(rawRate) == "nil" then
			rawRate = player.amountPerSecond
		end

		local playerName = label
		local rawName = player.name
		if type(rawName) == "string" and not issecretvalue(rawName) then
			playerName = rawName
		end
		if issecretvalue(playerName) then
			-- Pass the secret name directly to the FontString-backed tooltip;
			-- string.format/tostring would erase it.
			local ok = pcall(tooltip.AddLine, tooltip, playerName)
			if not ok then tooltip:AddLine("?") end
			tooltip:AddLine(tostring(options.labelRate))
		else
			playerName = playerName or "?"
			tooltip:AddLine(string.format("%s - %s", tostring(playerName), tostring(options.labelRate)))
		end
		tooltip:AddDoubleLine(L["Segment time"], string.format("%s s", Skada:FormatNumberSecret(totaltime)), 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(options.labelDamage, Skada:FormatNumberSecret(rawValue), 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(options.labelRate, Skada:FormatNumberSecret(rawRate), 1, 1, 1, 1, 1, 1)

		-- Add top spells (unavailable while the spell collection is secret)
		local realID = SecretHelper:GetPlayerID(player, id)
		local spells = Skada.NativeAPI:GetPlayerSpells(realID, view, options.damageType)
		if type(spells) == "table" and not issecretvalue(spells) then
			local sorted = {}
			local spellValueKey = options.spellValueKey or "totalAmount"

			for _, s in ipairs(spells) do
				if type(s) == "table" and not issecretvalue(s) then
					local rawAmount = s[spellValueKey]
					if type(rawAmount) ~= "nil" then
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
					local spellID = 0
					if type(s.spellID) == "number" then
						spellID = s.spellID
					end
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					local name = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))

					local rawVal = s[spellValueKey]
					if issecretvalue(rawVal) then
						tooltip:AddDoubleLine(name, Skada:FormatNumberSecret(rawVal), 1, 1, 1, 1, 1, 1)
					elseif type(rawVal) ~= "nil" then
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

--[[
	Create a simple tooltip handler without top spells
	
	@param labelTotal: Label for total line
	@return function - Tooltip handler
]]
function ModuleBase:CreateSimpleTooltip(labelTotal)
	return function(win, id, label, tooltip)
		local set = win:get_selected_set()
		if type(set) ~= "table" then return end

		local player = Skada:find_player(set, id)
		if type(player) == "table" then
			local rawValue = player.totalAmount
			if type(rawValue) ~= "nil" then
				tooltip:AddDoubleLine(labelTotal, Skada:FormatNumberSecret(rawValue), 1, 1, 1, 1, 1, 1)
			end
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
		if type(set) ~= "table" then return end

		local player = Skada:find_player(set, id)
		if type(player) ~= "table" then return end

		local rawPlayerValue = player.totalAmount
		if issecretvalue(rawPlayerValue) then
			return
		end

		local playerValue = tonumber(rawPlayerValue) or 0
		local totalValue = 0

		local view = Skada.NativeAPI:GetSessionView(set, options.damageType)
		if type(view) == "table" then
			local sources = view.combatSources
			if type(sources) == "table" then
				for _, p in ipairs(sources) do
					if type(p) == "table" and not issecretvalue(p) then
						totalValue = totalValue + SecretHelper:SafeNumber(p.totalAmount)
					end
				end
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
		local set = Skada:GetActiveSet()
		if type(set) == "table" then
			local player = Skada:find_player(set, UnitGUID("player"))
			if type(player) == "table" then
				local rate = self:GetPlayerRate(set, player, rateType)
				-- Use string.format to avoid concatenation crimes with secret values
				return string.format("%s %s", Skada:FormatNumberSecret(rate), label or "")
			end
		end
	end)

	Skada:AddFeed(feedNameRaid, function()
		local set = Skada:GetActiveSet()
		if type(set) == "table" then
			local rate = self:GetRaidRate(set, rateType)
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
