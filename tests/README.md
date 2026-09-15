# Tests

Run `./tests/run-headless.sh` from the repository root. The launcher loads
`game/project.godot` and runs `res://tests/test_runner.tscn`; project verification
does not use isolated `--script` execution.

## Release 0.6.0 verification — 2026-09-15

Release checks for 0.6.0:

- The complete headless suite passed **787/787**. It passed again in a clean
  copy created from the staged index after a fresh import.
- The focused native refactor and rendering runner reported **79 cases,
  0 failures**.
- Tool tests: painted-terrain exporter 6/6; terrain importer 17 passed with
  1 optional real-map test skipped; PixelLab client 16/16 with Pillow.

See the [release verification record](../docs/release-verification-2026-09-15.md).

## Game time held like KaM Remake — 2026-09-14

`timekeeping_tests.gd` adds **5 cases**. They check that a long frame replays
every owed tick, that uneven frames and speed changes keep exactly the same game
time, that a stall replays only the capped 100-tick backlog, that an exhausted
frame budget leaves ticks owed for later frames, and that restart and load do
not replay loading time. `sawmill_operation_tests.gd` now consumes the scene's
clock restart before its first `_process()` call. Measured with real frames,
the economy demo at 2× keeps 100% of game time with both loops. The economy
demo with 40 extra Carriers at 2× keeps 35% instead of 17%. The full headless
suite passed **787/787**; native suites were not rerun.

## Retained building layers — 2026-09-14

`building_layer_tests.gd` adds **4 cases**: cached building geometry reuse and
invalidation by terrain height and ground-preparation progress; procedural
building layers redrawing only after selection, saved-state or grinding-mill
tick changes; exact layer order of units before and after a building in the
same row; and immediate hiding of a removed building's layer. Twenty
deterministic native captures were pixel-identical before and after the
change; see [render performance](../docs/render-performance.md).
The full headless suite passed **782/782**; native test suites were not rerun.

## Packed pathfinding index — 2026-09-14

`fast_path_equivalence_tests.gd` adds **4 cases** that compare the packed A*,
nearest-goal Dijkstra and reachability against the retained historical
Dictionary implementation: real economy-demo routes with an established trail
and worker blockers, local index updates versus a full rebuild, untracked
revisions, bulk terrain replacement and nested searches. The transport search
suite now expects existence checks to use one reachability query and no route
search. See [pathfinding performance](../docs/pathfinding-performance.md).
The full headless suite passed **778/778**; native rendering checks were not rerun.

## Day/night removal — 2026-09-14

The calendar, solar lighting, sky clock, night schedule, Workers' housing and
night wolves suites were deleted with their features. Hunger, nutrition, life
presentation, foundation and footprint suites now expect a constant 390
milli-condition tick, no night state and a 29-building catalog.
`day_night_removal_save_tests.gd` adds **4 cases** for loading v22 sleep, wolf
and cottage data into save v23. The full headless suite passed **774/774**;
native rendering checks were not rerun. Sections below are historical milestones.

## Publication verification — 2026-09-12

The current project was rerun with Godot **4.7.2**: **762/762** full headless
cases and **81/81** focused native OpenGL cases passed. The local Python
PixelLab client suite passed **16/16**, including its Pillow-dependent case;
no live API generation was invoked. Commands and clean-checkout verification
are recorded in [the publication report](../docs/release-verification-2026-09-12.md).
Older counts below are historical feature milestones, not the current total.

## Refactor and runtime work — 2026-09-11

The extended full headless suite passed **762/762** after the stock/HUD and
transport-search changes. The final focused native suite passed **81/81**,
including stock ownership/freshness, physical deliveries, unchanged destination
ranking, hunger/sleep/fog UI and retained/painted terrain. Run
`godot --path game --audio-driver Dummy res://tests/refactor_runner.tscn`.
The [audit and measurements](../docs/refactor-audit-2026-09-11.md) distinguish
measured improvements from remaining candidates. No gameplay/save/art changes.

## Lumber hut footprint v2 — 2026-09-10

The current complete runner passed **755/755 headless cases**. The new
`lumber_hut_footprint_tests.gd` suite adds **12 cases** for the nine-cell
4×3 mask, recessed doorway, placement/leveling/cancellation, real paid
construction and wood transport, historical v0/v1 plus current v2 saves,
atomic invalid-load rejection, and both connected authored road networks.
Run `godot --headless --path game res://tests/lumber_hut_footprint_runner.tscn`.

