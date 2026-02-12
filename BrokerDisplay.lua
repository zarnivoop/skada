-- LDB data object with an optional internal frame.
local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

local name = L["Data text"]
local mod = Skada:NewModule(name)
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")

local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

mod.name = name
mod.description = L["Data text acts as an LDB data feed. It can be integrated in any LDB display such as Titan Panel or ChocolateBar. It also has an optional internal frame."]
Skada:AddDisplaySystem("broker", mod)

local function sortDataset(win)
	table.sort(win.dataset, function (a, b)
		if not a or not a.id then
			return false
		elseif not b or not b.id then
			return true
		else
			-- Use Skada:SafeNumber for robust comparison, treating nil/non-numeric as 0.
			-- This ensures nil values are sorted consistently (at the beginning if ascending, end if descending).
			-- The original logic had nil 'a' come after 'b', and nil 'b' come before 'a'.
			-- Skada:SafeNumber(nil) returns 0, so 0 > X is false, X > 0 is true.
			-- This means nil values (0) will appear at the end when sorting descending (a > b).
			-- This matches the original behavior where nil values were pushed to the end.
			return Skada:SafeNumber(a.value) > Skada:SafeNumber(b.value)
		end
	end)
end

local function formatLabel(win, data)
	if not data then return "" end
	if win.db.isusingclasscolors and data.class and RAID_CLASS_COLORS[data.class] then
		return string.format("|c%s%s|r", RAID_CLASS_COLORS[data.class].colorStr, data.label or "")
	else
		return string.format("%s", data.label or "")
	end
end

local function formatValue(win, data)
	if not data then return "" end
	if data.valuetext then
		return string.format("%s", data.valuetext)
	else
		-- Use string.format for multiple parts to support secret values
		if data.valueText1 and data.valueText2 then
			return string.format("%s %s", data.valueText1, data.valueText2)
		else
			return string.format("%s", data.valueText1 or "")
		end
	end
end

local function clickHandler(win, frame, button)
	if not win.obj then
		return
	end

	if button=="LeftButton" and IsShiftKeyDown() then
		Skada:OpenMenu(win)
	elseif button=="LeftButton" then
		Skada:ModeMenu(win)
	elseif button=="RightButton" then
		Skada:SegmentMenu(win)
	end
end

local function tooltipHandler(win, tooltip)
	if win.db.useframe then
		Skada:SetTooltipPosition(tooltip, win.frame)
	end

	-- Default color.
	local color = win.db.textcolor

	tooltip:AddLine(win.metadata.title)
	tooltip:AddLine(" ")

	sortDataset(win)
	if #win.dataset > 0 then
		for i, data in ipairs(win.dataset) do
			if data.id and not data.ignore and i < 30 then
				local label = formatLabel(win, data)
				local value = formatValue(win, data)

				if win.metadata.showspots and Skada.db.profile.showranks then
					label = (("%2u. %s"):format(i, label))
				end

				tooltip:AddDoubleLine(label or "", value or "", color.r, color.g, color.b, color.r, color.g, color.b)

			end
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(L["Hint: Left-Click to set active mode."], 0, 1, 0)
	tooltip:AddLine(L["Right-click to set active set."], 0, 1, 0)
	tooltip:AddLine(L["Shift + Left-Click to open menu."], 0, 1, 0)

	tooltip:Show()
end

local ttactive = false

function mod:Create(win, isnew)
	-- Optional internal frame
	if not win.frame then
		local winName = win.db.name.."BrokerFrame"
		win.frame = CreateFrame("Frame", winName, UIParent, "BackdropTemplate")
		win.frame:SetHeight(win.db.height or 30)
		win.frame:SetWidth(win.db.width or 200)
		win.frame:SetPoint("CENTER", 0, 0)

		-- Register with LibWindow-1.1.
		libwindow.RegisterConfig(win.frame, win.db)

		-- Restore window position.
		if isnew then
			libwindow.SavePosition(win.frame)
		else
			libwindow.RestorePosition(win.frame)
		end

		local title = win.frame:CreateFontString("frameTitle", "OVERLAY", "ChatFontNormal")
		title:SetPoint("CENTER", 0, 0)
		win.frame.title = title

		win.frame:EnableMouse(true)
		win.frame:SetMovable(true)
		win.frame:RegisterForDrag("LeftButton")
		win.frame:SetScript("OnMouseUp", function(frame, button)
			clickHandler(win, frame, button)
		end)
		win.frame:SetScript("OnEnter", function(frame)
			tooltipHandler(win, GameTooltip)
		end)
		win.frame:SetScript("OnLeave", function(frame)
			GameTooltip:Hide()
		end)
		win.frame:SetScript("OnDragStart", function(frame)
			if not win.db.barslocked then
				GameTooltip:Hide()
				frame.isDragging = true
				frame:StartMoving()
			end
		end)
		win.frame:SetScript("OnDragStop", function(frame)
			frame:StopMovingOrSizing()
			frame.isDragging = false
			libwindow.SavePosition(frame)
		end)

	end

	-- LDB object
	if not win.obj then
		win.obj = ldb:NewDataObject('Skada: '..win.db.name, {
			type = "data source",
			text = "",
			OnTooltipShow = function (tooltip)
				tooltipHandler(win, tooltip)
			end,
			OnClick = function(frame, button)
				clickHandler(win, frame, button)
			end
		})
	end

	mod:ApplySettings(win)
