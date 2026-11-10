--[[

The traditional bar display used in some form by most damage meters.

--]]

local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local titleHover
local snapBarRows
local TITLE_TEXT_Y = 0
local applyColumnGeometry
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
		window.bargroup:AddButton(L["Report"], L["Report description"], "Interface\\Buttons\\UI-GuildButton-MOTD-Up", "Interface\\Buttons\\UI-GuildButton-MOTD-Up", function() Skada:ReportMenu(bargroup.win) end)

		-- The library's resize grabber updates bars in its own OnUpdate, but
		-- that can lag or be interrupted. Drive the bar length directly from
		-- the group's real width so the bars track the drag immediately.
		window.bargroup:HookScript("OnSizeChanged", function(g)
			if g._skadaSyncingWidth then return end
			local width = g:GetWidth()
			if not width or width <= 1 then return end
			g._skadaSyncingWidth = true
			if g.length ~= width then
				g:SetLength(width)
			end
			if g.barCount and g.barCount > 0 then
				g:SortBars()
				if g.win then snapBarRows(g.win) end
			end
			g._skadaSyncingWidth = nil
		end)

	end
	window.bargroup.win = window
	local titleButton = window.bargroup.button
	if titleButton and not titleButton._skadaTitleClickHooked then
		titleButton._skadaTitleClickHooked = true
		titleButton:HookScript("OnMouseDown", function(button)
			button._skadaClickLeft = button:GetParent():GetLeft()
			button._skadaClickTop = button:GetParent():GetTop()
		end)
		titleButton:HookScript("OnMouseUp", function(button, mouseButton)
			local group = button:GetParent()
			local left, top = group:GetLeft(), group:GetTop()
			local moved = math.abs((button._skadaClickLeft or left) - (left or 0)) > 3
				or math.abs((button._skadaClickTop or top) - (top or 0)) > 3
			if not moved then
				if mouseButton == "LeftButton" then
					Skada:ModeMenu(window)
				elseif mouseButton == "RightButton" then
					Skada:SegmentMenu(window)
				end
			end
		end)
		titleButton:HookScript("OnEnter", function(button)
			local fs = button:GetFontString()
			if fs then
				local r, g, b, a = fs:GetTextColor()
				button._skadaTitleColor = { r, g, b, a }
				fs:SetTextColor(0.55, 0.80, 1.00, 1)
			end
			GameTooltip:SetOwner(button, "ANCHOR_TOP")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(L["Left click: mode"])
			GameTooltip:AddLine(L["Right click: segment"])
			GameTooltip:Show()
		end)
		titleButton:HookScript("OnLeave", function(button)
			local fs = button:GetFontString()
			local c = button._skadaTitleColor
			if fs and c then fs:SetTextColor(c[1], c[2], c[3], c[4]) end
			button._skadaTitleColor = nil
			GameTooltip:Hide()
		end)
	end
	window.bargroup.RegisterCallback(mod, "AnchorMoved")
	window.bargroup.RegisterCallback(mod, "WindowResized")
	window.bargroup:EnableMouse(true)
	window.bargroup:SetScript("OnMouseDown", function(win, button)
		if IsShiftKeyDown() then
			Skada:OpenMenu(window)
		end
		-- Right-click navigation belongs to bar rows, not the group. The title
		-- owns right-click as the segment menu and must never fall through to
		-- the legacy back-navigation path.
	end)
	window.bargroup.button:SetScript("OnClick", function(win, button)
		if IsShiftKeyDown() then Skada:OpenMenu(window) end
	end)

	local function restButtonOpacity()
		return (window.db.hoverbuttons ~= false) and 0 or 0.25
	end
	window.bargroup:SetButtonsOpacity(restButtonOpacity())
	-- Also reveal when the cursor enters a button itself (covers the case where
	-- the button consumed the hover before the title bar saw it).
	for _, btn in ipairs(window.bargroup.buttons or {}) do
		btn:HookScript("OnEnter", function()
			titleHover(window, true)
		end)
		btn:HookScript("OnLeave", function()
			if not window.bargroup.button:IsMouseOver() then
				titleHover(window, false)
			end
		end)
	end
	window.bargroup.button:SetScript("OnEnter", function()
		titleHover(window, true)
	end)
	window.bargroup.button:SetScript("OnLeave", function()
		if not window.bargroup.button:IsMouseOver() then
			titleHover(window, false)
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
	local ok, err
	if mode.Enter then
		ok, err = pcall(mode.Enter, mode, win, id, label)
	end
	if not ok and err then
		Skada:RecordDisplayError("Drilldown enter", err)
		-- Still switch mode/title; an Enter failure must not leave the window
		-- stuck on the parent list.
	end
	-- Display mode.
	ok, err = pcall(win.DisplayMode, win, mode)
	if not ok then
		Skada:RecordDisplayError("Drilldown display", err)
		win:set_mode_title()
		win.changed = true
	end
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
	-- The bar owns the source identifiers even when the id/name are secret.
	-- Pass them straight to C_DamageMeter when drilling into spells.
	win._drillSourceGUID = bar.sourceGUID
	win._drillSourceCreatureID = bar.sourceCreatureID

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

titleHover = function(window, hover)
	local g = window.bargroup
	local db = window.db
	if not g then return end
	local wasHover = g._titleHover
	g._titleHover = hover and true or false

	if db.hoverbuttons == false then
		return
	end

	local base = db.title.height or 30
	local size = db.buttonsize or 15
	local header = g.columnheaders

	if hover then
		if header then
			if not wasHover then
				header._hoverWasShown = header:IsShown()
			end
			header:Hide()
		end
		g:SetButtonLayout(db.buttonspacing or 3, db.buttonpaddingright or 8, size, (base - size) / 2 - TITLE_TEXT_Y)
		g:SetButtonsOpacity(1)
	else
		if header then
			if header._hoverWasShown then
				header:Show()
			end
			header._hoverWasShown = nil
		end
		g:SetButtonLayout(db.buttonspacing or 3, db.buttonpaddingright or 8, size, g._normalButtonOffset or max((base - size) / 2, 0))
		g:SetButtonsOpacity(0)
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

local function BarIconMouseDown(icon, button) -- shift-click to link spell into chat
	local bar = icon.bar
	if button == "LeftButton" and not IsShiftKeyDown() then
		BarClick(bar, button)
		return
	end
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

local applyColumnHeaders

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
	if not issecretvalue(title) and win._lastSetTitle == title then return end
	win._lastSetTitle = issecretvalue(title) and nil or title
	local fs = win.bargroup.button:GetFontString()
	if fs then
		fs:SetText(title)
	else
		win.bargroup.button:SetText(title)
	end
end

-- Ordered columns shared by values and headers. Width thresholds also keep
-- compact windows readable without a separate setting.
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

-- Snap every visible row to the same physical-pixel grid. The bar library
-- anchors each row relative to the previous one, so at fractional UI scales
-- rounding can make one gap look wider than its neighbour. Doing this after
-- SortBars keeps the visual stride exact without touching the mode data.
snapBarRows = function(win)
	local g = win and win.bargroup
	if not g then return end
	local es = g:GetEffectiveScale() or 1
	if es <= 0 then es = 1 end
	local thickness = g:GetThickness() or win.db.barheight or 22
	local spacing = g:GetSpacing() or win.db.barspacing or 0
	local heightPx = math.max(1, math.floor(thickness * es + 0.5))
	local gapPx = math.max(0, math.floor(spacing * es + 0.5))
	local stride = (heightPx + gapPx) / es
	local height = heightPx / es
	local topInset = gapPx / es

	local visible = {}
	for _, bar in pairs(g:GetBars() or {}) do
		if bar:IsShown() then visible[#visible + 1] = bar end
	end
	if #visible == 0 then return end

	table.sort(visible, function(a, b)
		if g.growup then return (a:GetBottom() or 0) < (b:GetBottom() or 0) end
		return (a:GetTop() or 0) > (b:GetTop() or 0)
	end)

	for i, bar in ipairs(visible) do
		bar:ClearAllPoints()
		if g.growup then
			bar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, (i - 1) * stride + topInset)
			bar:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, (i - 1) * stride + topInset)
		else
			bar:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -(i - 1) * stride - topInset)
			bar:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, -(i - 1) * stride - topInset)
		end
		bar:SetHeight(height)
	end
