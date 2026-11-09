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
	if value == nil then return "-" end
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

local function percentage(value, total)
	if issecretvalue(value) or issecretvalue(total) then return nil end
	if type(value) ~= "number" or type(total) ~= "number" or total <= 0 then return nil end
	return (value / total) * 100
end

local function formatPercent(value)
	if type(value) ~= "number" then return nil end
	return string.format("%.0f%%", value)
end

local function perMinute(value, duration)
	if issecretvalue(value) or issecretvalue(duration) then return nil end
	if type(value) ~= "number" or type(duration) ~= "number" or duration <= 0 then return nil end
	return value * 60 / duration
end

local function formatPerMinute(value)
	if type(value) ~= "number" then return nil end
	return string.format("%.1f/min", value)
end

local function bestSource(set, damageType)
	local view = NativeAPI:GetSessionView(set, damageType)
	if type(view) ~= "table" or issecretvalue(view) then return nil end
	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return nil end
	local best, bestValue, bestIndex
	for i, source in ipairs(sources) do
		if type(source) == "table" and not issecretvalue(source) then
			local value = source.totalAmount
			if not issecretvalue(value) and type(value) == "number" and (not bestValue or value > bestValue) then
				best, bestValue, bestIndex = source, value, i
			end
		end
	end
	return best, bestValue, bestIndex
end

local function firstDeath(set)
	local view = NativeAPI:GetSessionView(set, 9)
	if type(view) ~= "table" or issecretvalue(view) then return nil end
	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return nil end
	local firstTime, firstName
	for i, source in ipairs(sources) do
		if type(source) == "table" and not issecretvalue(source) then
			local deathTime = source.deathTimeSeconds
			if not issecretvalue(deathTime) and type(deathTime) == "number"
				and (not firstTime or deathTime < firstTime) then
				firstTime = deathTime
				firstName = SecretHelper:GetPlayerLabel(source, i)
			end
		end
	end
	return firstName, firstTime
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
	local source, _, sourceIndex = bestSource(set, 8)
	if not source then return nil end
	local playerName = SecretHelper:GetPlayerLabel(source, sourceIndex or 1)
	local spells = NativeAPI:GetPlayerSpells(source.sourceGUID, set, 8, source.sourceCreatureID)
	if type(spells) ~= "table" or issecretvalue(spells) then return tostring(playerName or "-") end
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
	return tostring(playerName or "-")
end

local function summarisedStats(set)
	local duration = Skada:GetSetTime(set)
	local damage = ModuleBase:GetSetTotal(set, 0)
	local healing = ModuleBase:GetSetTotal(set, 2)
	local absorbs = ModuleBase:GetSetTotal(set, 4)
	local avoidable = ModuleBase:GetSetTotal(set, 8)
	local interrupts = ModuleBase:GetSetTotal(set, 5)
	local dispels = ModuleBase:GetSetTotal(set, 6)
	local damageTaken = ModuleBase:GetSetTotal(set, 7)

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

	local topSource, topAmount, topIndex = bestSource(set, 0)
	local topName = topSource and SecretHelper:GetPlayerLabel(topSource, topIndex or 1) or nil
	local firstDeathName, firstDeathTime = firstDeath(set)
	local avoidableSource = topAvoidable(set)

	local healingAndAbsorbs = nil
	if not issecretvalue(healing) and not issecretvalue(absorbs)
		and type(healing) == "number" and type(absorbs) == "number" then
		healingAndAbsorbs = healing + absorbs
	end

	return {
		duration = duration,
		damage = damage,
		healing = healing,
		absorbs = absorbs,
		avoidable = avoidable,
		interrupts = interrupts,
		dispels = dispels,
		damageTaken = damageTaken,
		deaths = deaths,
		topSource = topSource,
		topAmount = topAmount,
		topName = topName,
		topShare = percentage(topAmount, damage),
		firstDeathName = firstDeathName,
		firstDeathTime = firstDeathTime,
		avoidableTax = percentage(avoidable, damageTaken),
		interruptRate = perMinute(interrupts, duration),
		dispelRate = perMinute(dispels, duration),
		deathRate = perMinute(deaths, duration),
		absorbShare = percentage(absorbs, healingAndAbsorbs),
		avoidableTop = avoidableSource,
	}
end

local function plainNumber(value)
	return type(value) == "number" and not issecretvalue(value)
end

