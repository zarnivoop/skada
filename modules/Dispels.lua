local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("Dispels", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Dispels then return end

	local mod = Skada:NewModule(L["Dispels"])
	local playermod = Skada:NewModule(L["Dispels spell list"])
	local DAMAGE_TYPE = 6 -- Dispels

	function playermod:Enter(win, id, label)
		playermod.playerid = id
		playermod.title = tostring(label) .. L["'s Dispels"]
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
		mod.metadata = {click1 = playermod, showspots = true, icon = "Interface\\Icons\\Spell_holy_dispelmagic"}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		local total = ModuleBase:GetSetTotal(set, DAMAGE_TYPE)
		GameTooltip:AddDoubleLine(L["Dispels"], Skada:FormatNumberSecret(total), 1, 1, 1)
	end

	function mod:FormatSetSummary(datasetItem, set)
		local total = ModuleBase:GetSetTotal(set, DAMAGE_TYPE)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(total), true)
	end
end)
