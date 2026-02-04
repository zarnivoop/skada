local _, addon = ...

local Skada = LibStub("AceAddon-3.0"):NewAddon(addon, "Skada", "AceTimer-3.0", "LibNotify-1.0")
_G.Skada = Skada

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

local acd = LibStub("AceConfigDialog-3.0")
local icon = LibStub("LibDBIcon-1.0", true)
local media = LibStub("LibSharedMedia-3.0")
local lds = LibStub("LibDualSpec-1.0", true)

local dataobj = LibStub("LibDataBroker-1.1"):NewDataObject("Skada", {
	label = "Skada",
	type = "data source",
	icon = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
	text = "n/a"
})

InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
if not InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory = function(frame, addOn, position)
		frame.OnCommit = frame.okay;
		frame.OnDefault = frame.default;
		frame.OnRefresh = frame.refresh;

		if frame.parent then
			local category = Settings.GetCategory(frame.parent);
			local subcategory, layout = Settings.RegisterCanvasLayoutSubcategory(category, frame, frame.name, frame.name);
			subcategory.ID = frame.name;

			return subcategory, category;
		else
			local category, layout = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name);
			category.ID = frame.name;
			Settings.RegisterAddOnCategory(category);
			return category;
		end
	end
end

-- Simple boss detection helpers removed - WoW 12.0+ uses native encounter detection
function Skada:GetSpellIcon(spellId)
	if not spellId or spellId == 0 then return nil end
	local info = C_Spell.GetSpellInfo(spellId)
	if info then
		return info.iconID
	end
	return nil
end

function Skada:GetGameVersion()
	local version = floor((floor(select(4, GetBuildInfo())) / 10000))

	return version
end

local popup

-- Aliases
local tsort, tinsert, tremove = table.sort, table.insert, table.remove
local next, pairs, ipairs, type = next, pairs, ipairs, type
-- bit.band no longer needed with Native API

-- Returns the group type (i.e., "party" or "raid") and the size of the group.
function Skada:GetGroupTypeAndCount()
	local groupType
	local count = GetNumGroupMembers()

	-- Modern API detection with Classic Era support
	if IsInRaid() then
		groupType = "raid"
	elseif IsInGroup() then -- Works in both Retail and Classic
		groupType = "party"
		-- Maintain Classic-era behavior where count includes player
		count = count > 0 and count - 1 or 0
	end

	return groupType, count
end

do
	popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate") -- Recycle the popup frame as an event handler.
	popup:SetScript("OnEvent", function(frame, event, ...)
		local handler = Skada[event]
		if handler then
			handler(Skada, ...)
		else
			-- Some events are registered for compatibility but don't have handlers with Native API
			Skada:Debug("Unhandled event:", event)
		end
	end)

	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 1, right = 1, top = 1, bottom = 1 }
	})
	popup:SetSize(250, 100)
	popup:SetPoint("CENTER", UIParent, "CENTER")
	popup:SetFrameStrata("DIALOG")
	popup:Hide()

	popup:EnableKeyboard(true)
	popup:SetScript("OnKeyDown", function(self, key)
		if GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
			popup:SetPropagateKeyboardInput(false) -- swallow escape
			popup:Hide()
		end
	end)

	local text = popup:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	text:SetPoint("TOP", popup, "TOP", 0, -15)
	text:SetText(L["Do you want to reset Skada?"])

	local accept = CreateFrame("Button", nil, popup)
	accept:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Check")
	accept:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	accept:SetSize(50, 50)
	accept:SetPoint("BOTTOM", popup, "BOTTOM", -50, 5)
	accept:SetScript("OnClick", function(f)
		Skada:Reset()
		f:GetParent():Hide()
	end)

	local close = CreateFrame("Button", nil, popup)
	close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	close:SetSize(50, 50)
	close:SetPoint("BOTTOM", popup, "BOTTOM", 50, 5)
	close:SetScript("OnClick", function(f) f:GetParent():Hide() end)
	function Skada:ShowPopup()
		popup:SetPropagateKeyboardInput(true)
		popup:Show()
	end
end

-- Keybindings
BINDING_HEADER_Skada = "Skada"
BINDING_NAME_SKADA_TOGGLE = L["Toggle window"]
BINDING_NAME_SKADA_RESET = L["Reset"]
BINDING_NAME_SKADA_NEWSEGMENT = L["Start new segment"]
BINDING_NAME_SKADA_STOP = L["Stop"]

-- The current set
Skada.current = nil

-- The total set
Skada.total = nil

-- The last set
Skada.last = nil

-- Modes - these are modules, really. Modeules?
local modes = {}

-- Pet tracking handled by Native API
-- No local pet/player tables needed

-- Flag marking if we need an update.
local changed = true

-- Flag for if we were in a party/raid.
local wasinparty = nil

-- By default we just use RAID_CLASS_COLORS as class colors.
Skada.classcolors = RAID_CLASS_COLORS

-- The selected data feed.
local selectedfeed = nil

-- A list of data feeds available. Modules add to it.
local feeds = {}

-- Disabled flag.
local disabled = false

-- Our windows.
local windows = {}

-- Our display providers.
Skada.displays = {}

-- Timer for updating windows.
local update_timer = nil

-- Timer for checking for combat end.
local tick_timer = nil

function Skada:GetWindows()
	return windows
end

local function find_mode(name)
	for i, mode in ipairs(modes) do
		if mode:GetName() == name then
			return mode
		end
	end
end

-- Our window type.
local Window = {}

local mt = { __index = Window }

function Window:new()
	return setmetatable({
		-- The selected mode and set
		selectedmode = nil,
		selectedset = nil,

		-- Mode and set to return to after combat.
		restore_mode = nil,
		restore_set = nil,

		usealt = true,

		-- Our dataset.
		dataset = {},

		-- Metadata about our dataset.
		metadata = {},

		-- Our display provider.
		display = nil,

		-- Our mode traversing history.
		history = {},

		-- Flag for window-specific changes.
		changed = false,

	}, mt)
end

function Window:AddOptions()
	local db = self.db

	local options = {
		type = "group",
		name = function() return db.name end,
		args = {

			rename = {
				type = "input",
				name = L["Rename window"],
				desc = L["Enter the name for the window."],
				get = function() return db.name end,
				set = function(win, val)
					if val ~= db.name and val ~= "" then
						local oldname = db.name
						db.name = val
						Skada.options.args.windows.args[val] = Skada.options.args.windows.args[oldname]
						Skada.options.args.windows.args[oldname] = nil
					end
				end,
				order = 1,
			},

			locked = {
				type = "toggle",
				name = L["Lock window"],
				desc = L["Locks the bar window in place."],
				order = 2,
				get = function() return db.barslocked end,
				set = function()
					db.barslocked = not db.barslocked
					Skada:ApplySettings()
				end,
			},

			delete = {
				type = "execute",
				name = L["Delete window"],
				desc = L["Deletes the chosen window."],
				order = 20,
				width = "full",
				confirm = function() return "Are you sure you want to delete this window?" end,
				func = function() Skada:DeleteWindow(db.name) end,
			},

		}
	}

	options.args.switchoptions = {
		type = "group",
		name = L["Mode switching"],
		order = 4,
		args = {

			modeincombat = {
				type = "select",
				name = L["Combat mode"],
				desc = L["Automatically switch to set 'Current' and this mode when entering combat."],
				values = function()
					local modes = {}
					modes[""] = L["None"]
					for i, mode in ipairs(Skada:GetModes()) do
						modes[mode:GetName()] = mode:GetName()
					end
					return modes
				end,
				get = function() return db.modeincombat end,
				set = function(win, mode) db.modeincombat = mode end,
				order = 21,
			},

			wipemode = {
				type = "select",
				name = L["Wipe mode"],
				desc = L["Automatically switch to set 'Current' and this mode after a wipe."],
				values = function()
					local modes = {}
					modes[""] = L["None"]
					for i, mode in ipairs(Skada:GetModes()) do
						modes[mode:GetName()] = mode:GetName()
					end
					return modes
				end,
				get = function() return db.wipemode end,
				set = function(win, mode) db.wipemode = mode end,
				order = 21,
			},
			returnaftercombat = {
				type = "toggle",
				name = L["Return after combat"],
				desc = L["Return to the previous set and mode after combat ends."],
				order = 23,
				get = function() return db.returnaftercombat end,
				set = function() db.returnaftercombat = not db.returnaftercombat end,
				disabled = function() return db.returnaftercombat == nil end,
			},
		}
	}

	self.display:AddDisplayOptions(self, options.args)

	Skada.options.args.windows.args[self.db.name] = options
