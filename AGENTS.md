# Skada Development Agent Guide: WoW 12.0 (Midnight) Compatibility

This document outlines the critical changes in WoW 12.0's internal combat API and how to develop for the modernized Skada.

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
- `SecretHelper:SafeGT(a, b)`: Safe greater-than comparison using `pcall`.
- `Skada:FormatNumberSecret(val)`: Automatically handles secret values vs. numeric values for the UI.

## 2. Structural Changes

### Native API Transition
Skada now relies on `Skada.NativeAPI` which polls Blizzard's internal session data rather than parsing the `COMBAT_LOG_EVENT_UNFILTERED`.
- **No Manual Summing**: High-level totals (Damage, Healing, etc.) are provided by the session view.
- **GUIDs as IDs**: Use `sourceGUID` from the API for player identification.
- **Polling Intervals**: Display updates are triggered by `UPDATE_DISPLAY` signals from the Native API handler.

### Module Standards
Modules should be "Hardened" by default:
- **Iterate Safely**: In loop for sources/spells, check `if type(item) == "table" and not SecretHelper:IsSecret(item) then`.
- **Handle Metadata**: Always define `mod.metadata.columns` in `OnEnable` to prevent nil-indexing errors in the summary bar.
- **Selective Wiping**: Use `win:Wipe()` when the "Secret Mode" state changes to prevent duplicated "Combat_N" vs "PlayerName" bars.

## 3. UI and Sizing
- **Sorting Fallback**: When values are secret, use `1000 - nr` as the bar value to preserve the API-provided order while allowing the bar display to function.
- **Total Bar**: The total bar should use `total + 1` to ensure it stays at the top of the list during active combat.

---
> [!IMPORTANT]
> Never assume a value from `NativeAPI` is a number until checked with `issecretvalue` or wrapped in `pcall`.