The actual construction, stock, footprint-input, Relief viewport and slope
suites also passed **41/41 natively**. [Footprint QA](../docs/art/qa/lumber-hut-footprint-v2/README.md)
contains 61 native visual samples, unchanged-art hashes, exact hover/click
matching, and the normal menu → Relief → physical log delivery journey
(7 phases, 17 captures, zero failures). `res://tools/preview_lumber_hut_footprint.tscn`
reproduces its visual fixtures. No house PNG, construction mask or art
registration changed. Explicit historical fixtures keep their independently
measured v1 corridors/64-tick earthwork; new v2 behavior is tested separately.

## Lumber hut stored logs — 2026-09-10

The complete runner passed **743/743 headless cases**. The stock suite passed
**8/8 headless and natively**, covering actual 0–6 assets, physical producer
handover/carrier pickup, reservations, save/load, construction, privacy,
paused/disabled work, alpha selection, six rendered log-end pixel controls
and night lighting. The final added stock-only alpha-picking assertion was
also rerun in the focused headless/native suite.

Run `godot --path game res://tests/lumber_hut_stock_runner.tscn` for the focused
suite. `res://tests/lumber_hut_stock_game_runner.tscn -- --speed=4` exercises the
real menu → Relief → harvest → hut delivery journey (7 phases, 17 native
captures, zero failures). `res://tools/preview_lumber_hut_stock.tscn` captures
all stock levels and contexts. [QA and actual images](../docs/art/qa/lumber-hut-stock-v1/README.md)
separate synthetic stock fixtures from the real delivery. The original house,
all construction masters/masks and their registration remain unchanged;
the footprint/art grounding bug was deferred at that milestone and is now
handled by the separate v2 geometry revision above.

## PixelLab lumberjack in the normal game — 2026-09-10

The complete project scene runner passed **735/735 headless cases** in Godot
4.7.2 after integration and the shadow-precision fix. The added suites cover
6 real-asset/alpha cases, 10 observed-animation state cases and 13 actual
MainScene cases, plus one captured native shadow geometry regression.
This includes all 24 clip/direction combinations, motion/work/cargo transitions,
pause, shared loading/fallback, real save/load, indoor/fog visibility, all-eight
work-stance continuity and alpha selection behind a foreground tree.

[Native game QA](../docs/art/qa/lumberjack-pixellab-game-v1/README.md) separates
22 artificial-state screenshots and independent pixel controls from the real
menu → Relief → harvest → delivery journey. Reproduce the natural run with
`godot --path game res://tests/lumberjack_game_integration_runner.tscn -- --capture=/private/tmp/lumberjack-game-review --speed=1`.
Use `--no-capture --speed=4` for the logic-only faster journey. The runner uses
isolated save paths and preserves player saves. The final recorded native run
contains 17 phase screenshots and 60 observed frames of a real chopping cycle.

## Lumber hut construction — 2026-09-10

The complete scene runner passed **705/705 headless cases** in Godot 4.7.2.
`lumber_hut_construction_tests.gd` adds **12 cases**, also verified **12/12
natively**: all 33 graphical steps driven by real Builder work and delivered
materials, saved/resumed progress, unchanged costs and footprints, genuine
alpha, selection, earthwork, pause, legacy appearance, fog and lighting.
Stable depth and actual lower-front pixels are checked against an unobstructed
sprite reference to catch terrain erasing the building.

Run the focused scene with
`godot --path game res://tests/lumber_hut_construction_runner.tscn`.
The [72 native QA captures and animation](../docs/art/qa/lumber-hut-construction-v1/README.md)
record artwork validation separately from the simulation tests.

## Workers' housing — 2026-09-09

`housing_tests.gd` adds **9 cases** for the project-specific Workers' Cottage:
exact two-bed capacity, automatic Carrier/Builder assignment, distribution
between multiple cottages after reassignment, ownership and reachability, unfinished/disabled
residences, Warehouse overflow, dawn departure, JSON round trips and atomic
rejection of incompatible or over-capacity v20 snapshots.

The complete project scene runner passed **693/693 headless cases** in Godot
4.7.2. The catalog/geometry suites now verify 30 building types, both
project-balanced 3-plank + 2-stone extensions, and the economy demo's 35
instances occupying 259 cells.

## Unit thoughts and independent work pause — 2026-09-07

Four new suites add **38 cases**:

