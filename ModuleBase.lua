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
					d.source = player
					d.isLocalPlayer = player.isLocalPlayer
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
				d.source = player
				d.isLocalPlayer = player.isLocalPlayer
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
					d.source = player
					d.isLocalPlayer = player.isLocalPlayer
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
					d.source = player
					d.isLocalPlayer = player.isLocalPlayer
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
local function showSpellPlaceholder(win, message)
	local d = ModuleBase:ReuseDatasetEntry(win.dataset, 1)
	d._is_nodata = nil
	d.id = "spell_placeholder"
	d.label = message
	d.value = 0
	d.valuetext = ""
	d.ignore = true
	d.icon = nil
	d.spellid = nil
	d.class = nil
	d.role = nil
	d.color = nil
	d.spellDetails = nil
	d.target = nil
	d.overkill = nil
	d.avoidable = nil
	d.deadly = nil
	win.metadata.maxvalue = 1
end

function ModuleBase:GetDrillSpells(win, playerid, set, damageType)
	local sourceGUID = win._drillSourceGUID
	local sourceCreatureID = win._drillSourceCreatureID
	local source = win._drillSource
	if win._drillIsLocalPlayer then
		local playerGUID = UnitGUID("player")
		if type(playerGUID) == "string" and not issecretvalue(playerGUID) then
			sourceGUID = playerGUID
			sourceCreatureID = nil
		end
	end
	if type(source) == "table" and not issecretvalue(source) then
		local direct = Skada.NativeAPI:GetSpellsFromSource(source)
		-- A restricted collection cannot be read. Fall through to a fresh
		-- source query, which can still return plain spell data in combat.
		if type(direct) == "table" and not issecretvalue(direct) then
			return direct
		end
	end

	local hasDirectSource = type(sourceGUID) ~= "nil" or type(sourceCreatureID) ~= "nil"
	local view = Skada.NativeAPI:GetSessionView(set, damageType)
	local player = Skada:find_player_in_session(view, playerid)
	if type(player) ~= "table" then
		player = Skada:find_player(set, playerid)
	end
	if not hasDirectSource and type(player) ~= "table" then
		return nil
	end

	local realID
	if hasDirectSource then
		realID = sourceGUID
	else
		realID = SecretHelper:GetPlayerID(player, playerid)
	end
	return Skada.NativeAPI:GetPlayerSpells(realID, view or set, damageType, sourceCreatureID)
end

-- Resolve a spell name without comparing or indexing a secret spell ID.
-- The returned name may itself be a secret string during combat; callers must
-- pass it straight to a FontString and must not compare or concatenate it.
local function spellNameFromID(spellID)
	if type(spellID) ~= "number" then return nil end
	if issecretvalue(spellID) then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(name) == "string" then return name end
		local okInfo, info = pcall(C_Spell.GetSpellInfo, spellID)
		if okInfo and type(info) == "table" and not issecretvalue(info) then
			local infoName = info.name
			if type(infoName) == "string" then return infoName end
		end
		return nil
	end
	if spellID <= 0 then return nil end
	local info = C_Spell.GetSpellInfo(spellID)
	if type(info) == "table" and not issecretvalue(info) then
		local name = info.name
		if type(name) == "string" then return name end
	end
	return nil
end

local function spellTargetDetails(spell)
	if type(spell) ~= "table" or issecretvalue(spell) then return nil end
	local details = spell.combatSpellDetails
	if type(details) ~= "table" or issecretvalue(details) then return nil end
	if details.unitName ~= nil or details.amount ~= nil then
		return details
	end
	local first = details[1]
	if type(first) == "table" and not issecretvalue(first) then
		return first
	end
	return nil
end

local function plainName(value)
	if type(value) == "string" and not issecretvalue(value) and value ~= "" then
		return value
	end
	return nil
end