end

local SCHOOL_COLORS = {
	[1] = {r = 1, g = 0.82, b = 0.17},
	[2] = {r = 0.96, g = 0.91, b = 0.11},
	[4] = {r = 0.89, g = 0.33, b = 0.10},
	[8] = {r = 0.31, g = 0.81, b = 0.19},
	[16] = {r = 0.40, g = 0.86, b = 0.96},
	[32] = {r = 0.61, g = 0.39, b = 0.76},
	[64] = {r = 0.92, g = 0.47, b = 0.88},
}

local function setBarColor(bar, data, win)
	local r, g, b, a
	if data.color then
		r, g, b, a = data.color.r, data.color.g, data.color.b, data.color.a or 1
	elseif data.spellschool and not issecretvalue(data.spellschool) and win.db.spellschoolcolors then
		local color = SCHOOL_COLORS[data.spellschool]
		if color then r, g, b, a = color.r, color.g, color.b, color.a or 1 end
	elseif data.class and not issecretvalue(data.class) and win.db.classcolorbars then
		local color = Skada.classcolors[data.class]
		if color then
			r, g, b, a = color.r, color.g, color.b, color.a or 1
			local mix, amount = win.db.classcolormix, win.db.classcolormixamount
			if mix and amount and amount > 0 then
				r = r * (1 - amount) + mix.r * amount
				g = g * (1 - amount) + mix.g * amount
				b = b * (1 - amount) + mix.b * amount
			end
		end
	end
	if not r then
		local color = win.db.barcolor
		r, g, b, a = color.r, color.g, color.b, color.a or 1
	end
	local cached = bar._skadaColor
	if cached and bar.colors and #bar.colors > 0
		and cached[1] == r and cached[2] == g and cached[3] == b and cached[4] == a then
		return
	end
	bar._skadaColor = { r, g, b, a }
	bar:UnsetAllColors()
	bar:SetColorAt(0, r, g, b, a)
