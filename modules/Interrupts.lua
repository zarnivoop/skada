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
			local amount = p.totalAmount or 0
			if issecretvalue and issecretvalue(amount) then
				return amount -- If any secret, total is secret
			end
			total = total + (tonumber(amount) or 0)
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
		
		local hasSecretAPI = issecretvalue ~= nil
		local hasSecretValues = false
		local max = 0
		local nr = 1
		local totalInterrupts = 0
		
		for _, spell in pairs(spells) do
			local amount = spell.totalAmount or 0
			if hasSecretAPI and issecretvalue(amount) then
				hasSecretValues = true
			else
				totalInterrupts = totalInterrupts + (tonumber(amount) or 0)
			end
		end
		
		for _, spell in pairs(spells) do
			local rawAmount = spell.totalAmount or 0
			local isSecretAmt = hasSecretAPI and rawAmount and issecretvalue(rawAmount)
			
			if rawAmount ~= 0 or isSecretAmt then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = spell.spellID
				local spellID = spell.spellID or 0
				local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
				d.label = spellInfo and spellInfo.name or ("Spell " .. spell.spellID)
				
				if isSecretAmt then
					d.value = 1000 - nr
					d.valuetext = Skada:FormatNumberSecret(rawAmount)
				else
					local amount = tonumber(rawAmount) or 0
					d.value = amount
					d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalInterrupts) * 100)
					if amount > max then
						max = amount
					end
				end
				d.icon = Skada:GetSpellIcon(spell.spellID)
				nr = nr + 1
			end
		end
		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or max
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
		GameTooltip:AddDoubleLine(L["Interrupts"], Skada:FormatNumberSecret(total), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		local total = getSetTotal(set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(total), true)
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
		
		-- Check for WoW 12.0 issecretvalue function
		local hasSecretAPI = issecretvalue ~= nil
		
		-- Detect if any values are secret (during combat)
		local hasSecretValues = false
		local max = 0
		local nr = 1
		
		-- First pass: detect secrets
		local setTotal = 0
		for _, player in pairs(sources) do
			local amount = player.totalAmount
			if amount then
				if hasSecretAPI and issecretvalue(amount) then
					hasSecretValues = true
				else
					local num = tonumber(amount) or 0
					setTotal = setTotal + num
				end
			end
		end
		set.interrupts = setTotal
		
		-- If secret state changed, wipe the window
		if win.metadata.wasSecretValues ~= nil and win.metadata.wasSecretValues ~= hasSecretValues then
			win:Wipe()
		end
		win.metadata.wasSecretValues = hasSecretValues
		win.metadata.ordersort = hasSecretValues

		for _, player in pairs(sources) do
			-- Get player name
			local playerName = nil
			local rawName = player.name or player.unitName
			if rawName then
				if hasSecretAPI and issecretvalue(rawName) then
					playerName = string.format("%s", rawName)
				elseif type(rawName) == "string" then
					playerName = rawName
				end
			end
			
			if playerName then
				local rawInterrupts = player.totalAmount
				local interrupts = 0
				local isSecretInt = hasSecretAPI and rawInterrupts and issecretvalue(rawInterrupts)
				
				if rawInterrupts and not isSecretInt then
					interrupts = tonumber(rawInterrupts) or 0
				end
				
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				-- Use real GUID for detail view navigation
				d.id = player.sourceGUID or playerName
				
				if hasSecretValues then
					d.value = 1000 - nr
					d.valuetext = Skada:FormatNumberSecret(rawInterrupts)
				else
					d.value = interrupts
					d.valuetext = Skada:FormatNumber(interrupts)
					if interrupts > max then
						max = interrupts
					end
				end
				
				d.label = playerName
				d.class = player.class or player.classFilename
				d.role = player.role
				d.order = nr

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or max
	end
end)