local function spellTargetName(spell, details)
	if type(spell) ~= "table" or issecretvalue(spell) then spell = nil end
	if type(details) ~= "table" or issecretvalue(details) then details = nil end
	return (details and plainName(details.unitName))
		or (details and plainName(details.name))
		or (spell and plainName(spell.unitName))
		or (spell and plainName(spell.creatureName))
end

function ModuleBase:CreateSourceTooltip(options)
	return function(win, id, label, tooltip)
		local source = win._hoverSource
		if label ~= nil then
			local ok = pcall(tooltip.AddLine, tooltip, label)
			if not ok then tooltip:AddLine("?") end
		end
		if type(source) == "table" and not issecretvalue(source) then
			local value = source[options.valueKey or "totalAmount"]
			local rate = source[options.rateKey or "amountPerSecond"]
			if value ~= nil then
				tooltip:AddDoubleLine(options.labelDamage or "Total", Skada:FormatNumberSecret(value), 1,1,1,1,1,1)
			end
			if rate ~= nil and options.labelRate then
				tooltip:AddDoubleLine(options.labelRate, Skada:FormatNumberSecret(rate), 1,1,1,1,1,1)
			end
		end
	end
end

function ModuleBase:CreateTargetTooltip()
	return function(win, id, label, tooltip)
		local data = win._hoverSpell
		if data == nil then return end
		local text = data.label
		if text ~= nil then
			local ok = pcall(tooltip.AddLine, tooltip, text)
			if not ok then tooltip:AddLine("?") end
		end
		local value = data.valuetext
		if value ~= nil then
			local ok = pcall(tooltip.AddDoubleLine, tooltip, L["Amount"], value, 1,1,1,1,1,1)
			if not ok then tooltip:AddLine(L["Amount"]) end
		end
	end
end

function ModuleBase:CreateSpellTooltip()
	return function(win, id, label, tooltip)
		local data = win._hoverSpell
		if not data then return end
		if data.target ~= nil then
			tooltip:AddLine(L["Target"])
			local ok = pcall(tooltip.AddLine, tooltip, data.target)
			if not ok then tooltip:AddLine("?") end
		end
		local overkill = data.overkill
		if overkill ~= nil and not issecretvalue(overkill) and overkill ~= 0 then
			tooltip:AddDoubleLine(L["Overkill"], Skada:FormatNumber(overkill), 1, 1, 1, 1, 1, 1)
		elseif issecretvalue(overkill) then
			local ok = pcall(tooltip.AddDoubleLine, tooltip, L["Overkill"], Skada:FormatNumberSecret(overkill), 1, 1, 1, 1, 1, 1)
			if not ok then tooltip:AddLine(L["Overkill"]) end
		end
		if data.avoidable ~= nil and not issecretvalue(data.avoidable) and data.avoidable then
			tooltip:AddLine(L["Avoidable damage"], 1, 0.4, 0.4)
		end
		if data.deadly ~= nil and not issecretvalue(data.deadly) and data.deadly then
			tooltip:AddLine(L["Deadly"], 1, 0.2, 0.2)
		end
	end
end

--[[
	Damage done sources only carry combatSpellDetails.unitName for some
	damage types; for player DamageDone the field is empty. Enemy damage taken
	sources, on the other hand, keep their own combatSpells collection whose
	details name the player who dealt the damage. This reverses that mapping so
	a player's target list can be built after combat.

	The enemy source object is read directly whenever possible. That is the same
	object the Enemy damage taken bar drills into, so it also works for
	creature-ID-only sources where a fresh source query can come back empty.
]]
local function collectReverseRows(view, playerName)
	local rows = {}
	if type(view) ~= "table" or issecretvalue(view) then return rows end
	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return rows end
	for _, enemy in ipairs(sources) do
		if type(enemy) == "table" and not issecretvalue(enemy) then
			local spells = Skada.NativeAPI:GetSpellsFromSource(enemy)
			if type(spells) ~= "table" or issecretvalue(spells) then
				spells = Skada.NativeAPI:GetPlayerSpells(enemy.sourceGUID, view, 10, enemy.sourceCreatureID)
			end
			if type(spells) == "table" and not issecretvalue(spells) then
				local total = 0
				for _, spell in ipairs(spells) do
					local details = spellTargetDetails(spell)
					if spellTargetName(spell, details) == playerName then
						local amount = details and details.amount
						if issecretvalue(amount) then
							amount = nil
						elseif type(amount) ~= "number" or amount == 0 then
							amount = spell.totalAmount
						end
						if type(amount) == "number" and not issecretvalue(amount) then
							total = total + amount
						end
					end
				end
				if total > 0 then
					rows[#rows + 1] = {
						label = enemy.name,
						value = total,
						class = enemy.classFilename,
						icon = nil,
						order = #rows + 1,
					}
				end
			end
		end
	end
	return rows
