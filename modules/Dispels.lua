local _, Skada = ...
Skada:AddLoadableModule("Dispels", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Dispels then return end

	local mod = Skada:NewModule(L["Dispels"])
	local playermod = Skada:NewModule(L["Dispels spell list"])

	local function getSetTotal(set)
		if not set then return 0 end
		-- 6 = Dispels
		local view = Skada.NativeAPI:GetSessionView(set, 6)
		if not view then return 0 end
		
		local total = 0
		local sources = view.combatSources or view.participants or {}
		for _, p in pairs(sources) do
			total = total + (p.dispels or p.totalAmount or 0)
		end
		return total
	end

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Dispels"]
	end

	function playermod:Update(win, set)
		-- 6 = Dispels
		local view = Skada.NativeAPI:GetSessionView(set, 6)
		if not view then return end
		
		local source = Skada.NativeAPI:GetPlayerSpells(self.playerid, view, 6)
		if not source then return end
		
		local spells = source.combatSpells
		if not spells then return end
		
		local max = 0
		local nr = 1
		local totalDispels = 0
		
		if spells then
			-- Calculate total for percentage
			for _, spell in pairs(spells) do
				totalDispels = totalDispels + (spell.totalAmount or 0)
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
					d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalDispels) * 100)
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

	function mod:Update(win, set)
		-- 6 = Dispels
		local view = Skada.NativeAPI:GetSessionView(set, 6)
		if not view then return end
		
		local sources = view.combatSources or {}
		local max = 0
		local nr = 1
		
		local setTotal = 0
		for _, p in pairs(sources) do
			local amount = Skada:SafeNumber(p.totalAmount)
			setTotal = setTotal + amount
		end
		set.dispels = setTotal -- Cache

		for i, player in pairs(sources) do
			local dispels = Skada:SafeNumber(player.totalAmount or 0)
			if dispels > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.value = dispels
				d.label = player.name or player.unitName
				d.class = player.class or player.classFilename
				d.role = player.role
				d.id = player.sourceGUID
				d.valuetext = Skada:FormatNumber(dispels)
				if dispels > max then
					max = dispels
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
		local total = getSetTotal(set)
		GameTooltip:AddDoubleLine(L["Dispels"], Skada:FormatNumber(total), 1,1,1)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
	end

	function mod:FormatSetSummary(datasetItem, set)
		local total = getSetTotal(set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(total), true)
	end
end)
