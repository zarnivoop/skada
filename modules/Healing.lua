local _, Skada = ...
Skada:AddLoadableModule("Healing", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Healing then return end

	local mod = Skada:NewModule(L["Healing"])
	local playermod = Skada:NewModule(L["Healing spell list"])
	local hpsmod = Skada:NewModule(L["HPS"])

	local pairs = pairs
	local ipairs = ipairs

	local function getHPS(set, player)
		local totaltime = Skada:PlayerActiveTime(set, player)
		return (player.healing or 0) / math.max(1,totaltime)
	end

	local function getRaidHPS(set)
		if set.time > 0 then
			return set.healing / math.max(1, set.time)
		else
			local endtime = set.endtime
			if not endtime then
				endtime = time()
			end
			return set.healing / math.max(1, endtime - set.starttime)
		end
	end

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label..L["'s Healing"]
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, self.playerid)
		local max = 0
		local nr = 1
		
		if player and player.healingspells then
			for spellname, spell in pairs(player.healingspells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = spell.id
				d.label = spellname
				d.value = spell.healing
				d.valuetext = Skada:FormatNumber(spell.healing)..(" (%02.1f%%)"):format(spell.healing / math.max(1, player.healing) * 100)
				d.icon = Skada:GetSpellIcon(spell.id)
				
				if spell.healing > max then
					max = spell.healing
				end
				nr = nr + 1
			end
		end
		win.metadata.maxvalue = max
	end

	-- Healing overview.
	function mod:Update(win, set)
		local max = 0
		local nr = 1

		for i, player in ipairs(set.players) do
			if (player.healing or 0) > 0 then
				local hps = getHPS(set, player)

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = player.name

				Skada:FormatValueText(d,
					Skada:FormatNumber(player.healing or 0), self.metadata.columns.Healing,
					Skada:FormatNumber(hps), self.metadata.columns.HPS,
					string.format("%02.1f%%", (player.healing or 0) / set.healing * 100), self.metadata.columns.Percent
				)

				d.value = player.healing or 0
				d.id = player.id
				d.class = player.class
				d.role = player.role
				if (player.healing or 0) > max then
					max = player.healing or 0
				end
				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	-- Tooltip for a specific player.
	local function hps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			local activetime = Skada:PlayerActiveTime(set, player)
			local totaltime = Skada:GetSetTime(set)
			tooltip:AddLine(player.name.." - "..L["HPS"])
			tooltip:AddDoubleLine(L["Segment time"], totaltime.."s", 255,255,255,255,255,255)
			tooltip:AddDoubleLine(L["Active time"], activetime.."s", 255,255,255,255,255,255)
			tooltip:AddDoubleLine(L["Healing done"], Skada:FormatNumber(player.healing), 255,255,255,255,255,255)
			tooltip:AddDoubleLine(Skada:FormatNumber(player.healing) .. " / " .. activetime .. ":", ("%02.1f"):format(player.healing / math.max(1,activetime)), 255,255,255,255,255,255)
		end
	end

	-- HPS-only view
	function hpsmod:FormatSetSummary(datasetItem, set)
		Skada:FormatValueText(datasetItem, Skada:FormatNumber(getRaidHPS(set)), true)
	end

	function hpsmod:Update(win, set)
		local max = 0
		local nr = 1

		for i, player in ipairs(set.players) do
			local hps = getHPS(set, player)

			if hps > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.label = player.name
				d.id = player.id
				d.value = hps
				d.class = player.class
				d.role = player.role
				d.valuetext = Skada:FormatNumber(hps)
				if hps > max then
					max = hps
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = hps_tooltip}
		hpsmod.metadata = {showspots = true, tooltip = hps_tooltip, icon = "Interface\\Icons\\spell_nature_healingtouch"}
		mod.metadata = {click1 = playermod, showspots = true, columns = {Healing = true, HPS = true, Percent = true}, icon = "Interface\\Icons\\spell_nature_healingtouch"}

		-- Note: In WoW 12.0.0+, we don't register combat log events
		-- Data comes from NativeAPI polling instead

		Skada:AddFeed(L["Healing: Personal HPS"], function()
			if Skada.current then
				local player = Skada:find_player(Skada.current, UnitGUID("player"))
				if player then
					return Skada:FormatNumber(getHPS(Skada.current, player)).." "..L["HPS"]
				end
			end
		end)
		Skada:AddFeed(L["Healing: Raid HPS"], function()
			if Skada.current then
				return Skada:FormatNumber(getRaidHPS(Skada.current)).." "..L["RHPS"]
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
		GameTooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(getRaidHPS(set)), 1,1,1)
	end

	function mod:FormatSetSummary(datasetItem,set)
		Skada:FormatValueText(
			datasetItem,
			Skada:FormatNumber(set.healing), self.metadata.columns.Healing,
			Skada:FormatNumber(getRaidHPS(set)), self.metadata.columns.HPS
		)
	end

	-- Called by Skada when a new player is added to a set.
	function mod:AddPlayerAttributes(player)
		if not player.healing then
			player.healing = 0
			player.healingspells = {}
		end
	end

	-- Called by Skada when a new set is created.
	function mod:AddSetAttributes(set)
		if not set.healing then
			set.healing = 0
		end
	end
end)