end

-- Sets a slave window for this window. This window will also be updated on view updates.
function Window:SetChild(window)
	self.child = window
end

function Window:destroy()
	self.dataset = nil

	if self.display and self.display.Destroy then
		self.display:Destroy(self)
	end

	local name = self.db.name or Skada.windowdefaults.name
	Skada.options.args.windows.args[name] = nil -- remove from options
end

function Window:SetDisplay(name)
	-- Don't do anything if nothing actually changed.
	if name ~= self.db.display or self.display == nil then
		if self.display then
			-- Destroy old display.
			self.display:Destroy(self)
		end

		-- Set new display.
		self.db.display = name
		self.display = Skada.displays[self.db.display]

		-- Add options. Replaces old options.
		self:AddOptions()
	end
end

-- Tells window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
	-- Fetch max value if our mode has not done this itself.
	if not self.metadata.maxvalue then
		self.metadata.maxvalue = 0
		for i, data in ipairs(self.dataset) do
			if data.id and data.value > self.metadata.maxvalue then
				self.metadata.maxvalue = data.value
			end
		end
	end

	-- Display it.
	if self.display and self.display.Update then
		self.display:Update(self)
	end
	self:set_mode_title()
end

-- Called before dataset is updated.
function Window:UpdateInProgress()
	for i, data in ipairs(self.dataset) do
		if data.ignore then -- ensure total bar icon is cleared before bar is recycled
			data.icon = nil
		end
		data.id = nil
		data.ignore = nil
	end
end

function Window:Show()
	self.display:Show(self)
end

function Window:Hide()
	self.display:Hide(self)
end

function Window:IsShown()
	return self.display:IsShown(self)
end

function Window:Reset()
	for i, data in ipairs(self.dataset) do
		wipe(data)
	end
end

function Window:Wipe()
	-- Clear dataset.
	self:Reset()

	-- Clear display.
	if self.display and self.display.Wipe then
		self.display:Wipe(self)
	end

	if self.child then
		self.child:Wipe()
	end
end

-- If selectedset is "current", returns current set if we are in combat, otherwise returns the last set.
function Window:get_selected_set()
	return Skada:find_set(self.selectedset)
end

-- Sets up the mode view.
function Window:DisplayMode(mode)
	self:Wipe()

	self.selectedplayer = nil
	self.selectedmode = mode

	self.metadata = wipe(self.metadata or {})

	-- Apply mode's metadata.
	if mode.metadata then
		for key, value in pairs(mode.metadata) do
			self.metadata[key] = value
		end
	end

	self.changed = true
	self:set_mode_title() -- in case data sets are empty

	if self.child then
		self.child:DisplayMode(mode)
	end

	Skada:UpdateDisplay(false)
end

local numsetfmts = 8
local function SetLabelFormat(name, starttime, endtime, fmt)
	fmt = fmt or Skada.db.profile.setformat
	local namelabel = name
	if fmt < 1 or fmt > numsetfmts then fmt = 3 end
	local timelabel = ""
	if starttime and endtime and fmt > 1 then
		local duration = SecondsToTime(endtime - starttime, false, false, 2)
		-- translate locale time abbreviations, whose escape sequences are not legal in chat
		Skada.getsetlabel_fs = Skada.getsetlabel_fs or UIParent:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		Skada.getsetlabel_fs:SetText(duration)
		duration = "(" .. Skada.getsetlabel_fs:GetText() .. ")"

		if fmt == 2 then
			timelabel = duration
		elseif fmt == 3 then
			timelabel = date("%H:%M", starttime) .. " " .. duration
		elseif fmt == 4 then
			timelabel = date("%I:%M", starttime) .. " " .. duration
		elseif fmt == 5 then
			timelabel = date("%H:%M", starttime) .. " - " .. date("%H:%M", endtime)
		elseif fmt == 6 then
			timelabel = date("%I:%M", starttime) .. " - " .. date("%I:%M", endtime)
		elseif fmt == 7 then
			timelabel = date("%H:%M:%S", starttime) .. " - " .. date("%H:%M:%S", endtime)
		elseif fmt == 8 then
			timelabel = date("%H:%M", starttime) .. " - " .. date("%H:%M", endtime) .. " " .. duration
		end
	end

	local comb
	if #namelabel == 0 or #timelabel == 0 then
		comb = namelabel .. timelabel
	elseif timelabel:match("^%p") then
		comb = namelabel .. " " .. timelabel
	else
		comb = namelabel .. ": " .. timelabel
	end
	-- provide both the combined label and the separated name/time labels
	return comb, namelabel, timelabel
end

function Skada:SetLabelFormats() -- for config option display
	local ret = {}
	local start = 1000007900
	for i = 1, numsetfmts do
		ret[i] = SetLabelFormat("Hogger", start, start + 380, i)
	end
	return ret
end

function Skada:GetSetLabel(set) -- return a nicely-formatted label for a set
	if not set then return "" end
	
	-- Handle Native API session fields (capital T)
	local startTime = set.startTime or set.starttime
	local endTime = set.endTime or set.endtime or time()
	
	return SetLabelFormat(set.name or "Unknown", startTime, endTime)
end

function Window:set_mode_title()
	if not self.selectedmode or not self.selectedset then return end
	local name = self.selectedmode.title or self.selectedmode:GetName()

	-- save window settings for RestoreView after reload
	self.db.set = self.selectedset
	local savemode = name
	if self.history[1] then -- can't currently preserve a nested mode, use topmost one
		savemode = self.history[1].title or self.history[1]:GetName()
	end
	self.db.mode = savemode

	if self.db.titleset then
		local setname
		if self.selectedset == "current" then
			setname = L["Current"]
		elseif self.selectedset == "total" then
			setname = L["Total"]
		else
			local set = self:get_selected_set()
			if set then
				setname = Skada:GetSetLabel(set)
			end
		end
	if setname then
		name = name .. ": " .. setname
	end
	end
	if disabled and (self.selectedset == "current" or self.selectedset == "total") then
		-- indicate when data collection is disabled
		name = name .. "  |cFFFF0000" .. L["DISABLED"] .. "|r"
	end
	self.metadata.title = name
	if self.display and self.display.SetTitle then
		self.display:SetTitle(self, name)
	end
end

local function sort_modes()
	tsort(modes, function(a, b)
		if Skada.db.profile.sortmodesbyusage and Skada.db.profile.modeclicks then
			-- Most frequest usage order
			return (Skada.db.profile.modeclicks[a:GetName()] or 0) > (Skada.db.profile.modeclicks[b:GetName()] or 0)
		else
			-- Alphabetic order
			return a:GetName() < b:GetName()
		end
	end)
end

local function click_on_mode(win, id, label, button)
	if button == "LeftButton" then
		local mode = find_mode(id)
		if mode then
			-- Store number of clicks on modes, for automatic sorting.
			if Skada.db.profile.sortmodesbyusage then
				if not Skada.db.profile.modeclicks then
					Skada.db.profile.modeclicks = {}
				end
				Skada.db.profile.modeclicks[id] = (Skada.db.profile.modeclicks[id] or 0) + 1
				sort_modes()
			end
			win:DisplayMode(mode)
		end
	elseif button == "RightButton" then
		win:RightClick()
	end
end

-- Sets up the mode list.
function Window:DisplayModes(settime)
	self.history = wipe(self.history or {})
	self:Wipe()

	self.selectedplayer = nil
	self.selectedmode = nil

	self.metadata = wipe(self.metadata or {})

	self.metadata.title = L["Skada: Modes"]

	-- Find the selected set
	-- With Native API, we only have "current" and "total" sessions
	-- Historical sessions are managed by WoW's API
	if settime == "current" or settime == "total" then
		self.selectedset = settime
	else
		-- Try to parse as session ID
		local sessionId = tonumber(settime)
		if sessionId then
			self.selectedset = settime -- Store as string session ID
		else
			-- Default to current
			self.selectedset = "current"
		end
	end

	self.metadata.click = click_on_mode
	self.metadata.maxvalue = 1
	self.metadata.sortfunc = function(a, b) return a.name < b.name end

	if self.display and self.display.SetTitle then
		self.display:SetTitle(self, self.metadata.title)
	end
	self.changed = true

	if self.child then
		self.child:DisplayModes(settime)
	end

	Skada:UpdateDisplay(false)
