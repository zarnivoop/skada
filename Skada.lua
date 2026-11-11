local _, addon = ...

local Skada = LibStub("AceAddon-3.0"):NewAddon(addon, "Skada", "AceTimer-3.0", "AceEvent-3.0", "LibNotify-1.0")
_G.Skada = Skada

-- Forever display/table faces. Cinzel is a Latin-only display face; fall back
-- to the established UI fonts on locales it does not cover.
Skada.ThemeFonts = {
	title = "Expressway",
	bar = "ABF",
	header = "Marcellus",
}
do
	local locale = _G.GetLocale and _G.GetLocale() or "enUS"
	if locale == "ruRU" or locale == "koKR" or locale == "zhCN" or locale == "zhTW" then
		Skada.ThemeFonts = {
			title = "ABF",
			bar = "Accidental Presidency",
			header = "Accidental Presidency",
		}
	end
end

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

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

function Skada:GetSpellIcon(spellId)
	-- Use cached version from SecretValueHelper for performance
	return self.SecretHelper:GetSpellIcon(spellId)
end
function Skada:GetGameVersion()
	local build = select(4, GetBuildInfo())
	-- Forever reports interface 16001, which is not a retail build number.
	if type(build) == "number" and build >= 16001 and build < 17000 then
		return 16
	end
	return floor((floor(build) / 10000))
end

local popup

-- Aliases
local tsort, tinsert, tremove = table.sort, table.insert, table.remove
local next, pairs, ipairs, type = next, pairs, ipairs, type
-- bit.band no longer needed with Native API

-- Check if the player is in a PvP instance (battleground or arena).
local function IsInPVP()
	local _, instanceType = IsInInstance()
	return instanceType == "pvp" or instanceType == "arena"
end

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
	popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

	popup:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = true, tileSize = 0, edgeSize = 1,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	popup:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
	popup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	popup:SetSize(300, 120)
	popup:SetPoint("CENTER", UIParent, "CENTER")
	popup:SetFrameStrata("TOOLTIP")
	popup:Hide()

	popup:EnableKeyboard(true)
	popup:SetScript("OnKeyDown", function(self, key)
		if GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
			popup:SetPropagateKeyboardInput(false) -- swallow escape
			popup:Hide()
		end
	end)

	local text = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("TOP", popup, "TOP", 0, -25)
	text:SetText(L["Do you want to reset Skada?"])

	local accept = CreateFrame("Button", nil, popup, "BackdropTemplate")
	accept:SetSize(100, 30)
	accept:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 40, 20)
	
	accept:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	accept:SetBackdropColor(0.1, 0.4, 0.1, 0.8)
	accept:SetBackdropBorderColor(0.2, 0.6, 0.2, 1)

	local acceptText = accept:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	acceptText:SetPoint("CENTER")
	acceptText:SetText(L["Yes"])

	accept:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.5, 0.2, 1) end)
	accept:SetScript("OnLeave", function(self) self:SetBackdropColor(0.1, 0.4, 0.1, 0.8) end)
	accept:SetScript("OnClick", function(f)
		Skada:Reset()
		f:GetParent():Hide()
	end)

	local close = CreateFrame("Button", nil, popup, "BackdropTemplate")
	close:SetSize(100, 30)
	close:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -40, 20)
	
	close:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	close:SetBackdropColor(0.4, 0.1, 0.1, 0.8)
	close:SetBackdropBorderColor(0.6, 0.2, 0.2, 1)

	local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	closeText:SetPoint("CENTER")
	closeText:SetText(L["No"])

	close:SetScript("OnEnter", function(self) self:SetBackdropColor(0.5, 0.2, 0.2, 1) end)
	close:SetScript("OnLeave", function(self) self:SetBackdropColor(0.4, 0.1, 0.1, 0.8) end)
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

-- Our windows.
local windows = {}

