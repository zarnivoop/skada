local _, Skada = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)
local SettingsAPI = _G.Settings
local MenuUtil = _G.MenuUtil

local ACCENT = { 0.36, 0.62, 0.83 }
local MUTED = { 0.72, 0.76, 0.82 }

local UI = {}

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

local function OptionName(option)
	if type(option.name) == "function" then
		return SafeCall(option.name) or ""
	end
	return tostring(option.name or "")
end

local function OptionDesc(option)
	if type(option.desc) == "function" then
		return SafeCall(option.desc) or ""
	end
	return tostring(option.desc or "")
end

local function CallGet(option, ctx, path)
	local getter = option.get or ctx.get
	if type(getter) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(getter, path)
	if ok then return a, b, c, d end
	return nil
end

local function CallSet(option, ctx, path, ...)
	local setter = option.set or ctx.set
	if type(setter) ~= "function" then return end
	pcall(setter, path, ...)
end

local function IsDisabled(option, ctx, path)
	local disabled = option.disabled or ctx.disabled
	if type(disabled) == "function" then
		return SafeCall(disabled, path) and true or false
	end
	return disabled == true
end

local function ResolveValues(option, path)
	local values = option.values
	if type(values) == "function" then
		values = SafeCall(values, path)
	end
	if type(values) ~= "table" then return {} end
	return values
end

