local _, Skada = ...
Skada:AddLoadableModule("Themes", "Adds a set of standard themes to Skada. Custom themes can also be used.", function(Skada, L)
	if Skada.db.profile.modulesBlocked.Themes then return end

	local themes = {
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
			y = 40.759735107422,
			x = -384.59716796875,
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
			point = "RIGHT",
			version = 1,
			mode = "Damage",
			roleicons = false,
			barorientation = 1,
			snapto = true,
			isonnewline = false,
			fixedbarwidth = false,
			width = 600,
			textcolor = { r = 0.9, g = 0.9, b = 0.9, },
			buttons = { segment = true, menu = true, mode = true, report = true, reset = true, },
			bartexture = "Armory",
			barwidth = 259.56884765625,
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

			-- Inline exclusive
			isonnewline = false,
			isusingclasscolors = true,
			height = 30,
			width = 600,
			color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
			isusingelvuiskin = true,
			issolidbackdrop = false,
			fixedbarwidth = false,

			-- Broker exclusive
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

			-- Inline exclusive
			isonnewline = false,
			isusingclasscolors = true,
			height = 30,
			width = 600,
			color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
			isusingelvuiskin = true,
			issolidbackdrop = false,
			fixedbarwidth = false,

			-- Broker exclusive
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

			-- Inline exclusive
			isonnewline = false,
			isusingclasscolors = true,
			height = 30,
			width = 600,
			color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
			isusingelvuiskin = true,
			issolidbackdrop = false,
			fixedbarwidth = false,

			-- Broker exclusive
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

			-- Inline exclusive
			isonnewline = false,
			isusingclasscolors = true,
			height = 30,
			width = 600,
			color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
			isusingelvuiskin = true,
			issolidbackdrop = false,
			fixedbarwidth = false,

			-- Broker exclusive
			textcolor = {r = 0.9, g = 0.9, b = 0.9},
			useframe = true
		}
	}

	local selectedwindow = nil
	local selectedtheme = nil
	local savewindow = nil
	local savename = nil
	local deletetheme = nil
	local exporttheme = nil
	local importtext = ""

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
			for i = 1, count do
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

	local function EncodeTheme(theme)
		local serialized = SerializeValue(theme)
		return THEME_PREFIX .. Base64Encode(serialized)
	end

	local function DecodeTheme(str)
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
	local function ShowExportDialog(text)
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
		-- Re-highlight on focus so user can always Ctrl+C
		editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

		frame:SetScript("OnHide", function(self) self:SetParent(nil) exportFrame = nil end)
		exportFrame = frame
		frame:Show()
	end

	local options = {
		type="group",
		name=L["Themes"],
		args={
			header2 = {
				type="header",
				name=L["Apply theme"],
				order=3,
			},

			applytheme = {
				type="select",
				name=L["Theme"],
				values=	function()
					local list = {}
					-- Add default theme first
					if Skada.defaulttheme then
						list[Skada.defaulttheme.name] = Skada.defaulttheme.name
					end
					for i, theme in ipairs(themes) do
						list[theme.name] = theme.name
					end
					if Skada.db.profile.themes then
						for i, theme in ipairs(Skada.db.profile.themes) do
							list[theme.name] = theme.name
						end
					end
					return list
				end,
				get=function() return selectedtheme end,
				set=function(i, name) selectedtheme = name end,
				order=3.1,
			},
			applywindow = {
				type="select",
				name=L["Window"],
				values=	function()
					local list = {}
					for i, win in ipairs(Skada:GetWindows()) do
						list[win.db.name] = win.db.name
					end
					return list
				end,
				get=function() return selectedwindow end,
				set=function(i, name) selectedwindow = name end,
				order=3.2,
			},
			applybutton = {
				type="execute",
				name=L["Apply"],
				func=function()
					if selectedwindow and selectedtheme then
						local thetheme = nil
						-- Check default theme first
						if Skada.defaulttheme and Skada.defaulttheme.name == selectedtheme then
							thetheme = Skada.defaulttheme
						end
						-- Check built-in themes
						if not thetheme then
							for i, theme in ipairs(themes) do
								if theme.name == selectedtheme then thetheme = theme end
							end
						end
						-- Check custom themes
						if not thetheme and Skada.db.profile.themes then
							for i, theme in ipairs(Skada.db.profile.themes) do
								if theme.name == selectedtheme then thetheme = theme end
							end
						end

						if thetheme then
							for i, win in ipairs(Skada:GetWindows()) do
								if win.db.name == selectedwindow then
									Skada:tcopy(win.db, thetheme, {"name", "modeincombat", "display", "set", "mode", "wipemode", "returnaftercombat"})
									Skada:ApplySettings()
									Skada:Print(L["Theme applied!"])
								end
							end
						end
					end
				end,
				order=3.3,
			},

			header3 = {
				type="header",
				name=L["Save theme"],
				order=4,
			},

			savewindow = {
				type="select",
				name=L["Window"],
				values=	function()
					local list = {}
					for i, win in ipairs(Skada:GetWindows()) do
						list[win.db.name] = win.db.name
					end
					return list
				end,
				get=function() return savewindow end,
				set=function(i, name) savewindow = name end,
				order=4.1,
			},
			savenametext = {
				type="input",
				name=L["Name"],
				desc=L["Name of your new theme."],
				get=function() return savename end,
				set=function(i, val) savename = val end,
				order=4.2,
			},
			savebutton = {
				type="execute",
				name=L["Save"],
				func=function()
					for i, win in ipairs(Skada:GetWindows()) do
						if win.db.name == savewindow then
							Skada.db.profile.themes = Skada.db.profile.themes or {}
							local theme = {}
							Skada:tcopy(theme, win.db)
							theme.name = savename
							table.insert(Skada.db.profile.themes, theme)
						end
					end
				end,
				order=4.3,
			},

			header4 = {
				type="header",
				name=L["Delete theme"],
				order=5,
			},

			deltheme = {
				type="select",
				name=L["Theme"],
				values=	function()
					local list = {}
					if Skada.db.profile.themes then
						for i, theme in ipairs(Skada.db.profile.themes) do
							list[theme.name] = theme.name
						end
					end
					return list
				end,
				get=function() return deletetheme end,
				set=function(i, name) deletetheme = name end,
				order=5.1,
			},

		deletebutton = {
				type="execute",
				name=L["Delete"],
				func=function()
					if Skada.db.profile.themes then
						for i, theme in ipairs(Skada.db.profile.themes) do
							if theme.name == deletetheme then
								table.remove(Skada.db.profile.themes, i)
							end
						end
					end
				end,
				order=5.2
			},

			header5 = {
				type="header",
				name=L["Export theme"],
				order=6,
			},

			exporttheme = {
				type="select",
				name=L["Theme to export"],
				values=function()
					local list = {}
					-- Add default theme
					if Skada.defaulttheme then
						list[Skada.defaulttheme.name] = Skada.defaulttheme.name
					end
					for i, theme in ipairs(themes) do
						list[theme.name] = theme.name
					end
					if Skada.db.profile.themes then
						for i, theme in ipairs(Skada.db.profile.themes) do
							list[theme.name] = theme.name
						end
					end
					return list
				end,
				get=function() return exporttheme end,
				set=function(i, name) exporttheme = name end,
				order=6.1,
			},

			exportbutton = {
				type="execute",
				name=L["Export"],
				func=function()
					if exporttheme then
						local thetheme = nil
						-- Check default theme first
						if Skada.defaulttheme and Skada.defaulttheme.name == exporttheme then
							thetheme = Skada.defaulttheme
						end
						-- Check built-in themes
						if not thetheme then
							for i, theme in ipairs(themes) do
								if theme.name == exporttheme then thetheme = theme end
							end
						end
						-- Check custom themes
						if not thetheme and Skada.db.profile.themes then
							for i, theme in ipairs(Skada.db.profile.themes) do
								if theme.name == exporttheme then thetheme = theme end
							end
						end
						if thetheme then
							local encoded = EncodeTheme(thetheme)
							ShowExportDialog(encoded)
						end
					end
				end,
				order=6.2,
			},

			header6 = {
				type="header",
				name=L["Import theme"],
				order=7,
			},

			importtext = {
				type="input",
				name=L["Theme data"],
				desc=L["Paste theme data here to import"],
				width="full",
				get=function() return importtext end,
				set=function(i, val) importtext = val end,
				order=7.1,
			},

			importbutton = {
				type="execute",
				name=L["Import"],
				func=function()
					if importtext and importtext ~= "" then
						local success, theme = DecodeTheme(importtext)
						if success and theme then
							Skada.db.profile.themes = Skada.db.profile.themes or {}
							table.insert(Skada.db.profile.themes, theme)
							Skada:Print(L["Theme imported successfully: "] .. (theme.name or "Unnamed"))
							importtext = ""
						else
							Skada:Print(L["Failed to import theme. Make sure the string starts with !Skada!"])
						end
					end
				end,
				order=7.2,
			},

		}
	}

	Skada.options.args['Themes'] = options

end)