end

local function click_on_set(win, id, label, button)
	if button == "LeftButton" then
		win:DisplayModes(id)
	elseif button == "RightButton" then
		win:RightClick()
	end
end

-- Sets up the set list.
function Window:DisplaySets()
	self.history = wipe(self.history or {})
	self:Wipe()

	self.metadata = wipe(self.metadata or {})

	self.selectedplayer = nil
	self.selectedmode = nil
	self.selectedset = nil

	self.metadata.title = L["Skada: Fights"]
	if self.display and self.display.SetTitle then
		self.display:SetTitle(self, self.metadata.title)
	end

	self.metadata.click = click_on_set
	self.metadata.maxvalue = 1
	-- self.metadata.sortfunc = function(a,b) return a.name < b.name end
	self.changed = true

	if self.child then
		self.child:DisplaySets()
	end

	Skada:UpdateDisplay(false)
end

-- Default "right-click" behaviour in case no special click function is defined:
-- 1) If there is a mode traversal history entry, go to the last mode.
-- 2) Go to modes list if we are in a mode.
-- 3) Go to set list.
function Window:RightClick(group, button)
	if self.selectedmode then
		-- If mode traversal history exists, go to last entry, else mode list.
		if #self.history > 0 then
			self:DisplayMode(tremove(self.history))
		else
			self:DisplayModes(self.selectedset)
		end
	elseif self.selectedset then
		self:DisplaySets()
	end
end

function Skada:tcopy(to, from, ...)
	for k, v in pairs(from) do
		local skip = false
		if ... then
			for i, j in ipairs(...) do
				if j == k then
					skip = true
					break
				end
			end
		end
		if not skip then
			if type(v) == "table" then
				to[k] = {}
				Skada:tcopy(to[k], v, ...)
			else
				to[k] = v
			end
		end
	end
end

function Skada:CreateWindow(name, db, display)
	local isnew = false
	if not db then
		isnew = true
		db = {}
		self:tcopy(db, Skada.windowdefaults)
		tinsert(self.db.profile.windows, db)
	end
	if display then
		db.display = display
	end

	-- Migrate old settings.
	if not db.barbgcolor then
		db.barbgcolor = { r = 0.3, g = 0.3, b = 0.3, a = 0.6 }
	end
	if not db.buttons then
		db.buttons = { menu = true, reset = true, report = true, mode = true, segment = true, stop = true }
	end
	if not db.scale then
		db.scale = 1
	end

	if not db.version then
		-- On changes that needs updates to window data structure, increment version in defaults and handle it after this bit.
		db.version = 1
		db.buttons.stop = true
	end

	local window = Window:new()
	window.db = db
	window.db.name = name

	if self.displays[window.db.display] then
		-- Set the window's display and call it's Create function.
		window:SetDisplay(window.db.display or "bar")

		window.display:Create(window, isnew)

		tinsert(windows, window)

		-- Set initial view, set list.
		window:DisplaySets()

		if isnew and find_mode(L["Damage"]) then
			-- Default mode for new windows - will not fail if mode is disabled.
			self:RestoreView(window, "current", L["Damage"])
		elseif window.db.set or window.db.mode then
			-- Restore view.
			self:RestoreView(window, window.db.set, window.db.mode)
		end
	else
		-- This window's display is missing.
		self:Print("Window '" ..
		name .. "' was not loaded because its display module, '" .. window.db.display .. "' was not found.")
	end

	self:ApplySettings()
	return window
end

-- Deleted named window from our windows table, and also from db.
function Skada:DeleteWindow(name)
	for i, win in ipairs(windows) do
		if win.db.name == name then
			win:destroy()
			wipe(tremove(windows, i))
		end
	end
	for i, win in ipairs(self.db.profile.windows) do
		if win.name == name then
			tremove(self.db.profile.windows, i)
		end
	end
end

function Skada:Print(msg)
	print("|cFF33FF99Skada|r: " .. msg)
end

function Skada:Debug(...)
	if not Skada.db.profile.debug then return end
	local msg = ""
	for i = 1, select("#", ...) do
		local val = select(i, ...)
		local v
		-- Safe conversion for debug output
		if issecretvalue and issecretvalue(val) then
			v = string.format("%s", val)
		else
			v = tostring(val)
		end
		
		if #msg > 0 then
			msg = msg .. ", "
		end
		msg = msg .. v
	end
	print("|cFF33FF99Skada Debug|r: " .. msg)
end

local function slashHandler(param)
	local reportusage =
	"/skada report [raid|party|instance|guild|officer|say] [current||total|set_num] [mode] [max_lines]"
	if param == "pets" then
		Skada:PetDebug()
	elseif param == "cpu" then
		local funcs = {}
		UpdateAddOnCPUUsage()
		for k, v in pairs(Skada) do
			if type(v) == "function" then
				local usage, calls = GetFunctionCPUUsage(v, true)
				--local info = debug.getinfo(v, "n")
				tinsert(funcs, { ["name"] = k, ["usage"] = usage, ["calls"] = calls })
			end
		end
		tsort(funcs, function(a, b) return a.usage > b.usage end)
		for i, func in ipairs(funcs) do
			print(func.name .. '\t' .. func.usage .. ' (' .. func.calls .. ')')
			if i > 10 then
				break
			end
		end
	elseif param == "test" then
		Skada:Notify("test")
	elseif param == "reset" then
		Skada:Reset()
	-- newsegment command removed - with Native API, sessions are managed by WoW
	elseif param == "toggle" then
		Skada:ToggleWindow()
	elseif param == "debug" then
		Skada.db.profile.debug = not Skada.db.profile.debug
		Skada:Print("Debug mode " ..
		(Skada.db.profile.debug and ("|cFF00FF00" .. L["ENABLED"] .. "|r") or ("|cFFFF0000" .. L["DISABLED"] .. "|r")))
	elseif param == "config" then
		Skada:OpenOptions()
	elseif param:sub(1, 6) == "report" then
		local chan = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "instance") or
			(IsInRaid() and "raid") or
			(IsInGroup() and "party") or
			"say"
		local set = "current"
		local report_mode_name = L["Damage"]
		local w1, w2, w3, w4 = param:match("^%s*(%w*)%s*(%w*)%s*([^%d]-)%s*(%d*)%s*$", 7)
		if w1 and #w1 > 0 then
			chan = string.lower(w1)
		end
		if w2 and #w2 > 0 then
			w2 = tonumber(w2) or w2:lower()
			if Skada:find_set(w2) then
				set = w2
			end
		end
		if w3 and #w3 > 0 then
			w3 = strtrim(w3)
			w3 = strtrim(w3, "'\"[]()") -- strip optional quoting
			if find_mode(w3) then
				report_mode_name = w3
			end
		end
		local max = tonumber(w4) or 10

		if chan == "instance" then chan = "instance_chat" end
		if chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer" or chan == "instance_chat" then
			Skada:Report(chan, "preset", report_mode_name, set, max)
		else
			Skada:Print("Usage:")
			Skada:Print(("%-20s"):format(reportusage))
		end
	else
		Skada:Print("Usage:")
		Skada:Print(("%-20s"):format(reportusage))
		Skada:Print(("%-20s"):format("/skada reset"))
		Skada:Print(("%-20s"):format("/skada toggle"))
		Skada:Print(("%-20s"):format("/skada debug"))
		Skada:Print(("%-20s"):format("/skada newsegment"))
		Skada:Print(("%-20s"):format("/skada config"))
		Skada:Print(("%-20s"):format("/skada datatest"))
		Skada:Print(("%-20s"):format("/skada status"))
	end
end

local function sendchat(msg, chan, chantype)
	if chantype == "self" then
		-- To self.
		Skada:Print(msg)
	elseif chantype == "channel" then
		-- To channel.
		SendChatMessage(msg, "CHANNEL", nil, chan)
	elseif chantype == "preset" then
		-- To a preset channel id (say, guild, etc).
		SendChatMessage(msg, string.upper(chan))
	elseif chantype == "whisper" then
		-- To player.
		SendChatMessage(msg, "WHISPER", nil, chan)
	elseif chantype == "bnet" then
		BNSendWhisper(chan, msg)
	end
end

