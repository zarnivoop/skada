local _, Skada = ...
Skada:AddLoadableModule("DamageTaken", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.DamageTaken then return end

	local mod = Skada:NewModule(L["Damage taken"])
	local playermod = Skada:NewModule(L["Damage taken details"])





	local function getSetTotal(set)
		if not set then return 0 end
		-- 7 = DamageTaken
		local view = Skada.NativeAPI:GetSessionView(set, 7)
		if not view then return 0 end
		
		local total = 0
		local sources = view.combatSources or {}
		for _, p in pairs(sources) do
			total = total + Skada:SafeNumber(p.totalAmount)
		end
		return total
	end

	local function getDTPS(set, player)
		-- Use API DTPS (type 7 = DamageTaken)
		return Skada.NativeAPI:GetPlayerRate(set, player, 7)
	end

	function mod:Update(win, set)
		-- 7 = DamageTaken
		local view = Skada.NativeAPI:GetSessionView(set, 7)
		if not view then return end
		
		local sources = view.combatSources or {}
		local max = 0
		local nr = 1
		
		-- Calculate total for percentage
		local setTotalDT = 0
		for _, p in pairs(sources) do
			local amount = Skada:SafeNumber(p.totalAmount)
			setTotalDT = setTotalDT + amount
		end

		for i, player in pairs(sources) do
			local damagetaken = Skada:SafeNumber(player.totalAmount or 0)
			if damagetaken > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				local dtps = getDTPS(set, player)

				local playerName = player.name or player.unitName
				local playerID = player.sourceGUID

				d.label = playerName
				d.value = Skada:SafeNumber(damagetaken)

				Skada:FormatValueText(d,
					Skada:FormatNumber(damagetaken), self.metadata.columns.Damage,
					string.format("%02.1f", dtps), self.metadata.columns.DTPS,
					string.format("%02.1f%%", damagetaken / math.max(1, setTotalDT) * 100), self.metadata.columns.Percent
				)
				d.id = playerID
				d.class = player.class or player.classFilename
				d.role = player.role

				if damagetaken > max then
					max = damagetaken
				end
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Damage taken"]
	end

	-- Detail view of a player.
	function playermod:Update(win, set)
		-- 7 = DamageTaken
		local spells = Skada.NativeAPI:GetPlayerSpells(self.playerid, set, 7)
		if not spells then return end
		
		local max = 0
		local nr = 1
		local totalDT = 0
		
		for _, spell in pairs(spells) do
			totalDT = totalDT + (spell.totalAmount or 0)
		end
		
		for _, spell in pairs(spells) do
			local amount = spell.totalAmount or 0
			if amount > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = spell.spellID
				local spellID = spell.spellID or 0
				local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
				d.label = spellInfo and spellInfo.name or ("Spell " .. spell.spellID)
				
				d.value = amount
				d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalDT) * 100)
				d.icon = Skada:GetSpellIcon(spell.spellID)
				
				if amount > max then
					max = amount
				end
				nr = nr + 1
			end
		end
		
		win.metadata.maxvalue = max
	end

	-- Tooltip for damage taken.
	local function playerspell_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		-- 7 = DamageTaken
		local view = Skada.NativeAPI:GetSessionView(set, 7)
		if not view then return end
		
		local sources = view.combatSources or {}
		local player
		for _, p in pairs(sources) do
			-- Safely compare GUIDs, handling "secret values"
			local sourceGUID = tostring(p.sourceGUID or "")
			if sourceGUID == playermod.playerid then
				player = p
				break
			end
		end

		if player then
			local damagetaken = Skada:SafeNumber(player.totalAmount or 0)
			tooltip:AddLine((player.name or label).." - "..L["Damage Taken"])
			tooltip:AddDoubleLine(L["Total Damage:"], Skada:FormatNumber(damagetaken), 1,1,1,1,1,1)
			
			-- Add top 3 sources (spells)
			local spells = Skada.NativeAPI:GetPlayerSpells(playermod.playerid, set, 7)
			if spells then
				local sorted = {}
				for _, s in pairs(spells) do
					table.insert(sorted, s)
				end
				table.sort(sorted, function(a, b) return (a.totalAmount or 0) > (b.totalAmount or 0) end)
				
				tooltip:AddLine(" ")
				tooltip:AddLine(L["Top Sources"])
				for i = 1, math.min(3, #sorted) do
					local s = sorted[i]
					local spellID = s.spellID or 0
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					local name = spellInfo and spellInfo.name or ("Source " .. s.spellID)
					local val = s.totalAmount or 0
					local percent = (val / math.max(1, damagetaken)) * 100
					tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1,1,1,1,1,1)
				end
			end
		end
	end


	function mod:OnEnable()
		playermod.metadata = {tooltip = playerspell_tooltip}
		mod.metadata = {click1 = playermod, showspots = true, columns = {Damage = true, DTPS = true, Percent = true}, icon = "Interface\\Icons\\Inv_shield_06"}

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
	end

	function mod:FormatSetSummary(datasetItem,set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(getSetTotal(set)), true)
	end
end)
