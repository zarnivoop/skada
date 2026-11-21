--[[
	Custom bar display.

	This renderer deliberately does not use SpecializedLibBars. It owns its
	window shell, row pool, column layout, scrolling and title bar.
]]

local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)
local media = LibStub("LibSharedMedia-3.0")
local libwindow = LibStub("LibWindow-1.1")

local mod = Skada:NewModule("BarRenderer")
mod.name = L["Bar display"]
mod.description = L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."]
Skada:AddDisplaySystem("bar", mod)

local pairs, ipairs, type = pairs, ipairs, type
local table_sort = table.sort
local max, min, floor = math.max, math.min, math.floor
local stopAnimator

local COLUMN_WIDTH = 64
local COLUMN_GAP = 6
local COLUMN_RIGHT_PAD = 4

local SCHOOL_COLORS = {
	[1] = { r = 1.00, g = 0.82, b = 0.17 },
	[2] = { r = 0.96, g = 0.91, b = 0.11 },
	[4] = { r = 0.89, g = 0.33, b = 0.10 },
	[8] = { r = 0.31, g = 0.81, b = 0.19 },
	[16] = { r = 0.40, g = 0.86, b = 0.96 },
	[32] = { r = 0.61, g = 0.39, b = 0.76 },
	[64] = { r = 0.92, g = 0.47, b = 0.88 },
}

local SPELL_COLORS = {
	{ r = 0.35, g = 0.55, b = 0.85 },
	{ r = 0.80, g = 0.48, b = 0.35 },
	{ r = 0.42, g = 0.72, b = 0.52 },
	{ r = 0.72, g = 0.62, b = 0.32 },
	{ r = 0.62, g = 0.48, b = 0.80 },
	{ r = 0.32, g = 0.68, b = 0.72 },
}

local classIconCoords = {}
for class, coords in pairs(CLASS_ICON_TCOORDS or {}) do
	local l, r, t, b = unpack(coords)
	local adj = 0.02
	classIconCoords[class] = { l + adj, r - adj, t + adj, b - adj }
end

local roleIconCoords = {
	DAMAGER = { 0.3125, 0.63, 0.3125, 0.63 },
	HEALER = { 0.3125, 0.63, 0.015625, 0.3125 },
	TANK = { 0, 0.296875, 0.3125, 0.63 },
	LEADER = { 0, 0.296875, 0.015625, 0.3125 },
}

local function snapPixels(value, scale)
	if not value then return 0 end
	if not scale or scale <= 0 then scale = 1 end
	return floor(value * scale + 0.5) / scale
end

local function srgbToLinear(value)
	value = value or 0
	if value <= 0 then return 0 end
	return value ^ 2.2
end

local function mediaStatusbar(key)
	if not key or key == "None" then return "Interface\\Buttons\\WHITE8X8" end
	return media:Fetch("statusbar", key) or "Interface\\Buttons\\WHITE8X8"
end

local function mediaBackground(key)
	if not key or key == "None" then return "Interface\\Buttons\\WHITE8X8" end
	return media:Fetch("background", key) or "Interface\\Buttons\\WHITE8X8"
end

local function fontPath(key, fallback)
	return media:Fetch("font", key) or media:Fetch("font", fallback) or "Fonts\\FRIZQT__.TTF"
end

local function plain(value)
	return type(value) == "string" and not issecretvalue(value) and value ~= ""
end

local function secretKey(value)
	if issecretvalue(value) then return "secret" end
	return tostring(value)
end

local function applyShadow(fs, enabled)
	if not fs then return end
	if enabled then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.85)
	else
		fs:SetShadowOffset(0, 0)
	end
end

local function columnRightOffset(slot)
	return COLUMN_RIGHT_PAD + (3 - slot) * (COLUMN_WIDTH + COLUMN_GAP)
end

