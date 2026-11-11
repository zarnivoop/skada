# Skada Development Agent Guide: WoW 12.0 (Midnight) & Forever Compatibility

This document outlines the critical changes in WoW 12.0's / Forever's internal combat API and how to develop for the modernized Skada.

## 0. Forever Client Facts
- Forever is game type `camelot` (`WOW_PROJECT_ID` 18), Interface **16001**, and runs the modern/Mainline API — not the Classic Era API.
- It uses `C_DamageMeter`; the combat log is restricted, so there is no legacy fallback.
- Forever loads **dedicated TOC files**: `Skada_Camelot.toc` and `Skada_Forever.toc`, each with **only** `## Interface: 16001`. Never put `16001` in the plain `Skada.toc`; that file is the retail/Standard manifest.
- `Skada_Camelot.toc` and `Skada_Forever.toc` must stay byte-identical. Real Forever addons (Questie, Details) use this same suffix convention.
- `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` is **false** on Forever. Version-gated code should also check `WOW_PROJECT_CAMELOT`.
- `C_DamageMeter.GetCombatSessionFromID(sessionID, type)` and `GetCombatSessionSourceFromID(sessionID, type, sourceGUID, sourceCreatureID)` require the damage type argument.

## 1. The Core Challenge: Secret Values

WoW 12.0 introduces **Secret Values**. These are special data types returned by combat APIs during active combat.

### Critical Gotchas
- **Math Crashes**: Adding, subtracting, or multiplying a secret value (e.g., `val + 0`) will cause a hard script crash.
- **Comparison Crashes**: Using `>` or `<` on secret values will cause a hard script crash.
- **Indexing Crashes**: If a table *itself* is a secret value (Blizzard restricts the whole object), attempting to index it (e.g., `s.spellID`) will cause a hard script crash.
- **Format Safety**: `string.format()` with most patterns works with secret values (e.g., `%.0f`, `%d`, `%s`). `FontString:SetText(secretValue)` also works. However, you cannot compare the result of string.format with secret values using `==` or `~=`.

### Developing Safely
Always use the `SecretHelper` (localized from `Skada.SecretHelper`):
- `SecretHelper:IsSecret(val)`: Verification before math.
- `SecretHelper:SafeNumber(val)`: Returns `0` for secrets so you can safely sum totals or sort bars.
- `SecretHelper:SafeCompare(a, b)`: Safe comparison using `pcall`.
- `Skada:FormatNumberSecret(val)`: Automatically handles secret values vs. numeric values for the UI.

## 2. Structural Changes

### Native API Transition
Skada now relies on `Skada.NativeAPI` which polls Blizzard's internal session data rather than parsing the `COMBAT_LOG_EVENT_UNFILTERED`.
- **No Manual Summing**: High-level totals (Damage, Healing, etc.) are provided by the session view.
- **GUIDs as IDs**: Use `sourceGUID` for player identification when it is plain. In combat it may be a conditional secret; use synthetic `combat_N` IDs and `isLocalPlayer` instead.
- **Polling Intervals**: Display updates are triggered by `UPDATE_DISPLAY` signals from the Native API handler.

### Module Standards
Modules should be "Hardened" by default:
- **Iterate Safely**: In loop for sources/spells, check `if type(item) == "table" and not SecretHelper:IsSecret(item) then`.
- **Handle Metadata**: Always define `mod.metadata.columns` in `OnEnable` to prevent nil-indexing errors in the summary bar.
- **Selective Wiping**: Use `win:Wipe()` when the "Secret Mode" state changes to prevent duplicated "Combat_N" vs "PlayerName" bars.