function Skada:Report(channel, chantype, report_mode_name, report_set_name, max, window)
	if chantype == "channel" then
		local list = { GetChannelList() }
		for i = 1, #list, 3 do
			if Skada.db.profile.report.channel == list[i + 1] then
				channel = list[i]
				break
			end
		end
	end

	local report_table
	local report_set
	local report_mode
	if not window then
		report_mode = find_mode(report_mode_name)
		report_set = Skada:find_set(report_set_name)
		if report_set == nil then
			return
		end
		-- Create a temporary fake window.
		report_table = Window:new()

		-- Tell our mode to populate our dataset.
		report_mode:Update(report_table, report_set)
	else
		report_table = window
		report_set = window:get_selected_set()
		report_mode = window.selectedmode
	end

	if not report_set then
		Skada:Print(L["There is nothing to report."])
		return
	end

	-- Sort our temporary table according to value unless ordersort is set.
	if not report_table.metadata.ordersort then
		tsort(report_table.dataset, Skada.valueid_sort)
	end

	-- Title
	sendchat(
	string.format(L["Skada: %s for %s:"], report_mode.title or report_mode:GetName(), Skada:GetSetLabel(report_set)),
		channel, chantype)

	-- For each item in dataset, print label and valuetext.
	local nr = 1
	for i, data in ipairs(report_table.dataset) do
		if data.id then
			local label = data.reportlabel or (data.spellid and GetSpellLink(data.spellid)) or data.label
			local value = data.valuetext or data.valueText1
			if report_mode.metadata and report_mode.metadata.showspots then
				sendchat(("%2u. %s   %s"):format(nr, label, value), channel, chantype)
			else
				sendchat(("%s   %s"):format(label, value), channel, chantype)
			end
			nr = nr + 1
		end
		if nr > max then
			break
		end
	end
end

function Skada:RefreshMMButton()
	if icon then
		icon:Refresh("Skada", self.db.profile.icon)
		if self.db.profile.icon.hide then
			icon:Hide("Skada")
		else
			icon:Show("Skada")
		end
	end
end



function Skada:SetActive(enable)
	if enable then
		for i, win in ipairs(windows) do
			win:Show()
		end
	else
		for i, win in ipairs(windows) do
			win:Hide()
		end
	end
	
	-- With Native API, window visibility doesn't affect data collection
	-- The hidedisables setting only controls window visibility
end

function Skada:CanReset()
	return true
end

function Skada:Reset()
	self:Wipe()

	if self.last ~= nil then
		wipe(self.last)
		self.last = nil
	end

	-- With Native API, sets are managed by WoW's C_DamageMeter
	-- No local set management needed

	-- Reset all windows
	for i, win in ipairs(windows) do
		win:Reset()
		win.selectedset = "current"
		win.changed = true
	end

	-- Let the modes know
	for i, mode in ipairs(modes) do
		if mode.OnReset then
			mode:OnReset()
		end
	end

	if self.db.profile.reset.instance then
		Skada:OnCombatStart()
	end
end

function Skada:DeleteSet(set)
	-- With Native API, sets are managed by WoW's C_DamageMeter
	-- Individual set deletion not supported
end

function Skada:ReloadSettings()
	-- Delete all existing windows in case of a profile change.
	for i, win in ipairs(windows) do
		win:destroy()
	end
	windows = {}

	-- Re-create windows
	for i, win in ipairs(self.db.profile.windows) do
		self:CreateWindow(win.name, win)
	end

	self.total = self.char.total

	-- Minimap button.
	if icon and not icon:IsRegistered("Skada") then
		icon:Register("Skada", dataobj, self.db.profile.icon)
	end

	self:RefreshMMButton()

	self:ApplySettings()
end

function Skada:ApplySettings()
	for i, win in ipairs(windows) do
		if win.display and win.display.ApplySettings then
			win.display:ApplySettings(win)
		end
	end

	if (self.db.profile.hidesolo and not IsInGroup()) or (self.db.profile.hidepvp and IsInPVP()) then
		self:SetActive(false)
	else
		self:SetActive(true)

		for i, win in ipairs(windows) do
			if win.db.hidden and win:IsShown() then
				win:Hide()
			end
		end
	end

	self:UpdateDisplay(true)
end

function Skada:SetFeed(feed)
	selectedfeed = feed
	self:UpdateDisplay()
end

-- NewSegment removed - with Native API, sessions are managed by WoW

function Skada:OnCombatEnd()
	-- Called when Native API detects combat session has ended
	if not self.current then return end
	
	self:Debug("OnCombatEnd")
	
	-- Save reference to last session for "Last" view
	self.last = self.current
	self.current = nil

	-- Restore window views if configured
	for i, win in ipairs(windows) do
		if win.db.returnaftercombat and win.restore_mode and win.restore_set then
			self:RestoreView(win, win.restore_set, win.restore_mode)
			win.restore_mode = nil
			win.restore_set = nil
		end
		-- Show windows if they were hidden during combat
		if not win.db.hidden and self.db.profile.hidecombat and (not self.db.profile.hidesolo or IsInGroup()) then
			win:Show()
		end
	end

	-- Update display and stop combat timer
	self:UpdateDisplay(true)
	if update_timer then self:CancelTimer(update_timer) end
	update_timer = nil
end

function Skada:OnCombatStart()
	-- Called when Native API detects active combat session
	self:Wipe()

	-- Mark that we are in combat (modules query API directly for data)
	self.current = { name = "Current", sessionType = 1 }
	
	-- Add encounter info if available
	if self.encounterName and GetTime() < (self.encounterTime or 0) + 15 then
		self.current.mobname = self.encounterName
		self.current.gotboss = true
		self.encounterName = nil
		self.encounterTime = nil
	end

	for i, win in ipairs(windows) do
		-- Store current view for restoration after combat if configured
		if win.db.returnaftercombat then
			win.restore_set = win.selectedset
			win.restore_mode = win.selectedmode and win.selectedmode:GetName()
		end
		
		-- Always switch to current segment when entering combat
		win.selectedset = "current"
		
		-- Switch to combat mode if configured, otherwise just refresh current mode
		if win.db.modeincombat and win.db.modeincombat ~= "" then
			local mymode = find_mode(win.db.modeincombat)
			if mymode then
				win:DisplayMode(mymode)
			end
		elseif win.selectedmode then
			-- Keep current mode but trigger a refresh
			win.changed = true
		end

		if not win.db.hidden and self.db.profile.hidecombat then
			win:Hide()
		end
	end
	
	self:UpdateDisplay(true)
	update_timer = self:ScheduleRepeatingTimer("UpdateDisplay", self.db.profile.updatefrequency or 0.25)
end

function Skada:Wipe()
	for i, win in ipairs(windows) do win:Wipe() end
end

function Skada:RestoreView(win, theset, themode)
	if theset and type(theset) == "string" and (theset == "current" or theset == "total" or theset == "last") then
		win.selectedset = theset
	elseif theset and type(theset) == "number" then
		-- Session ID from Native API
		win.selectedset = tostring(theset)
	else
		win.selectedset = "current"
	end

	changed = true

	if themode then
		local mymode = find_mode(themode)
		if mymode then
			win:DisplayMode(mymode)
		else
			win:DisplayModes(win.selectedset)
		end
	else
		win:DisplayModes(win.selectedset)
	end
end

