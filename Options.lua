local _, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", true)
local media = LibStub("LibSharedMedia-3.0")

-- The option schema historically used these AceGUI shared-media lists. Keep
-- the tables available for the new Settings renderer without requiring AceGUI.
AceGUIWidgetLSMlists = {
	font = {},
	statusbar = {},
	background = {},
	border = {},
	sound = {},
}
for kind, target in pairs(AceGUIWidgetLSMlists) do
	for _, name in ipairs(media:List(kind)) do
		target[name] = name
	end
end

Skada.resetoptions = { [1] = L["No"], [2] = L["Yes"], [3] = L["Ask"] }

Skada.windowdefaults = {
	name = "Skada",

	barspacing = 1,
	bartexture = "Forever Bar",
	barfont = Skada.ThemeFonts.bar,
	barfontflags = "",
	barfontsize = 13,
	barheight = 22,
	barwidth = 470,
	barorientation = 1,
	barcolor = { r = 0.35, g = 0.55, b = 0.70, a = 1 },
	barbgcolor = { r = 0.012, g = 0.014, b = 0.018, a = 0.10 },
	transparentbackground = false,
	labelcolor = { r = 0.97, g = 0.98, b = 1.00, a = 1 },
	valuetextcolor = { r = 0.96, g = 0.97, b = 1.00, a = 1 },
	classcolormix = { r = 0.03, g = 0.07, b = 0.13, a = 1 },
	classcolormixamount = 0.50,
	barslocked = false,
	clickthrough = false,

	alternaterows = false,
	highlightself = true,
	selfhighlightcolor = { r = 0.55, g = 0.85, b = 1.00, a = 0.10 },
	spark = false,
	barfill = false,
	iconscale = 100,
	barinset = 1,

	spellschoolcolors = true,
	classcolorbars = true,
	classcolortext = false,
	classicons = true,
	roleicons = false,
	showself = true,

	buttons = { menu = true, reset = true, report = true, mode = true, segment = true },
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
	columnheadertextcolor = { r = 0.95, g = 0.97, b = 1.00, a = 1 },
	showrowseparators = false,
	rowseparatorcolor = { r = 0.45, g = 0.62, b = 0.75, a = 0.25 },

	title = { textcolor = { r = 0.98, g = 0.99, b = 1.00, a = 1 }, height = 30, font = Skada.ThemeFonts.title, fontsize = 13, paddingleft = 12, paddingtop = 3, texture = "Forever Bar", bordercolor = { r = 0.32, g = 0.48, b = 0.62, a = 0.12 }, bordertexture = "Forever Line", borderthickness = 1, color = { r = 0.06, g = 0.11, b = 0.20, a = 0.68 }, color2 = { r = 0.015, g = 0.028, b = 0.055, a = 0.68 }, fontflags = "", textalign = "LEFT" },
	background = {
		height = 300,
		texture = "None",
		bordercolor = { r = 0.30, g = 0.45, b = 0.58, a = 0.20 },
		bordertexture = "Forever Line",
		borderthickness = 1,
		color = { r = 0.014, g = 0.016, b = 0.020, a = 0.10 },
		tile = false,
		tilesize = 0,
	},

	strata = "LOW",
	scale = 1,

	reversegrowth = false,
	modeincombat = "auto",
	returnaftercombat = false,
	wipemode = "",

	hidden = false,
	enabletitle = true,
	titleset = true,

	set = "current",
	mode = nil,

	display = "bar",
	snapto = true,
	version = 1,
	smoothing = true,

	-- Inline exclusive
	isonnewline = false,
	isusingclasscolors = true,
	height = 30,
	width = 600,
	color = { r = 0.3, g = 0.3, b = 0.3, a = 0.6 },
	isusingelvuiskin = true,
	issolidbackdrop = false,
	fixedbarwidth = false,

	-- Broker exclusive
	textcolor = { r = 0.9, g = 0.9, b = 0.9 },
	useframe = true
}

local windefaultscopy = {}
Skada:tcopy(windefaultscopy, Skada.windowdefaults)

