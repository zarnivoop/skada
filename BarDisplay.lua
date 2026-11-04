--[[

The traditional bar display used in some form by most damage meters.

--]]

local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

-- Aliases
local table_sort = table.sort
local next, pairs, ipairs, type = next, pairs, ipairs, type

--
-- Display implementation.
--

-- Add to Skada's enormous list of display providers.
mod.name = L["Bar display"]
mod.description = L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."]
Skada:AddDisplaySystem("bar", mod)

-- Called when a Skada window starts using this display provider.
function mod:Create(window)
	-- Re-use bargroup if it exists.
	window.bargroup = mod:GetBarGroup(window.db.name)

	-- Save a reference to window in bar group. Needed for some nasty callbacks.
	if window.bargroup then
		-- Clear callbacks.
		window.bargroup.callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(window.bargroup)
	else
		window.bargroup = mod:NewBarGroup(window.db.name, nil, window.db.background.height, window.db.barwidth, window.db.barheight, "SkadaBarWindow"..window.db.name)
		local bargroup = window.bargroup -- ticket 323

		-- Add window buttons.
		window.bargroup:AddButton(L["Configure"], L["Configure description"], "Interface\\Buttons\\UI-OptionsButton", "Interface\\Buttons\\UI-OptionsButton", function() Skada:OpenMenu(bargroup.win) end)
		window.bargroup:AddButton(L["Reset"], L["Reset description"], "Interface\\Buttons\\UI-StopButton", "Interface\\Buttons\\UI-StopButton", function() Skada:ShowPopup() end)
		window.bargroup:AddButton(L["Segment"], L["Segment description"], "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", function() Skada:SegmentMenu(bargroup.win) end)
		window.bargroup:AddButton(L["Mode"], L["Mode description"], "Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON", "Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON", function() Skada:ModeMenu(bargroup.win) end)
		window.bargroup:AddButton(L["Report"], L["Report description"], "Interface\\Buttons\\UI-GuildButton-MOTD-Up", "Interface\\Buttons\\UI-GuildButton-MOTD-Up", function() Skada:OpenReportWindow(bargroup.win) end)

	end
	window.bargroup.win = window
	window.bargroup.RegisterCallback(mod, "AnchorMoved")
	window.bargroup.RegisterCallback(mod, "WindowResized")
	window.bargroup:EnableMouse(true)
	window.bargroup:SetScript("OnMouseDown", function(win, button) if IsShiftKeyDown() then Skada:OpenMenu(window) elseif button == "RightButton" then window:RightClick() end end)
	window.bargroup.button:SetScript("OnClick", function(win, button) if IsShiftKeyDown() then Skada:OpenMenu(window) elseif button == "RightButton" then window:RightClick() end end)

	local function restButtonOpacity()
		return (window.db.hoverbuttons ~= false) and 0 or 0.25
	end
	window.bargroup:SetButtonsOpacity(restButtonOpacity())
	-- Also reveal when the cursor enters a button itself (covers the case where
	-- the button consumed the hover before the title bar saw it).
	for _, btn in ipairs(window.bargroup.buttons or {}) do
		btn:HookScript("OnEnter", function()
			window.bargroup:SetButtonsOpacity(1.0)
		end)
		btn:HookScript("OnLeave", function()
			if not window.bargroup.button:IsMouseOver() then
				window.bargroup:SetButtonsOpacity(restButtonOpacity())
			end
		end)
	end
	window.bargroup.button:SetScript("OnEnter", function()
		window.bargroup:SetButtonsOpacity(1.0)
	end)
	window.bargroup.button:SetScript("OnLeave", function()
		if not window.bargroup.button:IsMouseOver() then
			window.bargroup:SetButtonsOpacity(restButtonOpacity())
		end
	end)

	window.bargroup:HideIcon()

	window.bargroup.button:GetFontString():SetWordWrap(false);
	window.bargroup.button:GetFontString():SetPoint("LEFT", window.bargroup.button, "LEFT", 5, 1)
	window.bargroup.button:GetFontString():SetJustifyH("LEFT")
	window.bargroup.button:SetHeight(window.db.title.height or 15)

	-- Register with LibWindow-1.0.
	libwindow.RegisterConfig(window.bargroup, window.db)

	-- Restore window position.
	libwindow.RestorePosition(window.bargroup)

	if not mod.class_icon_tcoords then -- amortized class icon coordinate adjustment
		mod.class_icon_tcoords = {}
		for class, coords in pairs(CLASS_ICON_TCOORDS) do
			local l,r,t,b = unpack(coords)
			local adj = 0.02
			mod.class_icon_tcoords[class] = {(l+adj),(r-adj),(t+adj),(b-adj)}
		end
	end

	if not mod.role_icon_tcoords then
		mod.role_icon_tcoords = {
			DAMAGER = {0.3125, 0.63, 0.3125, 0.63},
			HEALER  = {0.3125, 0.63, 0.015625, 0.3125},
			TANK    = {0, 0.296875, 0.3125, 0.63},
			LEADER  = {0, 0.296875, 0.015625, 0.3125},
			NONE    = ""
		}
	end

end

-- Called by Skada windows when the window is to be destroyed/cleared.
function mod:Destroy(win)
	win.bargroup:Hide()
	win.bargroup = nil
end

-- Called by Skada windows when the window is to be completely cleared and prepared for new data.
function mod:Wipe(win)
	-- Reset sort function.
	win.bargroup:SetSortFunction(nil)

	-- Reset scroll offset.
	win.bargroup:SetBarOffset(0)

	-- Remove the bars.
	local bars = win.bargroup:GetBars()
	if bars then
		for i, bar in pairs(bars) do
			bar:Hide()
			win.bargroup:RemoveBar(bar)
		end
	end

	-- Clean up.
	win.bargroup:SortBars()
end

local function showmode(win, id, label, mode)
	-- Add current mode to window traversal history.
	if win.selectedmode then
		tinsert(win.history, win.selectedmode)
	end
	-- Call the Enter function on the mode.
	if mode.Enter then
		mode:Enter(win, id, label)
	end
	-- Display mode.
	win:DisplayMode(mode)
end

local function BarClickIgnore(bar, button)
	local win = bar.win
	if button == "RightButton" then
		win:RightClick()
	end
end

local function BarClick(bar, button)
	local win, id, label = bar.win, bar.id, bar.text
	local click1 = win.metadata.click1
	local click2 = win.metadata.click2
	local click3 = win.metadata.click3

	if button == "RightButton" and IsShiftKeyDown() then
		Skada:OpenMenu(win)
	elseif win.metadata.click then
		win.metadata.click(win, id, label, button)
	elseif button == "RightButton" then
		win:RightClick()
	elseif click2 and IsShiftKeyDown() then
		showmode(win, id, label, click2)
	elseif click3 and IsControlKeyDown() then
		showmode(win, id, label, click3)
	elseif click1 then
		showmode(win, id, label, click1)
	end
