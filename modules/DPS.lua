local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("DPS", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.DPS then return end

	local mod = Skada:NewModule(L["DPS"])
	local DAMAGE_TYPE = 0 -- DamageDone

	function mod:Update(win, set)
		if type(set) ~= "table" then return end

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if type(view) ~= "table" then return end

		local sources = view.combatSources
		if type(sources) ~= "table" or issecretvalue(sources) then return end

		-- Detect secrets
		local hasSecretValues = SecretHelper:DetectSecrets(sources, "amountPerSecond")

		-- Update window metadata
		SecretHelper:UpdateWindowMetadata(win, hasSecretValues)

		local max = 0
		local nr = 1

		for _, player in ipairs(sources) do
			if type(player) == "table" and not issecretvalue(player) then
				local rawDps = player.amountPerSecond
				local isSecretDps = issecretvalue(rawDps)
				local dps = 0
				if not isSecretDps then
					dps = tonumber(rawDps) or 0
				end

				if dps > 0 or isSecretDps then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.label = SecretHelper:GetPlayerLabel(player, nr)

					if hasSecretValues then
						d.id = "combat_" .. nr
						d.sourceGUID = player.sourceGUID
						d.sourceCreatureID = player.sourceCreatureID
						d.value = SecretHelper:GetDisplayValue(rawDps, nr, #sources)
						d.valuetext = Skada:FormatNumberSecret(rawDps)
					else
						local guid = player.sourceGUID
						if type(guid) == "string" and not issecretvalue(guid) then
							d.id = guid
						else
							d.id = "player_" .. nr
						end
						d.value = dps
						d.valuetext = Skada:FormatNumber(dps)
						if dps > max then
							max = dps
						end
					end

					d.class = SecretHelper:GetPlayerClass(player)
					d.role = player.role
					d.order = nr

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = SecretHelper:GetMaxValue(hasSecretValues, max, #sources)
	end

	function mod:OnEnable()
		mod.metadata = {showspots = true, icon = "Interface\\Icons\\Inv_throwingaxe_02"}
		Skada:AddMode(self, L["Damage"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:FormatSetSummary(datasetItem, set)
		local raidDPS = ModuleBase:GetRaidRate(set, 1)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(raidDPS), true)
	end
end)
