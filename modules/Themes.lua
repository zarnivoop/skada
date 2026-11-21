local _, Skada = ...
Skada:AddLoadableModule("Themes", "Adds a set of standard theme presets to Skada.", function(Skada, L)
	if Skada.db.profile.modulesBlocked.Themes then return end

	-- Built-in theme presets (read-only)
	Skada.themePresets = {
		{
			name = "Forever: Skyborne",
			barspacing=1,
			bartexture="Forever Bar",
			barfont=Skada.ThemeFonts.bar,
			barfontflags="",
			barfontsize=13,
			barheight=22,
			barwidth=470,
			barorientation=1,
			barcolor = {r = 0.35, g = 0.55, b = 0.70, a = 1},
			barbgcolor = {r = 0.012, g = 0.014, b = 0.018, a = 0.10},
			labelcolor = {r = 0.97, g = 0.98, b = 1.00, a = 1},
			valuetextcolor = {r = 0.96, g = 0.97, b = 1.00, a = 1},
			classcolorbars = true,
			classcolormix = {r = 0.03, g = 0.07, b = 0.13, a = 1},
			classcolormixamount = 0.50,
			classcolortext = false,
			classicons = true,
			roleicons = false,
			showself = true,
			alternaterows = false,
			highlightself = true,
			selfhighlightcolor = {r = 0.55, g = 0.85, b = 1.00, a = 0.10},
			spark = false,
			barfill = false,
			iconscale = 100,
			barinset = 1,
			smoothing = true,
			buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
			hoverbuttons = true,
			buttonspacing = 6,
			buttonsize = 15,
			buttonpaddingright = 10,
			totalicon = [[Interface\AddOns\Skada\media\icons\ForeverCrest]],
			showcolumnheaders = true,
			columnheadersheight = 8,
			columnheaderfontsize = 8,
			columnheaderfontflags = "",
			columnheaderfont = Skada.ThemeFonts.header,
			textshadow = false,
			columnheaderbottom = 6,
			columnheadertextcolor = {r = 0.95, g = 0.97, b = 1.00, a = 1},
			showrowseparators = false,
			rowseparatorcolor = {r = 0.45, g = 0.62, b = 0.75, a = 0.25},
			title = {textcolor = {r = 0.98, g = 0.99, b = 1.00, a = 1}, height = 30, font=Skada.ThemeFonts.title, fontsize=13,
				paddingleft = 12, paddingtop = 3,
				texture="Forever Bar", bordercolor = {r = 0.32, g = 0.48, b = 0.62, a = 0.12}, bordertexture="Forever Line",
				borderthickness = 1, color = {r = 0.06, g = 0.11, b = 0.20, a = 0.68}, color2 = {r = 0.015, g = 0.028, b = 0.055, a = 0.68}, fontflags = "", textalign = "LEFT"},
			background = {height = 300, texture="None", bordercolor = {r = 0.30, g = 0.45, b = 0.58, a = 0.20},
				bordertexture="Forever Line", borderthickness = 1, color = {r = 0.014, g = 0.016, b = 0.020, a = 0.10}, tile = false, tilesize = 0},
			display = "bar",
			version = 1,
			strata = "LOW",
			scale = 1,
			enabletitle = true,
			titleset = true,
			width = 470,
			height = 30,
		},
		{
			name = "Midnight Glass",
			barspacing=2,
			bartexture="Skada Glass",
			barfont="ABF",
			barfontflags="OUTLINE",
			barfontsize=11,
			barheight=20,
			barwidth=260,
			barorientation=1,
			barcolor = {r = 0.2, g = 0.5, b = 0.9, a=1},
			barbgcolor = {r = 0, g = 0, b = 0, a = 0.3},
			classcolorbars = true,
			classcolortext = false,
			classicons = true,
			roleicons = true,
			showself = true,
			alternaterows = true,
			highlightself = true,
			selfhighlightcolor = {r = 1, g = 1, b = 1, a = 0.15},
			spark = true,
			barfill = false,
			iconscale = 110,
			barinset = 1,
			smoothing = true,
			buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
			title = {textcolor = {r = 1, g = 1, b = 1, a = 1}, height = 22, font="ABF", fontsize=11, texture="Skada Glass", bordercolor = {r=0,g=0,b=0,a=0}, bordertexture="None", borderthickness=0, color = {r=0.05,g=0.1,b=0.2,a=0.9}, color2 = {r=0.1,g=0.3,b=0.6,a=0.9}, fontflags = "OUTLINE", textalign = "LEFT"},
			background = {height=200, texture="None", bordercolor = {r=1,g=1,b=1,a=0.1}, bordertexture="None", borderthickness=1, color = {r=0,g=0,b=0,a=0.4}},
			display = "bar",
			version = 1,
		},
		{
			name = "Clear Material",
			barspacing=1,
			bartexture="Skada Material",
			barfont="ABF",
			barfontflags="",
			barfontsize=10,
			barheight=18,
			barwidth=260,
			barorientation=1,
			barcolor = {r = 0.5, g = 0.5, b = 0.5, a=1},
			barbgcolor = {r = 0, g = 0, b = 0, a = 0},
			classcolorbars = true,
			classcolortext = true,
			classicons = true,
			roleicons = false,
			showself = true,
			alternaterows = false,
			highlightself = true,
			selfhighlightcolor = {r = 1, g = 1, b = 1, a = 0.1},
			spark = false,
			barfill = false,
			iconscale = 100,
			barinset = 0,
			smoothing = true,
			buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
			title = {textcolor = {r = 0.8, g = 0.8, b = 0.8, a = 1}, height = 18, font="ABF", fontsize=10, texture="Skada Material", bordercolor = {r=0,g=0,b=0,a=0.2}, bordertexture="None", borderthickness=0, color = {r=0.1,g=0.1,b=0.1,a=0.8}, fontflags = "", textalign = "LEFT"},
			background = {height=180, texture="None", bordercolor = {r=0,g=0,b=0,a=0}, bordertexture="None", borderthickness=0, color = {r=0,g=0,b=0,a=0}},
			display = "bar",
			version = 1,
		},
		{
			name = "Midnight",
			titleset = true,
			barheight = 16,
			color = { a = 0.6, r = 0.3, g = 0.3, b = 0.3, },
			issolidbackdrop = false,
			classicons = true,
			barslocked = false,
			clickthrough = false,
			wipemode = "",
			set = "current",
			hidden = false,
			title = { textcolor = { a = 1, r = 0.9, g = 0.9, b = 0.9, }, color = { a = 1, r = 0.10196079313755, g = 0.23921570181847, b = 0.30196079611778, }, bordercolor = { a = 1, r = 0, g = 0, b = 0, }, barfontsize = 10, font = "ABF", fontsize = 10, height = 18, fontflags = "", bordertexture = "None", borderthickness = 2, texture = "Armory", },
			display = "bar",
			barfontflags = "",
			isusingelvuiskin = true,
			barfont = "ABF",
			strata = "LOW",
			classcolortext = false,
			spellschoolcolors = true,
			barbgcolor = { a = 0.6, r = 0.3, g = 0.3, b = 0.3, },
			barcolor = { a = 1, r = 0.3, g = 0.3, b = 0.8, },
			background = { height = 128, bordertexture = "None", borderthickness = 0, tile = false, color = { a = 0.047262098640203, r = 0, g = 0, b = 0, }, bordercolor = { a = 1, r = 0, g = 0, b = 0, }, tilesize = 0, texture = "None", },
			barfontsize = 10,
			version = 1,
			roleicons = false,
			barorientation = 1,
			snapto = true,
			isonnewline = false,
			fixedbarwidth = false,
			width = 600,
			textcolor = { r = 0.9, g = 0.9, b = 0.9, },
			buttons = { segment = true, menu = true, mode = true, report = true, reset = true, },
			bartexture = "Armory",
			barwidth = 260,
			barspacing = 0,
			reversegrowth = false,
			smoothing = true,
			modeincombat = "auto",
			scale = 1,
			enabletitle = true,
			classcolorbars = true,
			isusingclasscolors = true,
			returnaftercombat = false,
			showself = true,
			height = 30,
		},

		{
			name = "Minimalistic",

			barspacing=0,
			bartexture="Armory",
			barfont="Accidental Presidency",
			barfontflags="",
			barfontsize=12,
			barheight=16,
			barwidth=240,
			barorientation=1,
			barcolor = {r = 0.3, g = 0.3, b = 0.8, a=1},
			barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
			barslocked=false,
			clickthrough=false,

			classcolorbars = true,
			classcolortext = false,
			classicons = true,
			roleicons = false,
			showself = true,

			buttons = {menu = true, reset = true, report = true, mode = true, segment = true},

			title = {textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1}, height = 18, font="Accidental Presidency", fontsize=12, texture="Armory", bordercolor = {r=0,g=0,b=0,a=1}, bordertexture="None", borderthickness=0, color = {r=0.6,g=0.6,b=0.8,a=1}, fontflags = ""},
			background = {
				height=195,
				texture="None",
				bordercolor = {r=0,g=0,b=0,a=1},
				bordertexture="Blizzard Party",
				borderthickness=0,
				color = {r=0,g=0,b=0,a=0.4},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
			scale = 1,
			version = 1,

			isonnewline = false,
			isusingclasscolors = true,
			height = 30,
			width = 600,
			color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
			isusingelvuiskin = true,
			issolidbackdrop = false,
			fixedbarwidth = false,

			textcolor = {r = 0.9, g = 0.9, b = 0.9},
		},


	}

	-- Curated Forever variants share Skyborne's layout and typography but use
	-- distinct palettes. They are inserted right after Skyborne in the picker.
	local baseTheme = Skada.themePresets[1]

	local function mergeTheme(target, source)
		for k, v in pairs(source) do
			if type(v) == "table" then
				if type(target[k]) ~= "table" then target[k] = {} end
				mergeTheme(target[k], v)
			else
				target[k] = v
			end
		end
	end

	-- Variants are full style presets, not just palettes: bar geometry, icons,
	-- header/separator treatment and title framing all change with the theme.
	local function addForeverVariant(index, name, settings)
		local theme = {}
		Skada:tcopy(theme, baseTheme)
		theme.name = name
		mergeTheme(theme, settings)
		table.insert(Skada.themePresets, index, theme)
	end

	addForeverVariant(2, "Forever: Forge", {
		barheight = 20,
		barspacing = 2,
		barinset = 2,
		bartexture = "Forever Bar",
		barcolor = { r = 0.62, g = 0.28, b = 0.12, a = 1 },
		barbgcolor = { r = 0.020, g = 0.012, b = 0.008, a = 0.55 },
		labelcolor = { r = 1.00, g = 0.94, b = 0.86, a = 1 },
		valuetextcolor = { r = 1.00, g = 0.88, b = 0.70, a = 1 },
		classcolormix = { r = 0.20, g = 0.07, b = 0.02, a = 1 },
		classcolormixamount = 0.65,
		classicons = true,
		roleicons = true,
		spark = true,
		barfill = true,
		alternaterows = false,
		showrowseparators = true,
		rowseparatorcolor = { r = 0.85, g = 0.45, b = 0.18, a = 0.35 },
		columnheadertextcolor = { r = 1.00, g = 0.88, b = 0.72, a = 1 },
		title = {
			height = 28,
			font = Skada.ThemeFonts.title,
			fontsize = 14,
			texture = "Armory",
			bordertexture = "Forever Line",
			borderthickness = 2,
			color = { r = 0.10, g = 0.035, b = 0.015, a = 0.88 },
			color2 = { r = 0.020, g = 0.006, b = 0.002, a = 0.88 },
			bordercolor = { r = 0.95, g = 0.50, b = 0.20, a = 0.35 },
			textcolor = { r = 1.00, g = 0.90, b = 0.75, a = 1 },
			textalign = "LEFT",
		},
		background = {
			texture = "None",
			bordertexture = "Forever Line",
			borderthickness = 2,
			color = { r = 0.018, g = 0.010, b = 0.006, a = 0.55 },
			bordercolor = { r = 0.80, g = 0.35, b = 0.12, a = 0.35 },
		},
	})

	addForeverVariant(3, "Forever: Canopy", {
		barheight = 18,
		barspacing = 0,
		barinset = 0,
		bartexture = "Forever Bar",
		classcolorbars = false,
		classcolortext = false,
		barcolor = { r = 0.20, g = 0.62, b = 0.36, a = 1 },
		barbgcolor = { r = 0.005, g = 0.020, b = 0.012, a = 0.15 },
		labelcolor = { r = 0.88, g = 1.00, b = 0.92, a = 1 },
		valuetextcolor = { r = 0.82, g = 1.00, b = 0.88, a = 1 },
		classcolormix = { r = 0.02, g = 0.10, b = 0.05, a = 1 },
		classcolormixamount = 0.50,
		classicons = true,
		roleicons = true,
		spark = true,
		barfill = false,
		alternaterows = true,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.82, g = 1.00, b = 0.88, a = 1 },
		title = {
			height = 26,
			font = Skada.ThemeFonts.header,
			fontsize = 14,
			texture = "Skada Glass",
			bordertexture = "Forever Line",
			borderthickness = 1,
			color = { r = 0.020, g = 0.070, b = 0.040, a = 0.55 },
			color2 = { r = 0.005, g = 0.020, b = 0.010, a = 0.55 },
			bordercolor = { r = 0.30, g = 0.80, b = 0.50, a = 0.25 },
			textcolor = { r = 0.85, g = 1.00, b = 0.90, a = 1 },
			textalign = "CENTER",
		},
		background = {
			texture = "None",
			bordertexture = "Forever Line",
			borderthickness = 1,
			color = { r = 0.005, g = 0.018, b = 0.010, a = 0.08 },
			bordercolor = { r = 0.25, g = 0.60, b = 0.40, a = 0.25 },
		},
	})

	addForeverVariant(4, "Forever: Eclipse", {
		barheight = 24,
		barspacing = 3,
		barinset = 1,
		bartexture = "Skada Glass",
		classcolormix = { r = 0.12, g = 0.04, b = 0.20, a = 1 },
		classcolormixamount = 0.60,
		classicons = false,
		roleicons = false,
		barcolor = { r = 0.50, g = 0.30, b = 0.85, a = 1 },
		barbgcolor = { r = 0.015, g = 0.008, b = 0.030, a = 0.28 },
		labelcolor = { r = 0.93, g = 0.88, b = 1.00, a = 1 },
		valuetextcolor = { r = 0.88, g = 0.80, b = 1.00, a = 1 },
		spark = true,
		barfill = false,
		alternaterows = true,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.86, g = 0.78, b = 1.00, a = 1 },
		title = {
			height = 34,
			font = Skada.ThemeFonts.title,
			fontsize = 15,
			texture = "Skada Glass",
			bordertexture = "Glow",
			borderthickness = 1,
			color = { r = 0.050, g = 0.020, b = 0.100, a = 0.75 },
			color2 = { r = 0.010, g = 0.005, b = 0.030, a = 0.75 },
			bordercolor = { r = 0.60, g = 0.35, b = 0.95, a = 0.35 },
			textcolor = { r = 0.92, g = 0.85, b = 1.00, a = 1 },
			textalign = "LEFT",
		},
		background = {
			texture = "Skada Glass",
			bordertexture = "Glow",
			borderthickness = 1,
			color = { r = 0.010, g = 0.004, b = 0.025, a = 0.25 },
			bordercolor = { r = 0.55, g = 0.30, b = 0.90, a = 0.35 },
		},
	})

	-- Base64 encoding/decoding for compact theme strings
	local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local b64lookup = {}
	for i = 1, 64 do b64lookup[b64chars:sub(i, i)] = i - 1 end

	local function Base64Encode(data)
		local out = {}
		local len = #data
		for i = 1, len, 3 do
			local b1 = data:byte(i)
			local b2 = i + 1 <= len and data:byte(i + 1) or 0
			local b3 = i + 2 <= len and data:byte(i + 2) or 0
			local n = b1 * 65536 + b2 * 256 + b3
			out[#out+1] = b64chars:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
			out[#out+1] = b64chars:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
			out[#out+1] = i + 1 <= len and b64chars:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
			out[#out+1] = i + 2 <= len and b64chars:sub(n % 64 + 1, n % 64 + 1) or "="
		end
		return table.concat(out)
	end

	local function Base64Decode(data)
		data = data:gsub("[^" .. b64chars .. "=]", "")
		local out = {}
		for i = 1, #data, 4 do
			local c1 = b64lookup[data:sub(i, i)] or 0
			local c2 = b64lookup[data:sub(i+1, i+1)] or 0
			local c3 = b64lookup[data:sub(i+2, i+2)]
			local c4 = b64lookup[data:sub(i+3, i+3)]
			local n = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
			out[#out+1] = string.char(math.floor(n / 65536) % 256)
			if c3 then out[#out+1] = string.char(math.floor(n / 256) % 256) end
			if c4 then out[#out+1] = string.char(n % 256) end
		end
		return table.concat(out)
	end

	-- Simple recursive serializer (no loadstring needed)
	local function SerializeValue(v)
		local t = type(v)
		if t == "string" then
			return "s" .. #v .. ":" .. v
		elseif t == "number" then
			return "n" .. tostring(v) .. ";"
		elseif t == "boolean" then
			return v and "T" or "F"
		elseif t == "table" then
			local parts = {"t"}
			local count = 0
			for key, val in pairs(v) do
				parts[#parts+1] = SerializeValue(key) .. SerializeValue(val)
				count = count + 1
			end
			parts[1] = "t" .. count .. ":"
			return table.concat(parts)
		end
		return "Z" -- nil
	end

	local function DeserializeValue(str, pos)
		local tag = str:sub(pos, pos)
		if tag == "s" then
			local lenEnd = str:find(":", pos + 1)
			local len = tonumber(str:sub(pos + 1, lenEnd - 1))
			return str:sub(lenEnd + 1, lenEnd + len), lenEnd + len + 1
		elseif tag == "n" then
			local numEnd = str:find(";", pos + 1)
			return tonumber(str:sub(pos + 1, numEnd - 1)), numEnd + 1
		elseif tag == "T" then
			return true, pos + 1
		elseif tag == "F" then
			return false, pos + 1
		elseif tag == "t" then
			local countEnd = str:find(":", pos + 1)
			local count = tonumber(str:sub(pos + 1, countEnd - 1))
			local tbl = {}
			local p = countEnd + 1
			for _ = 1, count do
				local key, val
				key, p = DeserializeValue(str, p)
				val, p = DeserializeValue(str, p)
				tbl[key] = val
			end
			return tbl, p
		elseif tag == "Z" then
			return nil, pos + 1
		end
		return nil, pos + 1
	end

	local THEME_PREFIX = "!Skada!"

	-- Encode a theme table into a shareable string
	function Skada:EncodeTheme(theme)
		local serialized = SerializeValue(theme)
		return THEME_PREFIX .. Base64Encode(serialized)
	end

	-- Decode a theme string into a table. Returns success, theme.
	function Skada:DecodeTheme(str)
		str = str:match("^%s*(.-)%s*$") -- trim
		if str:sub(1, #THEME_PREFIX) ~= THEME_PREFIX then
			return false, nil
		end
		local b64data = str:sub(#THEME_PREFIX + 1)
		local ok, decoded = pcall(Base64Decode, b64data)
		if not ok or not decoded or #decoded == 0 then
			return false, nil
		end
		local ok2, result = pcall(DeserializeValue, decoded, 1)
		if ok2 and type(result) == "table" then
			return true, result
		end
		return false, nil
	end

	-- Show export dialog with copyable text
	local exportFrame = nil
	function Skada:ShowThemeExportDialog(text)
		if exportFrame then exportFrame:Hide() end

		local frame = CreateFrame("Frame", "SkadaThemeExport", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(480, 160)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
		frame:SetFrameStrata("TOOLTIP")
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
		frame.TitleBg:SetHeight(30)
		frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -8)
		frame.title:SetText(L["Export Theme"])

		local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		hint:SetPoint("TOP", frame, "TOP", 0, -38)
		hint:SetText(L["Copy the string below (Ctrl+C) and share it"])
		hint:SetTextColor(0.7, 0.7, 0.7)

		local editbox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		editbox:SetSize(430, 30)
		editbox:SetPoint("CENTER", frame, "CENTER", 0, -10)
		editbox:SetFontObject(ChatFontNormal)
		editbox:SetText(text)
		editbox:SetAutoFocus(true)
		editbox:HighlightText()
		editbox:SetScript("OnEscapePressed", function() frame:Hide() end)
		editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

		frame:SetScript("OnHide", function(self) self:SetParent(nil) exportFrame = nil end)
		exportFrame = frame
		frame:Show()
	end

	-- Apply a theme table to a window, preserving identity fields
	function Skada:ApplyThemeToWindow(win, theme)
		-- Themes are style presets, not display choices. Keep the current
		-- renderer and the user's ledger summary preference.
		Skada:tcopy(win.db, theme, {"name", "modeincombat", "display", "set", "mode", "wipemode", "returnaftercombat", "ledgersummary", "ledgertransparent"})
		local themeBg = theme.background and theme.background.color
		win.db.ledgertransparent = (themeBg and themeBg.a and themeBg.a <= 0.01) and true or false
		-- Bars cache their colors; rebuild them so the new palette is visible.
		win:Wipe()
		Skada:ApplySettings()
		Skada:UpdateDisplay(true)
	end

end)
