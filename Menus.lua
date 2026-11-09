local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

local MenuUtil = _G.MenuUtil
local ACCENT = { 0.36, 0.62, 0.83 }

local function CreateContext(owner, generator)
	if not MenuUtil or not MenuUtil.CreateContextMenu then return end
	return MenuUtil.CreateContextMenu(owner or UIParent, generator)
end

local function AddModeEntries(root, window)
	root:CreateTitle(L["Mode"])
	local modes = Skada:GetModes()
	for i = 1, #modes do
		local module = modes[i]
		root:CreateRadio(module:GetName(), function()
			return window.selectedmode == module
		end, function()
			window:DisplayMode(module)
		end)
	end
end

local function AddSetEntries(root, window)
	root:CreateTitle(L["Segment"])
	root:CreateRadio(L["Total"], function() return window.selectedset == "total" end, function()
		window.selectedset = "total"
		Skada:Wipe()
		Skada:UpdateDisplay(true)
	end)
	root:CreateRadio(L["Current"], function() return window.selectedset == "current" end, function()
		window.selectedset = "current"
		Skada:Wipe()
		Skada:UpdateDisplay(true)
	end)
	for i, set in ipairs(Skada:GetSets()) do
		local id = set.sessionID or set.startTime or set.starttime or i
		root:CreateRadio(Skada:GetSetLabel(set), function() return window.selectedset == id end, function()
			window.selectedset = id
			Skada:Wipe()
			Skada:UpdateDisplay(true)
		end)
	end
end

local function AddWindowEntries(root, window)
	root:CreateTitle(window.db.name)
	AddModeEntries(root, window)
	root:CreateDivider()
	AddSetEntries(root, window)
	root:CreateDivider()
	root:CreateCheckbox(L["Lock window"], function() return window.db.barslocked end, function()
		window.db.barslocked = not window.db.barslocked
		Skada:ApplySettings()
	end)
	root:CreateButton(L["Duplicate window"], function()
		Skada:DuplicateWindow(window.db.name)
	end)
	root:CreateButton(L["Hide window"], function()
		if window:IsShown() then
			window.db.hidden = true
			window:Hide()
		else
			window.db.hidden = false
			window:Show()
		end
	end)
end

function Skada:ReportMenu(window)
	CreateContext(UIParent, function(_, root)
		root:CreateTitle(L["Report"])
		for _, choice in ipairs(Skada:GetChatChannelChoices()) do
			root:CreateButton(choice.label, function()
				Skada:ReportToChat(window, choice.key)
			end)
		end
	end)
end

function Skada:OpenMenu(window)
	local windows = Skada:GetWindows()
	CreateContext(UIParent, function(_, root)
		root:CreateTitle(L["Skada Menu"])
		for i = 1, #windows do
			local win = windows[i]
			root:CreateButton(win.db.name, function()
				CreateContext(UIParent, function(_, sub)
					AddWindowEntries(sub, win)
				end)
			end)
		end
		root:CreateButton(L["New window"], function()
			Skada:PromptNewWindow("bar")
		end)
		root:CreateDivider()
		if not window or (window and window.selectedmode) then
			root:CreateButton(L["Report"], function()
				Skada:ReportMenu(window)
			end)
		end
		root:CreateButton(L["Combat summary"], function()
			local win = window or Skada:GetWindows()[1]
			Skada:ShowCombatSummary(win and win:get_selected_set())
		end)
		root:CreateButton(L["Toggle window"], function() Skada:ToggleWindow() end)
		root:CreateButton(L["Reset"], function() Skada:Reset() end)
		root:CreateButton(L["Configure"], function() Skada:OpenOptions(window) end)
		root:CreateDivider()
		root:CreateCheckbox(L["Simulation Mode"], function()
			return Skada.Simulation and Skada.Simulation.active
		end, function()
			if Skada.Simulation then
				Skada.Simulation:SetEnabled(not Skada.Simulation.active)
			end
		end)
	end)
end

function Skada:SegmentMenu(window)
	CreateContext(UIParent, function(_, root)
		AddSetEntries(root, window)
	end)
end

function Skada:ModeMenu(window)
	CreateContext(UIParent, function(_, root)
		AddModeEntries(root, window)
	end)
end

-- Report window -------------------------------------------------------------

