local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("Damage", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Damage then return end

	local mod = Skada:NewModule(L["Damage"])
	local playermod = Skada:NewModule(L["Damage spell list"])
	local DAMAGE_TYPE = 0 -- DamageDone

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label .. L["'s Damage"]
	end

	function playermod:Update(win, set)
		ModuleBase:UpdateSpellList(win, self.playerid, set, DAMAGE_TYPE, {valueKey = "totalAmount"})
	end

	function mod:Update(win, set)
		if not set then return end
		
		-- Wrap ModuleBase call in pcall to catch errors during combat
		local success, err = pcall(ModuleBase.UpdatePlayerList, ModuleBase, win, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateKey = "amountPerSecond",
			columns = {"Damage", "DPS", "Percent"},
			getRateFunc = function(s, p) return ModuleBase:GetPlayerRate(s, p, 1) end,
			includePercent = true
		})
		
		if not success then
			-- Print error to chat frame directly
			print("SKADA ERROR:", err)
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000SKADA ERROR:|r " .. tostring(err))
		end
	end

	local function dps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		local player = Skada:find_player(set, id)
		if not player then return end

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if not view then return end

		local totaltime = Skada:GetSetTime(view)
		local rawDamage = player.totalAmount or 0
		local rawDps = player.amountPerSecond or 0

		tooltip:AddLine((player.name or label) .. " - " .. L["DPS"])
		tooltip:AddDoubleLine(L["Segment time"], totaltime .. "s", 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage done"], Skada:FormatNumberSecret(rawDamage), 1, 1, 1, 1, 1, 1)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumberSecret(rawDps), 1, 1, 1, 1, 1, 1)

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
						local playerVal = SecretHelper:SafeNumber(rawDamage)
						local percent = playerVal > 0 and (val / playerVal) * 100 or 0
						tooltip:AddDoubleLine(name, Skada:FormatNumber(val) .. " (" .. string.format("%02.1f%%", percent) .. ")", 1, 1, 1, 1, 1, 1)
					end
				end
			end
		end
	end

	local function damage_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end
		local player = Skada:find_player(set, id)
		if not player then return end

		local rawPlayerDamage = player.totalAmount or 0
		if SecretHelper:HasSecretAPI() and issecretvalue(rawPlayerDamage) then
			return
		end

		local playerDamage = tonumber(rawPlayerDamage) or 0
		local totalDamage = 0

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if view then
			local sources = view.combatSources or view.participants or {}
			for _, p in pairs(sources) do
				totalDamage = totalDamage + SecretHelper:SafeNumber(p.totalAmount)
			end
		end

		if totalDamage > 0 then
			local percent = (playerDamage / totalDamage) * 100
			tooltip:AddDoubleLine(L["Damage share"], ("%02.1f%%"):format(percent), 255, 255, 255, 255, 255, 255)
		end
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = dps_tooltip}
		mod.metadata = {click1 = playermod, post_tooltip = damage_tooltip, showspots = true, columns = {Damage = true, DPS = true, Percent = true}, icon = "Interface\\Icons\\Inv_throwingaxe_01"}

		ModuleBase:AddStandardFeeds(L["Damage: Personal DPS"], L["Damage: Raid DPS"], 1, L["DPS"], L["RDPS"])
		Skada:AddMode(self, L["Damage"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
		ModuleBase:RemoveStandardFeeds(L["Damage: Personal DPS"], L["Damage: Raid DPS"])
	end

	function mod:AddToTooltip(set, tooltip)
		local raidDps = ModuleBase:GetRaidRate(set, 1)
		GameTooltip:AddDoubleLine(L["DPS"], Skada:FormatNumberSecret(raidDps), 1, 1, 1)
	end

	function mod:FormatSetSummary(datasetItem, set)
		ModuleBase:FormatSetSummary(datasetItem, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateType = 1,
			columns = {"Damage", "DPS"}
		})
	end
end)
