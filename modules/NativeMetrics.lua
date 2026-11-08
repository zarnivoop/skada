local _, Skada = ...
local ModuleBase = Skada.ModuleBase

-- Shared factory for straightforward C_DamageMeter modes. Damage/Healing keep
-- their richer feeds/tooltips; Threat/Deaths/Compare have special data flows.
local function RegisterMetric(spec)
	local key = spec.key
	local damageType = spec.damageType
	local style = spec.style or "players"

	Skada:AddLoadableModule(key, nil, function(Skada, L)
		if Skada.db.profile.modulesBlocked[key] then return end

		local displayLabel = L[spec.label] or spec.label
		local displayCategory = L[spec.category or "Other"] or L["Other"]
		local mod = Skada:NewModule(displayLabel)
		local playermod = Skada:NewModule(displayLabel .. " details")

		function playermod:Enter(win, id, barLabel)
			playermod.playerid = id
			if issecretvalue(barLabel) then
				playermod.title = displayLabel
			else
				playermod.title = tostring(barLabel) .. " - " .. displayLabel
			end
		end

		function playermod:Update(win, set)
			ModuleBase:UpdateSpellList(win, self.playerid, set, damageType)
		end

		if style == "players" then
			local tooltip = ModuleBase:CreatePlayerTooltip({
				damageType = damageType,
				valueKey = spec.valueKey or "totalAmount",
				rateKey = spec.rateKey or "amountPerSecond",
				labelDamage = displayLabel,
				labelRate = spec.rateLabel or "DPS",
				spellValueKey = spec.valueKey or "totalAmount",
			})

			function mod:Update(win, set)
				ModuleBase:UpdatePlayerList(win, set, {
					damageType = damageType,
					valueKey = spec.valueKey or "totalAmount",
					rateKey = spec.rateKey or "amountPerSecond",
					columns = spec.orderColumns,
					formatRate = spec.formatRate,
					getRateFunc = function(s, p) return ModuleBase:GetPlayerRate(s, p, damageType) end,
					includePercent = spec.includePercent ~= false,
				})
			end

			function mod:OnEnable()
				playermod.metadata = { tooltip = tooltip }
				mod.metadata = {
					click1 = playermod,
					showspots = true,
					columns = spec.columns,
					icon = spec.icon,
				}
				Skada:AddMode(self, displayCategory)
			end
		else
			function mod:Update(win, set)
				ModuleBase:UpdateSimpleList(win, set, {
					damageType = damageType,
					valueKey = spec.valueKey or "totalAmount",
				})
			end

			function mod:OnEnable()
				playermod.metadata = {}
				mod.metadata = {
					click1 = playermod,
					showspots = true,
					icon = spec.icon,
				}
				Skada:AddMode(self, displayCategory)
			end
		end

		function mod:OnDisable()
			Skada:RemoveMode(self)
		end

		function mod:AddToTooltip(set, tooltipFrame)
			local total = ModuleBase:GetSetTotal(set, damageType, { valueKey = spec.valueKey or "totalAmount" })
			GameTooltip:AddDoubleLine(displayLabel, Skada:FormatNumberSecret(total), 1, 1, 1)
		end

		function mod:FormatSetSummary(datasetItem, set)
			if style == "players" then
				ModuleBase:FormatSetSummary(datasetItem, set, {
					damageType = damageType,
					valueKey = spec.valueKey or "totalAmount",
					rateType = damageType,
					columns = spec.orderColumns,
				})
			else
				local total = ModuleBase:GetSetTotal(set, damageType, { valueKey = spec.valueKey or "totalAmount" })
				-- Simple modes have no column spec, so the total row must use
				-- the single value-text path or it renders as an empty row.
				datasetItem.valuetext = Skada:FormatNumberSecret(total)
			end
		end
	end)
end

RegisterMetric({
	key = "Absorbs",
	label = "Absorbs",
	damageType = 4,
	category = "Healing",
	style = "players",
	columns = { Absorbs = true, AbsorbRate = true, Percent = true },
	orderColumns = { "Absorbs", "AbsorbRate", "Percent" },
	rateLabel = "APS",
	icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
})

RegisterMetric({
	key = "AvoidableDamageTaken",
	label = "Avoidable damage",
	damageType = 8,
	category = "Damage taken",
	style = "players",
	columns = { Avoidable = true, AvoidableRate = true, Percent = true },
	orderColumns = { "Avoidable", "AvoidableRate", "Percent" },
	rateLabel = "ADPS",
	icon = "Interface\\Icons\\Ability_Defend",
})

RegisterMetric({
	key = "EnemyDamageTaken",
	label = "Enemy damage taken",
	damageType = 10,
	category = "Other",
	style = "players",
	columns = { EnemyDamage = true, EnemyRate = true, Percent = true },
	orderColumns = { "EnemyDamage", "EnemyRate", "Percent" },
	rateLabel = "DPS",
	icon = "Interface\\Icons\\Ability_DualWield",
})

RegisterMetric({
	key = "DamageTaken",
	label = "Damage taken",
	damageType = 7,
	category = "Other",
	style = "players",
	columns = { Damage = true, DTPS = true, Percent = true },
	orderColumns = { "Damage", "DTPS", "Percent" },
	rateLabel = "DTPS",
	formatRate = function(rate) return string.format("%02.1f", rate) end,
	icon = "Interface\\Icons\\Inv_shield_06",
})

RegisterMetric({
	key = "Interrupts",
	label = "Interrupts",
	damageType = 5,
	category = "Other",
	style = "simple",
	icon = "Interface\\Icons\\Ability_rogue_kidneyshot",
})

RegisterMetric({
	key = "Dispels",
	label = "Dispels",
	damageType = 6,
	category = "Other",
	style = "simple",
	icon = "Interface\\Icons\\Spell_holy_dispelmagic",
})