- `activity_control_tests.gd`: **12** simulation cases for independent flags,
  physical returns, carried goods, cancelled pickups, closed destinations,
  exporting existing outputs, hunger/sleep/yield and paused services.
- `pause_save_tests.gd`: **9** v20 persistence/validation cases, including
  legacy defaults without resetting nutrition, preserved paid recipes and
  training, construction/earthwork, partial meals and carried military rations.
- `unit_thoughts_tests.gd`: **10** read-only Czech current/next descriptions,
  covering real work, logistics, meals, sleep, blocked movement, pause and fog.
- `inspector_activity_tests.gd`: **7** view/input cases for live indoor details,
  separate unit/workplace controls, services/sites, ownership, stale signals,
  real mouse clicks and scrolling long nutrition text in a 900×720 inspector.

The complete project scene runner passed **684/684 headless cases** in Godot
4.7.2 without parse or runtime errors, extending the previous 646-case baseline.
The new inspector/input suite also passed **7/7 in native OpenGL**, with actual
900×720 renders checked for readable thoughts, separate pause reasons and
scrollable nutrition/construction controls. The pause save suite passed
**9/9 natively**; affected existing nutrition UI checks passed **17/17**.
See [feature rules and implementation](../docs/unit-thoughts-and-pause.md).

## Gentle seven-day nutrition — 2026-09-07

The complete project scene runner passed **646/646 headless cases** in Godot
4.7.2, without parse or runtime errors. Three new suites add **26 cases**:
thirteen simulation cases, eight v19 save cases and five nutrition UI cases.
The affected UI suites also passed **17/17 in native OpenGL**, and nutrition
save cases passed **8/8 natively**. The actual 900×720 inspector was rendered
and checked in fed, empty, weakened and starving states without overflow.

Coverage includes a full 42,000-tick no-food simulation with actual sleep and
fog, exact death for civilians and soldiers even when spawned off the global
clock phase, half sleeping appetite without extending the seven-day reserve,
fully fed new professions, unchanged carrier movement, progressive recovery
without a one-bite reset, 80% outdoor/indoor/construction/earthwork progress,
rescuing a zero-satiety soldier with a real ration, and inactive foreign units.
Save tests preserve partial metabolic, meal-recovery and work remainders;
malformed fields fail transactionally and old saves retain their satiety and
stocks while starting an explicit fresh deprivation history.

An additional isolated **ten-day / 60,000-tick** run used current building
footprints, fog, a supplied Inn, three Carriers and a Carpenter. All four
survived and ate nine real visits each, producing **860 stored planks**. Peak
deprivation stayed below **1.023 days**, never accumulating toward weakness;
the final JSON save/load was exact. No player save or running game was changed.

## Fog of war — 2026-09-07

At the fog milestone, the combined project runner passed **620/620 cases** both headless
and in native Godot 4.7.2 / Apple M4 / OpenGL Compatibility, without GDScript
parse or runtime errors. Four new suites add **31 cases**: ten simulation and
ownership cases, nine save/validation cases, eight view/input cases and four
actual gameplay activation cases.

Coverage includes three map states, circular sight and footprint centers,
completed buildings/towers, indoor and dying observers, retained exploration,
strict ownership, inert foreign economy placeholders, observer-cache/delta
invalidation, transactional v18 loading and pre-v18 migration. Actual scene
tests exercise all normal new-game maps, restart, legacy activation, intentional
disabled saves, hidden selection and controls, whole-footprint placement,
local HUD accounting, stale sprite/shadow callbacks and real mouse input.

Native image assertions compare a hidden enemy with the same scene with that
enemy removed: sprite, shadow, carried gold and satiety leave no pixels. They
also check black unknown ground with F2 overlays enabled, remembered ground,
unchanged visible ground and height-correct foreground occlusion. Movement
does not rebuild terrain or fog geometry; actual height edits provide the
positive invalidation control. The inspected native illustration is
[fog-of-war.png](../docs/previews/fog-of-war.png).

The 256×256 / 60-observer native benchmark reduced a simultaneous sight/mask
update from 36.15 ms to 14.35 ms by retaining projected fog geometry. See
[rules, limitations and measured costs](../docs/fog-of-war.md).
Existing migration assertions now explicitly expect legacy all-map knowledge;
the terrain-hover suite authors a surveyed map to isolate terrain explanations.
The player's saved games and running map were not reset or overwritten.

