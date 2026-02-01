local _, Skada = ...
Skada:AddLoadableModule("DamageTaken", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.DamageTaken then return end

	local mod = Skada:NewModule(L["Damage taken"])
	local playermod = Skada:NewModule(L["Damage taken details"])





	function mod:Update(win, set)
		local max = 0

		local nr = 1
		for i, player in ipairs(set.players) do
			local damagetaken = player.damagetaken or 0
			if damagetaken > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				local totaltime = Skada:PlayerActiveTime(set, player)
				local dtps = damagetaken / math.max(1,totaltime)

				d.label = player.name
				d.value = damagetaken

				Skada:FormatValueText(d,
					Skada:FormatNumber(damagetaken), self.metadata.columns.Damage,
					string.format("%02.1f", dtps), self.metadata.columns.DTPS,
					string.format("%02.1f%%", damagetaken / math.max(1, set.damagetaken or 1) * 100), self.metadata.columns.Percent
				)
				d.id = player.id
				d.class = player.class
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
		local player = Skada:find_player(set, self.playerid)
		local max = 0
		local nr = 1
		
		if player and player.damagetakenspells then
			for spellname, spell in pairs(player.damagetakenspells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = spell.id
				d.label = spellname
				d.value = spell.damage
				d.valuetext = Skada:FormatNumber(spell.damage)..(" (%02.1f%%)"):format(spell.damage / math.max(1, player.damagetaken) * 100)
				d.icon = Skada:GetSpellIcon(spell.id)
				
				if spell.damage > max then
					max = spell.damage
				end
				nr = nr + 1
			end
		end
		
		win.metadata.maxvalue = max
	end

	-- Tooltip for damage taken.
	local function playerspell_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
		if player then
			tooltip:AddLine(player.name.." - "..L["Damage Taken"])
			tooltip:AddDoubleLine(L["Total Damage:"], Skada:FormatNumber(player.damagetaken), 255,255,255,255,255,255)
			local set = win:get_selected_set()
			if set and set.damagetaken and set.damagetaken > 0 then
				tooltip:AddDoubleLine(L["Percentage:"], string.format("%02.1f%%", player.damagetaken / set.damagetaken * 100), 255,255,255,255,255,255)
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
		if not player.damagetaken then
			player.damagetaken = 0
		end
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
		if not set.damagetaken then
			set.damagetaken = 0
		end
	end

	function mod:FormatSetSummary(datasetItem,set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(set.damagetaken), true)
	end
end)
