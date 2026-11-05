local _, Skada = ...
Skada.versions = {
	{
		id = "2.2.4",
		title = "Skada 2.2.4",
		message = "Session and default-theme hotfix",
		changes = {
			"Fixed set switching and missing bars by resolving an empty Current session through Expired, the newest tracked session, the last native snapshot, or the Total session",
			"Default session detection now uses the documented Current/DamageDone types instead of probing unrelated damage types",
			"Cached tracked sessions and session IDs so the set list and historical views survive empty API responses",
			"Added `/skada api` diagnostics for live session/meter troubleshooting",
			"Default Skyborne tuning: ABF 13 text, no font outline, near-white text, neutral 10%-opaque bar backing, vertically centered title",
		}
	},
	{
		id = "2.2.3",
		title = "Skada 2.2.3",
		message = "Hotfix for 2.2.2",
		changes = {
			"Fixed a load-time error caused by a stale Forever Stone LibSharedMedia registration",
		}
	},
	{
		id = "2.2.2",
		title = "Skada 2.2.2",
		message = "Forever: Skyborne theme",
		changes = {
			"Added the new default Forever: Skyborne theme with transparent panel, hover-revealed title controls, mode-aware column headers, row separators, and a gold total crest",
			"Added Cinzel and Marcellus (OFL) with a Latin-locale fallback and pixel-crisp mono-outline text treatment",
			"Improved class-colored bar readability with crisper text rendering and configurable text shadow",
			"Added title padding, button spacing, button size, column header, and row separator settings",
			"Migrates the old out-of-box window look once while preserving custom themes",
		}
	},
	{
		id = "2.2.1",
		title = "Skada 2.2.1",
		message = "WoW: Forever support",
		changes = {
			"Added support for World of Warcraft: Forever (Interface 16001)",
			"Added dedicated `Skada_Camelot.toc` / `Skada_Forever.toc` manifests",
			"Updated C_DamageMeter session lookups and segment durations",
			"Hardened secret-value handling during combat",
			"Replaced deprecated chat and screen-resolution APIs",
			"Fixed the total bar reusing stale percentage/column text",
		}
	},
	{
		id = "2.2.0",
		title = "Skada 2.2.0",
		message = "Polish, encounter names, and release workflow",
		changes = {
			"User interface polish and improvements",
			"Encounter name improvements",
			"Added GitHub release workflow",
			"Fixed various bugs and edge cases",
		}
	},
	{
		id = "2.1.0",
		title = "Skada 2.1.0",
		message = "Basic cleanup: bug fixes, UI polish, encounter names, GitHub release workflow",
		changes = {
			"Bug fixes and general cleanup",
			"User interface polish",
			"Encounter name improvements",
			"Added GitHub release workflow",
		}
	},
	{
		id = "2.0.2",
		title = "Skada 2.0.2",
		message = "New themes and performance improvements",
		changes = {
			"Added several new themes",
			"Removed old start/stop segment (no longer possible)",
			"Performance improvements",
		}
	},
	{
		id = "2.0.1",
		title = "Skada 2.0.1",
		message = "Initial Midnight fixes and minor improvements",
		changes = {
			"Fixed minimap toggle",
			"Simplified themes",
			"Fixed broker and inline display issues",
		}
	},
	{
		id = "2.0.0",
		title = "Skada 2.0.0",
		message = "Adapted for WoW 12.0, Midnight. Now using data provided by the built-in damage meter.",
		changes = {
			"Basic rework and simplification for WoW 12.0",
			"Some modules have been disabled for now",
		}
	},
	{
		id = "1.10.0",
		title = "Skada 1.10.0",
		message = "A ton of small fixes and improvements to bring the addon to a more up to date state.",
		changes = {
			"Value columns reworked into something more readable",
			"Bar display windows now snap to nearest size",
			"Power Gains modes reworked into one mode",
		}
	},
	{
		id = "1.8.0",
		title = "Skada 1.8.0",
		message = "Updated for 9.0!",
		changes = {
			"Pets without a unit will be properly associated with their owner",
		}
	},
	{
		id = "1.6.7",
		title = "Skada 1.6.7",
		message = "Added new overview modes",
		changes = {
			"Buffs overview mode showing spells used",
			"Debuffs overview mode showing spells used",
			"Clicking a spell shows the corresponding players",
		}
	},
	{
		id = "1.6.4",
		title = "Skada 1.6.4",
		message = "Quality of life improvements",
		changes = {
			"Added a new update frequency option",
			"Added a new notification system (LibNotify) to display version information unobtrusively",
		}
	},
	{
		id = "1.6.3",
		title = "Skada 1.6.3",
		message = "Roundup of recent changes",
		changes = {
			"Added a Smooth Bars option, for smoothly animated bar changes. Note that this does come at a performance cost.",
			"Mode list is now sorted by how often you use the modes.",
			"Added spell school color and tooltip info.",
			"Doubled default update frequency.",
			"Fixed a compatibility issue for RealUI users.",
		}
	},
}