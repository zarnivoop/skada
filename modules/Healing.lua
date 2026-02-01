local _, Skada = ...
Skada:AddLoadableModule("Healing", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Healing then return end

	local mod = Skada:NewModule(L["Healing"])
	local playermod = Skada:NewModule(L["Healing spell list"])
	local hpsmod = Skada:NewModule(L["HPS"])

	local pairs = pairs
	local ipairs = ipairs

	local function getSetTotal(set)
		if not set then return 0 end
		-- 2 = Healing
		local view = Skada.NativeAPI:GetSessionView(set, 2)
		if not view then return 0 end
		
		local total = 0
		local sources = view.combatSources or view.participants or {}
		for _, p in pairs(sources) do
			total = total + Skada:SafeNumber(p.totalAmount)
		end
		return total
	end

	local function getHPS(set, player)
		-- Use API HPS (type 3 = Hps)
		return Skada.NativeAPI:GetPlayerRate(set, player, 3)
	end

	local function getRaidHPS(set)
		-- Use API HPS (type 3 = Hps)
		return Skada.NativeAPI:GetRaidRate(set, 3)
	end
	
	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Healing"]
	end

	function playermod:Update(win, set)
		-- 2 = Healing
		local spells = Skada.NativeAPI:GetPlayerSpells(self.playerid, set, 2)
		if not spells then return end
		
		local max = 0
		local nr = 1
		local totalHealing = 0
		
		-- Calculate total first for percentage
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				totalHealing = totalHealing + Skada:SafeNumber(spell.totalAmount)
			end
		end
		
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				local amount = Skada:SafeNumber(spell.totalAmount)
				
				if amount > 0 then
					local spellID = spell.spellID or 0
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.id = spellID
					
					-- Get spell name from spellID
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					d.label = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))
					
					d.value = amount
					d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalHealing) * 100)
					d.icon = Skada:GetSpellIcon(spellID)
					
					if amount > max then
						max = amount
					end
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = max
	end

	-- Healing overview.
	function mod:Update(win, set)
		-- 2 = Healing
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if not healingSet then return end
		
		-- Use API participants/sources
		local sources = healingSet.combatSources or healingSet.participants or {}
		
		local max = 0
		local nr = 1
		
		-- Calculate Set Total Healing on the fly (if API doesn't provide it conveniently in the list)
		local setTotalHealing = 0
		for _, p in pairs(sources) do
			local amount = Skada:SafeNumber(p.healing or p.totalAmount)
			setTotalHealing = setTotalHealing + amount
		end
		healingSet.healing = setTotalHealing -- Cache it for getRaidHPS

		for i, player in pairs(sources) do
			-- API returns a map or list, pairs works for both
			local amount = Skada:SafeNumber(player.totalAmount or 0)
			
			if amount > 0 then
				local hps = getHPS(healingSet, player)
				
				-- Normalize player name/id
				local playerName = player.name or player.unitName
				local playerID = player.sourceGUID or player.guid or player.unitGUID

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = playerName

				Skada:FormatValueText(d,
					Skada:FormatNumber(amount), self.metadata.columns.Healing,
					Skada:FormatNumber(hps), self.metadata.columns.HPS,
					string.format("%02.1f%%", amount / math.max(1, setTotalHealing) * 100), self.metadata.columns.Percent
				)

				d.value = amount
				d.id = playerID
				d.class = player.class or player.classFilename
				d.role = player.role -- API might not have this, might need fallback
				if amount > max then
					max = amount
				end
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	-- Tooltip for a specific player.
		local function hps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		
		-- Use Skada:find_player which handles Native API sessions
		local player = Skada:find_player(set, id)
		if not player then return end
		
		-- 2 = Healing - get healing-specific session view
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if not healingSet then return end
		
		local totaltime = Skada:GetSetTime(healingSet)
		local amount = Skada:SafeNumber(player.totalAmount or 0)
		local hps = Skada:SafeNumber(player.amountPerSecond or 0)
		
		tooltip:AddLine((player.name or label).." - "..L["HPS"])
		tooltip:AddDoubleLine(L["Segment time"], totaltime.."s", 1,1,1,1,1,1)
		tooltip:AddDoubleLine(L["Healing done"], Skada:FormatNumber(amount), 1,1,1,1,1,1)
		tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(hps), 1,1,1,1,1,1)
		
		-- Add top 3 spells
		-- 2 = Healing
		local spells = Skada.NativeAPI:GetPlayerSpells(id, healingSet, 2)
		if spells then
			local sorted = {}
			for _, s in pairs(spells) do
				if type(s) == "table" and s.totalAmount then
					table.insert(sorted, s)
				end
			end
			table.sort(sorted, function(a, b) 
				local aVal = Skada:SafeNumber(a.totalAmount or 0)
				local bVal = Skada:SafeNumber(b.totalAmount or 0)
				return aVal > bVal
			end)
			
			if #sorted > 0 then
				tooltip:AddLine(" ")
				tooltip:AddLine(L["Top Spells"])
				for i = 1, math.min(3, #sorted) do
					local s = sorted[i]
					local spellID = s.spellID or 0
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					local name = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))
					local val = Skada:SafeNumber(s.totalAmount or 0)
					local percent = amount > 0 and (val / amount) * 100 or 0
					tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1,1,1,1,1,1)
				end
			end
		end
	end

	-- Tooltip for a specific spell (in spell list)
	local function spell_tooltip(win, id, label, tooltip)
		local playerID = playermod.playerid
		if not playerID then return end

		local set = win:get_selected_set()
		if not set then return end
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if not healingSet then return end

		-- 2 = Healing
		local spellData = Skada.NativeAPI:GetPlayerSpell(playerID, healingSet, 2, id)

		if spellData then
			local amount = spellData.totalAmount or 0
			tooltip:AddLine(label .. " (" .. L["Healing"] .. ")")
			tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(amount), 1,1,1)
			
			if spellData.hitCount then 
				tooltip:AddDoubleLine(L["Hits"], spellData.hitCount, 1,1,1) 
			end
			if spellData.critCount then 
				tooltip:AddDoubleLine(L["Crits"], spellData.critCount, 1,1,1) 
			end
			if spellData.tickCount then
				tooltip:AddDoubleLine(L["Ticks"], spellData.tickCount, 1,1,1)
			end
		end
	end

	-- HPS-only view
	function hpsmod:FormatSetSummary(datasetItem, set)
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if healingSet then
			Skada:FormatValueText(datasetItem, Skada:FormatNumber(getRaidHPS(healingSet)), true)
		end
	end

	function hpsmod:Update(win, set)
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if not healingSet then return end
		
		local sources = healingSet.combatSources or {}
		local max = 0

		local nr = 1

		for i, player in pairs(sources) do
			local amount = Skada:SafeNumber(player.totalAmount or 0)
			
			if amount > 0 then
				local hps = getHPS(healingSet, player)
				
				-- Normalize player name/id
				local playerName = player.name or player.unitName
				local playerID = player.sourceGUID

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = playerName
				d.id = playerID
				d.value = Skada:SafeNumber(hps)
				d.class = player.class or player.classFilename
				d.role = player.role
				d.valuetext = Skada:FormatNumber(hps)
				if hps > max then
					max = hps
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:OnEnable()
		playermod.metadata = {} -- Remove tooltip for spell list
		hpsmod.metadata = {showspots = true, tooltip = hps_tooltip, icon = "Interface\\Icons\\spell_nature_healingtouch"}
		mod.metadata = {click1 = playermod, showspots = true, columns = {Healing = true, HPS = true, Percent = true}, icon = "Interface\\Icons\\spell_nature_healingtouch"}

		-- Note: In WoW 12.0.0+, we don't register combat log events
		-- Data comes from NativeAPI polling instead

		Skada:AddFeed(L["Healing: Personal HPS"], function()
			if Skada.current then
				local player = Skada:find_player_in_session(Skada.current, UnitGUID("player"))
				if player then
					return Skada:FormatNumber(getHPS(Skada.current, player)).." "..L["HPS"]
				end
			end
		end)
		Skada:AddFeed(L["Healing: Raid HPS"], function()
			if Skada.current then
				return Skada:FormatNumber(getRaidHPS(Skada.current)).." "..L["RHPS"]
			end
		end)
		Skada:AddMode(self, L["Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
	end

	function hpsmod:OnEnable()
		Skada:AddMode(self, L["Healing"])
	end

	function hpsmod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		GameTooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(getRaidHPS(set)), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		local total = getSetTotal(set)
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumber(total), self.metadata.columns.Healing,
			Skada:FormatNumber(getRaidHPS(set)), self.metadata.columns.HPS
		)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
		-- No longer needed with Native API
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
		-- No longer needed with Native API
	end
end)