function Skada:find_set(s)
	if s == "current" then
		local set = self.NativeAPI:GetCurrentSession()
		if set then 
			set.sessionType = 1
			self:Debug("find_set('current') returned session with", set.combatSources and #set.combatSources or 0, "sources")
		else
			self:Debug("find_set('current') returned nil")
		end
		return set
	elseif s == "total" then
		local set = self.NativeAPI:GetTotalSession()
		if set then set.sessionType = 0 end
		return set
	elseif type(s) == "string" and tonumber(s) then
		return self.NativeAPI:GetSessionByID(tonumber(s))
	end
	return s
end

-- Helper to find player in Native API session
-- Note: With WoW 12.0+ secret values, we must use pcall for comparisons
function Skada:find_player_in_session(session, playerGUID)
	if not session or not playerGUID then return nil end
	local sources = session.combatSources or session.participants or {}
	for _, p in pairs(sources) do
		-- Secret values cannot be compared directly, wrap in pcall
		local success, matches = pcall(function()
			return (p.sourceGUID == playerGUID) or (p.guid == playerGUID) or (p.unitGUID == playerGUID)
		end)
		if success and matches then
			return p
		end
	end
	return nil
end

-- Alias for backward compatibility
function Skada:find_player(set, playerGUID)
	return self:find_player_in_session(set, playerGUID)
end

function Skada:PLAYER_REGEN_DISABLED()
	if not self.current then
		self:OnCombatStart()
	end
end

function Skada:PLAYER_REGEN_ENABLED()
	-- Only end combat if we're not in an encounter (boss fights use ENCOUNTER_END)
	if self.current and not self.current.gotboss then
		self:OnCombatEnd()
	end
end

function Skada:ENCOUNTER_START(encounterId, encounterName)
	self.encounterName = encounterName
	self.encounterTime = GetTime()
	if self.current then
		self.current.mobname = encounterName
		self.current.gotboss = true
	end
end

function Skada:ENCOUNTER_END(encounterId, encounterName)
	if self.current then
		self.current.mobname = encounterName
		self.current.gotboss = true
		-- End combat after boss encounter ends
		self:OnCombatEnd()
	end
end

-- Native API Event Handlers
function Skada:DAMAGE_METER_COMBAT_SESSION_UPDATED()
	if self.NativeAPI then
		local sessionData = self.NativeAPI:GetCurrentSession()
		if sessionData and not self.current then
			self:OnCombatStart()
		end
		self:UpdateDisplay(true)
	end
end

function Skada:DAMAGE_METER_CURRENT_SESSION_UPDATED()
	if self.NativeAPI then
		self:UpdateDisplay(true)
	end
end

function Skada:DAMAGE_METER_RESET()
	self:Reset()
end


--
-- Data broker
--

function dataobj:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()

	local set
	if Skada.current then
		set = Skada.current
	else
		-- With Native API, use total session if no current
		set = Skada.NativeAPI and Skada.NativeAPI:GetTotalSession()
	end
	if set then
		GameTooltip:AddLine(L["Skada summary"], 0, 1, 0)
		for i, mode in ipairs(modes) do
			if mode.AddToTooltip ~= nil then
				mode:AddToTooltip(set, GameTooltip)
			end
		end
	end

	GameTooltip:AddLine(L["Hint: Left-Click to toggle Skada window."], 0, 1, 0)
	GameTooltip:AddLine(L["Shift + Left-Click to reset."], 0, 1, 0)
	GameTooltip:AddLine(L["Right-click to open menu"], 0, 1, 0)

	GameTooltip:Show()
end

function dataobj:OnLeave()
	GameTooltip:Hide()
end

function dataobj:OnClick(button)
	if button == "LeftButton" and IsShiftKeyDown() then
		Skada:Reset()
	elseif button == "LeftButton" then
		Skada:ToggleWindow()
	elseif button == "RightButton" then
		Skada:OpenMenu()
	end
end

local totalbarcolor = { r = 0.2, g = 0.2, b = 0.5, a = 1 }
local bossicon = "Interface\\Icons\\Achievment_boss_ultraxion"
local nonbossicon = "Interface\\Icons\\icon_petfamily_critter"

function Skada:UpdateDisplay(force)
	-- Force an update by setting our "changed" flag to true.
	if force then
		changed = true
	end

	-- Update data feed.
	-- This is done even if our set has not changed, since for example DPS changes even though the data does not.
	-- Does not update feed text if nil.
	if selectedfeed ~= nil then
		local feedtext = selectedfeed()
		if feedtext then
			dataobj.text = feedtext
		end
	end

	for i, win in ipairs(windows) do
		-- Update window if forced, if window state changed, or if in combat (to refresh bars/feeds)
		if changed or win.changed or self.current then
			win.changed = false
			if win.selectedmode then -- Force mode display for display systems which do not handle navigation.
				win:set_mode_title()
				local set = win:get_selected_set()

				if set then
					-- Inform window that a data update will take place.
					win:UpdateInProgress()

					-- Let mode update data.
					if win.selectedmode.Update then
						win.selectedmode:Update(win, set)
					else
						self:Print("Mode " .. win.selectedmode:GetName() .. " does not have an Update function!")
					end

					-- Add a total bar using the mode summaries optionally.
					if self.db.profile.showtotals and win.selectedmode.FormatSetSummary then
						local total = 0
						local existing = nil
						for i, data in ipairs(win.dataset) do
							if data.id then
								-- Protect against secret values in summation
								local val = Skada:SafeNumber(data.value)
								total = total + val
							end
							if not existing and not data.id then
								existing = data
							end
						end
						total = total + 1

						local d = existing or {}
						win.selectedmode:FormatSetSummary(d, set)
						d.value = total
						d.label = L["Total"]
						d.icon = dataobj.icon
						d.id = "total"
						d.ignore = true
						if not existing then
							tinsert(win.dataset, 1, d)
						end
					end
				end

				-- Let window display the data.
				if win.display and win.display.Update then
					local success, err = pcall(win.display.Update, win.display, win)
					if not success and Skada.db.profile.debug then
						Skada:Debug("Display Update Error (Inside Mode):", err)
					end
				end
			elseif win.selectedset then
				local set = win:get_selected_set()

				-- Wipe only on explicit mode/view change, not every refresh.
				if win.changed or not win.metadata.is_modelist then
					if Skada.db.profile.debug then
						Skada:Debug("View Change to Mode List. Wiping.")
					end
					win:Wipe()
				end

				-- View available modes.
				if Skada.db.profile.debug then
					Skada:Debug("Updating Mode List. Modes count:", #modes, "Set exists:", set ~= nil)
					if set then
						Skada:Debug("  Set Name:", set.name or "Current/Unknown")
						Skada:Debug("  Sources count:", set.combatSources and #set.combatSources or 0)
					end
				end
				for i, mode in ipairs(modes) do
					local d = win.dataset[i] or {}
					win.dataset[i] = d

					d.id = mode:GetName()
					d.label = mode:GetName()
					d.value = 1
					if set and mode.FormatSetSummary ~= nil then
						local success, err = pcall(mode.FormatSetSummary, mode, d, set)
						if not success and Skada.db.profile.debug then
							Skada:Debug("FormatSetSummary Error in", mode:GetName(), ":", err)
						end
					end
					if mode.metadata and mode.metadata.icon then
						d.icon = mode.metadata.icon
					end
				end

				if Skada.db.profile.debug then
					Skada:Debug("Mode List Dataset size:", #win.dataset)
				end

				-- Tell window to sort by our data order. Our modes are in the correct order already.
				win.metadata.ordersort = true
				win.metadata.maxvalue = 1 -- Ensure bars show up

				-- Let display provider/tooltip know we are showing a mode list.
				if set then
					win.metadata.is_modelist = true
				end

				-- Let window display the data.
				if win.display and win.display.Update then
					local success, err = pcall(win.display.Update, win.display, win)
					if not success and Skada.db.profile.debug then
						Skada:Debug("Display Update Error (Mode List):", err)
					end
				end
			else
				-- Wipe only on explicit view change.
				if win.changed or win.metadata.is_modelist or win.selectedmode then
					win:Wipe()
				end

				-- View available sets.
				local nr = 1
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = "total"
				d.label = L["Total"]
				d.value = 1
				if self.total and self.total.gotboss then
					d.icon = bossicon
				else
					d.icon = nonbossicon
				end

				nr = nr + 1
				d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = "current"
				d.label = L["Current"]
				d.value = 1
				if self.current and self.current.gotboss then
					d.icon = bossicon
				else
					d.icon = nonbossicon
				end

				-- With Native API, historical sessions are managed by WoW
				-- Not displayed in local menu

				win.metadata.ordersort = true

				-- Let window display the data.
				if win.display and win.display.Update then
					local success, err = pcall(win.display.Update, win.display, win)
					if not success and Skada.db.profile.debug then
						Skada:Debug("Display Update Error (Set List):", err)
					end
				end
			end
		end
	end

	-- Mark as unchanged.
	changed = false
end

--[[

API
Everything below this is OK to use in modes.

--]]

function Skada:GetSets()
	-- With Native API, sessions are managed by WoW's C_DamageMeter
	-- Return empty table for compatibility
	return {}
end

function Skada:GetModes(sortfunc)
	return modes
end

-- Formats a number into human readable form.
function Skada:FormatNumber(number)
	if not number then return "" end
	
	-- Check for WoW 12.0 secret value FIRST to avoid comparison errors
	if issecretvalue and issecretvalue(number) then
		-- Secret values should be formatted with FormatNumberSecret, not here
		-- Return a placeholder to indicate misuse
		return "?"
	end
	
	-- Now it is safe to perform comparisons
	if number == 0 then return "" end

	if self.db.profile.numberformat == 1 then
		if number > 1000000000 then
			return ("%dB"):format(number / 1000000000)
		elseif number > 100000000 then
			return ("%dM"):format(number / 1000000)
		elseif number > 10000000 then
			return ("%02.1fM"):format(number / 1000000)
		elseif number > 1000000 then
			return ("%02.2fM"):format(number / 1000000)
		elseif number > 100000 then
			return ("%dK"):format(number / 1000)
		elseif number > 999 then
			return ("%02.1fK"):format(number / 1000)
		end
	end
	
	return tostring(math.floor(number))
end

-- Format a number that may be a WoW 12.0 secret value.
function Skada:FormatNumberSecret(number)
	-- For secret values, use string.format with %.0f for clean whole numbers
	if issecretvalue and issecretvalue(number) then
		local success, s = pcall(string.format, "%.0f", number)
		if success then return s end
		return "?"
	end
	-- For normal values, use regular formatting
	return self:FormatNumber(number)
end

-- Safely converts a value to a number, handling nil values and "secret values" from Native API.
function Skada:SafeNumber(value)
	if not value then return 0 end
	
	-- Check for WoW 12.0 issecretvalue function
	if issecretvalue and issecretvalue(value) then
		return 0 -- Return 0 for arithmetic/sorting safety; the module handles secret display separately
	end
	
	if type(value) ~= "number" then return 0 end
	
	-- Try multiple approaches to strip secret status
	-- First try: string.format (like NativeAPI.sanitizeNumber)
	local success, s = pcall(string.format, "%f", value)
	if success then
		local num = tonumber(s)
		if num then return num end
	end
	
	-- Second try: tostring (might work better with some secret values)
	local success2, s2 = pcall(tostring, value)
	if success2 then
		local num = tonumber(s2)
		if num then return num end
	end
	
	-- Third try: arithmetic (value + 0)
	local success3, result = pcall(function() return value + 0 end)
	if success3 and type(result) == "number" then
		return result
	end
	
	return value -- Return original value (possibly secret) instead of 0
end

local function scan_for_columns(mode)
	-- Only process if not already scanned.
	if not mode.scanned then
		mode.scanned = true

		-- Add options for this mode if available.
		if mode.metadata and mode.metadata.columns then
			Skada:AddColumnOptions(mode)
		end

		-- Scan any linked modes.
		if mode.metadata then
			if mode.metadata.click1 then
				scan_for_columns(mode.metadata.click1)
			end
			if mode.metadata.click2 then
				scan_for_columns(mode.metadata.click2)
			end
			if mode.metadata.click3 then
				scan_for_columns(mode.metadata.click3)
			end
		end
	end
end

-- Register a display system
local numorder = 5
function Skada:AddDisplaySystem(key, mod)
	self.displays[key] = mod
	if mod.description then
		Skada.options.args.windows.args[key .. "desc"] = {
			type = "description",
			name = mod.description,
			order = numorder
		}
		numorder = numorder + 1
	end
end

-- Register a mode.
function Skada:AddMode(mode, category)
	-- Mode set verification removed - not needed with Native API
	-- verify_set function was undefined

	-- Set mode category (used for menus)
	mode.category = category or L['Other']

	-- Add to mode list
	tinsert(modes, mode)

	-- Set this mode as the active mode if it matches the saved one.
	-- Bit of a hack.
	for i, win in ipairs(windows) do
		if mode:GetName() == win.db.mode then
			self:RestoreView(win, win.db.set, mode:GetName())
		end
	end

	-- Find if we now have our chosen feed.
	-- Also a bit ugly.
	if selectedfeed == nil and self.db.profile.feed ~= "" then
		for name, feed in pairs(feeds) do
			if name == self.db.profile.feed then
				self:SetFeed(feed)
			end
		end
	end

	-- Add column configuration if available.
	if mode.metadata then
		scan_for_columns(mode)
	end

	-- Sort modes.
	sort_modes()

	-- Remove all bars and start over to get ordering right.
	-- Yes, this all sucks - the problem with this and the above is that I don't know when
	-- all modules are loaded. :/
	for i, win in ipairs(windows) do
		win:Wipe()
	end
	changed = true
end

-- Unregister a mode.
function Skada:RemoveMode(mode)
	tremove(modes, mode)
end

function Skada:GetFeeds()
	return feeds
end

-- Register a data feed.
function Skada:AddFeed(name, func)
	feeds[name] = func
end

-- Unregister a data feed.
function Skada:RemoveFeed(name, func)
	for i, feed in ipairs(feeds) do
		if feed.name == name then
			tremove(feeds, i)
		end
	end
end

--[[

Sets

--]]

function Skada:GetSetTime(set)
	-- For Native API sessions
	if set.startTime then
		if set.endTime then
			-- Session has ended, return duration
			return (set.endTime - set.startTime)
		else
			-- Session is still active, return current duration
			return (time() - set.startTime)
		end
	-- Legacy support
	elseif set.time then
		return set.time
	elseif set.starttime then
		return (time() - set.starttime)
	else
		return 0
	end
end

-- Returns the time (in seconds) a player has been active for a set.
function Skada:PlayerActiveTime(set, player)
	-- With Native API, we don't have individual player active time tracking
	-- Return session duration if player has activity, 0 otherwise
	
	-- Check if player has any activity in this set
	local hasActivity = false
	
	-- Check common activity fields from Native API
	-- Use SafeNumber to handle secret values
	if Skada:SafeNumber(player.totalAmount or 0) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.healing or 0) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.damageTaken or 0) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.dispels or 0) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.interrupts or 0) > 0 then
		hasActivity = true
	end
	
	if not hasActivity then
		return 0
	end
	
	-- Calculate session duration
	local startTime = set.startTime or set.starttime or 0
	local endTime = set.endTime or set.endtime or time()
	
	if endTime <= startTime then
		-- Session hasn't started or is instantaneous
		return 0
	end
	
	return endTime - startTime
