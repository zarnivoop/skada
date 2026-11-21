--[[
	Bar display options shared by the custom bar renderer.
	Extracted from the old libbars-based BarDisplay.
]]

local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)

local function AddDisplayOptions(win, options)
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

			animaterows = {
				type="toggle",
				name=L["Animate row changes"],
				desc=L["Slide bars to their new positions when their rank changes."],
				order=24,
				get=function() return db.animaterows ~= false end,
				set=function()
					db.animaterows = (db.animaterows == false)
					Skada:ApplySettings()
				end,
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
				desc=L["Show a small value / rate / percent header row under the title."],
				order=42,
				get=function() return db.showcolumnheaders end,
				set=function()
					db.showcolumnheaders = not db.showcolumnheaders
					Skada:ApplySettings()
				end,
			},

			disablecolumns = {
				type="toggle",
				name=L["Disable columns"],
				desc=L["Show one combined value instead of separate value, rate and percent columns."],
				order=42.15,
				get=function() return db.disablecolumns == true end,
				set=function()
					db.disablecolumns = not db.disablecolumns
					Skada:ApplySettings()
				end,
			},



			stickytotal = {
				type="toggle",
				name=L["Sticky total row"],
				desc=L["Keep the total row pinned to the top while scrolling."],
				order=42.2,
				get=function() return db.stickytotal ~= false end,
				set=function()
					db.stickytotal = (db.stickytotal == false)
					Skada:ApplySettings()
				end,
			},

			compact = {
				type="toggle",
				name=L["Compact rows"],
				desc=L["Use tighter rows and hide icons to fit more players."],
				order=42.4,
				get=function() return db.compact == true end,
				set=function()
					db.compact = not db.compact
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

Skada.AddBarDisplayOptions = AddDisplayOptions