Native pixel tests require their own test window to be visible: a hidden or
minimized macOS window can suspend `frame_post_draw` without a script error.
If needed, restore only the verified test-process window, not the player's game.

## Menu map selection and graphics sandbox — 2026-09-07

The combined game runner passed **572/572 cases**, and the separate graphics
sandbox runner passed **40/40**. All **15 menu cases** also passed with native
Godot 4.7.2 / Apple M4 rendering. The six additional menu cases cover sandbox
entry/return with and without a paused game, the fourth map's starter and reset,
missing/wrong imports, and both independent save slots after restarting the
session. Fixtures use synthetic terrain and temporary saves, without requiring
the optional local source map or overwriting either player slot.

Native previews additionally verified the real Mountainous Region start and
existing graphics workbench opened through the menu. Both corresponding launch
flags were checked. Opening/closing the sandbox does not write its presets.


## Graphics sandbox — 2026-09-07

The separate asset-independent sandbox runner covers **27 cases**: eight prior
terrain-reference cases, eight renderer-control cases, seven object-layer cases
and four versioned-state cases. It is intentionally separate from the main
simulation suite:

```sh
godot --headless --path game res://tests/terrain_sandbox_runner.tscn
```

Native verification also covered unchanged default pixels, live layer controls,
actual checkbox/wheel input, small-window layout, screenshot + settings export
and both local source crops. The private source atlas and map fixtures are not
required for the synthetic suite. See [sandbox verification](../docs/terrain-graphics-sandbox.md).

## Mountainous Region starter — 2026-09-07

The complete combined project runner passed **572/572 cases** in Godot 4.7.2.
Four new asset-independent cases cover the canonical map identity, completed
Warehouse and School footprints, the unobstructed route between their doors,
exact totals of 50 gold and 20 each of logs/planks/stone, zero unrequested
wares, first-Carrier delivery for a second profession, and a complete v17 JSON
roundtrip. The gold breakdown is intentionally 49 in the Warehouse plus one in
the School, preventing a citizen-free start from deadlocking.

## Mountainous Region external terrain — 2026-09-06

The complete combined project runner passed **552/552 cases** with no GDScript
parse or runtime errors, preserving the concurrently completed movement and main-menu changes.
The terrain-only import milestone added **16 cases**: seven loader/simulation
cases and nine actual-scene view cases. They author synthetic maps and need no
original data. The later canonical starter coverage is described above.

Coverage includes all shared height vertices and orientation, terrain/tree
validation, no accidental settlement on generic imports, slope/rock/water placement rules, actual
pathfinding through a river gap, normal v17 JSON saves, explicit missing-map
fallback, scene reset, full-map camera fit, wheel input, resize behavior,
retained terrain caches, separate save slots and real F5/F9 temporary-file
roundtrips. Large-map tree culling retains near-edge offscreen casters and never
culls workers or changes simulation state; the default starter remains intact.

The separate Node converter suite passed **18/18**, including the optional
independent full raw-file check of Mountainous Region. The actual imported map
also passed Godot loading, complete v17 JSON roundtrip, continued ticks and
four cross-map routes with every step checked. Native screenshots show the
real scene in overview and close-up. See
[provenance, local setup and limitations](../docs/mountainous-region.md).

## Main menu and saved sessions — 2026-09-06

The combined project runner passed **536/536 cases** in Godot 4.7.2.
The nine new menu cases also passed with native Apple M4 / OpenGL rendering.
They exercise real button and keyboard input, both menu layouts (1152 × 720
and 1680 × 720), all three map choices, paused simulation/input isolation,
saving and resuming, missing/corrupt saves, and restored time, inventory and
map identity. Fixtures use temporary save files and preserve the player's slot.
Normal startup and both demo launch flags were checked separately, including
selecting a different map after launching with a demo flag. Native screenshots
are in `docs/previews/main-menu.png`, `map-selection.png` and `pause-menu.png`.


## Idle carriers blocking narrow doorways — 2026-09-06

The complete combined project runner passed **527/527 cases** both headless
and in native Godot 4.7.2 (Apple M4 / OpenGL Compatibility), with no GDScript
parse or runtime errors. The new suites add **16 cases**: nine narrow-lane
scenarios with production building footprints, four recovery cases after
cancelled movement, and three cases where a retreat's destination changes.

