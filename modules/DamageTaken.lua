local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("DamageTaken", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.DamageTaken then return end

	local mod = Skada:NewModule(L["Damage taken"])
	local playermod = Skada:NewModule(L["Damage taken details"])
	local DAMAGE_TYPE = 7 -- DamageTaken

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = label .. L["'s Damage taken"]
	end

	function playermod:Update(win, set)
		ModuleBase:UpdateSpellList(win, self.playerid, set, DAMAGE_TYPE)
	end

	function mod:Update(win, set)
		ModuleBase:UpdatePlayerList(win, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateKey = "amountPerSecond",
			columns = {"Damage", "DTPS", "Percent"},
			getRateFunc = function(s, p) return ModuleBase:GetPlayerRate(s, p, DAMAGE_TYPE) end,
			formatRate = function(rate) return string.format("%02.1f", rate) end,
			includePercent = true
		})
	end

	function mod:OnEnable()
		playermod.metadata = {}
		mod.metadata = {click1 = playermod, showspots = true, columns = {Damage = true, DTPS = true, Percent = true}, icon = "Interface\\Icons\\Inv_shield_06"}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:FormatSetSummary(datasetItem, set)
		ModuleBase:FormatSetSummary(datasetItem, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount",
			rateType = DAMAGE_TYPE,
			columns = {"Damage", "DTPS"}
		})
	end
end)
