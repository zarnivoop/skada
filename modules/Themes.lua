local _, Skada = ...
Skada:AddLoadableModule("Themes", "Adds a set of standard theme presets to Skada.", function(Skada, L)
	if Skada.db.profile.modulesBlocked.Themes then return end

	-- Built-in theme presets (read-only)
	Skada.themePresets = {
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
			useframe = true,
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
			modeincombat = "",
			scale = 1,
			enabletitle = true,
			classcolorbars = true,
			isusingclasscolors = true,
			returnaftercombat = false,
			showself = true,
			height = 30,
		},
		{
			name = "Skada default (ElvUI)",

			barspacing=0,
			bartexture="BantoBar",
			barfont="Expressway",
			barfontflags="",
			barfontsize=10,
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

			title = {textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1}, height = 18, font="Expressway", barfontsize=10, fontsize=10, texture="Armory", bordercolor = {r=0,g=0,b=0,a=1}, bordertexture="None", borderthickness=2, color = {r=0.3,g=0.3,b=0.3,a=1}, fontflags = ""},
			background = {
				height=200,
				texture="Solid",
				bordercolor = {r=0,g=0,b=0,a=1},
				bordertexture="Blizzard Party",
				borderthickness=1,
				color = {r=0,g=0,b=0,a=0.8},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",
			scale = 1,

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
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
			useframe = true
		},

		{
			name = "Legion-era default theme",

			barspacing=0,
			bartexture="BantoBar",
			barfont="Accidental Presidency",
			barfontflags="",
			barfontsize=13,
			barheight=18,
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

			title = {textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1}, height = 20, font="Accidental Presidency", fontsize=13, texture="Armory", bordercolor = {r=0,g=0,b=0,a=1}, bordertexture="None", borderthickness=2, color = {r=0.3,g=0.3,b=0.3,a=1}, fontflags = ""},
			background = {
				height=200,
				texture="Solid",
				bordercolor = {r=0,g=0,b=0,a=1},
				bordertexture="Blizzard Party",
				borderthickness=2,
				color = {r=0,g=0,b=0,a=0.4},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",
			scale = 1,

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
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
			useframe = true
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
			useframe = true
		},

		{
			name = "All glowy 'n stuff",

			barspacing=0,
			bartexture="LiteStep",
			barfont="ABF",
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

			title = {textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1}, height = 20, font="ABF", fontsize=12, texture="Aluminium", bordercolor = {r=0,g=0,b=0,a=1}, bordertexture="None", borderthickness=0, color = {r=0.6,g=0.6,b=0.8,a=1}, fontflags = ""},
			background = {
				height=195,
				texture="None",
				bordercolor = {r=0.9,g=0.9,b=0.5,a=0.6},
				bordertexture="Glow",
				borderthickness=5,
				color = {r=0,g=0,b=0,a=0.4},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",
			scale = 1,

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
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
			useframe = true
		},

		{
			name = "Neon",

			barspacing=1,
			bartexture="Armory",
			barfont="ABF",
			barfontflags="OUTLINE",
			barfontsize=10,
			barheight=16,
			barwidth=260,
			barorientation=1,
			barcolor = {r = 0.1, g = 0.6, b = 1, a=1},
			barbgcolor = {r = 0.05, g = 0.05, b = 0.1, a = 0.85},
			barslocked=false,
			clickthrough=false,

			classcolorbars = true,
			classcolortext = false,
			classicons = true,
			roleicons = false,
			showself = true,
			spellschoolcolors = true,

			alternaterows = true,
			highlightself = true,
			selfhighlightcolor = {r = 0.4, g = 0.8, b = 1, a = 0.15},
			spark = true,
			barfill = false,
			iconscale = 100,
			smoothing = true,

			buttons = {menu = true, reset = true, report = true, mode = true, segment = true},

			title = {textcolor = {r = 0.6, g = 0.9, b = 1, a = 1}, height = 20, font="ABF", fontsize=10, texture="Armory", bordercolor = {r=0,g=0.5,b=1,a=0.6}, bordertexture="None", borderthickness=0, color = {r=0.02,g=0.05,b=0.15,a=1}, color2 = {r=0.1,g=0.2,b=0.4,a=1}, fontflags = "OUTLINE", textalign = "LEFT"},
			background = {
				height=195,
				texture="None",
				bordercolor = {r=0,g=0.6,b=1,a=0.5},
				bordertexture="Glow",
				borderthickness=4,
				color = {r=0.01,g=0.01,b=0.05,a=0.9},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",
			scale = 1,

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
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
			useframe = true
		},

		{
			name = "Transparent",

			barspacing=1,
			bartexture="Armory",
			barfont="ABF",
			barfontflags="OUTLINE",
			barfontsize=10,
			barheight=16,
			barwidth=240,
			barorientation=1,
			barcolor = {r = 0.4, g = 0.4, b = 0.6, a=0.5},
			barbgcolor = {r = 0.1, g = 0.1, b = 0.1, a = 0.25},
			barslocked=false,
			clickthrough=false,

			classcolorbars = true,
			classcolortext = false,
			classicons = true,
			roleicons = false,
			showself = true,
			spellschoolcolors = true,

			alternaterows = false,
			highlightself = true,
			selfhighlightcolor = {r = 1, g = 1, b = 1, a = 0.08},
			spark = false,
			barfill = false,
			iconscale = 100,
			smoothing = true,

			buttons = {menu = true, reset = true, report = true, mode = true, segment = true},

			title = {textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 0.8}, height = 16, font="ABF", fontsize=10, texture="Armory", bordercolor = {r=0,g=0,b=0,a=0}, bordertexture="None", borderthickness=0, color = {r=0.1,g=0.1,b=0.1,a=0.3}, fontflags = "OUTLINE", textalign = "CENTER"},
			background = {
				height=195,
				texture="None",
				bordercolor = {r=0,g=0,b=0,a=0},
				bordertexture="None",
				borderthickness=0,
				color = {r=0,g=0,b=0,a=0},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",
			scale = 1,

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
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
			useframe = true
		},

		{
			name = "Compact",

			barspacing=0,
			bartexture="Armory",
			barfont="ABF",
			barfontflags="",
			barfontsize=9,
			barheight=12,
			barwidth=200,
			barorientation=1,
			barcolor = {r = 0.25, g = 0.25, b = 0.5, a=1},
			barbgcolor = {r = 0.15, g = 0.15, b = 0.15, a = 0.7},
			barslocked=false,
			clickthrough=false,

			classcolorbars = true,
			classcolortext = false,
			classicons = false,
			roleicons = false,
			showself = true,
			spellschoolcolors = true,

			alternaterows = true,
			highlightself = false,
			selfhighlightcolor = {r = 1, g = 1, b = 1, a = 0.12},
			spark = false,
			barfill = false,
			iconscale = 100,
			smoothing = true,

			buttons = {menu = true, reset = false, report = false, mode = true, segment = true},

			title = {textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1}, height = 14, font="ABF", fontsize=9, texture="Armory", bordercolor = {r=0,g=0,b=0,a=1}, bordertexture="None", borderthickness=0, color = {r=0.15,g=0.15,b=0.2,a=1}, fontflags = "", textalign = "LEFT"},
			background = {
				height=120,
				texture="None",
				bordercolor = {r=0,g=0,b=0,a=1},
				bordertexture="None",
				borderthickness=0,
				color = {r=0,g=0,b=0,a=0.5},
				tile = false,
				tilesize = 0,
			},

			strata = "LOW",
			scale = 1,

			hidden = false,
			enabletitle = true,
			titleset = true,

			display = "bar",
			snapto = true,
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
			useframe = true
		}
	}

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
		Skada:tcopy(win.db, theme, {"name", "modeincombat", "display", "set", "mode", "wipemode", "returnaftercombat"})
		Skada:ApplySettings()
	end

end)
