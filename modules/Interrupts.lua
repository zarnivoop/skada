local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("Interrupts", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Interrupts then return end

	local mod = Skada:NewModule(L["Interrupts"])
	local playermod = Skada:NewModule(L["Interrupt spells"])
	local DAMAGE_TYPE = 5 -- Interrupts

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = tostring(label) .. L["'s Interrupts"]
	end

	function playermod:Update(win, set)
		ModuleBase:UpdateSpellList(win, self.playerid, set, DAMAGE_TYPE)
	end

	function mod:Update(win, set)
		ModuleBase:UpdateSimpleList(win, set, {
			damageType = DAMAGE_TYPE,
			valueKey = "totalAmount"
		})
	end

	function mod:OnEnable()
		mod.metadata = {click1 = playermod, showspots = true, icon = "Interface\\Icons\\Ability_rogue_kidneyshot"}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		local total = ModuleBase:GetSetTotal(set, DAMAGE_TYPE)
		GameTooltip:AddDoubleLine(L["Interrupts"], Skada:FormatNumberSecret(total), 1, 1, 1)
	end

	function mod:FormatSetSummary(datasetItem, set)
		local total = ModuleBase:GetSetTotal(set, DAMAGE_TYPE)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(total), true)
	end
end)