local function SortedValueKeys(values)
	local keys = {}
	for key in pairs(values) do
		if not issecretvalue(key) then keys[#keys + 1] = key end
	end
	table.sort(keys, function(a, b)
		if type(a) == "number" and type(b) == "number" then return a < b end
		return tostring(a) < tostring(b)
	end)
	return keys
end

local function ValueLabel(values, key)
	local label = values[key]
	if label == nil then return tostring(key) end
	return tostring(label)
end

local function Place(page, frame)
	local y = page._y or 0
	frame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
	frame:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
	page._y = y + (frame:GetHeight() or 0) + 4
end

local function AddBackdrop(frame, alpha)
	if not frame.SetBackdrop and _G.BackdropTemplateMixin then
		_G.Mixin(frame, _G.BackdropTemplateMixin)
	end
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(0.10, 0.12, 0.16, alpha or 0.45)
	frame:SetBackdropBorderColor(1, 1, 1, 0.05)
end

local function MakeText(parent, font, size, text, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetFontObject(_G[font] or _G.GameFontHighlight)
	if size then fs:SetFont(fs:GetFont(), size) end
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
	return fs
end

local function Refresh()
	if UI and UI.frame and UI.frame:IsShown() then
		UI:BuildPage()
	end
end

-- Confirmation popup used by execute options.
local confirmCallback
_G.StaticPopupDialogs["SKADA_MODERN_CONFIRM"] = {
	text = "%s",
	button1 = _G.YES or "Yes",
	button2 = _G.NO or "No",
	OnAccept = function() if confirmCallback then local f = confirmCallback; confirmCallback = nil; f() end end,
	OnCancel = function() confirmCallback = nil end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function ShowConfirm(question, callback)
	confirmCallback = callback
	local dialog = StaticPopup_Show("SKADA_MODERN_CONFIRM", question)
	return dialog
end

local pendingWindowDisplay

_G.StaticPopupDialogs["SKADA_NEW_WINDOW"] = {
	text = L["Enter the name for the window."],
	button1 = _G.OKAY or "OK",
	button2 = _G.CANCEL or "Cancel",
	hasEditBox = true,
	maxLetters = 32,
	OnShow = function(self)
		local box = self.EditBox or self.editBox
		if box then
			box:SetText("")
			box:SetFocus()
		end
	end,
	OnAccept = function(self)
		local box = self.EditBox or self.editBox
		local name = box and strtrim(box:GetText() or "") or ""
		if name ~= "" and pendingWindowDisplay then
			Skada:CreateWindow(name, nil, pendingWindowDisplay)
			if Skada.settingsUI then
				Skada.settingsUI.selectedWindow = name
				Skada.settingsUI:BuildPage()
			end
		end
		pendingWindowDisplay = nil
	end,
	OnCancel = function() pendingWindowDisplay = nil end,
	EditBoxOnEnterPressed = function(self)
		local name = strtrim(self:GetText() or "")
		if name ~= "" and pendingWindowDisplay then
			Skada:CreateWindow(name, nil, pendingWindowDisplay)
			if Skada.settingsUI then
				Skada.settingsUI.selectedWindow = name
				Skada.settingsUI:BuildPage()
			end
			pendingWindowDisplay = nil
		end
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function Skada:PromptNewWindow(displayKey)
	local display = Skada.displays and Skada.displays[displayKey]
	local name = display and display.name or displayKey or L["Bar"]
	pendingWindowDisplay = displayKey or "bar"
	StaticPopup_Show("SKADA_NEW_WINDOW", name)
end

local function CreateRow(page, height)
	local row = CreateFrame("Frame", nil, page, "BackdropTemplate")
	row:SetHeight(height or 48)
	row:SetPoint("LEFT", page, "LEFT", 0, 0)
	row:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	Place(page, row)
	row:EnableMouse(true)
	AddBackdrop(row, 0.24)
	if row.SetBackdropColor then
		row:SetBackdropColor(0.10, 0.12, 0.16, 0.16)
		row:SetScript("OnEnter", function(self)
			self:SetBackdropColor(0.14, 0.18, 0.23, 0.42)
		end)
		row:SetScript("OnLeave", function(self)
			self:SetBackdropColor(0.10, 0.12, 0.16, 0.16)
		end)
	end
	return row
end

local function AddSection(page, title, desc)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetHeight(desc and 48 or 32)
	holder:SetPoint("LEFT", page, "LEFT", 0, 0)
	holder:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	Place(page, holder)
	local fs = MakeText(holder, "GameFontNormal", 13, "", ACCENT)
	fs:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -8)
	fs:SetText(string.upper(tostring(title or "")))
	if desc and desc ~= "" then
		local d = MakeText(holder, "GameFontNormalSmall", 11, desc, MUTED)
		d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
		d:SetPoint("RIGHT", holder, "RIGHT", -4, 0)
	end
	return holder
end

local function AddDescription(page, text)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetPoint("LEFT", page, "LEFT", 0, 0)
	holder:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	local fs = MakeText(holder, "GameFontNormalSmall", 11, text, MUTED)
	fs:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -4)
	fs:SetPoint("RIGHT", holder, "RIGHT", -4, 0)
	holder:SetHeight(math.max(18, fs:GetStringHeight() + 8))
	Place(page, holder)
	return holder
end

local function AddHeader(page, text)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetHeight(26)
	holder:SetPoint("LEFT", page, "LEFT", 0, 0)
	holder:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	Place(page, holder)
	local fs = MakeText(holder, "GameFontNormal", 11, string.upper(tostring(text or "")), ACCENT)
	fs:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -8)
	return holder
end

local function AttachTooltip(frame, text)
	if not text or text == "" then return end
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function CreateCheckbox(row, option, ctx, path)
	local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	local value = CallGet(option, ctx, path) and true or false
	check:SetChecked(value)
	if IsDisabled(option, ctx, path) then check:Disable() else check:Enable() end
	check:SetScript("OnClick", function(self)
		CallSet(option, ctx, path, not value)
		Refresh()
	end)
	return check
end

local function CreateSlider(row, option, ctx, path)
	local uid = (UI.sliderCounter or 0) + 1
	UI.sliderCounter = uid
	local name = "SkadaSettingsSlider" .. uid
	local slider = CreateFrame("Slider", name, row, "OptionsSliderTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	slider:SetWidth(210)
	local low = _G[name .. "Low"]
	local high = _G[name .. "High"]
	if low then low:SetText("") end
	if high then high:SetText("") end
	local min = tonumber(option.min) or 0
	local max = tonumber(option.max) or 1
	local step = tonumber(option.step) or 0.01
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	local value = tonumber(CallGet(option, ctx, path)) or min
	slider:SetValue(value)
	local valueText = MakeText(row, "GameFontHighlightSmall", 11, "", MUTED)
	valueText:SetPoint("RIGHT", slider, "RIGHT", 0, 15)
	local disabled = IsDisabled(option, ctx, path)
	if disabled then slider:Disable() else slider:Enable() end
	local function format(v)
		if step < 0.1 then
			return string.format("%.2f", v)
		elseif step < 1 then
			return string.format("%.1f", v)
		else
			return string.format("%d", math.floor(v + 0.5))
		end
	end
	valueText:SetText(format(value))
	if not disabled then
		slider:SetScript("OnValueChanged", function(_, v)
			valueText:SetText(format(v))
		end)
		slider:SetScript("OnMouseUp", function(_, button)
			if button == "LeftButton" then
				CallSet(option, ctx, path, slider:GetValue())
			end
		end)
	end
	return slider
end

local mediaPicker
local function GetMediaPicker()
	if mediaPicker then return mediaPicker end
	local frame = CreateFrame("Frame", "SkadaMediaPicker", UIParent, "BackdropTemplate")
	frame:SetSize(380, 420)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	AddBackdrop(frame, 0.98)
	frame.title = MakeText(frame, "GameFontNormal", 14, "", { 1, 1, 1, 1 })
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() frame:Hide() end)

	local searchLabel = MakeText(frame, "GameFontNormalSmall", 10, L["Search"], MUTED)
	searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -34)
	local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	search:SetSize(320, 24)
	search:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -50)
	search:SetAutoFocus(false)
	search:SetMaxLetters(60)
	frame.search = search

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -82)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 14)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(320)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	frame.scroll = scroll
	frame.content = content
	frame.rows = {}

	local function styleRow(row, selected, hovered)
		if not row.SetBackdropColor then return end
		if selected then
			row:SetBackdropColor(0.20, 0.38, 0.55, 0.55)
			row:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
		elseif hovered then
			row:SetBackdropColor(0.14, 0.18, 0.23, 0.55)
			row:SetBackdropBorderColor(1, 1, 1, 0.08)
		else
			row:SetBackdropColor(0, 0, 0, 0)
			row:SetBackdropBorderColor(1, 1, 1, 0.05)
		end
	end

	local function ensureRow(index)
		local row = frame.rows[index]
		if row then return row end
		row = CreateFrame("Button", nil, content, "BackdropTemplate")
		row:SetHeight(25)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * 27)
		row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * 27)
		if row.SetBackdrop then
			row:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
		end
		row.label = MakeText(row, "GameFontHighlight", 12, "")
		row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
		row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		row:SetScript("OnEnter", function(btn) styleRow(btn, btn.selected, true) end)
		row:SetScript("OnLeave", function(btn) styleRow(btn, btn.selected, false) end)
		row:SetScript("OnClick", function(btn)
			local key = btn.key
			local callback = frame.onSelect
			frame:Hide()
			if key ~= nil and callback then callback(key) end
		end)
		frame.rows[index] = row
		return row
	end

	local function refresh()
		local text = string.lower(strtrim(search:GetText() or ""))
		local shown = 0
		for _, key in ipairs(frame.keys or {}) do
			local label = ValueLabel(frame.sources, key)
			local haystack = string.lower(label) .. " " .. string.lower(tostring(key))
			if text == "" or string.find(haystack, text, 1, true) then
				shown = shown + 1
				local row = ensureRow(shown)
				row.key = key
				row.selected = key == frame.current
				row.label:SetText(label)
				row:Show()
				styleRow(row, row.selected, false)
			end
		end
		for i = shown + 1, #frame.rows do frame.rows[i]:Hide() end
		content:SetWidth(math.max(120, (scroll:GetWidth() or 320) - 22))
		content:SetHeight(math.max(1, shown * 27 + 2))
		scroll:SetVerticalScroll(0)
	end
	frame.refresh = refresh
	search:SetScript("OnTextChanged", refresh)
	search:SetScript("OnEscapePressed", function() frame:Hide() end)
	frame:SetScript("OnShow", function()
		search:SetFocus()
		refresh()
	end)
	tinsert(_G.UISpecialFrames, "SkadaMediaPicker")
	mediaPicker = frame
	return frame
