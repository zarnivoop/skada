local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("HPS", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.HPS then return end

	local mod = Skada:NewModule(L["HPS"])
	local DAMAGE_TYPE = 2 -- Healing

	function mod:Update(win, set)
		if not set then return end

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if not view then return end

		local sources = view.combatSources or {}
		local hasSecretAPI = SecretHelper:HasSecretAPI()

		-- Detect secrets
		local hasSecretValues = false
		for _, player in pairs(sources) do
			local amountVal = player.totalAmount
			if amountVal and hasSecretAPI and issecretvalue(amountVal) then
				hasSecretValues = true
				break
			end
		end

		-- Update window metadata
		SecretHelper:UpdateWindowMetadata(win, hasSecretValues)

		local max = 0
		local nr = 1

		for _, player in pairs(sources) do
			local rawAmount = player.totalAmount or 0
			local isSecretAmount = hasSecretAPI and rawAmount and issecretvalue(rawAmount)
			local amount = 0
			if not isSecretAmount then
				amount = tonumber(rawAmount) or 0
			end

			if amount > 0 or isSecretAmount then
				local hps = ModuleBase:GetPlayerRate(set, player, DAMAGE_TYPE)
				local playerName = SecretHelper:GetPlayerName(player)

				if playerName then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.label = playerName

					if hasSecretValues then
						d.id = "combat_" .. nr
						d.value = 1000 - nr
						d.valuetext = Skada:FormatNumberSecret(hps)
					else
						d.id = player.sourceGUID or playerName
						d.value = SecretHelper:SafeNumber(hps)
						d.valuetext = Skada:FormatNumber(hps)
						if hps > max then
							max = hps
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
		mod.metadata = {showspots = true, icon = "Interface\\Icons\\spell_nature_healingtouch"}
		Skada:AddMode(self, L["Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:FormatSetSummary(datasetItem, set)
		local raidHPS = ModuleBase:GetRaidRate(set, DAMAGE_TYPE)
		Skada:FormatValueText(datasetItem, Skada:FormatNumberSecret(raidHPS), true)
	end
end)