local function destroyReportWindow()
	local frame = Skada.ReportWindow
	if frame then
		frame:Hide()
		frame:SetParent(nil)
		Skada.ReportWindow = nil
	end
end

local function reportChannels()
	local channellist = {
		whisper = { L["Whisper"], "whisper", true },
		target = { L["Whisper Target"], "whisper" },
		say = { L["Say"], "preset" },
		raid = { L["Raid"], "preset" },
		party = { L["Party"], "preset" },
		instance_chat = { L["Instance"], "preset" },
		guild = { L["Guild"], "preset" },
		officer = { L["Officer"], "preset" },
		self = { L["Self"], "self" },
		bnet = { BATTLENET_OPTIONS_LABEL, "bnet", true },
	}
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local chan = list[i + 1]
		if chan ~= "Trade" and chan ~= "General" and chan ~= "LocalDefense" and chan ~= "LookingForGroup" then
			channellist[chan] = { ("%s: %d/%s"):format(L["Channel"], list[i], chan), "channel" }
		end
	end
	return channellist
end

local function MakeLabel(parent, text, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetFont(fs:GetFont(), size or 12)
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
	return fs
end

local function AddDropdown(parent, width, defaultText, getValues, getSelected, setSelected)
	local template = Skada.dropdownTemplate
	if not template then return nil end
	local dropdown = CreateFrame("DropdownButton", nil, parent, template)
	dropdown:SetSize(width or 150, 26)
	dropdown:SetDefaultText(defaultText or "")
	dropdown:SetupMenu(function(_, root)
		local values = getValues()
		for _, entry in ipairs(values) do
			root:CreateRadio(entry.label, function() return getSelected() == entry.value end, function()
				setSelected(entry.value)
			end)
		end
	end)
	return dropdown
end

function Skada:CreateReportWindow(window)
	destroyReportWindow()
	if window then
		Skada.db.profile.report.set = window.selectedset
		Skada.db.profile.report.mode = window.db.mode
	end
	local frame = CreateFrame("Frame", "SkadaReportFrame", UIParent, "BackdropTemplate")
	frame:SetSize(330, window and 300 or 400)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
		frame:SetBackdropColor(0.025, 0.035, 0.05, 0.96)
		frame:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
	end
	self.ReportWindow = frame

	local title = MakeLabel(frame, L["Report"], 14, { 1, 1, 1, 1 })
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	close:SetScript("OnClick", destroyReportWindow)

	local y = -44
	local function place(row)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
		row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, y)
		y = y - (row:GetHeight() + 6)
	end

	if not window then
		local modeRow = CreateFrame("Frame", nil, frame)
		modeRow:SetHeight(36)
		place(modeRow)
		local modeLabel = MakeLabel(modeRow, L["Mode"], 12)
		modeLabel:SetPoint("LEFT", modeRow, "LEFT", 0, 0)
		local modes = {}
		for _, module in ipairs(Skada:GetModes()) do
			modes[#modes + 1] = { value = module:GetName(), label = module:GetName() }
		end
		local modeDrop = AddDropdown(modeRow, 160, Skada.db.profile.report.mode or "", function() return modes end,
			function() return Skada.db.profile.report.mode end,
			function(value) Skada.db.profile.report.mode = value end)
		if modeDrop then modeDrop:SetPoint("RIGHT", modeRow, "RIGHT", 0, 0) end

		local setRow = CreateFrame("Frame", nil, frame)
		setRow:SetHeight(36)
		place(setRow)
		local setLabel = MakeLabel(setRow, L["Segment"], 12)
		setLabel:SetPoint("LEFT", setRow, "LEFT", 0, 0)
		local sets = {
			{ value = "total", label = L["Total"] },
			{ value = "current", label = L["Current"] },
		}
		for i, set in ipairs(Skada:GetSets()) do
			local id = set.sessionID or set.startTime or set.starttime or i
			sets[#sets + 1] = { value = id, label = Skada:GetSetLabel(set) }
		end
		local setDrop = AddDropdown(setRow, 160, Skada.db.profile.report.set or "current", function() return sets end,
			function() return Skada.db.profile.report.set end,
			function(value) Skada.db.profile.report.set = value end)
		if setDrop then setDrop:SetPoint("RIGHT", setRow, "RIGHT", 0, 0) end
	end

	local channellist = reportChannels()
	local currentChannel = Skada.db.profile.report.channel or "say"
	if not channellist[currentChannel] then currentChannel = "say" end

	local channelRow = CreateFrame("Frame", nil, frame)
	channelRow:SetHeight(36)
	place(channelRow)
	local channelLabel = MakeLabel(channelRow, L["Channel"], 12)
	channelLabel:SetPoint("LEFT", channelRow, "LEFT", 0, 0)
	local channelEntries = {}
	for chan, kind in pairs(channellist) do
		channelEntries[#channelEntries + 1] = { value = chan, label = kind[1] }
	end
	table.sort(channelEntries, function(a, b) return a.label < b.label end)
	local channelDrop = AddDropdown(channelRow, 160, channellist[currentChannel][1], function() return channelEntries end,
		function() return currentChannel end,
		function(value)
			Skada.db.profile.report.channel = value
			Skada.db.profile.report.chantype = channellist[value][2]
			Skada:CreateReportWindow(window)
		end)
	if channelDrop then channelDrop:SetPoint("RIGHT", channelRow, "RIGHT", 0, 0) end

	local lineRow = CreateFrame("Frame", nil, frame)
	lineRow:SetHeight(36)
	place(lineRow)
	local lineLabel = MakeLabel(lineRow, L["Lines"], 12)
	lineLabel:SetPoint("LEFT", lineRow, "LEFT", 0, 0)
	local slider = CreateFrame("Slider", "SkadaReportLines", lineRow, "OptionsSliderTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetPoint("RIGHT", lineRow, "RIGHT", -8, 0)
	slider:SetWidth(180)
	slider:SetMinMaxValues(1, 25)
	slider:SetValueStep(1)
	slider:SetValue(Skada.db.profile.report.number or 10)
	slider:SetScript("OnValueChanged", function(_, value)
		Skada.db.profile.report.number = math.floor(value + 0.5)
	end)
	if _G["SkadaReportLinesLow"] then _G["SkadaReportLinesLow"]:SetText("") end
	if _G["SkadaReportLinesHigh"] then _G["SkadaReportLinesHigh"]:SetText("") end

	local needsTarget = channellist[currentChannel][3]
	if needsTarget then
		local targetRow = CreateFrame("Frame", nil, frame)
		targetRow:SetHeight(36)
		place(targetRow)
		local targetLabel = MakeLabel(targetRow, L["Whisper Target"], 12)
		targetLabel:SetPoint("LEFT", targetRow, "LEFT", 0, 0)
		local box = CreateFrame("EditBox", nil, targetRow, "InputBoxTemplate")
		box:SetSize(160, 26)
		box:SetPoint("RIGHT", targetRow, "RIGHT", 0, 0)
		box:SetAutoFocus(false)
		box:SetText(Skada.db.profile.report.target or "")
		box:SetScript("OnTextChanged", function(self)
			Skada.db.profile.report.target = self:GetText()
		end)
	end

	frame:SetHeight(math.max(190, -y + 58))

	local reportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	reportButton:SetSize(150, 28)
	reportButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
	reportButton:SetText(L["Report"])
	reportButton:SetScript("OnClick", function()
		local mode = Skada.db.profile.report.mode
		local set = Skada.db.profile.report.set
		local channel = Skada.db.profile.report.channel
		local chantype = Skada.db.profile.report.chantype
		local number = Skada.db.profile.report.number
		if channel == "whisper" then
			channel = Skada.db.profile.report.target
			if channel and #strtrim(channel) == 0 then channel = nil end
		elseif channel == "bnet" then
			if BNet_GetBNetIDAccount then
				channel = BNet_GetBNetIDAccount(Skada.db.profile.report.target)
			else
				channel = Skada.db.profile.report.target
			end
		elseif channel == "target" then
			if UnitExists("target") then
				local toon, realm = UnitName("target")
				if realm and #realm > 0 then channel = toon .. "-" .. realm else channel = toon end
			else
				channel = nil
			end
		end
		if channel and chantype and mode and set and number then
			Skada:Report(channel, chantype, mode, set, number, window)
			destroyReportWindow()
		else
			Skada:Print("Error: Whisper target not found")
		end
	end)

	tinsert(_G.UISpecialFrames, "SkadaReportFrame")
end

function Skada:OpenReportWindow(window)
	destroyReportWindow()
	self:CreateReportWindow(window)
	if self.ReportWindow then self.ReportWindow:Show() end
end