end

local function OpenMediaPicker(owner, title, keys, sources, current, onSelect)
	local frame = GetMediaPicker()
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
	frame:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
	frame:SetHeight(420)
	frame.title:SetText(title or "")
	frame.keys = keys
	frame.sources = sources
	frame.current = current
	frame.onSelect = onSelect
	frame.search:SetText("")
	frame:Show()
	frame.refresh()
end

local function CreateMediaPickerButton(row, option, sources, keys, current, ctx, path, disabled)
	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(220, 26)
	button:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	button:SetText(ValueLabel(sources, current))
	button:SetScript("OnClick", function(btn)
		OpenMediaPicker(btn, OptionName(option), keys, sources, current, function(key)
			CallSet(option, ctx, path, key)
			Refresh()
		end)
	end)
	if disabled then button:Disable() else button:Enable() end
	return button
end

local function CreateDropdown(row, option, ctx, path)
	local sources = ResolveValues(option, path)
	local current = CallGet(option, ctx, path)
	local disabled = IsDisabled(option, ctx, path)
	local keys = SortedValueKeys(sources)
	if type(option.dialogControl) == "string" and option.dialogControl:sub(1, 6) == "LSM30_" then
		return CreateMediaPickerButton(row, option, sources, keys, current, ctx, path, disabled)
	end

	local dropdown
	if _G.CreateFrame and UI.dropdownTemplate then
		dropdown = CreateFrame("DropdownButton", nil, row, UI.dropdownTemplate)
	end
	if not dropdown then
		dropdown = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		dropdown.SetDefaultText = function(self, text) self:SetText(text) end
		dropdown.SetupMenu = function(self, fn)
			self:SetScript("OnClick", function(btn)
				if MenuUtil and MenuUtil.CreateContextMenu then
					MenuUtil.CreateContextMenu(btn, function(_, root)
						fn(btn, root)
					end)
				end
			end)
		end
	end
	dropdown:SetSize(220, 26)
	dropdown:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	dropdown:SetDefaultText(ValueLabel(sources, current))
	dropdown:SetupMenu(function(_, root)
		root:CreateTitle(OptionName(option))
		for _, key in ipairs(keys) do
			local label = ValueLabel(sources, key)
			root:CreateRadio(label, function() return key == current end, function()
				CallSet(option, ctx, path, key)
				Refresh()
			end)
		end
	end)
	if disabled then dropdown:Disable() else dropdown:Enable() end
	return dropdown
