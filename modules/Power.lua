local _, Skada = ...
Skada:AddLoadableModule("Power", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Power then return end

	local mod = Skada:NewModule("Power")
	local PowerTypes = Enum.PowerType
	local GetSpellInfo = C_Spell.GetSpellInfo
	local GetSpellIcon = Skada.GetSpellIcon
	local FormatNumber = Skada.FormatNumber
	local GetPowerTypeInfo = GetPowerTypeInfo

	-- Map of power types to their icons (names are fetched dynamically from the game)
	local POWER_INFO = {
		[PowerTypes.Mana] = { icon = "Interface\\Icons\\Spell_magic_managain" },
		[PowerTypes.Rage] = { icon = "Interface\\Icons\\Ability_warrior_rampage" },
		[PowerTypes.Focus] = { icon = "Interface\\Icons\\Ability_hunter_focusedaim" },
		[PowerTypes.Energy] = { icon = "Interface\\Icons\\Ability_rogue_sprint" },
		[PowerTypes.RunicPower] = { icon = "Interface\\Icons\\Ability_deathknight_runicimpowerment" },
		[PowerTypes.HolyPower] = { icon = "Interface\\Icons\\Ability_paladin_beaconoflight" },
		[PowerTypes.Fury] = { icon = "Interface\\Icons\\Ability_demonhunter_demonspikes" },
		[PowerTypes.Maelstrom] = { icon = "Interface\\Icons\\Spell_shaman_maelstromweapon" },
		[PowerTypes.Insanity] = { icon = "Interface\\Icons\\Spell_shadow_shadowwordpain" },
		[PowerTypes.ComboPoints] = { icon = "Interface\\Icons\\Ability_rogue_eviscerate" },
		[PowerTypes.SoulShards] = { icon = "Interface\\Icons\\Spell_shadow_soulgem" },
		[PowerTypes.LunarPower] = { icon = "Interface\\Icons\\Ability_druid_eclipseorange" },
		[PowerTypes.ArcaneCharges] = { icon = "Interface\\Icons\\Spell_arcane_arcane01" },
		[PowerTypes.Pain] = { icon = "Interface\\Icons\\Ability_demonhunter_painbringer" }
	}

	-- Get localized power type name
	local function GetPowerTypeName(powerType)
		local powerInfo = GetPowerTypeInfo(powerType)
		return powerInfo and powerInfo.name or _G["POWER_TYPE_"..powerType] or tostring(powerType)
	end

	local function log_gain(set, gain)
		local player = Skada:get_player(set, gain.playerid, gain.playername)
		if not player then return end

		-- Initialize power tracking if needed
		if not player.power then
			player.power = {
				total = {},    -- Total gains by power type
				spells = {},   -- Spells by power type
				types = {}     -- Set of active power types
			}
		end
		if not set.power then
			set.power = {
				total = {},
				types = {}
			}
		end

		local ptype = gain.type
		-- Skip if power type is not recognized
		if not POWER_INFO[ptype] then return end

		-- Initialize power type tracking
		if not player.power.total[ptype] then
			player.power.total[ptype] = 0
			player.power.spells[ptype] = {}
			player.power.types[ptype] = true
		end
		if not set.power.total[ptype] then
			set.power.total[ptype] = 0
			set.power.types[ptype] = true
		end

		-- Add to totals
		player.power.total[ptype] = player.power.total[ptype] + gain.amount
		set.power.total[ptype] = set.power.total[ptype] + gain.amount

		-- Track by spell
		if not player.power.spells[ptype][gain.spellid] then
			player.power.spells[ptype][gain.spellid] = 0
		end
		player.power.spells[ptype][gain.spellid] = player.power.spells[ptype][gain.spellid] + gain.amount
	end

	local gain = {}

	local function SpellEnergize(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellId, spellName, spellSchool, samount, overEnergize, powerType = ...

		gain.playerid = srcGUID
		gain.playername = srcName
		gain.spellid = spellId
		gain.spellname = spellName
		gain.amount = samount
		gain.type = powerType

		Skada:FixPets(gain)
		log_gain(Skada.current, gain)
		log_gain(Skada.total, gain)
	end

	-- Power gains mode
	local powermod = {}
	local powermod_mt = { __index = powermod }

	-- Player detail mode
	local playermod = {}
	local playermod_mt = { __index = playermod }

	function powermod:GetName()
		return L["Power gains"]
	end

	function powermod:Update(win, set)
		-- Handle old data structure
		if not set or not set.power or not set.power.total then return end

		local nr = 1
		local max = 0

		-- Get selected power type from window
		local powerType = win.metadata.powerType or -1

		for i, player in ipairs(set.players) do
			-- Skip if player has old or invalid power data structure
			if player and player.power and player.power.total then
				local total = 0
				
				if powerType == -1 then
					-- Sum all power types
					for ptype, amount in pairs(player.power.total) do
						total = total + amount
					end
				else
					-- Show specific power type
					total = player.power.total[powerType] or 0
				end

				if total > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.value = total
					d.valuetext = FormatNumber(total)
					d.class = player.class
					d.role = player.role

					if total > max then
						max = total
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = max
	end

	function powermod:AddToTooltip(win, set, tooltip)
		-- Handle old data structure
		if not set or not set.power or not set.power.total then return end

		local total = 0
		local powerType = win.metadata.powerType or -1
		
		if powerType == -1 then
			for ptype, amount in pairs(set.power.total) do
				tooltip:AddLine(GetPowerTypeName(ptype), FormatNumber(amount))
				total = total + amount
			end
			tooltip:AddLine("Total", FormatNumber(total))
		else
			tooltip:AddLine(GetPowerTypeName(powerType), FormatNumber(set.power.total[powerType] or 0))
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid = id
		win.playername = label
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		-- Handle old data structure
		if not player or not player.power or not player.power.total or not player.power.spells then return end

		local nr = 1
		local max = 0
		local powerType = win.metadata.powerType or -1

		if powerType == -1 then
			-- Show all power types summed by spell
			local spellTotals = {}
			for ptype, spells in pairs(player.power.spells) do
				for spellid, amount in pairs(spells) do
					spellTotals[spellid] = (spellTotals[spellid] or 0) + amount
				end
			end

			for spellid, total in pairs(spellTotals) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label = GetSpellInfo(spellid)
				d.value = total
				d.valuetext = FormatNumber(total)
				d.icon = GetSpellIcon(spellid)

				if total > max then
					max = total
				end

				nr = nr + 1
			end
		else
			-- Show spells for specific power type
			local spells = player.power.spells[powerType]
			if spells then
				for spellid, amount in pairs(spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = GetSpellInfo(spellid)
					d.value = amount
					d.valuetext = FormatNumber(amount)
					d.icon = GetSpellIcon(spellid)

					if amount > max then
						max = amount
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.hasicon = true
		win.metadata.maxvalue = max
	end

	function mod:OnEnable()
		-- Register combat log events
		Skada:RegisterForCL(SpellEnergize, 'SPELL_ENERGIZE', {src_is_interesting = true})
		Skada:RegisterForCL(SpellEnergize, 'SPELL_PERIODIC_ENERGIZE', {src_is_interesting = true})

		-- Create the power gains mode
		local powergains = {}
		setmetatable(powergains, powermod_mt)

		-- Create the player detail mode
		local playerdetail = {}
		setmetatable(playerdetail, playermod_mt)

		-- Link them together
		powergains.metadata = {
			showspots = true,
			click1 = playerdetail,
			filterclass = true,
			icon = "Interface\\Icons\\Spell_magic_managain"
		}
		playerdetail.metadata = {
			showspots = false,
			icon = "Interface\\Icons\\Spell_magic_managain"
		}

		-- Add mode to Skada
		Skada:AddMode(powergains)
	end
end)
