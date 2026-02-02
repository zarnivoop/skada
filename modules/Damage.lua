local _, Skada = ...
Skada:AddLoadableModule("Damage", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Damage then return end

	local mod = Skada:NewModule(L["Damage"])
	local playermod = Skada:NewModule(L["Damage spell list"])
	local dpsmod = Skada:NewModule(L["DPS"])

	local pairs = pairs
	local ipairs = ipairs

	local function getDPS(set, player)
		-- Use API DPS (type 1 = Dps)
		return Skada.NativeAPI:GetPlayerRate(set, player, 1)
	end

	local function getRaidDPS(set)
		-- Use API DPS (type 1 = Dps)
		return Skada.NativeAPI:GetRaidRate(set, 1)
	end

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Damage"]
	end

	function playermod:Update(win, set)
		-- 0 = DamageDone
		local spells = Skada.NativeAPI:GetPlayerSpells(self.playerid, set, 0)
		if not spells then return end
		
		local hasSecretAPI = issecretvalue ~= nil
		local hasSecretValues = false
		local max = 0
		local nr = 1
		local totalDamage = 0
		
		-- Calculate total first for percentage and detect secrets
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				local amount = spell.totalAmount
				if hasSecretAPI and issecretvalue(amount) then
					hasSecretValues = true
				else
					totalDamage = totalDamage + (tonumber(amount) or 0)
				end
			end
		end
		
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				local rawAmount = spell.totalAmount
				local isSecretAmt = hasSecretAPI and rawAmount and issecretvalue(rawAmount)
				
				if rawAmount ~= 0 or isSecretAmt then
					local spellID = spell.spellID or 0
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.id = spellID
					
					-- Get spell name from spellID
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					d.label = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))
					
					if isSecretAmt then
						d.value = 1000 - nr
						d.valuetext = Skada:FormatNumberSecret(rawAmount)
					else
						local amount = tonumber(rawAmount) or 0
						d.value = amount
						d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalDamage) * 100)
						if amount > max then
							max = amount
						end
					end
					d.icon = Skada:GetSpellIcon(spellID)
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or max
	end

	-- Damage overview.
	function mod:Update(win, set)
		if not set then return end
		
		-- 0 = DamageDone
		local view = Skada.NativeAPI:GetSessionView(set, 0)
		if not view then return end
		
		local sources = view.combatSources or {}
		
		-- Check for WoW 12.0 issecretvalue function
		local hasSecretAPI = issecretvalue ~= nil
		
		-- Detect if any values are secret (during combat)
		local hasSecretValues = false
		local max = 0
		local nr = 1
		
		-- First pass: detect secrets and calculate total for non-secrets
		local totalDamage = 0
		for _, player in pairs(sources) do
			local damageValue = player.totalAmount
			if damageValue then
				if hasSecretAPI and issecretvalue(damageValue) then
					hasSecretValues = true
				else
					local num = tonumber(damageValue) or 0
					totalDamage = totalDamage + num
				end
			end
		end
		
		-- If secret state changed, wipe the window to prevent duplicate bars
		-- (combat uses "combat_N" IDs, non-combat uses player names)
		if win.metadata.wasSecretValues ~= nil and win.metadata.wasSecretValues ~= hasSecretValues then
			win:Wipe()
		end
		win.metadata.wasSecretValues = hasSecretValues
		
		-- If values are secret, we'll preserve API order for sorting
		win.metadata.ordersort = hasSecretValues
		
		for _, player in pairs(sources) do
			-- Get player name - string.format works with secrets
			local playerName = nil
			local rawName = player.name or player.unitName
			
			if rawName then
				if hasSecretAPI and issecretvalue(rawName) then
					playerName = string.format("%s", rawName)
				elseif type(rawName) == "string" then
					playerName = rawName
				end
			end
			
			-- Only process if we have a name
			if playerName then
				-- Get raw damage value (may be secret)
				local rawDamage = player.totalAmount
				local damage = 0
				local isSecretDamage = hasSecretAPI and rawDamage and issecretvalue(rawDamage)
				
				if rawDamage and not isSecretDamage then
					damage = tonumber(rawDamage) or 0
				end
				
				-- Get raw DPS (may be secret)
				local rawDps = player.amountPerSecond or player.rate
				local dps = 0
				local isSecretDps = hasSecretAPI and rawDps and issecretvalue(rawDps)
				
				if rawDps and not isSecretDps then
					dps = tonumber(rawDps) or 0
				end
				
				-- Get class/role safely
				local playerClass = nil
				local rawClass = player.class or player.classFilename
				if rawClass and type(rawClass) == "string" then
					playerClass = rawClass
				end
				
				local playerRole = player.role
				
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				
				-- Use player GUID as ID for detail view navigation.
				-- Even if it is a secret value, Skada:find_player will handle it.
				d.id = player.sourceGUID or playerName
				d.label = playerName  -- Label can still be the (formatted) secret string
				d.class = playerClass
				d.role = playerRole
				d.order = nr  -- Store order for fallback sorting
				
				if hasSecretValues then
					-- During combat: use FormatNumberSecret for secret values
					local damageText = Skada:FormatNumberSecret(rawDamage)
					local dpsText = Skada:FormatNumberSecret(rawDps)
					
					Skada:FormatValueText(d,
						damageText, self.metadata.columns.Damage,
						dpsText, self.metadata.columns.DPS,
						"", self.metadata.columns.Percent  -- Can't calculate % with secrets
					)
					d.value = 1000 - nr  -- Use order for bar sizing
				else
					-- After combat: values are readable, format normally
					local percent = totalDamage > 0 and (damage / totalDamage * 100) or 0
					
					Skada:FormatValueText(d,
						Skada:FormatNumber(damage), self.metadata.columns.Damage,
						Skada:FormatNumber(dps), self.metadata.columns.DPS,
						string.format("%02.1f%%", percent), self.metadata.columns.Percent
					)
					d.value = damage
					if damage > max then
						max = damage
					end
				end
				
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or (max > 0 and max or 1)
	end

	-- Tooltip for a specific player.
	local function dps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		local player = Skada:find_player(set, id)
		if not player then return end
		
		-- 0 = DamageDone - get damage-specific session view
		local damageSet = Skada.NativeAPI:GetSessionView(set, 0)
		if not damageSet then return end
		
		local totaltime = Skada:GetSetTime(damageSet)
		local rawDamage = player.totalAmount or 0
		local rawDps = player.amountPerSecond or 0
		
		tooltip:AddLine((playerName or label).." - "..L["DPS"])
		tooltip:AddDoubleLine(L["Segment time"], totaltime.."s", 1,1,1,1,1,1)
		tooltip:AddDoubleLine(L["Damage done"], Skada:FormatNumberSecret(rawDamage), 1,1,1,1,1,1)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumberSecret(rawDps), 1,1,1,1,1,1)
		
		-- Add top 3 spells
		-- 0 = DamageDone
		local spells = Skada.NativeAPI:GetPlayerSpells(id, damageSet, 0)
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
					
					local rawVal = s.totalAmount or 0
					local isSecretVal = issecretvalue and issecretvalue(rawVal)
					
					if isSecretVal then
						tooltip:AddDoubleLine(name, Skada:FormatNumberSecret(rawVal), 1,1,1,1,1,1)
					else
						local val = tonumber(rawVal) or 0
						local playerVal = Skada:SafeNumber(rawDamage)
						local percent = playerVal > 0 and (val / playerVal) * 100 or 0
						tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1,1,1,1,1,1)
					end
				end
			end
		end
	end

	-- Tooltip for a specific player.
	-- This is a post-tooltip
	-- With Native API, we can't track individual player activity time
	-- So we'll show damage percentage instead
	local function damage_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		local player = Skada:find_player(set, id)
		if player then
			-- Calculate total damage in set for percentage
			local rawPlayerDamage = player.totalAmount or 0
			local isSecretPlayerDamage = issecretvalue and issecretvalue(rawPlayerDamage)
			
			if isSecretPlayerDamage then
				-- Can't show share percentage with secrets
				return
			end
			
			local playerDamage = tonumber(rawPlayerDamage) or 0
			local totalDamage = 0
			
			-- 0 = DamageDone
			local view = Skada.NativeAPI:GetSessionView(set, 0)
			if view then
				local sources = view.combatSources or view.participants or {}
				for _, p in pairs(sources) do
					totalDamage = totalDamage + Skada:SafeNumber(p.totalAmount or 0)
				end
			end
			
			if totalDamage > 0 then
				local percent = (playerDamage / totalDamage) * 100
				tooltip:AddDoubleLine(L["Damage share"], ("%02.1f%%"):format(percent), 255,255,255,255,255,255)
			end
		end
	end

	-- DPS-only view
	function dpsmod:FormatSetSummary(datasetItem, set)
		local raidDPS = getRaidDPS(set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(raidDPS), true)
	end

	function dpsmod:Update(win, set)
		if not set then return end
		
		-- 0 = DamageDone
		local view = Skada.NativeAPI:GetSessionView(set, 0)
		if not view then return end
		
		local sources = view.combatSources or {}
		
		-- Secret detection
		local hasSecretAPI = issecretvalue ~= nil
		local hasSecretValues = false
		local max = 0
		local nr = 1
		
		for _, player in pairs(sources) do
			local dpsVal = player.amountPerSecond or player.rate
			if dpsVal and hasSecretAPI and issecretvalue(dpsVal) then
				hasSecretValues = true
				break
			end
		end
		
		-- Wipe on state change
		if win.metadata.wasSecretValues ~= nil and win.metadata.wasSecretValues ~= hasSecretValues then
			win:Wipe()
		end
		win.metadata.wasSecretValues = hasSecretValues
		win.metadata.ordersort = hasSecretValues

		for _, player in pairs(sources) do
			local rawDps = player.amountPerSecond or player.rate
			local isSecretDps = hasSecretAPI and rawDps and issecretvalue(rawDps)
			local dps = 0
			if not isSecretDps then
				dps = tonumber(rawDps) or 0
			end

			if dps > 0 or isSecretDps then
				local rawName = player.name or player.unitName
				local playerName = rawName
				if hasSecretAPI and issecretvalue(rawName) then
					playerName = string.format("%s", rawName)
				end

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = playerName
				
				if hasSecretValues then
					d.id = "combat_" .. nr
					d.value = 1000 - nr
					d.valuetext = Skada:FormatNumberSecret(rawDps)
				else
					d.id = player.sourceGUID or playerName
					d.value = dps
					d.valuetext = Skada:FormatNumber(dps)
					if dps > max then
						max = dps
					end
				end
				
				d.class = player.class or player.classFilename
				d.role = player.role
				d.order = nr

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or max
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = dps_tooltip}
		dpsmod.metadata = {showspots = true, tooltip = dps_tooltip, icon = "Interface\\Icons\\Inv_throwingaxe_02"}
		mod.metadata = {click1 = playermod, post_tooltip = damage_tooltip, showspots = true, columns = {Damage = true, DPS = true, Percent = true}, icon = "Interface\\Icons\\Inv_throwingaxe_01"}

		Skada:AddFeed(L["Damage: Personal DPS"], function()
			if Skada.current then
				local player = Skada:find_player(Skada.current, UnitGUID("player"))
				if player then
					local dps = getDPS(Skada.current, player)
					return Skada:FormatNumberSecret(dps).." "..L["DPS"]
				end
			end
		end)
		Skada:AddFeed(L["Damage: Raid DPS"], function()
			if Skada.current then
				local raidDps = getRaidDPS(Skada.current)
				return Skada:FormatNumberSecret(raidDps).." "..L["RDPS"]
			end
		end)
		Skada:AddMode(self, L["Damage"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
		Skada:RemoveFeed(L["Damage: Personal DPS"])
		Skada:RemoveFeed(L["Damage: Raid DPS"])
	end

	function dpsmod:OnEnable()
		Skada:AddMode(self, L["Damage"])
	end

	function dpsmod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		local raidDps = getRaidDPS(set)
		GameTooltip:AddDoubleLine(L["DPS"], Skada:FormatNumberSecret(raidDps), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		-- Calculate total damage from session view
		local totalDamage = 0
		local raidDps = 0
		if set then
			raidDps = getRaidDPS(set)
			-- 0 = DamageDone
			local view = Skada.NativeAPI:GetSessionView(set, 0)
			if view then
				local sources = view.combatSources or {}
				for _, player in pairs(sources) do
					local damageVal = player.totalAmount or 0
					if issecretvalue and issecretvalue(damageVal) then
						-- If we find a secret value, the whole total is effectively secret
						totalDamage = damageVal
						break
					end
					totalDamage = totalDamage + (tonumber(damageVal) or 0)
				end
			end
		end
		
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumberSecret(totalDamage), self.metadata.columns.Damage,
			Skada:FormatNumberSecret(raidDps), self.metadata.columns.DPS
		)
	end

	-- Called by Skada when a new player is added to a set.
	-- With Native API, players come from API, not created locally
	function mod:AddPlayerAttributes(player)
		-- No-op for Native API
	end

	-- Called by Skada when a new set is created.
	-- With Native API, sets are API sessions, not created locally
	function mod:AddSetAttributes(set)
		-- No-op for Native API
	end
end)