end

local function CreateInput(row, option, ctx, path)
	local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	box:SetSize(220, 26)
	box:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	box:SetAutoFocus(false)
	box:SetMaxLetters(64)
	box:SetText(tostring(CallGet(option, ctx, path) or ""))
	local disabled = IsDisabled(option, ctx, path)
	if disabled then box:Disable() else box:Enable() end
	if not disabled then
		box:SetScript("OnEnterPressed", function(self)
			CallSet(option, ctx, path, self:GetText())
			self:ClearFocus()
			Refresh()
		end)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	end
	return box
end

local function CreateExecute(row, option, ctx, path)
	local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	button:SetSize(190, 24)
	button:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	button:SetText(OptionName(option))
	local disabled = IsDisabled(option, ctx, path)
	if disabled then button:Disable() else button:Enable() end
	if not disabled then
		button:SetScript("OnClick", function()
			local func = option.func
			if type(func) ~= "function" then return end
			local confirm = option.confirm
			local question
			if type(confirm) == "function" then
				question = SafeCall(confirm, path)
			elseif type(confirm) == "string" then
				question = confirm
			end
			if question and question ~= "" then
				ShowConfirm(question, function() pcall(func, path); Refresh() end)
			else
				pcall(func, path)
				Refresh()
			end
		end)
	end
	return button
end

local function CreateColor(row, option, ctx, path)
	local r, g, b, a = CallGet(option, ctx, path)
	r, g, b, a = tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(54, 22)
	swatch:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	local tex = swatch:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	tex:SetColorTexture(r, g, b, a)
	swatch.tex = tex
	swatch:SetScript("OnClick", function()
		local picker = _G.ColorPickerFrame
		local function apply()
			local nr, ng, nb = picker:GetColorRGB()
			local na = a
			if option.hasAlpha and picker.GetColorAlpha then
				na = picker:GetColorAlpha() or a
			end
			CallSet(option, ctx, path, nr, ng, nb, na)
			tex:SetColorTexture(nr, ng, nb, na)
		end
		if picker and picker.SetupColorPickerAndShow then
			picker:SetupColorPickerAndShow({
				r = r, g = g, b = b, opacity = a,
				hasAlpha = option.hasAlpha,
				swatchFunc = apply,
				opacityFunc = apply,
				cancelFunc = function() end,
			})
		elseif picker then
			picker.func = apply
			picker.opacityFunc = apply
			picker.hasAlpha = option.hasAlpha
			picker:SetColorRGB(r, g, b)
			picker:Show()
		end
	end)
	return swatch
end

local function CreateControl(page, key, option, ctx)
	local path = {}
	for i = 1, #ctx.path do path[i] = ctx.path[i] end
	path[#path + 1] = key

	local label = OptionName(option)
	local desc = OptionDesc(option)
	local controlWidths = {
		toggle = 30,
		range = 250,
		select = 220,
		input = 220,
		execute = 190,
		color = 80,
	}
	local controlWidth = controlWidths[option.type] or 220
	local rowWidth = page:GetWidth()
	if not rowWidth or rowWidth < 350 then rowWidth = 540 end
	local labelWidth = math.min(300, math.max(180, rowWidth - controlWidth - 40))
	local height = desc ~= "" and 58 or 46
	local row = CreateRow(page, height)
	local fs = MakeText(row, "GameFontHighlight", 12, label)
	fs:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -9)
	fs:SetWidth(labelWidth)
	local descBox
	if desc ~= "" then
		descBox = MakeText(row, "GameFontNormalSmall", 10, desc, MUTED)
		descBox:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
		descBox:SetWidth(labelWidth)
	end
	AttachTooltip(row, desc)

	local needed = 10 + (fs:GetStringHeight() or 14) + 10
	if descBox then needed = needed + (descBox:GetStringHeight() or 12) + 12 end
	needed = math.max(42, needed)
	local oldHeight = row:GetHeight()
	if needed > oldHeight then
		row:SetHeight(needed)
		page._y = (page._y or 0) - oldHeight + needed
	end

	local control
	if option.type == "toggle" then
		control = CreateCheckbox(row, option, ctx, path)
	elseif option.type == "range" then
		control = CreateSlider(row, option, ctx, path)
	elseif option.type == "select" then
		control = CreateDropdown(row, option, ctx, path)
	elseif option.type == "input" then
		control = CreateInput(row, option, ctx, path)
	elseif option.type == "execute" then
		control = CreateExecute(row, option, ctx, path)
	elseif option.type == "color" then
		control = CreateColor(row, option, ctx, path)
	end
	if control then row.control = control end
	return row
end