end

-- Pet tracking is handled by the Native API in WoW 12.0+
-- No custom pet tracking needed

-- FixMyPets removed - Native API handles pet tracking

function Skada:SetTooltipPosition(tooltip, frame)
	local p = self.db.profile.tooltippos
	if p == "default" then
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40);
	elseif p == "topleft" then
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
	elseif p == "topright" then
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
	elseif p == "smart" and frame then
		-- Choose anchor point depending on frame position
		if frame:GetLeft() < (GetScreenWidth() / 2) then
			tooltip:SetOwner(frame, "ANCHOR_NONE")
			tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, 0)
		else
			tooltip:SetOwner(frame, "ANCHOR_NONE")
			tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -10, 0)
		end
	end
end

-- Format value text in a standardized way. Up to 3 value and boolean (show/don't show) combinations are accepted.
-- Values are set on the datasetItem from left to right.
function Skada:FormatValueText(datasetItem, ...)
	local value1, bool1, value2, bool2, value3, bool3 = ...

	if not datasetItem then return end
	-- Backward compatibility
	if type(datasetItem) == "string" then
		return datasetItem
	end
	if bool1 then
		datasetItem.valueText1 = value1
	end

	if bool2 then
		datasetItem.valueText2 = value2
	end

	if bool3 then
		datasetItem.valueText3 = value3
	end
end

local function value_sort(a, b)
	if not a or a.value == nil then
		return false
	elseif not b or b.value == nil then
		return true
	else
		return a.value > b.value
	end
end

function Skada.valueid_sort(a, b)
	if not a or a.value == nil or a.id == nil then
		return false
	elseif not b or b.value == nil or b.id == nil then
		return true
	else
		return a.value > b.value
	end
end

-- Tooltip display. Shows subview data for a specific row.
-- Using a fake window, the subviews are asked to populate the window's dataset normally.
local ttwin = Window:new()
local white = { r = 1, g = 1, b = 1 }
function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
	-- Clean dataset.
	wipe(ttwin.dataset)

	-- Tell mode we are entering our real window.
	if mode.Enter then
		mode:Enter(win, id, label)
	end

	-- Ask mode to populate dataset in our fake window.
	mode:Update(ttwin, win:get_selected_set())

	-- Sort dataset unless we are using ordersort.
	if not mode.metadata or not mode.metadata.ordersort then
		tsort(ttwin.dataset, value_sort)
	end

	-- Show title and data if we have data.
	if #ttwin.dataset > 0 then
		tooltip:AddLine(mode.title or mode:GetName(), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

		-- Display the top X, default 3, rows.
		local nr = 0
		for i, data in ipairs(ttwin.dataset) do
			if data.id and nr < Skada.db.profile.tooltiprows then
				nr = nr + 1

				local color = white
				if data.color then
					-- Explicit color from dataset.
					color = data.color
				elseif data.class then
					-- Class color.
					local color = Skada.classcolors[data.class]
				end

				local label = data.label
				if mode.metadata and mode.metadata.showspots then
					label = nr .. ". " .. label
				end

				if data.labeltext then
					tooltip:AddDoubleLine(label, data.valuetext, color.r, color.g, color.b)
				else
					tooltip:AddDoubleLine(label, data.valueText1, color.r, color.g, color.b)
				end
			end
		end

		-- Add an empty line.
		if mode.Enter then
			tooltip:AddLine(" ")
		end
	end
end

-- Generic tooltip function for displays
function Skada:ShowTooltip(win, id, label)
	local t = GameTooltip
	if Skada.db.profile.tooltips then
		if win.metadata.is_modelist and Skada.db.profile.informativetooltips then
			t:ClearLines()

			Skada:AddSubviewToTooltip(t, win, find_mode(id), id, label)

			t:Show()
		elseif win.metadata.click1 or win.metadata.click2 or win.metadata.click3 or win.metadata.tooltip then
			t:ClearLines()

			local hasClick = win.metadata.click1 or win.metadata.click2 or win.metadata.click3

			-- Current mode's own tooltips.
			if win.metadata.tooltip then
				local numLines = t:NumLines()
				win.metadata.tooltip(win, id, label, t)

				-- Spacer
				if t:NumLines() ~= numLines and hasClick then
					t:AddLine(" ")
				end
			end

			-- Generic informative tooltips.
			if Skada.db.profile.informativetooltips then
				if win.metadata.click1 then
					Skada:AddSubviewToTooltip(t, win, win.metadata.click1, id, label)
				end
				if win.metadata.click2 then
					Skada:AddSubviewToTooltip(t, win, win.metadata.click2, id, label)
				end
				if win.metadata.click3 then
					Skada:AddSubviewToTooltip(t, win, win.metadata.click3, id, label)
				end
			end

			-- Current mode's own post-tooltips.
			if win.metadata.post_tooltip then
				local numLines = t:NumLines()
				win.metadata.post_tooltip(win, id, label, t)

				-- Spacer
				if t:NumLines() ~= numLines and hasClick then
					t:AddLine(" ")
				end
			end

			-- Click directions.
			if win.metadata.click1 then
				t:AddLine(L["Click for"] .. " " .. win.metadata.click1:GetName() .. ".", 0.2, 1, 0.2)
			end
			if win.metadata.click2 then
				t:AddLine(L["Shift-Click for"] .. " " .. win.metadata.click2:GetName() .. ".", 0.2, 1, 0.2)
			end
			if win.metadata.click3 then
				t:AddLine(L["Control-Click for"] .. " " .. win.metadata.click3:GetName() .. ".", 0.2, 1, 0.2)
			end
			t:Show()
		end
	end
end

-- Generic border
function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	local borderbackdrop = {}
	if not frame.borderFrame then
		frame.borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		frame.borderFrame:SetFrameLevel(0)
	end
	frame.borderFrame:SetPoint("TOPLEFT", frame, -thickness - (padleft or 0), thickness + (padtop or 0))
	frame.borderFrame:SetPoint("BOTTOMRIGHT", frame, thickness + (padright or 0), -thickness - (padbottom or 0))
	if texture and thickness > 0 then
		borderbackdrop.edgeFile = media:Fetch("border", texture)
	else
		borderbackdrop.edgeFile = nil
	end
	borderbackdrop.edgeSize = thickness
	frame.borderFrame:SetBackdrop(borderbackdrop)
	if color then
		frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	end
end

-- Generic frame settings
function Skada:FrameSettings(db, include_dimensions)
	local obj = {
		type = "group",
		name = L["Window"],
		order = 2,
		args = {

			bgheader = {
				type = "header",
				name = L["Background"],
				order = 1
			},

			texture = {
				type = 'select',
				dialogControl = 'LSM30_Background',
				name = L["Background texture"],
				desc = L["The texture used as the background."],
				values = AceGUIWidgetLSMlists.background,
				get = function() return db.background.texture end,
				set = function(win, key)
					db.background.texture = key
					Skada:ApplySettings()
				end,
				width = "double",
				order = 1.1
			},

			tile = {
				type = 'toggle',
				name = L["Tile"],
				desc = L["Tile the background texture."],
				get = function() return db.background.tile end,
				set = function(win, key)
					db.background.tile = key
					Skada:ApplySettings()
				end,
				order = 1.2
			},

			tilesize = {
				type = "range",
				name = L["Tile size"],
				desc = L["The size of the texture pattern."],
				min = 0,
				max = math.floor(GetScreenWidth()),
				step = 1.0,
				get = function() return db.background.tilesize end,
				set = function(win, val)
					db.background.tilesize = val
					Skada:ApplySettings()
				end,
				order = 1.3
			},


			color = {
				type = "color",
				name = L["Background color"],
				desc = L["The color of the background."],
				hasAlpha = true,
				get = function(i)
					local c = db.background.color
					return c.r, c.g, c.b, c.a
				end,
				set = function(i, r, g, b, a)
					db.background.color = { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
					Skada:ApplySettings()
				end,
				order = 1.4
			},

			borderheader = {
				type = "header",
				name = L["Border"],
				order = 2
			},

			bordertexture = {
				type = "select",
				dialogControl = "LSM30_Border",
				name = L["Border texture"],
				desc = L["The texture used for the borders."],
				values = AceGUIWidgetLSMlists.border,
				get = function() return db.background.bordertexture end,
				set = function(win, key)
					db.background.bordertexture = key
					Skada:ApplySettings()
				end,
				width = "double",
				order = 2.1
			},

			bordercolor = {
				type = "color",
				name = L["Border color"],
				desc = L["The color used for the border."],
				hasAlpha = true,
				get = function(i)
					local c = db.background.bordercolor or { r = 0, g = 0, b = 0, a = 1 }
					return c.r, c.g, c.b, c.a
				end,
				set = function(i, r, g, b, a)
					db.background.bordercolor = { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
					Skada:ApplySettings()
				end,
				order = 2.2
			},

			thickness = {
				type = "range",
				name = L["Border thickness"],
				desc = L["The thickness of the borders."],
				min = 0,
				max = 50,
				step = 0.5,
				get = function() return db.background.borderthickness end,
				set = function(win, val)
					db.background.borderthickness = val
					Skada:ApplySettings()
				end,
				order = 2.3
			},

			optionheader = {
				type = "header",
				name = L["General"],
				order = 4
			},

			scale = {
				type = "range",
				name = L["Scale"],
				desc = L["Sets the scale of the window."],
				min = 0.1,
				max = 3,
				step = 0.01,
				get = function() return db.scale end,
				set = function(win, val)
					db.scale = val
					Skada:ApplySettings()
				end,
				order = 4.1
			},

			strata = {
				type = "select",
				name = L["Strata"],
				desc = L["This determines what other frames will be in front of the frame."],
				values = { ["BACKGROUND"] = "BACKGROUND", ["LOW"] = "LOW", ["MEDIUM"] = "MEDIUM", ["HIGH"] = "HIGH", ["DIALOG"] = "DIALOG", ["FULLSCREEN"] = "FULLSCREEN", ["FULLSCREEN_DIALOG"] = "FULLSCREEN_DIALOG" },
				get = function() return db.strata end,
				set = function(win, val)
					db.strata = val
					Skada:ApplySettings()
				end,
				order = 4.2
			},

		}
	}

	if include_dimensions then
		obj.args.width = {
			type = "range",
			name = L["Width"],
			min = 100,
			max = GetScreenWidth(),
			step = 1.0,
			get = function() return db.width end,
			set = function(win, key)
				db.width = key
				Skada:ApplySettings()
			end,
			order = 4.3
		}

		obj.args.height = {
			type = "range",
			name = L["Height"],
			min = 16,
			max = 400,
			step = 1.0,
			get = function() return db.height end,
			set = function(win, key)
				db.height = key
				Skada:ApplySettings()
			end,
			order = 4.4
		}
	end
	return obj
end

function Skada:OnInitialize()
	-- Register some SharedMedia goodies.
	media:Register("font", "Adventure", [[Interface\Addons\Skada\media\fonts\Adventure.ttf]])
	media:Register("font", "ABF", [[Interface\Addons\Skada\media\fonts\ABF.ttf]])
	media:Register("font", "Vera Serif", [[Interface\Addons\Skada\media\fonts\VeraSe.ttf]])
	media:Register("font", "Diablo", [[Interface\Addons\Skada\media\fonts\Avqest.ttf]])
	media:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\media\fonts\Accidental Presidency.ttf]])

	media:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\media\statusbar\Aluminium]])
	media:Register("statusbar", "Armory", [[Interface\Addons\Skada\media\statusbar\Armory]])
	media:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\media\statusbar\BantoBar]])
	media:Register("statusbar", "Glaze2", [[Interface\Addons\Skada\media\statusbar\Glaze2]])
	media:Register("statusbar", "Gloss", [[Interface\Addons\Skada\media\statusbar\Gloss]])
	media:Register("statusbar", "Graphite", [[Interface\Addons\Skada\media\statusbar\Graphite]])
	media:Register("statusbar", "Grid", [[Interface\Addons\Skada\media\statusbar\Grid]])
	media:Register("statusbar", "Healbot", [[Interface\Addons\Skada\media\statusbar\Healbot]])
	media:Register("statusbar", "LiteStep", [[Interface\Addons\Skada\media\statusbar\LiteStep]])
	media:Register("statusbar", "Minimalist", [[Interface\Addons\Skada\media\statusbar\Minimalist]])
	media:Register("statusbar", "Otravi", [[Interface\Addons\Skada\media\statusbar\Otravi]])
	media:Register("statusbar", "Outline", [[Interface\Addons\Skada\media\statusbar\Outline]])
	media:Register("statusbar", "Perl", [[Interface\Addons\Skada\media\statusbar\Perl]])
	media:Register("statusbar", "Smooth", [[Interface\Addons\Skada\media\statusbar\Smooth]])
	media:Register("statusbar", "Round", [[Interface\Addons\Skada\media\statusbar\Round]])
	media:Register("statusbar", "TukTex", [[Interface\Addons\Skada\media\statusbar\normTex]])
	media:Register("border", "Glow", [[Interface\Addons\Skada\media\border\glowTex]])
	media:Register("border", "Roth", [[Interface\Addons\Skada\media\border\roth]])
	media:Register("background", "Copper", [[Interface\Addons\Skada\media\background\copper]])

	-- Some sounds (copied from Omen).
	media:Register("sound", "Rubber Ducky", 566121) --[[Sound\Doodad\Goblin_Lottery_Open01.ogg]]
	media:Register("sound", "Cartoon FX", 566543) --[[Sound\Doodad\Goblin_Lottery_Open03.ogg]]
	media:Register("sound", "Explosion", 566982) --[[Sound\Doodad\Hellfire_Raid_FX_Explosion05.ogg]]
	media:Register("sound", "Shing!", 566240) --[[Sound\Doodad\PortcullisActive_Closed.ogg]]
	media:Register("sound", "Wham!", 566946) --[[Sound\Doodad\PVP_Lordaeron_Door_Open.ogg]]
	media:Register("sound", "Simon Chime", 566076) --[[Sound\Doodad\SimonGame_LargeBlueTree.ogg]]
	media:Register("sound", "War Drums", 567275) --[[Sound\Event Sounds\Event_wardrum_ogre.ogg]]
	media:Register("sound", "Cheer", 567283) --[[Sound\Event Sounds\OgreEventCheerUnique.ogg]]
	media:Register("sound", "Humm", 569518) --[[Sound\Spells\SimonGame_Visual_GameStart.ogg]]
	media:Register("sound", "Short Circuit", 568975) --[[Sound\Spells\SimonGame_Visual_BadPress.ogg]]
	media:Register("sound", "Fel Portal", 569215) --[[Sound\Spells\Sunwell_Fel_PortalStand.ogg]]
	media:Register("sound", "Fel Nova", 568582) --[[Sound\Spells\SeepingGaseous_Fel_Nova.ogg]]
	media:Register("sound", "You Will Die!", 546633) --[[Sound\Creature\CThun\CThunYouWillDie.ogg]]

	-- DB
	self.db = LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, "Default")
	if type(SkadaPerCharDB) ~= "table" then SkadaPerCharDB = {} end
	self.char = SkadaPerCharDB
	-- self.char.sets not used with Native API
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Skada", self.options, true)

	-- Profiles
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Skada-Profiles",
		LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db), true)
	local profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)
	profiles.order = 600
	profiles.disabled = false
	Skada.options.args.profiles = profiles

	-- Dual spec profiles
	if lds then
		lds:EnhanceDatabase(self.db, "SkadaDB")
		lds:EnhanceOptions(LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db), self.db)
	end

	-- Blizzard options frame
	local panel = CreateFrame("Frame", "SkadaBlizzOptions")
	panel.name = "Skada"
	InterfaceOptions_AddCategory(panel)

	local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", 10, -15)
	fs:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 10, -45)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetText("Skada")

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetText(L["Configure"])
	button:SetWidth(128)
	button:SetPoint("TOPLEFT", 10, -48)
	button:SetScript('OnClick', function()
		while CloseWindows() do end
		return Skada:OpenOptions()
	end)

	-- Slash Handler
	SLASH_SKADA1 = "/skada"
	SlashCmdList.SKADA = slashHandler

	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")
	-- ClearAllIndexes callback removed - method doesn't exist

	if self.db.profile.total then
		self.db.profile.current = nil
		self.db.profile.total = nil
		self.db.profile.sets = nil
	end

	self:SetNotifyIcon("Interface\\Icons\\Spell_Lightning_LightningBolt01")
	self:SetNotifyStorage(self.db.profile.versions)
	self:NotifyOnce(self.versions)