end

local function setBarTextColor(bar, data, win)
	if data.class and not issecretvalue(data.class) and win.db.classcolortext then
		local color = Skada.classcolors[data.class]
		if color then
			bar.label:SetTextColor(color.r, color.g, color.b, color.a or 1)
			if bar.columns then
				for i = 1, 3 do
					if bar.columns[i] then
						bar.columns[i]:SetTextColor(color.r, color.g, color.b, color.a or 1)
					end
				end
			end
			return
		end
	end
	local ltc = win.db.labelcolor
	if ltc then
		bar.label:SetTextColor(ltc.r, ltc.g, ltc.b, ltc.a or 1)
	else
		bar.label:SetTextColor(1, 1, 1, 1)
	end
	local vtc = win.db.valuetextcolor
	if bar.columns then
		for i = 1, 3 do
			if bar.columns[i] then
				if vtc then
					bar.columns[i]:SetTextColor(vtc.r, vtc.g, vtc.b, vtc.a or 1)
				else
					bar.columns[i]:SetTextColor(1, 1, 1, 1)
				end
			end
		end
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
	-- Some modes may alter title continously, but most ticks repeat the same
	-- string. Secret titles still need a write (they cannot be compared).
	local title = win.metadata.title
	local titleSecret = issecretvalue(title)
	local fs = win.bargroup.button:GetFontString()
	if titleSecret or win._lastTitleText ~= title then
		win._lastTitleText = titleSecret and nil or title
		if fs then
			fs:SetText(title)
		else
			win.bargroup.button:SetText(title)
		end
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

	local columnSpec = buildColumnSpec(win)
	win._columnSpec = columnSpec
	local nr = 1
	local activeBarIds = {}
	for i, data in ipairs(win.dataset) do
		if data.id then
			local barid = data.id
			local barlabel = data.label
			activeBarIds[barid] = true

			local bar = win.bargroup:GetBar(barid)

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

			end

			bar.text = barlabel
			bar.link = nil
			bar.spellid = nil
			bar.sourceGUID = data.sourceGUID
			bar.sourceCreatureID = data.sourceCreatureID
			if data.spellid then
				bar.spellid = data.spellid
			elseif data.hyperlink then
				bar.link = data.hyperlink
			end


			if data.role and data.role ~= "NONE" and win.db.roleicons then
				bar:ShowIcon()
				bar:SetIconWithCoord("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", mod.role_icon_tcoords[data.role])
			elseif data.class and win.db.classicons and mod.class_icon_tcoords[data.class] then
				bar:ShowIcon()
				bar:SetIconWithCoord("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes", mod.class_icon_tcoords[data.class])
			elseif data.icon ~= nil then
				bar:ShowIcon()
				bar:SetIcon(data.icon)
				if bar.icon then bar.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) end
			else
				bar:HideIcon()
			end
			if data.role and data.role ~= "NONE" and win.db.roleicons
				or (data.class and win.db.classicons and mod.class_icon_tcoords[data.class])
				or data.icon ~= nil then
				bar.iconFrame.bar = bar
				bar.iconFrame:EnableMouse(true)
				bar.iconFrame:SetScript("OnEnter", BarIconEnter)
				bar.iconFrame:SetScript("OnLeave", HideGameTooltip)
				bar.iconFrame:SetScript("OnMouseDown", BarIconMouseDown)
			else
				bar.iconFrame:EnableMouse(false)
			end

			local isSelf = data.isSelf == true
			if not isSelf and type(data.id) == "string" and not issecretvalue(data.id) then
				local playerGUID = UnitGUID("player")
				if type(playerGUID) == "string" and not issecretvalue(playerGUID) then
					isSelf = data.id == playerGUID
				end
			end
			if Skada.db.profile.showself and data.id and isSelf then
				bar.fixed = true
				bar.isSelfBar = true
			else
				bar.isSelfBar = false
			end

			setBarColor(bar, data, win)
			setBarTextColor(bar, data, win)

			if win.metadata.ordersort then
				bar.order = i
			end

			-- Secret names cannot safely be composed with a rank prefix via
			-- string.format. Pass them straight to the FontString instead.
			if win.metadata.showspots and Skada.db.profile.showranks and not data.ignore
				and not issecretvalue(data.label) then
				if win.db.barorientation == 1 then
					bar:SetLabel(("%2u. %s"):format(nr, data.label))
				else
					bar:SetLabel(("%s %2u"):format(data.label, nr))
				end
			else
				bar:SetLabel(data.label)
			end

			if data.valuetext then
				bar:SetColumnText(1, nil)
				bar:SetColumnText(2, nil)
				bar:SetColumnText(3, data.valuetext)
			else
				bar:SetColumnText(1, nil)
				bar:SetColumnText(2, nil)
				bar:SetColumnText(3, nil)
				local firstSlot = 4 - #columnSpec
				for ci = 1, #columnSpec do
					bar:SetColumnText(firstSlot + ci - 1, data[columnSpec[ci].value])
				end
			end
			applyColumnGeometry(bar)

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
	snapBarRows(win)
	-- Rebuild labels every update. The secret-state transition at combat end
	-- can happen inside the mode update, so a cached header state is not a
	-- reliable guard. This also keeps the 2-column combat / 3-column
	-- post-combat layouts in sync with the actual value columns.
	applyColumnHeaders(win, win.db)
	if win.bargroup._titleHover then
		titleHover(win, true)
	end

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
	snapBarRows(group.win)
