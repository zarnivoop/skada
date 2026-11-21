local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)
local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

local mod = Skada:NewModule("LedgerDisplay")
mod.name = L["Ledger"]
mod.description = L["A table of damage, healing, damage taken, avoidable damage, interrupts, dispels and deaths."]
Skada:AddDisplaySystem("ledger", mod)

local ROW_HEIGHT = 26
local MAX_ROWS = 40
local TITLE_HEIGHT = 30
local SUMMARY_HEIGHT = 64
local HEADER_HEIGHT = 26
local PADDING = 8
local SCROLLBAR = 20

local METRICS = {
	{key = "damage", label = L["Damage"], short = string.upper(L["Damage"]), dtype = 0, weight = 0.19},
	{key = "healing", label = L["Healing"], short = string.upper(L["Healing"]), dtype = 2, weight = 0.18},
	{key = "taken", label = L["Damage taken"], short = L["Taken"], dtype = 7, weight = 0.15},
	{key = "avoidable", label = L["Avoidable damage"], short = L["Avoid"], dtype = 8, weight = 0.15},
	{key = "interrupts", label = L["Interrupts"], short = L["Int"], dtype = 5, weight = 0.11},
	{key = "dispels", label = L["Dispels"], short = L["Disp"], dtype = 6, weight = 0.11},
	{key = "deaths", label = L["Deaths"], short = string.upper(L["Deaths"]), dtype = 9, weight = 0.11},
}

local SUMMARY = {
	{key = "deaths", label = string.upper(L["Deaths"])},
	{key = "interrupts", label = L["Int"]},
	{key = "dispels", label = L["Disp"]},
	{key = "avoidable", label = L["Avoid"]},
	{key = "damage", label = string.upper(L["Damage"])},
}

local function savePosition(win)
	local frame = win and win.ledgerFrame
	if not frame then return end
	local parent = frame:GetParent() or UIParent
	local parentHeight = parent:GetHeight()
	if not parentHeight or parentHeight <= 0 then return end
	local left, top = frame:GetLeft(), frame:GetTop()
	if not left or not top then return end
	local scale = frame:GetScale() or 1
	win.db.x = left * scale
	win.db.y = top * scale - parentHeight
	win.db.point = "TOPLEFT"
	win.db.scale = scale
end

local function plainString(value)
	if type(value) == "string" and not issecretvalue(value) and value ~= "" then
		return value
	end
	return nil
end

local function sourceName(source)
	if type(source) ~= "table" or issecretvalue(source) then return nil end
	return plainString(source.name) or plainString(source.playerName) or plainString(source.unitName)
end

local function formatValue(value)
	if value == nil then return "-" end
	if issecretvalue(value) then return Skada:FormatNumberSecret(value) end
	local text = Skada:FormatNumber(value)
	if text == "" and value == 0 then text = "0" end
	return text
end

local function sourceKey(source)
	if type(source) ~= "table" or issecretvalue(source) then return nil end
	local guid = source.sourceGUID or source.guid
	if type(guid) == "string" and not issecretvalue(guid) then return guid end
	local resolved = Skada.NativeAPI:ResolveSourceGUID(source)
	if type(resolved) == "string" and not issecretvalue(resolved) then return resolved end
	return nil
end

local function addMetric(map, key, value, countOnly)
	if not key then return end
	if countOnly then
		map[key] = (map[key] or 0) + 1
	elseif value ~= nil then
		local current = map[key]
		if current == nil then
			map[key] = value
		elseif not issecretvalue(current) and not issecretvalue(value) then
			map[key] = current + value
		else
			-- A secret cannot be added. Keep the latest value so the cell can
			-- still display something in combat.
			map[key] = value
		end
	end
end

local function sourceAmount(source)
	local candidates = {
		source.totalAmount,
		source.amount,
		source.total,
		source.value,
		source.healing,
		source.healingDone,
		source.totalHealing,
		source.effectiveAmount,
	}
	local fallback
	for i = 1, 8 do
		local value = candidates[i]
		if issecretvalue(value) then return value end
		if type(value) == "number" then
			if value ~= 0 then return value end
			if fallback == nil then fallback = value end
		end
	end
	return fallback