The reported loaded-lumberjack/idle-carrier blockage was reproduced before
the fix: the carrier could only select an immediate off-route neighbor, so
neither planning nor execution could use a clearing farther along the lane.
Tests now cover multi-step retreat, a dead-end hut doorway, blocked indoor
exit, both worker-ID orders, timed reciprocal passing, per-step interpolation
and origin reservations, shared distant pockets, busy-worker/guard protection,
trail-wear suppression, cargo and workplace conservation, and save/reload.
Separate cancellation and dawn cases catch an idle movement cooldown that
previously never finished. Dynamic-obstacle cases ensure a lost resting place
does not strand the carrier permanently in a busy `yield` state.

Historical no-pocket fixtures now close the lane's tails as well: a clearing
several tiles ahead or behind is a valid escape, not a permanent blockade.
Tests use their own worlds; the player's running map and saves were untouched.

## Builder foundation preparation — 2026-09-06

The complete combined project runner passed **511/511 cases**, with no
GDScript parse or runtime errors. The new suites add **28 cases**: 13 physical
simulation cases, nine save/validation cases and six real-scene presentation
cases. Native rendering separately exercised actual placement on the unchanged
starter hillside, progressive Builder earthwork, Carrier deliveries and final
construction. The cost remained exactly 3 planks + 2 stone for the Hut.

Checks cover no-Builder and empty-stock controls, ordered preparation before
materials, one-unit terrain steps, protected neighbors, future surface
reservations, dynamic worker obstruction, cancellation, exclusive Builders,
night pause/resume, exact partial-work JSON checkpoints, legacy v1–16 behavior
and transactional rejection. Actual pointer input checks the gold preview and
every footprint tile; frame-driven presentation checks stakes, working shovel,
paused cues and the transition to ordinary construction.

The existing slope-readability negative control now uses a genuinely too-uneven
but walkable grassy site. Gentle slopes are positive preparation cases; the
independent flat-rock rejection and road-on-slope controls remain.
Inspected previews: `docs/previews/foundation-preview.jpg` and
`docs/previews/foundation-working.jpg`.
See [mechanics and save v17](../docs/foundation-preparation.md).

## Building footprints — 2026-09-06

The complete combined runner passed **483/483 cases** with no GDScript parse or
runtime errors. This adds **32 groups**: 14 simulation/geometry, eight save
compatibility, three full-economy integration and seven viewport/rendering groups.
The native game view was also inspected for completed buildings and actual
mouse-hover placement with its eight-cell Sawmill mask and blue doorway.

New suites use default production worlds and actual catalog geometry. They
exercise every production recipe, all 30 demo types across 35 buildings and
259 occupied cells, physical wood and stone
transport, indoor work, crowded exits, sleep/wake, construction cancellation,
all mask-cell blockers, diagonal movement and in-flight visible steps, nearest
footprint extraction range, legacy/current mixed saves and malformed data.
The existing starter bootstrap and uphill relief logistics also use real masks.

Compact historical fixtures explicitly use `legacy_world_fixture.gd`, which
returns the production simulation configured to author supported version-0
buildings. Their prior economic/movement assertions continue testing old-save
behavior; this helper is never loaded by the game. Current scenarios and new
footprint suites do not use it. See [geometry and provenance](../docs/building-footprints.md).

Inspected images: `docs/previews/building-footprints-village.png` and
`docs/previews/building-footprints-placement.png`.

## Sunlight and sky display — 2026-09-06

The complete combined runner passed **451/451 headless cases** in Godot 4.7.2,
with no GDScript parse or runtime errors.

The lighting feature adds **20 cases**: eight pure solar-cycle checks, five
sky-display UI cases and seven actual-scene lighting/shadow cases. Focused runs
passed all twenty; the seven integration cases also passed with native rendering.
The native pixel check proves that the HUD keeps its color while the map darkens.

Coverage includes smooth dawn/sunset and midnight wrapping, very large saved
ticks, opposite morning/evening shadows, the real 0.5×/1×/2× and pause controls,
load/reset synchronization, unchanged simulation snapshots and retained terrain
mesh identities. Shadow outlines follow independently checked terrain heights,
clip to map rows and stop drawing for workers who enter buildings. The sky
display fits 900/1152px layouts, yields clicks to the map and hides behind menus.

Native inspections covered dawn, morning, noon, sunset and night, plus both
low-sun angles on the starter map's raised terrain, without triangulation errors.
Inspected screenshots: `docs/previews/solar-morning.png`, `solar-noon.png`,
`solar-sunset.png` and `solar-night.png` in the same directory.