end

function mod:Show(win)
	win.bargroup:Show()
	win.bargroup:SortBars()
	snapBarRows(win)
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
	snapBarRows(win)
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

-- Single source of truth for the right-aligned column order. The same list
-- drives header labels and the value-column layout; there are no per-order
-- saved offsets that can go stale.
local COLUMN_WIDTH = 64
local COLUMN_GAP = 6
local COLUMN_RIGHT_PAD = 4
local function columnRightOffset(slot)
	return COLUMN_RIGHT_PAD + (3 - slot) * (COLUMN_WIDTH + COLUMN_GAP)
end

function applyColumnGeometry(bar)
	if not bar or not bar.columns then return end
	-- Apply on every update: the bar library re-anchors columns when the bar
	-- size changes, which would otherwise leave header labels and values
	-- aligned to different right edges.
	local c3 = bar.columns[3]
	if c3 then
		c3:ClearAllPoints()
		c3:SetPoint("RIGHT", bar, "RIGHT", -COLUMN_RIGHT_PAD, 0)
		c3:SetWidth(COLUMN_WIDTH)
		c3:SetJustifyH("RIGHT")
	end
	local c2 = bar.columns[2]
	if c2 and c3 then
		c2:ClearAllPoints()
		c2:SetPoint("RIGHT", c3, "LEFT", -COLUMN_GAP, 0)
		c2:SetWidth(COLUMN_WIDTH)
		c2:SetJustifyH("RIGHT")
	end
	local c1 = bar.columns[1]
	if c1 and c2 then
		c1:ClearAllPoints()
		c1:SetPoint("RIGHT", c2, "LEFT", -COLUMN_GAP, 0)
		c1:SetWidth(COLUMN_WIDTH)
		c1:SetJustifyH("RIGHT")
	end