end

local function metricMap(set, dtype, countOnly)
	local map = { names = {} }
	local view = Skada.NativeAPI:GetSessionView(set, dtype)
	if type(view) ~= "table" or issecretvalue(view) then return map end
	local sources = view.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then
		sources = view.participants
	end
	if type(sources) ~= "table" or issecretvalue(sources) then return map end
	for _, source in ipairs(sources) do
		if type(source) == "table" and not issecretvalue(source) then
			local value = countOnly and nil or sourceAmount(source)
			addMetric(map, sourceKey(source), value, countOnly)
			local name = sourceName(source)
			if name then
				addMetric(map.names, name, value, countOnly)
			end
		end
	end
	return map
end

local function deathSources(set)
	local function sourcesFrom(view)
		if type(view) ~= "table" or issecretvalue(view) then return nil end
		local sources = view.combatSources
		if type(sources) ~= "table" or issecretvalue(sources) then
			sources = view.participants
		end
		if type(sources) ~= "table" or issecretvalue(sources) then return nil end
		return sources
	end

	local sources = sourcesFrom(Skada.NativeAPI:GetSessionView(set, 9))
	if sources and #sources > 0 then return sources end

	if C_DamageMeter then
		local sessionID = type(set) == "table" and not issecretvalue(set) and set.sessionID or nil
		if sessionID then
			local ok, view = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, 9)
			if ok then
				sources = sourcesFrom(view)
				if sources and #sources > 0 then return sources end
			end
		else
			for _, sessionType in ipairs({1, 2, 0}) do
				local ok, view = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, 9)
				if ok then
					sources = sourcesFrom(view)
					if sources and #sources > 0 then return sources end
				end
			end
		end
	end
	return sources or {}
end

local function sumMap(map)
	if type(map) ~= "table" then return nil end
	local total = 0
	local any = false
	for key, value in pairs(map) do
		if key ~= "names" and type(value) == "number" and not issecretvalue(value) then
			total = total + value
			any = true
		end
	end
	return any and total or nil
end

local function setTextIfPresent(fontString, value)
	if not fontString then return end
	if value == nil then
		fontString:SetText("-")
	else
		fontString:SetText(value)
	end
end

local function rowName(row, data)
	local name = plainString(data.source.name)
	if not name then
		name = Skada.SecretHelper:GetPlayerLabel(data.source, data.order)
	end
	return name
end

local function rowClass(data)
	return Skada.SecretHelper:GetPlayerClass(data.source)
end

local function classColor(class)
	local color = class and RAID_CLASS_COLORS[class]
	if color then return color.r, color.g, color.b end
	return 0.92, 0.95, 0.98
end

local function lookupMetric(map, key, source)
	if type(map) ~= "table" then return nil end
	local value = key and map[key] or nil
	if value == nil and map.names then
		local name = sourceName(source)
		if name then value = map.names[name] end
	end
	return value
end

