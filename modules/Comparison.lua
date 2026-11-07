local _, Skada = ...
local SecretHelper = Skada.SecretHelper

Skada:AddLoadableModule("Compare", nil, function(Skada, L)
	if Skada.db.profile.modulesBlocked.Compare then return end

	local mod = Skada:NewModule(L["Compare"])
	local DAMAGE_TYPE = 0

	local function sources(view)
		if type(view) ~= "table" or issecretvalue(view) then return nil end
		local list = view.combatSources
		if type(list) ~= "table" or issecretvalue(list) then return nil end
		return list
	end

	local function previousSet(set)
		local sessions = Skada:GetSets()
		local currentID = type(set) == "table" and set.sessionID or nil
		local fallback
		for i = 1, #sessions do
			local candidate = sessions[i]
			if candidate and candidate.sessionID ~= currentID then
				return candidate
			end
			if candidate and not fallback then fallback = candidate end
		end
		return fallback
	end

	function mod:Update(win, set)
		local dataset = win.dataset
		local function entry(nr)
			local d = dataset[nr]
			if not d then d = {}; dataset[nr] = d end
			return d
		end

		local previous = previousSet(set)
		local curView = Skada.NativeAPI:GetSessionView(set, DAMAGE_TYPE)
		local prevView = previous and Skada.NativeAPI:GetSessionView(previous, DAMAGE_TYPE) or nil
		local curSources = sources(curView)
		local prevSources = sources(prevView)

		if not curSources or not prevSources then
			local d = entry(1)
			d.id = "compare_unavailable"
			d.label = L["Comparison available after combat"]
			d.value = 1
			d.valuetext = nil
			d.valueText1 = nil
			d.valueText2 = nil
			d.valueText3 = nil
			win.metadata.maxvalue = 1
			for i = 2, #dataset do dataset[i].id = nil end
			return
		end

		local prevByGUID, prevByName = {}, {}
		for _, source in ipairs(prevSources) do
			if type(source) == "table" and not issecretvalue(source) then
				local guid = source.sourceGUID
				local name = source.name
				if type(guid) == "string" and not issecretvalue(guid) then prevByGUID[guid] = source end
				if type(name) == "string" and not issecretvalue(name) then prevByName[name] = source end
			end
		end

		local nr, max = 1, 1
		for _, source in ipairs(curSources) do
			if type(source) == "table" and not issecretvalue(source) then
				local current = source.totalAmount
				if not issecretvalue(current) and type(current) == "number" then
					local guid = source.sourceGUID
					local name = source.name
					local prev
					if type(guid) == "string" and not issecretvalue(guid) then prev = prevByGUID[guid] end
					if not prev and type(name) == "string" and not issecretvalue(name) then prev = prevByName[name] end
					local previousAmount = prev and prev.totalAmount
					if issecretvalue(previousAmount) then previousAmount = nil end
					local prevValue = type(previousAmount) == "number" and previousAmount or 0
					local delta = current - prevValue

					local d = entry(nr)
					d.id = type(guid) == "string" and not issecretvalue(guid) and guid or ("compare_" .. nr)
					d.label = SecretHelper:GetPlayerLabel(source, nr)
					d.class = SecretHelper:GetPlayerClass(source)
					d.value = math.abs(delta)
					d.valuetext = nil
					d.ignore = nil
					d.valueText1 = Skada:FormatNumber(current)
					d.valueText2 = Skada:FormatNumber(prevValue)
					if delta == 0 then
						d.valueText3 = "0"
					else
						d.valueText3 = (delta > 0 and "+" or "") .. Skada:FormatNumber(delta)
					end
					d.icon = nil
					if d.value > max then max = d.value end
					nr = nr + 1
				end
			end
		end
		for i = nr, #dataset do if dataset[i] then dataset[i].id = nil end end
		win.metadata.maxvalue = max > 0 and max or 1
	end

	function mod:OnEnable()
		mod.metadata = {
			columns = { Damage = true, DPS = true, Percent = true },
			columnSpec = {
				{ label = L["Now"], value = "valueText1" },
				{ label = L["Previous"], value = "valueText2" },
				{ label = L["Delta"], value = "valueText3" },
			},
			icon = "Interface\\Icons\\inv_misc_coin_01",
		}
		Skada:AddMode(self, L["Other"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)