local function RenderArgs(page, args, ctx)
	if type(args) ~= "table" then return end
	local sorted = {}
	for key, option in pairs(args) do
		if type(option) == "table" and type(option.type) == "string" then
			sorted[#sorted + 1] = { key = key, option = option, order = tonumber(option.order) or 100 }
		end
	end
	table.sort(sorted, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return tostring(a.key) < tostring(b.key)
	end)

	for _, entry in ipairs(sorted) do
		local key, option = entry.key, entry.option
		if option.type == "group" then
			local groupCtx = {
				path = ctx.path,
				get = option.get or ctx.get,
				set = option.set or ctx.set,
				disabled = option.disabled or ctx.disabled,
			}
			if not option.inline and option.name then
				AddSection(page, OptionName(option), OptionDesc(option))
			elseif option.name and option.inline then
				AddHeader(page, OptionName(option))
			end
			if type(option.args) == "table" then
				RenderArgs(page, option.args, groupCtx)
			end
		elseif option.type == "description" then
			AddDescription(page, OptionName(option))
		elseif option.type == "header" then
			AddHeader(page, OptionName(option))
		else
			CreateControl(page, key, option, ctx)
		end
	end
end

local function AddSpacer(page, height)
	local f = CreateFrame("Frame", nil, page)
	f:SetHeight(height or 12)
	f:SetPoint("LEFT", page, "LEFT", 0, 0)
	f:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	Place(page, f)
	return f
end

local function AddFlatButton(page, text, callback, width)
	local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	button:SetSize(width or 170, 24)
	button:SetText(text)
	button:SetScript("OnClick", callback)
	return button
end

local function AddProfilePage(page)
	local db = Skada.db
	local current = db:GetCurrentProfile()
	AddSection(page, L["Profiles"], L["Profiles allow separate settings for different characters or specs."])

	local currentRow = CreateRow(page, 42)
	local currentText = MakeText(currentRow, "GameFontHighlight", 12, (L["Current profile"] or "Current profile") .. ": " .. tostring(current))
	currentText:SetPoint("LEFT", currentRow, "LEFT", 10, 0)

	local profiles = db:GetProfiles()
	table.sort(profiles)
	local selectorRow = CreateRow(page, 46)
	local selectorLabel = MakeText(selectorRow, "GameFontHighlight", 12, L["Switch profile"] or "Switch profile")
	selectorLabel:SetPoint("LEFT", selectorRow, "LEFT", 10, 0)
	local dropdown = CreateFrame("DropdownButton", nil, selectorRow, UI.dropdownTemplate or "UIPanelButtonTemplate")
	if UI.dropdownTemplate then
		dropdown:SetSize(200, 26)
		dropdown:SetPoint("RIGHT", selectorRow, "RIGHT", -8, 0)
		dropdown:SetDefaultText(current)
		dropdown:SetupMenu(function(_, root)
			root:CreateTitle(L["Profiles"])
			for _, name in ipairs(profiles) do
				root:CreateRadio(name, function() return name == current end, function()
					if name ~= current then
						db:SetProfile(name)
						Refresh()
					end
				end)
			end
		end)
	else
		dropdown:SetSize(200, 24)
		dropdown:SetPoint("RIGHT", selectorRow, "RIGHT", -8, 0)
		dropdown:SetText(current)
		dropdown:SetScript("OnClick", function(self)
			MenuUtil.CreateContextMenu(self, function(_, root)
				root:CreateTitle(L["Profiles"])
				for _, name in ipairs(profiles) do
					root:CreateRadio(name, function() return name == current end, function()
						if name ~= current then db:SetProfile(name); Refresh() end
					end)
				end
			end)
		end)
	end

	local newRow = CreateRow(page, 46)
	local newLabel = MakeText(newRow, "GameFontHighlight", 12, L["New profile"] or "New profile")
	newLabel:SetPoint("LEFT", newRow, "LEFT", 10, 0)
	local newBox = CreateFrame("EditBox", nil, newRow, "InputBoxTemplate")
	newBox:SetSize(200, 26)
	newBox:SetPoint("RIGHT", newRow, "RIGHT", -8, 0)
	newBox:SetAutoFocus(false)
	newBox:SetMaxLetters(32)
	newBox:SetScript("OnEnterPressed", function(self)
		local name = strtrim(self:GetText())
		if name ~= "" and name ~= current then
			db:SetProfile(name)
			self:SetText("")
			self:ClearFocus()
			Refresh()
		end
	end)

	local buttonRow = CreateFrame("Frame", nil, page)
	buttonRow:SetHeight(32)
	buttonRow:SetPoint("LEFT", page, "LEFT", 0, 0)
	buttonRow:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	Place(page, buttonRow)
	local copy = AddFlatButton(buttonRow, L["Copy current"] or "Copy current", function()
		local name = strtrim(newBox:GetText())
		if name == "" or name == current then return end
		local old = current
		db:SetProfile(name)
		db:CopyProfile(old)
		newBox:SetText("")
		Refresh()
	end, 150)
	copy:SetPoint("LEFT", buttonRow, "LEFT", 10, 0)
	local delete = AddFlatButton(buttonRow, L["Delete profile"] or "Delete profile", function()
		local name = strtrim(newBox:GetText())
		if name == "" or name == current then return end
		if db.profiles[name] then
			ShowConfirm((L["Delete profile"] or "Delete profile") .. " " .. name .. "?", function()
				db:DeleteProfile(name)
				Refresh()
			end)
		end
	end, 150)
	delete:SetPoint("LEFT", copy, "RIGHT", 8, 0)
	local reset = AddFlatButton(buttonRow, L["Reset profile"] or "Reset profile", function()
		ShowConfirm(L["Reset the current profile?"] or "Reset the current profile?", function()
			db:ResetProfile()
			Refresh()
		end)
	end, 150)
	reset:SetPoint("LEFT", delete, "RIGHT", 8, 0)
end

local function AddVersionPage(page)
	AddSection(page, L["Version History"], L["View the version history of Skada."])
	local button = AddFlatButton(page, L["Show Version History"], function() Skada:ShowVersionHistory() end, 200)
	button:SetPoint("LEFT", page, "LEFT", 10, 0)
	Place(page, button)
	local apiButton = AddFlatButton(page, "/skada api diagnostics", function()
		Skada:DumpAPIDiagnostics()
	end, 200)
	apiButton:SetPoint("LEFT", button, "RIGHT", 8, 0)
end

function UI:BuildPage()
	if not self.content then return end
	if self.section == "windows" then
		self:BuildNav()
	else
		self:UpdateNav()
	end
	if self.page then
		self.page:Hide()
		self.page:SetParent(nil)
		self.page = nil
	end
	self.content:SetWidth(math.max(400, self.scroll:GetWidth() - 24))
	local page = CreateFrame("Frame", nil, self.content)
	page:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
	page:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
	page:SetHeight(1)
	page._y = 0
	self.page = page

	local section = self.section or "generaloptions"
	local args = Skada.options and Skada.options.args
	if not args then return end

	if section == "windowsoverview" then
		self:BuildWindowsOverview(page)
	elseif section == "windows" then
		self:BuildWindowsPage(page)
	elseif section == "profiles" then
		AddProfilePage(page)
	elseif section == "version_history" then
		AddVersionPage(page)
	else
		local group = args[section]
		if group and type(group.args) == "table" then
			RenderArgs(page, group.args, { path = {} })
		else
			AddDescription(page, L["No settings available."])
		end
	end
	page:SetHeight(math.max(1, page._y or 0))
	self.content:SetHeight(math.max(page:GetHeight(), self.scroll:GetHeight()))
end

local function AddWindowPresets(page, winObj)
	local presetRow = CreateFrame("Frame", nil, page)
	presetRow:SetHeight(34)
	presetRow:SetPoint("LEFT", page, "LEFT", 0, 0)
	presetRow:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	Place(page, presetRow)
	local presets = {
		{ label = L["Compact"] or "Compact", width = 320, height = 18, background = 180, spacing = 1, headers = true, ranks = false },
		{ label = L["Standard"] or "Standard", width = 470, height = 22, background = 300, spacing = 1, headers = true, ranks = true },
		{ label = L["Detailed"] or "Detailed", width = 620, height = 26, background = 380, spacing = 2, headers = true, ranks = true },
	}
	local last
	for _, preset in ipairs(presets) do
		local presetData = preset
		local button = AddFlatButton(presetRow, presetData.label, function()
			local db = winObj.db
			db.barwidth = presetData.width
			db.barheight = presetData.height
			db.barspacing = presetData.spacing
			db.background.height = presetData.background
			db.showcolumnheaders = presetData.headers
			db.showranks = presetData.ranks
			Skada:ApplySettings()
			UI:BuildPage()
		end, 120)
		if last then
			button:SetPoint("LEFT", last, "RIGHT", 8, 0)
		else
			button:SetPoint("LEFT", presetRow, "LEFT", 10, 0)
		end
		last = button
	end
end

function UI:BuildWindowsOverview(page)
	AddSection(page, L["Windows"], L["Windows are independent damage meter displays."])
	AddDescription(page, L["Create a window with one of the display types below."])
	AddSection(page, L["Create window"])
	for key, display in pairs(Skada.displays or {}) do
		local row = CreateRow(page, 52)
		local name = display.name or key
		local fs = MakeText(row, "GameFontHighlight", 12, name)
		fs:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -9)
		local desc = MakeText(row, "GameFontNormalSmall", 10, display.description or "", MUTED)
		desc:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
		desc:SetWidth(300)
		local create = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		create:SetSize(110, 24)
		create:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		create:SetText(_G.CREATE or "Create")
		create:SetScript("OnClick", function()
			Skada:PromptNewWindow(key)
		end)
	end