local function buildRows(win, set)
	local maps = {}
	local damageView = Skada.NativeAPI:GetSessionView(set, 0)
	if type(damageView) ~= "table" or issecretvalue(damageView) then
		return {}, damageView, maps, false
	end
	local sources = damageView.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then
		return {}, damageView, maps, false
	end

	for _, metric in ipairs(METRICS) do
		if metric.key ~= "damage" and metric.key ~= "deaths" then
			maps[metric.key] = metricMap(set, metric.dtype, false)
		end
	end
	-- Deaths can live in a different session than the current one; use the
	-- same fallback the Deaths mode uses, then count per player.
	maps.deaths = { names = {} }
	for _, source in ipairs(deathSources(set)) do
		if type(source) == "table" and not issecretvalue(source) then
			local key = sourceKey(source)
			if key then maps.deaths[key] = (maps.deaths[key] or 0) + 1 end
			local name = sourceName(source)
			if name then maps.deaths.names[name] = (maps.deaths.names[name] or 0) + 1 end
		end
	end

	local rows = {}
	local order = 0
	for _, source in ipairs(sources) do
		if type(source) == "table" and not issecretvalue(source) then
			order = order + 1
			local key = sourceKey(source)
			local row = {
				source = source,
				key = key,
				order = order,
				values = {},
			}
			row.values.damage = sourceAmount(source)
			for _, metric in ipairs(METRICS) do
				if metric.key ~= "damage" then
					row.values[metric.key] = lookupMetric(maps[metric.key], key, source)
				end
			end
			rows[#rows + 1] = row
		end
	end

	local sortKey = win and win.db and win.db.ledgersort or "damage"
	local desc = not (win and win.db and win.db.ledgerdesc == false)
	local canSort = true
	for _, row in ipairs(rows) do
		local value = row.values[sortKey or "damage"]
		if value ~= nil and (type(value) ~= "number" or issecretvalue(value)) then
			canSort = false
			break
		end
	end
	if canSort and #rows > 1 then
		table.sort(rows, function(a, b)
			local av = a.values[sortKey] or 0
			local bv = b.values[sortKey] or 0
			if av == bv then return a.order < b.order end
			if desc then return av > bv end
			return av < bv
		end)
	end

	return rows, damageView, maps, canSort
end

local function updateScroll(win)
	local frame = win and win.ledgerFrame
	if not frame or not frame.scroll then return end
	local scroll = frame.scroll
	local bar = frame.scrollBar
	local child = frame.scrollChild
	if not child then return end
	local viewHeight = scroll:GetHeight() or 0
	local contentHeight = child:GetHeight() or 0
	local maxScroll = math.max(0, contentHeight - viewHeight)
	if bar then
		bar:SetMinMaxValues(0, maxScroll)
		local value = scroll:GetVerticalScroll() or 0
		if type(value) ~= "number" or issecretvalue(value) then value = 0 end
		if value > maxScroll then value = maxScroll end
		bar:SetValue(value)
		bar:SetShown(maxScroll > 0)
	end
end

local function scrollBy(win, delta)
	local frame = win and win.ledgerFrame
	if not frame or not frame.scroll then return end
	local scroll = frame.scroll
	local maxScroll = scroll:GetVerticalScrollRange()
	if type(maxScroll) ~= "number" or issecretvalue(maxScroll) then return end
	local value = (scroll:GetVerticalScroll() or 0) - (delta or 0) * ROW_HEIGHT * 3
	value = math.max(0, math.min(maxScroll, value))
	scroll:SetVerticalScroll(value)
	if frame.scrollBar then
		frame.scrollBar:SetValue(value)
	end
end

local function layout(win)
	local frame = win.ledgerFrame
	if not frame then return end
	local width = frame:GetWidth() - PADDING * 2 - SCROLLBAR
	if width < 200 then width = 200 end
	local playerWidth = math.floor(width * 0.30)
	local remaining = width - playerWidth
	local right = PADDING
	local rightOffsets = {}
	for i = #METRICS, 1, -1 do
		local colWidth = math.floor(remaining * METRICS[i].weight)
		rightOffsets[i] = right + colWidth
		right = right + colWidth
	end
	frame._playerWidth = playerWidth
	frame._rightOffsets = rightOffsets
	frame._contentWidth = width

	if frame.scrollChild then
		frame.scrollChild:SetWidth(width)
	end
	if frame.summary and frame.summary.stats then
		local summaryWidth = frame.summary:GetWidth()
		if summaryWidth and summaryWidth > 0 then
			local step = summaryWidth / #SUMMARY
			for i, block in ipairs(frame.summary.stats) do
				block:ClearAllPoints()
				block:SetPoint("TOPLEFT", frame.summary, "TOPLEFT", (i - 1) * step, 0)
				block:SetWidth(step - 8)
			end
		end
	end
	if frame.titleText then
		frame.titleText:SetPoint("LEFT", frame, "TOPLEFT", PADDING + 20, -(TITLE_HEIGHT / 2))
	end
	if frame.subtitle then
		frame.subtitle:SetPoint("LEFT", frame.titleText, "RIGHT", 8, 0)
	end

	if frame.header and frame.header.cols then
		frame.header.cols[1]:SetWidth(playerWidth - 6)
		for i = 2, #METRICS + 1 do
			local fs = frame.header.cols[i]
			fs:ClearAllPoints()
			fs:SetPoint("RIGHT", frame.header, "RIGHT", -rightOffsets[i - 1], 0)
			fs:SetWidth(math.max(30, math.floor(remaining * METRICS[i - 1].weight) - 6))
		end
	end

	for i = 1, MAX_ROWS do
		local row = frame.rows and frame.rows[i]
		if row then
			row.name:SetWidth(playerWidth - 10)
			for m = 1, #METRICS do
				local fs = row.values[m]
				if fs then
					fs:ClearAllPoints()
					fs:SetPoint("RIGHT", row, "RIGHT", -rightOffsets[m], 0)
				end
			end
		end
	end
	updateScroll(win)
end

local function updateSummary(win, damageView, maps)
	maps = maps or {}
	local frame = win.ledgerFrame
	if not frame or not frame.summary then return end
	local stats = frame.summary.stats
	if not stats then return end

	local deaths = sumMap(maps.deaths)
	local interrupts = sumMap(maps.interrupts)
	local dispels = sumMap(maps.dispels)
	local avoidable = sumMap(maps.avoidable)
	local damage = damageView and damageView.totalAmount or nil

	stats[1].value:SetText(deaths and tostring(deaths) or "-")
	stats[2].value:SetText(interrupts and tostring(interrupts) or "-")
	stats[3].value:SetText(dispels and tostring(dispels) or "-")
	stats[4].value:SetText(avoidable and Skada:FormatNumberSecret(avoidable) or "-")
	stats[5].value:SetText(damage and Skada:FormatNumberSecret(damage) or "-")

	stats[4].value:SetTextColor(0.94, 0.55, 0.55)
	stats[1].value:SetTextColor(0.94, 0.55, 0.55)
	stats[2].value:SetTextColor(0.53, 0.86, 0.66)
	stats[3].value:SetTextColor(0.55, 0.74, 0.94)
	stats[5].value:SetTextColor(0.92, 0.95, 0.98)
end

local function updateHeader(win, canSort)
	local frame = win.ledgerFrame
	if not frame or not frame.header then return end
	local sortKey = win.db.ledgersort or "damage"
	local desc = win.db.ledgerdesc ~= false
	frame.header.cols[1]:SetText(L["Player"])
	for i, metric in ipairs(METRICS) do
		local label = metric.short
		if canSort and metric.key == sortKey then
			label = label .. (desc and " v" or " ^")
		end
		frame.header.cols[i + 1]:SetText(label)
	end
end

function mod:Create(window, isnew)
	local frameName = (window.db.name or "Skada") .. "LedgerFrame"
	local frame = _G[frameName]
	if not frame then
		frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
	end
	window.ledgerFrame = frame
	frame.win = window
	frame:SetFrameLevel(5)
	frame:SetSize(window.db.width or 760, window.db.height or 360)

	if not frame.titleBar then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(0.03, 0.04, 0.05, 0.94)
		frame:SetBackdropBorderColor(0.32, 0.44, 0.55, 0.45)

		local titleBar = CreateFrame("Button", nil, frame)
		titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
		titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
		titleBar:SetHeight(TITLE_HEIGHT)
		titleBar:RegisterForDrag("LeftButton")
		titleBar:SetScript("OnDragStart", function(self)
			if frame.win and not frame.win.db.barslocked then
				self._dragging = true
				frame:StartMoving()
			end
		end)
		titleBar:SetScript("OnDragStop", function(self)
			frame:StopMovingOrSizing()
			savePosition(frame.win)
		end)
		titleBar:SetScript("OnMouseUp", function(self, button)
			if self._dragging then
				self._dragging = nil
				return
			end
			if button == "RightButton" then
				Skada:OpenMenu(frame.win)
			elseif button == "LeftButton" then
				Skada:SegmentMenu(frame.win)
			end
		end)
		frame.titleBar = titleBar

		local bg = titleBar:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(titleBar)
		bg:SetColorTexture(0.06, 0.11, 0.16, 0.85)
		frame.titleBg = bg

		local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("LEFT", titleBar, "LEFT", PADDING + 20, 0)
		title:SetText(L["Ledger"])
		frame.titleText = title

		local subtitle = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		subtitle:SetPoint("LEFT", title, "RIGHT", 8, 0)
		subtitle:SetTextColor(0.55, 0.66, 0.76)
		frame.subtitle = subtitle

		local menu = CreateFrame("Button", nil, titleBar)
		menu:SetSize(44, 20)
		menu:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
		menu:SetNormalFontObject(_G.GameFontNormalSmall)
		menu:SetText("MENU")
		menu:SetScript("OnClick", function() Skada:OpenMenu(frame.win) end)
		frame.menuButton = menu

		local displayButton = Skada:CreateDisplayButton(titleBar, window, 15)
		displayButton:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 6, -7)
		frame.displayButton = displayButton

		local summaryButton = CreateFrame("Button", nil, titleBar)
		summaryButton:SetSize(64, 20)
		summaryButton:SetPoint("RIGHT", menu, "LEFT", -6, 0)
		summaryButton:SetNormalFontObject(_G.GameFontNormalSmall)
		summaryButton:SetText(L["Summary"])
		summaryButton:SetScript("OnClick", function()
			local win = frame.win
			if not win then return end
			win.db.ledgersummary = win.db.ledgersummary == false
			mod:ApplySettings(win)
		end)
		summaryButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(L["Show summary"])
			GameTooltip:AddLine(L["Show the summary strip at the top of the ledger."], 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		summaryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.summaryButton = summaryButton

		local summary = CreateFrame("Frame", nil, frame)
		summary:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PADDING, -6)
		summary:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -PADDING, -6)
		summary:SetHeight(SUMMARY_HEIGHT - 8)
		frame.summary = summary
		summary.stats = {}
		for i, entry in ipairs(SUMMARY) do
			local block = CreateFrame("Frame", nil, summary)
			block:SetPoint("TOPLEFT", summary, "TOPLEFT", 0, 0)
			block:SetWidth(150)
			block:SetHeight(SUMMARY_HEIGHT - 12)
			local label = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			label:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
			label:SetText(string.upper(entry.label))
			label:SetTextColor(0.48, 0.58, 0.68)
			local value = block:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
			value:SetText("-")
			block.label = label
			block.value = value
			summary.stats[i] = block
		end

		local header = CreateFrame("Frame", nil, frame)
		header:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -4)
		header:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -4)
		header:SetHeight(HEADER_HEIGHT)
		frame.header = header
		header.cols = {}
		local headerLine = header:CreateTexture(nil, "ARTWORK")
		headerLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
		headerLine:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
		headerLine:SetHeight(1)
		headerLine:SetColorTexture(0.25, 0.35, 0.45, 0.35)

		local playerHead = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		playerHead:SetPoint("LEFT", header, "LEFT", 0, 0)
		playerHead:SetText(L["Player"])
		playerHead:SetTextColor(0.48, 0.58, 0.68)
		playerHead:SetJustifyH("LEFT")
		header.cols[1] = playerHead
		for i, metric in ipairs(METRICS) do
						local fs = CreateFrame("Button", nil, header)
			fs:SetHeight(HEADER_HEIGHT)
			fs:SetNormalFontObject(_G.GameFontNormalSmall)
			fs:SetText(metric.short)
			fs:GetFontString():SetTextColor(0.48, 0.58, 0.68)
			fs:GetFontString():SetJustifyH("RIGHT")
			fs:GetFontString():ClearAllPoints()
			fs:GetFontString():SetPoint("RIGHT", fs, "RIGHT", 0, 0)
			fs:SetScript("OnClick", function()
				local win = frame.win
				if not win then return end
				if win.db.ledgersort == metric.key then
					win.db.ledgerdesc = win.db.ledgerdesc == false
				else
					win.db.ledgersort = metric.key
					win.db.ledgerdesc = true
				end
				mod:Update(win)
			end)
			header.cols[i + 1] = fs
		end

		local scroll = CreateFrame("ScrollFrame", nil, frame)
		scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
		scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR - 2, PADDING)
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(_, delta) scrollBy(frame.win, delta) end)
		frame.scroll = scroll

		local scrollBar = CreateFrame("Slider", nil, frame)
		scrollBar:SetOrientation("VERTICAL")
		scrollBar:SetWidth(12)
		scrollBar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 16, 0)
		scrollBar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 16, 0)
		scrollBar:SetMinMaxValues(0, 0)
		scrollBar:SetValueStep(ROW_HEIGHT)
		scrollBar:SetObeyStepOnDrag(true)
		scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
		scrollBar:SetScript("OnValueChanged", function(_, value)
			scroll:SetVerticalScroll(value or 0)
		end)
		scrollBar:Hide()
		frame.scrollBar = scrollBar

		local child = CreateFrame("Frame", nil, scroll)
		child:SetWidth(frame:GetWidth() - PADDING * 2 - SCROLLBAR)
		child:SetHeight(1)
		scroll:SetScrollChild(child)
		frame.scrollChild = child

		frame.rows = {}
		for i = 1, MAX_ROWS do
			local row = CreateFrame("Button", nil, child)
			row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
			row:SetHeight(ROW_HEIGHT)
			row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
			row:SetScript("OnEnter", function(self)
				if not self.data then return end
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				GameTooltip:ClearLines()
				pcall(GameTooltip.AddLine, GameTooltip, rowName(self, self.data))
				for _, metric in ipairs(METRICS) do
					local value = self.data.values[metric.key]
					if value ~= nil then
						pcall(GameTooltip.AddDoubleLine, GameTooltip, metric.label, formatValue(value), 1, 1, 1, 1, 1, 1)
					end
				end
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
			row:EnableMouseWheel(true)
			row:SetScript("OnMouseWheel", function(_, delta) scrollBy(frame.win, delta) end)

			local bg = row:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints(row)
			bg:SetColorTexture(0.55, 0.75, 0.95, 0.035)
			row.bg = bg

			local line = row:CreateTexture(nil, "ARTWORK")
			line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
			line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
			line:SetHeight(1)
			line:SetColorTexture(1, 1, 1, 0.035)
			row.line = line

			local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			name:SetPoint("LEFT", row, "LEFT", 0, 0)
			name:SetJustifyH("LEFT")
			name:SetWordWrap(false)
			name:SetHeight(ROW_HEIGHT)
			row.name = name

			row.values = {}
			for m = 1, #METRICS do
				local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				fs:SetJustifyH("RIGHT")
				fs:SetHeight(ROW_HEIGHT)
				row.values[m] = fs
			end
			frame.rows[i] = row
		end

		local resize = CreateFrame("Button", nil, frame)
		resize:SetSize(16, 16)
		resize:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
		resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
		resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
		resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
		resize:SetAlpha(0.45)
		resize:SetScript("OnEnter", function(self) self:SetAlpha(0.85) end)
		resize:SetScript("OnLeave", function(self) self:SetAlpha(0.45) end)
		resize:SetScript("OnMouseDown", function(_, button)
			if button == "LeftButton" and frame.StartSizing then
				frame:StartSizing("BOTTOMRIGHT")
			end
		end)
		resize:SetScript("OnMouseUp", function()
			if frame.StopMovingOrSizing then
				frame:StopMovingOrSizing()
			end
			local width = math.max(600, frame:GetWidth() or 760)
			local height = math.max(260, frame:GetHeight() or 360)
			frame:SetSize(width, height)
			window.db.width = width
			window.db.height = height
			libwindow.SavePosition(frame)
			layout(window)
		end)
		frame.resizeButton = resize
	end

	libwindow.RegisterConfig(frame, window.db)
	if isnew and not window.db.x and not window.db.y then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		libwindow.SavePosition(frame)
	else
		libwindow.RestorePosition(frame)
	end
	frame:SetSize(window.db.width or 760, window.db.height or 360)

	frame:EnableMouse(true)
	frame:SetMovable(true)
	if frame.SetResizable then
		frame:SetResizable(true)
	end
	if frame.SetMinResize then
		frame:SetMinResize(600, 260)
	end
	frame:SetScript("OnSizeChanged", function()
		if frame.win then layout(frame.win) end
	end)
	frame:Show()
	self:ApplySettings(window)
	self:Update(window)
end

function mod:Destroy(win)
	if not win.ledgerFrame then return end
	win.ledgerFrame:Hide()
	if not win._switching then
		win.ledgerFrame = nil
	end
end

function mod:Wipe(win) end

function mod:Show(win)
	if win.ledgerFrame then win.ledgerFrame:Show() end
end

function mod:Hide(win)
	if win.ledgerFrame then win.ledgerFrame:Hide() end
end

function mod:IsShown(win)
	return win.ledgerFrame and win.ledgerFrame:IsShown()
end

function mod:SetTitle(win, title)
	local frame = win.ledgerFrame
	if not frame or not frame.titleText then return end
	frame.titleText:SetText(L["Ledger"])
	if frame.subtitle then
		local set = win:get_selected_set()
		local label = set and Skada:GetSetLabel(set) or nil
		frame.subtitle:SetText(label or tostring(title or ""))
	end
end

function mod:ApplySettings(win)
	local frame = win.ledgerFrame
	if not frame then return end
	local db = win.db
	local fontPath = db.barfontpath or media:Fetch("font", db.barfont) or "Fonts\\FRIZQT__.TTF"
	local fontSize = db.barfontsize or 12
	local flags = db.barfontflags or ""
	local titlePath = db.title and (db.title.fontpath or media:Fetch("font", db.title.font)) or fontPath
	local titleSize = db.title and (db.title.fontsize or 13) or 13

	frame:SetSize(db.width or 760, db.height or 360)
	local showSummary = db.ledgersummary ~= false
	if frame.summary then
		frame.summary:SetShown(showSummary)
	end
	if frame.summaryButton then
		frame.summaryButton:SetAlpha(showSummary and 1 or 0.45)
	end
	if frame.header then
		frame.header:ClearAllPoints()
		if showSummary and frame.summary then
			frame.header:SetPoint("TOPLEFT", frame.summary, "BOTTOMLEFT", 0, -4)
			frame.header:SetPoint("TOPRIGHT", frame.summary, "BOTTOMRIGHT", 0, -4)
		else
			frame.header:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", PADDING, -6)
			frame.header:SetPoint("TOPRIGHT", frame.titleBar, "BOTTOMRIGHT", -PADDING, -6)
		end
	end
	if frame.titleText then
		frame.titleText:SetFont(titlePath, titleSize, "")
	end
	if frame.subtitle then
		frame.subtitle:SetFont(fontPath, 11, "")
	end
	if frame.header and frame.header.cols then
		for _, fs in ipairs(frame.header.cols) do
			if fs.SetFont then
				fs:SetFont(fontPath, 10, "")
			elseif fs.GetFontString then
				local buttonFont = fs:GetFontString()
				if buttonFont and buttonFont.SetFont then
					buttonFont:SetFont(fontPath, 10, "")
				end
			end
		end
	end
	if frame.summary and frame.summary.stats then
		for _, block in ipairs(frame.summary.stats) do
			block.label:SetFont(fontPath, 8, "")
			block.value:SetFont(fontPath, 17, "")
		end
	end
	if frame.rows then
		for _, row in ipairs(frame.rows) do
			row.name:SetFont(fontPath, fontSize, flags)
			for _, fs in ipairs(row.values) do
				fs:SetFont(fontPath, fontSize, flags)
			end
		end
	end
	local bg = db.background and db.background.color
	if bg then
		frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 0.94)
	end
	layout(win)