end

function ModuleBase:GetReversePlayerTargets(player, set)
	if type(player) ~= "table" or issecretvalue(player) then return nil end
	local playerName = player.name
	if type(playerName) ~= "string" or issecretvalue(playerName) or playerName == "" then
		playerName = player.unitName
	end
	if type(playerName) ~= "string" or issecretvalue(playerName) or playerName == "" then
		return nil
	end

	local rows = collectReverseRows(Skada.NativeAPI:GetSessionView(set, 10), playerName)
	if #rows > 0 then return rows end

	-- The selected segment can be Total or a historical session whose
	-- EnemyDamageTaken view is empty or unavailable. Current and expired
	-- sessions still carry the same player-to-mob mapping.
	for _, sessionType in ipairs({1, 2}) do
		local fallback = Skada.NativeAPI:GetSessionByParams(sessionType, 10)
		if type(fallback) == "table" and fallback ~= set then
			rows = collectReverseRows(fallback, playerName)
			if #rows > 0 then return rows end
		end
	end
	return nil
end

--[[
	Collect plain target names for a player source. Direct spell details are
	preferred; player DamageDone has none, so the reverse enemy lookup fills in.
]]
function ModuleBase:GetTargetNames(player, set, damageType)
	local names, seen = {}, {}
	local function add(value)
		if type(value) == "string" and not issecretvalue(value) and value ~= "" and not seen[value] then
			seen[value] = true
			names[#names + 1] = value
		end
	end
	if type(player) ~= "table" or issecretvalue(player) then return names end

	local spells = Skada.NativeAPI:GetSpellsFromSource(player)
	if type(spells) ~= "table" or issecretvalue(spells) then
		spells = Skada.NativeAPI:GetPlayerSpells(player.sourceGUID, set, damageType)
	end
	if type(spells) == "table" and not issecretvalue(spells) then
		for _, spell in ipairs(spells) do
			if type(spell) == "table" and not issecretvalue(spell) then
				add(spellTargetName(spell, spell.combatSpellDetails))
			end
		end
	end
	if #names == 0 then
		local rows = self:GetReversePlayerTargets(player, set)
		if rows then
			for _, row in ipairs(rows) do add(row.label) end
		end
	end
	return names
end

function ModuleBase:UpdateTargetList(win, playerid, set, damageType, options)
	options = options or {}
	local spells = self:GetDrillSpells(win, playerid, set, damageType)
	local rows = {}
	local map = {}
	local max = 0
	local nr = 1

	local reverseRows
	local function getReverseRows()
		if reverseRows == nil then
			reverseRows = self:GetReversePlayerTargets(win._drillSource, set) or false
		end
		return reverseRows or nil
	end

	if type(spells) ~= "table" or issecretvalue(spells) then
		rows = getReverseRows() or rows
		if #rows == 0 then
			showSpellPlaceholder(win, InCombatLockdown() and L["Spell details available after combat"] or L["No target data recorded"])
			return
		end
		for _, row in ipairs(rows) do
			if type(row.value) == "number" and row.value > max then max = row.value end
		end
	else
		for _, spell in ipairs(spells) do
			local details = spellTargetDetails(spell)
			if details then
				local target = spellTargetName(spell, details)
				local amount = details.amount
				if not issecretvalue(amount) then
					if amount == nil or (type(amount) == "number" and amount == 0) then
						amount = spell.totalAmount
					end
					if not issecretvalue(amount)
						and (amount == nil or (type(amount) == "number" and amount == 0))
						and #spells == 1 and win._drillSource and not issecretvalue(win._drillSource) then
						amount = win._drillSource.totalAmount
					end
				end
				if target ~= nil then
					local targetClass
					local rawClass = details.unitClassFilename
					if type(rawClass) == "string" and not issecretvalue(rawClass) and RAID_CLASS_COLORS[rawClass] then
						targetClass = rawClass
					end
					local targetIcon
					if type(details.specIconID) == "number" and not issecretvalue(details.specIconID) then
						targetIcon = details.specIconID
					end
					if not issecretvalue(target) and not issecretvalue(amount) and type(amount) == "number" then
						local row = map[target]
						if not row then
							row = {
								label = target,
								value = 0,
								class = targetClass,
								icon = targetIcon,
								order = nr,
							}
							map[target] = row
							rows[#rows + 1] = row
						end
						row.value = row.value + amount
						if row.value > max then max = row.value end
					else
						rows[#rows + 1] = {
							label = target,
							value = SecretHelper:GetDisplayValue(amount, nr, #spells),
							valuetext = Skada:FormatNumberSecret(amount),
							class = targetClass,
							icon = targetIcon,
							order = nr,
						}
					end
					nr = nr + 1
				end
			end
		end

		if #rows == 0 then
			rows = getReverseRows() or rows
			for _, row in ipairs(rows) do
				if type(row.value) == "number" and row.value > max then max = row.value end
			end
		end
	end

	if #rows == 0 then
		showSpellPlaceholder(win, InCombatLockdown() and L["Spell details available after combat"] or L["No target data recorded"])
		return
	end

	for i, row in ipairs(rows) do
		local d = self:ReuseDatasetEntry(win.dataset, i)
		d._is_nodata = nil
		d.id = "target_" .. i
		d.label = row.label
		d.value = row.value
		d.order = row.order
		d.class = row.class
		d.icon = row.icon
		d.spellid = nil
		d.link = nil
		d.ignore = nil
		if row.valuetext then
			d.valuetext = row.valuetext
		elseif issecretvalue(row.value) then
			d.valuetext = Skada:FormatNumberSecret(row.value)
		else
			d.valuetext = Skada:FormatNumber(row.value)
		end
	end
	win.metadata.maxvalue = max > 0 and max or (#rows > 0 and #rows or 1)
end

function ModuleBase:UpdateSpellList(win, playerid, set, damageType, options)
	options = options or {}
	local valueKey = options.valueKey or "totalAmount"

	local spells = self:GetDrillSpells(win, playerid, set, damageType)


	if type(spells) == "nil" then
		showSpellPlaceholder(win, InCombatLockdown() and L["Spell details available after combat"] or L["No spell data recorded"])
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

					local spellName = spellNameFromID(rawSpellID)
					if not secretSpellID and plainSpellID and plainSpellID > 0 then
						d.id = plainSpellID
						d.spellid = plainSpellID
					end
					local details = spellTargetDetails(spell)
					local target = spellTargetName(spell, details)
					d.spellDetails = details
					d.target = target
					d.overkill = spell.overkillAmount
					d.avoidable = spell.isAvoidable
					d.deadly = spell.isDeadly
					if type(spellName) == "string" then
						if not issecretvalue(spellName)
							and type(target) == "string" and not issecretvalue(target) and target ~= "" then
							d.label = spellName .. " - " .. target
						else
							d.label = spellName
						end
					else
						d.label = "Spell " .. tostring(nr)
					end

					d.value = SecretHelper:GetDisplayValue(rawValue, nr, #spells)
					d.valuetext = Skada:FormatNumberSecret(rawValue)
					local icon = Skada:GetSpellIcon(rawSpellID)
					if icon ~= nil and not issecretvalue(icon) then d.icon = icon end
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
					local spellIDIsSecret = false
					if type(spell.spellID) == "number" then
						if issecretvalue(spell.spellID) then
							spellIDIsSecret = true
						else
							spellID = spell.spellID
						end
					end

					local d = self:ReuseDatasetEntry(win.dataset, nr)
					d._is_nodata = nil
					d.id = spellID

					local baseName = spellNameFromID(spellID)
					if type(baseName) ~= "string" then
						baseName = spellIDIsSecret and L["Spell"] or ("Spell " .. tostring(spellID))
					end
					local details = spellTargetDetails(spell)
					local target = spellTargetName(spell, details)
					d.spellDetails = details
					d.target = target
					d.overkill = spell.overkillAmount
					d.avoidable = spell.isAvoidable
					d.deadly = spell.isDeadly
					if type(target) == "string" and not issecretvalue(target) and target ~= "" then
						d.label = baseName .. " - " .. target
					else
						d.label = baseName
					end

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

	if nr == 1 then
		showSpellPlaceholder(win, InCombatLockdown() and L["Spell details available after combat"] or L["No spell data recorded"])
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

		if type(player) ~= "table" then player = win._hoverSource end
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

		-- Add top spells. Prefer the source object from the hovered bar; fall
		-- back to the native query with the local player's plain unit GUID.
		local spells = win._hoverSource and Skada.NativeAPI:GetSpellsFromSource(win._hoverSource)
		if spells == nil then
			local realID
			if win._hoverIsLocalPlayer then
				realID = UnitGUID("player")
			end
			if type(realID) ~= "string" or issecretvalue(realID) then
				realID = SecretHelper:GetPlayerID(player, id)
			end
			spells = Skada.NativeAPI:GetPlayerSpells(realID, view, options.damageType)
		end
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
					local spellIDIsSecret = false
					if type(s.spellID) == "number" then
						if issecretvalue(s.spellID) then
							spellIDIsSecret = true
						else
							spellID = s.spellID
						end
					end
					local name = spellNameFromID(spellID)
					if type(name) ~= "string" then
						name = spellIDIsSecret and L["Spell"] or ("Spell " .. tostring(spellID))
					end
					local details = s.combatSpellDetails
					local target = spellTargetName(s, details)
					if not issecretvalue(name)
						and type(target) == "string" and not issecretvalue(target) and target ~= "" then
						name = name .. " - " .. target
					end

					local rawVal = s[spellValueKey]
					local right
					if issecretvalue(rawVal) then
						right = Skada:FormatNumberSecret(rawVal)
					elseif type(rawVal) ~= "nil" then
						local val = tonumber(rawVal) or 0
						local playerVal = SecretHelper:SafeNumber(rawValue)
						local percent = playerVal > 0 and (val / playerVal) * 100 or 0
						right = Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")"
					end
					if type(right) == "string" then
						if issecretvalue(name) or issecretvalue(right) then
							local ok = pcall(tooltip.AddDoubleLine, tooltip, name, right, 1, 1, 1, 1, 1, 1)
							if not ok then pcall(tooltip.AddLine, tooltip, name) end
						else
							tooltip:AddDoubleLine(name, right, 1, 1, 1, 1, 1, 1)
						end
					end
				end
			end
		end

		-- Target names are useful on their own when the top-spell section is
		-- empty or when the spell collection is otherwise restricted. Player
		-- DamageDone data has no target names, so the helper falls back to the
		-- reverse lookup through Enemy damage taken.
		local names = ModuleBase:GetTargetNames(player, set, options.damageType)
		if #names > 0 then
			tooltip:AddLine(" ")
			tooltip:AddLine(L["Targets"])
			for i = 1, math.min(3, #names) do
				local ok = pcall(tooltip.AddLine, tooltip, names[i])
				if not ok then tooltip:AddLine("?") end
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