## Civilian daily schedule — 2026-09-05

The final combined runner passed **431/431 headless cases** in Godot 4.7.2,
including the completed food integration and all night-schedule suites, with
no GDScript parse or runtime errors. Native rendering checks are described below.

The night schedule adds **30 cases**: ten simulation lifecycle cases, nine
save/compatibility cases, six night-meal/cargo cases and five actual HUD cases.
Focused runs passed all thirty. Coverage includes the exact 20:00/05:00
boundaries, every role's work eligibility, actual lumberjack/forester/fisher
returns to their own huts, six people sharing a warehouse and physically
leaving for morning jobs, paused paid recipes/construction, released work
reservations, preserved cargo, blocked routes and completed visual steps.

Save checks cover shared virtual doorways, repeated JSON reloads, legacy
night migration, deferred rations, transactional corruption rejection and a
previously unemployed specialist switching from Warehouse to its new hut.
Night meals preserve cargo through sleep, an Inn visit, a save and dawn;
military requests survive the pause in civilian deliveries.

Native rendering verified six sleeping civilians, the soldier remaining
outside and the original carried stone delivered after dawn. The inspected
previews are `docs/previews/night-warehouse-sleeping.png`,
`docs/previews/night-hut-sleeping.png` and `docs/previews/night-morning-work.png`.
These checks cover schedules and indoor visibility; lighting remains unchanged.

## Inns and military supplies — 2026-09-05

The food integration milestone passed **401/401 headless cases** in Godot 4.7.2,
with no GDScript parse or runtime errors. This run was started before the separate
night-schedule suites were registered. It includes the calendar and **54 food
cases**: twelve civilian meals, fourteen military deliveries, eight food saves,
six food controls, eight daily-hunger cases and six satiety UI cases.

Food checks cover seating, meal time and paused hunger, specialist return,
manual orders, four ration types, last-item competition with ordinary logistics,
physical pickup/handoff, changed or missing targets/sources, unreachable routes,
and continued saves without duplicate food. Progressive-course checks include
mid-course saves, course boundaries, already-full diners still eating, and v13
already-paid meal migration. Malformed reservations and meal states must be
rejected without replacing the live world. Two full game days with two different
menus verify daily meals, real production, retained workplaces and nighttime
food visits during rest.

Native rendered inspections verified the Inn inventory/occupancy and soldier
selection/supply panels; previews are in `docs/previews/food-inn-seating.png`
and `docs/previews/food-soldier-supply.png`. New native previews
`hunger-map-satiety.png`, `hunger-eating-progress.png` and `hunger-inn-diners.png`
in the same directory verify the actual bars, hidden diner, rising satiety,
course time and Inn guest details. These native checks are separate from the
headless runner result.

## Calendar clock verification — 2026-09-05

The clock adds **7 simulation cases and 4 real-scene HUD cases**, registered
in the main runner. Both focused project-scene runs passed all **11/11**:
exact minute/phase/midnight boundaries, a complete 6,000-tick cycle, current
and historical v11/v12 JSON saves, continued time with conserved inventories,
large integer ticks, pause and 0.5×/1×/2× speed, tooltips, and 1152/900-pixel
HUD layouts. A native-rendered game check also verified the visible clock at
Day 1 05:00 and Day 2 00:00. These checks cover time and presentation;
NPC schedules and changes in world lighting are not part of this milestone.

## Previous complete suite — 2026-09-05

The runner registers **336 cases**, including ten indoor-worker lifecycle,
six indoor-save and six indoor-visibility cases added after the 314-case hut
milestone. All **336/336 passed both headless and with native rendering** in
Godot 4.7.2 on 2026-09-05, without script errors. Native pixel comparisons also
verified that a hidden worker matches the worker-absent image exactly, and
that exiting restores the original outdoor image including cargo. Hut menu
visibility was also checked natively at 1152 × 720 and 1440 × 900. A separate native window
check verified maximized startup (2560 × 1284 client area on the development
monitor), live 1440 × 900 / 1920 × 1080 / 1920 × 820 resizing, full HUD coverage
and no letterboxing.
Several cases iterate over all catalog recipes
or military definitions; the case count is not the number of individual
assertions or content entries.