## 3. UI and Sizing
- **Configuration**: `Settings.lua` registers a Blizzard `Settings` canvas category and renders the existing `Skada.options` schema with native widgets (dropdowns, sliders, checkboxes, color pickers). Windows settings lists each window as a child entry in the sidebar, with create-window controls on the Windows parent page and only the selected window shown in the right pane; SharedMedia-backed font, texture, background, border, and sound selects use a searchable scrollable picker instead of a long context menu. The old AceConfigDialog tree and AceGUI widgets are gone from the visual path; AceDB/AceEvent/AceTimer/AceLocale remain backend libraries.
- **Menus**: `Menus.lua` uses `MenuUtil.CreateContextMenu` for the window/mode/segment menus; the report dialog is a custom frame. `UIDropDownMenu` is no longer used.
- **Profiles**: the Profiles tab is custom (switch/create/copy/delete/reset). AceDBOptions and AceConfigRegistry/AceConfigDialog/AceGUI/AceGUI-3.0-SharedMediaWidgets are removed from `embeds.xml`.
- **Media lists**: `Options.lua` still exposes the historical `AceGUIWidgetLSMlists` table name for module schemas, but it is populated directly from LibSharedMedia and does not load AceGUI.
- **Sorting Fallback**: When values are secret, use rank-scaled bar values against the actual row count (`count - nr + 1`) with `maxvalue = count`. This preserves API order without making every combat bar look full; `1000 - nr` with max `999` was the old bug.
- **Total Bar**: The total bar should use `total + 1` to ensure it stays at the top of the list during active combat.
- **Default theme**: `Forever: Skyborne` is the default for new profiles (`Options.lua` `windowdefaults` and `modules/Themes.lua`). It uses `Forever Bar` / `Forever Line` / `ForeverCrest` assets, a 12%-opaque panel, and 15px title buttons with 6px spacing.
- **Typography**: Expressway 13 for the title (Cinzel/ABF fallback when Expressway is not registered), ABF 13 for bars, Marcellus 8 for headers. All font flags are empty (no outline); `textshadow` defaults **off**. Text colors are near-white. Fonts live in `media/fonts/` with OFL licenses. `Skada.ThemeFonts` falls back to ABF / Accidental Presidency on ruRU/koKR/zhCN/zhTW.
- **Bar backing**: `barbgcolor` is a neutral 10%-opaque dark fill and `alternaterows` is off by default, so the meter sits quietly against the game world. A per-window `transparentbackground` toggle forces the unfilled bar background alpha to zero. The title text is vertically centered against the title row/buttons.
- **Theme toggles**: Bars > `Column headers` default **on**, `Row separators` default **off**. Headers are mode-aware (`DMG / DPS / %`, `HEAL / HPS / %`, `DMG / DTPS / %`) and hide on modes with no columns. During combat the Percent column is mathematically unavailable from secret totals, so the header collapses to `DMG / DPS` and returns to three columns after combat. Headers render inside the existing 30px title bar. With hover-only buttons they share the title's vertical center; with always-visible buttons they use the compact bottom strip so the two do not overlap. Enabling headers never grows the title bar or moves the buttons. `Title bar` also exposes left padding, button spacing, button size, and `Show buttons on hover`.
- **Hover controls**: With `hoverbuttons` enabled, all five title-bar buttons are alpha 0 at rest and fade in while the mouse is anywhere over the title bar. This keeps the default title bar clean without removing any action.
- **Responsive columns**: Full-width windows show Damage/DPS/Percent; below 300px the rate column is hidden; below 400px Percent is hidden (and Percent is always unavailable while values are secret). Header slots and value columns share one column spec.
- **Layout presets**: Windows settings exposes one-click Compact / Standard / Detailed layout presets for the selected window.
- **Contextual mode**: `modeincombat = "auto"` selects Healing for healers in a group, Damage Taken for tanks, and Damage otherwise. DPS/HPS modes were consolidated into the Damage/Healing rate columns; old saved choices migrate.
- **History and comparison**: Set labels include tracked start times/durations; the Compare mode shows current vs previous session values and deltas.
- **Deaths**: the native Deaths mode opens Blizzard's death recap via `OpenDeathRecapUI`; this does not overlap the old commented-out Deaths module.
- **Threat**: uses `UnitDetailedThreatSituation` raw threat plus its percentage fields, two explicit columns (Threat, %), and a pull-aggro threshold row. TPS is not provided by the native threat API, so the old blank TPS column was removed. Target/focus tracking remains the trigger; warnings still use the player's threat percentage.
- **Combat segment behavior**: entering combat does not force the window to Current. Total/historical selections persist unless the user has no segment selected; `returnaftercombat` only restores a mode/set changed during combat.
- **Native metric coverage**: Absorbs, Avoidable Damage Taken, and Enemy Damage Taken are exposed from `C_DamageMeter`; all three support player/spell drilldowns. Enemy sources may be creature-ID-only, so source lookup and spell drilldown accept `sourceCreatureID` without a GUID.
- **Native metric factory**: `modules/NativeMetrics.lua` now also owns Damage Taken, Interrupts, and Dispels. Simple modes use `UpdateSimpleList`; player modes use `UpdatePlayerList`. Damage/Healing and the special Threat/Deaths/Compare modes stay custom.
- **Secret labels**: never build a rank prefix with `string.format` around a secret player name; pass the secret label directly to the FontString so combat rows remain readable. The same applies to tooltip lines: use the secret label directly and skip class-color/rank composition.
- **Reused bars**: in secret mode, positional `combat_N` IDs mean a bar can represent a different player after a reorder. Bar color, text color, source metadata, icons, and self-highlight state are reapplied on every update; the color path caches the last applied color to avoid appending duplicate gradient stops.
- **External reset and group transitions**: `DAMAGE_METER_RESET` only clears Skada state and cache; it does not call `ResetAllCombatSessions` again. Group join/leave invalidates the current native session and reapplies visibility after the event settles.
- **Secret class colors**: `SecretHelper:GetPlayerClass` normalizes uppercase class tokens from `classFilename` or `class`, ignores secret values, and validates against `RAID_CLASS_COLORS`; class color lookups never use a secret value as a table key. Bars are not destroyed and recreated when class data appears mid-combat.
- **Recycled bar colors**: `BarDisplay` clears `bar._skadaColor` in `CreateBar`. The color cache is only accepted when `bar.colors` still contains stops, since the library clears `bar.colors` when recycling a bar.
- **Row animation**: per-window `animaterows` is on by default. When enabled, `snapBarRows` tweens a bar from its previous row to its new row over 0.16 seconds; `SortBars` skips anchoring a bar while `_rowAnimating` is set. Animation state is cleared on hide/recycle and layout updates, and row animation is suppressed while resizing.
- **Spell detail fallback**: if native spell data is nil or empty, `ModuleBase:UpdateSpellList` inserts a placeholder row instead of leaving an empty window. The spell-detail placeholder is ignored by ranking and says spell details are available after combat while in combat. `/skada spells` reports the selected detail source and spell-field shape, including whether each value is plain, nil, a table, or secret. Detail views carry the clicked bar's native source object through `_drillSource`; this avoids failing a source lookup when the GUID is secret. Local-player rows also carry `isLocalPlayer` and fall back to `UnitGUID("player")` for the native spell query, matching Details' behavior. Current/total source and session-view lookups prefer the type APIs and fall back to the ID query, which avoids secret-GUID failures seen with the ID path. Player hover tooltips use `_hoverSource` and `_hoverIsLocalPlayer` from the hovered bar for the same spell query and local-player fallback. The diagnostic also dumps the direct source fields, and extraction accepts additional native collection names plus a first-entry spell-ID fallback. Spell rows consume `combatSpellDetails` for target, overkill, avoidable, and deadly metadata; secret booleans must be guarded before truth tests. `UpdateTargetList` builds target views from `combatSpellDetails.unitName`; Damage/Healing expose them via Shift-click, and Enemy damage taken click1 lists player contributors. Damage-meter type lookups use `Enum.DamageMeterType` when available in both source and session-view queries, including Enemy damage taken. Target views sanitize secret class/icon fields and scale unknown amounts against the row count. Empty `combatSpellDetails.unitName` values fall back to `spell.creatureName`; zero target amounts fall back to the spell total, then the source total for a single contributor. Enemy damage taken uses `CreateSourceTooltip` on the main rows and `CreateTargetTooltip` on contributor rows, and has no redundant Targets submode. `GetReversePlayerTargets` scans EnemyDamageTaken sources for a player name when the player source has no target details; it only works when names are plain. `GetSessionView` never returns the incoming Damage session when a different damage-type query fails; it returns nil and `/skada api` prints each current type view; `/skada spells` selects the last-clicked or hovered window and prints target dataset values plus first spell details for non-empty sources. `/skada clearerrors` clears the saved display error, whose timestamp is included in the diagnostic.
- **Right-click back**: the bar group background handles right-click navigation again, while the title button keeps right-click for the segment menu.
- **Performance**: session lookups are cached per tick; header labels and title writes are skipped when their layout key has not changed. Fixed column geometry is reapplied after bars update because the bar library can re-anchor columns on resize; visible rows are snapped to a physical-pixel stride after sorting to avoid uneven gaps at fractional UI scales, with the same top inset applied before the first row (including the total bar). Snapping is reapplied after scroll, settings changes, and width-resize hooks because those paths call `SortBars` directly. Combat updates default to 0.10s; bar smoothing is kept but interpolates at 25% per frame instead of 10%.
- **Quick mode**: left-clicking the title opens the mode menu and right-clicking opens the segment menu. Hover highlights the title and shows the interaction hint. Wheel mode cycling is intentionally not used, and title right-click does not also run the legacy back-navigation handler.
- **Report menu**: the title Report button and Skada menu open a direct channel menu. Whisper and Battle.net targets are configured in General options; the old report modal is no longer used by these entry points.
- **New window**: the Skada window menu creates a bar window directly through the existing name prompt. The Windows sidebar lists each window as a child entry and selects the newly created window; the Windows parent page holds the create-window controls.
- **Duplicate window**: `Skada:DuplicateWindow(name)` deep-copies the window database, assigns a unique copy name, offsets the position, and creates the new window. It is exposed in the window settings section and per-window Skada menu.
- **Role defaults**: contextual Auto mode can map tank/healer/damager to any mode in General options.
- **Combat summary**: `Summary.lua` provides a post-combat panel with duration, raid DPS/HPS, deaths, avoidable damage, interrupts, dispels, top damage, and top avoidable ability. It can also be written to the configured chat channel instead of the window; window remains the default. It opens from the window menu or `/skada summary`. Auto-display is off by default; when enabled it defaults to boss fights only and omits zero-value rows. It derives top damage share, first death and death rate, avoidable tax, interrupt/dispel cadence, and absorb share, and always ends with one short humorous verdict. A one-line comparison against the last matching attempt is shown when encounter, difficulty, and group size match; `pullhistory` stores up to 20 compact pull snapshots per encounter and the comparison can be disabled in General options. Its dragged position is stored per profile, and it hides immediately on `PLAYER_REGEN_DISABLED`.
- **Migration**: `Skada:ApplyThemeMigration()` runs once per profile and only replaces the old out-of-box look (`Skada Glass`, 260px bars); custom themes are left untouched.

