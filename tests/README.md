# Tests

Run `./tests/run-headless.sh` from the repository root. The launcher loads
`game/project.godot` and runs `res://tests/test_runner.tscn`; project verification
does not use isolated `--script` execution.

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
| Calendar clock | 7 | Exact phase/day boundaries, ten-minute cycle, old/current saves and large ticks |
| Calendar clock HUD | 4 | Actual pause/speed controls, tooltips and responsive clock |
| Civilian daily schedule | 10 | Exact work/rest boundaries, owned huts, communal warehouse entry/exit, paused production/construction, no home, blocked cargo, movement continuity and active guards |
| Night schedule save compatibility | 9 | Actual sleepers, cargo conservation, route rebuilding, v13/v14 migration, malformed bedrooms, shared doorway, night meal and new workplace |
| Night meals and deferred cargo | 6 | Released military stock reservations, retained loaded ration, night meals across sleep/save/dawn and empty Inn without night logistics |
| Night schedule HUD | 5 | Selected worker status, building/local/global sleeper counts, preserved cargo/population, military exclusion and 900px layout |
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