| Suite | Cases | Main coverage |
|---|---:|---|
| Main runner | 34 | Terrain/projection, pathfinding, professions, school, trees, stockpile and base economy |
| Worker movement | 6 | Full-tick movement/swap timing and blocked-delivery recovery |
| Eight-way paths | 10 | Eight directions, corner/flank/height constraints, exact 9/6/3 diagonal costs, octile A* vs Dijkstra optimality |
| Diagonal movement | 9 | Actual eight-way steps and interpolation, threshold-crossing wear timing, busy flanks, swaps on all surfaces and crossing traffic |
| Diagonal trails | 6 | Dirt/stone/mixed diagonal joins, actual polygon coverage, relief/UVs and locally updated vs rebuilt meshes |
| Idle yielding | 10 | Both ID orders, physical sidesteps, clearance reservations, no-pocket alternatives, protected workers/guards, cargo/home conservation and mid-yield reload |
| Natural trail wear | 14 | Retained 36-pass strength, 16-pass maintenance, absolute-time decay, sparse state, profile tuning, actual undirected links, movement costs and terrain cleanup |
| Sustained carrier traffic | 7 | Few trips vs sustained real traffic, world-tick regrowth, permanent stone, no yield footprints, actual entry speed, field/deposit cleanup and reloadability |
| Natural trail rendering | 9 | Invisible first three passes, faint weak traces, real 2×2 U routes without invented X, mature and branch regrowth, slopes and local/full rebuild equivalence |
| Trail save compatibility | 8 | Precise v11 cell/link state, scan-phase restoration, legacy migration and transactional corruption rejection |
| One worker per workplace | 20 | All producer professions, exclusive stable homes, paid training, field ownership, return trips, failed-search caching and vacancy/topology invalidation |
| Workplace save compatibility | 11 | Strict v10 home validation and v1–9 migration without shared claims or lost workers/cargo |
| Indoor worker lifecycle | 10 | Exact doorway and completed interpolation, indoor production across batches, real lumberjack round trips, busy exits and idle yielding, no fictitious trail wear, Inn visits and guards/Barracks departure |
| Indoor save compatibility | 6 | V12 indoor work continuation, multiple visitors plus outdoor doorway occupancy in both ID/array orders, 15 atomic corruption rejections, v11 migration, indoor death and blocked saved departures with conserved cargo |
| Indoor unit visibility | 6 | Actual indoor versus outdoor passerby draw entries, safe reappearance, building/citizen/stock details, read-only selection, live and stale draw callbacks excluding sprite/shadow/cargo/hunger, no base-map rebuild |
| Forester hut | 11 | Required completed exclusive home, fixed planting radius, blocked target recovery, arrival/finish validation, save/load, authored demos and actual paid construction/training/planting |
| Fisher hut | 5 | Existing pond and untouched starter terrain/stock, real player-command construction/training/catch/hut/carrier/storage, exclusive hut ownership, homeless/incomplete-hut waiting, finite stock and mid-catch save/load |
| Forester and fisher hut UI | 4 | Actual generated menu entries/categories and placement signals, school tooltips and training actions, range/occupancy details and catalog-driven guidance |
| Save validation | 4 | Malformed data and transactional rejection |
| Grid configuration | 2 | Shared movement defaults and overrides |
| Economy invariants | 2 | Two 3,000-tick scenarios, reservations/inventories and resumed JSON snapshots |
| Production chains | 15 | Wheat fields, field claims/maturity, specialist work, bread, buffers and redistribution |
| Viewport input | 4 | Real keyboard/mouse dispatch, pause/focus, build tools, training and fields |
| Deposits | 9 | Five finite source types, terrain/reachability, exclusive extraction, depletion, output room and snapshots |
| Classic economy | 11 | Recipes, FIFO orders, army equipment, payment, construction, vines, food, trade and Watchtower guards |
| KaM construction prices | 3 | Independent exact costs for all 28 reference buildings, separately attributed Forester Hut project price, road/vine costs and rejection of raw logs as construction planks |
| Construction cost compatibility | 7 | Price decrease/increase, physical legacy delivery and builder completion, completed-site history, legacy-to-current round trip, conservative refunds, strict revision/material validation and old/new HUD prices |
| HUD layout and navigation | 12 | Two window sizes, stock/tool tabs, map-input isolation, school selection, repeat selection, help and Escape |
| Responsive window layout | 5 | Maximized/resizable startup policy, expanding aspect ratio, 16:9 and ultrawide HUD/map fit, real width/height resize signals and retained manual camera zoom |
| Construction cancellation | 7 | Empty/partial/active sites, one-time refunds, builder reuse, carried goods, atomic refusal and save/load |
| Construction cancellation UI | 2 | Actual placement/cancellation clicks at both sizes, distinct Esc behavior, freed tiles and completed-building protection |
| Resource stock accounting | 5 | Every ware, physical transfers, warehouse payments, consumed inputs and construction stock |
| Terrain heights | 9 | Shared corners, triangular samples, barriers, ramps, foundations, edits, real movement, interactions and migrations |
| Terrain rendering | 4 | Shared geometry, surface-conforming roads, picking, occlusion and revision caches |
| Terrain change tracking | 6 | Bounded per-cell stamps, multiple readers, height/surface changes, no-op behavior and legacy revision fallbacks |
| Retained terrain cache | 8 | Local versus full rebuild oracle, real mesh geometry/UV/color/order, retained base layers, camera/zoom without redraw, debug overlay and rebind lifecycle |
| Relief demo | 3 | Authored pass and building sites, 2,000-tick uphill logistics, save/load continuation |
| Minimal test level | 4 | Default startup/R reset, 20 each logs/planks/stone and 50 gold, finite reachable stone, first carrier and paid training, JSON continuation, full player-command bootstrap of hut/sawmill/quarry with six trained citizens and returned new planks/stone |
| Relief viewport | 6 | Real F2/button input, raised ground and roof selection, slope roads/building rules, interpolated feet |
| Square terrain and slope readability | 8 | Exact 40 × 40 geometry/picking, true-height contour meshes, retained row/cache behavior, paused real hover on plateau/slope/rock/road, transient-state immutability, invalid-click Build panel and independent Escape/F2 |
| Unit sprites | 6 | All 29 roles, real PNG alpha and distinct regions, scale/anchors/fallback, read-only motion, real drawing and pause invariants |
| Environment graphics | 8 | All 9 tree regions and full alpha coverage, root anchors/stable species, 16 road masks, mixed shared edges, texture UVs and slope geometry, cache updates and real drawing without simulation mutations |

