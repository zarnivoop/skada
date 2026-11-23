local _, Skada = ...
Skada:AddLoadableModule("Themes", "Adds a set of standard theme presets to Skada.", function(Skada, L)
	if Skada.db.profile.modulesBlocked.Themes then return end

	Skada.themeDefaults = {}
	Skada:tcopy(Skada.themeDefaults, Skada.windowdefaults)

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
			sparkcolor = {r = 1.00, g = 1.00, b = 1.00, a = 1},
			sparkglowcolor = {r = 0.55, g = 0.78, b = 1.00, a = 1},
			hovercolor = {r = 1.00, g = 1.00, b = 1.00, a = 0.065},
			overkillcolor = {r = 0.90, g = 0.20, b = 0.15, a = 0.68},
			overhealingcolor = {r = 0.25, g = 0.62, b = 1.00, a = 0.58},
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
			background = {height = 220, texture="None", bordercolor = {r = 0.30, g = 0.45, b = 0.58, a = 0.20},
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
		bartexture = "BantoBar",
		barfont = "Accidental Presidency",
		barcolor = { r = 0.62, g = 0.28, b = 0.12, a = 1 },
		barbgcolor = { r = 0.020, g = 0.012, b = 0.008, a = 0.55 },
		labelcolor = { r = 1.00, g = 0.94, b = 0.86, a = 1 },
		valuetextcolor = { r = 1.00, g = 0.88, b = 0.70, a = 1 },
		classcolormix = { r = 0.20, g = 0.07, b = 0.02, a = 1 },
		classcolormixamount = 0.65,
		classicons = true,
		roleicons = true,
		spark = true,
		sparkcolor = { r = 1.00, g = 0.85, b = 0.55, a = 1 },
		sparkglowcolor = { r = 1.00, g = 0.45, b = 0.10, a = 1 },
		hovercolor = { r = 1.00, g = 0.85, b = 0.60, a = 0.07 },
		overkillcolor = { r = 0.95, g = 0.40, b = 0.12, a = 0.75 },
		overhealingcolor = { r = 1.00, g = 0.72, b = 0.25, a = 0.60 },
		barfill = true,
		alternaterows = false,
		showrowseparators = true,
		rowseparatorcolor = { r = 0.85, g = 0.45, b = 0.18, a = 0.35 },
		columnheadertextcolor = { r = 1.00, g = 0.88, b = 0.72, a = 1 },
		title = {
			height = 28,
			font = "Cinzel",
			fontsize = 14,
			texture = "Armory",
			bordertexture = "Roth",
			borderthickness = 2,
			color = { r = 0.10, g = 0.035, b = 0.015, a = 0.88 },
			color2 = { r = 0.020, g = 0.006, b = 0.002, a = 0.88 },
			bordercolor = { r = 0.95, g = 0.50, b = 0.20, a = 0.35 },
			textcolor = { r = 1.00, g = 0.90, b = 0.75, a = 1 },
			textalign = "LEFT",
		},
		background = {
			texture = "Copper",
			bordertexture = "Roth",
			borderthickness = 2,
			tile = true,
			tilesize = 128,
			color = { r = 0.018, g = 0.010, b = 0.006, a = 0.55 },
			bordercolor = { r = 0.80, g = 0.35, b = 0.12, a = 0.35 },
		},
	})

	addForeverVariant(3, "Forever: Canopy", {
		barheight = 18,
		barspacing = 0,
		barinset = 0,
		bartexture = "Healbot",
		barfont = "Vera Serif",
		classcolorbars = false,
		classcolortext = false,
		barcolor = { r = 0.20, g = 0.62, b = 0.36, a = 1 },
		barbgcolor = { r = 0.005, g = 0.020, b = 0.012, a = 0.15 },
		labelcolor = { r = 0.88, g = 1.00, b = 0.92, a = 1 },
		valuetextcolor = { r = 0.82, g = 1.00, b = 0.88, a = 1 },
		classcolormix = { r = 0.02, g = 0.10, b = 0.05, a = 1 },
		classcolormixamount = 0.50,
		classicons = false,
		roleicons = true,
		spark = true,
		sparkcolor = { r = 0.75, g = 1.00, b = 0.82, a = 1 },
		sparkglowcolor = { r = 0.20, g = 0.85, b = 0.42, a = 1 },
		hovercolor = { r = 0.65, g = 1.00, b = 0.75, a = 0.07 },
		overkillcolor = { r = 0.90, g = 0.30, b = 0.20, a = 0.65 },
		overhealingcolor = { r = 0.30, g = 1.00, b = 0.55, a = 0.55 },
		barfill = false,
		alternaterows = true,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.82, g = 1.00, b = 0.88, a = 1 },
		title = {
			height = 28,
			font = "Adventure",
			fontsize = 15,
			fontflags = "OUTLINE",
			texture = "Skada Glass",
			bordertexture = "Roth",
			borderthickness = 1,
			color = { r = 0.020, g = 0.070, b = 0.040, a = 0.55 },
			color2 = { r = 0.005, g = 0.020, b = 0.010, a = 0.55 },
			bordercolor = { r = 0.30, g = 0.80, b = 0.50, a = 0.25 },
			textcolor = { r = 0.85, g = 1.00, b = 0.90, a = 1 },
			textalign = "LEFT",
			paddingleft = 14,
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
		bartexture = "Gloss",
		barfont = "ABF",
		classcolormix = { r = 0.12, g = 0.04, b = 0.20, a = 1 },
		classcolormixamount = 0.60,
		showicons = false,
		classicons = false,
		roleicons = false,
		barcolor = { r = 0.50, g = 0.30, b = 0.85, a = 1 },
		barbgcolor = { r = 0.015, g = 0.008, b = 0.030, a = 0.28 },
		labelcolor = { r = 0.93, g = 0.88, b = 1.00, a = 1 },
		valuetextcolor = { r = 0.88, g = 0.80, b = 1.00, a = 1 },
		spark = true,
		sparkcolor = { r = 0.95, g = 0.85, b = 1.00, a = 1 },
		sparkglowcolor = { r = 0.65, g = 0.35, b = 1.00, a = 1 },
		hovercolor = { r = 0.85, g = 0.75, b = 1.00, a = 0.07 },
		overkillcolor = { r = 0.90, g = 0.25, b = 0.65, a = 0.65 },
		overhealingcolor = { r = 0.60, g = 0.45, b = 1.00, a = 0.55 },
		barfill = false,
		alternaterows = true,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.86, g = 0.78, b = 1.00, a = 1 },
		title = {
			height = 34,
			font = "Marcellus",
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

	addForeverVariant(5, "Forever: Bastion", {
		barheight = 26,
		barspacing = 1,
		barinset = 2,
		barorientation = 2,
		bartexture = "Perl",
		barfont = "Vera Serif",
		barfontsize = 14,
		barcolor = { r = 0.72, g = 0.48, b = 0.18, a = 1 },
		barbgcolor = { r = 0.030, g = 0.020, b = 0.012, a = 0.38 },
		labelcolor = { r = 1.00, g = 0.94, b = 0.78, a = 1 },
		valuetextcolor = { r = 1.00, g = 0.88, b = 0.60, a = 1 },
		classcolormix = { r = 0.25, g = 0.12, b = 0.03, a = 1 },
		classcolormixamount = 0.55,
		classicons = false,
		roleicons = true,
		alternaterows = false,
		highlightself = true,
		selfhighlightcolor = { r = 1.00, g = 0.80, b = 0.40, a = 0.12 },
		spark = true,
		sparkcolor = { r = 1.00, g = 0.90, b = 0.65, a = 1 },
		sparkglowcolor = { r = 1.00, g = 0.50, b = 0.15, a = 1 },
		hovercolor = { r = 1.00, g = 0.85, b = 0.55, a = 0.08 },
		overkillcolor = { r = 0.95, g = 0.35, b = 0.10, a = 0.75 },
		overhealingcolor = { r = 1.00, g = 0.70, b = 0.25, a = 0.60 },
		barfill = true,
		iconscale = 110,
		showrowseparators = true,
		rowseparatorcolor = { r = 0.90, g = 0.65, b = 0.25, a = 0.32 },
		columnheadertextcolor = { r = 1.00, g = 0.90, b = 0.65, a = 1 },
		columnheaderfont = Skada.ThemeFonts.header,
		columnheaderfontsize = 9,
		hoverbuttons = true,
		buttonspacing = 8,
		buttonsize = 16,
		buttonpaddingright = 12,
		title = {
			height = 34,
			font = "Cinzel",
			fontsize = 16,
			texture = "Armory",
			bordertexture = "Forever Line",
			borderthickness = 2,
			color = { r = 0.150, g = 0.080, b = 0.020, a = 0.90 },
			color2 = { r = 0.030, g = 0.015, b = 0.005, a = 0.90 },
			bordercolor = { r = 0.95, g = 0.65, b = 0.20, a = 0.40 },
			textcolor = { r = 1.00, g = 0.92, b = 0.70, a = 1 },
			textalign = "LEFT",
			paddingleft = 14,
			paddingtop = 4,
			fontflags = "",
		},
		background = {
			height = 240,
			texture = "Copper",
			bordertexture = "Forever Line",
			borderthickness = 2,
			tile = true,
			tilesize = 128,
			color = { r = 0.030, g = 0.020, b = 0.010, a = 0.40 },
			bordercolor = { r = 0.80, g = 0.55, b = 0.15, a = 0.30 },
		},
	})

	addForeverVariant(6, "Forever: Rime", {
		barheight = 24,
		barspacing = 2,
		barinset = 0,
		bartexture = "Glaze2",
		barfont = "ABF",
		barfontflags = "OUTLINE",
		barfontsize = 12,
		barcolor = { r = 0.55, g = 0.85, b = 0.95, a = 1 },
		barbgcolor = { r = 0.020, g = 0.050, b = 0.070, a = 0.22 },
		labelcolor = { r = 0.90, g = 1.00, b = 1.00, a = 1 },
		valuetextcolor = { r = 0.75, g = 0.95, b = 1.00, a = 1 },
		classcolorbars = false,
		classcolortext = false,
		showicons = false,
		classicons = false,
		roleicons = false,
		alternaterows = true,
		highlightself = true,
		selfhighlightcolor = { r = 0.50, g = 0.90, b = 1.00, a = 0.12 },
		spark = true,
		sparkcolor = { r = 0.80, g = 1.00, b = 1.00, a = 1 },
		sparkglowcolor = { r = 0.30, g = 0.80, b = 1.00, a = 1 },
		hovercolor = { r = 0.60, g = 0.95, b = 1.00, a = 0.08 },
		overkillcolor = { r = 0.90, g = 0.30, b = 0.40, a = 0.65 },
		overhealingcolor = { r = 0.40, g = 0.85, b = 1.00, a = 0.55 },
		barfill = false,
		iconscale = 100,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.80, g = 1.00, b = 1.00, a = 1 },
		columnheaderfont = Skada.ThemeFonts.header,
		columnheaderfontsize = 9,
		hoverbuttons = true,
		buttonspacing = 8,
		buttonsize = 14,
		buttonpaddingright = 12,
		title = {
			height = 32,
			font = "Marcellus",
			fontsize = 15,
			fontflags = "OUTLINE",
			texture = "Skada Glass",
			bordertexture = "Glow",
			borderthickness = 1,
			color = { r = 0.020, g = 0.060, b = 0.080, a = 0.75 },
			color2 = { r = 0.005, g = 0.020, b = 0.030, a = 0.75 },
			bordercolor = { r = 0.50, g = 0.90, b = 1.00, a = 0.35 },
			textcolor = { r = 0.85, g = 1.00, b = 1.00, a = 1 },
			textalign = "LEFT",
			paddingleft = 14,
		},
		background = {
			height = 230,
			texture = "Skada Glass",
			bordertexture = "Glow",
			borderthickness = 1,
			color = { r = 0.005, g = 0.020, b = 0.030, a = 0.25 },
			bordercolor = { r = 0.40, g = 0.80, b = 1.00, a = 0.25 },
		},
	})

	addForeverVariant(7, "Midnight Glass", {
		barheight = 20,
		barspacing = 2,
		barinset = 1,
		barwidth = 260,
		bartexture = "Skada Glass",
		barfont = "ABF",
		barfontflags = "OUTLINE",
		barfontsize = 11,
		barcolor = { r = 0.20, g = 0.50, b = 0.90, a = 1 },
		barbgcolor = { r = 0.000, g = 0.000, b = 0.000, a = 0.30 },
		classcolorbars = true,
		classcolortext = false,
		classicons = true,
		roleicons = true,
		alternaterows = true,
		highlightself = true,
		selfhighlightcolor = { r = 1.00, g = 1.00, b = 1.00, a = 0.15 },
		spark = true,
		sparkcolor = { r = 1.00, g = 1.00, b = 1.00, a = 1 },
		sparkglowcolor = { r = 0.45, g = 0.70, b = 1.00, a = 1 },
		hovercolor = { r = 1.00, g = 1.00, b = 1.00, a = 0.07 },
		overkillcolor = { r = 0.90, g = 0.25, b = 0.25, a = 0.68 },
		overhealingcolor = { r = 0.35, g = 0.70, b = 1.00, a = 0.58 },
		barfill = false,
		iconscale = 110,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.85, g = 0.92, b = 1.00, a = 1 },
		hoverbuttons = true,
		title = {
			height = 22,
			font = "ABF",
			fontsize = 11,
			fontflags = "OUTLINE",
			texture = "Skada Glass",
			bordertexture = "None",
			borderthickness = 0,
			color = { r = 0.05, g = 0.10, b = 0.20, a = 0.90 },
			color2 = { r = 0.10, g = 0.30, b = 0.60, a = 0.90 },
			bordercolor = { r = 0, g = 0, b = 0, a = 0 },
			textcolor = { r = 1, g = 1, b = 1, a = 1 },
			textalign = "LEFT",
		},
		background = {
			height = 200,
			texture = "None",
			bordertexture = "None",
			borderthickness = 0,
			color = { r = 0, g = 0, b = 0, a = 0.40 },
			bordercolor = { r = 1, g = 1, b = 1, a = 0.10 },
		},
	})

	addForeverVariant(8, "Clear Material", {
		barheight = 18,
		barspacing = 1,
		barinset = 0,
		barwidth = 260,
		bartexture = "Skada Material",
		barfont = "ABF",
		barfontsize = 10,
		barcolor = { r = 0.50, g = 0.50, b = 0.50, a = 1 },
		barbgcolor = { r = 0, g = 0, b = 0, a = 0 },
		classcolorbars = true,
		classcolortext = true,
		classicons = true,
		roleicons = false,
		alternaterows = false,
		highlightself = true,
		selfhighlightcolor = { r = 1, g = 1, b = 1, a = 0.10 },
		spark = false,
		barfill = false,
		iconscale = 100,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.85, g = 0.85, b = 0.85, a = 1 },
		hoverbuttons = true,
		title = {
			height = 18,
			font = "ABF",
			fontsize = 10,
			texture = "Skada Material",
			bordertexture = "None",
			borderthickness = 0,
			color = { r = 0.10, g = 0.10, b = 0.10, a = 0.80 },
			color2 = { r = 0.10, g = 0.10, b = 0.10, a = 0.80 },
			bordercolor = { r = 0, g = 0, b = 0, a = 0.20 },
			textcolor = { r = 0.80, g = 0.80, b = 0.80, a = 1 },
			textalign = "LEFT",
		},
		background = {
			height = 180,
			texture = "None",
			bordertexture = "None",
			borderthickness = 0,
			color = { r = 0, g = 0, b = 0, a = 0 },
			bordercolor = { r = 0, g = 0, b = 0, a = 0 },
		},
	})

	addForeverVariant(9, "Minimalistic", {
		barheight = 15,
		barspacing = 0,
		barinset = 0,
		barwidth = 380,
		bartexture = "Minimalist",
		barfont = "ABF",
		barfontsize = 11,
		barcolor = { r = 0.55, g = 0.55, b = 0.58, a = 1 },
		barbgcolor = { r = 0.01, g = 0.01, b = 0.012, a = 0.08 },
		classcolorbars = false,
		classcolortext = false,
		showicons = false,
		classicons = false,
		roleicons = false,
		alternaterows = false,
		highlightself = true,
		selfhighlightcolor = { r = 1, g = 1, b = 1, a = 0.06 },
		spark = false,
		barfill = false,
		iconscale = 100,
		showrowseparators = false,
		showcolumnheaders = false,
		hoverbuttons = true,
		buttonspacing = 4,
		buttonsize = 12,
		buttonpaddingright = 8,
		title = {
			height = 20,
			font = "ABF",
			fontsize = 11,
			texture = "None",
			bordertexture = "None",
			borderthickness = 0,
			color = { r = 0.04, g = 0.04, b = 0.045, a = 0.45 },
			color2 = { r = 0.02, g = 0.02, b = 0.025, a = 0.45 },
			bordercolor = { r = 0, g = 0, b = 0, a = 0 },
			textcolor = { r = 0.82, g = 0.82, b = 0.85, a = 1 },
			textalign = "LEFT",
			paddingleft = 8,
		},
		background = {
			height = 160,
			texture = "None",
			bordertexture = "None",
			borderthickness = 0,
			color = { r = 0, g = 0, b = 0, a = 0.20 },
			bordercolor = { r = 0, g = 0, b = 0, a = 0 },
		},
	})

	addForeverVariant(10, "Forever: Grimoire", {
		barheight = 23,
		barspacing = 2,
		barinset = 1,
		bartexture = "Skada Material",
		barfont = "Vera Serif",
		barfontsize = 13,
		barcolor = { r = 0.55, g = 0.36, b = 0.16, a = 1 },
		barbgcolor = { r = 0.030, g = 0.018, b = 0.008, a = 0.42 },
		labelcolor = { r = 1.00, g = 0.91, b = 0.72, a = 1 },
		valuetextcolor = { r = 0.96, g = 0.80, b = 0.55, a = 1 },
		classcolormix = { r = 0.28, g = 0.16, b = 0.05, a = 1 },
		classcolormixamount = 0.45,
		classcolortext = true,
		classicons = false,
		roleicons = false,
		spark = true,
		sparkcolor = { r = 1.00, g = 0.88, b = 0.60, a = 1 },
		sparkglowcolor = { r = 0.85, g = 0.45, b = 0.12, a = 1 },
		hovercolor = { r = 1.00, g = 0.88, b = 0.62, a = 0.07 },
		overkillcolor = { r = 0.75, g = 0.18, b = 0.10, a = 0.70 },
		overhealingcolor = { r = 0.85, g = 0.65, b = 0.25, a = 0.55 },
		barfill = false,
		alternaterows = false,
		showrowseparators = true,
		rowseparatorcolor = { r = 0.72, g = 0.50, b = 0.22, a = 0.28 },
		columnheadertextcolor = { r = 0.95, g = 0.80, b = 0.55, a = 1 },
		columnheaderfont = "Marcellus",
		columnheaderfontsize = 9,
		hoverbuttons = true,
		buttonspacing = 7,
		buttonsize = 15,
		buttonpaddingright = 12,
		title = {
			height = 36,
			font = "Cinzel",
			fontsize = 17,
			texture = "Armory",
			bordertexture = "Roth",
			borderthickness = 3,
			color = { r = 0.120, g = 0.070, b = 0.025, a = 0.92 },
			color2 = { r = 0.030, g = 0.015, b = 0.005, a = 0.92 },
			bordercolor = { r = 0.82, g = 0.58, b = 0.24, a = 0.42 },
			textcolor = { r = 1.00, g = 0.88, b = 0.62, a = 1 },
			textalign = "LEFT",
			paddingleft = 16,
			paddingtop = 4,
		},
		background = {
			height = 250,
			texture = "Copper",
			bordertexture = "Roth",
			borderthickness = 2,
			tile = true,
			tilesize = 128,
			color = { r = 0.025, g = 0.014, b = 0.006, a = 0.35 },
			bordercolor = { r = 0.65, g = 0.42, b = 0.16, a = 0.35 },
		},
	})

	addForeverVariant(11, "Forever: Vanguard", {
		barheight = 21,
		barspacing = 0,
		barinset = 2,
		bartexture = "Graphite",
		barfont = "Accidental Presidency",
		barfontsize = 13,
		barcolor = { r = 0.33, g = 0.48, b = 0.60, a = 1 },
		barbgcolor = { r = 0.010, g = 0.018, b = 0.028, a = 0.55 },
		labelcolor = { r = 0.92, g = 0.97, b = 1.00, a = 1 },
		valuetextcolor = { r = 0.82, g = 0.92, b = 1.00, a = 1 },
		classcolormix = { r = 0.04, g = 0.10, b = 0.17, a = 1 },
		classcolormixamount = 0.50,
		classicons = true,
		roleicons = true,
		spark = false,
		barfill = true,
		alternaterows = false,
		showrowseparators = true,
		rowseparatorcolor = { r = 0.55, g = 0.70, b = 0.82, a = 0.25 },
		columnheadertextcolor = { r = 0.80, g = 0.90, b = 1.00, a = 1 },
		columnheaderfont = "Accidental Presidency",
		columnheaderfontsize = 9,
		hoverbuttons = true,
		buttonspacing = 6,
		buttonsize = 16,
		buttonpaddingright = 12,
		hovercolor = { r = 0.70, g = 0.88, b = 1.00, a = 0.07 },
		overkillcolor = { r = 0.90, g = 0.25, b = 0.20, a = 0.68 },
		overhealingcolor = { r = 0.35, g = 0.70, b = 1.00, a = 0.58 },
		title = {
			height = 30,
			font = "Diablo",
			fontsize = 15,
			texture = "Armory",
			bordertexture = "Roth",
			borderthickness = 3,
			color = { r = 0.060, g = 0.100, b = 0.150, a = 0.92 },
			color2 = { r = 0.010, g = 0.020, b = 0.035, a = 0.92 },
			bordercolor = { r = 0.45, g = 0.68, b = 0.85, a = 0.38 },
			textcolor = { r = 0.88, g = 0.96, b = 1.00, a = 1 },
			textalign = "LEFT",
		},
		background = {
			height = 230,
			texture = "None",
			bordertexture = "Roth",
			borderthickness = 2,
			color = { r = 0.010, g = 0.020, b = 0.035, a = 0.55 },
			bordercolor = { r = 0.35, g = 0.55, b = 0.72, a = 0.32 },
		},
	})

	addForeverVariant(12, "Forever: Tidecaller", {
		barheight = 24,
		barspacing = 2,
		barinset = 0,
		bartexture = "Glaze2",
		barfont = "ABF",
		barfontsize = 12,
		barcolor = { r = 0.18, g = 0.62, b = 0.68, a = 1 },
		barbgcolor = { r = 0.005, g = 0.025, b = 0.030, a = 0.22 },
		labelcolor = { r = 0.86, g = 1.00, b = 1.00, a = 1 },
		valuetextcolor = { r = 0.72, g = 0.96, b = 1.00, a = 1 },
		classcolormix = { r = 0.02, g = 0.14, b = 0.16, a = 1 },
		classcolormixamount = 0.45,
		classicons = true,
		roleicons = true,
		spark = true,
		sparkcolor = { r = 0.75, g = 1.00, b = 1.00, a = 1 },
		sparkglowcolor = { r = 0.15, g = 0.75, b = 0.85, a = 1 },
		hovercolor = { r = 0.55, g = 1.00, b = 1.00, a = 0.08 },
		overkillcolor = { r = 0.90, g = 0.30, b = 0.30, a = 0.65 },
		overhealingcolor = { r = 0.30, g = 0.90, b = 0.85, a = 0.55 },
		barfill = false,
		alternaterows = true,
		showrowseparators = false,
		columnheadertextcolor = { r = 0.70, g = 0.98, b = 1.00, a = 1 },
		columnheaderfont = "Marcellus",
		columnheaderfontsize = 9,
		hoverbuttons = true,
		buttonspacing = 8,
		buttonsize = 15,
		buttonpaddingright = 12,
		title = {
			height = 32,
			font = "Adventure",
			fontsize = 16,
			fontflags = "OUTLINE",
			texture = "Skada Glass",
			bordertexture = "Glow",
			borderthickness = 1,
			color = { r = 0.010, g = 0.070, b = 0.080, a = 0.78 },
			color2 = { r = 0.002, g = 0.020, b = 0.030, a = 0.78 },
			bordercolor = { r = 0.35, g = 0.90, b = 1.00, a = 0.35 },
			textcolor = { r = 0.80, g = 1.00, b = 1.00, a = 1 },
			textalign = "LEFT",
			paddingleft = 14,
		},
		background = {
			height = 240,
			texture = "None",
			bordertexture = "Glow",
			borderthickness = 1,
			color = { r = 0.004, g = 0.025, b = 0.032, a = 0.28 },
			bordercolor = { r = 0.25, g = 0.75, b = 0.85, a = 0.28 },
		},
	})

	local function themeSortKey(name)
		name = tostring(name or "")
		name = name:gsub("^Forever:%s*", "")
		return name:lower()
	end
	table.sort(Skada.themePresets, function(a, b)
		local ak, bk = themeSortKey(a.name), themeSortKey(b.name)
		if ak == bk then return tostring(a.name) < tostring(b.name) end
		return ak < bk
	end)

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
		-- Themes are complete style presets, not patches over whatever the
		-- previous theme left behind. Resolve them over the canonical style
		-- defaults, then preserve identity, position and behavior choices.
		local resolved = {}
		Skada:tcopy(resolved, Skada.themeDefaults or Skada.windowdefaults)
		Skada:tcopy(resolved, theme)
		Skada:tcopy(win.db, resolved, {
			"name", "display", "set", "mode", "wipemode", "returnaftercombat", "modeincombat",
			"hidden", "barslocked", "clickthrough", "x", "y", "point",
			"animaterows", "stickytotal", "compact", "showself",
			"ledgersummary", "ledgertransparent",
		})
		local themeBg = resolved.background and resolved.background.color
		win.db.ledgertransparent = (themeBg and themeBg.a and themeBg.a <= 0.01) and true or false
		-- Bars cache their colors; rebuild them so the new palette is visible.
		win:Wipe()
		Skada:ApplySettings()
		Skada:UpdateDisplay(true)
	end

end)
