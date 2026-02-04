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
		
		local success, err = pcall(ModuleBase.UpdatePlayerList, ModuleBase, win, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateKey = "amountPerSecond",
			columns = {"Damage", "DPS", "Percent"},
			getRateFunc = function(s, p) return ModuleBase:GetPlayerRate(s, p, 1) end,
			includePercent = true
		})
		
		if not success then
			print("SKADA ERROR:", err)
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000SKADA ERROR:|r " .. tostring(err))
		end
	end

	-- Use shared tooltip functions from ModuleBase
	local dps_tooltip = ModuleBase:CreatePlayerTooltip({
		damageType = DAMAGE_TYPE,
		valueKey = "totalAmount",
		rateKey = "amountPerSecond",
		labelDamage = L["Damage done"],
		labelRate = L["DPS"],
		spellValueKey = "totalAmount"
	})

	local damage_tooltip = ModuleBase:CreateDamageShareTooltip({
		damageType = DAMAGE_TYPE,
		labelShare = L["Damage share"]
	})

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
