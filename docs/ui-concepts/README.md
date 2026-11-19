# Skada UI concepts

Draft mockups for a non-bar display direction. The data strip and bar display stay; these are alternatives for the main window.

Constraint that shaped them: in combat, `C_DamageMeter` values are secret. Skada can display them but cannot add, divide, compare or compute shares. The API does return sources in rank order. Live layouts use order and formatted numbers; proportional layouts are review-only.

1. **Scoreboard cards**: grid of player cards, rank, DPS, total, top abilities. Live. Replaces bar lengths with a scannable board.
2. **Accountability ledger**: player by metric table for damage, healing, taken, avoidable, interrupts, dispels, deaths. Live for display; sorting by column after combat.
3. **Focus matrix**: player by enemy damage heatmap. Review. Shows target focus, cleave and split damage. Needs plain names, so it fills after combat.
4. **Threat runway**: one track, tank at 100%, everyone else a marker. Live if threat data is readable on Forever.
5. **Ticker wire**: one slim line cycling leader, deaths, interrupts, avoidable. Live accessory, not a main meter.
6. **Spell mosaic**: treemap drilldown of a player's abilities. Live rank-sized tiles; true area after combat.

Recommendation: build a `Board` display with cards first, then the ledger and focus matrix as layouts.
