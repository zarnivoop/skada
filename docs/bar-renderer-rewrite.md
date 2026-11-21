# Bar renderer rewrite

Status: exploration on `bar-renderer-explore`. Nothing here is merged or released.

## Recommendation

Rewrite the bar display, but do it as a second renderer first (`bar2`), prove parity and
performance, then switch the `bar` key and remove the embedded library. Do not swap the
live renderer in one step.

The current renderer is not slow enough to be a user-visible problem at normal raid
sizes, but a large part of its update cost is spent working around `SpecializedLibBars`
rather than drawing bars. A custom renderer has a credible path to roughly an order of
magnitude less update work, and it removes several layout bugs that only exist because
the library owns column geometry and row anchoring.

## What the current code owns

| Piece | Current owner | Size |
|---|---|---|
| Display adapter, options, tooltips, clicks, themes | `BarDisplay.lua` | ~2,350 lines |
| Window shell, row frames, sort, scroll, columns, smoothing, buttons | `SpecializedLibBars-1.0` | ~1,880 lines, 115 functions |

`BarDisplay` is already a renderer adapter wrapped around another renderer. It creates
rows, sets values and text, then repeatedly repairs the library's layout:

- `applyColumnGeometry()` re-anchors all three value columns **on every row, every
  update**, because the library re-anchors them when a bar changes size.
- `snapBarRows()` and `setRowPosition()` re-anchor every visible row after every sort,
  because the library owns row placement. The same loop also drives per-row animation.
- The bar-list `OnSizeChanged` hook pushes the real frame width back into the library's
  `length`, because the library's resize update can lag behind the drag.
- `SetBarBackgroundColor()` and `SetEnableMouse()` need nil guards because the library
  iterates `GetBars()`, which is nil for a fresh or emptied group.
- `_skadaColor` and the `bar.colors` check exist because the library clears texture
  color state when recycling a bar.
- `BarResize()` and the `backgroundwidth` script work around the library's background
  texture ownership.
- The comment on the unconditional `SortBars()` documents a real stale-`barCount` bug in
  the old guard.
- The library always creates **three** value FontStrings per row, even when only one
  column is visible. Hidden columns still had geometry, which is why the name was
  clipped until `applyColumnGeometry()` learned to anchor it to the first visible
  column.

These are not cosmetic complaints. They are repeated work and state that a clean
renderer would not need.

## Measured baseline

Headless simulator, 470px bars, 22px rows, three columns, mock eight-player session,
500 iterations of `win.display:Update(win)` after warm-up. Timings are simulator
numbers and are useful for relative comparison, not as absolute client promises.

| Case | Cost per renderer update |
|---|---:|
| Current library renderer, 9 rows | 0.827 ms |
| Current library renderer, 40 rows | 6.638 ms |
| Raw custom rows, 40 rows, fill width + three text writes | 0.259 ms |

The raw row number is not a complete renderer: it has no sort, secret handling,
animation, or tooltip bookkeeping. It does show that the primitive work is cheap and
that the library's layout/text repair path dominates the current 40-row cost.

A reasonable target for the replacement is **under 1 ms for 40 visible rows on a 10 Hz
update**, with **zero `OnUpdate` scripts while idle** and no steady-state allocations
beyond the dataset already supplied by the mode.

## Proposed architecture

Keep the existing display contract (`Create`, `Destroy`, `Wipe`, `Update`,
`ApplySettings`, `SetTitle`, `Show`, `Hide`, `IsShown`, `OnMouseWheel`) and the existing
window database keys. The rewrite is below that boundary.

### 1. Window shell

One frame owns everything:

- title button and drag behavior
- title-bar action buttons
- column-header strip
- resize grip and minimum size
- bar viewport
- saved top-left position and scale

The shell should be authored here instead of delegated. Saving `x`, `y`, `point` and
`scale` directly is simpler than routing through `LibWindow` and removes the
centre-relative migration path. `LibWindow` can stay for one release if that reduces
risk, but it is not needed by the new renderer.

### 2. Row object

One pooled row contains only what it draws:

```
Frame
├── background texture
├── fill texture          (width = value / maxvalue * usable width)
├── optional overlay fill (absorb/overheal/overkill; later)
├── icon texture
├── label FontString
├── value FontString 1..3 (created lazily, only for the visible slot count)
└── separator texture
```

Rows are opaque frames with an explicit `SetPoint` top-left and a fixed height. They do
not use `StatusBar`, gradient maps, or a library-managed parent chain.

### 3. Layout

Compute a single immutable layout per width/mode/settings change:

- `rowHeight`, `rowStep`, `visibleRows`
- visible column count and each column's right offset/width
- label left inset (icon or no icon)
- label right edge = left edge of the **first visible** value column
- header slots use the same offsets

Rows read the layout; they never calculate columns individually. This removes
`applyColumnGeometry()` entirely.

### 4. Update pipeline

```
dataset -> stable sort (only if needed) -> visible slice -> row diff -> content update -> anchor
```

