## 2.10.1
Column toggle fixes
- Turning a per-mode column on or off now restores separate columns when single-value mode is enabled
- Clarified the single-value column option

## 2.10.0
A richer set of themes and bar polish
- Reworked the theme presets with distinct bars, borders, fonts and title treatments
- Added Bastion, Rime, Grimoire, Vanguard and Tidecaller themes
- Added optional transparent title treatments and title-button styles to selected themes
- Themes now cover bar textures, title alignment, icons, headers, separators, hover, spillover and spark colors
- Added themable row hover, overkill, overhealing, spark and spark glow colors
- Added a Bar icons toggle and theme-aware background tiling
- Themes are sorted by name for easier browsing
- Reduced default and preset window heights
- Single-value text now sizes to its content when columns are disabled
- Switching themes now resets every style field instead of leaving stale styling

## 2.9.0
Bar polish and segment fixes
- Rows now highlight subtly on hover
- Spell bars show overkill and overhealing as a second segment
- Fixed historical segment selection showing the current fight instead of the selected fight
- Historical segment spell and source drilldowns now use the selected fight
- Target rows now show class or specialization icons, with a target fallback icon for NPCs
- Fixed the total row inheriting stale overkill data

## 2.8.0
Bar renderer and combat polish
- Rebuilt the bar window on an internal renderer with smoother updates, row animations and a more visible spark
- Windows resize live, snap to complete rows and keep their scale
- Added a sticky total row and compact row density
- Added alternating row bands for mode and segment lists, following the Alternate row colors setting
- Columns are configurable per mode; DPS, HPS, APS, ADPS and DTPS start hidden
- Added a single-value display option for a column-free layout
- Damage and Healing spell lists now use aligned value and percent columns
- Fixed spell icons and spell colors in combat, including restricted combat data
- Fixed the total row showing one player's amount instead of the session total
- The total row no longer opens a player's spell breakdown
- Column headers hide while the title controls are shown, and title icons no longer overlap
- Combat mode switching now defaults to None
- Replaced the per-window broker display with a general LDB data-source toggle; existing broker windows become bar windows
- New windows no longer ask for a display type; it can be changed afterward
- Fixed scrolling past the last row, empty row labels and stale scale after resizing

## 2.7.0
Window displays, ledger, and themes
- Windows can now switch between bar, line, and ledger displays while keeping their position and settings
- Added a cross-metric Ledger display showing damage, healing, damage taken, avoidable damage, interrupts, dispels, and deaths
- The ledger can be resized, its summary strip can be hidden, and rows can use alternate colors or separators
- Added a unified window menu for display, mode, segment, theme, report and summary output, and window actions
- Windows can switch display automatically when combat starts and ends
- Added Forever: Forge, Forever: Canopy, and Forever: Eclipse themes
- Removed the legacy ElvUI, Legion-era, and All glowy theme presets
- Spell bars now use spell-school colors with a varied fallback, and spell tooltips show school, amount, hits, and overhealing
- Fixed player names being clipped when only the damage column is shown
- Segment lists now show the newest fight first and keep the latest 20

## 2.6.8
Spell details during combat
- Spell details for other players now keep working during combat
- Your own spell details resolve reliably in combat

## 2.6.7
Per-player spell details
- Fixed spell details showing the local player's spells for every player in combat

## 2.6.6
Window positions
- Fixed the second window not restoring its position after login

## 2.6.5
Damage spell details
- Fixed Damage spell details disappearing while Healing details still worked

## 2.6.4
Targets, tooltips, and spell details
- Added a Targets view for Damage and Healing, opened with Shift-click
- Enemy damage taken now lists the players who damaged the enemy
- Damage and Healing rows show target rows with amounts and tooltips
- Player tooltips now list the mobs they damaged
- Fixed target names missing from spell rows and tooltips
- Spell detail views now explain when no spell data is available instead of showing a blank window
- Fixed several combat errors caused by restricted combat values
- Spell names stay visible during combat
- Right-click on the empty bar background returns to the previous view again

## 2.6.3
Optional row animation
- Added a per-window Animate row changes option, default on
- Bars slide to their new rows only when their rank changes, with a short ease-out tween
- Animation state is cleared on hide/recycle, and layout animation pauses while resizing

## 2.6.2
Group join, native reset, and bar color stability
- External `DAMAGE_METER_RESET` no longer calls `ResetAllCombatSessions` a second time, which could leave the native meter empty until `/reload` (issue #9)
- Group join/leave now invalidates the current native session cache and reapplies visibility after the transition settles
- Secret class tokens are no longer used as class-color table keys; combat rows use the fallback color consistently until class data is readable
- Class names are normalized from both `classFilename` and `class`, and bars are no longer destroyed and recreated when class data appears mid-combat
- Clear the cached bar color whenever a recycled bar is created, and only trust the cache when the bar still has color stops

## 2.6.1
Bar fixes, window duplication, and pull comparison
- Reapply class, spell-school, explicit, and default bar colors when positional combat bars are reused after a reorder
- Refresh label/value colors, source metadata, icons, and self-highlight state for reused bars
- Added Duplicate window to the window settings section and per-window Skada menu
- Added a persistent per-encounter pull history and one-line vs last attempt comparison in the combat summary; comparisons require the same encounter, difficulty, and group size and can be turned off in General options

## 2.6.0
Chat summaries and direct reports
- Combat summary can be written to chat instead of the window; the window remains the default
- Chat summaries use the configured channel, including party, raid, instance, guild, officer, whisper, Battle.net, target, and self
- Added a direct Report channel menu on the title bar and Skada menu, removing the report modal from those entry points
- Added whisper target fields for report and chat summary output in General options
- Font, texture, background, border, and sound selects now use a searchable scrollable picker when they come from SharedMedia
- Added a per-window transparent bar background toggle that hides the unfilled portion of the bars
- Windows settings lists each window as a child entry in the left navigation; the Windows parent holds the create-window controls and the right pane shows only the selected window
- Added a New window entry to the Skada window menu; it creates a bar window through the name prompt directly

## 2.5.0
Quick mode switching and post-combat summary
- The title bar now exposes the menus directly: left-click opens modes, right-click opens segments, and hover shows a short hint
- Removed wheel mode cycling and legacy back-navigation from title right-click
- Added configurable role defaults for contextual Auto combat mode (tank/healer/damager)
- Added a post-combat summary panel with duration, raid DPS/HPS, deaths, avoidable damage, interrupts, dispels, top damage, and top avoidable ability
- Summary can open from the window menu or `/skada summary`
- Automatic summaries are off by default, scoped to boss fights by default, and omit zero-value rows
- Added inferred lines to the summary: top damage share, first death with death rate, avoidable tax, interrupt and dispel cadence, and absorb share
- Added one always-on humorous verdict line
- Combat summary closes immediately when combat starts
- The summary panel remembers its dragged position per profile
- Combat updates now default to 0.10s instead of 0.25s; smoothing is still enabled but settles faster
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
