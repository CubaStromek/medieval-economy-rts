# Packed pathfinding index — 2026-09-14

Movement stuttered in a modest settlement because single simulation ticks
occasionally took hundreds of milliseconds. Profiling showed that almost all of
that time was route searching: an idle Carrier evaluated every transport task
with a full A* search, and one search on the 34 × 30 economy map took about
3.7 ms in GDScript. Each neighbor check recomputed walkability, slopes and
terrain definitions, and every heap entry was a new Dictionary.

Gameplay rules, routes, tie-breaking, movement costs and the save format are
unchanged.

## Implementation

- `GridPathfinder.PathIndex` stores walkability, doubled cell heights, all eight
  traversable edges and connected regions in packed arrays per grid
  (`grid.path_index`). Edges use exactly `GridMapSim.can_traverse()`: cardinal
  height access, walkable diagonal flanks and all four corner height checks.
- Searches read dynamic data live every time: temporary blockers, stone roads,
  natural trails and their established links, and the current terrain/overlay
  move ticks. Only connectivity changes update the index.
- The heap stores `priority × cell_count + cell_index` integers. This is exactly
  the historical (priority, row, column) ordering, so equal-cost routes resolve
  identically. `find_path_to_nearest` uses the same packed Dijkstra; nested
  searches from a goal test are independent.
- `GridMapSim` records the cells changed by `block`, `unblock`,
  `set_base_terrain` and height edits. The index updates only those cells and
  the edges within one cell of them. `configure_movement`, a revision bumped
  without tracked cells, or `invalidate_connectivity()` after bulk array
  replacement forces a full rebuild.
- A goal in another static region is rejected before searching; blockers only
  remove edges, so such a goal can never be reached. `is_reachable()` answers
  "would an unblocked search find a route" from the regions alone.
- Transport task generation and validation only ask whether any receiver is
  reachable, so `_ware_destination(existence_only)` now uses `is_reachable()`
  instead of building a route. Actual pickups still rank all destinations by
  real route cost.

`Workplaces` keeps its bounded search on the retained Dictionary heap helpers.

## Equivalence

- `fast_path_equivalence_tests.gd` keeps the historical Dictionary A* and
  Dijkstra as a reference. It compares routes and reachability on the running
  economy demo with an established trail, with and without worker blockers. It
  also checks nearest-goal searches, incremental updates against a fresh
  rebuild after block, terrain and height changes, untracked revisions, bulk
  replacement and nested searches.
- An independent prototype matched every route on the economy demo (1,344
  pairs), the player's save (417) and Mountainous Region (300, 143 × 127 map).
- A deterministic simulation-only profile ran the previous and the new code for
  600 ticks. The complete world state hash matched at ticks 150, 300, 450 and
  600 in every scenario below.

## Measurements

Local Apple M4, Godot 4.7.2 headless, simulation only, 600 ticks. These measure
simulation CPU, not frame rate on other hardware.

| Scenario | Mean tick | p95 | Worst tick | Ticks over 16 ms |
|---|---:|---:|---:|---:|
| Player save (28 × 22, 13 citizens) | 5.34 → **0.97 ms** | 31.5 → **1.9 ms** | 273 → **9.4 ms** | 51 → **0** |
| Economy demo (36 citizens) | 20.35 → **3.65 ms** | 97.7 → **7.8 ms** | 508 → **22 ms** | 108 → **3** |
| Economy demo + 40 Carriers | 830 → **45 ms** | 9,959 → **412 ms** | 18,048 → **736 ms** | 301 → 185 |

A single route search became about 24× faster on the economy map and 32× on
Mountainous Region (about 475 ms → 15 ms for a long route).

## Remaining candidates

1. The deliberately overcrowded +40 Carrier stress case is still expensive.
   The remaining cost comes from congestion: blocked workers replanning,
   `_path_with_yielding` relaxation retries and `IdleYieldRoute` searches, plus
   `_temporary_blockers_for` rebuilding a Dictionary for each query.
2. `_assign_task` still runs one A* per candidate task. A single multi-target
   search could rank them, but must reproduce the yielding fallback exactly.
3. Drawing: building geometry caching and retained procedural building layers
   were added the same day (see [render performance](render-performance.md));
   placeholder houses still submit roughly 100 GPU draw calls each.

Reproduce the comparison with a simulation-only script that constructs the
world exactly like `MainView` (economy demo with fog, or the default save via
`SaveSystem.load_world`), steps a fixed number of ticks and hashes
`JSON.stringify(world.to_data())`. Run it against two checkouts one at a time.