## 4. Local Machine Setup (Stefan)

- Repo: `/home/stefan/Dokument/skada` (branch `midnight`).
- WoW client: `/home/stefan/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_`
- AddOns path: `.../_forever_/Interface/AddOns/Skada`
- Client build observed: `1.60.1.70790` (`wowf` flavor), Interface **16001**.
- Installed addon version: **2.6.4** (`Skada-2.6.4-forever.zip` in the repo root).

### Build + install

```bash
cd /home/stefan/Dokument/skada
python3 generate-version.py
luacheck .
# optional, in a venv:
# python3 -m venv .tools/flint && .tools/flint/bin/pip install forever-lint
# .tools/flint/bin/forever-lint . --fail-on error

rm -rf release && mkdir -p release/Skada
rsync -a --exclude='.git' --exclude='.tools' --exclude='release' --exclude='tools' \
  --exclude='/Skada' --exclude='.github' --exclude='*.zip' \
  --exclude='.luacheckrc' --exclude='.editorconfig' --exclude='.gitignore' \
  --exclude='.pkgmeta' --exclude='.emdash.json' \
  --exclude='AGENTS.md' --exclude='API.md' --exclude='CHANGELOG.md' \
  --exclude='README.md' --exclude='generate-version.py' \
  ./ release/Skada/
# replace @project-version@ in all three TOCs with the release version
rm -f Skada-2.6.4-forever.zip
(cd release && 7z a -tzip -mx=9 ../Skada-2.6.4-forever.zip Skada >/dev/null)

# install (back up any existing install first)
ADDONS="/home/stefan/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
[ -e "$ADDONS/Skada" ] && mv "$ADDONS/Skada" "$ADDONS/Skada.backup.$(date +%Y%m%d-%H%M%S)"
7z x -y Skada-2.6.4-forever.zip -o"$ADDONS" >/dev/null
```