end

function UI:BuildWindowsPage(page)
	local windowsArgs = Skada.options.args.windows and Skada.options.args.windows.args or {}
	local windows = Skada:GetWindows()
	local byName = {}
	for _, win in ipairs(windows) do byName[win.db.name] = win end
	local names = {}
	for name in pairs(byName) do names[#names + 1] = name end
	table.sort(names)

	local selected = self.selectedWindow
	if not selected or not byName[selected] then
		selected = names[1]
		self.selectedWindow = selected
	end
	if not selected then
		AddSection(page, L["Windows"], L["Windows are independent damage meter displays."])
		AddDescription(page, L["No windows."] or "No windows.")
	else
		AddSection(page, selected, L["Windows are independent damage meter displays."])
		AddWindowPresets(page, byName[selected])
		local args = windowsArgs[selected]
		if args and type(args.args) == "table" then
			RenderArgs(page, args.args, { path = {} })
		else
			AddDescription(page, L["No settings available."])
		end
	end


end

function UI:SetSection(section)
	self.section = section
	if section == "windows" then
		local windows = Skada:GetWindows()
		local selected = self.selectedWindow
		local valid = false
		for _, win in ipairs(windows) do
			if win.db.name == selected then valid = true; break end
		end
		if not valid then self.selectedWindow = windows[1] and windows[1].db.name or nil end
	end
	self:BuildPage()
end

local navOrder = {
	{ key = "windows", label = L["Windows"] },
	{ key = "generaloptions", label = L["General options"] },
	{ key = "resetoptions", label = L["Data resets"] },
	{ key = "tooltips", label = L["Tooltips"] },
	{ key = "columns", label = L["Columns"] },
	{ key = "modules", label = L["Disabled Modules"] },
	{ key = "profiles", label = L["Profiles"] },
	{ key = "version_history", label = L["Version History"] },
}

function UI:UpdateNav()
	for key, button in pairs(self.navButtons or {}) do
		local active = key == self.section or (key == "windows" and self.section == "windowsoverview")
		if active then
			button:SetBackdropColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
			button.label:SetTextColor(1, 1, 1, 1)
		else
			button:SetBackdropColor(0, 0, 0, 0)
			button.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3], 1)
		end
	end
	for name, button in pairs(self.navWindows or {}) do
		local active = self.section == "windows" and self.selectedWindow == name
		if active then
			button:SetBackdropColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.30)
			button.label:SetTextColor(1, 1, 1, 1)
		else
			button:SetBackdropColor(0, 0, 0, 0)
			button.label:SetTextColor(MUTED[1], MUTED[2], MUTED[3], 1)
		end
	end