end

function mod:Update(win)
	local frame = win.ledgerFrame
	if not frame then return end
	local set = win:get_selected_set()
	if type(set) ~= "table" then
		for i = 1, MAX_ROWS do frame.rows[i].data = nil; frame.rows[i]:Hide() end
		return
	end

	local rows, damageView, maps, canSort = buildRows(win, set)
	win._ledgerRows = rows
	local scrollChild = frame.scrollChild
	scrollChild:SetHeight(math.max(1, #rows) * ROW_HEIGHT)
	updateScroll(win)

	for i = 1, MAX_ROWS do
		local row = frame.rows[i]
		local data = rows[i]
		row.data = data
		if data then
			local name = rowName(row, data)
			local ok = pcall(row.name.SetText, row.name, name)
			if not ok then row.name:SetText("?") end
			local class = rowClass(data)
			row.name:SetTextColor(classColor(class))
			for m, metric in ipairs(METRICS) do
				local value = data.values[metric.key]
				local fs = row.values[m]
				setTextIfPresent(fs, formatValue(value))
				local r, g, b = 0.92, 0.95, 0.98
				if value ~= nil and not issecretvalue(value) and value > 0 then
					if metric.key == "avoidable" or metric.key == "deaths" then
						r, g, b = 0.94, 0.55, 0.55
					elseif metric.key == "interrupts" then
						r, g, b = 0.53, 0.86, 0.66
					elseif metric.key == "dispels" then
						r, g, b = 0.55, 0.74, 0.94
					end
				end
				fs:SetTextColor(r, g, b)
			end
			if row.bg then row.bg:SetShown(i % 2 == 0) end
			row:Show()
		else
			row:Hide()
		end
	end

	updateSummary(win, damageView, maps)
	updateHeader(win, canSort)
	layout(win)
end

function mod:Dump(win)
	win = win or Skada._lastActiveWindow or Skada:GetWindows()[1]
	if not win then return end
	local set = win:get_selected_set()
	local setID = "nil"
	if type(set) == "table" and not issecretvalue(set) then
		setID = tostring(set.sessionID or set.sessionType or "?")
	end
	Skada:Print("Ledger set " .. setID .. " display=" .. tostring(win.db.display))
	for _, dtype in ipairs({0, 2, 7, 5, 6, 8, 9}) do
		local view = Skada.NativeAPI:GetSessionView(set, dtype)
		local sources
		if type(view) == "table" and not issecretvalue(view) then
			sources = view.combatSources
			if type(sources) ~= "table" or issecretvalue(sources) then
				sources = view.participants
			end
		end
		local count = type(sources) == "table" and #sources or 0
		Skada:Print("  type " .. dtype .. " view=" .. tostring(view ~= nil) .. " sources=" .. count)
		local first = type(sources) == "table" and sources[1] or nil
		if type(first) == "table" and not issecretvalue(first) then
			for key, value in pairs(first) do
				local kind = type(value)
				local secret = issecretvalue(value) and " secret" or ""
				local text = ""
				if not issecretvalue(value) and (kind == "number" or kind == "string") then
					text = " " .. tostring(value)
				end
				Skada:Print("    " .. tostring(key) .. " " .. kind .. secret .. text)
			end
		end
	end
end

function mod:AddDisplayOptions(win, options)
	local db = win.db
	options.ledgeroptions = {
		type = "group",
		name = L["Ledger"],
		order = 2,
		args = {
			ledgersummary = {
				type = "toggle",
				name = L["Show summary"],
				desc = L["Show the summary strip at the top of the ledger."],
				get = function() return db.ledgersummary ~= false end,
				set = function(_, value)
					db.ledgersummary = value
					Skada:ApplySettings()
				end,
				order = 1,
			},
		},
	}
end
