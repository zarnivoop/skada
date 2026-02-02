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

	-- Helper function to serialize table to string
	local function SerializeTable(t)
		local parts = {"{"}
		for key, value in pairs(t) do
			if type(key) == "string" then
				if type(value) == "table" then
					parts[#parts+1] = key .. " = " .. SerializeTable(value) .. ","
				elseif type(value) == "string" then
					parts[#parts+1] = key .. " = \"" .. value .. "\","
				elseif type(value) == "number" then
					parts[#parts+1] = key .. " = " .. value .. ","
				elseif type(value) == "boolean" then
					parts[#parts+1] = key .. " = " .. tostring(value) .. ","
				end
			end
		end
		parts[#parts+1] = "}"
		return table.concat(parts, " ")
	end

	-- Helper function to serialize theme to string
	local function SerializeTheme(theme)
		local lines = {"{"}
		for key, value in pairs(theme) do
			if type(value) == "table" then
				lines[#lines+1] = "  " .. key .. " = " .. SerializeTable(value) .. ","
			elseif type(value) == "string" then
				lines[#lines+1] = "  " .. key .. " = \"" .. value .. "\","
			elseif type(value) == "number" then
				lines[#lines+1] = "  " .. key .. " = " .. value .. ","
			elseif type(value) == "boolean" then
				lines[#lines+1] = "  " .. key .. " = " .. tostring(value) .. ","
			end
		end
		lines[#lines+1] = "}"
		return table.concat(lines, "\n")
	end

	-- Helper function to deserialize theme from string
	local function DeserializeTheme(str)
		local func, err = loadstring("return " .. str)
		if not func then
			return false, nil
		end
		local success, result = pcall(func)
		if success and type(result) == "table" then
			return true, result
		end
		return false, nil
	end

	-- Show export dialog with copyable text
	local function ShowExportDialog(text)
		local frame = CreateFrame("Frame", "SkadaThemeExport", UIParent, "BasicFrameTemplateWithInset")
		frame:SetSize(500, 400)
		frame:SetPoint("CENTER")
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:SetFrameLevel(100)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
		frame.TitleBg:SetHeight(30)
		frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -8)
		frame.title:SetText(L["Export Theme"])

		local editbox = CreateFrame("EditBox", nil, frame)
		editbox:SetMultiLine(true)
		editbox:SetFontObject(ChatFontNormal)
		editbox:SetWidth(460)
		editbox:SetHeight(300)
		editbox:SetPoint("TOP", frame, "TOP", 0, -40)
		editbox:SetText(text)
		editbox:HighlightText()
		editbox:SetAutoFocus(true)

		local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
		scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
		scroll:SetScrollChild(editbox)

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
							local serialized = SerializeTheme(thetheme)
							ShowExportDialog(serialized)
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
				multiline=true,
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
						local success, theme = DeserializeTheme(importtext)
						if success and theme then
							Skada.db.profile.themes = Skada.db.profile.themes or {}
							table.insert(Skada.db.profile.themes, theme)
							Skada:Print(L["Theme imported successfully: "] .. (theme.name or "Unnamed"))
							importtext = ""
						else
							Skada:Print(L["Failed to import theme. Check the data format."])
						end
					end
				end,
				order=7.2,
			},

		}
	}

	Skada.options.args['Themes'] = options

end)
