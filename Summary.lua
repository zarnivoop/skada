local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)
local ModuleBase = Skada.ModuleBase
local SecretHelper = Skada.SecretHelper
local NativeAPI = Skada.NativeAPI

local ACCENT = { 0.36, 0.62, 0.83 }

local function label(key, fallback)
	return L[key] or fallback
end

local function formatDuration(seconds)
	if issecretvalue(seconds) or type(seconds) ~= "number" then return "?" end
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function formatNumber(value)
	if value == nil then return "—" end
	if not issecretvalue(value) and type(value) == "number" and value == 0 then return "0" end
	return Skada:FormatNumberSecret(value)
end

local function formatRate(total, duration)
	if issecretvalue(total) or issecretvalue(duration) then return "?" end
	if type(total) ~= "number" or type(duration) ~= "number" or duration <= 0 then return "?" end
	local rate = total / duration
	if rate == 0 then return "0" end
	return Skada:FormatNumber(rate)
end

local function bestSource(set, damageType)
	local view = Skada.NativeAPI:GetSessionView(set, damageType)
	if type(view) ~= "table" or issecretvalue(view) then return nil end
	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return nil end
	local best, bestValue
	for i, source in ipairs(sources) do
		if type(source) == "table" and not issecretvalue(source) then
			local value = source.totalAmount
			if not issecretvalue(value) and type(value) == "number" and (not bestValue or value > bestValue) then
				best, bestValue = source, value
				best.index = i
			end
		end
	end
	return best, bestValue
end

local function spellName(spell)
	if type(spell) ~= "table" or issecretvalue(spell) then return nil end
	if type(spell.name) == "string" and not issecretvalue(spell.name) then return spell.name end
	local spellID = spell.spellID
	if type(spellID) == "number" and not issecretvalue(spellID) and spellID > 0 then
		local info = C_Spell.GetSpellInfo(spellID)
		return info and info.name
	end
	return nil
end

local function topAvoidable(set)
	local source = bestSource(set, 8)
	if not source then return "—" end
	local playerName = SecretHelper:GetPlayerLabel(source, source.index or 1)
	local spells = NativeAPI:GetPlayerSpells(source.sourceGUID, set, 8, source.sourceCreatureID)
	if type(spells) ~= "table" or issecretvalue(spells) then return tostring(playerName or "—") end
	local best, bestValue
	for _, spell in ipairs(spells) do
		if type(spell) == "table" and not issecretvalue(spell) then
			local value = spell.totalAmount
			if not issecretvalue(value) and type(value) == "number" and (not bestValue or value > bestValue) then
				best, bestValue = spell, value
			end
		end
	end
	local name = best and spellName(best)
	if name then return name .. " (" .. tostring(playerName) .. ")" end
	return tostring(playerName or "—")
end

local function buildSummary(set)
	local duration = Skada:GetSetTime(set)
	local damage = ModuleBase:GetSetTotal(set, 0)
	local healing = ModuleBase:GetSetTotal(set, 2)
	local avoidable = ModuleBase:GetSetTotal(set, 8)
	local interrupts = ModuleBase:GetSetTotal(set, 5)
	local dispels = ModuleBase:GetSetTotal(set, 6)

	-- A Deaths source is a person who died; use the row count rather than
	-- trusting a damage-like totalAmount field from other metric types.
	local deaths
	do
		local view = NativeAPI:GetSessionView(set, 9)
		if type(view) == "table" and not issecretvalue(view)
			and type(view.combatSources) == "table" and not issecretvalue(view.combatSources) then
			deaths = #view.combatSources
		else
			deaths = ModuleBase:GetSetTotal(set, 9)
		end
	end

	local topDamage = "—"
	local source, amount = bestSource(set, 0)
	if source then
		local name = SecretHelper:GetPlayerLabel(source, source.index or 1)
		topDamage = tostring(name or "—") .. " (" .. Skada:FormatNumber(amount or 0) .. ")"
	end
	local avoidableTop = topAvoidable(set)

	local rows = {}
	local function add(rowLabel, value, show)
		if show ~= false and value ~= nil and value ~= "—" then
			rows[#rows + 1] = { label = rowLabel, value = value }
		end
	end
	local function positive(value)
		if issecretvalue(value) then return true end
		return type(value) == "number" and value > 0
	end

	add(label("Duration", "Duration"), formatDuration(duration), duration ~= nil)
	add(label("Raid DPS", "Raid DPS"), formatRate(damage, duration), positive(damage) and positive(duration))
	add(label("Raid HPS", "Raid HPS"), formatRate(healing, duration), positive(healing) and positive(duration))
	add(label("Deaths", "Deaths"), formatNumber(deaths), positive(deaths))
	add(label("Avoidable damage", "Avoidable damage"), formatNumber(avoidable), positive(avoidable))
	add(label("Interrupts", "Interrupts"), formatNumber(interrupts), positive(interrupts))
	add(label("Dispels", "Dispels"), formatNumber(dispels), positive(dispels))
	add(label("Top damage", "Top damage"), topDamage, source ~= nil)
	add(label("Top avoidable", "Top avoidable"), avoidableTop, avoidableTop ~= "—")
	return rows, Skada:GetSetLabel(set)
end

local function ensureFrame()
	if Skada.CombatSummaryFrame then return Skada.CombatSummaryFrame end
	local frame = CreateFrame("Frame", "SkadaCombatSummaryFrame", UIParent, "BackdropTemplate")
	frame:SetSize(380, 360)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(0.018, 0.026, 0.038, 0.97)
		frame:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
	end

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
	title:SetText(label("Combat summary", "Combat summary"))
	frame.title = title

	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	frame.subtitle = subtitle

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() frame:Hide() end)

	frame.rows = {}
	for i = 1, 12 do
		local row = CreateFrame("Frame", nil, frame)
		row:SetHeight(24)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -48 - (i - 1) * 24)
		row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -48 - (i - 1) * 24)
		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.label:SetJustifyH("LEFT")
		row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.value:SetJustifyH("RIGHT")
		row.label:SetTextColor(0.72, 0.78, 0.86, 1)
		row.value:SetTextColor(0.98, 0.99, 1, 1)
		row:Hide()
		frame.rows[i] = row
	end

	Skada.CombatSummaryFrame = frame
	return frame
end

function Skada:ShowCombatSummary(set)
	if type(set) ~= "table" then set = self:GetActiveSet() end
	if type(set) ~= "table" then return end
	local rows, setLabel = buildSummary(set)
	local frame = ensureFrame()
	frame.subtitle:SetText(setLabel or "")
	frame:SetHeight(56 + #rows * 24 + 10)
	for i, row in ipairs(frame.rows) do
		local data = rows[i]
		if data then
			row.label:SetText(data.label)
			row.value:SetText(data.value)
			row:Show()
		else
			row:Hide()
		end
	end
	frame:Show()
end

function Skada:HideCombatSummary()
	if self.CombatSummaryFrame then self.CombatSummaryFrame:Hide() end
end

function Skada:ToggleCombatSummary()
	local frame = self.CombatSummaryFrame
	if frame and frame:IsShown() then
		frame:Hide()
	else
		local win = self:GetWindows()[1]
		self:ShowCombatSummary(win and win:get_selected_set())
	end
end