end

local ttactive = false

local function BarEnter(bar)
	local win, id, label = bar.win, bar.id, bar.text
	ttactive = true
	Skada:SetTooltipPosition(GameTooltip, win.bargroup)
	Skada:ShowTooltip(win, id, label)
end

local function BarLeave(bar)
	local win, id, label = bar.win, bar.id, bar.text
	if ttactive then
		GameTooltip:Hide()
		ttactive = false
	end
end

local function BarResize(bar)
	if bar.bgwidth then
		bar.bgtexture:SetWidth(bar.bgwidth * bar:GetWidth())
	else
		bar:SetScript("OnSizeChanged",bar.OnSizeChanged)
	end
	bar:OnSizeChanged() -- call library version
end

local function BarIconEnter(icon)
	local bar = icon.bar
	local win = bar.win
	if bar.spellid and win and win.bargroup then
		Skada:SetTooltipPosition(GameTooltip, win.bargroup);
		GameTooltip:SetHyperlink("spell:"..bar.spellid);
		GameTooltip:Show();
	end
	if bar.link and win and win.bargroup then
		Skada:SetTooltipPosition(GameTooltip, win.bargroup);
		GameTooltip:SetHyperlink(bar.link);
		GameTooltip:Show();
	end
end

local function BarIconMouseDown(icon) -- shift-click to link spell into chat
	local bar = icon.bar
	if not IsShiftKeyDown() or not bar.link then return end
	local activeEditBox = ChatFrameUtil.GetActiveWindow()
	if activeEditBox then
		ChatFrameUtil.InsertLink(bar.link)
	else
		ChatFrameUtil.OpenChat(bar.link, DEFAULT_CHAT_FRAME)
	end
end

-- Uses Skada.value_sort (defined in Skada.lua) to avoid duplication
local function value_sort(a, b)
	return Skada.value_sort(a, b)
end

local alignColumnHeaders

local function bar_order_sort(a,b)
	return a and b and a.order and b.order and a.order < b.order
end

local function HideGameTooltip()
	GameTooltip:Hide()
end

-- Called by Skada windows when title of window should change.
function mod:SetTitle(win, title)
	-- Set title.
	-- WoW 12.0+ restriction: Button:SetText() does not allow secret values during combat.
	-- However, FontString:SetText() does allow them. We use the internal FontString to bypass this.
	local fs = win.bargroup.button:GetFontString()
	if fs then
		fs:SetText(title)
	else
		win.bargroup.button:SetText(title)
	end
end