- Reuse one `active` table, one visible array, one row-spec array, and one layout table.
- Acquire rows by id; release rows that are no longer present.
- Update text only when a non-secret value changed.
- Update fill width only when the numeric bar value or max changed.
- Update colors only when the style signature changed; no gradient stop appends.
- Anchor each visible row once, in one loop, with a precomputed `y`.
- Pool only visible rows plus one screen of buffer; no frame per dataset entry when the
  dataset is very large.

### 5. Animation

One group-level `OnUpdate` drives all moving rows:

- record `fromY` / `toY` only when a rank changed
- interpolate with `GetTime()`
- stop the script when the last row settles
- suppress animation while resizing or changing layout

There is no per-row `OnUpdate` and no `SortBars`/`SetPoint` race.

### 6. Scrolling

Keep an offset in rows, not pixels. Wheel input changes the offset, clamps it to the
visible count, and only recycles the pool. The viewport clips rows; no secure scroll
template is involved, so combat scroll ranges stay non-secret.

### 7. Secret values

The renderer never compares a secret value, name, or table.

- Bar values are already numeric/synthetic by the time they reach the renderer.
- Value text is written directly with `FontString:SetText`; secret strings are never
  compared or concatenated.
- Labels are passed through untouched; rank prefixes are only built for plain labels.
- Palette and column lookups only use plain keys.
- The dirty checks skip a `==` comparison when a value is secret and simply write.

### 8. Settings mapping

Keep the database schema. The renderer consumes the existing keys:

`barheight`, `barspacing`, `barwidth`, `barorientation`, `reversegrowth`,
`bartexture`, `barcolor`, `barbgcolor`, `classcolorbars`, `classcolormix`,
`classicons`, `roleicons`, `showself`, `highlightself`, `spark`, `barfill`,
`alternaterows`, `showrowseparators`, `showcolumnheaders`, fonts, title, background,
buttons, `clickthrough`, `barslocked`, `scale`, `strata`, `smoothing`, `iconscale`,
`barinset`, `transparentbackground`.

`BarDisplay`'s options table can stay almost unchanged; only settings that the library
silently reinterpreted need a mapping table.

## Why this is worth doing

- **Less work per update**: no per-row column re-anchoring, no library sort-side repair,
  no gradient bookkeeping, fewer text writes.
- **Exact layout**: one column spec shared by headers, values and labels; hidden columns
  take no space; names use the remaining width naturally.
- **No library bugs as product behavior**: stale `barCount`, nil `GetBars()` on empty
  groups, color-cache invalidation, width-sync lag.
- **Animation without fighting the sorter**: the renderer owns row positions.
- **New row content**: multi-segment fills, overkill/absorb overlays, per-row markers,
  benchmark deltas, sparklines, variable row density.
- **New layout modes**: grouped rows, sticky totals, true compact rows, inline values,
  responsive columns, accessibility palettes.
- **Smaller dependency surface**: one embedded library and its XML gone from the
  package.

## Cost and risk

- About 1,200-1,600 lines of new renderer/shell code, plus adapter changes.
- The largest risk is parity, not drawing: title/button hover, headers, themes, scroll,
  resize, reverse growth, saved positions and combat transitions all have edge cases.
- `BarDisplay.lua` is the most exercised display in the addon; a silent regression in
  combat is worse than the current cost.
- Simulator timings are relative. A client benchmark with 25-40 raid rows is required
  before switching the default.
- Secret values and combat-time `FontString:SetText` behavior must be exercised in the
  same matrix as today.

## Migration plan

### Phase 1: prototype

- Add `BarRenderer.lua` and register a separate `bar2` display.
- Reuse the existing options schema and database keys; support one-column, two-column
  and three-column layouts.
- No removal of the library yet.

### Phase 2: parity

- Side-by-side screenshots for every theme, width boundary, mode, and combat/post-combat
  state.
- Exercise secret names/values, total bar, self bar, icons, role icons, tooltips,
  click-through, reverse growth, scroll and resize.
- Benchmark 9, 25 and 40 rows at 10 Hz; require a clear improvement over 6.6 ms at 40.

### Phase 3: switch

- Point the `bar` key at the new renderer.
- Remove `SpecializedLibBars-1.0` from `embeds.xml`, its `lib.xml`, and the
  `NewModule("BarDisplay", "SpecializedLibBars-1.0")` dependency.
- Delete `applyColumnGeometry`, `snapBarRows`, `_skadaColor`, the width-sync hook and
  the empty-group guards that only exist for the library.
- Keep a one-release fallback display if practical.

### Phase 4: new features

Only after parity: multi-segment bars, row groups, per-row markers, alternative row
densities, and the other capabilities that motivated the rewrite.

## Open questions

1. Is `LibWindow` also retired in phase 3, or left for a separate change?
2. Should `bar2` be user-visible in the Display menu during phase 1, or only available
   through `/skada display bar2`?
3. Is a variable row height worth supporting, or should all rows stay on one pixel grid?
4. Which new row feature is the first product requirement: overkill/absorb segments,
   benchmark deltas, or grouped rows?
