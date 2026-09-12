# Refactor and performance audit — 2026-09-11

The current checkout was reviewed across simulation, presentation, saves and
tools. Existing uncommitted feature/artwork work was preserved. This pass changes
neither game rules nor artwork, footprint geometry or the save format.

## Findings and changes

- **HUD stock accounting:** the 28 resource rows previously each called
  `resource_stock`, making 56 building traversals and 28 worker traversals per
  refresh. `SimulationWorld.resource_stocks()` now visits buildings and workers
  once, aggregating their inventories and skipping zero quantities. It returns
  fresh detached values, so same-tick payments, transfers, ownership changes
  and loads cannot leave a stale display. The single-resource query remains
  available. Completed warehouse storage, inputs/outputs and physical cargo
  retain their existing meanings; committed construction materials are excluded.
- **Population overview:** hunger/profession and sleeping totals now share one
  worker traversal. Previously the label and tooltip repeated four traversals.
  Existing fog ownership filtering and standalone tooltip calls are preserved.
- **Transport availability:** task generation and validation stop at the first
  reachable eligible destination. Actual pickup still ranks all eligible
  destinations using the existing distance, inventory and reservation rules.
  This avoids finding the best route when the caller only needs a yes/no result.
- **Unused code/resources:** removed three unreferenced private simulation
  wrappers (`_movement_duration_for`, `_preferred_log_destination`, `_farmer_home`),
  two unreferenced terrain helpers (`_uv_disc`, `_overlay_color`) and a write-only
  `_painted_textures` field. The latter eagerly extracted four atlas swatches
  that the current full-atlas compositor does not use. Public library methods
  remain available and lazy.

## Measurements

Local Apple M4, Godot 4.7.2, debug project. These measure CPU work, not overall
frame rate or performance on other hardware.

| Probe | Before | After |
|---|---:|---:|
| Entire HUD refresh, economy demo (35 buildings, 36 workers) | 0.983 ms | 0.382 ms |
| All 28 resource totals, individual queries vs bulk query | 0.671 ms | 0.178 ms |
| Routes searched to generate one transport task, 8 eligible consumers | 8 | 1 |
| Routes searched to validate that task | 8 | 1 |
| Routes searched at actual pickup, including movement to the chosen target | 9 | 9 |

The HUD comparison used the preserved pre-edit HUD and the final HUD against
the same unchanged world, alternating execution order. After one warm-up round,
eight batches of 500 calls per version were sampled in one headless process
without concurrent project tests. The reported upper-middle batch values show
about **61% less HUD refresh time**. No simulation ticks or saves were written.
The transport test instruments actual path calls; the nearest destination has
the last ID, proving early exit did not leak into actual destination selection.

Reproduce current accounting/HUD timing and the focused regressions:

```sh
godot --headless --path game res://tools/profile_stock_hud.tscn
godot --headless --path game res://tests/transport_search_runner.tscn
godot --path game --audio-driver Dummy --windowed --resolution 1440x900 res://tests/refactor_runner.tscn
./tests/run-headless.sh
```

The stock profiler compares the retained individual resource queries with the
bulk query on the current demo. Its current HUD timing does not recreate the
historical HUD implementation automatically. Run profiles without other
test/render jobs. The focused runner uses isolated fixtures and existing UI,
fog and terrain suites; it does not overwrite player saves.

## Verification

- Original full headless suite: **755/755**.
- Extended full headless suite: **762/762** after the functional changes.
- Final focused native OpenGL suite: **81 cases, zero failures**, including the
  final zero-quantity fast path, physical stock transfers, explicit/default
  owners, same-tick freshness, detached results, transport capacity and
  reservations, HUD layout, hunger, sleeping, fog, inspector and terrain caches.
- No GDScript parse/runtime errors; diff whitespace checks passed. The usual
  sandbox macOS certificate/log-access diagnostics were environmental.

## Remaining candidates

The initial runtime inventory was **17,102 lines across 60 scripts** (7,754 in
simulation, 9,348 in presentation). Tests account for another 26,148 lines.
Relative to the last commit, simulation grew by about 17% and presentation by
39%. Much of this is implemented features and regression coverage, not dead code.
The 1,078-line snapshot module contains transactional validation and historical
save migrations; it is not a safe target for indiscriminate deletion.

1. `main_view.gd` redraws fields and deposits by scanning every entity for each
   map row. The economy demo performs 30 × (16 + 10) = 780 row-membership checks
   per frame. Grouping once by row could reduce this, but needs measured frame
   impact and fog/render lifecycle coverage.
2. Building geometry and fog observer lists are reconstructed repeatedly during
   drawing. Measure their cost before adding caches with invalidation rules.
3. Workplace lookup repeatedly scans all workers, including during candidate
   task validation. A live index needs correct updates for assignments, death,
   profession changes and load; profile a larger settlement first.
4. Definition files are parsed again for new worlds and staged loads. A shared
   parsed cache with independent copies could reduce startup/load cost. Snapshot
   validation could likewise index deposits by position instead of repeated scans.
5. The largest UI/view modules can be split by responsibility when those areas
   are next changed. Moving code alone does not reduce runtime work. Small
   duplicated assertions and compatibility wrappers do not justify a new
   framework or an API break by themselves.

Production art records and QA captures outside `game/` are development evidence;
their disk size is not runtime memory or per-frame CPU cost.