local function verdictFor(stats)
	if plainNumber(stats.deaths) and stats.deaths == 0 then
		return "Nobody died. Suspicious. The healer may want a raise."
	end
	if plainNumber(stats.avoidableTax) and stats.avoidableTax > 20 then
		return "The floor has filed a formal complaint."
	end
	if plainNumber(stats.interrupts) and stats.interrupts == 0 and IsInInstance() then
		return "Kick button not found. Please check under the action bars."
	end
	if plainNumber(stats.topShare) and stats.topShare > 40 then
		return "Carry permit required. Please stretch before the next pull."
	end
	if plainNumber(stats.absorbShare) and stats.absorbShare > 50 then
		return "The healers were mostly decorative. The shields did the work."
	end
	if plainNumber(stats.deaths) and stats.deaths >= 3 then
		return "The floor sends its regards."
	end
	if plainNumber(stats.duration) and stats.duration < 30 then
		return "Blink and you missed it. The boss has requested a rematch."
	end
	return "The data does not lie. The boss might."
end

local function signedPercent(current, previous)
	if issecretvalue(current) or issecretvalue(previous) then return nil end
	if type(current) ~= "number" or type(previous) ~= "number" or previous <= 0 then return nil end
	local pct = ((current - previous) / previous) * 100
	if math.abs(pct) < 0.5 then return nil end
	return string.format("%+.0f%%", pct)
end

