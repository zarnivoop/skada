local _, Skada = ...
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("Deaths", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Deaths then return end

	local mod = Skada:NewModule(L["Deaths"])
	local DEATHS_TYPE = 9

	local function sourcesFrom(view)
		if type(view) ~= "table" or issecretvalue(view) then return nil end
		local sources = view.combatSources
		if type(sources) ~= "table" or issecretvalue(sources) then return nil end
		return sources
	end

	-- Death sessions can be empty for the current session after combat while
	-- the expired/overall death session still has the recap IDs. Try the
	-- related session types instead of rendering an empty window.
	local function deathSources(set)
		local sources = sourcesFrom(Skada.NativeAPI:GetSessionView(set, DEATHS_TYPE))
		if sources and #sources > 0 then return sources end

		if C_DamageMeter then
			local sessionID = type(set) == "table" and not issecretvalue(set) and set.sessionID or nil
			if sessionID then
				local ok, view = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, DEATHS_TYPE)
				if ok then
					sources = sourcesFrom(view)
					if sources and #sources > 0 then return sources end
				end
			else
				for _, sessionType in ipairs({1, 2, 0}) do
					local ok, view = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, DEATHS_TYPE)
					if ok then
						sources = sourcesFrom(view)
						if sources and #sources > 0 then return sources end
					end
				end
			end
		end
		return sources or {}
	end

	local function openRecap(win, id)
		local recapID = win._deathRecaps and win._deathRecaps[id]
		if recapID and not issecretvalue(recapID) and recapID > 0 and _G.OpenDeathRecapUI then
			local ok = pcall(_G.OpenDeathRecapUI, recapID)
			if ok then return end
		end
		Skada:Print("No death recap available for this death.")
	end

	local function formatDeathTime(seconds)
		if type(seconds) ~= "number" or issecretvalue(seconds) then return "" end
		seconds = math.max(0, math.floor(seconds))
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end

	function mod:Update(win, set)
		local sources = deathSources(set)
		win._deathRecaps = {}

		-- Chronological order is more useful than the API's newest-first order.
		-- During combat deathTimeSeconds can still be secret, so keep API order
		-- in that case and render a blank time rather than doing unsafe math.
		local ordered = {}
		for _, source in ipairs(sources) do
			if type(source) == "table" and not issecretvalue(source) then
				ordered[#ordered + 1] = source
			end
		end
		local t1, t2 = ordered[1] and ordered[1].deathTimeSeconds, ordered[2] and ordered[2].deathTimeSeconds
		if #ordered > 1 and not issecretvalue(t1) and not issecretvalue(t2) then
			table.sort(ordered, function(a, b)
				local at, bt = a.deathTimeSeconds, b.deathTimeSeconds
				if issecretvalue(at) or issecretvalue(bt) then return false end
				return (at or 0) < (bt or 0)
			end)
		end

		local nr = 1
		for _, source in ipairs(ordered) do
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			local guid = source.sourceGUID
			local id = type(guid) == "string" and not issecretvalue(guid) and guid or ("death_" .. nr)
			d.id = id
			d.label = SecretHelper:GetPlayerLabel(source, nr)
			d.class = SecretHelper:GetPlayerClass(source)
			d.value = 1
			d.valuetext = formatDeathTime(source.deathTimeSeconds)
			d.valueText1 = nil
			d.valueText2 = nil
			d.valueText3 = nil
			d.icon = "Interface\\Icons\\Spell_Shadow_DeathScream"
			local recapID = source.deathRecapID
			if not issecretvalue(recapID) then win._deathRecaps[id] = recapID end
			nr = nr + 1
		end

		if nr == 1 then
			local d = win.dataset[1] or {}
			win.dataset[1] = d
			d.id = "deaths_empty"
			d.label = L["No deaths recorded"]
			d.value = 1
			d.valuetext = nil
			d.valueText1 = nil
			d.valueText2 = nil
			d.valueText3 = nil
			d.icon = "Interface\\Icons\\Spell_Shadow_DeathScream"
			nr = 2
		end
		for i = nr, #win.dataset do win.dataset[i].id = nil end
		win.metadata.ordersort = true
		win.metadata.maxvalue = 1
	end

	function mod:OnEnable()
		mod.metadata = {
			click = function(win, id, label, button)
				if button == "RightButton" then
					win:RightClick()
				else
					openRecap(win, id)
				end
			end,
			icon = "Interface\\Icons\\Spell_Shadow_DeathScream",
		}
		Skada:AddMode(self, L["Other"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)