-- Called by Skada windows when the display should be updated to match the dataset.
function mod:Update(win)
	local mode = win.selectedmode
	local columns = mode and mode.metadata and mode.metadata.columns
	local sig = columns and (columns.Damage or columns.Healing) and ((mode and mode:GetName() or "") .. ":" .. (columns.Damage and "D" or "H")) or nil
	if win.bargroup.headerSignature ~= sig then
		mod:ApplySettings(win)
	end
	-- Some modes may alter title continously.
	local fs = win.bargroup.button:GetFontString()
	if fs then
		fs:SetText(win.metadata.title)
	else
		win.bargroup.button:SetText(win.metadata.title)
	end

	-- Sort if we are showing spots with "showspots".
	if win.metadata.showspots then
		table_sort(win.dataset, value_sort)
	end

	-- Find out if we have icons in this update, and if so, adjust accordingly.
	local hasicon = false
	for i, data in ipairs(win.dataset) do
		if (data.icon and not data.ignore) or (data.class and win.db.classicons) or (data.role and win.db.roleicons) then
			hasicon = true
		end
	end

	if hasicon and not win.bargroup.showIcon then
		win.bargroup:ShowIcon()
	end
	if not hasicon and win.bargroup.showIcon then
		win.bargroup:HideIcon()
	end

	-- If we are using "wipestale", we may have removed data
	-- and we need to remove unused bars.
	-- The Threat module uses this.
	-- For each bar, mark bar as unchecked.
	if win.metadata.wipestale then
		local bars = win.bargroup:GetBars()
		if bars then
			for name, bar in pairs(bars) do
				bar.checked = false
			end
		end
	end

	local nr = 1
	local activeBarIds = {}
	for i, data in ipairs(win.dataset) do
		if data.id then
			local barid = data.id
			local barlabel = data.label
			activeBarIds[barid] = true

			local bar = win.bargroup:GetBar(barid)

			if bar and bar.missingclass and data.class and not data.ignore then
				-- fixup bar that was generated before class info was available
				bar:Hide()
				win.bargroup:RemoveBar(bar)
				bar.missingclass = nil
				bar = nil
			end

			if bar then
				local barValue = data.value
				if type(barValue) ~= "number" then
					barValue = 0
				end
				bar:SetValue(barValue)
				bar:SetMaxValue(win.metadata.maxvalue or 1) -- MUST come after SetValue
			else
				-- Initialization of bars.
				local newValue = data.value
				if type(newValue) ~= "number" then
					newValue = 0
				end
				bar = mod:CreateBar(win, barid, barlabel, newValue, win.metadata.maxvalue or 1, data.icon, false)
				bar.id = barid
				bar.text = barlabel
				bar.fixed = false

				if not data.ignore then

					if data.icon ~= nil then
						bar:ShowIcon()

						bar.iconFrame.bar = bar
						bar.iconFrame:EnableMouse(true)
						bar.iconFrame:SetScript("OnEnter", BarIconEnter)
						bar.iconFrame:SetScript("OnLeave", HideGameTooltip)
						bar.iconFrame:SetScript("OnMouseDown", BarIconMouseDown)
					else
						bar:HideIcon()
					end

					bar:EnableMouse(true)
					bar:SetScript("OnEnter", BarEnter)
					bar:SetScript("OnLeave", BarLeave)
					bar:SetScript("OnMouseDown", BarClick)
				else
					bar:SetScript("OnEnter", nil)
					bar:SetScript("OnLeave", nil)
					bar:SetScript("OnMouseDown", BarClickIgnore)
				end
				local barValue = data.value
				if type(barValue) ~= "number" then
					barValue = 0
				end
				bar:SetValue(barValue)

				bar.link = nil
				bar.spellid = nil
				if data.spellid then
					bar.spellid = data.spellid
				elseif data.hyperlink then
					bar.link = data.hyperlink
				end

				if not data.class and (win.db.classicons or win.db.classcolorbars or win.db.classcolortext) then
					bar.missingclass = true
				else
					bar.missingclass = nil
				end

				if data.role and data.role ~= "NONE" and win.db.roleicons then
					bar:ShowIcon()
					-- bar:SetIconWithCoord("Interface\\LFGFrame\\UI-LFG-ICON-ROLES", GetTexCoordsForRole(data.role))
					bar:SetIconWithCoord("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", mod.role_icon_tcoords[data.role])
				elseif data.class and win.db.classicons and mod.class_icon_tcoords[data.class] then
					bar:ShowIcon()
					bar:SetIconWithCoord("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", mod.class_icon_tcoords[data.class])
				end

				if data.color then
					-- Explicit color from dataset.
					bar:SetColorAt(0, data.color.r, data.color.g, data.color.b, data.color.a or 1)
				elseif data.spellschool and win.db.spellschoolcolors then
					local school_colors = {
						[1] = {r = 1, g = 0.82, b = 0.17},
						[2] = {r = 0.96, g = 0.91, b = 0.11},
						[4] = {r = 0.89, g = 0.33, b = 0.10},
						[8] = {r = 0.31, g = 0.81, b = 0.19},
						[16] = {r = 0.40, g = 0.86, b = 0.96},
						[32] = {r = 0.61, g = 0.39, b = 0.76},
						[64] = {r = 0.92, g = 0.47, b = 0.88},
					}
					local color = school_colors[data.spellschool]
					if color then
						bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
					end
				elseif data.class and win.db.classcolorbars then
					-- Class color, optionally blended toward a theme tint so the
					-- bars sit inside the palette instead of fighting it.
					local color = Skada.classcolors[data.class]
					if color then
						local r, g, b = color.r, color.g, color.b
						local mix, amount = win.db.classcolormix, win.db.classcolormixamount
						if mix and amount and amount > 0 then
							r = r * (1 - amount) + mix.r * amount
							g = g * (1 - amount) + mix.g * amount
							b = b * (1 - amount) + mix.b * amount
						end
						bar:SetColorAt(0, r, g, b, color.a or 1)
					end
				else
					-- Default color.
					local color = win.db.barcolor
					bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
				end

				if data.class and win.db.classcolortext then
					-- Class color text.
					local color = Skada.classcolors[data.class]
					if color then
						bar.label:SetTextColor(color.r, color.g, color.b, color.a or 1)
						-- Apply color to all columns
						for i = 1, 3 do
							if bar.columns[i] then
								bar.columns[i]:SetTextColor(color.r, color.g, color.b, color.a or 1)
							end
						end
					end
				else
					-- Default color text, optionally themed.
					local ltc = win.db.labelcolor
					if ltc then
						bar.label:SetTextColor(ltc.r, ltc.g, ltc.b, ltc.a or 1)
					else
						bar.label:SetTextColor(1,1,1,1)
					end
					-- Apply value text color or default
					local vtc = win.db.valuetextcolor
					for i = 1, 3 do
						if bar.columns[i] then
							if vtc then
								bar.columns[i]:SetTextColor(vtc.r, vtc.g, vtc.b, vtc.a or 1)
							else
								bar.columns[i]:SetTextColor(1,1,1,1)
							end
						end
					end
				end

				local isSelf = data.isSelf == true
				if not isSelf and type(data.id) == "string" and not issecretvalue(data.id) then
					local playerGUID = UnitGUID("player")
					if type(playerGUID) == "string" and not issecretvalue(playerGUID) then
						isSelf = data.id == playerGUID
					end
				end
				if Skada.db.profile.showself and data.id and isSelf then
					-- Always show self
					bar.fixed = true
					bar.isSelfBar = true
				else
					bar.isSelfBar = false
				end
			end

			if win.metadata.ordersort then
				bar.order = i
			end

			if win.metadata.showspots and Skada.db.profile.showranks and not data.ignore then
				if win.db.barorientation == 1 then
					bar:SetLabel(("%2u. %s"):format(nr, data.label))
				else
					bar:SetLabel(("%s %2u"):format(data.label, nr))
				end
			else
				bar:SetLabel(data.label)
			end

			if data.valuetext then
				-- No columns
				bar:SetColumnText(3, data.valuetext)
			else
				-- Up to 3 columns - always call SetColumnText, it handles nil
				-- Note: Boolean tests on secret values are not allowed in WoW 12.0
				bar:SetColumnText(3, data.valueText1)
				bar:SetColumnText(2, data.valueText2)
				bar:SetColumnText(1, data.valueText3)
			end

			if win.metadata.wipestale then
				bar.checked = true
			end

			-- Emphathized items - cache a flag saying it is done so it is not done again.
			-- This is a little lame.
			if data.emphathize and bar.emphathize_set ~= true then
				bar:SetFont(nil,nil,win.db.barfontflags or "")
				bar.emphathize_set = true
			elseif not data.emphathize and bar.emphathize_set ~= false then
				bar:SetFont(nil,nil, win.db.barfontflags)
				bar.emphathize_set = false
			end

			-- Background texture color.
			if data.backgroundcolor then
				bar.bgtexture:SetVertexColor(data.backgroundcolor.r, data.backgroundcolor.g, data.backgroundcolor.b, data.backgroundcolor.a or 1)
			end

			-- Background texture size (in percent, as the mode has no idea on actual widths).
			if data.backgroundwidth then
				bar.bgtexture:ClearAllPoints()
				bar.bgtexture:SetPoint("BOTTOMLEFT")
				bar.bgtexture:SetPoint("TOPLEFT")
				bar.bgwidth = data.backgroundwidth
				bar:SetScript("OnSizeChanged",BarResize) -- ticket 365: required to resize bgtexture
				BarResize(bar)
			else
				bar.bgwidth = nil
			end

			if not data.ignore then
				nr = nr + 1
			end
		end
	end

	-- Remove bars that are no longer in the current dataset.
	-- This prevents stale bars from ID scheme transitions (e.g. combat_N <-> GUID)
	-- from lingering with outdated labels/values.
	local allBars = win.bargroup:GetBars()
	if allBars then
		for name, bar in pairs(allBars) do
			if not activeBarIds[name] then
				win.bargroup:RemoveBar(bar)
			end
		end
	end

	-- If we are using "wipestale", remove all unchecked bars.
	if win.metadata.wipestale then
		local bars = win.bargroup:GetBars()
		for name, bar in pairs(bars) do
			if not bar.checked then
				win.bargroup:RemoveBar(bar)
			end
		end
	end

	-- Always sort after applying the dataset. The previous "lazy" guard
	-- compared win.bargroup.barCount before and after the loop, but barCount
	-- is only assigned inside SortBars() itself, so it never differed and the
	-- guard suppressed legitimate re-sorts (rank changes, new/removed bars,
	-- ordersort updates). Sorting a few dozen bars per tick is cheap.
	if win.metadata.ordersort then
		win.bargroup:SetSortFunction(bar_order_sort)
	else
		win.bargroup:SetSortFunction(nil)
	end
	win.bargroup:SortBars()
	alignColumnHeaders(win)