The classic suite checks all **19 processing recipes** against independent
expected quantities and professions, plus all **14 military recruitment
requirements**. It verifies explicit production orders and active-batch save
state, one-time Gold school payment across load, physical carrier delivery
before Builder work, wheat/vine cycles, Inn consumption/starvation, actual
market quotes and carrier-delivered exchanges. The Watchtower scenario checks
staff assignment, Stone supply, save/load, an Inn visit and return, and the
separation of a posted guard from Barracks recruitment.

Version **12** validation adds actual indoor building references and bounded
visit dwell, while preserving directional trail wear and decay clocks,
exclusive compatible workplaces, corner heights, deposits, field kind/age,
condition, construction materials/progress and per-site cost revisions, paid
training, selected recipes, production orders and service queues. Workers in
versions **1–11** migrate as outdoor citizens; current indoor visitors restore
without taking a visible doorway occupant's reservation. Historical
versions **1–8** preserve the legacy building-price table, including completed
buildings' delivery history. Versions **1–9** migrate shared workplace claims
deterministically while preserving citizens and carried goods. Versions **1–7** migrate explicitly to flat terrain. Earlier v6
production and field checks remain regression coverage; v6 is not the current
save format. The previous four-building milestone's 67-case total is historical.

Input tests dispatch actual viewport events; movement tests advance full
simulation ticks. HUD tests run at 1152 × 720 and 1440 × 900, verify that all
28 resource values are reachable, and use the same buildable tile behind a
panel and on the open map to prove that UI clicks cannot place buildings.
Resource accounting uses independently expected, nonzero quantities for every
catalog ware, checking total stock and the warehouse / buildings / carried
breakdown. Regressions cover hut-only logs, physical transfers without double
counting, warehouse-only payments and consumed/committed materials.
They also cover school training, repeated selection, active tool/speed state,
help/stock popup exclusion and Escape. Native rendered previews at both window
sizes were inspected for construction, school, marketplace, recruitment,
workshop, warehouse, stockpile and controls readability.

Save/load fixtures use unique temporary JSON files and verify their cleanup,
so tests do not overwrite player saves or require access to the user-data folder.

Inspect output for GDScript parse/runtime errors as well as the final result.
The macOS system-certificate warning seen in the restricted local environment
is unrelated to this project-only suite. Tests relying on project resources
must continue to run through the headless project/test scene.
