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
		
		local max = 0
		local nr = 1
		local totalDamage = 0
		
		-- Calculate total first for percentage
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				totalDamage = totalDamage + Skada:SafeNumber(spell.totalAmount)
			end
		end
		
		for _, spell in pairs(spells) do
			if type(spell) == "table" and spell.totalAmount then
				local amount = Skada:SafeNumber(spell.totalAmount)
				if amount > 0 then
					local spellID = spell.spellID or 0
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.id = spellID
					
					-- Get spell name from spellID
					local spellInfo = spellID > 0 and C_Spell.GetSpellInfo(spellID)
					d.label = spellInfo and spellInfo.name or ("Spell " .. tostring(spellID))
					
					d.value = amount
					d.valuetext = Skada:FormatNumber(amount)..(" (%02.1f%%)"):format(amount / math.max(1, totalDamage) * 100)
					d.icon = Skada:GetSpellIcon(spellID)
					
					if amount > max then
						max = amount
					end
					nr = nr + 1
				end
			end
		end
		win.metadata.maxvalue = max
	end

	-- Damage overview.
	function mod:Update(win, set)
		if not set then return end
		
		-- 0 = DamageDone
		local view = Skada.NativeAPI:GetSessionView(set, 0)
		if not view then return end
		
		-- Max value.
		local max = 0
		local nr = 1
		
		-- Calculate total damage first for percentages
		local totalDamage = 0
		local sources = view.combatSources or {}
		for _, player in pairs(sources) do
			-- Try to get damage value safely
			local damage = 0
			local success, damageValue = pcall(function() return player.totalAmount end)
			if success and type(damageValue) == "number" then
				damage = Skada:SafeNumber(damageValue)
			end
			totalDamage = totalDamage + damage
		end
		
		for _, player in pairs(sources) do
			-- Try to get damage value safely
			local damage = 0
			local success, damageValue = pcall(function() return player.totalAmount end)
			if success and type(damageValue) == "number" then
				damage = Skada:SafeNumber(damageValue)
			end
			
			if damage > 0 then
					local dps = getDPS(set, player)
					
					local playerName = player.name or player.unitName
					local playerID = player.sourceGUID

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.label = playerName

					Skada:FormatValueText(d,
						Skada:FormatNumber(damage), self.metadata.columns.Damage,
						Skada:FormatNumber(dps), self.metadata.columns.DPS,
						string.format("%02.1f%%", damage / math.max(1, totalDamage) * 100), self.metadata.columns.Percent
					)

					d.value = Skada:SafeNumber(dps)
					d.id = playerID
					d.class = player.class or player.classFilename
					d.role = player.role
					if dps > max then
						max = dps
					end
					nr = nr + 1
				end
			end

		win.metadata.maxvalue = max
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
		local damage = Skada:SafeNumber(player.totalAmount or 0)
		local dps = Skada:SafeNumber(player.amountPerSecond or 0)
		
		tooltip:AddLine((player.name or "Unknown").." - "..L["DPS"])
		tooltip:AddDoubleLine(L["Segment time"], totaltime.."s", 255,255,255,255,255,255)
		tooltip:AddDoubleLine(L["Damage done"], Skada:FormatNumber(damage), 255,255,255,255,255,255)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(dps), 255,255,255,255,255,255)
		
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
					local val = Skada:SafeNumber(s.totalAmount or 0)
					local percent = damage > 0 and (val / damage) * 100 or 0
					tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 255,255,255,255,255,255)
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
			local playerDamage = Skada:SafeNumber(player.totalAmount or 0)
			local totalDamage = 0
			
			-- 0 = DamageDone
			local view = Skada.NativeAPI:GetSessionView(set, 0)
			if view then
				local sources = view.combatSources or view.participants or {}
				for _, p in pairs(sources) do
					local dmg = Skada:SafeNumber(p.totalAmount or 0)
					totalDamage = totalDamage + dmg
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
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(getRaidDPS(set)), true)
	end

	function dpsmod:Update(win, set)
		if not set then return end
		
		-- 0 = DamageDone
		local view = Skada.NativeAPI:GetSessionView(set, 0)
		if not view then return end
		
		local max = 0
		local nr = 1

		local sources = view.combatSources or {}
		for _, player in pairs(sources) do
			local dps = getDPS(set, player)

			if dps > 0 then
				local playerName = player.name or player.unitName
				local playerID = player.sourceGUID
				
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = playerName
				d.id = playerID
				d.value = dps
				d.class = player.class or player.classFilename
				d.role = player.role
				d.valuetext = Skada:FormatNumber(dps)
				if dps > max then
					max = dps
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = dps_tooltip}
		dpsmod.metadata = {showspots = true, tooltip = dps_tooltip, icon = "Interface\\Icons\\Inv_throwingaxe_02"}
		mod.metadata = {click1 = playermod, post_tooltip = damage_tooltip, showspots = true, columns = {Damage = true, DPS = true, Percent = true}, icon = "Interface\\Icons\\Inv_throwingaxe_01"}

		Skada:AddFeed(L["Damage: Personal DPS"], function()
			if Skada.current then
				local player = Skada:find_player(Skada.current, UnitGUID("player"))
				if player then
					return Skada:FormatNumber(getDPS(Skada.current, player)).." "..L["DPS"]
				end
			end
		end)
		Skada:AddFeed(L["Damage: Raid DPS"], function()
			if Skada.current then
				return Skada:FormatNumber(getRaidDPS(Skada.current)).." "..L["RDPS"]
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
		GameTooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(getRaidDPS(set)), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		-- Calculate total damage from session view
		local totalDamage = 0
		if set then
			-- 0 = DamageDone
			local view = Skada.NativeAPI:GetSessionView(set, 0)
			if view then
				local sources = view.combatSources or {}
				for _, player in pairs(sources) do
					local damage = player.damage or player.totalAmount or 0
					totalDamage = totalDamage + Skada:SafeNumber(damage)
				end
			end
		end
		
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumber(totalDamage), self.metadata.columns.Damage,
			Skada:FormatNumber(getRaidDPS(set)), self.metadata.columns.DPS
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