end

function mod:AnchorMoved(cbk, group, x, y)
	libwindow.SavePosition(group)
end

function mod:WindowResized(cbk, group)
	-- Capture position and size BEFORE clearing anchors
	local top = group:GetTop()
	local left = group:GetLeft()
	local width = group:GetWidth()

	-- Calculate snapped height based on number of bars
	local height = group:GetHeight()
	local barHeight = group.win.db.barheight
	local barSpacing = group.win.db.barspacing
	local totalBarHeight = barHeight + barSpacing
	local numBars = math.floor((height + barSpacing + (totalBarHeight/2)) / totalBarHeight)
	local snappedHeight = (numBars * totalBarHeight) - barSpacing

	-- Re-anchor with snapped height, restoring width explicitly
	group:ClearAllPoints()
	group:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	group:SetWidth(width)
	group:SetHeight(snappedHeight)

	-- Save position and size
	libwindow.SavePosition(group)
	group.win.db.background.height = snappedHeight
	group.win.db.barwidth = width
	group:SetLength(width)

	-- Re-layout all bars at the new width
	group:SortBars()
end

function mod:Show(win)
	win.bargroup:Show()
	win.bargroup:SortBars()
end

function mod:Hide(win)
	win.bargroup:Hide()
end

function mod:IsShown(win)
	return win.bargroup:IsShown()
end

local function getNumberOfBars(win)
	-- Use barCount maintained by SortBars for O(1) lookup
	return win.bargroup.barCount or 0
end

local function OnMouseWheel(frame, direction)
	local win = frame.win
	local maxbars = win.db.background.height / (win.db.barheight + win.db.barspacing)
	if direction == 1 and win.bargroup:GetBarOffset() > 0 then
		win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() - 1)
	elseif direction == -1 and ((getNumberOfBars(win) - maxbars - win.bargroup:GetBarOffset()) > 0) then
		win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() + 1)
	end
end

function mod:OnMouseWheel(win, frame, direction) -- external scrolling interface (SkadaScroll)
	if not frame then
		mod.framedummy = mod.framedummy or {}
		mod.framedummy.win = win
		frame = mod.framedummy
	end
	OnMouseWheel(frame, direction)
end

local function themeUpper(key)
	local v = L[key]
	if type(v) == "string" then
		return string.upper(v)
	end
	return string.upper(key)
end

local function applyRowSeparator(bar, p)
	if p.showrowseparators then
		if not bar.separator then
			bar.separator = bar:CreateTexture(nil, "OVERLAY")
			bar.separator:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
			bar.separator:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
			bar.separator:SetHeight(1)
		end
		local c = p.rowseparatorcolor or {r = 0.3, g = 0.45, b = 0.6, a = 0.25}
		bar.separator:SetColorTexture(c.r, c.g, c.b, c.a or 0.25)
		bar.separator:Show()
	elseif bar.separator then
		bar.separator:Hide()
	end
end

function alignColumnHeaders(win)
	local g = win.bargroup
	local header = g and g.columnheaders
	if not header or not header:IsShown() then return end

	local row
	for _, data in ipairs(win.dataset) do
		if data.id and data.id ~= "total" then
			row = data
			break
		end
	end
	if not row then row = win.dataset[1] end
	if not row or not row.id then return end

	local bar = g:GetBar(row.id)
	if not bar or not bar.columns then return end
	local barRight = bar:GetRight()
	if not barRight then return end

	for i = 1, 3 do
		local f = header.labels and header.labels[i]
		local col = bar.columns[i]
		if f and col then
			local colRight = col:GetRight()
			if colRight then
				f:ClearAllPoints()
				f:SetPoint("RIGHT", header, "RIGHT", -(barRight - colRight), 0)
			end
		end
	end
end

local function applyFontShadow(fs, enabled)
	if not fs then return end
	if enabled then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.85)
	else
		fs:SetShadowOffset(0, 0)
	end
end

local function applyBarShadows(bar, enabled)
	if not bar then return end
	applyFontShadow(bar.label, enabled)
	if bar.columns then
		for i = 1, 3 do
			applyFontShadow(bar.columns[i], enabled)
		end
	end
end

local function applyColumnHeaders(win, p)
	local g = win.bargroup
	local header = g.columnheaders
	local mode = win.selectedmode
	local columns = mode and mode.metadata and mode.metadata.columns
	local hasColumns = columns and (columns.Damage or columns.Healing)

	g.headerSignature = hasColumns and ((mode and mode:GetName() or "") .. ":" .. (columns.Damage and "D" or "H")) or nil

	if not p.showcolumnheaders or not hasColumns then
		if header then header:Hide() end
		return 0
	end

	local height = p.columnheadersheight or 16
	if not header then
		header = CreateFrame("Frame", nil, g.button)
		header:SetPoint("BOTTOMLEFT", g.button, "BOTTOMLEFT", 0, p.columnheaderbottom or 2)
		header:SetPoint("BOTTOMRIGHT", g.button, "BOTTOMRIGHT", 0, p.columnheaderbottom or 2)
		header.labels = {}
		for i = 1, 3 do
			local f = header:CreateFontString(nil, "OVERLAY")
			f:SetJustifyH("RIGHT")
			f:SetJustifyV("MIDDLE")
			header.labels[i] = f
		end
		g.columnheaders = header
	end

	header:SetHeight(height)
	header:Show()

	local font = p.columnheaderfontpath or media:Fetch("font", p.columnheaderfont or p.barfont)
	local c = p.columnheadertextcolor or p.title.textcolor or {r = 0.8, g = 0.9, b = 1, a = 1}
	-- BarDisplay assigns valueText3/valueText2/valueText1 to columns 1/2/3,
	-- i.e. column 1 is the leftmost (percent) and column 3 the rightmost (damage).
	local text = {
		columns.Percent and "%",
		columns.DPS and "DPS" or columns.HPS and "HPS" or columns.DTPS and "DTPS",
		columns.Damage and "DMG" or columns.Healing and "HEAL",
	}
	local offsets = {p.columnheaderoffset1 or 12, p.columnheaderoffset2 or 64, p.columnheaderoffset3 or 112}

	for i = 1, 3 do
		local f = header.labels[i]
		f:SetFont(font, p.columnheaderfontsize or 8, p.columnheaderfontflags or "")
		f:SetTextColor(c.r, c.g, c.b, (c.a or 1) * 0.80)
		applyFontShadow(f, p.textshadow)
		if text[i] then
			f:SetText(text[i])
			f:ClearAllPoints()
			f:SetPoint("RIGHT", header, "RIGHT", -offsets[i], 0)
			f:Show()
		else
			f:Hide()
		end
	end

	return height
