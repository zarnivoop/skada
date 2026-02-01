local _, Skada = ...
Skada:AddLoadableModule("Interrupts", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Interrupts then return end

	local mod = Skada:NewModule(L["Interrupts"])
	local playermod = Skada:NewModule(L["Interrupt spells"])
	mod.metadata = {icon = "Interface\\Icons\\Ability_rogue_kidneyshot"}

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Interrupts"]
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, self.playerid)
		local max = 0
		local nr = 1
		
		if player and player.interruptspells then
			for spellname, spell in pairs(player.interruptspells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = spell.id
				d.label = spellname
				d.value = spell.count
				d.valuetext = tostring(spell.count)
				d.icon = Skada:GetSpellIcon(spell.id)
				
				if spell.count > max then
					max = spell.count
				end
				nr = nr + 1
			end
		end
		win.metadata.maxvalue = max
	end

	function mod:OnEnable()
		mod.metadata = {click1 = playermod, icon = "Interface\\Icons\\Ability_rogue_kidneyshot"}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		GameTooltip:AddDoubleLine(L["Interrupts"], set.interrupts, 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		Skada:FormatValueText(datasetItem, set.interrupts, true)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
		if not player.interrupts then
			player.interrupts = 0
		end
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
		if not set.interrupts then
			set.interrupts = 0
		end
	end

	function mod:Update(win, set)
		local max = 0
		local nr = 1
		for i, player in ipairs(set.players) do
			local interrupts = player.interrupts or 0
			if interrupts > 0 then

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.value = interrupts
				d.label = player.name
				d.valuetext = tostring(interrupts)
				d.id = player.id
				d.class = player.class
				d.role = player.role
				if interrupts > max then
					max = interrupts
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end
end)
