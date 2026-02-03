local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("Healing", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Healing then return end

	local mod = Skada:NewModule(L["Healing"])
	local playermod = Skada:NewModule(L["Healing spell list"])
	local DAMAGE_TYPE = 2 -- Healing

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label .. L["'s Healing"]
	end

	function playermod:Update(win, set)
		ModuleBase:UpdateSpellList(win, self.playerid, set, DAMAGE_TYPE, {valueKey = "totalAmount"})
	end

	function mod:Update(win, set)
		ModuleBase:UpdatePlayerList(win, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateKey = "amountPerSecond",
			columns = {"Healing", "HPS", "Percent"},
			getRateFunc = function(s, p) return ModuleBase:GetPlayerRate(s, p, DAMAGE_TYPE) end,
			includePercent = true
		})
	end

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		local player = Skada:find_player(set, id)
		if not player then return end

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if not view then return end

		local totaltime = Skada:GetSetTime(view)
		local rawAmount = player.totalAmount or 0
		local rawHps = player.amountPerSecond or 0

		tooltip:AddLine((player.name or label) .. " - " .. L["HPS"])
		tooltip:AddDoubleLine(L["Segment time"], totaltime .. "s", 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(L["Healing done"], Skada:FormatNumberSecret(rawAmount), 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumberSecret(rawHps), 1, 1, 1, 1, 1, 1)

		-- Add top 3 spells
		local spells = Skada.NativeAPI:GetPlayerSpells(id, view, DAMAGE_TYPE)
		if spells then
			local sorted = {}
			for _, s in pairs(spells) do
				if type(s) == "table" and s.totalAmount then
					table.insert(sorted, s)
				end
			end
			table.sort(sorted, function(a, b)
				return SecretHelper:SafeNumber(a.totalAmount) > SecretHelper:SafeNumber(b.totalAmount)
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

					if SecretHelper:HasSecretAPI() and issecretvalue(rawVal) then
						tooltip:AddDoubleLine(name, Skada:FormatNumberSecret(rawVal), 1, 1, 1, 1, 1, 1)
					else
						local val = tonumber(rawVal) or 0
						local playerVal = SecretHelper:SafeNumber(rawAmount)
						local percent = playerVal > 0 and (val / playerVal) * 100 or 0
						tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1, 1, 1, 1, 1, 1)
					end
				end
			end
		end
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = hps_tooltip}
		mod.metadata = {click1 = playermod, showspots = true, columns = {Healing = true, HPS = true, Percent = true}, icon = "Interface\\Icons\\spell_nature_healingtouch"}

		ModuleBase:AddStandardFeeds(L["Healing: Personal HPS"], L["Healing: Raid HPS"], DAMAGE_TYPE, L["HPS"], L["RHPS"])
		Skada:AddMode(self, L["Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
		ModuleBase:RemoveStandardFeeds(L["Healing: Personal HPS"], L["Healing: Raid HPS"])
	end

	function mod:AddToTooltip(set, tooltip)
		local raidHps = ModuleBase:GetRaidRate(set, DAMAGE_TYPE)
		GameTooltip:AddDoubleLine(L["HPS"], Skada:FormatNumberSecret(raidHps), 1, 1, 1)
	end

	function mod:FormatSetSummary(datasetItem, set)
		ModuleBase:FormatSetSummary(datasetItem, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateType = DAMAGE_TYPE,
			columns = {"Healing", "HPS"}
		})
	end
end)
