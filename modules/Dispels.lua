local _, Skada = ...
Skada:AddLoadableModule("Dispels", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Dispels then return end

	local mod = Skada:NewModule(L["Dispels"])
	local playermod = Skada:NewModule(L["Dispels spell list"])



	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Dispels"]
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, self.playerid)
		local max = 0
		local nr = 1
		
		if player and player.dispellspells then
			for spellname, spell in pairs(player.dispellspells) do
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

	function mod:Update(win, set)
		local max = 0
		local nr = 1

		for i, player in ipairs(set.players) do
			local dispells = player.dispells or 0
			if dispells > 0 then

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.value = dispells
				d.label = player.name
				d.class = player.class
				d.role = player.role
				d.id = player.id
				d.valuetext = tostring(dispells)
				if dispells > max then
					max = dispells
				end
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:OnEnable()
		mod.metadata = {click1 = playermod, showspots = true, icon = "Interface\\Icons\\Spell_holy_dispelmagic"}

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		GameTooltip:AddDoubleLine(L["Dispels"], set.dispells, 1,1,1)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
		if not player.dispells then
			player.dispells = 0
		end
		if not player.interrupts then
			player.interrupts = 0
		end
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
		if not set.dispells then
			set.dispells = 0
		end
		if not set.interrupts then
			set.interrupts = 0
		end
	end

	function mod:FormatSetSummary(datasetItem, set)
		Skada:FormatValueText(datasetItem, set.dispells, true)
	end
end)