local function buildColumnSpec(win)
	local mode = win.selectedmode
	local columns = mode and mode.metadata and mode.metadata.columns
	local custom = mode and mode.metadata and mode.metadata.columnSpec
	if type(custom) == "table" then
		local spec = {}
		for i = 1, #custom do
			local entry = custom[i]
			if type(entry) == "table" and entry.label and entry.value then
				spec[#spec + 1] = { label = entry.label, value = entry.value }
			end
		end
		return spec
	end
	if type(columns) ~= "table" then return {} end
	local secret = win.metadata and win.metadata.wasSecretValues
	local width = win.bargroup and win.bargroup:GetWidth() or 0
	if not width or width < 1 then width = win.db.barwidth or 470 end
	local spec = {}
	if columns.Damage then
		spec[#spec + 1] = { label = "DMG", value = "valueText1" }
	elseif columns.Healing then
		spec[#spec + 1] = { label = "HEAL", value = "valueText1" }
	elseif columns.Absorbs then
		spec[#spec + 1] = { label = "ABS", value = "valueText1" }
	elseif columns.Avoidable then
		spec[#spec + 1] = { label = "AVOID", value = "valueText1" }
	elseif columns.EnemyDamage then
		spec[#spec + 1] = { label = "ENEMY", value = "valueText1" }
	end
	if width >= 300 then
		if columns.DPS then
			spec[#spec + 1] = { label = "DPS", value = "valueText2" }
		elseif columns.HPS then
			spec[#spec + 1] = { label = "HPS", value = "valueText2" }
		elseif columns.DTPS then
			spec[#spec + 1] = { label = "DTPS", value = "valueText2" }
		elseif columns.AbsorbRate then
			spec[#spec + 1] = { label = "APS", value = "valueText2" }
		elseif columns.AvoidableRate then
			spec[#spec + 1] = { label = "ADPS", value = "valueText2" }
		elseif columns.EnemyRate then
			spec[#spec + 1] = { label = "DPS", value = "valueText2" }
		end
	end
	if width >= 400 and not secret and columns.Percent then
		spec[#spec + 1] = { label = "%", value = "valueText3" }
	end
	return spec
end

local function savePosition(frame)
	local win = frame and frame.win
	local db = win and win.db
	if not db then return end
	local parent = frame:GetParent() or UIParent
	local parentHeight = parent:GetHeight()
	local left, top = frame:GetLeft(), frame:GetTop()
	if not parentHeight or parentHeight <= 0 or not left or not top then return end
	local scale = frame:GetScale() or 1
	db.x = left * scale
	db.y = top * scale - parentHeight
	db.point = "TOPLEFT"
end

local function getBarColor(data, win, p)
	local color = data.color
	if not issecretvalue(color) and color then
		return color.r, color.g, color.b, color.a or 1
	end
	if not issecretvalue(data.spellschool) and data.spellschool and p.spellschoolcolors then
		local color = SCHOOL_COLORS[data.spellschool]
		if color then return color.r, color.g, color.b, 1 end
	end
	if not issecretvalue(data.class) and data.class and p.classcolorbars then
		local color = Skada.classcolors[data.class]
		if color then
			local r, g, b, a = color.r, color.g, color.b, color.a or 1
			local mix, amount = p.classcolormix, p.classcolormixamount
			if mix and amount and amount > 0 then
				r = r * (1 - amount) + mix.r * amount
				g = g * (1 - amount) + mix.g * amount
				b = b * (1 - amount) + mix.b * amount
			end
			return r, g, b, a
		end
	end
	if win.metadata and win.metadata.isspelllist then
		local order = tonumber(data.order) or 1
		local color = SPELL_COLORS[((order - 1) % #SPELL_COLORS) + 1]
		return color.r, color.g, color.b, 1
	end
	local color = p.barcolor
	return color.r, color.g, color.b, color.a or 1
end

local function setTextIfChanged(fs, text, secret)
	if not fs then return end
	if secret then
		fs._skadaText = nil
		fs:SetText(text)
		return
	end
	local current = fs:GetText()
	if fs._skadaText ~= text or (not issecretvalue(current) and current ~= text) then
		fs._skadaText = text
		fs:SetText(text)
	end
end

local function ensureColumn(row, index)
	local fs = row.columns[index]
	if not fs then
		fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetJustifyH("RIGHT")
		fs:SetJustifyV("MIDDLE")
		fs:SetWordWrap(false)
		row.columns[index] = fs
	end
	return fs
end

local function layoutRowText(row, frame, spec, p, hasIcon)
	local font = frame._fontPath or "Fonts\\FRIZQT__.TTF"
	local size = frame._fontSize or 13
	local flags = frame._fontFlags or ""
	row.label:SetFont(font, size, flags)
	for i = 1, 3 do
		local fs = row.columns[i]
		if fs then fs:SetFont(font, size, flags) end
	end
	local firstSlot = 4 - #spec
	for i = 1, #spec do
		local slot = firstSlot + i - 1
		local fs = ensureColumn(row, slot)
		fs:SetFont(font, size, flags)
		fs:ClearAllPoints()
		fs:SetPoint("RIGHT", row, "RIGHT", -columnRightOffset(slot), 0)
		fs:SetWidth(COLUMN_WIDTH)
		fs:SetJustifyH("RIGHT")
		fs:Show()
	end
	for i = 1, 3 do
		local fs = row.columns[i]
		if fs and not (i >= firstSlot and i < firstSlot + #spec) then
			fs:Hide()
		end
	end
	local iconOffset = (hasIcon and row.iconSize or 0) + 2
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row, "LEFT", iconOffset, 0)
	if #spec > 0 then
		row.label:SetPoint("RIGHT", row.columns[firstSlot], "LEFT", -2, 0)
	else
		row.label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
	end
	row.label:SetJustifyH("LEFT")
	row._firstVisible = firstSlot
end

local function createRow(frame)
	local row = CreateFrame("Frame", nil, frame)
	row:SetHeight(frame.rowHeight or 22)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.selfOverlay = row:CreateTexture(nil, "ARTWORK")
	row.selfOverlay:SetAllPoints()
	row.selfOverlay:Hide()
	row.fill = row:CreateTexture(nil, "ARTWORK")
	row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.fill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	row.fill:SetVertexColor(0.3, 0.5, 0.8, 1)
	row.icon = row:CreateTexture(nil, "OVERLAY")
	row.icon:SetSize(22, 22)
	row.icon:Hide()
	row.iconFrame = CreateFrame("Frame", nil, row)
	row.iconFrame:SetAllPoints(row.icon)
	row.iconFrame:EnableMouse(false)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetWordWrap(false)
	row.label:SetFont(frame._fontPath or "Fonts\\FRIZQT__.TTF", frame._fontSize or 13, frame._fontFlags or "")
	row.label:SetJustifyV("MIDDLE")
	row.columns = {}
	row.separator = row:CreateTexture(nil, "OVERLAY")
	row.separator:SetHeight(1)
	row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.separator:Hide()
	row:EnableMouse(true)
	return row
end

local function createActionButton(frame, title, key, texture, onClick)
	local b = CreateFrame("Button", nil, frame.button)
	b:SetSize(15, 15)
	b:SetNormalTexture(texture)
	b:SetHighlightTexture(texture, "ADD")
	b:SetAlpha(0.25)
	b:SetScript("OnClick", onClick)
	frame.buttons[#frame.buttons + 1] = b
	b.title = title
	b.key = key
	return b
end

local function applyTitleAndActions(win, frame, p)
	local button = frame.button
	local fontName = "SkadaBarTitle" .. (win.db.name or "window")
	local titleFont = _G[fontName]
	if not titleFont then
		titleFont = CreateFont(fontName)
	end
	titleFont:SetFont(fontPath(p.title.font, "Cinzel"), p.title.fontsize or 13, p.title.fontflags or "")
	titleFont:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a or 1)
	button:SetNormalFontObject(titleFont)

	button:SetHeight(p.title.height or 30)
	if not button.skadaBackground then
		button.skadaBackground = button:CreateTexture(nil, "ARTWORK")
		button.skadaBackground:SetAllPoints(button)
	end
	local titleBg = button.skadaBackground
	local c1, c2 = p.title.color, p.title.color2 or p.title.color
	titleBg:SetColorTexture(1, 1, 1, 1)
	titleBg:SetGradient("HORIZONTAL",
		CreateColor(srgbToLinear(c1.r), srgbToLinear(c1.g), srgbToLinear(c1.b), c1.a or 1),
		CreateColor(srgbToLinear(c2.r), srgbToLinear(c2.g), srgbToLinear(c2.b), c2.a or 1))
	Skada:ApplyBorder(button, p.title.bordertexture, p.title.bordercolor, p.title.borderthickness)

	local fs = button:GetFontString()
	if fs then
		fs:SetJustifyH(p.title.textalign or "LEFT")
		fs:SetJustifyV("MIDDLE")
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", button, "LEFT", max((p.title.paddingleft or 10) + 14, 24), 0)
		applyShadow(fs, p.textshadow)
	end

	local size = p.buttonsize or 15
	local spacing = p.buttonspacing or 6
	local right = p.buttonpaddingright or 10
	local previous = button
	for _, b in ipairs(frame.buttons) do
		local setting = p.buttons and b.key and p.buttons[b.key]
		if setting ~= nil then b:SetShown(setting and true or false) end
		if b:IsShown() then
			b:SetSize(size, size)
			b:ClearAllPoints()
			b:SetPoint("RIGHT", previous, "RIGHT", -right, 0)
			previous = b
			right = spacing
		end
	end
	local alpha = (p.hoverbuttons ~= false) and (frame._titleHover and 1 or 0) or 0.25
	frame:SetButtonsOpacity(alpha)
end

local function createShell(win)
	local frameName = "SkadaBarWindow" .. (win.db.name or "window")
	local frame = _G[frameName]
	if frame then return frame end

	frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
	frame.win = win
	frame.rows = {}
	frame.rowPool = {}
	frame.rowById = {}
	frame.buttons = {}
	frame.offset = 0
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then frame:SetResizeBounds(120, 80, 1600, 1200) end
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(self, direction)
		if self.win then mod:OnMouseWheel(self.win, nil, direction) end
	end)
	frame:SetScript("OnMouseDown", function(self, button)
		local w = self.win
		if not w then return end
		if IsShiftKeyDown() then
			Skada:OpenMenu(w)
		elseif button == "RightButton" then
			w:RightClick()
		end
	end)

	frame.button = CreateFrame("Button", nil, frame)
	frame.button:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
	frame.button:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.button:RegisterForDrag("LeftButton")
	frame.button:SetScript("OnDragStart", function(self)
		local w = self:GetParent().win
		if not w or w.db.barslocked then return end
		self._dragging = true
		self:GetParent():StartMoving()
	end)
	frame.button:SetScript("OnDragStop", function(self)
		local parent = self:GetParent()
		parent:StopMovingOrSizing()
		self._dragging = nil
		savePosition(parent)
	end)
	frame.button:SetScript("OnMouseDown", function(self, button)
		self._startLeft = frame:GetLeft()
		self._startTop = frame:GetTop()
	end)
	frame.button:SetScript("OnMouseUp", function(self, button)
		local w = self:GetParent().win
		if not w then return end
		local moved = math.abs((self._startLeft or frame:GetLeft()) - (frame:GetLeft() or 0)) > 3
			or math.abs((self._startTop or frame:GetTop()) - (frame:GetTop() or 0)) > 3
		if moved or self._dragging then return end
		if button == "LeftButton" then
			Skada:ModeMenu(w)
		elseif button == "RightButton" then
			Skada:SegmentMenu(w)
		end
	end)
	frame.button:SetScript("OnEnter", function(self)
		frame._titleHover = true
		self:GetParent():SetButtonsOpacity((self:GetParent().win.db.hoverbuttons ~= false) and 1 or 0.25)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L["Left click: mode"])
		GameTooltip:AddLine(L["Right click: segment"])
		GameTooltip:Show()
	end)
	frame.button:SetScript("OnLeave", function(self)
		frame._titleHover = false
		self:GetParent():SetButtonsOpacity((self:GetParent().win.db.hoverbuttons ~= false) and 0 or 0.25)
		GameTooltip:Hide()
	end)

	frame.SetButtonsOpacity = function(self, alpha)
		for _, b in ipairs(self.buttons) do b:SetAlpha(alpha) end
	end

	frame.displayToggle = Skada:CreateDisplayButton(frame.button, win, 16)
	frame.displayToggle:SetPoint("LEFT", frame.button, "LEFT", 4, 0)

	createActionButton(frame, L["Reset"], "reset", "Interface\\Buttons\\UI-StopButton", function() Skada:ShowPopup() end)
	createActionButton(frame, L["Segment"], "segment", "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", function() Skada:SegmentMenu(frame.win) end)
	createActionButton(frame, L["Mode"], "mode", "Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON", function() Skada:ModeMenu(frame.win) end)
	createActionButton(frame, L["Report"], "report", "Interface\\Buttons\\UI-GuildButton-MOTD-Up", function() Skada:ReportMenu(frame.win) end)

	local resizeTicker
	local function finishResize()
		if not frame._resizing then return end
		frame._resizing = false
		frame._resizeStart = nil
		if resizeTicker then resizeTicker:Hide() end
		local step = (frame.rowHeight or 22) + (frame.rowSpacing or 1)
		local spacing = frame.rowSpacing or 1
		local height = frame:GetHeight()
		local width = frame:GetWidth()
		if height and height > 1 then
			local rows = max(1, floor((height + spacing) / step + 0.5))
			frame:SetHeight(rows * step - spacing)
		end
		if frame.win then
			if width and width > 1 then frame.win.db.barwidth = width end
			if frame:GetHeight() > 1 then frame.win.db.background.height = frame:GetHeight() end
			savePosition(frame)
			mod:Layout(frame.win)
			mod:Update(frame.win)
		end
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
		if button ~= "LeftButton" then return end
		local x, y = GetCursorPosition()
		local scale = frame:GetEffectiveScale() or 1
		frame._resizeStart = {
			x = x,
			y = y,
			w = frame:GetWidth(),
			h = frame:GetHeight(),
			scale = scale,
		}
		frame._resizing = true
		if resizeTicker then resizeTicker:Show() end
	end)
	resize:SetScript("OnMouseUp", finishResize)
	frame.resizeButton = resize

	resizeTicker = CreateFrame("Frame", nil, frame)
	resizeTicker:Hide()
	resizeTicker:SetScript("OnUpdate", function(self)
		if not frame._resizing then
			self:Hide()
			return
		end
		if not (_G.IsMouseButtonDown and _G.IsMouseButtonDown("LeftButton")) then
			finishResize()
			return
		end
		local start = frame._resizeStart
		if not start then
			finishResize()
			return
		end
		local x, y = GetCursorPosition()
		local scale = start.scale or 1
		if scale <= 0 then scale = 1 end
		local width = max(160, min(1600, start.w + (x - start.x) / scale))
		local height = max(80, min(1200, start.h + (start.y - y) / scale))
		frame:SetSize(width, height)
		if frame.win then
			frame.win.db.barwidth = width
			frame.win.db.background.height = height
			mod:Layout(frame.win)
			mod:Update(frame.win)
		end
	end)
	frame.resizeTicker = resizeTicker

	frame:SetScript("OnSizeChanged", function(self)
		if self._sizingGuard or self._resizing then return end
		self._sizingGuard = true
		local width, height = self:GetWidth(), self:GetHeight()
		if self.win and width and height and width > 1 and height > 1 then
			self.win.db.barwidth = width
			self.win.db.background.height = height
			if self.display == mod then
				mod:Layout(self.win)
				mod:Update(self.win)
			end
		end
		self._sizingGuard = nil
	end)

	frame.header = CreateFrame("Frame", nil, frame.button)
	frame.header.labels = {}
	for i = 1, 3 do
		local fs = frame.header:CreateFontString(nil, "OVERLAY")
		fs:SetJustifyH("RIGHT")
		fs:SetJustifyV("MIDDLE")
		fs:Hide()
		frame.header.labels[i] = fs
	end

	libwindow.RegisterConfig(frame, win.db)
	return frame
end

local function setRowStyle(row, data, win, p, hasIcon)
	local r, g, b, a = getBarColor(data, win, p)
	row.fill:SetVertexColor(r, g, b, a)

	local class = data.class
	if not issecretvalue(class) and class and p.classcolortext then
		local c = Skada.classcolors[class]
		if c then
			row.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
		else
			row.label:SetTextColor(1, 1, 1, 1)
		end
	else
		local c = p.labelcolor
		row.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
	end
	for i = 1, 3 do
		local fs = row.columns[i]
		if fs then
			if not issecretvalue(class) and class and p.classcolortext then
				local c = Skada.classcolors[class]
				fs:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, 1)
			else
				local c = p.valuetextcolor or { r = 1, g = 1, b = 1, a = 1 }
				fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
			end
		end
	end

	local bg = p.barbgcolor
	local bgAlpha = p.transparentbackground and 0 or (bg.a or 0.6)
	if p.alternaterows and row._visibleIndex and row._visibleIndex % 2 == 0 then
		local d = 0.04
		row.bg:SetColorTexture(max(0, bg.r - d), max(0, bg.g - d), max(0, bg.b - d), min(1, bgAlpha + d))
	else
		row.bg:SetColorTexture(bg.r, bg.g, bg.b, bgAlpha)
	end

	if p.highlightself and row._isSelf then
		local sc = p.selfhighlightcolor or { r = 1, g = 1, b = 1, a = 0.12 }
		row.selfOverlay:SetColorTexture(sc.r, sc.g, sc.b, sc.a or 0.12)
		row.selfOverlay:Show()
	else
		row.selfOverlay:Hide()
	end

	if p.showrowseparators then
		local c = p.rowseparatorcolor or { r = 0.3, g = 0.45, b = 0.6, a = 0.25 }
		row.separator:SetColorTexture(c.r, c.g, c.b, c.a or 0.25)
		row.separator:Show()
	else
		row.separator:Hide()
	end

	if row.icon:IsShown() then
		local iconScale = (p.iconscale or 100) / 100
		row.iconSize = (row:GetHeight() or 22) * iconScale
		row.icon:SetSize(row.iconSize, row.iconSize)
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	else
		row.iconSize = 0
	end
	applyShadow(row.label, p.textshadow)
	for i = 1, 3 do
		applyShadow(row.columns[i], p.textshadow)
	end
end

function mod:Create(window, isNew)
	local frame = createShell(window)
	window.bargroup = frame
	frame.win = window
	frame.display = mod
	frame.offset = frame.offset or 0
	if frame.buttons then
		for _, b in ipairs(frame.buttons) do b:Show() end
	end
	libwindow.RegisterConfig(frame, window.db)
	libwindow.RestorePosition(frame)
	frame:Show()
	mod:Layout(window)
end

function mod:Destroy(win)
	if win.bargroup then
		stopAnimator(win.bargroup)
		win.bargroup:Hide()
		win.bargroup.win = nil
		win.bargroup = nil
	end
end

function mod:Wipe(win)
	local frame = win.bargroup
	if not frame then return end
	stopAnimator(frame)
	frame.offset = 0
	for _, row in ipairs(frame.rows) do
		row:Hide()
		row.id = nil
		row._anim = nil
		row._targetWidth = nil
		row._currentWidth = nil
		row._targetY = nil
		row._currentY = nil
		if row.spark then row.spark:Hide() end
		frame.rowPool[#frame.rowPool + 1] = row
	end
	frame.rows = {}
	frame.rowById = {}
end

function mod:SetTitle(win, title)
	local frame = win.bargroup
	if not frame or not frame.button then return end
	local secret = issecretvalue(title)
	if not secret and frame._lastTitle == title then return end
	frame._lastTitle = secret and nil or title
	local fs = frame.button:GetFontString()
	if fs then fs:SetText(title) else frame.button:SetText(title) end
end

function mod:Layout(win)
	local frame = win.bargroup
	if not frame then return end
	frame._styleVersion = (frame._styleVersion or 0) + 1
	stopAnimator(frame)
	for _, row in ipairs(frame.rows) do
		row._anim = nil
		row._targetWidth = nil
		row._currentWidth = nil
		row._targetY = nil
		row._currentY = nil
	end
	local p = win.db
	local scale = frame:GetEffectiveScale() or 1
	frame.rowHeight = snapPixels(p.barheight or 22, scale)
	frame.rowSpacing = snapPixels(p.barspacing or 1, scale)
	frame:SetWidth(p.barwidth or 470)
	frame:SetHeight(p.background.height or 300)
	if frame.button then frame.button:SetHeight(p.title.height or 30) end
	if p.strata then frame:SetFrameStrata(p.strata) end
	frame:SetScale(p.scale or 1)
	frame:SetBackdrop({ bgFile = mediaBackground(p.background.texture), edgeFile = nil, tile = false, edgeSize = 0 })
	local bg = p.background.color
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
	Skada:ApplyBorder(frame, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness)

	local texture = p.bartexturepath or mediaStatusbar(p.bartexture)
	local font = fontPath(p.barfont, "ABF")
	frame._fontPath = font
	frame._fontSize = p.barfontsize or 13
	frame._fontFlags = p.barfontflags or ""
	for _, row in ipairs(frame.rows) do
		row:SetHeight(frame.rowHeight)
		row:EnableMouse(not p.clickthrough)
		row:EnableMouseWheel(not p.clickthrough)
		if row.iconFrame then row.iconFrame:EnableMouse(not p.clickthrough) end
		row.fill:SetTexture(texture)
		row.label:SetFont(font, p.barfontsize or 13, p.barfontflags or "")
		for i = 1, 3 do
			local fs = row.columns[i]
			if fs then fs:SetFont(font, p.barfontsize or 13, p.barfontflags or "") end
		end
	end

	local header = frame.header
	if header then
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", frame.button, "TOPLEFT", 0, 0)
		header:SetPoint("BOTTOMRIGHT", frame.button, "BOTTOMRIGHT", 0, 0)
		header:SetFrameLevel((frame.button:GetFrameLevel() or 1) + 2)
		local spec = buildColumnSpec(win)
		local show = p.showcolumnheaders and #spec > 0
		header:SetShown(show and true or false)
		if show then
			for i = 1, 3 do header.labels[i]:Hide() end
			local first = 4 - #spec
			local font2 = fontPath(p.columnheaderfont or p.barfont, "Marcellus")
			local c = p.columnheadertextcolor or p.title.textcolor
			for i = 1, #spec do
				local slot = first + i - 1
				local fs = header.labels[slot]
				fs:SetFont(font2, p.columnheaderfontsize or 8, p.columnheaderfontflags or "")
				fs:SetTextColor(c.r, c.g, c.b, (c.a or 1) * 0.8)
				fs:SetText(spec[i].label)
				fs:ClearAllPoints()
				fs:SetPoint("RIGHT", header, "RIGHT", -columnRightOffset(slot), 0)
				fs:Show()
			end
		end
	end
	applyTitleAndActions(win, frame, p)
	frame:SetButtonsOpacity((p.hoverbuttons ~= false) and (frame._titleHover and 1 or 0) or 0.25)
	if frame.resizeButton then frame.resizeButton:SetShown(not p.barslocked) end
	frame:EnableMouse(not p.clickthrough)
	if p.enabletitle == false and frame.button then frame.button:Hide() else frame.button:Show() end
end

local function setIcon(row, data, win, p)
	local icon, coord
	local role, class, dataIcon = data.role, data.class, data.icon
	if not issecretvalue(data.id) and data.id == "total" and p.totalicon then
		icon = p.totalicon
	elseif not issecretvalue(role) and role and role ~= "NONE" and p.roleicons then
		icon = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
		coord = roleIconCoords[role]
	elseif not issecretvalue(class) and class and p.classicons and classIconCoords[class] then
		icon = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
		coord = classIconCoords[class]
	elseif not issecretvalue(dataIcon) and dataIcon then
		icon = dataIcon
	end
	if not icon then
		row.icon:Hide()
		row.iconFrame:EnableMouse(false)
		return false
	end
	row.icon:SetTexture(icon)
	if coord then
		row.icon:SetTexCoord(coord[1], coord[2], coord[3], coord[4])
	else
		row.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	end
	row.icon:Show()
	row.iconSize = (row:GetHeight() or 22) * ((p.iconscale or 100) / 100)
	row.icon:SetSize(row.iconSize, row.iconSize)
	row.icon:ClearAllPoints()
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.iconFrame:EnableMouse(not p.clickthrough)
	row.iconFrame.bar = row
	return true
end

local function iconEnter(iconFrame)
	local row = iconFrame.bar
	local win = row and row.win
	if not row or not win then return end
	if row.spellid then
		Skada:SetTooltipPosition(GameTooltip, win.bargroup)
		GameTooltip:SetHyperlink("spell:" .. row.spellid)
		GameTooltip:Show()
	elseif row.link then
		Skada:SetTooltipPosition(GameTooltip, win.bargroup)
		GameTooltip:SetHyperlink(row.link)
		GameTooltip:Show()
	end
end

local function showMode(win, id, label, mode)
	if win.selectedmode then table.insert(win.history, win.selectedmode) end
	if mode.Enter then pcall(mode.Enter, mode, win, id, label) end
	win:DisplayMode(mode)
end

local function rowClick(row, button)
	local win = row.win
	if not win then return end
	Skada._lastActiveWindow = win
	local click1, click2, click3 = win.metadata.click1, win.metadata.click2, win.metadata.click3
	win._drillSource = row.source
	win._drillIsLocalPlayer = row.isLocalPlayer
	win._drillSourceGUID = row.sourceGUID
	win._drillSourceCreatureID = row.sourceCreatureID
	if button == "RightButton" and IsShiftKeyDown() then
		Skada:OpenMenu(win)
	elseif win.metadata.click then
		win.metadata.click(win, row.id, row.text, button)
	elseif button == "RightButton" then
		win:RightClick()
	elseif click2 and IsShiftKeyDown() then
		showMode(win, row.id, row.text, click2)
	elseif click3 and IsControlKeyDown() then
		showMode(win, row.id, row.text, click3)
	elseif click1 then
		showMode(win, row.id, row.text, click1)
	end
end

local function rowEnter(row)
	local win = row.win
	if not win then return end
	win._hoverSource = row.source
	win._hoverIsLocalPlayer = row.isLocalPlayer
	win._hoverSourceGUID = row.sourceGUID
	win._hoverSourceCreatureID = row.sourceCreatureID
	win._hoverSpell = row.spellData
	Skada:SetTooltipPosition(GameTooltip, win.bargroup)
	Skada:ShowTooltip(win, row.id, row.text)
end

local function rowLeave(row)
	local win = row.win
	if not win then return end
	win._hoverSource = nil
	win._hoverIsLocalPlayer = nil
	win._hoverSourceGUID = nil
	win._hoverSourceCreatureID = nil
	win._hoverSpell = nil
	GameTooltip:Hide()
end

local function rowWheel(row, direction)
	local win = row.win
	if not win then return end
	mod:OnMouseWheel(win, nil, direction)
end

local function resetRowForUse(row)
	row.label._skadaText = nil
	row.label:SetText("")
	for i = 1, 3 do
		local fs = row.columns[i]
		if fs then
			fs._skadaText = nil
			fs:SetText("")
			fs:Hide()
		end
	end
	row._specKey = nil
	row._singleText = nil
	row._iconKey = nil
	row._styleKey = nil
	row._hasIcon = false
	row._anim = nil
	row._targetWidth = nil
	row._currentWidth = nil
	row._targetY = nil
	row._currentY = nil
end

local function acquireRow(frame)
	local row = table.remove(frame.rowPool)
	if not row then
		row = createRow(frame)
		row.win = frame.win
		row:SetScript("OnEnter", rowEnter)
		row:SetScript("OnLeave", rowLeave)
		row:SetScript("OnMouseDown", rowClick)
		row:SetScript("OnMouseWheel", rowWheel)
		row:EnableMouseWheel(true)
		row.iconFrame:SetScript("OnEnter", iconEnter)
		row.iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.iconFrame:SetScript("OnMouseDown", function(iconFrame, button)
			if button == "LeftButton" and not IsShiftKeyDown() then
				rowClick(iconFrame.bar, button)
			end
		end)
	end
	row.win = frame.win
	resetRowForUse(row)
	row:Show()
	return row
end

local function releaseRow(frame, row)
	local id = row.id
	row:Hide()
	row.id = nil
	row._anim = nil
	row._targetWidth = nil
	row._currentWidth = nil
	row._currentY = nil
	row._targetY = nil
	if row.spark then row.spark:Hide() end
	if id ~= nil then frame.rowById[id] = nil end
	frame.rowPool[#frame.rowPool + 1] = row
end

local function anchorRow(row, frame, y, growup)
	row:ClearAllPoints()
	if growup then
		row:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, y)
		row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, y)
	else
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
		row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
	end
end

local function stepAnimations(frame, elapsed)
	local active = false
	for _, row in ipairs(frame.rows) do
		local target = row._targetWidth
		if target then
			local current = row._currentWidth or target
			local diff = target - current
			if math.abs(diff) <= 0.5 then
				row._currentWidth = target
				row._targetWidth = nil
				row.fill:SetWidth(target)
			else
				current = current + diff * 0.25
				row._currentWidth = current
				row.fill:SetWidth(current)
				active = true
			end
		end
		local anim = row._anim
		if anim then
			anim.elapsed = (anim.elapsed or 0) + elapsed
			local t = min(1, anim.elapsed / 0.16)
			local eased = 1 - (1 - t) * (1 - t)
			local y = anim.fromY + (anim.toY - anim.fromY) * eased
			row._currentY = y
			anchorRow(row, frame, y, row._growup)
			if t >= 1 then
				row._currentY = anim.toY
				row._anim = nil
			else
				active = true
			end
		end
	end
	if not active then
		frame:SetScript("OnUpdate", nil)
		frame._animating = false
	end
end

local function ensureAnimator(frame)
	if frame._animating then return end
	frame._animating = true
	frame:SetScript("OnUpdate", stepAnimations)
end

stopAnimator = function(frame)
	frame:SetScript("OnUpdate", nil)
	frame._animating = false
	for _, row in ipairs(frame.rows or {}) do
		row._anim = nil
		row._targetY = nil
		row._currentY = nil
	end
end

function mod:Update(win)
	local frame = win.bargroup
	if not frame then return end
	local p = win.db
	local dataset = win.dataset or {}
	if win.metadata.showspots then table_sort(dataset, Skada.value_sort) end
	local spec = buildColumnSpec(win)
	local maxvalue = win.metadata.maxvalue or 1
	if type(maxvalue) ~= "number" or maxvalue <= 0 then maxvalue = 1 end
	local step = (frame.rowHeight or 22) + (frame.rowSpacing or 1)
	local visibleRows = max(1, floor(((frame:GetHeight() or 100) + frame.rowSpacing) / step))
	local startIndex = min((frame.offset or 0) + 1, #dataset)
	local endIndex = min(#dataset, startIndex + visibleRows - 1)
	local specKey = table.concat({ tostring(frame:GetWidth()), tostring(#spec), tostring(p.iconscale), tostring(p.classicons), tostring(p.roleicons) }, ":")
	local fillVersion = tostring(p.barorientation or 1) .. ":" .. tostring(p.barinset or 0)
	local styleVersion = frame._styleVersion or 0
	local viewTitle = win.metadata and win.metadata.title
	if not issecretvalue(viewTitle) and frame._lastViewTitle ~= viewTitle then
		frame._lastViewTitle = viewTitle
		frame._skipAnimation = true
	end
	if frame._lastSelectedMode ~= win.selectedmode then
		frame._lastSelectedMode = win.selectedmode
		frame._skipAnimation = true
	end

	local kept = {}
	local nr = 1
	local visibleIndex = 0
	for i = 1, #dataset do
		local data = dataset[i]
		if data.id and i >= startIndex and i <= endIndex then
			local row = frame.rowById[data.id]
			if not row then
				row = acquireRow(frame)
				row.id = data.id
				frame.rowById[data.id] = row
				frame.rows[#frame.rows + 1] = row
			end
			kept[row] = true
			row.win = win
			row.text = data.label
			row.spellData = data
			row.spellid = data.spellid
			row.link = data.hyperlink
			row.source = data.source or win._drillSource
			row.isLocalPlayer = data.isLocalPlayer
			row.sourceGUID = data.sourceGUID or win._drillSourceGUID
			row.sourceCreatureID = data.sourceCreatureID or win._drillSourceCreatureID
			visibleIndex = visibleIndex + 1
			row._visibleIndex = visibleIndex

			local iconKey = secretKey(data.role) .. "|" .. secretKey(data.class) .. "|" .. secretKey(data.icon) .. "|" .. tostring(p.roleicons) .. "|" .. tostring(p.classicons)
			if row._iconKey ~= iconKey then
				row._iconKey = iconKey
				row._hasIcon = setIcon(row, data, win, p)
			end

			if row._specKey ~= specKey then
				row._specKey = specKey
				layoutRowText(row, frame, spec, p, row._hasIcon)
			end

			local isSelf = data.isSelf == true
			local playerGUID = UnitGUID("player")
			if not isSelf and not issecretvalue(data.id) and type(playerGUID) == "string"
				and not issecretvalue(playerGUID) and data.id == playerGUID then
				isSelf = true
			end
			row._isSelf = isSelf
			local styleKey = secretKey(data.class) .. "|" .. secretKey(data.spellschool) .. "|" .. secretKey(data.color) .. "|" .. tostring(visibleIndex % 2) .. "|" .. tostring(styleVersion) .. "|" .. tostring(win.metadata.isspelllist) .. "|" .. tostring(isSelf) .. "|" .. tostring(p.highlightself)
			if row._styleKey ~= styleKey then
				row._styleKey = styleKey
				setRowStyle(row, data, win, p, row._hasIcon)
			end

			local label = data.label
			if win.metadata.showspots and Skada.db.profile.showranks and not data.ignore
				and not issecretvalue(label) then
				label = ("%2u. %s"):format(nr, label)
			end
			setTextIfChanged(row.label, label, issecretvalue(label))

			local valuetext = data.valuetext
			local valuetextSecret = issecretvalue(valuetext)
			if valuetextSecret or valuetext ~= nil then
				local valueColumn = ensureColumn(row, 3)
				valueColumn:SetFont(frame._fontPath or "Fonts\\FRIZQT__.TTF", frame._fontSize or 13, frame._fontFlags or "")
				valueColumn:ClearAllPoints()
				valueColumn:SetPoint("RIGHT", row, "RIGHT", -COLUMN_RIGHT_PAD, 0)
				valueColumn:SetWidth(COLUMN_WIDTH)
				valueColumn:SetJustifyH("RIGHT")
				for i2 = 1, 3 do
					local fs = row.columns[i2]
					if fs then
						if i2 == 3 then
							setTextIfChanged(fs, valuetext, valuetextSecret)
							if not fs:IsShown() then fs:Show() end
						else
							setTextIfChanged(fs, "", false)
							if fs:IsShown() then fs:Hide() end
						end
					end
				end
				if not row._singleText then
					row._singleText = true
					row.label:ClearAllPoints()
					row.label:SetPoint("LEFT", row, "LEFT", (row.iconSize or 0) + 2, 0)
					row.label:SetPoint("RIGHT", row.columns[3], "LEFT", -2, 0)
				end
			else
				if row._singleText then
					row._singleText = nil
					row._specKey = nil
					layoutRowText(row, frame, spec, p, row._hasIcon)
					row._specKey = specKey
				end
				local firstSlot = 4 - #spec
				for si = 1, #spec do
					local slot = firstSlot + si - 1
					local fs = row.columns[slot]
					if fs then
						local key = spec[si].value
						setTextIfChanged(fs, data[key], issecretvalue(data[key]))
					end
				end
			end

			local value = data.value
			if type(value) ~= "number" then value = 0 end
			local ratio = max(0, min(1, value / maxvalue))
			local inset = p.barinset or 0
			local usable = max(0, frame:GetWidth() - inset * 2)
			if row._fillVersion ~= fillVersion then
				row._fillVersion = fillVersion
				row.fill:ClearAllPoints()
				if p.barorientation == 2 then
					row.fill:SetPoint("TOPRIGHT", row, "TOPRIGHT", -inset, -inset)
					row.fill:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -inset, inset)
				else
					row.fill:SetPoint("TOPLEFT", row, "TOPLEFT", inset, -inset)
					row.fill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", inset, inset)
				end
			end
			local targetWidth = max(1, usable * ratio)
			if p.smoothing and not frame._resizing and row._currentWidth then
				if math.abs(row._currentWidth - targetWidth) > 0.5 then
					row._targetWidth = targetWidth
					ensureAnimator(frame)
				else
					row._targetWidth = nil
				end
			else
				row._targetWidth = nil
				row._currentWidth = targetWidth
				row.fill:SetWidth(targetWidth)
			end

			local index = row._visibleIndex
			local y = (index - 1) * step
			if row._targetY ~= y or row._growup ~= p.reversegrowth then
				local grew = p.reversegrowth and true or false
				row._targetY = y
				row._growup = grew
				if p.animaterows == false or frame._resizing or frame._skipAnimation or not row._currentY or not row:IsShown() then
					row._currentY = y
					row._anim = nil
					anchorRow(row, frame, y, grew)
				else
					row._anim = { fromY = row._currentY, toY = y, elapsed = 0 }
					ensureAnimator(frame)
				end
			end
			if row:GetHeight() ~= frame.rowHeight then row:SetHeight(frame.rowHeight) end
			if not row:IsShown() then row:Show() end
			if p.spark and visibleIndex == 1 then
				if not row.spark then
					row.spark = row:CreateTexture(nil, "OVERLAY")
					row.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
					row.spark:SetBlendMode("ADD")
					row.spark:SetWidth(12)
				end
				row.spark:SetHeight((frame.rowHeight or 22) * 2.2)
				row.spark:ClearAllPoints()
				row.spark:SetPoint("CENTER", row.fill, "RIGHT", 0, 0)
				row.spark:Show()
			elseif row.spark then
				row.spark:Hide()
			end

			if not data.ignore then nr = nr + 1 end
		end
	end

	for _, row in ipairs(frame.rows) do
		if not kept[row] then
			releaseRow(frame, row)
		end
	end
	local active = {}
	for row in pairs(kept) do active[#active + 1] = row end
	frame.rows = active
	frame._skipAnimation = nil
end

function mod:Dump(win)
	win = win or Skada._lastActiveWindow or Skada:GetWindows()[1]
	local frame = win and win.bargroup
	if not frame then
		Skada:Print("Bar diagnostic: no active bar window.")
		return
	end
	Skada:Print(("Bar diagnostic: display=%s rows=%d frame=%sx%s scale=%s effective=%s dbScale=%s"):format(
		tostring(win.db.display), #(frame.rows or {}), tostring(frame:GetWidth()), tostring(frame:GetHeight()),
		tostring(frame:GetScale()), tostring(frame:GetEffectiveScale()), tostring(win.db.scale)))
	for i, row in ipairs(frame.rows or {}) do
		local text = row.label:GetText()
		local textDesc
		if issecretvalue(text) then textDesc = "<secret>"
		elseif type(text) == "string" then textDesc = ("%q"):format(text)
		else textDesc = tostring(text) end
		local data = row.spellData
		local dataLabel = data and data.label
		local dataDesc
		if issecretvalue(dataLabel) then dataDesc = "<secret>"
		elseif type(dataLabel) == "string" then dataDesc = ("%q"):format(dataLabel)
		else dataDesc = tostring(dataLabel) end
		local r, g, b, a = row.label:GetTextColor()
		local sw = "?"
		pcall(function() sw = row.label:GetStringWidth() end)
		Skada:Print(("row %d id=%s text=%s data=%s shown=%s label=%sx%s at %s,%s stringW=%s alpha=%s color=%.2f/%.2f/%.2f/%.2f y=%s targetY=%s anim=%s"):format(
			i, tostring(row.id), textDesc, dataDesc, tostring(row.label:IsShown()),
			tostring(row.label:GetWidth()), tostring(row.label:GetHeight()),
			tostring(row.label:GetLeft()), tostring(row.label:GetTop()), tostring(sw), tostring(row.label:GetAlpha()),
			r, g, b, a, tostring(row._currentY), tostring(row._targetY), tostring(row._anim ~= nil)))
	end
end

function mod:ApplySettings(win)
	mod:Layout(win)
	mod:Update(win)
end

function mod:Show(win)
	if win.bargroup then
		win.bargroup:Show()
		mod:Layout(win)
		mod:Update(win)
	end
end

function mod:Hide(win)
	if win.bargroup then
		stopAnimator(win.bargroup)
		win.bargroup:Hide()
	end
end

function mod:IsShown(win)
	return win.bargroup and win.bargroup:IsShown() or false
end

function mod:OnMouseWheel(win, frame, direction)
	local g = win.bargroup
	if not g then return end
	local step = (g.rowHeight or 22) + (g.rowSpacing or 1)
	local visible = max(1, floor((g:GetHeight() or 100) / step))
	local maxOffset = max(0, #(win.dataset or {}) - visible)
	if direction == 1 then
		g.offset = max(0, (g.offset or 0) - 1)
	elseif direction == -1 then
		g.offset = min(maxOffset, (g.offset or 0) + 1)
	end
	mod:Update(win)
end

function mod:AddDisplayOptions(win, options)
	if Skada.AddBarDisplayOptions then
		Skada.AddBarDisplayOptions(win, options)
	else
		options.frameoptions = Skada:FrameSettings(win.db, true)
	end
end

