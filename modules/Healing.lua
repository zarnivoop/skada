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
			local amount = p.totalAmount or 0
			if issecretvalue and issecretvalue(amount) then
				return amount -- If any secret, total is secret
			end
			total = total + (tonumber(amount) or 0)
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
		
		local hasSecretAPI = issecretvalue ~= nil
		local hasSecretValues = false
		local max = 0
		local nr = 1
		local totalHealing = 0
		
		-- Calculate total first for percentage and detect secrets
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				local amount = spell.totalAmount
				if hasSecretAPI and issecretvalue(amount) then
					hasSecretValues = true
				else
					totalHealing = totalHealing + (tonumber(amount) or 0)
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
						d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalHealing) * 100)
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

	-- Healing overview.
	function mod:Update(win, set)
		-- 2 = Healing
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if not healingSet then return end
		
		-- Use API participants/sources
		local sources = healingSet.combatSources or healingSet.participants or {}
		local sourceCount = 0
		for _ in pairs(sources) do sourceCount = sourceCount + 1 end
		
		-- Check for WoW 12.0 issecretvalue function
		local hasSecretAPI = issecretvalue ~= nil
		
		-- Detect if values are secret (during combat)
		local hasSecretValues = false
		local max = 0
		local nr = 1
		
		-- First pass: detect secrets and calculate total for non-secrets
		local setTotalHealing = 0
		for _, player in pairs(sources) do
			local amountVal = player.healing or player.totalAmount
			if amountVal then
				if hasSecretAPI and issecretvalue(amountVal) then
					hasSecretValues = true
				else
					local num = tonumber(amountVal) or 0
					setTotalHealing = setTotalHealing + num
				end
			end
		end
		
		-- If secret state changed, wipe the window to prevent duplicate bars
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
				-- Get raw healing value (may be secret)
				local rawAmount = player.healing or player.totalAmount
				local amount = 0
				local isSecretAmount = hasSecretAPI and rawAmount and issecretvalue(rawAmount)
				
				if rawAmount and not isSecretAmount then
					amount = tonumber(rawAmount) or 0
				end
				
				-- Get raw HPS (may be secret)
				local rawHps = player.amountPerSecond or player.rate
				local hps = 0
				local isSecretHps = hasSecretAPI and rawHps and issecretvalue(rawHps)
				
				if rawHps and not isSecretHps then
					hps = tonumber(rawHps) or 0
				else
					-- Fallback: calculate HPS if available
					hps = getHPS(healingSet, player)
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
				d.label = playerName
				d.class = playerClass
				d.role = playerRole
				d.order = nr  -- Store order for fallback sorting
				
				if hasSecretValues then
					-- During combat: use FormatNumberSecret for secret values
					local healingText = Skada:FormatNumberSecret(rawAmount)
					local hpsText = Skada:FormatNumberSecret(rawHps)
					
					Skada:FormatValueText(d,
						healingText, self.metadata.columns.Healing,
						hpsText, self.metadata.columns.HPS,
						"", self.metadata.columns.Percent  -- Can't calculate % with secrets
					)
					d.value = 1000 - nr  -- Use order for bar sizing
				else
					-- After combat: values are readable
					local percent = setTotalHealing > 0 and (amount / setTotalHealing * 100) or 0
					
					Skada:FormatValueText(d,
						Skada:FormatNumber(amount), self.metadata.columns.Healing,
						Skada:FormatNumber(hps), self.metadata.columns.HPS,
						string.format("%02.1f%%", percent), self.metadata.columns.Percent
					)
					d.value = amount
					if amount > max then
						max = amount
					end
				end
				
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or (max > 0 and max or 1)
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
		local rawAmount = player.totalAmount or 0
		local rawHps = player.amountPerSecond or 0
		
		tooltip:AddLine((playerName or label).." - "..L["HPS"])
		tooltip:AddDoubleLine(L["Segment time"], totaltime.."s", 1,1,1,1,1,1)
		tooltip:AddDoubleLine(L["Healing done"], Skada:FormatNumberSecret(rawAmount), 1,1,1,1,1,1)
		tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumberSecret(rawHps), 1,1,1,1,1,1)
		
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
					
					local rawVal = s.totalAmount or 0
					local isSecretVal = issecretvalue and issecretvalue(rawVal)
					
					if isSecretVal then
						tooltip:AddDoubleLine(name, Skada:FormatNumberSecret(rawVal), 1,1,1,1,1,1)
					else
						local val = tonumber(rawVal) or 0
						local playerVal = Skada:SafeNumber(rawAmount)
						local percent = playerVal > 0 and (val / playerVal) * 100 or 0
						tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1,1,1,1,1,1)
					end
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
			local rawAmount = spellData.totalAmount or 0
			tooltip:AddLine(label .. " (" .. L["Healing"] .. ")")
			tooltip:AddDoubleLine(L["Total"], Skada:FormatNumberSecret(rawAmount), 1,1,1)
			
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
		local raidHPS = getRaidHPS(set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(raidHPS), true)
	end

	function hpsmod:Update(win, set)
		local healingSet = Skada.NativeAPI:GetSessionView(set, 2)
		if not healingSet then return end
		
		local sources = healingSet.combatSources or {}
		
		-- Secret detection
		local hasSecretAPI = issecretvalue ~= nil
		local hasSecretValues = false
		local max = 0
		local nr = 1
		
		for _, player in pairs(sources) do
			local amountVal = player.totalAmount
			if amountVal and hasSecretAPI and issecretvalue(amountVal) then
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
			local rawAmount = player.totalAmount or 0
			local isSecretAmount = hasSecretAPI and rawAmount and issecretvalue(rawAmount)
			local amount = 0
			if not isSecretAmount then
				amount = tonumber(rawAmount) or 0
			end
			
			if amount > 0 or isSecretAmount then
				local hps = getHPS(healingSet, player)
				
				-- Normalize player name/id
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
					d.valuetext = Skada:FormatNumberSecret(hps)
				else
					d.id = player.sourceGUID or playerName
					d.value = Skada:SafeNumber(hps)
					d.valuetext = Skada:FormatNumber(hps)
					if hps > max then
						max = hps
					end
				end
				
				d.class = player.class or player.classFilename
				d.role = player.role
				d.order = nr

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = hasSecretValues and (1000 - 1) or (max > 0 and max or 1)
	end

	function mod:OnEnable()
		playermod.metadata = {} -- Remove tooltip for spell list
		hpsmod.metadata = {showspots = true, tooltip = hps_tooltip, icon = "Interface\\Icons\\spell_nature_healingtouch"}
		mod.metadata = {click1 = playermod, showspots = true, columns = {Healing = true, HPS = true, Percent = true}, icon = "Interface\\Icons\\spell_nature_healingtouch"}

		-- Note: In WoW 12.0.0+, we don't register combat log events
		-- Data comes from NativeAPI polling instead

		Skada:AddFeed(L["Healing: Personal HPS"], function()
			if Skada.current then
				local player = Skada:find_player(Skada.current, UnitGUID("player"))
				if player then
					local hps = getHPS(Skada.current, player)
					return Skada:FormatNumberSecret(hps).." "..L["HPS"]
				end
			end
		end)
		Skada:AddFeed(L["Healing: Raid HPS"], function()
			if Skada.current then
				local raidHps = getRaidHPS(Skada.current)
				return Skada:FormatNumberSecret(raidHps).." "..L["RHPS"]
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
		local raidHps = getRaidHPS(set)
		GameTooltip:AddDoubleLine(L["HPS"], Skada:FormatNumberSecret(raidHps), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		local total = getSetTotal(set)
		local raidHps = getRaidHPS(set)
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumberSecret(total), self.metadata.columns.Healing,
			Skada:FormatNumberSecret(raidHps), self.metadata.columns.HPS
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