end

function UI:BuildNav()
	if not self.sidebar then return end
	for _, button in pairs(self.navButtons or {}) do button:Hide(); button:SetParent(nil) end
	for _, button in pairs(self.navWindows or {}) do button:Hide(); button:SetParent(nil) end
	self.navButtons = {}
	self.navWindows = {}

	local windows = Skada:GetWindows()
	local names = {}
	for _, win in ipairs(windows) do names[#names + 1] = win.db.name end
	table.sort(names)
	if self.section == "windows" then
		local valid = false
		for _, name in ipairs(names) do
			if name == self.selectedWindow then valid = true; break end
		end
		if not valid then self.selectedWindow = names[1] end
	end

	local last
	local function place(button, indent)
		button:SetPoint("LEFT", self.sidebar, "LEFT", indent or 0, 0)
		button:SetPoint("RIGHT", self.sidebar, "RIGHT", 0, 0)
		if last then
			button:SetPoint("TOP", last, "BOTTOM", 0, -2)
		else
			button:SetPoint("TOP", self.sidebar, "TOP", 0, 0)
		end
		last = button
	end

	for _, entry in ipairs(navOrder) do
		local button = CreateFrame("Button", nil, self.sidebar, "BackdropTemplate")
		button:SetHeight(30)
		AddBackdrop(button, 0.35)
		button:SetBackdropColor(0, 0, 0, 0)
		local label = MakeText(button, "GameFontNormal", 12, entry.label, MUTED)
		label:SetPoint("LEFT", button, "LEFT", 12, 0)
		button.label = label
		button:SetScript("OnClick", function()
			if entry.key == "windows" then
				UI:SetSection("windowsoverview")
			else
				UI:SetSection(entry.key)
			end
		end)
		local function isParentActive()
			return UI.section == entry.key or (entry.key == "windows" and UI.section == "windowsoverview")
		end
		button:SetScript("OnEnter", function(btn)
			if not isParentActive() then btn:SetBackdropColor(1, 1, 1, 0.05) end
		end)
		button:SetScript("OnLeave", function(btn)
			if not isParentActive() then btn:SetBackdropColor(0, 0, 0, 0) end
		end)
		self.navButtons[entry.key] = button
		place(button, 0)
		if entry.key == "windows" then
			for _, name in ipairs(names) do
				local child = CreateFrame("Button", nil, self.sidebar, "BackdropTemplate")
				child:SetHeight(24)
				AddBackdrop(child, 0.2)
				child:SetBackdropColor(0, 0, 0, 0)
				local childLabel = MakeText(child, "GameFontNormal", 11, name, MUTED)
				childLabel:SetPoint("LEFT", child, "LEFT", 12, 0)
				childLabel:SetPoint("RIGHT", child, "RIGHT", -6, 0)
				child.label = childLabel
				child:SetScript("OnClick", function() UI:SelectWindow(name) end)
				child:SetScript("OnEnter", function(btn)
					if not (UI.section == "windows" and UI.selectedWindow == name) then
						btn:SetBackdropColor(1, 1, 1, 0.05)
					end
				end)
				child:SetScript("OnLeave", function(btn)
					if not (UI.section == "windows" and UI.selectedWindow == name) then
						btn:SetBackdropColor(0, 0, 0, 0)
					end
				end)
				self.navWindows[name] = child
				place(child, 22)
			end
		end
	end
	self:UpdateNav()
end

function UI:SelectWindow(name)
	self.section = "windows"
	self.selectedWindow = name
	self:BuildPage()
end

function UI:Create(frame)
	self.frame = frame
	frame:SetSize(820, 620)

	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(62)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -8)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -8)
	local title = MakeText(header, "GameFontNormalHuge", 22, "Skada", { 1, 1, 1, 1 })
	title:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -4)
	local subtitle = MakeText(header, "GameFontNormalSmall", 11, L["A damage meter."], MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	close:SetScript("OnClick", function() frame:Hide() end)
	close:Hide()
	self.closeButton = close
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(0.018, 0.026, 0.038, 0.97)
		frame:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.35)
	end

	local sidebar = CreateFrame("Frame", nil, frame)
	sidebar:SetWidth(190)
	sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)
	sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
	self.sidebar = sidebar
	self.navButtons = {}

	self:BuildNav()


	local scroll = CreateFrame("ScrollFrame", "SkadaSettingsScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 18, 0)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 18)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(560)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	self.scroll = scroll
	self.content = content

	-- Lay children out from the top after every rebuild.
	self.layout = CreateFrame("Frame", nil, content)
	self.layout:SetAllPoints(content)
	self.layout:SetScript("OnShow", function() end)

	frame:SetScript("OnShow", function()
		self:BuildPage()
	end)
	self:SetSection("windowsoverview")
end

function Skada:ShowStandaloneSettings()
	local frame = self.settingsCanvas
	if not frame then return end
	frame:SetParent(UIParent)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	if UI and UI.closeButton then UI.closeButton:Show() end
	frame:Show()
end

function Skada:SetupSettingsCategory()
	if self.settingsCategory then return end
	if not SettingsAPI or not SettingsAPI.RegisterCanvasLayoutCategory then return end
	if not self.settingsCanvas then
		local frame = CreateFrame("Frame", "SkadaSettingsCanvas", UIParent, "BackdropTemplate")
		self.settingsCanvas = frame
		UI.dropdownTemplate = nil
		local ok, test = pcall(CreateFrame, "DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
		if ok and test then
			UI.dropdownTemplate = "WowStyle1DropdownTemplate"
			test:Hide()
			test:SetParent(nil)
		end
		UI:Create(frame)
		self.settingsUI = UI
		self.dropdownTemplate = UI.dropdownTemplate
	end
	local category = SettingsAPI.RegisterCanvasLayoutCategory(self.settingsCanvas, "Skada")
	SettingsAPI.RegisterAddOnCategory(category)
	self.settingsCategory = category
end

function Skada:OpenOptions(window)
	self:SetupSettingsCategory()
	if window and UI then
		UI.selectedWindow = window.db.name
		UI:SetSection("windows")
	end
	if self.settingsCategory and SettingsAPI and SettingsAPI.OpenToCategory then
		local ok = pcall(SettingsAPI.OpenToCategory, self.settingsCategory:GetID())
		if UI then
			UI:BuildPage()
			if UI.closeButton then
				if (_G.SettingsPanel and _G.SettingsPanel:IsShown()) then
					UI.closeButton:Hide()
				else
					UI.closeButton:Show()
				end
			end
		end
		if not ok and not (_G.SettingsPanel and _G.SettingsPanel:IsShown()) then
			-- Older Settings panels can fail before painting the canvas; fall
			-- back to a standalone frame only if the panel did not open.
			self:ShowStandaloneSettings()
		end
	else
		self:ShowStandaloneSettings()
	end
end
