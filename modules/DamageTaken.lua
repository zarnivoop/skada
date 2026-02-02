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
			local amount = p.totalAmount or 0
			if issecretvalue and issecretvalue(amount) then
				return amount -- If any secret, total is secret
			end
			total = total + (tonumber(amount) or 0)
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
		
		-- Check for WoW 12.0 issecretvalue function
		local hasSecretAPI = issecretvalue ~= nil
		
		-- Detect if any values are secret (during combat)
		local hasSecretValues = false
		local max = 0
		local nr = 1
		
		-- First pass: detect secrets and calculate total
		local setTotalDT = 0
		for _, player in pairs(sources) do
			local amount = player.totalAmount
			if amount then
				if hasSecretAPI and issecretvalue(amount) then
					hasSecretValues = true
				else
					local num = tonumber(amount) or 0
					setTotalDT = setTotalDT + num
				end
			end
		end
		
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
				local rawDamageTaken = player.totalAmount
				local damagetaken = 0
				local isSecretDT = hasSecretAPI and rawDamageTaken and issecretvalue(rawDamageTaken)
				
				if rawDamageTaken and not isSecretDT then
					damagetaken = tonumber(rawDamageTaken) or 0
				end
				
				-- Get DTPS
				local dtps = getDTPS(set, player)
				
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				-- Use player GUID as ID for detail view navigation.
				d.id = player.sourceGUID or playerName
				
				d.label = playerName
				d.class = player.class or player.classFilename
				d.role = player.role
				d.order = nr
				
				if hasSecretValues then
					d.value = 1000 - nr
					Skada:FormatValueText(d,
						Skada:FormatNumberSecret(rawDamageTaken), self.metadata.columns.Damage,
						Skada:FormatNumberSecret(dtps), self.metadata.columns.DTPS,
						"", self.metadata.columns.Percent
					)
				else
					d.value = damagetaken
					if damagetaken > max then
						max = damagetaken
					end
					Skada:FormatValueText(d,
						Skada:FormatNumber(damagetaken), self.metadata.columns.Damage,
						string.format("%02.1f", dtps), self.metadata.columns.DTPS,
						string.format("%02.1f%%", damagetaken / math.max(1, setTotalDT) * 100), self.metadata.columns.Percent
					)
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or max
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
		
		local hasSecretAPI = issecretvalue ~= nil
		local hasSecretValues = false
		local max = 0
		local nr = 1
		local totalDT = 0
		
		for _, spell in pairs(spells) do
			local amount = spell.totalAmount or 0
			if hasSecretAPI and issecretvalue(amount) then
				hasSecretValues = true
			else
				totalDT = totalDT + (tonumber(amount) or 0)
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
					d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalDT) * 100)
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
			local rawDamageTaken = player.totalAmount or 0
			tooltip:AddLine((player.name or label).." - "..L["Damage Taken"])
			tooltip:AddDoubleLine(L["Total Damage:"], Skada:FormatNumberSecret(rawDamageTaken), 1,1,1,1,1,1)
			
			-- Add top 3 sources (spells)
			local spells = Skada.NativeAPI:GetPlayerSpells(playermod.playerid, set, 7)
			if spells then
				local sorted = {}
				for _, s in pairs(spells) do
					table.insert(sorted, s)
				end
				table.sort(sorted, function(a, b) 
					local aVal = a.totalAmount or 0
					local bVal = b.totalAmount or 0
					if issecretvalue and (issecretvalue(aVal) or issecretvalue(bVal)) then
						-- Can't compare secrets reliably, keep order
						return false
					end
					return (tonumber(aVal) or 0) > (tonumber(bVal) or 0)
				end)
				
				tooltip:AddLine(" ")
				tooltip:AddLine(L["Top Sources"])
				for i = 1, math.min(3, #sorted) do
					local s = sorted[i]
					local spellID = s.spellID or 0
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					local name = spellInfo and spellInfo.name or ("Source " .. s.spellID)
					local rawVal = s.totalAmount or 0
					
					if issecretvalue and issecretvalue(rawVal) then
						tooltip:AddDoubleLine(name, Skada:FormatNumberSecret(rawVal), 1,1,1,1,1,1)
					else
						local val = tonumber(rawVal) or 0
						local dt = tonumber(rawDamageTaken) or 0
						local percent = dt > 0 and (val / dt) * 100 or 0
						tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1,1,1,1,1,1)
					end
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
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(getSetTotal(set)), true)
	end
end)
