# Retained terrain performance — 2026-09-05

The bottleneck was repeated submission of thousands of small terrain polygons,
not the HUD stock totals. A carrier's new footprint also rebuilt the complete
map's geometry. Gameplay, routes, tick settings, artwork and saves are unchanged.

## Implementation

- Terrain rows retain CanvasItem drawing commands between frames. Dynamic
  objects use interleaved rows, preserving the original foreground ridge
  occlusion rather than sorting by height-shifted screen Y.
- Base terrain and road/wear layers have independent cell geometry and row
  meshes. Only consecutive equal-texture triangles are merged; transparent
  shoulders and transitions retain their original order and UVs.
- With direction-aware natural trails, one step can update both endpoint
  neighborhoods: at most fourteen surface cells and four surface rows.
  It does not rebuild base meshes. Shared-height/material changes include
  dependent neighbours; definition changes and grid rebinds rebuild everything.
- Bounded per-cell revision stamps support independent renderers without a
  growing change log. Direct legacy revision edits fail safely to a full update.
- Mesh colors use an explicit brightness modulation so bright slope highlights
  survive UNORM8 vertex-color storage. The remaining one-step quantization is
  covered by tests and native pixel comparison.

This uses Godot's [retained CanvasItem drawing](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)
and [ArrayMesh triangle arrays](https://docs.godotengine.org/en/4.7/tutorials/3d/procedural_geometry/arraymesh.html).

## Measurements

Local Apple M4, Godot 4.7.2 GL Compatibility, 1440 × 900 window, default 28 × 22
relief village and 0.5× simulation speed. Measurements are developer-run debug
build results on this machine, not a general hardware guarantee.

| Check | Before | After |
|---|---:|---:|
| Ordinary game, native `--print-fps` | 8–10 FPS | 86–90 FPS |
| Live frame interval, 900-frame post-change sample | — | Mean 11.28 ms, p95 15.71 ms, max 23.70 ms |
| Draw calls per frame | More than 6,300 at startup | Mean 432, p95 451 in live sample |
| Terrain update cost | Roughly 50–70 ms for whole map | Mean 2.95 ms, p95 4.16 ms, max 5.67 ms |

The update-cost sample advanced 240 real simulation ticks and observed 28 terrain
updates: 140 surface cells rebuilt and **zero base-terrain cells rebuilt**.
Across 900 live frames only 42 terrain-row redraws occurred, not 22 per frame.

Six matched native captures cover the relief and full economy villages, startup,
simulation advancement and passability overlays. Every compared map pixel
differs by at most one RGB step out of 255; geometry and occlusion are unchanged.

### Eight-way movement follow-up — 2026-09-05

A new native run after square terrain, exclusive workplaces and diagonal trails
used the explicit relief fixture at 1440 × 900 and 0.5×. Across 900 frames it
measured mean **4.035 ms**, p95 **4.249 ms**, max **19.765 ms**, with only
**12 terrain-row redraws**. These measurements are not a controlled comparison
with the earlier artwork/layout milestone.

The following 240 ticks caused 39 local updates: 365 surface cells and **zero
base cells** rebuilt. Surface updates averaged 7.708 ms (p95 13.765 ms): diagonal
joins have more geometry than cardinal strips, but updates remain local. A
separate warmed-up six-worker probe measured 0.206 ms/tick with unreachable
workplaces, confirming failed-assignment searches remain cached.

## Reproduce

Run only one measured game instance at a time and avoid concurrent test/render
jobs. The profiler does not write saves or change project settings:

```sh
godot --path game --audio-driver Dummy --resolution 1440x900 --script res://tools/profile_rendering.gd -- --relief-demo
```

It warms up for 60 frames, samples 900 live frames, then measures terrain updates
over 240 real ticks. `RENDER_PROFILE` and `CACHE_PROFILE` are printed as JSON.
Replace `--relief-demo` with `--economy-demo` to profile the larger economy
fixture separately. Without either argument the current default is the minimal
test level, not the populated relief village used above.

Regression verification: `./tests/run-headless.sh`. The original rendering
milestone covered 154 cases; see `tests/README.md` for the expanded current suite,
including real row-draw reuse on camera motion, partial updates compared against
a completely rebuilt renderer, road neighbours, shared heights, texture/color
definitions, save/load rebinds, and retained mesh data/painter order.

## Retained building layers — 2026-09-14

Profiling after the day/night removal showed procedural placeholder buildings
as the largest remaining map cost. Every frame each one recomputed its terrain
geometry and re-submitted foundations, walls, roof courses, door, details and
its label, about 100 draw commands per house.

- `MainView.building_geometry()` caches each building's footprint geometry. The
  cache key covers the bound world and grids, the connectivity revision (which
  changes with terrain heights), type, anchor, entrance, footprint version and
  ground-preparation progress. Callers treat the shared result as read-only.
- Each object row still draws its ground layer (deposits, fields, selection)
  first. Its depth-sorted entries are then split into ordered child layers at
  every procedural building. Trees, units and bitmap houses stay in layers
  redrawn every frame, and the row's fog is the final layer. Tree order
  therefore reproduces the original painter order exactly.
- A procedural building keeps its retained CanvasItem drawing until its visual
  inputs change. The signature covers the saved building dictionary,
  selection, a grinding mill's tick, terrain heights and the bound world or
  terrain grid. Bitmap houses are not retained because doors, residents and
  stock animate. Fog only decides whether a building is drawn at all.
- A building that disappears (removal, fog) hides its layer immediately.

This does not reduce GPU draw calls; merging placeholder houses into meshes
would be the next step for that.

### Verification

- Twenty deterministic native captures cover the player's save, the economy
  demo, a selected building, zoom, a construction site through its progress,
  a disabled building and a grinding mill. The simulation was frozen before
  the first frame and stepped explicitly. The pre-change and changed code were
  **pixel-identical in all 20 captures**.
- `building_layer_tests.gd` checks cache reuse and invalidation, redraws only on
  selection/state/mill-tick changes, the complete layer order around a
  building, and hiding a removed building's layer.

### Measurements

Local Apple M4, Godot 4.7.2, 1440 × 900 window, vsync off, 1× speed, 400 live
frames after 100 warm-up ticks.

| Scenario | Frame p50 | Frame mean | Draw calls p50 | Static redraws / 400 frames |
|---|---:|---:|---:|---:|
| Player save (9 buildings, 6 procedural) | 13.95 → **9.38 ms** | 14.41 → **9.83 ms** | 1,174 → 1,174 | 7 |
| Economy demo (29 buildings, 26 procedural) | 38.67 → **18.88 ms** | 41.99 → **21.69 ms** | 4,608 → 4,468 | 41 |
