local _, Skada = ...
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("HPS", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.HPS then return end

	local mod = Skada:NewModule(L["HPS"])
	local DAMAGE_TYPE = 2 -- Healing

	function mod:Update(win, set)
		if type(set) ~= "table" then return end

		local view = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		if type(view) ~= "table" then return end

		local sources = view.combatSources
		if type(sources) ~= "table" or issecretvalue(sources) then return end

		-- Detect secrets
		local hasSecretValues = SecretHelper:DetectSecrets(sources, "amountPerSecond")
			or SecretHelper:DetectSecrets(sources, "totalAmount")

		-- Update window metadata
		SecretHelper:UpdateWindowMetadata(win, hasSecretValues)

		local max = 0
		local nr = 1

		for _, player in ipairs(sources) do
			if type(player) == "table" and not issecretvalue(player) then
				local rawAmount = player.totalAmount
				local isSecretAmount = issecretvalue(rawAmount)
				local amount = 0
				if not isSecretAmount then
					amount = tonumber(rawAmount) or 0
				end

				if amount > 0 or isSecretAmount then
					local hps = ModuleBase:GetPlayerRate(set, player, DAMAGE_TYPE)

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.label = SecretHelper:GetPlayerLabel(player, nr)

					if hasSecretValues then
						d.id = "combat_" .. nr
						d.sourceGUID = player.sourceGUID
						d.sourceCreatureID = player.sourceCreatureID
						d.value = SecretHelper:GetDisplayValue(hps, nr, #sources)
						d.valuetext = Skada:FormatNumberSecret(hps)
					else
						local guid = player.sourceGUID
						if type(guid) == "string" and not issecretvalue(guid) then
							d.id = guid
						else
							d.id = "player_" .. nr
						end
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

		win.metadata.maxvalue = SecretHelper:GetMaxValue(hasSecretValues, max, #sources)
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