Skada.defaults = {
	profile = {
		version = 1,
		reset = { instance = 1, join = 1, leave = 1 },
		icon = { hide = false, radius = 80, minimapPos = 195 },
		numberformat = 1,
		setformat = 3,
		showranks = true,
		tooltips = true,
		tooltippos = "smart",
		tooltiprows = 3,
		informativetooltips = true,
		hidesolo = false,
		hidepvp = false,
		hidecombat = false,
		feed = "",
		showtotals = false,
		showcombatsummary = false,
		combatsummaryscope = "boss",
		combatsummaryoutput = "window",
		combatsummarychannel = "say",
		combatsummarytarget = "",
		combatsummarycomparison = true,
		pullhistory = {},
		roledefaults = { TANK = "", HEALER = "", DAMAGER = "" },
		sortmodesbyusage = true,
		updatefrequency = 0.10,

		modules = {},
		columns = {},
		report = { mode = "Damage", set = "current", channel = "Say", chantype = "preset", number = 10, target = "" },
		modulesBlocked = {},

		versions = {},

		windows = { windefaultscopy }
	}
}

-- Adds column configuration options for a mode.
function Skada:AddColumnOptions(mod)
	local db = self.db.profile.columns

	if mod.metadata and mod.metadata.columns then
		local cols = {
			type = "group",
			name = mod:GetName(),
			order = 0,
			inline = true,
			args = {}
		}

		for colname, value in pairs(mod.metadata.columns) do
			local c = mod:GetName() .. "_" .. colname

			-- Set initial value from db if available, otherwise use mod default value.
			if db[c] ~= nil then
				mod.metadata.columns[colname] = db[c]
			end

			-- Add column option.
			local col = {
				type = "toggle",
				name = L[colname] or colname,
				get = function() return mod.metadata.columns[colname] end,
				set = function()
					mod.metadata.columns[colname] = not mod.metadata.columns[colname]
					db[c] = mod.metadata.columns[colname]
					Skada:UpdateDisplay(true)
				end,
			}
			cols.args[c] = col
		end

		Skada.options.args.columns.args[mod:GetName()] = cols
	end
end

function Skada:AddLoadableModuleCheckbox(mod, name, description)
	local new = {
		type = "toggle",
		name = name,
		desc = description,
		order = 1,
	}
	Skada.options.args.modules.args[mod] = new
end

local deletewindow = nil
local newdisplay = "bar"

