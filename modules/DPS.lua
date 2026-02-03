local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("DPS", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.DPS then return end

	local mod = Skada:NewModule(L["DPS"])
	local DAMAGE_TYPE = 0 -- DamageDone

	function mod:Update(win, set)
		if not set then return end

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if not view then return end

		local sources = view.combatSources or {}
		local hasSecretAPI = SecretHelper:HasSecretAPI()

		-- Detect secrets
		local hasSecretValues = false
		for _, player in pairs(sources) do
			local dpsVal = player.amountPerSecond or player.rate
			if dpsVal and hasSecretAPI and issecretvalue(dpsVal) then
				hasSecretValues = true
				break
			end
		end

		-- Update window metadata
		SecretHelper:UpdateWindowMetadata(win, hasSecretValues)

		local max = 0
		local nr = 1

		for _, player in pairs(sources) do
			local rawDps = player.amountPerSecond or player.rate
			local isSecretDps = hasSecretAPI and rawDps and issecretvalue(rawDps)
			local dps = 0
			if not isSecretDps then
				dps = tonumber(rawDps) or 0
			end

			if dps > 0 or isSecretDps then
				local playerName = SecretHelper:GetPlayerName(player)
				if playerName then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.label = playerName

					if hasSecretValues then
						d.id = "combat_" .. nr
						d.value = 1000 - nr
						d.valuetext = Skada:FormatNumberSecret(rawDps)
					else
						d.id = player.sourceGUID or playerName
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

		win.metadata.maxvalue = SecretHelper:GetMaxValue(hasSecretValues, max, nr - 1)
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