end

function applyColumnHeaders(win, p)
	local g = win.bargroup
	local header = g.columnheaders
	local mode = win.selectedmode
	local columns = mode and mode.metadata and mode.metadata.columns
	local hasColumns = type(columns) == "table" and (columns.Damage or columns.Healing)
	local spec = buildColumnSpec(win)
	hasColumns = hasColumns or #spec > 0

	g.headerSignature = hasColumns and ((mode and mode:GetName() or "") .. ":" .. (columns.Damage and "D" or "H")) or nil

	if not p.showcolumnheaders or #spec == 0 then
		if header then header:Hide() end
		return 0
	end

	local height = p.columnheadersheight or 8
	if not header then
		header = CreateFrame("Frame", nil, g.button)
		header.labels = {}
		for i = 1, 3 do
			local f = header:CreateFontString(nil, "OVERLAY")
			f:SetJustifyH("RIGHT")
			f:SetJustifyV("MIDDLE")
			header.labels[i] = f
		end
		g.columnheaders = header
	end

	-- With hover-only buttons the header has the title bar to itself, so align
	-- its text with the title's vertical center. When buttons are always
	-- visible, keep the compact bottom strip so they do not overlap.
	header:ClearAllPoints()
	if p.hoverbuttons then
		header:SetPoint("TOPLEFT", g.button, "TOPLEFT", 0, 0)
		header:SetPoint("BOTTOMRIGHT", g.button, "BOTTOMRIGHT", 0, 0)
	else
		header:SetPoint("BOTTOMLEFT", g.button, "BOTTOMLEFT", 0, p.columnheaderbottom or 2)
		header:SetPoint("BOTTOMRIGHT", g.button, "BOTTOMRIGHT", 0, p.columnheaderbottom or 2)
		header:SetHeight(height)
	end
	header:Show()

	local font = p.columnheaderfontpath or media:Fetch("font", p.columnheaderfont or p.barfont)
	local c = p.columnheadertextcolor or p.title.textcolor or {r = 0.8, g = 0.9, b = 1, a = 1}
	local headerKey = table.concat({
		mode and mode.GetName and mode:GetName() or "none",
		tostring(#spec),
		tostring(p.showcolumnheaders),
		tostring(p.columnheaderfont or p.barfont),
		tostring(p.columnheaderfontsize or 8),
		tostring(p.columnheaderfontflags or ""),
		tostring(c.r) .. "," .. tostring(c.g) .. "," .. tostring(c.b),
	}, ":")
	if header._headerKey == headerKey then return height end
	header._headerKey = headerKey

	for i = 1, 3 do
		local f = header.labels[i]
		f:SetFont(font, p.columnheaderfontsize or 8, p.columnheaderfontflags or "")
		f:SetTextColor(c.r, c.g, c.b, (c.a or 1) * 0.80)
		applyFontShadow(f, p.textshadow)
		f:Hide()
	end

	-- Right-align the available columns. Two-column combat layouts therefore
	-- occupy slots 2/3, matching the value layout; after combat the third slot
	-- returns for Percent. No offsets are read from the profile.
	local firstSlot = 4 - #spec
	for i = 1, #spec do
		local slot = firstSlot + i - 1
		local f = header.labels[slot]
		if f then
			f:SetText(spec[i].label)
			f:ClearAllPoints()
			f:SetPoint("RIGHT", header, "RIGHT", -columnRightOffset(slot), 0)
			f:Show()
		end
	end

	return height
end

function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
	local bar = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon)
	bar.win = win
	bar._skadaColor = nil
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
	-- Snap row height and spacing to whole physical pixels. At non-integer UI
	-- scales, fractional heights make the row step alternate between N and
	-- N+1 pixels, which reads as an inconsistent 1px gap between some bars.
	local uiScale = g:GetEffectiveScale() or 1
	if uiScale <= 0 then uiScale = 1 end
	local function snapPixels(value)
		return math.floor((value or 0) * uiScale + 0.5) / uiScale
	end
	g:SetBarHeight(snapPixels(p.barheight))
	g:SetHeight(p.background.height)
	g:SetWidth(p.barwidth)
	g:SetLength(p.barwidth)
	g:SetTexture(p.bartexturepath or media:Fetch('statusbar', p.bartexture))

	local bgAlpha = p.transparentbackground and 0 or (p.barbgcolor.a or 0.6)
	g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, bgAlpha)
	if g:GetBars() then
		for _, bar in pairs(g:GetBars()) do
			bar._skadaColor = nil
			applyRowSeparator(bar, p)
			applyBarShadows(bar, p.textshadow)
		end
	end
	g:SetFont(p.barfontpath or media:Fetch('font', p.barfont), p.barfontsize, p.barfontflags)
	if g.button then
		g.button:EnableMouseWheel(false)
		g.button:SetScript("OnMouseWheel", nil)
	end
	g:SetSpacing(snapPixels(p.barspacing))
	g:UnsetAllColors()
	g:SetColorAt(0,p.barcolor.r,p.barcolor.g,p.barcolor.b, p.barcolor.a)
	if p.barslocked then
		g:Lock()
	else
		g:Unlock()
	end
	snapBarRows(win)

	if p.strata then g:SetFrameStrata(p.strata) end

	-- Header
	local fo = CreateFont("TitleFont"..win.db.name)
	local titleFontPath = p.title.fontpath or media:Fetch('font', p.title.font)
	if not titleFontPath then
		-- Expressway is registered by EllesmereUI when present; keep a sensible
		-- bundled fallback for profiles created without that font available.
		titleFontPath = media:Fetch('font', "Cinzel") or media:Fetch('font', "ABF") or "Fonts\\FRIZQT__.TTF"
	end
	fo:SetFont(titleFontPath, p.title.fontsize, p.title.fontflags)
	if p.title.textcolor then
		fo:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a)
	end
	g.button:SetNormalFontObject(fo)

	local baseTitleHeight = p.title.height or 15
	local headerHeight = applyColumnHeaders(win, p)
	local titleRowHeight = baseTitleHeight
	if headerHeight > 0 then
		titleRowHeight = max(baseTitleHeight - headerHeight, 18)
	end
	g.button:SetHeight(baseTitleHeight)

	-- Keep the title at the same vertical anchor whether or not the column
	-- header strip is present. The header strip belongs to the bottom of the
	-- bar and must not shift the title text.
	local fs = g.button:GetFontString()
	if fs then
		fs:SetJustifyH(p.title.textalign or "LEFT")
		fs:SetJustifyV("MIDDLE")
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", g.button, "LEFT", p.title.paddingleft or 10, TITLE_TEXT_Y)
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
	g._normalButtonOffset = buttonOffset
	g:SetButtonLayout(p.buttonspacing or 3, p.buttonpaddingright or 8, buttonSize, buttonOffset)

	-- Button visibility.
	g:ShowButton(L["Configure"], p.buttons.menu)
	g:ShowButton(L["Reset"], p.buttons.reset)
	g:ShowButton(L["Mode"], p.buttons.mode)
	g:ShowButton(L["Segment"], p.buttons.segment)
	g:ShowButton(L["Report"], p.buttons.report)
	-- g:ShowButton(L["Stop"], p.buttons.stop)

	g:SetButtonsOpacity(((p.hoverbuttons ~= false) and g.button:IsMouseOver()) and 1 or ((p.hoverbuttons ~= false) and 0 or 0.25))
	if g._titleHover then
		titleHover(win, true)
	end

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

			transparentbackground = {
				type="toggle",
				name=L["Transparent bar background"],
				desc=L["Hides the unfilled part of the bars by making the bar background fully transparent."],
				order=23,
				get=function() return db.transparentbackground end,
				set=function()
					db.transparentbackground = not db.transparentbackground
					Skada:ApplySettings()
				end,
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