-- Our display providers.
Skada.displays = {}
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

			duplicate = {
				type = "execute",
				name = L["Duplicate window"],
				desc = L["Create a copy of this window and its settings."],
				order = 19,
				width = "full",
				func = function() Skada:DuplicateWindow(db.name) end,
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
					modes["auto"] = L["Auto"]
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
			if data.id then
				local val = Skada:SafeNumber(data.value)
				if val > self.metadata.maxvalue then
					self.metadata.maxvalue = val
				end
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
-- SecondsToTimeAbbrev returns a format pattern on some clients (For example
-- "%d m"), so build the short duration ourselves instead of showing the
-- pattern or formatting the raw seconds into it.
local function FormatDurationAbbrev(seconds)
	seconds = tonumber(seconds)
	if not seconds or seconds < 0 then return "" end
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		local hours = math.floor(seconds / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		if minutes > 0 then return string.format("%dh %dm", hours, minutes) end
		return string.format("%dh", hours)
	elseif seconds >= 60 then
		return string.format("%dm", math.floor(seconds / 60))
	end
	return string.format("%ds", seconds)
end

local function SetLabelFormat(name, starttime, endtime, fmt)
	fmt = fmt or Skada.db.profile.setformat
	local namelabel = name
	if fmt < 1 or fmt > numsetfmts then fmt = 3 end
	local timelabel = ""
	if starttime and endtime and fmt > 1 then
		local duration = FormatDurationAbbrev(endtime - starttime)
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
	if type(set) ~= "table" then return "" end

	local name = "Unknown"
	local rawName = set.name
	if issecretvalue(rawName) then
		-- Names can be secret in combat. Do not run string/format operations
		-- that need a plain string on them.
		return "Combat"
	elseif type(rawName) == "string" then
		name = rawName
	end

	-- Prefer the encounter name (e.g. "Hogger") when the Native API provides one.
	local encounter = set.encounterName
	if not issecretvalue(encounter) and type(encounter) == "string" and encounter ~= "" then
		name = encounter
	end

	-- Native API sessions expose durationSeconds instead of start/end times.
	local duration = set.durationSeconds
	if type(duration) == "number" and not issecretvalue(duration) and duration > 0 then
		local durationText = FormatDurationAbbrev(duration)
		if type(durationText) == "string" and #durationText > 0 then
			local startedAt = set.startedAt
			if type(startedAt) == "number" and not issecretvalue(startedAt) then
				return name .. " " .. date("%H:%M", startedAt) .. " (" .. durationText .. ")"
			end
			return name .. " (" .. durationText .. ")"
		end
	end

	-- Handle Native API session fields (capital T)
	local startTime = set.startTime or set.starttime
	local endTime = set.endTime or set.endtime or time()

	return SetLabelFormat(name, startTime, endTime)
end

function Window:set_mode_title()
	if not self.selectedmode or not self.selectedset then return end
	local name = tostring(self.selectedmode.title or self.selectedmode:GetName())

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
			-- Append encounter name if the Native API session has one.
			-- Use type() to avoid crashing on secret values during combat.
			local set = self:get_selected_set()
			local encounter = set and set.encounterName
			if not issecretvalue(encounter) and type(encounter) == "string" and encounter ~= "" then
				setname = setname .. " (" .. encounter .. ")"
			end
		elseif self.selectedset == "total" then
			setname = L["Total"]
			local set = self:get_selected_set()
			local encounter = set and set.encounterName
			if not issecretvalue(encounter) and type(encounter) == "string" and encounter ~= "" then
				setname = setname .. " (" .. encounter .. ")"
			end
		else
			local set = self:get_selected_set()
			if set then
				setname = Skada:GetSetLabel(set)
			end
		end
	if setname then
		name = tostring(name) .. ": " .. tostring(setname)
	end
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
	self._drillSource = nil
	self._drillSourceGUID = nil
	self._drillSourceCreatureID = nil

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
	self._drillSource = nil
	self._drillSourceGUID = nil
	self._drillSourceCreatureID = nil

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
	self._drillSource = nil
	self._drillSourceGUID = nil
	self._drillSourceCreatureID = nil
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
		db.buttons = { menu = true, reset = true, report = true, mode = true, segment = true }
	end
	if not db.scale then
		db.scale = 1
	end
	if db.smoothing == nil then
		db.smoothing = true
	end
	if db.animaterows == nil then
		db.animaterows = true
	end

	if not db.version then
		-- On changes that needs updates to window data structure, increment version in defaults and handle it after this bit.
		db.version = 1
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

function Skada:DuplicateWindow(name)
	local source
	for _, win in ipairs(windows) do
		if win.db.name == name then source = win; break end
	end
	if not source then return end

	local used = {}
	for _, win in ipairs(windows) do used[win.db.name] = true end
	local base = name .. " copy"
	local newName = base
	local n = 2
	while used[newName] do
		newName = base .. " " .. n
		n = n + 1
	end

	local db = {}
	self:tcopy(db, source.db)
	db.name = newName
	db.hidden = false
	db.x = (db.x or 0) + 24
	db.y = (db.y or 0) - 24
	tinsert(self.db.profile.windows, db)
	self:CreateWindow(newName, db)
	if self.settingsUI and self.settingsUI.section == "windows" then
		self.settingsUI:SelectWindow(newName)
	end
	return newName
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

local function describeSession(set)
	if type(set) ~= "table" then return "none" end
	if issecretvalue(set) then return "secret" end
	local name, sources
	pcall(function()
		name = set.name or set.encounterName
		sources = set.combatSources
	end)
	local count = "?"
	if type(sources) == "table" then
		if issecretvalue(sources) then
			count = "secret"
		else
			local ok, n = pcall(function() return #sources end)
			count = ok and tostring(n) or "?"
		end
	else
		count = "none"
	end
	return (type(name) == "string" and name or "unnamed") .. " sources=" .. count
end

function Skada:DumpDeathsDiagnostics()
	self:Print("Death session diagnostics:")
	local win = windows and windows[1]
	local set = win and win:get_selected_set()
	if set and type(set) == "table" and not issecretvalue(set) then
		self:Print("Selected set: sessionType=" .. tostring(set.sessionType) .. " sessionID=" .. tostring(set.sessionID))
	else
		self:Print("Selected set: unavailable/secret")
	end

	local function describe(view)
		if type(view) ~= "table" then return tostring(view) end
		if issecretvalue(view) then return "secret" end
		local sources = view.combatSources
		if type(sources) ~= "table" then return "sources=" .. type(sources) end
		if issecretvalue(sources) then return "sources=secret" end
		local n = #sources
		local first = n > 0 and sources[1]
		local fields = ""
		if type(first) == "table" and not issecretvalue(first) then
			local keys = {}
			for k in pairs(first) do keys[#keys + 1] = tostring(k) end
			fields = " firstFields=" .. table.concat(keys, ",")
			if not issecretvalue(first.deathRecapID) then
				fields = fields .. " recap=" .. tostring(first.deathRecapID)
			end
		end
		return "sources=" .. tostring(n) .. fields
	end

	for _, sessionType in ipairs({1, 2, 0}) do
		local ok, view = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, 9)
		self:Print("Type " .. sessionType .. ": " .. (ok and describe(view) or ("error " .. tostring(view))))
	end
	if set and type(set) == "table" and not issecretvalue(set) and set.sessionID then
		local ok, view = pcall(C_DamageMeter.GetCombatSessionFromID, set.sessionID, 9)
		self:Print("ID " .. tostring(set.sessionID) .. ": " .. (ok and describe(view) or ("error " .. tostring(view))))
	end
	local recent = _G.C_DeathRecap and _G.C_DeathRecap.GetMostRecentDeathRecap
	if recent then
		local ok, id = pcall(recent)
		self:Print("Most recent recap: " .. (ok and tostring(id) or "error"))
	end
end

local function spellValueKind(value)
	if value == nil then return "nil" end
	if issecretvalue(value) then return "secret" end
	return type(value)
end

function Skada:DumpSpellDiagnostics()
	local win = self:GetWindows()[1]
	if not win then
		self:Print("Spell diagnostics: no window")
		return
	end
	local set = win:get_selected_set()
	local mode = win.selectedmode
	local playerID = mode and mode.playerid
	self:Print("Spell diagnostics:")
	self:Print("  window set: " .. tostring(win.selectedset))
	self:Print("  resolved set: " .. spellValueKind(set))
	if set == nil then return end
	if issecretvalue(set) then
		self:Print("  set is secret; cannot inspect session")
		return
	end
	self:Print("  mode: " .. (mode and tostring(mode:GetName()) or "none"))
	self:Print("  detail player id: " .. spellValueKind(playerID))
	if playerID ~= nil and not issecretvalue(playerID) then
		self:Print("  detail player: " .. tostring(playerID))
	end
	self:Print("  drill source: " .. spellValueKind(win._drillSource))
	self:Print("  drill GUID: " .. spellValueKind(win._drillSourceGUID))
	self:Print("  drill creature ID: " .. spellValueKind(win._drillSourceCreatureID))

	local fields = { "combatSpells", "spells", "abilities", "damageSpells", "healingSpells", "combatSpellDetails" }
	local found = false
	for damageType = 0, 10 do
		local ok, source = pcall(self.NativeAPI.GetSessionSource, self.NativeAPI, win._drillSourceGUID, set, damageType, win._drillSourceCreatureID)
		if ok and source ~= nil then
			found = true
			self:Print("  source type " .. tostring(damageType) .. ": " .. spellValueKind(source))
			if issecretvalue(source) then
				self:Print("    source is secret; spell fields cannot be inspected")
			else
				for _, field in ipairs(fields) do
					local okField, value = pcall(function() return source[field] end)
					if okField and value ~= nil then
						local kind = spellValueKind(value)
						local line = "    " .. field .. ": " .. kind
						if kind == "table" then
							local okCount, count = pcall(function() return #value end)
							if okCount then line = line .. " count=" .. tostring(count) end
							local okKeys, keys = pcall(function()
								local out = {}
								for key, item in pairs(value) do
									if #out >= 8 then break end
									out[#out + 1] = tostring(key) .. ":" .. spellValueKind(item)
								end
								return out
							end)
							if okKeys and #keys > 0 then line = line .. " first={" .. table.concat(keys, ", ") .. "}" end
						end
						self:Print(line)
					end
				end
			end
		end
	end
	if not found then
		self:Print("  no source found for the drill GUID or selected player")
	end
end

function Skada:DumpAPIDiagnostics()
	self:Print("Damage meter diagnostics:")
	if C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable then
		local ok, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
		self:Print("API available: " .. (ok and tostring(available) or "error") .. (reason and (" - " .. tostring(reason)) or ""))
	end
	if _G.IsCombatDataRestricted then
		local ok, restricted = pcall(_G.IsCombatDataRestricted)
		self:Print("Combat data restricted: " .. (ok and tostring(restricted) or "error"))
	end
	local known = self.NativeAPI:GetKnownSessions()
	self:Print("Known event sessions: " .. tostring(#known))
	local sessions = self.NativeAPI:GetAvailableSessions()
	local count = type(sessions) == "table" and (pcall(function() return #sessions end) and #sessions or "?") or 0
	self:Print("Available sessions: " .. tostring(count))
	for i, session in ipairs(sessions) do
		if i > 8 then break end
		local id = session.sessionID
		local name = session.name
		if issecretvalue(id) then id = "<secret>" end
		if issecretvalue(name) then name = "<secret>" end
		self:Print("  " .. tostring(id) .. " - " .. tostring(name or "?"))
	end
	self:Print("Current(1,0): " .. describeSession(self.NativeAPI:GetSessionByParams(1, 0)))
	self:Print("Expired(2,0): " .. describeSession(self.NativeAPI:GetSessionByParams(2, 0)))
	self:Print("Total(0,0): " .. describeSession(self.NativeAPI:GetSessionByParams(0, 0)))
	self:Print("Last current snapshot: " .. describeSession(self.NativeAPI.lastCurrentSession))
	local win = self:GetWindows()[1]
	local available = 0
	if type(sessions) == "table" then
		local ok, count = pcall(function() return #sessions end)
		available = ok and count or 0
	end
	local knownCount = #known
	local summary = table.concat({
		"api=" .. tostring(C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and select(2, pcall(C_DamageMeter.IsDamageMeterAvailable)) or "?"),
		"restricted=" .. tostring(_G.IsCombatDataRestricted and select(2, pcall(_G.IsCombatDataRestricted)) or "?"),
		"available=" .. tostring(available),
		"known=" .. tostring(knownCount),
		"current=" .. describeSession(self.NativeAPI:GetSessionByParams(1, 0)),
		"expired=" .. describeSession(self.NativeAPI:GetSessionByParams(2, 0)),
		"total=" .. describeSession(self.NativeAPI:GetSessionByParams(0, 0)),
		"set=" .. (win and tostring(win.selectedset) or "?"),
		"resolved=" .. (win and describeSession(win:get_selected_set()) or "?"),
	}, " | ")
	self:Print("SUMMARY " .. summary)
	if self.db and self.db.profile then
		self.db.profile.apiDump = summary
		self.db.profile.apiDumpTime = time and time() or nil
	end
	for _, win in ipairs(self:GetWindows()) do
		self:Print("Window " .. tostring(win.db.name) .. " set=" .. tostring(win.selectedset) .. " resolved=" .. describeSession(win:get_selected_set()))
	end
end


function Skada:RecordDisplayError(context, err)
	local text = tostring(context or "Display") .. ": " .. tostring(err)
	if self.db and self.db.profile then
		self.db.profile.lastError = text
		self.db.profile.lastErrorTime = time and time() or nil
	end
	if not self._displayErrorShown then
		self._displayErrorShown = true
		self:Print("Display error - " .. text)
	end
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
	if param == "api" then
		Skada:DumpAPIDiagnostics()
		return
	end
	if param == "deaths" then
		Skada:DumpDeathsDiagnostics()
		return
	end
	if param == "spells" then
		Skada:DumpSpellDiagnostics()
		return
	end
	if param == "summary" then
		local win = windows and windows[1]
		Skada:ShowCombatSummary(win and win:get_selected_set())
		return
	end

	if param == "cpu" then
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
		Skada:Print(("%-20s"):format("/skada config"))
	end
end

function Skada:GetChatChannelChoices()
	return {
		{ key = "say", label = L["Say"], chantype = "preset" },
		{ key = "party", label = L["Party"], chantype = "preset" },
		{ key = "raid", label = L["Raid"], chantype = "preset" },
		{ key = "instance_chat", label = L["Instance"], chantype = "preset" },
		{ key = "guild", label = L["Guild"], chantype = "preset" },
		{ key = "officer", label = L["Officer"], chantype = "preset" },
		{ key = "whisper", label = L["Whisper"], chantype = "whisper", needsTarget = true },
		{ key = "target", label = L["Whisper Target"], chantype = "whisper" },
		{ key = "bnet", label = BATTLENET_OPTIONS_LABEL or L["Battle.net"], chantype = "bnet", needsTarget = true },
		{ key = "self", label = L["Self"], chantype = "self" },
	}
end

function Skada:ResolveChatChannel(key, target)
	local choice
	for _, entry in ipairs(self:GetChatChannelChoices()) do
		if entry.key == key then choice = entry; break end
	end
	if not choice then return nil end
	local channel = key
	if key == "target" then
		if not UnitExists("target") then return nil end
		local toon, realm = UnitName("target")
		if not toon then return nil end
		channel = realm and #realm > 0 and (toon .. "-" .. realm) or toon
	elseif key == "whisper" then
		channel = target and strtrim(target) or nil
		if not channel or #channel == 0 then return nil end
	elseif key == "bnet" then
		channel = target and strtrim(target) or nil
		if not channel or #channel == 0 then return nil end
		if BNet_GetBNetIDAccount then
			channel = BNet_GetBNetIDAccount(channel) or channel
		end
	elseif key == "self" then
		channel = "self"
	end
	return channel, choice.chantype, choice
end

local function sendchat(msg, chan, chantype)
	if chantype == "self" then
		-- To self.
		Skada:Print(msg)
	elseif chantype == "channel" then
		-- To channel.
		C_ChatInfo.SendChatMessage(msg, "CHANNEL", nil, chan)
	elseif chantype == "preset" then
		-- To a preset channel id (say, guild, etc).
		C_ChatInfo.SendChatMessage(msg, string.upper(chan))
	elseif chantype == "whisper" then
		-- To player.
		C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, chan)
	elseif chantype == "bnet" then
		C_BattleNet.SendWhisper(chan, msg)
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
			local label = data.reportlabel
			if type(label) ~= "string" then
				if type(data.spellid) == "number" then
					label = C_Spell.GetSpellLink(data.spellid)
				end
			end
			if type(label) ~= "string" then
				label = data.label
			end
			if issecretvalue(label) or type(label) ~= "string" then
				label = "?"
			end

			local value = data.valuetext
			if type(value) == "nil" then
				value = data.valueText1
			end
			if issecretvalue(value) or type(value) ~= "string" then
				value = "?"
			end
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

function Skada:SendChatLine(msg, channel, chantype)
	sendchat(msg, channel, chantype)
end

function Skada:ReportToChat(window, key)
	local target = Skada.db.profile.report.target
	local channel, chantype = self:ResolveChatChannel(key, target)
	if not channel then
		self:Print("Error: Whisper target not found")
		return
	end
	local mode, set
	if window and window.selectedmode then
		mode = window.selectedmode:GetName()
		set = window.selectedset or "current"
	else
		mode = self.db.profile.report.mode or L["Damage"]
		set = self.db.profile.report.set or "current"
	end
	local number = self.db.profile.report.number or 10
	self:Report(channel, chantype, mode, set, number, window and window.selectedmode and window or nil)
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





function Skada:ToggleWindow()
	local showing = false
	for i, win in ipairs(windows) do
		if win:IsShown() then
			showing = true
			break
		end
	end

	if showing then
		for i, win in ipairs(windows) do
			win:Hide()
		end
	else
		for i, win in ipairs(windows) do
			if not win.db.hidden then
				win:Show()
			end
		end
	end
	self:UpdateDisplay(true)
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

	self.current = nil

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

	-- Also reset the native damage meter sessions, with re-entry guard
	-- to prevent loop: Reset() -> ResetAllSessions() -> DAMAGE_METER_RESET -> Reset()
	if not self._resetting and self.NativeAPI then
		self._resetting = true
		self.NativeAPI:ResetAllSessions()
		self.NativeAPI:ClearSessionCache()
		self._resetting = nil
	end

	self:UpdateDisplay(true)
end

function Skada:DeleteSet(set)
	-- With Native API, sets are managed by WoW's C_DamageMeter
	-- Individual set deletion not supported
end

function Skada:ReloadSettings()
	if self.db.profile.updatefrequency == nil then
		self.db.profile.updatefrequency = 0.10
	end
	if type(self.db.profile.roledefaults) ~= "table" then
		self.db.profile.roledefaults = { TANK = "", HEALER = "", DAMAGER = "" }
	end
	if not self.db.profile.combatsummaryDefaultMigrated then
		self.db.profile.showcombatsummary = false
		self.db.profile.combatsummaryDefaultMigrated = true
	end
	if self.db.profile.combatsummaryscope == nil then
		self.db.profile.combatsummaryscope = "boss"
	end
	if type(self.db.profile.pullhistory) ~= "table" then
		self.db.profile.pullhistory = {}
	end
	self.lastPullComparison = nil
	-- Delete all existing windows in case of a profile change.
	for i, win in ipairs(windows) do
		win:destroy()
	end
	windows = {}

	-- Re-create windows
	for i, win in ipairs(self.db.profile.windows) do
		self:CreateWindow(win.name, win)
	end
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

	for i, win in ipairs(windows) do
		if (self.db.profile.hidesolo and not IsInGroup()) or (self.db.profile.hidepvp and IsInPVP()) then
			win:Hide()
		else
			if win.db.hidden then
				win:Hide()
			else
				win:Show()
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

function Skada:PLAYER_REGEN_DISABLED()
	self:HideCombatSummary()
end

function Skada:ShouldShowCombatSummary(set)
	local scope = self.db.profile.combatsummaryscope or "boss"
	if scope == "group" then
		return IsInGroup() or IsInInstance()
	elseif scope == "instance" then
		return IsInInstance()
	end
	if not IsInInstance() then return false end
	local encounter = type(set) == "table" and not issecretvalue(set) and set.encounterName or nil
	return not issecretvalue(encounter) and type(encounter) == "string" and encounter ~= ""
end

function Skada:GetPullKey(set)
	if type(set) ~= "table" or issecretvalue(set) then return nil end
	local encounter = set.encounterName
	if issecretvalue(encounter) or type(encounter) ~= "string" or encounter == "" then return nil end
	local _, _, difficultyID = GetInstanceInfo()
	difficultyID = tonumber(difficultyID) or 0
	local groupSize = GetNumGroupMembers() or 1
	if groupSize < 1 then groupSize = 1 end
	return encounter .. "|" .. tostring(difficultyID) .. "|" .. tostring(groupSize)
end

function Skada:GetPullSnapshot(set)
	local key = self:GetPullKey(set)
	if not key then return nil end
	local duration = self:GetSetTime(set)
	if issecretvalue(duration) or type(duration) ~= "number" or duration <= 0 then return nil end
	local MB = self.ModuleBase
	local values = {
		damage = MB:GetSetTotal(set, 0),
		healing = MB:GetSetTotal(set, 2),
		avoidable = MB:GetSetTotal(set, 8),
		damageTaken = MB:GetSetTotal(set, 7),
		interrupts = MB:GetSetTotal(set, 5),
		dispels = MB:GetSetTotal(set, 6),
	}
	for _, value in pairs(values) do
		if issecretvalue(value) or type(value) ~= "number" then return nil end
	end
	local deaths = 0
	local deathView = self.NativeAPI:GetSessionView(set, 9)
	if type(deathView) == "table" and not issecretvalue(deathView)
		and type(deathView.combatSources) == "table" and not issecretvalue(deathView.combatSources) then
		deaths = #deathView.combatSources
	end
	return key, {
		duration = duration,
		damage = values.damage,
		healing = values.healing,
		avoidable = values.avoidable,
		damageTaken = values.damageTaken,
		interrupts = values.interrupts,
		dispels = values.dispels,
		deaths = deaths,
		at = time(),
	}
end

function Skada:GetLastPull(set)
	local key = self:GetPullKey(set)
	if not key then return nil end
	local history = self.db.profile.pullhistory
	local list = type(history) == "table" and history[key] or nil
	return type(list) == "table" and list[#list] or nil
end

function Skada:RecordPull(set)
	local key, snapshot = self:GetPullSnapshot(set)
	if not key or not snapshot then return end
	local history = self.db.profile.pullhistory
	if type(history) ~= "table" then
		history = {}
		self.db.profile.pullhistory = history
	end
	local list = history[key]
	if type(list) ~= "table" then
		list = {}
		history[key] = list
	end
	list[#list + 1] = snapshot
	while #list > 20 do table.remove(list, 1) end
end

function Skada:CapturePullComparison(set)
	local previous = self:GetLastPull(set)
	self:RecordPull(set)
	local key = self:GetPullKey(set)
	if previous and key then
		self.lastPullComparison = { set = set, key = key, previous = previous }
	else
		self.lastPullComparison = nil
	end
end

function Skada:GetPullComparisonForSet(set)
	local pending = self.lastPullComparison
	if not pending then return nil end
	if pending.set == set then return pending.previous end
	if type(set) == "table" and set.sessionType and set.sessionType ~= 1 then return nil end
	if pending.key and self:GetPullKey(set) == pending.key then return pending.previous end
	return nil
end

-- Contextual auto-mode: pick a sensible meter for the player's role when in a
-- group. Solo play stays on Damage rather than assuming the role is relevant.
function Skada:GetAutoModeName()
	local role = _G.UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "NONE"
	local key = (role == "HEALER" and "HEALER") or (role == "TANK" and "TANK") or "DAMAGER"
	local defaults = self.db.profile.roledefaults
	local configured = defaults and defaults[key]
	if (IsInGroup() or IsInRaid()) and type(configured) == "string" and configured ~= "" then
		local mode = find_mode(configured)
		if mode then return mode:GetName() end
	end
	if (IsInGroup() or IsInRaid()) and key == "HEALER" then
		return L["Healing"]
	elseif (IsInGroup() or IsInRaid()) and key == "TANK" then
		return L["Damage Taken"]
	end
	return L["Damage"]
end

-- DPS/HPS were redundant once Damage/Healing gained rate columns. Redirect
-- saved old mode choices to the consolidated modes.
function Skada:ApplyModeConsolidation()
	if self.db.profile.modesConsolidated then return end
	self.db.profile.modesConsolidated = true
	for _, win in ipairs(self:GetWindows()) do
		if win.db.mode == L["DPS"] then
			win.db.mode = L["Damage"]
		elseif win.db.mode == L["HPS"] then
			win.db.mode = L["Healing"]
		end
		if win.db.modeincombat == L["DPS"] then
			win.db.modeincombat = L["Damage"]
		elseif win.db.modeincombat == L["HPS"] then
			win.db.modeincombat = L["Healing"]
		end
		if win.db.wipemode == L["DPS"] then
			win.db.wipemode = L["Damage"]
		elseif win.db.wipemode == L["HPS"] then
			win.db.wipemode = L["Healing"]
		end
		-- Existing profiles that never opted into a specific combat mode get
		-- the new contextual default once.
		if win.db.modeincombat == "" then
			win.db.modeincombat = "auto"
		end
	end
end

-- Main tick function: handles combat transitions and display updates.
-- Replaces the old OnCombatStart/OnCombatEnd + 6 event handler approach.
function Skada:Tick()
	if self.NativeAPI then self.NativeAPI:BeginTick() end
	-- Simulation mode: generate mock data and update
	if self.Simulation and self.Simulation.active then
		self.Simulation:Update()
		self:UpdateDisplay(true)
		return
	end

	local inCombat = InCombatLockdown()

	-- Detect combat start
	if inCombat and not self.current then
		self:HideCombatSummary()
		self:Wipe()
		self.current = { name = "Current", sessionType = 1 }

		for i, win in ipairs(windows) do
			if win.db.returnaftercombat then
				win.restore_set = win.selectedset
				win.restore_mode = win.selectedmode and win.selectedmode:GetName()
			end
			-- Do not force the segment to Current. A user explicitly viewing
			-- Total or a historical segment should keep that segment through
			-- combat; only an empty selection falls back to Current.
			if not win.selectedset then
				win.selectedset = "current"
			end
			local combatMode = win.db.modeincombat
			if combatMode == "auto" then
				combatMode = self:GetAutoModeName()
			end
			if combatMode and combatMode ~= "" then
				local mymode = find_mode(combatMode)
				if mymode then
					win:DisplayMode(mymode)
				end
			elseif win.selectedmode then
				win.changed = true
			end
			if not win.db.hidden and self.db.profile.hidecombat then
				win:Hide()
			end
		end
		changed = true
	end

	-- Detect combat end
	if not inCombat and self.current then
		local summarySet = self.NativeAPI:GetSessionView(self.current, 0)
		if summarySet then
			self:CapturePullComparison(summarySet)
		end
		self.last = self.current
		self.current = nil

		for i, win in ipairs(windows) do
			if win.db.returnaftercombat and win.restore_mode and win.restore_set then
				self:RestoreView(win, win.restore_set, win.restore_mode)
				win.restore_mode = nil
				win.restore_set = nil
			end
			if not win.db.hidden and self.db.profile.hidecombat and (not self.db.profile.hidesolo or IsInGroup()) then
				win:Show()
			end
		end
		if self.db.profile.showcombatsummary and summarySet and self:ShouldShowCombatSummary(summarySet) then
			self:ShowCombatSummary(summarySet)
		end
		changed = true
	end

	-- Always update: the set list view needs to pick up sessions that load after
	-- the initial render, and the per-window guard in UpdateDisplay prevents
	-- unnecessary rebuilds for mode views that haven't changed.
	self:UpdateDisplay(inCombat or changed)
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

local function sessionHasSources(set)
	if type(set) ~= "table" then return false end
	-- A secret session cannot be inspected safely; return it and let the
	-- display path handle or suppress it.
	if issecretvalue(set) then return true end
	local sources = set.combatSources
	if type(sources) ~= "table" or issecretvalue(sources) then return false end
	return #sources > 0
end

function Skada:find_set(s)
	if s == "current" then
		local set = self.NativeAPI:GetCurrentSession()
		if sessionHasSources(set) then
			pcall(function() set.sessionType = 1 end)
			return set
		end

		-- The Current query can be empty or nil at a combat boundary. Try the
		-- Expired session, then the newest tracked historical session, then the
		-- last snapshot observed from the native API.
		local expired = self.NativeAPI:GetSessionByParams(2, 0)
		if sessionHasSources(expired) then
			pcall(function() expired.sessionType = 2 end)
			return expired
		end

		local sessions = self.NativeAPI:GetAvailableSessions()
		if type(sessions) == "table" then
			for i = #sessions, 1, -1 do
				local available = sessions[i]
				if type(available) == "table" and available.sessionID then
					local byid = self.NativeAPI:GetSessionByID(available.sessionID, 0)
					if sessionHasSources(byid) then return byid end
				end
			end
		end

		if sessionHasSources(self.NativeAPI.lastCurrentSession) then
			local last = self.NativeAPI.lastCurrentSession
			pcall(function() last.sessionType = 1 end)
			return last
		end

		if self.NativeAPI.lastKnownSessionID then
			local lastKnown = self.NativeAPI:GetSessionByID(self.NativeAPI.lastKnownSessionID, self.NativeAPI.lastKnownDamageType or 0)
			if sessionHasSources(lastKnown) then return lastKnown end
		end

		local total = self.NativeAPI:GetTotalSession()
		if sessionHasSources(total) then
			pcall(function() total.sessionType = 0 end)
			return total
		end

		self:Debug("find_set('current') has no populated session")
		return set or self.current
	elseif s == "total" then
		local set = self.NativeAPI:GetTotalSession()
		if type(set) == "table" then
			self.total = set
			pcall(function() set.sessionType = 0 end)
		end
		return set
	elseif type(s) == "number" then
		return self.NativeAPI:GetSessionByID(s)
	elseif type(s) == "string" and tonumber(s) then
		return self.NativeAPI:GetSessionByID(tonumber(s))
	end
	return s
end

-- Helper to find player in Native API session
function Skada:find_player_in_session(session, playerGUID)
	if type(session) ~= "table" or type(playerGUID) == "nil" then return nil end
	if issecretvalue(session) then return nil end
	local sources = session.combatSources
	if type(sources) ~= "table" then
		sources = session.participants
	end
	if type(sources) ~= "table" or issecretvalue(sources) then return nil end

	local idType = type(playerGUID)
	local idIsSecret = issecretvalue(playerGUID)

	-- Handle artificial combat IDs
	if idType == "string" and not idIsSecret and (playerGUID:sub(1, 7) == "combat_" or playerGUID:sub(1, 7) == "player_") then
		local index = tonumber(playerGUID:sub(8))
		if index then
			local nr = 1
			for _, p in ipairs(sources) do
				if nr == index then return p end
				nr = nr + 1
			end
		end
		return nil
	end

	-- Use pcall for any lookup that may involve a secret GUID. Comparing a
	-- plain value with a secret value throws, so the source GUID must be
	-- checked before the direct fast path.
	for k, p in pairs(sources) do
		if type(p) == "table" and not issecretvalue(p) then
			local needsPcall = idIsSecret or issecretvalue(p.sourceGUID)
			if needsPcall then
				local success, matches = pcall(function()
					return (p.sourceGUID == playerGUID) or (k == playerGUID) or (p.guid == playerGUID) or (p.unitGUID == playerGUID) or (p.id == playerGUID)
				end)
				if success and matches then
					return p
				end
			elseif (p.sourceGUID == playerGUID) or (k == playerGUID) or (p.guid == playerGUID) or (p.unitGUID == playerGUID) or (p.id == playerGUID) then
				return p
			end
		end
	end
	-- The player's own GUID is normally plain even when other source GUIDs are
	-- secret. Fall back to isLocalPlayer (NeverSecret) for self lookups so the
	-- personal DPS/HPS feed keeps working in combat.
	local selfGUID = UnitGUID("player")
	if type(selfGUID) == "string" and not issecretvalue(selfGUID) and not issecretvalue(playerGUID) and playerGUID == selfGUID then
		for _, p in ipairs(sources) do
			if type(p) == "table" and not issecretvalue(p) and p.isLocalPlayer == true then
				return p
			end
		end
	end

	return nil
end

-- Alias for backward compatibility
function Skada:find_player(set, playerGUID)
	return self:find_player_in_session(set, playerGUID)
end

-- Native API Event Handlers — invalidate any cached session snapshots so the
-- next Tick() reads fresh data, then flag that data changed.
-- The Tick() timer handles combat transitions and display updates.
function Skada:DAMAGE_METER_COMBAT_SESSION_UPDATED(event, damageType, sessionID)
	-- AceEvent passes the event name as the first argument.
	if self.NativeAPI then
		self.NativeAPI:TrackSession(sessionID, damageType)
		self.NativeAPI:InvalidateCache()
	end
	changed = true
end

function Skada:DAMAGE_METER_CURRENT_SESSION_UPDATED()
	if self.NativeAPI then self.NativeAPI:InvalidateCache() end
	changed = true
end

function Skada:DAMAGE_METER_RESET()
	-- This event can come from another addon or Blizzard's own meter. Clear
	-- Skada's state, but do not call ResetAllCombatSessions a second time:
	-- a duplicate native reset can leave the native meter unable to attribute
	-- damage until the UI is reloaded.
	if self._resetting then return end
	if self.NativeAPI then self.NativeAPI:ClearSessionCache() end
	self._resetting = true
	self:Reset()
	self._resetting = nil
end

-- Helper for conditional reset (No=1, Yes=2, Ask=3)
local function check_reset(setting)
	if setting == 2 then
		Skada:Reset()
	elseif setting == 3 then
		Skada:ShowPopup()
	end
end

function Skada:GROUP_ROSTER_UPDATE()
	local wasInGroup = self._wasInGroup
	local inGroup = IsInGroup()
	self._wasInGroup = inGroup

	-- Skip the initial call (state not yet established)
	if wasInGroup == nil then return end

	local transitioned = wasInGroup ~= inGroup
	if not wasInGroup and inGroup then
		-- Joined a group
		check_reset(self.db.profile.reset.join)
	elseif wasInGroup and not inGroup then
		-- Left a group
		check_reset(self.db.profile.reset.leave)
	end

	if transitioned and self.NativeAPI then
		self.NativeAPI.lastCurrentSession = nil
		self.NativeAPI:InvalidateCache()
		changed = true
	end

	-- Re-apply visibility (handles hidesolo)
	self:ApplySettings()

	-- GROUP_ROSTER_UPDATE can arrive before the group state and native
	-- sessions have fully settled. Re-run once after the transition so a
	-- hidesolo window or a stale current session does not require /reload.
	if transitioned and _G.C_Timer and _G.C_Timer.After then
		_G.C_Timer.After(0.25, function()
			if not Skada or not Skada.db then return end
			if Skada.NativeAPI then
				Skada.NativeAPI.lastCurrentSession = nil
				Skada.NativeAPI:InvalidateCache()
			end
			changed = true
			Skada:ApplySettings()
			Skada:UpdateDisplay(true)
		end)
	end
end

function Skada:ZONE_CHANGED_NEW_AREA()
	local wasInInstance = self._wasInInstance
	local inInstance = IsInInstance()
	self._wasInInstance = inInstance

	-- Skip the initial call (state not yet established)
	if wasInInstance == nil then return end

	if not wasInInstance and inInstance then
		-- Entered an instance
		check_reset(self.db.profile.reset.instance)
	end
end


--
-- Data broker
--

function dataobj:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()

	local set = Skada:GetActiveSet()
	if type(set) == "table" then
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
		-- Update window if forced, if window state changed, if in combat (to refresh bars/feeds),
		-- or if showing the set list (which must re-query available sessions every tick).
		if changed or win.changed or self.current or (not win.selectedmode and not win.selectedset) then
			win.changed = false
			if win.selectedmode then -- Force mode display for display systems which do not handle navigation.
				win:set_mode_title()
				local set = win:get_selected_set()

				if set then
					-- Inform window that a data update will take place.
					win:UpdateInProgress()

				-- Let mode update data.
				if win.selectedmode.Update then
					local ok, err = pcall(win.selectedmode.Update, win.selectedmode, win, set)
					if not ok then
						if self.db.profile.debug then
							self:Debug("Mode Update Error:", win.selectedmode:GetName(), err)
						end
						self:RecordDisplayError("Mode update in " .. tostring(win.selectedmode:GetName()), err)
					end
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
						-- The entry may have been reused from another mode/view.
						-- Clear stale columns before the summary fills the ones it owns.
						d.valuetext = nil
						d.valueText1 = nil
						d.valueText2 = nil
						d.valueText3 = nil
						-- Total is not a player: never inherit a class color/icon.
						d.class = nil
						d.role = nil
						d.color = nil
						d.spellschool = nil
						win.selectedmode:FormatSetSummary(d, set)
						d.value = total
						d.label = L["Total"]
						d.icon = win.db.totalicon or dataobj.icon
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
					if not success then
						if Skada.db.profile.debug then
							Skada:Debug("Display Update Error (Inside Mode):", err)
						end
						self:RecordDisplayError("Display update", err)
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
						Skada:Debug("  Set Name:", issecretvalue(set.name) and "<secret>" or tostring(set.name or "Current/Unknown"))
						local sourceCount = 0
						if type(set.combatSources) == "table" and not issecretvalue(set.combatSources) then
							sourceCount = #set.combatSources
						end
						Skada:Debug("  Sources count:", sourceCount)
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
				for i, set in ipairs(self:GetSets()) do
					nr = nr + 1
					d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = set.sessionID or set.startTime or i
					d.label = self:GetSetLabel(set)
					d.value = 1
					local encounter = set.encounterName
					if set.gotboss or (not issecretvalue(encounter) and type(encounter) == "string" and encounter ~= "") then
						d.icon = bossicon
					else
						d.icon = nonbossicon
					end
				end

				-- Clear stale entries beyond the current set list so removed
				-- sessions don't leave orphan bars.
				for i = nr + 1, #win.dataset do
					if win.dataset[i] then
						win.dataset[i].id = nil
					end
				end

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
	if self.NativeAPI then
		return self.NativeAPI:GetAvailableSessions()
	end
	return {}
end

-- One-time Forever theme migration. It only replaces the old out-of-box
-- window look, never a user's custom theme.
-- Migrate the old Skyborne display title (Cinzel 14) to the current default
-- (Expressway 13). Only windows still using the Skyborne Forever assets are
-- touched; custom title fonts and other presets are preserved.
function Skada:ApplyTitleFontMigration()
	if self.db.profile.titleFontMigrated then return 0 end
	self.db.profile.titleFontMigrated = true
	local migrated = 0
	for _, win in ipairs(self:GetWindows()) do
		local title = win.db.title
		if title and title.font == "Cinzel" and title.fontsize == 14
			and win.db.bartexture == "Forever Bar" and title.texture == "Forever Bar" then
			title.font = "Expressway"
			title.fontsize = 13
			migrated = migrated + 1
		end
	end
	return migrated
end

function Skada:ApplyThemeMigration()
	if self.db.profile.themeMigrated then
		return 0
	end
	self.db.profile.themeMigrated = true

	local preset
	for _, theme in ipairs(self.themePresets or {}) do
		if theme.name == "Forever: Skyborne" then
			preset = theme
			break
		end
	end
	if not preset then return 0 end

	local migrated = 0
	for _, win in ipairs(self:GetWindows()) do
		-- Only the old out-of-box look is replaced. Custom themes and windows
		-- already using Skyborne are left alone.
		if win.db.bartexture == "Skada Glass" and win.db.barwidth == 260 then
			self:ApplyThemeToWindow(win, preset)
			migrated = migrated + 1
		end
	end
	return migrated
end

-- Return the Native API session for the current fight, or the overall session
-- when no fight is active. Skada.current is only a lightweight state marker.
function Skada:GetActiveSet()
	if self.NativeAPI then
		if self.current then
			local set = self.NativeAPI:GetCurrentSession()
			if type(set) == "table" then
				return set
			end
			return self.current
		end
		return self.NativeAPI:GetTotalSession()
	end
	return self.current or self.total
end

function Skada:GetModes(sortfunc)
	return modes
end

-- Formats a number into human readable form.
-- Adds thousands separators to a non-negative integer for the "Detailed" format.
local function GroupThousands(n)
	n = math.floor(n)
	if n < 1000 then return tostring(n) end
	local formatted = ""
	while n >= 1000 do
		formatted = string.format(",%03d", n % 1000) .. formatted
		n = math.floor(n / 1000)
	end
	return tostring(n) .. formatted
end

function Skada:FormatNumber(number)
	-- Check for secret values before any nil/zero comparison.
	if issecretvalue(number) then
		-- Secret values should be formatted with FormatNumberSecret, not here.
		return "?"
	end
	if number == nil then return "" end

	-- Now it is safe to perform comparisons
	if number == 0 then return "" end

	if self.db.profile.numberformat == 1 then
		-- Condensed format (K/M/B)
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
		return tostring(math.floor(number))
	elseif self.db.profile.numberformat == 2 then
		-- Detailed format: full number with thousands separators
		return GroupThousands(number)
	end
	
	return tostring(math.floor(number))
end

-- Format a number that may be a WoW 12.0 secret value.
function Skada:FormatNumberSecret(number)
	-- For secret values, use string.format with %.0f for clean whole numbers
	if issecretvalue(number) then
		-- string.format is safe for secret values
		local s = string.format("%.0f", number)
		return tostring(s)
	end
	-- For normal values, use regular formatting
	return self:FormatNumber(number)
end

-- Safely converts a value to a number, handling nil values and "secret values" from Native API.
function Skada:SafeNumber(value)
	if issecretvalue(value) then return 0 end
	if type(value) ~= "number" then return 0 end
	return value
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
	for i = 1, #modes do
		if modes[i] == mode then
			tremove(modes, i)
			return
		end
	end
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
	feeds[name] = nil
end

--[[

Sets

--]]

function Skada:GetSetTime(set)
	if type(set) ~= "table" then return 0 end

	-- Native API sessions expose durationSeconds. This value may be secret
	-- during combat; return it as-is and let the caller format it safely.
	local duration = set.durationSeconds
	if issecretvalue(duration) then
		return duration
	elseif type(duration) == "number" then
		return duration
	end

	-- Older/legacy session structures
	if set.startTime then
		if set.endTime then
			-- Session has ended, return duration
			return (set.endTime - set.startTime)
		else
			-- Session is still active, return current duration
			return (time() - set.startTime)
		end
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
	if Skada:SafeNumber(player.totalAmount) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.healing) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.damageTaken) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.dispels) > 0 then
		hasActivity = true
	elseif Skada:SafeNumber(player.interrupts) > 0 then
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

local SafeNumber = Skada.SafeNumber
local function value_sort(a, b)
	if type(a) ~= "table" or a.id == nil then
		return false
	elseif type(b) ~= "table" or b.id == nil then
		return true
	elseif issecretvalue(a.value) or issecretvalue(b.value) then
		-- Bar values are normally replaced with synthetic order values while
		-- data is secret, but never compare the real secret value.
		return (a.order or 0) < (b.order or 0)
	elseif a.value == nil then
		return false
	elseif b.value == nil then
		return true
	else
		return SafeNumber(Skada, a.value) > SafeNumber(Skada, b.value)
	end
end
Skada.value_sort = value_sort

function Skada.valueid_sort(a, b)
	if type(a) ~= "table" or a.id == nil or issecretvalue(a.value) then
		return false
	elseif type(b) ~= "table" or b.id == nil or issecretvalue(b.value) then
		return true
	elseif a.value == nil then
		return false
	elseif b.value == nil then
		return true
	else
		-- Use Skada:SafeNumber for numeric comparison
		return Skada:SafeNumber(a.value) > Skada:SafeNumber(b.value)
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
					color = Skada.classcolors[data.class] or white
				end

				local label = data.label
				local secretLabel = issecretvalue(label)
				if not secretLabel and mode.metadata and mode.metadata.showspots then
					label = nr .. ". " .. label
				end

				local right = data.valuetext
				if type(right) ~= "string" then
					right = data.valueText1
					if type(right) ~= "string" then right = "" end
				end
				if not secretLabel then
					tooltip:AddDoubleLine(label, right, color.r, color.g, color.b)
				else
					local ok = pcall(tooltip.AddDoubleLine, tooltip, label, right, color.r, color.g, color.b)
					if not ok then pcall(tooltip.AddLine, tooltip, label, color.r, color.g, color.b) end
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

-- Pre-allocated border backdrop table (reused per call)
local borderbackdrop = {}

-- Generic border
function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	wipe(borderbackdrop)
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

			opacity = {
				type = "range",
				name = L["Opacity"],
				desc = L["The opacity of the background."],
				min = 0,
				max = 1,
				step = 0.01,
				isPercent = true,
				get = function() return db.background.color.a end,
				set = function(win, val)
					db.background.color.a = val
					Skada:ApplySettings()
				end,
				order = 1.5
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
	media:Register("font", "Cinzel", [[Interface\Addons\Skada\media\fonts\Cinzel-SemiBold.ttf]])
	media:Register("font", "Marcellus", [[Interface\Addons\Skada\media\fonts\Marcellus-Regular.ttf]])

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
	media:Register("statusbar", "Skada Modern", [[Interface\Addons\Skada\media\statusbar\SkadaModern]])
	media:Register("statusbar", "Skada Glass", [[Interface\Addons\Skada\media\statusbar\SkadaGlass]])
	media:Register("statusbar", "Skada Material", [[Interface\Addons\Skada\media\statusbar\SkadaMaterial]])
	media:Register("border", "Glow", [[Interface\Addons\Skada\media\border\glowTex]])
	media:Register("border", "Roth", [[Interface\Addons\Skada\media\border\roth]])
	media:Register("background", "Copper", [[Interface\Addons\Skada\media\background\copper]])
	media:Register("border", "Forever Line", [[Interface\Addons\Skada\media\border\ForeverLine.tga]])
	media:Register("statusbar", "Forever Bar", [[Interface\Addons\Skada\media\statusbar\ForeverBar.tga]])

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
	-- Dual spec database enhancement is backend-only; the old AceDBOptions
	-- profile page has been replaced by Skada's own Profiles page.
	if lds then
		lds:EnhanceDatabase(self.db, "SkadaDB")
	end

	-- Slash Handler
	SLASH_SKADA1 = "/skada"
	SlashCmdList.SKADA = slashHandler

	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")
	-- ClearAllIndexes callback removed - method doesn't exist



	self:SetNotifyIcon("Interface\\Icons\\Spell_Lightning_LightningBolt01")
	self:SetNotifyStorage(self.db.profile.versions)
	self:NotifyOnce(self.versions)
	if self.SetupSettingsCategory then
		self:SetupSettingsCategory()
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

	self:ApplyThemeMigration()
	self:ApplyTitleFontMigration()
	self:ApplyModeConsolidation()

	-- Register for native damage meter events (just flag data as changed)
	self:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	self:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	self:RegisterEvent("DAMAGE_METER_RESET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")

	-- Test session types to find correct values
	self.NativeAPI:TestSessionTypes()

	-- Single repeating timer handles combat transitions, simulation, and display updates
	self.tickTimer = self:ScheduleRepeatingTimer("Tick", self.db.profile.updatefrequency or 0.10)

	-- Group and zone change events for data reset triggers
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	-- Initialize group/instance state so first transition is detected correctly
	self._wasInGroup = IsInGroup()
	self._wasInInstance = IsInInstance()

	-- Register callback for SharedMedia to re-apply settings when new media is registered
	media.RegisterCallback(self, "LibSharedMedia_Registered", "OnMediaRegistered")
end

function Skada:OnMediaRegistered(event, mediaType, key)
	-- Re-apply settings when new media is registered to ensure fonts/textures are updated
	self:ApplySettings()
end

-- Reschedule the Tick timer when the user changes updatefrequency in Options.
-- Without this the new value only took effect after /reload.
function Skada:ApplyUpdateFrequency()
	if self.tickTimer then
		self:CancelTimer(self.tickTimer)
		self.tickTimer = nil
	end
	self.tickTimer = self:ScheduleRepeatingTimer("Tick", self.db.profile.updatefrequency or 0.10)
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