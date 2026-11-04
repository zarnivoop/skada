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
- **Sorting Fallback**: When values are secret, use `1000 - nr` as the bar value to preserve the API-provided order while allowing the bar display to function.
- **Total Bar**: The total bar should use `total + 1` to ensure it stays at the top of the list during active combat.
- **Default theme**: `Forever: Skyborne` is the default for new profiles (`Options.lua` `windowdefaults` and `modules/Themes.lua`). It uses `Forever Bar` / `Forever Line` / `ForeverCrest` assets, a 12%-opaque panel, and 15px title buttons with 6px spacing.
- **Typography**: Cinzel SemiBold 14 for the title, Marcellus 12 for bars, Marcellus 8 for headers. Title uses `MONOCHROME`, bar text uses `OUTLINEMONOCHROME` for crisp contrast over class colors; headers use empty flags. `textshadow` defaults **off**, with a Text shadow toggle in Bars for a 1px shadow. Fonts live in `media/fonts/` with OFL licenses. `Skada.ThemeFonts` falls back to ABF / Accidental Presidency on ruRU/koKR/zhCN/zhTW.
- **Theme toggles**: Bars > `Column headers` default **on**, `Row separators` default **off**. Headers are mode-aware (`% / DPS / DMG`, `% / HPS / HEAL`, `% / DTPS / DMG`) and hide on modes with no columns. Headers render inside the existing 30px title bar (title row compresses to 22px, header strip is 8px at bottom offset 6px), so enabling them does not grow the title bar or move the buttons. `Title bar` also exposes left padding, button spacing, button size, and `Show buttons on hover`.
- **Hover controls**: With `hoverbuttons` enabled, all five title-bar buttons are alpha 0 at rest and fade in while the mouse is anywhere over the title bar. This keeps the default title bar clean without removing any action.
- **Migration**: `Skada:ApplyThemeMigration()` runs once per profile and only replaces the old out-of-box look (`Skada Glass`, 260px bars); custom themes are left untouched.

## 4. Local Machine Setup (Stefan)

- Repo: `/home/stefan/Dokument/skada` (branch `midnight`).
- WoW client: `/home/stefan/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_`
- AddOns path: `.../_forever_/Interface/AddOns/Skada`
- Client build observed: `1.60.1.70790` (`wowf` flavor), Interface **16001**.
- Installed addon version: **2.2.2** (`Skada-2.2.2-forever.zip` in the repo root).

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
rm -f Skada-2.2.2-forever.zip
(cd release && 7z a -tzip -mx=9 ../Skada-2.2.2-forever.zip Skada >/dev/null)

# install (back up any existing install first)
ADDONS="/home/stefan/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
[ -e "$ADDONS/Skada" ] && mv "$ADDONS/Skada" "$ADDONS/Skada.backup.$(date +%Y%m%d-%H%M%S)"
7z x -y Skada-2.2.2-forever.zip -o"$ADDONS" >/dev/null
```

### TOC rule

`Skada.toc` is the retail/Standard manifest. `Skada_Camelot.toc` and `Skada_Forever.toc` are the Forever manifests; both say only `## Interface: 16001` and must remain byte-identical. Never merge `16001` into `Skada.toc`.

### Headless test (no login)

`wow-ui-sim` is installed at `~/.local/share/wow-ui-sim/current` (outside the repo). Use the `skada-sim` wrapper: `skada-sim lua-errors`, `skada-sim dump-tree --exec-lua @script.lua`, or `skada-sim --delay 4000 --exec-lua @script.lua screenshot --png -o out.png`. The wrapper sets `WOW_INSTALL_PATH`, `--allow-ui-version-mismatch`, the Forever AddOns path, and `--no-saved-vars`. Global `--exec-lua`/`--delay` must come before the subcommand. Full recipe, mock-session example, and screenshot scripts are in the `skada-forever` skill.

### Release

Tag `v2.2.2` and push; `.github/workflows/release-midnight.yml` runs `luacheck`, `forever-lint`, regenerates `Version.lua`, and runs the BigWigs packager. The packager recognizes the suffixed TOCs and `16001`.

---
> [!IMPORTANT]
> Never assume a value from `NativeAPI` is a number until checked with `issecretvalue` or wrapped in `pcall`.