end

function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
	local bar = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon)
	bar.win = win
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", OnMouseWheel)
	bar.iconFrame:SetScript("OnEnter", nil)
	bar.iconFrame:SetScript("OnLeave", nil)
	bar.iconFrame:SetScript("OnMouseDown", nil)
	bar.iconFrame:EnableMouse(false)
	applyRowSeparator(bar, win.db)
	applyBarShadows(bar, win.db.textshadow)
	return bar
end

local titlebackdrop = {}
local windowbackdrop = {}

-- Called by Skada windows when window settings have changed.
function mod:ApplySettings(win)
	local g = win.bargroup
		g:SetFrameLevel(1)
	local p = win.db
	g:ReverseGrowth(p.reversegrowth)
	g:SetOrientation(p.barorientation)
	g:SetBarHeight(p.barheight)
	g:SetHeight(p.background.height)
	g:SetWidth(p.barwidth)
	g:SetLength(p.barwidth)
	g:SetTexture(p.bartexturepath or media:Fetch('statusbar', p.bartexture))

	g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, p.barbgcolor.a or 0.6)
	if g:GetBars() then
		for _, bar in pairs(g:GetBars()) do
			applyRowSeparator(bar, p)
			applyBarShadows(bar, p.textshadow)
		end
	end
	g:SetFont(p.barfontpath or media:Fetch('font', p.barfont), p.barfontsize, p.barfontflags)
	g:SetSpacing(p.barspacing)
	g:UnsetAllColors()
	g:SetColorAt(0,p.barcolor.r,p.barcolor.g,p.barcolor.b, p.barcolor.a)
	if p.barslocked then
		g:Lock()
	else
		g:Unlock()
	end

	if p.strata then g:SetFrameStrata(p.strata) end

	-- Header
	local fo = CreateFont("TitleFont"..win.db.name)
	fo:SetFont(p.title.fontpath or media:Fetch('font', p.title.font), p.title.fontsize, p.title.fontflags)
	if p.title.textcolor then
		fo:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a)
	end
	g.button:SetNormalFontObject(fo)

	-- Title text alignment and padding
	local fs = g.button:GetFontString()
	if fs then
		fs:SetJustifyH(p.title.textalign or "LEFT")
		fs:SetJustifyV("TOP")
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", g.button, "TOPLEFT", p.title.paddingleft or 10, -(p.title.paddingtop or 5))
		applyFontShadow(fs, p.textshadow)
	end

	local titleBgFile = media:Fetch("statusbar", p.title.texture)
	if not titleBgFile or p.title.texture == "None" then
		titleBgFile = "Interface\\Buttons\\WHITE8X8"
	end
	titlebackdrop.bgFile = titleBgFile
	titlebackdrop.tile = false
	titlebackdrop.tileSize = 0
	titlebackdrop.edgeSize = p.title.borderthickness
	g.button:SetBackdrop(titlebackdrop)
	local color = p.title.color
	g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)

	-- Title gradient
	local tex = g.button:GetNormalTexture()
	if tex and p.title.color and p.title.color2 then
		tex:SetGradient("HORIZONTAL", CreateColor(p.title.color.r, p.title.color.g, p.title.color.b, p.title.color.a), CreateColor(p.title.color2.r, p.title.color2.g, p.title.color2.b, p.title.color2.a or 1))
	elseif tex then
		tex:SetGradient("HORIZONTAL", CreateColor(1,1,1,1), CreateColor(1,1,1,1)) -- Reset if no gradient
	end

	local baseTitleHeight = p.title.height or 15
	local headerHeight = applyColumnHeaders(win, p)
	-- Keep the title bar the same height. When headers are enabled the title
	-- row shrinks inside it and the header strip uses the bottom 10px.
	local titleRowHeight = baseTitleHeight
	if headerHeight > 0 then
		titleRowHeight = max(baseTitleHeight - headerHeight, 18)
	end
	g.button:SetHeight(baseTitleHeight)

	Skada:ApplyBorder(g.button, p.title.bordertexture, p.title.bordercolor, p.title.borderthickness)

	if p.enabletitle then
		g:ShowAnchor()
	else
		g:HideAnchor()
	end

	-- Adjust button positions. Keep them aligned to the title row, not the
	-- combined title+header height, otherwise they look vertically centered.
	local buttonSize = p.buttonsize or 12
	local buttonOffset = p.buttonverticaloffset or max((titleRowHeight - buttonSize) / 2, 0)
	g:SetButtonLayout(p.buttonspacing or 3, p.buttonpaddingright or 8, buttonSize, buttonOffset)

	-- Button visibility.
	g:ShowButton(L["Configure"], p.buttons.menu)
	g:ShowButton(L["Reset"], p.buttons.reset)
	g:ShowButton(L["Mode"], p.buttons.mode)
	g:ShowButton(L["Segment"], p.buttons.segment)
	g:ShowButton(L["Report"], p.buttons.report)
	-- g:ShowButton(L["Stop"], p.buttons.stop)

	g:SetButtonsOpacity(((p.hoverbuttons ~= false) and g.button:IsMouseOver()) and 1 or ((p.hoverbuttons ~= false) and 0 or 0.25))

	-- Window
	local padtop = (p.enabletitle and not p.reversegrowth and baseTitleHeight)
	local padbottom = (p.enabletitle and p.reversegrowth and baseTitleHeight)
	Skada:ApplyBorder(g, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness, padtop, padbottom)

	local bgFile = p.background.texturepath or media:Fetch("background", p.background.texture)
	if not bgFile or p.background.texture == "None" then
		bgFile = "Interface\\Buttons\\WHITE8X8"
	end
	windowbackdrop.bgFile = bgFile
	windowbackdrop.tile = false
	windowbackdrop.tileSize = 0
	g:SetBackdrop(windowbackdrop)

	local bgcolor = p.background.color
	g:SetBackdropColor(bgcolor.r, bgcolor.g, bgcolor.b, bgcolor.a or 1)

	-- Clickthrough
	g:SetEnableMouse(not p.clickthrough)

	-- Scale
	g:SetScale(p.scale)

	-- Smoothing
	g:SetSmoothing(p.smoothing)

	-- Bar fill
	g:SetFill(p.barfill)

	-- Alternating row colors
	g:SetAlternateRows(p.alternaterows)

	-- Self-highlight
	if p.highlightself then
		local sc = p.selfhighlightcolor
		g:SetSelfHighlight(true, sc and {sc.r, sc.g, sc.b, sc.a})
	else
		g:SetSelfHighlight(false)
	end

	-- Spark on leading bar
	g:SetSpark(p.spark)

	-- Icon scale
	g:SetIconScale(p.iconscale or 100)

	-- Bar inset
	g:SetBarInset(p.barinset or 0)

	libwindow.SavePosition(g)

	g:SortBars()
