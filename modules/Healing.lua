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
		playermod.title = tostring(label) .. L["'s Healing"]
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

	-- Use shared tooltip function from ModuleBase
	local hps_tooltip = ModuleBase:CreatePlayerTooltip({
		damageType = DAMAGE_TYPE,
		valueKey = "totalAmount",
		rateKey = "amountPerSecond",
		labelDamage = L["Healing done"],
		labelRate = L["HPS"],
		spellValueKey = "totalAmount"
	})

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
