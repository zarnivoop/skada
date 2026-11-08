## 2.5.0
Quick mode switching and post-combat summary
- Mouse-wheel over the window title cycles through modes
- Added configurable role defaults for contextual Auto combat mode (tank/healer/damager)
- Added a post-combat summary panel with duration, raid DPS/HPS, deaths, avoidable damage, interrupts, dispels, top damage, and top avoidable ability
- Summary can open from the window menu or `/skada summary`
- Automatic summaries are off by default, scoped to boss fights by default, and omit zero-value rows
- Added `Summary.lua` to the manifest and summary-related settings

## 2.4.1
Threat
- Switched the Threat mode to native `UnitDetailedThreatSituation` data with raw threat values
- Show raw Threat and `%` columns; removed the always-empty TPS column
- Added the pull-aggro threshold row
- Fixed Threat headers/values by giving the mode an explicit column spec
- Preserve the user-selected segment through combat; only fall back to Current when no segment is selected
- Apply the configured spacing above the first row so the first bar (including the total bar) has the same gap as the rest
- Center column headers vertically with the window title when title buttons are hover-only; retain the lower strip when buttons are always visible
- Added native Absorbs, Avoidable Damage Taken, and Enemy Damage Taken modes
- Added player/spell drilldowns to the new modes, including creature-ID-only enemy sources
- Migrated Damage Taken, Interrupts, and Dispels to the shared native metric factory
- Avoid rank-prefix `string.format` on secret player names so combat rows do not render with empty labels
- Preserve secret player names in bar, informative, and broker tooltips instead of replacing them with rank-only or formatted-empty labels
- Reapply physical row snapping after scroll, settings changes, and width-resize re-sorts


## 2.4.0
Performance and contextual UX
- Cache native session lookups per tick and avoid duplicate session resolution during window updates
- Reapply fixed column geometry when bars update so headers and values share exact right edges; snap visible rows to an integer physical-pixel stride so fractional UI scales do not leave uneven 1px gaps
- Fixed secret-value combat bars rendering nearly full: the fallback now scales ranks against the actual row count
- Consolidated redundant DPS/HPS modes into the Damage/Healing rate columns; saved old mode choices are migrated
- Added contextual Auto combat mode (healer → Healing, tank → Damage Taken, damage/solo → Damage)
- Made columns responsive: full width shows Damage/DPS/%, compact widths drop the rate or percentage column
- Added timestamped fight-history labels and a compact Compare mode for current vs previous session
- Added a native Deaths mode that shows death time from `deathTimeSeconds`, orders deaths chronologically, falls back across current/expired/overall death sessions, shows an explicit empty-state row, and opens the Blizzard death recap; `/skada deaths` reports session diagnostics
- Added one-click Compact / Standard / Detailed layout presets to Windows settings

## 2.3.0
Modern UI and combat-data fixes
- Replaced the AceConfigDialog/AceGUI configuration and menu UI with a native Blizzard Settings page, native context menus, and a custom report dialog
- Added a custom Profiles page for switching, creating, copying, deleting, and resetting profiles
- Removed unused AceConfig, AceGUI, AceDBOptions, and shared-media widget libraries and from `.pkgmeta` externals
- Fixed combat spell breakdowns by passing the clicked source GUID/CID directly to `C_DamageMeter` and handling secret spell IDs, icons, and row IDs
- Fixed set/session fallback, event-tracked session IDs, and tracked session lists when the native session endpoint is empty
- Corrected column order to Damage → DPS → Percent with fixed-width column slots and matching headers in and out of combat
- Fixed title vertical alignment, hover-header behavior, pixel-snapped row spacing, and instant bar-width updates while resizing
- Added a native window-name prompt and a visible Delete Window action
- Default Skyborne title font is now Expressway 13, with fallbacks when Expressway is not registered
- Added `/skada api` session diagnostics
- Fixed set labels showing `SecondsToTimeAbbrev` format patterns such as `%d m` instead of the duration

## 2.2.5
Session tracking fallback
- Track combat session IDs from `DAMAGE_METER_COMBAT_SESSION_UPDATED` and synthesize the set list when `GetAvailableCombatSessions` returns empty
- Resolve the last known session ID for the Current view when the live Current/Expired queries are empty
- `/skada api` now reports API availability, combat-data restriction, known event sessions, and resolved window sets

## 2.2.4
Session and default-theme hotfix
- Fixed set switching and missing bars by resolving an empty Current session through Expired, the newest tracked session, the last native snapshot, or the Total session
- Default session detection now uses the documented Current/DamageDone types instead of probing unrelated damage types
- Cached tracked sessions and session IDs so the set list and historical views survive empty API responses
- Added `/skada api` diagnostics for live session/meter troubleshooting
- Default Skyborne tuning: ABF 13 text, no font outline, near-white text, neutral 10%-opaque bar backing, vertically centered title

## 2.2.3
Hotfix for 2.2.2
- Fixed a load-time error caused by a stale Forever Stone LibSharedMedia registration

## 2.2.2
Forever: Skyborne theme
- Added the new default Forever: Skyborne theme with transparent panel, hover-revealed title controls, mode-aware column headers, row separators, and a gold total crest
- Added Cinzel and Marcellus (OFL) with a Latin-locale fallback and pixel-crisp mono-outline text treatment
- Improved class-colored bar readability with crisper text rendering and configurable text shadow
- Added title padding, button spacing, button size, column header, and row separator settings
- Migrates the old out-of-box window look once while preserving custom themes

## 2.2.1
WoW: Forever support
- Added support for World of Warcraft: Forever (Interface 16001)
- Added dedicated `Skada_Camelot.toc` / `Skada_Forever.toc` manifests
- Updated C_DamageMeter session lookups and segment durations
- Hardened secret-value handling during combat
- Replaced deprecated chat and screen-resolution APIs
- Fixed the total bar reusing stale percentage/column text

## 2.2.0
Polish, encounter names, and release workflow
- User interface polish and improvements
- Encounter name improvements
- Added GitHub release workflow
- Fixed various bugs and edge cases

## 2.1.0
Basic cleanup: bug fixes, UI polish, encounter names, GitHub release workflow
- Bug fixes and general cleanup
- User interface polish
- Encounter name improvements
- Added GitHub release workflow

## 2.0.2
New themes and performance improvements
- Added several new themes
- Removed old start/stop segment (no longer possible)
- Performance improvements

## 2.0.1
Initial Midnight fixes and minor improvements
- Fixed minimap toggle
- Simplified themes
- Fixed broker and inline display issues

## 2.0.0
Adapted for WoW 12.0, Midnight. Now using data provided by the built-in damage meter.
- Basic rework and simplification for WoW 12.0
- Some modules have been disabled for now

## 1.10.0
A ton of small fixes and improvements to bring the addon to a more up to date state.
- Value columns reworked into something more readable
- Bar display windows now snap to nearest size
- Power Gains modes reworked into one mode

## 1.8.0
Updated for 9.0!
- Pets without a unit will be properly associated with their owner

## 1.6.7
Added new overview modes
- Buffs overview mode showing spells used
- Debuffs overview mode showing spells used
- Clicking a spell shows the corresponding players

## 1.6.4
Quality of life improvements
- Added a new update frequency option
- Added a new notification system (LibNotify) to display version information unobtrusively

## 1.6.3
Roundup of recent changes
- Added a Smooth Bars option, for smoothly animated bar changes. Note that this does come at a performance cost.
- Mode list is now sorted by how often you use the modes.
- Added spell school color and tooltip info.
- Doubled default update frequency.
- Fixed a compatibility issue for RealUI users.