local function buildComparison(stats, previous)
	if type(previous) ~= "table" then return nil end
	local parts = {}
	if plainNumber(stats.damage) and plainNumber(stats.duration) and stats.duration > 0
		and plainNumber(previous.damage) and plainNumber(previous.duration) and previous.duration > 0 then
		local pct = signedPercent(stats.damage / stats.duration, previous.damage / previous.duration)
		if pct then parts[#parts + 1] = string.format(L["DPS %s"] or "DPS %s", pct) end
	end
	if plainNumber(stats.deaths) and plainNumber(previous.deaths) then
		local diff = stats.deaths - previous.deaths
		if diff ~= 0 then parts[#parts + 1] = string.format(L["deaths %+d"] or "deaths %+d", diff) end
	end
	if plainNumber(stats.avoidable) and plainNumber(stats.duration) and stats.duration > 0
		and plainNumber(previous.avoidable) and plainNumber(previous.duration) and previous.duration > 0 then
		local pct = signedPercent((stats.avoidable / stats.duration) * 60, (previous.avoidable / previous.duration) * 60)
		if pct then parts[#parts + 1] = string.format(L["avoidable/min %s"] or "avoidable/min %s", pct) end
	end
	if #parts == 0 then return nil end
	return string.format(L["vs last attempt: %s"] or "vs last attempt: %s", table.concat(parts, ", "))
end

local function buildSummary(set, previousPull)
	local stats = summarisedStats(set)
	local rows = {}
	local function add(rowLabel, value, show)
		if show ~= false and value ~= nil and value ~= "-" then
			rows[#rows + 1] = { label = rowLabel, value = value }
		end
	end
	local function positive(value)
		if issecretvalue(value) then return true end
		return type(value) == "number" and value > 0
	end

	local deathText = formatNumber(stats.deaths)
	if stats.deathRate then deathText = deathText .. " (" .. formatPerMinute(stats.deathRate) .. ")" end

	add(label("Duration", "Duration"), formatDuration(stats.duration), stats.duration ~= nil)
	add(label("Raid DPS", "Raid DPS"), formatRate(stats.damage, stats.duration), positive(stats.damage) and positive(stats.duration))
	add(label("Raid HPS", "Raid HPS"), formatRate(stats.healing, stats.duration), positive(stats.healing) and positive(stats.duration))
	add(label("Deaths", "Deaths"), deathText, positive(stats.deaths))
	if stats.firstDeathTime then
		add(label("First death", "First death"), formatDuration(stats.firstDeathTime) .. " (" .. tostring(stats.firstDeathName) .. ")", true)
	end
	local avoidableText = formatNumber(stats.avoidable)
	local avoidableTaxText = formatPercent(stats.avoidableTax)
	if avoidableTaxText then avoidableText = avoidableText .. " (" .. avoidableTaxText .. " of taken)" end
	add(label("Avoidable damage", "Avoidable damage"), avoidableText, positive(stats.avoidable))
	local interruptText = formatNumber(stats.interrupts)
	if stats.interruptRate then interruptText = interruptText .. " (" .. formatPerMinute(stats.interruptRate) .. ")" end
	add(label("Interrupts", "Interrupts"), interruptText, positive(stats.interrupts))
	local dispelText = formatNumber(stats.dispels)
	if stats.dispelRate then dispelText = dispelText .. " (" .. formatPerMinute(stats.dispelRate) .. ")" end
	add(label("Dispels", "Dispels"), dispelText, positive(stats.dispels))

	if stats.topSource then
		local topShare = formatPercent(stats.topShare)
		local topText = tostring(stats.topName or "-") .. " (" .. formatNumber(stats.topAmount)
		if topShare then topText = topText .. ", " .. topShare .. " share" end
		topText = topText .. ")"
		add(label("Top damage", "Top damage"), topText, true)
	end
	if stats.avoidableTop then
		add(label("Top avoidable", "Top avoidable"), stats.avoidableTop, true)
	end
	if stats.absorbShare then
		add(label("Absorb share", "Absorb share"), formatPercent(stats.absorbShare), true)
	end
	return rows, Skada:GetSetLabel(set), verdictFor(stats), buildComparison(stats, previousPull)
end

local function ensureFrame()
	if Skada.CombatSummaryFrame then return Skada.CombatSummaryFrame end
	local frame = CreateFrame("Frame", "SkadaCombatSummaryFrame", UIParent, "BackdropTemplate")
	frame:SetSize(380, 360)
	frame:SetClampedToScreen(true)
	local saved = Skada.db.profile.summarypos
	if type(saved) == "table" then
		frame:SetPoint(saved.point or "CENTER", UIParent, saved.relativePoint or saved.point or "CENTER", saved.x or 0, saved.y or 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local point, _, relativePoint, x, y = f:GetPoint(1)
		if point then
			Skada.db.profile.summarypos = {
				point = point,
				relativePoint = relativePoint or point,
				x = x or 0,
				y = y or 0,
			}
		end
	end)
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

	frame.comparison = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.comparison:SetJustifyH("LEFT")
	frame.comparison:SetWordWrap(false)
	frame.comparison:SetTextColor(0.72, 0.78, 0.86, 1)
	frame.comparison:Hide()

	frame.verdict = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.verdict:SetJustifyH("LEFT")
	frame.verdict:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	frame.verdict:Hide()

	frame.rows = {}
	for i = 1, 14 do
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

local function sendSummaryToChat(rows, setLabel, verdict, comparison)
	local key = Skada.db.profile.combatsummarychannel or "say"
	local channel, chantype = Skada:ResolveChatChannel(key, Skada.db.profile.combatsummarytarget)
	if not channel then
		Skada:Print("Error: Whisper target not found")
		return false
	end
	Skada:SendChatLine(string.format(L["Skada: %s for %s:"], L["Combat summary"], setLabel or ""), channel, chantype)
	for _, row in ipairs(rows) do
		Skada:SendChatLine(row.label .. ": " .. row.value, channel, chantype)
	end
	if comparison then
		Skada:SendChatLine(comparison, channel, chantype)
	end
	if verdict then
		Skada:SendChatLine(verdict, channel, chantype)
	end
	return true
end

function Skada:ShowCombatSummary(set)
	if type(set) ~= "table" then set = self:GetActiveSet() end
	if type(set) ~= "table" then return end
	local previousPull = (self.db.profile.combatsummarycomparison ~= false) and self:GetPullComparisonForSet(set) or nil
	local rows, setLabel, verdict, comparison = buildSummary(set, previousPull)
	if (self.db.profile.combatsummaryoutput or "window") == "chat" then
		if self.CombatSummaryFrame then self.CombatSummaryFrame:Hide() end
		sendSummaryToChat(rows, setLabel, verdict, comparison)
		return
	end
	local frame = ensureFrame()
	frame.subtitle:SetText(setLabel or "")
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
	local footerY = -48 - #rows * 24 - 2
	local height = 56 + #rows * 24 + 10
	if comparison then
		frame.comparison:ClearAllPoints()
		frame.comparison:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, footerY)
		frame.comparison:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
		frame.comparison:SetText(comparison)
		frame.comparison:Show()
		footerY = footerY - 20
		height = height + 20
	else
		frame.comparison:Hide()
	end
	if verdict then
		frame.verdict:ClearAllPoints()
		frame.verdict:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, footerY)
		frame.verdict:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
		frame.verdict:SetText(verdict)
		frame.verdict:Show()
		height = height + 20
	else
		frame.verdict:Hide()
	end
	frame:SetHeight(height)
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
