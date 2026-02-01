local _, Skada = ...
Skada:AddLoadableModule("Interrupts", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Interrupts then return end

	local mod = Skada:NewModule(L["Interrupts"])
	local playermod = Skada:NewModule(L["Interrupt spells"])
	mod.metadata = {icon = "Interface\\Icons\\Ability_rogue_kidneyshot"}

	local function getSetTotal(set)
		if not set then return 0 end
		-- 5 = Interrupts
		local view = Skada.NativeAPI:GetSessionView(set, 5)
		if not view then return 0 end
		
		local total = 0
		local sources = view.combatSources or {}
		for _, p in pairs(sources) do
			total = total + (p.totalAmount or 0)
		end
		return total
	end

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Interrupts"]
	end

	function playermod:Update(win, set)
		-- 5 = Interrupts
		local view = Skada.NativeAPI:GetSessionView(set, 5)
		if not view then return end
		
		local source = Skada.NativeAPI:GetPlayerSpells(self.playerid, view, 5)
		if not source then return end
		
		local spells = source.combatSpells
		if not spells then return end
		
		local max = 0
		local nr = 1
		local totalInterrupts = 0
		
		if spells then
			-- Calculate total for percentage
			for _, spell in pairs(spells) do
				totalInterrupts = totalInterrupts + (spell.totalAmount or 0)
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
					d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalInterrupts) * 100)
					d.icon = Skada:GetSpellIcon(spell.spellID)
					
					if amount > max then
						max = amount
					end
					nr = nr + 1
				end
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
		local total = getSetTotal(set)
		GameTooltip:AddDoubleLine(L["Interrupts"], Skada:FormatNumber(total), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		local total = getSetTotal(set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(total), true)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
	end

	function mod:Update(win, set)
		-- 5 = Interrupts
		local view = Skada.NativeAPI:GetSessionView(set, 5)
		if not view then return end
		
		local sources = view.combatSources or {}
		local max = 0
		local nr = 1
		
		local setTotal = 0
		for _, p in pairs(sources) do
			local amount = Skada:SafeNumber(p.totalAmount)
			setTotal = setTotal + amount
		end
		set.interrupts = setTotal -- Cache

		for i, player in pairs(sources) do
			local interrupts = Skada:SafeNumber(player.totalAmount)
			if interrupts > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.value = interrupts
				d.label = player.name or player.unitName
				d.valuetext = Skada:FormatNumber(interrupts)
				d.id = player.sourceGUID
				d.class = player.class or player.classFilename
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