end

--
-- Options.
--

function mod:AddDisplayOptions(win, options)
	local db = win.db

	options.baroptions = {
		type = "group",
		name = L["Bars"],
		order = 1,
		args = {

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
				order = 1,
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
				order = 3,
			},

			bartexture = {
				type = 'select',
				dialogControl = 'LSM30_Statusbar',
				name = L["Bar texture"],
				desc = L["The texture used by all bars."],
				values = AceGUIWidgetLSMlists.statusbar,
				get = function() return db.bartexture end,
				set = function(win,key)
					db.bartexture = key
					Skada:ApplySettings()
				end,
				order = 12,
			},

			barspacing = {
				type="range",
				name=L["Bar spacing"],
				desc=L["Distance between bars."],
				min=0,
				max=10,
				step=1,
				get=function() return db.barspacing end,
				set=function(win, spacing)
					db.barspacing = spacing
					Skada:ApplySettings()
				end,
				order=13,
			},

			barheight = {
				type="range",
				name=L["Bar height"],
				desc=L["The height of the bars."],
				min=10,
				max=40,
				step=1,
				get=function() return db.barheight end,
				set=function(win, height)
					db.barheight = height
					Skada:ApplySettings()
				end,
				order=14,
			},

			barorientation = {
				type="select",
				name=L["Bar orientation"],
				desc=L["The direction the bars are drawn in."],
				values=	function() return {[1] = L["Left to right"], [3] = L["Right to left"]} end,
				get=function() return db.barorientation end,
				set=function(win, orientation)
					db.barorientation = orientation
					Skada:ApplySettings()
				end,
				order=17,
			},

			reversegrowth = {
				type="toggle",
				name=L["Reverse bar growth"],
				desc=L["Bars will grow up instead of down."],
				order=19,
				get=function() return db.reversegrowth end,
				set=function()
					db.reversegrowth = not db.reversegrowth
					Skada:ApplySettings()
				end,
			},

			color = {
				type="color",
				name=L["Bar color"],
				desc=L["Choose the default color of the bars."],
				hasAlpha=true,
				get=function(i)
					local c = db.barcolor
					return c.r, c.g, c.b, c.a
				end,
				set=function(i, r,g,b,a)
					db.barcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
				order=21,
			},

			bgcolor = {
				type="color",
				name=L["Background color"],
				desc=L["Choose the background color of the bars."],
				hasAlpha=true,
				get=function(i) return db.barbgcolor.r, db.barbgcolor.g, db.barbgcolor.b, db.barbgcolor.a end,
				set=function(i, r,g,b,a) db.barbgcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}; Skada:ApplySettings() end,
				order=22,
			},

			classcolorbars = {
				type="toggle",
				name=L["Class color bars"],
				desc=L["When possible, bars will be colored according to player class."],
				order=30,
				get=function() return db.classcolorbars end,
				set=function()
					db.classcolorbars = not db.classcolorbars
					Skada:ApplySettings()
				end,
			},

			classcolortext = {
				type="toggle",
				name=L["Class color text"],
				desc=L["When possible, bar text will be colored according to player class."],
				order=31,
				get=function() return db.classcolortext end,
				set=function()
					db.classcolortext = not db.classcolortext
					Skada:ApplySettings()
				end,
			},

			classicons = {
				type="toggle",
				name=L["Class icons"],
				desc=L["Use class icons where applicable."],
				order=32,
				get=function() return db.classicons end,
				set=function()
					db.classicons = not db.classicons
					Skada:ApplySettings()
				end,
			},

			roleicons = {
				type="toggle",
				name=L["Role icons"],
				desc=L["Use role icons where applicable."],
				order=33,
				get=function() return db.roleicons end,
				set=function()
					db.roleicons = not db.roleicons
					Skada:ApplySettings()
				end,
			},

			spellschoolcolors = {
				type="toggle",
				name=L["Spell school colors"],
				desc=L["Use spell school colors where applicable."],
				order=33,
				get=function() return db.spellschoolcolors end,
				set=function()
					db.spellschoolcolors = not db.spellschoolcolors
					Skada:ApplySettings()
				end,
			},

			clickthrough = {
				type="toggle",
				name=L["Clickthrough"],
				desc=L["Disables mouse clicks on bars."],
				order=20,
				get=function() return db.clickthrough end,
				set=function()
					db.clickthrough = not db.clickthrough
					Skada:ApplySettings()
				end,
			},

			smoothing = {
				type="toggle",
				name=L["Smooth bars"],
				desc=L["Animate bar changes smoothly rather than immediately."],
				order=34,
				get=function() return db.smoothing end,
				set=function()
					db.smoothing = not db.smoothing
					Skada:ApplySettings()
				end,
			},

			alternaterows = {
				type="toggle",
				name=L["Alternate row colors"],
				desc=L["Slightly darkens every other bar for easier readability."],
				order=35,
				get=function() return db.alternaterows end,
				set=function()
					db.alternaterows = not db.alternaterows
					Skada:ApplySettings()
				end,
			},

			highlightself = {
				type="toggle",
				name=L["Highlight self"],
				desc=L["Adds a subtle highlight overlay on your own bar to make it easier to spot."],
				order=36,
				get=function() return db.highlightself end,
				set=function()
					db.highlightself = not db.highlightself
					Skada:ApplySettings()
				end,
			},

			selfhighlightcolor = {
				type="color",
				name=L["Self highlight color"],
				desc=L["The color of the self-highlight overlay."],
				hasAlpha=true,
				order=37,
				get=function(i)
					local c = db.selfhighlightcolor or {r = 1, g = 1, b = 1, a = 0.12}
					return c.r, c.g, c.b, c.a
				end,
				set=function(i, r,g,b,a)
					db.selfhighlightcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
			},

			spark = {
				type="toggle",
				name=L["Spark effect"],
				desc=L["Shows a glowing spark on the leading bar's fill edge."],
				order=38,
				get=function() return db.spark end,
				set=function()
					db.spark = not db.spark
					Skada:ApplySettings()
				end,
			},

			barfill = {
				type="toggle",
				name=L["Reverse fill"],
				desc=L["Bars fill from empty to full instead of shrinking from full."],
				order=39,
				get=function() return db.barfill end,
				set=function()
					db.barfill = not db.barfill
					Skada:ApplySettings()
				end,
			},

			iconscale = {
				type="range",
				name=L["Icon size"],
				desc=L["Scale the class/spell icons relative to bar height."],
				min=50,
				max=150,
				step=5,
				isPercent=false,
				get=function() return db.iconscale or 100 end,
				set=function(win, val)
					db.iconscale = val
					Skada:ApplySettings()
				end,
				order=40,
			},

			barinset = {
				type="range",
				name=L["Bar inset"],
				desc=L["The amount of spacing between the bar fill and the bar frame."],
				min=0,
				max=10,
				step=1,
				get=function() return db.barinset or 0 end,
				set=function(win, val)
					db.barinset = val
					Skada:ApplySettings()
				end,
				order=41,
			},

			valuetextcolor = {
				type="color",
				name=L["Value text color"],
				desc=L["Sets a custom color for the numeric value columns. Uncheck class color text to see this."],
				hasAlpha=true,
				order=41,
				get=function(i)
					local c = db.valuetextcolor
					if c then
						return c.r, c.g, c.b, c.a or 1
					else
						return 1, 1, 1, 1
					end
				end,
				set=function(i, r,g,b,a)
					db.valuetextcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
			},

			showcolumnheaders = {
				type="toggle",
				name=L["Column headers"],
				desc=L["Show a small Damage / DPS / Percent header row under the title."],
				order=42,
				get=function() return db.showcolumnheaders end,
				set=function()
					db.showcolumnheaders = not db.showcolumnheaders
					Skada:ApplySettings()
				end,
			},

			showrowseparators = {
				type="toggle",
				name=L["Row separators"],
				desc=L["Draw a thin separator line between bars."],
				order=43,
				get=function() return db.showrowseparators end,
				set=function()
					db.showrowseparators = not db.showrowseparators
					Skada:ApplySettings()
				end,
			},

			textshadow = {
				type="toggle",
				name=L["Text shadow"],
				desc=L["Adds a 1px shadow behind bar and title text. Disable for the crispest edges."],
				order=44,
				get=function() return db.textshadow end,
				set=function()
					db.textshadow = not db.textshadow
					Skada:ApplySettings()
				end,
			},

		}
	}

		options.titleoptions = {
		type = "group",
		name = L["Title bar"],
		order=2,
		args = {

			enable = {
				type="toggle",
				name=L["Enable"],
				desc=L["Enables the title bar."],
				order=0,
				get=function() return db.enabletitle end,
				set=function()
					db.enabletitle = not db.enabletitle
					Skada:ApplySettings()
				end,
			},

			titleset = {
				type="toggle",
				name=L["Include set"],
				desc=L["Include set name in title bar"],
				order=0.5,
				get=function() return db.titleset end,
				set=function()
					db.titleset = not db.titleset
					Skada:ApplySettings()
				end,
			},

			height = {
				type="range",
				name=L["Title height"],
				desc=L["The height of the title frame."],
				order=1,
				min=10,
				max=50,
				step=1,
				get=function() return db.title.height end,
				set=function(win, val)
					db.title.height = val
					Skada:ApplySettings()
				end,
			},

			paddingleft = {
				type="range",
				name=L["Title left padding"],
				desc=L["Space between the left edge and the title text."],
				order=1.1,
				min=0,
				max=30,
				step=1,
				get=function() return db.title.paddingleft or 10 end,
				set=function(win, val)
					db.title.paddingleft = val
					Skada:ApplySettings()
				end,
			},

			buttonspacing = {
				type="range",
				name=L["Title button spacing"],
				desc=L["Space between the title bar buttons."],
				order=1.2,
				min=0,
				max=12,
				step=1,
				get=function() return db.buttonspacing or 3 end,
				set=function(win, val)
					db.buttonspacing = val
					Skada:ApplySettings()
				end,
			},

			buttonsize = {
				type="range",
				name=L["Title button size"],
				desc=L["Size of the title bar buttons."],
				order=1.3,
				min=10,
				max=22,
				step=1,
				get=function() return db.buttonsize or 12 end,
				set=function(win, val)
					db.buttonsize = val
					Skada:ApplySettings()
				end,
			},

			hoverbuttons = {
				type="toggle",
				name=L["Show buttons on hover"],
				desc=L["Hide the title bar buttons until the mouse hovers over the title bar."],
				order=1.4,
				get=function() return db.hoverbuttons ~= false end,
				set=function()
					db.hoverbuttons = (db.hoverbuttons == false)
					Skada:ApplySettings()
				end,
			},

			font = {
				type = 'select',
				dialogControl = 'LSM30_Font',
				name = L["Bar font"],
				desc = L["The font used by all bars."],
				values = AceGUIWidgetLSMlists.font,
				get = function() return db.title.font end,
				set = function(win,key)
					db.title.font = key
					Skada:ApplySettings()
				end,
				order=2,
			},

			fontsize = {
				type="range",
				name=L["Bar font size"],
				desc=L["The font size of all bars."],
				min=7,
				max=40,
				step=1,
				get=function() return db.title.fontsize end,
				set=function(win, size)
					db.title.fontsize = size
					Skada:ApplySettings()
				end,
				order=3,
			},

			fontflags = {
				type = 'select',
				name = L["Font flags"],
				desc = L["Sets the font flags."],
				values = {[""] = L["None"], ["OUTLINE"] = L["Outline"], ["THICKOUTLINE"] = L["Thick outline"], ["MONOCHROME"] = L["Monochrome"], ["OUTLINEMONOCHROME"] = L["Outlined monochrome"]},
				get = function() return db.title.fontflags end,
				set = function(win,key)
					db.title.fontflags = key
					Skada:ApplySettings()
				end,
				order=4,
			},

			textalign = {
				type="select",
				name=L["Text alignment"],
				desc=L["The alignment of the title text."],
				values = {["LEFT"] = L["Left"], ["CENTER"] = L["Center"], ["RIGHT"] = L["Right"]},
				get=function() return db.title.textalign or "LEFT" end,
				set=function(win, key)
					db.title.textalign = key
					Skada:ApplySettings()
				end,
				order=4.5,
			},

			textcolor = {
				type="color",
				name=L["Title color"],
				desc=L["The text color of the title."],
				hasAlpha=true,
				get=function(i)
					local c = db.title.textcolor or {r = 0.9, g = 0.9, b = 0.9, a = 1}
					return c.r, c.g, c.b, c.a
				end,
				set=function(i, r,g,b,a)
					db.title.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
				order=4.1,
			},

			texture = {
				type = 'select',
				dialogControl = 'LSM30_Statusbar',
				name = L["Background texture"],
				desc = L["The texture used as the background of the title."],
				values = AceGUIWidgetLSMlists.statusbar,
				get = function() return db.title.texture end,
				set = function(win,key)
					db.title.texture = key
					Skada:ApplySettings()
				end,
				order=5,
			},

			color = {
				type="color",
				name=L["Background color"],
				desc=L["The background color of the title."],
				hasAlpha=true,
				get=function(i)
					local c = db.title.color
					return c.r, c.g, c.b, c.a
				end,
				set=function(i, r,g,b,a)
					db.title.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
				order=5.1,
			},

			opacity = {
				type="range",
				name=L["Opacity"],
				desc=L["The opacity of the title bar background."],
				min=0,
				max=1,
				step=0.01,
				isPercent=true,
				get=function() return db.title.color.a or 1 end,
				set=function(win, val)
					db.title.color.a = val
					Skada:ApplySettings()
				end,
				order=5.15,
			},

			color2 = {
				type="color",
				name=L["Gradient color"],
				desc=L["The secondary background color of the title for gradient effects."],
				hasAlpha=true,
				get=function(i)
					local c = db.title.color2
					if c then
						return c.r, c.g, c.b, c.a
					else
						return 0, 0, 0, 0
					end
				end,
				set=function(i, r,g,b,a)
					db.title.color2 = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
				order=5.2,
			},

			bordertexture = {
				type = 'select',
				dialogControl = 'LSM30_Border',
				name = L["Border texture"],
				desc = L["The texture used for the border of the title."],
				values = AceGUIWidgetLSMlists.border,
				get = function() return db.title.bordertexture end,
				set = function(win,key)
					db.title.bordertexture = key
					Skada:ApplySettings()
				end,
				order=6,
			},

			bordercolor = {
				type="color",
				name=L["Border color"],
				desc=L["The color used for the border."],
				hasAlpha=true,
				get=function(i)
					local c = db.title.bordercolor or {r = 0, g = 0, b = 0, a = 1}
					return c.r, c.g, c.b, c.a
				end,
				set=function(i, r,g,b,a)
					db.title.bordercolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end,
				order=6.1,
			},

			thickness = {
				type="range",
				name=L["Border thickness"],
				desc=L["The thickness of the borders."],
				min=0,
				max=50,
				step=0.5,
				get=function() return db.title.borderthickness end,
				set=function(win, val)
					db.title.borderthickness = val
					Skada:ApplySettings()
				end,
				order=6.2,
			},

			buttons = {
				type = "group",
				name = L["Buttons"],
				order=20,
				inline=true,
				args = {
					report = {
						type="toggle",
						name=L["Report"],
						order=1,
						get=function() return db.buttons.report == nil or db.buttons.report end,
						set=function()
							db.buttons.report = not db.buttons.report
							Skada:ApplySettings()
						end,
					},
					mode = {
						type="toggle",
						name=L["Mode"],
						order=2,
						get=function() return db.buttons.mode == nil or db.buttons.mode end,
						set=function()
							db.buttons.mode = not db.buttons.mode
							Skada:ApplySettings()
						end,
					},
					segment = {
						type="toggle",
						name=L["Segment"],
						order=3,
						get=function() return db.buttons.segment == nil or db.buttons.segment end,
						set=function()
							db.buttons.segment = not db.buttons.segment
							Skada:ApplySettings()
						end,
					},
					reset = {
							type="toggle",
							name=L["Reset"],
							order=4,
							get=function() return db.buttons.reset end,
							set=function()
								db.buttons.reset = not db.buttons.reset
								Skada:ApplySettings()
							end,
					},
					menu = {
							type="toggle",
							name=L["Configure"],
							order=5,
							get=function() return db.buttons.menu end,
							set=function()
								db.buttons.menu = not db.buttons.menu
								Skada:ApplySettings()
							end,
					},

				}
			}
		}
	}

	options.windowoptions = Skada:FrameSettings(db, false)

	-- Per-window theme options
	local selectedpreset = nil
	local importtext = ""

	options.themeoptions = {
		type = "group",
		name = L["Themes"],
		order = 5,
		args = {

			header1 = {
				type = "header",
				name = L["Apply theme"],
				order = 1,
			},

			preset = {
				type = "select",
				name = L["Theme"],
				values = function()
					local list = {}
					if Skada.themePresets then
						for _, theme in ipairs(Skada.themePresets) do
							list[theme.name] = theme.name
						end
					end
					return list
				end,
				get = function() return selectedpreset end,
				set = function(_, name) selectedpreset = name end,
				order = 1.1,
			},

			applybutton = {
				type = "execute",
				name = L["Apply"],
				func = function()
					if selectedpreset and Skada.themePresets then
						for _, theme in ipairs(Skada.themePresets) do
							if theme.name == selectedpreset then
								Skada:ApplyThemeToWindow(win, theme)
								Skada:Print(L["Theme applied!"])
								break
							end
						end
					end
				end,
				order = 1.2,
			},

			header2 = {
				type = "header",
				name = L["Export theme"],
				order = 2,
			},

			exportbutton = {
				type = "execute",
				name = L["Export"],
				desc = L["Export this window's settings as a shareable theme string."],
				func = function()
					local themedata = {}
					Skada:tcopy(themedata, db)
					themedata.name = db.name or "Exported Theme"
					local encoded = Skada:EncodeTheme(themedata)
					Skada:ShowThemeExportDialog(encoded)
				end,
				order = 2.1,
			},

			header3 = {
				type = "header",
				name = L["Import theme"],
				order = 3,
			},

			importtext = {
				type = "input",
				name = L["Theme data"],
				desc = L["Paste theme data here to import"],
				width = "full",
				get = function() return importtext end,
				set = function(_, val) importtext = val end,
				order = 3.1,
			},

			importbutton = {
				type = "execute",
				name = L["Import"],
				func = function()
					if importtext and importtext ~= "" then
						local success, theme = Skada:DecodeTheme(importtext)
						if success and theme then
							Skada:ApplyThemeToWindow(win, theme)
							Skada:Print(L["Theme imported and applied!"])
							importtext = ""
						else
							Skada:Print(L["Failed to import theme. Make sure the string starts with !Skada!"])
						end
					end
				end,
				order = 3.2,
			},
		}
	}
end