### TOC rule

`Skada.toc` is the retail/Standard manifest. `Skada_Camelot.toc` and `Skada_Forever.toc` are the Forever manifests; both say only `## Interface: 16001` and must remain byte-identical. Never merge `16001` into `Skada.toc`.

### Headless test (no login)

`wow-ui-sim` is installed at `~/.local/share/wow-ui-sim/current` (outside the repo). Use the `skada-sim` wrapper: `skada-sim lua-errors`, `skada-sim dump-tree --exec-lua @script.lua`, or `skada-sim --delay 4000 --exec-lua @script.lua screenshot --png -o out.png`. The wrapper sets `WOW_INSTALL_PATH`, `--allow-ui-version-mismatch`, the Forever AddOns path, and `--no-saved-vars`. Global `--exec-lua`/`--delay` must come before the subcommand. Full recipe, mock-session example, and screenshot scripts are in the `skada-forever` skill.

### Release

Tag `v2.6.4` and push; `.github/workflows/release-midnight.yml` runs `luacheck`, `forever-lint`, regenerates `Version.lua`, and runs the BigWigs packager. The packager recognizes the suffixed TOCs and `16001`.

---
> [!IMPORTANT]
> Never assume a value from `NativeAPI` is a number until checked with `issecretvalue` or wrapped in `pcall`.