Skada.options = {
	type = "group",
	name = "Skada",
	plugins = {},
	args = {
		d = {
			type = "description",
			name = L["A damage meter."],
			order = 0,
		},

		windows = {
			type = "group",
			name = L["Windows"],
			order = 1,
			args = {}
		},

		resetoptions = {
			type = "group",
			name = L["Data resets"],
			order = 2,
			args = {

				resetinstance = {
					type = "select",
					name = L["Reset on entering instance"],
					desc = L["Controls if data is reset when you enter an instance."],
					values = function() return Skada.resetoptions end,
					get = function() return Skada.db.profile.reset.instance end,
					set = function(self, opt) Skada.db.profile.reset.instance = opt end,
					order = 30,
				},

				resetjoin = {
					type = "select",
					name = L["Reset on joining a group"],
					desc = L["Controls if data is reset when you join a group."],
					values = function() return Skada.resetoptions end,
					get = function() return Skada.db.profile.reset.join end,
					set = function(self, opt) Skada.db.profile.reset.join = opt end,
					order = 31,
				},

				resetleave = {
					type = "select",
					name = L["Reset on leaving a group"],
					desc = L["Controls if data is reset when you leave a group."],
					values = function() return Skada.resetoptions end,
					get = function() return Skada.db.profile.reset.leave end,
					set = function(self, opt) Skada.db.profile.reset.leave = opt end,
					order = 32,
				},

			}

		},

		tooltips = {
			type = "group",
			name = L["Tooltips"],
			order = 3,
			args = {
				tooltips = {
					type = "toggle",
					name = L["Show tooltips"],
					desc = L["Shows tooltips with extra information in some modes."],
					order = 1,
					get = function() return Skada.db.profile.tooltips end,
					set = function() Skada.db.profile.tooltips = not Skada.db.profile.tooltips end,
				},

				informative = {
					type = "toggle",
					name = L["Informative tooltips"],
					desc = L["Shows subview summaries in the tooltips."],
					order = 2,
					get = function() return Skada.db.profile.informativetooltips end,
					set = function() Skada.db.profile.informativetooltips = not Skada.db.profile.informativetooltips end,
				},

				rows = {
					type = "range",
					name = L["Subview rows"],
					desc = L["The number of rows from each subview to show when using informative tooltips."],
					min = 1,
					max = 10,
					step = 1,
					get = function() return Skada.db.profile.tooltiprows end,
					set = function(self, val) Skada.db.profile.tooltiprows = val end,
					order = 3,
				},

				tooltippos = {
					type = "select",
					name = L["Tooltip position"],
					desc = L["Position of the tooltips."],
					values = { ["default"] = L["Default"], ["topright"] = L["Top right"], ["topleft"] = L["Top left"], ["smart"] = L["Smart"] },
					get = function() return Skada.db.profile.tooltippos end,
					set = function(self, opt) Skada.db.profile.tooltippos = opt end,
					order = 4,
				},
			}
		},

		generaloptions = {
			type = "group",
			name = L["General options"],
			order = 4,
			args = {

				mmbutton = {
					type = "toggle",
					name = L["Show minimap button"],
					desc = L["Toggles showing the minimap button."],
					order = 1,
					get = function() return not Skada.db.profile.icon.hide end,
					set = function()
						Skada.db.profile.icon.hide = not Skada.db.profile.icon.hide
						Skada:RefreshMMButton()
					end,
				},



				showtotals = {
					type = "toggle",
					name = L["Show totals"],
					desc = L["Shows a extra row with a summary in certain modes."],
					order = 3,
					get = function() return Skada.db.profile.showtotals end,
					set = function() Skada.db.profile.showtotals = not Skada.db.profile.showtotals end,
				},


				roledefaults = {
					type = "group",
					name = L["Role defaults"],
					desc = L["Modes used by contextual Auto combat mode for each group role."],
					inline = true,
					order = 4,
					args = {
						tank = {
							type = "select",
							name = L["Tank"],
							values = function()
								local values = { [""] = L["Automatic"] }
								for _, mode in ipairs(Skada:GetModes()) do values[mode:GetName()] = mode:GetName() end
								return values
							end,
							get = function() return Skada.db.profile.roledefaults.TANK or "" end,
							set = function(_, value) Skada.db.profile.roledefaults.TANK = value end,
						},
						healer = {
							type = "select",
							name = L["Healer"],
							values = function()
								local values = { [""] = L["Automatic"] }
								for _, mode in ipairs(Skada:GetModes()) do values[mode:GetName()] = mode:GetName() end
								return values
							end,
							get = function() return Skada.db.profile.roledefaults.HEALER or "" end,
							set = function(_, value) Skada.db.profile.roledefaults.HEALER = value end,
						},
						damager = {
							type = "select",
							name = L["Damage"],
							values = function()
								local values = { [""] = L["Automatic"] }
								for _, mode in ipairs(Skada:GetModes()) do values[mode:GetName()] = mode:GetName() end
								return values
							end,
							get = function() return Skada.db.profile.roledefaults.DAMAGER or "" end,
							set = function(_, value) Skada.db.profile.roledefaults.DAMAGER = value end,
						},
					},
				},
				showcombatsummary = {
					type = "toggle",
					name = L["Combat summary"],
					desc = L["Show a summary panel after combat ends."],
					order = 14,
					get = function() return Skada.db.profile.showcombatsummary end,
					set = function() Skada.db.profile.showcombatsummary = not Skada.db.profile.showcombatsummary end,
				},
				combatsummaryscope = {
					type = "select",
					name = L["Combat summary scope"],
					desc = L["Choose when the summary opens automatically. It is still available from the menu and /skada summary."],
					order = 15,
					values = {
						boss = L["Boss fights only"],
						instance = L["All instance fights"],
						group = L["All group fights"],
					},
					get = function() return Skada.db.profile.combatsummaryscope or "boss" end,
					set = function(_, value) Skada.db.profile.combatsummaryscope = value end,
					disabled = function() return not Skada.db.profile.showcombatsummary end,
				},
				combatsummaryoutput = {
					type = "select",
					name = L["Summary output"],
					desc = L["Choose whether the summary opens as a window or is written to chat."],
					order = 16,
					values = {
						window = L["Window"],
						chat = L["Chat"],
					},
					get = function() return Skada.db.profile.combatsummaryoutput or "window" end,
					set = function(_, value) Skada.db.profile.combatsummaryoutput = value end,
				},
				combatsummarychannel = {
					type = "select",
					name = L["Summary channel"],
					desc = L["Chat channel used when the summary output is set to chat."],
					order = 17,
					values = function()
						local values = {}
						for _, choice in ipairs(Skada:GetChatChannelChoices()) do
							values[choice.key] = choice.label
						end
						return values
					end,
					get = function() return Skada.db.profile.combatsummarychannel or "say" end,
					set = function(_, value) Skada.db.profile.combatsummarychannel = value end,
					disabled = function() return (Skada.db.profile.combatsummaryoutput or "window") ~= "chat" end,
				},
				combatsummarytarget = {
					type = "input",
					name = L["Summary whisper target"],
					desc = L["Name for whisper or Battle.net summary output."],
					order = 18,
					width = "double",
					get = function() return Skada.db.profile.combatsummarytarget or "" end,
					set = function(_, value) Skada.db.profile.combatsummarytarget = value end,
					disabled = function()
						if (Skada.db.profile.combatsummaryoutput or "window") ~= "chat" then return true end
						local key = Skada.db.profile.combatsummarychannel
						return key ~= "whisper" and key ~= "bnet"
					end,
				},
				combatsummarycomparison = {
					type = "toggle",
					name = L["Compare with previous attempts"],
					desc = L["Show one line comparing this fight with the last matching attempt."],
					order = 19,
					get = function() return Skada.db.profile.combatsummarycomparison ~= false end,
					set = function()
						Skada.db.profile.combatsummarycomparison = not Skada.db.profile.combatsummarycomparison
					end,
				},

				reporttarget = {
					type = "input",
					name = L["Whisper target"],
					desc = L["Name used by whisper and Battle.net report output."],
					order = 19,
					width = "double",
					get = function() return Skada.db.profile.report.target or "" end,
					set = function(_, value) Skada.db.profile.report.target = value end,
				},

				hidesolo = {
					type = "toggle",
					name = L["Hide when solo"],
					desc = L["Hides Skada's window when not in a party or raid."],
					order = 5,
					get = function() return Skada.db.profile.hidesolo end,
					set = function()
						Skada.db.profile.hidesolo = not Skada.db.profile.hidesolo
						Skada:ApplySettings()
					end,
				},

				hidepvp = {
					type = "toggle",
					name = L["Hide in PvP"],
					desc = L["Hides Skada's window when in Battlegrounds/Arenas."],
					order = 6,
					get = function() return Skada.db.profile.hidepvp end,
					set = function()
						Skada.db.profile.hidepvp = not Skada.db.profile.hidepvp
						Skada:ApplySettings()
					end,
				},

				hidecombat = {
					type = "toggle",
					name = L["Hide in combat"],
					desc = L["Hides Skada's window when in combat."],
					order = 7,
					get = function() return Skada.db.profile.hidecombat end,
					set = function()
						Skada.db.profile.hidecombat = not Skada.db.profile.hidecombat
						Skada:ApplySettings()
					end,
				},


				sortmodesbyusage = {
					type = "toggle",
					name = L["Sort modes by usage"],
					desc = L["The mode list will be sorted to reflect usage instead of alphabetically."],
					order = 12,
					width = "full",
					get = function() return Skada.db.profile.sortmodesbyusage end,
					set = function()
						Skada.db.profile.sortmodesbyusage = not Skada.db.profile.sortmodesbyusage
						Skada:ApplySettings()
					end,
				},

				showranks = {
					type = "toggle",
					name = L["Show rank numbers"],
					desc = L["Shows numbers for relative ranks for modes where it is applicable."],
					order = 9,
					get = function() return Skada.db.profile.showranks end,
					set = function()
						Skada.db.profile.showranks = not Skada.db.profile.showranks
						Skada:ApplySettings()
					end,
				},



				showself = {
					type = "toggle",
					name = L["Always show self"],
					desc = L["Keeps the player shown last even if there is not enough space."],
					order = 11,
					get = function() return Skada.db.profile.showself end,
					set = function()
						Skada.db.profile.showself = not Skada.db.profile.showself
						Skada:ApplySettings()
					end,
				},

				numberformat = {
					type = "select",
					name = L["Number format"],
					desc = L["Controls the way large numbers are displayed."],
					values = function() return { [1] = L["Condensed"], [2] = L["Detailed"] } end,
					get = function() return Skada.db.profile.numberformat end,
					set = function(self, opt) Skada.db.profile.numberformat = opt end,
					order = 13,
				},

				datafeed = {
					type = "select",
					name = L["Data feed"],
					desc = L
					["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."],
					values = function()
						local feeds = {}
						feeds[""] = L["None"]
						for name, func in pairs(Skada:GetFeeds()) do feeds[name] = name end
						return feeds
					end,
					get = function() return Skada.db.profile.feed end,
					set = function(self, feed)
						Skada.db.profile.feed = feed
						if feed ~= "" then Skada:SetFeed(Skada:GetFeeds()[feed]) end
					end,
					order = 14,
				},



				setformat = {
					type = "select",
					name = L["Set format"],
					desc = L["Controls the way set names are displayed."],
					values = Skada:SetLabelFormats(),
					get = function() return Skada.db.profile.setformat end,
					set = function(self, opt)
						Skada.db.profile.setformat = opt; Skada:ApplySettings();
					end,
					order = 17,
					width = "double",
				},

				updatefrequency = {
					type = "range",
					name = L["Update frequency"],
					desc = L["How often windows are updated. Shorter for faster updates. Increases CPU usage."],
					min = 0.10,
					max = 1,
					step = 0.05,
					get = function() return Skada.db.profile.updatefrequency or 0.10 end,
					set = function(self, opt)
						Skada.db.profile.updatefrequency = opt
						Skada:ApplyUpdateFrequency()
					end,
					order = 18,
					width = "double",
				},

				simulation = {
					type = "group",
					name = L["Debug & Simulation"],
					order = 100,
					inline = true,
					args = {
						simulation_mode = {
							type = "toggle",
							name = L["Simulation Mode"],
							desc = L["Enables simulation mode for performance testing. Auto-disables in real combat."],
							get = function() return Skada.Simulation and Skada.Simulation.active end,
							set = function(self, val) 
								if Skada.Simulation then
									Skada.Simulation:SetEnabled(val)
								end
							end,
							order = 1,
						},
						simulation_size = {
							type = "range",
							name = L["Simulation Group Size"],
							desc = L["Controls the number of simulated participants."],
							min = 1,
							max = 40,
							step = 1,
							get = function() return Skada.Simulation and Skada.Simulation.groupSize or 40 end,
							set = function(self, val)
								if Skada.Simulation then
									Skada.Simulation:SetGroupSize(val)
								end
							end,
							order = 2,
							disabled = function() return not (Skada.Simulation and Skada.Simulation.active) end,
						},
					}
				}

			}
		},
		columns = {
			type = "group",
			name = L["Columns"],
			order = 5,
			args = {},
		},
		modules = {
			type = "group",
			name = L["Disabled Modules"],
			order = 6,
			get = function(i) return Skada.db.profile.modulesBlocked[i[#i]] end,
			set = function(i, value)
				Skada.db.profile.modulesBlocked[i[#i]] = value; Skada.options.args.modules.args.apply.disabled = false
			end,
			args = {
				desc = {
					type = "description",
					name = L["Tick the modules you want to disable."],
					width = "full",
					order = 0,
				},
				apply = {
					type = "execute",
					name = APPLY,
					width = "full",
					func = ReloadUI,
					confirm = function()
						return L["This change requires a UI reload. Are you sure?"]
					end,
					disabled = true,
					order = 99,
				},
			},
		},
		version_history = {
			type = "group",
			name = L["Version History"],
			order = 7,
			args = {
				description = {
					type = "description",
					name = L["View the version history of Skada."],
					width = "full",
					order = 1,
				},
				show_button = {
					type = "execute",
					name = L["Show Version History"],
					desc = L["Display the version history using the notification system."],
					func = function() Skada:ShowVersionHistory() end,
					width = "full",
					order = 2,
				}
			}
		}
	}
}

local function create_window_button(display_key)
	return {
		type = "input",
		name = L["Enter the name for the window."],
		width = "double",
		set = function(self, val)
			if val and val ~= "" then
				Skada:CreateWindow(val, nil, display_key)
			end
		end,
		order = 2,
	}
end

local function update_create_windows()
	local args = Skada.options.args.windows.args

	-- Remove any existing window creation buttons
	for k in pairs(args) do
		if k:match("^create_") or k == "display_types" then
			args[k] = nil
		end
	end

	for name, display in pairs(Skada.displays) do
		-- Create a group for each display type
		local display_group = {
			type = "group",
			name = display.name,
			order = 0.5,
			inline = true,
			args = {
				-- Add description for this display type
				desc = {
					type = "description",
					name = display.description,
					width = "full",
					order = 1,
				},
				create = create_window_button(name)
			}
		}

		-- Add the group to the options
		args["create_" .. name] = display_group
	end
end

-- Hook into AddDisplaySystem to update window creation buttons when displays are registered
local original_add_display = Skada.AddDisplaySystem
Skada.AddDisplaySystem = function(self, key, mod)
	original_add_display(self, key, mod)
	update_create_windows()
end