end

function mod:IsShown(win)
	return win.frame:IsShown()
end

function mod:Show(win)
	if win.db.useframe then
		win.frame:Show()
	end
end

function mod:Hide(win)
	if win.db.useframe then
		win.frame:Hide()
	end
end

function mod:Destroy(win)
	win.obj.text = " "
	win.obj = nil
	win.frame:Hide()
	win.frame = nil
end

function mod:Wipe(win)
	win.text = " "
end

function mod:SetTitle(win, title)
end

function mod:Update(win)
	if win.obj then
		win.obj.text = ""
	end
	sortDataset(win)
	if #win.dataset > 0 then
		local data = win.dataset[1]
		if data and data.id then
			local labelText = formatLabel(win, data)
			local valueText = formatValue(win, data)
			local fullText = string.format("%s - %s", labelText, valueText)

			if win.obj then
				-- LibDataBroker-1.1 often crashes when setting secret values because it performs
				-- boolean comparisons (old_val ~= new_val) internally.
				pcall(function() win.obj.text = fullText end)
			end
			if win.db.useframe then
				-- FontString:SetText is safe with secret values.
				win.frame.title:SetText(fullText)
			end
		end
	end
end

function mod:OnInitialize()
end

function mod:ApplySettings(win)
	if win.db.useframe then
		local title = win.frame.title
		local db = win.db

		win.frame:SetMovable(not win.db.barslocked)
		win.frame:SetHeight(win.db.height or 30)
		win.frame:SetWidth(win.db.width or 200)
		local fbackdrop = {}
		fbackdrop.bgFile = media:Fetch("background", db.background.texture)
		fbackdrop.tile = db.background.tile
		fbackdrop.tileSize = db.background.tilesize
		win.frame:SetBackdrop(fbackdrop)
		win.frame:SetBackdropColor(db.background.color.r,db.background.color.g,db.background.color.b,db.background.color.a)

		Skada:ApplyBorder(win.frame, db.background.bordertexture, db.background.bordercolor, db.background.borderthickness)

		title:SetTextColor(db.textcolor.r,db.textcolor.g,db.textcolor.b,db.textcolor.a)
		title:SetFont(media:Fetch('font', db.barfont), db.barfontsize, db.barfontflags)
		title:SetText(win.metadata.title or "Skada")
		title:SetWordWrap(false)
		title:SetJustifyH("CENTER")
		title:SetJustifyV("MIDDLE")
		title:SetHeight(win.db.height or 30)

		win.frame:SetScale(db.scale)
		win.frame:SetFrameStrata(db.strata)
	else
		win.frame:Hide()
	end
	self:Update(win)
end

function mod:AddDisplayOptions(win, options)
	local db = win.db
	options.main = {
		type = "group",
		name = "Datatext",
		order = 3,
		args = {

			useframe = {
				type = 'toggle',
				name = "Use frame",
				desc = "Shows a standalone frame. Not needed if you are using an LDB display provider such as Titan Panel or ChocolateBar.",
				get = function() return db.useframe end,
				set = function(win,key)
					db.useframe = key
					Skada:ApplySettings()
				end,
				order=0.0,
			},

			classcolortext = {
					type="toggle",
					name=L["Class color text"],
					desc=L["When possible, bar text will be colored according to player class."],
					order=0.1,
					get=function() return db.isusingclasscolors end,
					set=function()
							db.isusingclasscolors = not db.isusingclasscolors
							Skada:ApplySettings()
						end,
			},
			color = {
				type="color",
				name=L["Text color"],
				desc=L["Choose the default color."],
				hasAlpha=true,
				get=function(i)
						local c = db.textcolor
						return c.r, c.g, c.b, c.a
					end,
				set=function(i, r,g,b,a)
						db.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						Skada:ApplySettings()
					end,
				order=4,
			},

			barfont = {
				type = 'select',
				dialogControl = 'LSM30_Font',
				name = L["Bar font"],
				desc = L["The font used by all bars."],
				values = AceGUIWidgetLSMlists.font,
				get = function() return db.barfont end,
				set = function(win,key)
					db.barfont = key
					Skada:ApplySettings()
				end,
				order=1,
			},

			barfontsize = {
				type="range",
				name=L["Bar font size"],
				desc=L["The font size of all bars."],
				min=7,
				max=40,
				step=1,
				get=function() return db.barfontsize end,
				set=function(win, size)
					db.barfontsize = size
					Skada:ApplySettings()
				end,
				order=2,
			},

			barfontflags = {
				type = 'select',
				name = L["Font flags"],
				desc = L["Sets the font flags."],
				values = {[""] = L["None"], ["OUTLINE"] = L["Outline"], ["THICKOUTLINE"] = L["Thick outline"], ["MONOCHROME"] = L["Monochrome"], ["OUTLINEMONOCHROME"] = L["Outlined monochrome"]},
				get = function() return db.barfontflags end,
				set = function(win,key)
					db.barfontflags = key
					Skada:ApplySettings()
				end,
				order=3,
			},

		}
	}

	options.window = Skada:FrameSettings(db, true)
end