end

function Skada:OpenOptions(window)
	acd:SetDefaultSize("Skada", 800, 600)
	if window then
		acd:Open("Skada")
		acd:SelectGroup("Skada", "windows", window.db.name)
	elseif not acd:Close("Skada") then
		acd:Open("Skada")
	end
end

function Skada:OnEnable()
	self:ReloadSettings()

	-- WoW 12.0.0+ only - use native damage meter API
	if not self.NativeAPI then
		self:Print("|cFFFF0000Error:|r NativeAPI not loaded! Skada requires WoW 12.0.0+")
		return
	end

	-- Load modules first to ensure they register attributes before data arrives
	if self.moduleList then
		for i = 1, #self.moduleList do
			self.moduleList[i](self, L)
		end
		self.moduleList = nil
	end

	-- Register for native damage meter events
	popup:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	popup:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	popup:RegisterEvent("DAMAGE_METER_RESET")
	
	-- Native API doesn't need polling
	
	-- Print info message
	self:Print("Damage meter powered by native WoW 12.0+ API")
	
	-- Test session types to find correct values
	self.NativeAPI:TestSessionTypes()

	-- Only register events that have handlers and are needed with Native API
	popup:RegisterEvent("PLAYER_REGEN_DISABLED")
	popup:RegisterEvent("PLAYER_REGEN_ENABLED")
	popup:RegisterEvent("ENCOUNTER_START")
	popup:RegisterEvent("ENCOUNTER_END")

	if type(CUSTOM_CLASS_COLORS) == "table" then
		Skada.classcolors = CUSTOM_CLASS_COLORS
	end

	-- Instead of listening for callbacks on SharedMedia we simply wait a few seconds and then re-apply settings
	-- to catch any missing media. Lame? Yes.
	self:ScheduleTimer("ApplySettings", 2)
	
	-- With Native API, data collection is always enabled
	disabled = false
end

function Skada:AddLoadableModule(name, description, func)
	if not self.moduleList then self.moduleList = {} end
	self.moduleList[#self.moduleList + 1] = func
	self:AddLoadableModuleCheckbox(name, L[name], description and L[description])
end

function Skada:ShowVersionHistory()
	-- Check if we have any version entries
	if not self.versions or #self.versions == 0 then return end

	-- Show all versions directly using the notify library
	self:ShowDetailedNotification(self.versions)
end