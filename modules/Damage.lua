local _, Skada = ...
Skada:AddLoadableModule("Damage", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Damage then return end

	local mod = Skada:NewModule(L["Damage"])
	local playermod = Skada:NewModule(L["Damage spell list"])
	local dpsmod = Skada:NewModule(L["DPS"])

	local pairs = pairs
	local ipairs = ipairs

	local function getDPS(set, player)
		if player.native_dps then
			return player.native_dps
		end
		local totaltime = Skada:PlayerActiveTime(set, player)
		return (player.damage or 0) / math.max(1,totaltime)
	end

	local function getRaidDPS(set)
		if set.time > 0 then
			return (set.damage or 0) / math.max(1, set.time)
		else
			local endtime = set.endtime
			if not endtime then
				endtime = time()
			end
			return (set.damage or 0) / math.max(1, endtime - set.starttime)
		end
	end

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Damage"]
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, self.playerid)
		local max = 0
		local nr = 1
		
		if player and player.damagespells then
			for spellname, spell in pairs(player.damagespells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = spell.id
				d.label = spellname
				d.value = spell.damage
				d.valuetext = Skada:FormatNumber(spell.damage)..(" (%02.1f%%)"):format(spell.damage / math.max(1, player.damage) * 100)
				d.icon = Skada:GetSpellIcon(spell.id)
				
				if spell.damage > max then
					max = spell.damage
				end
				nr = nr + 1
			end
		end
		win.metadata.maxvalue = max
	end

	-- Damage overview.
	function mod:Update(win, set)
		-- Max value.
		local max = 0

		local nr = 1
		for i, player in ipairs(set.players) do
			local damage = player.damage or 0
			if damage > 0 then
				local dps = getDPS(set, player)

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = player.name

				Skada:FormatValueText(d,
					Skada:FormatNumber(damage), self.metadata.columns.Damage,
					Skada:FormatNumber(dps), self.metadata.columns.DPS,
					string.format("%02.1f%%", damage / math.max(1, set.damage or 1) * 100), self.metadata.columns.Percent
				)

				d.value = damage
				d.id = player.id
				d.class = player.class
				d.role = player.role
				if damage > max then
					max = damage
				end
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	-- Tooltip for a specific player.
	local function dps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			local activetime = Skada:PlayerActiveTime(set, player)
			local totaltime = Skada:GetSetTime(set)
			tooltip:AddLine(player.name.." - "..L["DPS"])
			tooltip:AddDoubleLine(L["Segment time"], totaltime.."s", 255,255,255,255,255,255)
			tooltip:AddDoubleLine(L["Active time"], activetime.."s", 255,255,255,255,255,255)
			tooltip:AddDoubleLine(L["Damage done"], Skada:FormatNumber(player.damage), 255,255,255,255,255,255)
			tooltip:AddDoubleLine(Skada:FormatNumber(player.damage) .. " / " .. activetime .. ":", ("%02.1f"):format(player.damage / math.max(1,activetime)), 255,255,255,255,255,255)
		end
	end

	-- Tooltip for a specific player.
	-- This is a post-tooltip
	local function damage_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			local activetime = Skada:PlayerActiveTime(set, player)
			local totaltime = Skada:GetSetTime(set)
			tooltip:AddDoubleLine(L["Activity"], ("%02.1f%%"):format(activetime/math.max(1,totaltime)*100), 255,255,255,255,255,255)
		end
	end

	-- DPS-only view
	function dpsmod:FormatSetSummary(datasetItem, set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(getRaidDPS(set)), true)
	end

	function dpsmod:Update(win, set)
		local max = 0
		local nr = 1

		for i, player in ipairs(set.players) do
			local dps = getDPS(set, player)

			if dps > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = player.name
				d.id = player.id
				d.value = dps
				d.class = player.class
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

		-- Note: In WoW 12.0.0+, we don't register combat log events
		-- Data comes from NativeAPI polling instead

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
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumber(set.damage), self.metadata.columns.Damage,
			Skada:FormatNumber(getRaidDPS(set)), self.metadata.columns.DPS
		)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
		if not player.damage then
			player.damage = 0
			player.damagespells = {}
		end
		if not player.damaged then
			player.damaged = {}
		end
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
		if not set.damage then
			set.damage = 0
		end
	end
end)
