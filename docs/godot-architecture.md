# Godot architecture

## Design goals

The current Medieval Economy RTS project uses Godot 4.7 and typed GDScript
(verified on 4.7.2; the earlier vertical slice targeted 4.6). Authoritative game
state must be testable without graphics, advance on a fixed tick, use integer
grid coordinates and remain suitable for deterministic replays/multiplayer.
The current 28-building economy extends the first vertical slice while keeping
its model/view boundaries.

## Runtime layers

```text
Input/UI ──commands──> SimulationWorld ──read-only snapshots──> View
                         │
          ┌──────────────┼──────────────────┐
          Grid      Task/Reservation    Economy/Entities
          A*        source + tile       recipes/inventory
```

- **Simulation** (`game/scripts/simulation/`) is `RefCounted` model code. It
  does not depend on `Node2D`, `Camera2D`, frame delta or drawing APIs.
- **View/input** (`game/scripts/view/main_view.gd`) owns camera, selection,
  build controls, interpolation and placeholder drawing. It submits building
  operations to the model and reads model state for display.
- **UI** (`game/scripts/view/game_hud.gd`) is a separate `CanvasLayer` created by
  the view. It reads model queries and emits build, speed and training requests;
  only the view applies those commands. `EconomyActions` owns the selected
  School/workshop/recruitment/market controls and emits requests without editing
  inventories. The stockpile groups all catalog wares into three categories;
  the left panel separates building categories, a scrollable inspector and
  always-visible School/forester help.
- **Data** (`game/data/*.json`) defines resources, buildings, recipes, unit
  tuning, soldiers/equipment, food/trade rules and surface movement costs in
  one place.
- **Economic services** (`classic_economy.gd`) handle recipes/orders, material
  demand, construction, payment, food, recruitment and marketplace services.
- **Finite extraction** (`resource_deposits.gd`) handles deposit placement,
  reachable work cells, source claims, depletion and specialist home delivery.

There is no gameplay Autoload. A scene owns its
`SimulationWorld`, making multiple worlds and tests possible without hidden
global state.

## Fixed simulation time

The view accumulates real seconds and calls `step_tick()` at 10 Hz. Like KaM
Remake (`TKMGame.UpdateGame`), game time is held against real time: a slow frame
replays every owed tick before the next draw instead of slowing the game. The
debt is capped at 100 ticks (Remake's `MAX_TICKS_PER_GAME_UPDATE`), so longer
stalls such as a breakpoint or system sleep are not replayed. Catch-up spends
at most 100 ms of real time per frame and leaves the remaining ticks owed.
Starting, loading or resetting a game restarts the clock so loading time is not
replayed; pause and the main menu owe nothing. Tests call `step_tick()` directly. Visual workers lerp
between `previous_position` and `position`; interpolation never changes the
integer logical cell.

Recipe, growth, construction and movement durations are integer ticks. The
0.5×/1×/2× and pause controls change how quickly fixed 10 Hz simulation steps
are requested; individual economic deltas are never scaled by frame time.

## Terrain grid, trails, roads and placement

`GridMapSim` owns three independent layers. Base terrain is a dense row-major
array of stable IDs (`grass`, `dirt`, `water`, `rock`), surface infrastructure
is a sparse overlay (`trail`, `stone_road`) and building occupancy is held in
`blocked_by`. Grass and dirt are currently walkable/buildable; water and rock
are neither. A surface overlay can change movement cost but can never make an
impassable base cell walkable.

The grid exposes buildability, walkability, deterministic eight-way movement neighbours,
weighted path cost and authoritative movement duration. Both A* and the unit
state machine read the same data-driven values: ordinary grass/dirt `6`, trail
`4`, stone road `2` ticks/cost per cardinal step. Diagonal steps use
`ceil(sqrt(2) * cardinal_ticks)`, currently `9/6/3`. `surface_at()` is retained only as a
legacy compatibility wrapper; new systems read `base_terrain_at()` and
`overlay_at()` separately.

`movement.json` is the shared source of defaults for standalone grids and live
worlds. `DefinitionCatalog` caches the parsed defaults and returns independent
deep copies; partial tuning overrides preserve omitted terrain properties.

Only normal carrier steps on roadable grass or base dirt add traffic wear;
idle yielding is excluded. Cells and canonical undirected links retain up to
36 passes, with absolute-tick decay. Weak wear loses one pass every 200 ticks;
established wear loses one every 400 ticks and remains established at 16 or
more. Decay checks run every 20 ticks over sparse touched state, not the map.
The threshold-crossing step still uses the previous surface speed. Dirt speed
requires the actually established entry link; stone construction remains the
fastest tier. A building resolves an adjacent entrance
before its one-cell footprint is blocked, and placement clears any surface
state underneath it.

`trail_last_decay` preserves fractional decay intervals, and `trail_links`
records direction evidence instead of connecting every neighboring dirt tile.
`add_dirt_trail()` is an explicit map-authoring helper that may create authored
joins; actual traffic never uses it. Surface cleanup removes incident links and
links whose diagonal flanks become impassable. See [`natural-trails.md`](natural-trails.md).

`TerrainRenderer` is a read-only `Node2D` client of this model. A shared
`MapProjection` maps the grid to 40 × 40 ground cells plus shared corner-height
offsets. Deterministic variants, textures and priority-based edge/corner
transitions conform to the same triangles as road surfaces and worker feet.
Base terrain and road/wear overlays have separate cell caches and row meshes.
Contiguous equal-texture commands are batched without texture sorting. Retained
even-Z terrain rows interleave with MainView's odd-Z dynamic object rows; camera
motion and object animation do not resubmit terrain. Per-cell revision stamps
refresh local dependency neighbourhoods while definition/rebind/legacy changes
retain a conservative complete-rebuild fallback. See
[`render-performance.md`](render-performance.md) for profiling and regression coverage.

Next terrain increments:

- further painted terrain and mask atlases; roads and trees already have
  original painted artwork, and shared heights/slopes are implemented;
- rotation for the implemented multi-cell footprints; fixed south-facing masks,
  full-area construction and per-building save compatibility are described in
  [`building-footprints.md`](building-footprints.md);
- connected-region cache for quick reachability rejection;
- stone-road construction tasks instead of immediate completion;
- terrain-dependent wear tuning if later playtesting needs it;
- terrain revision integration with cached path invalidation.

## Entities and definitions

Entities have monotonically increasing integer IDs. Runtime dictionaries are
keyed by that ID and update loops sort their keys. Entity dictionaries are an
expedient prototype representation; the planned promotion is one typed
simulation class per domain (`BuildingState`, `WorkerState`, `TreeState`) or
typed value objects, still independent of scene nodes.

Definitions are loaded by `DefinitionCatalog`:

- `resources.json`: 28 ware IDs, names, category/color/HUD order, market prices
  and food restoration where applicable;
- `buildings.json`: 30 buildings with construction costs/times, category,
  inventory limits, professions, extraction rules, recipes/orders, training and
  recruitment IDs;
- `recipes.json`: 19 input/output batches and project-balanced integer durations;
- `units.json`: 15 civilian professions, training/payment, harvesting, planting,
  carrying and display data;
- `soldiers.json`: 14 Barracks/Town Hall types, equipment/payment and recruit
  requirements; its training-duration metadata is not an active military timer;
- `economy.json`: food condition thresholds, trade-off/special rates, field
  growth, immediate road/vine costs and balance provenance;
- `movement.json`: base-terrain rules/colors, overlay move ticks (also used as
  A* cost) and dirt-trail threshold.

IDs in definitions and saves are strings so content can be extended without
renumbering an enum. Validation/schema checks should be added before modding is
opened to users.

## Work and transport

`TaskBoard` is the authority for claimable jobs. Each task has a stable ID,
kind, source ID/key, target and `reserved_by`. Creation is idempotent per source
key. Reservation and validation happen in one method, so two workers cannot
observe an unclaimed task and both take it.

Workers have explicit professions. Representative state machines include:

```text
lumberjack: idle → claim tree → harvest → carry log → own lumberjack hut
carrier:    claim output/warehouse ware → carry → consumer/site/service or warehouse
gardener:   own Forester Hut → find valid site in radius → walk → plant → cooldown
farmer:     walk to wheat/vine plot → sow/harvest → carry to Farm/Vineyard
extractor:  claim finite deposit → reachable work cell → harvest → carry home
operator:   claim staffed building → walk → work through its selected recipe
builder:    claim supplied construction site → walk → complete construction
recruit:    walk to Barracks or assigned Watchtower → wait for equipment/guard
hungry unit: find supplied Inn → walk → consume food → resume work
```

Gardeners need a completed, exclusive Forester Hut but no player target command.
Their weighted nearest-goal search is limited to Manhattan distance 8 from
that hut (catalog `planting_radius`). Ownership/range is revalidated at arrival
and completion, and homeless Gardeners wait. The search
considers authored terrain, overlays, buildings and entrances, worker occupancy
and exclusive planting-site reservations. Planted trees advance through
sapling and young phases on simulation ticks. Only the mature phase produces a
normal `harvest_tree` task, so the existing lumberjack pipeline needs no
special planted-tree branch.

Production buildings consume inputs once, count down integer ticks and expose
outputs. Generic transport tasks cover all 28 wares. Four equipment workshops
require explicit FIFO recipe orders; `recipe_id`, `production_queue` and
`order_active` preserve the current batch and order through saves. Production
requires appropriate staff and bounded output room. A carrier's completed
steps reinforce its route; specialist steps do not.

As of 2026-09-05, `Workplaces` owns the assignment policy. `worker.home_id` is
the single persistent association; the reverse `workplace_worker(id)` lookup
is derived, avoiding a second stale owner field after death/load. A building's
`worker` definition identifies its one compatible profession. New specialists
claim the nearest completed, reachable, unoccupied building by permanent
weighted path cost and building-ID tie-break. Recruits retain their existing
barracks-order priority and use exclusive ownership only for tower posts.

Once claimed, a workplace is retained during hunger trips, path blockage,
input starvation and output backpressure. Empty slots do not automatically
create citizens. `owns_workplace` gates task selection, arrival, extraction,
field completion, operation and producer delivery. No completed batch or
blocked delivery searches for a replacement home. A waiting unemployed
specialist may claim a new vacancy on its next idle tick. Explicit authoring
requests for a wrong/occupied/unfinished home fail without allocating a unit.
The historical sandbox-only automatic Sawmill remains an authoring exception;
playable economy production requires its assigned specialist.

Save v10 and later strictly validate unique compatible completed homes and carried
output compatibility. It instantiates workers without auto-claiming, so a
home-less saved citizen cannot steal a later saved owner's building. Versions
1–9 retain the first valid explicit owner by worker ID, detach surplus or
obsolete claims without removing citizens/cargo, then let unemployed workers
seek vacancies through ordinary simulation ticks. Existing construction cost
revisions remain independent and are not migrated twice.

Schools are the first entity-producing building type. Their definition lists
trainable unit IDs and queue capacity, while each unit definition owns its
training duration. Explicit UI commands append to a FIFO queue. Training and
completion advance in fixed ticks; a completed unit tries the authored entrance
and then the other cardinal sides in canonical order. If every exit is blocked,
the completed queue head waits at zero ticks without consuming an entity ID.
In the expanded economy a carrier-delivered Gold payment is consumed exactly
once for each queue head. `training_paid` prevents a reload or blocked exit
from charging twice. Older compatibility worlds retain the earlier free
training rules.

Construction sites use the same carrier matching as processing inputs, but
store delivered wares separately until a Builder can work. Advanced player
placement requires materials; authored demo buildings start complete. Roads
and vine fields intentionally bypass carrier/build tasks: their one-Stone or
one-Plank cost is paid from completed warehouses immediately and atomically.

`ResourceDeposits` owns finite Stone, Coal, Iron Ore, Gold Ore and Fish sources.
Workers reserve each source through the shared task board and work only at a
reachable cell or its bank/edge. Successful completion consumes one source
unit together with the exclusive task. Output capacity includes other workers'
reserved extraction and carried yield, preventing simultaneous overfill.

`ClassicEconomy` also handles condition loss and Inn visits, explicit market
exchanges, Barracks equipment recruitment, Town Hall payments and Watchtower
staff assignment. School training and construction have active timers. Ready
trades/recruitment have no extra timer: they resolve at a service update when
payment/equipment, Recruit and exit conditions permit. Soldiers and tower
ammunition currently have no combat system.

A later logistics matcher can add configurable priorities and demand age to
the current route-cost/supply balancing. Reservation tokens can cover source
quantity, destination capacity and worker assignment as an explicit transaction.

## Pathfinding and tile reservations

`GridPathfinder` is deterministic weighted A* on eight neighbours. It minimizes
travel ticks across grass/dirt/stone and uses coordinate tie-breaking. Its
octile heuristic is derived from the minimum configured surface cost, so a longer
stone route can correctly beat a shorter grass route. A returned path excludes
the start and includes the destination. Task selection compares full weighted
route cost rather than tile count. Callers supply the starting cell to
`path_cost(grid, path, start)` so the first diagonal has its correct cost.
`can_traverse()` rejects diagonal corner cutting through blocked/steep flanks;
`can_step()` additionally checks temporary occupancy on both flanks. Cardinal
neighbours remain available for building exits and resource interactions.

The same module also exposes a deterministic Dijkstra nearest-goal search for
autonomous gardener placement. It orders equal-cost candidates by grid
coordinate and uses the same movement costs as A*, so reachability and road
preferences stay consistent across professions.

Both searches use the same binary heap, with priority then canonical cell order.
A* computes its minimum-cost heuristic once per search and skips obsolete heap
entries after a cheaper route is found.

`tile_reservations` records the worker occupying each cell. A worker only moves
after reserving the next cell. Head-on neighbours use an atomic swap: both
positions and both reservation owners change together. After a bounded wait,
a blocked worker replans while treating other workers as temporary obstacles.
If an unladen worker still cannot reach its claimed source, it releases that
task and selects the nearest currently reachable source. Future congestion work
can add wait-age priority and time-expanded reservations for narrow routes while
retaining the one-cell/one-owner invariant.

Idle, empty-handed, task-free units can yield into a safe off-route cell.
`idle_yield_route.gd` first checks immediate pockets, then searches a local
retreat of up to 16 steps / 256 visited cells. It can traverse the requested
lane to a clearing farther away; a dead-end door can use an ordinary timed
reciprocal step past the requester when the clearing is behind them. Busy
workers, unfinished movements and posted tower guards are protected.
Pocket selection avoids building entrances, trees, fields,
deposits and planting claims, and prefers staying off roads. It preserves
`home_id` and holds each vacated tile until that interpolated step finishes.
Simultaneous retreats cannot claim the same resting destination, and yielding
carrier steps never generate trail wear. If that destination closes or becomes
occupied, the worker chooses a new resting place relative to the requester's
remaining route. With no remaining escape it releases the stale yield task
and waits safely instead of staying permanently busy in the passage.
A movement-per-tick guard and brief rest prevent double moves and jitter,
while a lower-ID worker whose idle update already ran can still yield.
If ordinary routing fails, a second search may pass through idle blockers,
but only after the same pure route search verifies a reachable resting place.
A blocker with no pocket stays an obstacle, allowing alternative destinations
to be selected.
Yield paths, clearance reservations and rest timers are transient on load.
An idle worker still finishes any committed movement cooldown after a job is
cancelled, preventing a visually stationary person from remaining permanently
ineligible to yield or enter a building.

The tick scheduler tracks workers already updated in the current tick. A swap
consumes both participants' updates, and cannot involve a worker whose cooldown
was already decremented that tick. Movement duration is therefore independent
of which participant has the lower entity ID.

`planting_reservations` prevents two gardeners or a build/terrain command from
claiming the same future tree cell. It is released on completion or aborted
movement; if no site is reachable, the gardener remains idle and retries after
a data-driven fixed-tick delay.

Building logistics may complete from a legally adjacent cell (including a
diagonal with clear flanks) when the
building entrance itself is occupied. Idle workers carrying ware always resume
delivery before claiming new work, and placement protects existing entrance
cells from being covered by another building.

If a delivery route becomes inaccessible, the worker retains its cargo and
selects a reachable compatible destination using current occupancy. A
specialist retains its original workplace; carriers prefer a reachable
consumer and then a warehouse. Without a destination they wait
for a bounded retry interval, allowing later construction to restore delivery.

## UI, camera and controls

The placeholder view draws an orthogonal 2.5D foundation without proprietary
assets. `TerrainRenderer` owns terrain presentation while `MainView` retains
entities, input and UI. The camera supports WASD/arrows, middle-mouse drag and
wheel zoom. Left-click uses the shared projection to select a tile and apply
the selected road/building tool. Successful load/reset operations rebind the
renderer because `SimulationWorld` replaces its grid object.

`GameHud` builds a 340-pixel left panel with mutually exclusive Build/Details
views. Visible Infrastructure/Food/Mining/Military buttons organize construction;
the selected tool and speed have persistent highlights. Explicit selection/tool
commands also reveal the appropriate view when their values have not changed.
Long lists scroll independently, and selected tools scroll into view. `EconomyActions`
shows all 15 School professions and gold cost, workshop recipe orders,
Barracks/Town Hall equipment requirements and Marketplace quotes. Its signals
route through `MainView` to `queue_unit_training`, `queue_production`,
`queue_recruitment` and `queue_trade`; UI never deducts wares itself. Gardener
is explicitly described as the autonomous forester.

Unfinished buildings expose **Cancel construction** in Details, separately
from **Stop placing / Esc**. The HUD routes cancellation through `MainView` to
`SimulationWorld.cancel_construction(id)`. It plans a full material refund to
reachable completed warehouses before mutation, respecting per-ware capacity
and incoming cargo. Failure leaves the site/workers untouched and reports why.
Success removes source tasks and grid blockage, releases builders, clears old
building references and reroutes loaded carriers without discarding cargo.
Completed/missing IDs are rejected; the view clears selection and placement
after success. Cancellation preserves the existing save format.

The overview bar keeps Logs/Planks/Stone/Bread/Gold visible. All stocks opens
`ResourceStatusBar` with Materials/Food/Equipment tabs and all 28 resources,
total-stock labels, a warehouse / buildings / carried breakdown and procedural
`ResourceIcon` drawings. Both views read `SimulationWorld.resource_stock()`;
overview tooltips expose the same breakdown. The total includes completed
warehouse storage, building inputs/outputs and each worker's current ware once.
Materials committed to construction or consumed when a recipe starts are
excluded. `stored_amount()` retains its warehouse-only meaning for payments,
and `pipeline_amount()` retains its existing production/transport semantics.
The popup closes through its button or Escape; it excludes the Controls popup.
The selected
inspector shows live inventory, delivered construction materials, recipes,
input capacity, staff and simulation status. Fields/deposits display growth
or remaining stock. Long inventories and recruitment costs use separate lines.
The bottom bar contains time, citizens/hunger, speed and Controls. The event
strip displays the latest message; its tooltip retains the recent history.

The renderer draws wheat/vine growth, finite-deposit marks, construction
scaffolds/progress, building motifs and profession marks. Field age and factory
animation read simulation state. Camera fitting puts the initial 34 × 24 map
beside the left panel, with ordinary pan/zoom still available.

`MainView._input()` handles Space before GUI dispatch, consuming press, repeat
and release events. Only a distinct press toggles pause. Focused buttons remain
keyboard-accessible with Enter without also acting on the pause shortcut.

UI must remain a client of simulation queries/commands. It must not directly
edit authoritative inventory dictionaries. Signals or immutable
presentation snapshots can replace the current polling when the interface
grows.

## Day/night cycle removed — 2026-09-14

The former `DayCycle`, `SolarCycle`, `SolarShadows`, `SkyClock`,
`DailySchedule`, `Residences` and `NightWolves` modules were removed at the
user's request. `SimulationWorld.TICK_SECONDS` (0.1 s) is the shared fixed tick.
There is no calendar or lighting state: `MainView` no longer modulates the map,
and object rows draw no cast shadows. Civilians are eligible for work at every
tick. `Nutrition.BALANCE_DAY_TICKS` (6,000) only converts the historical
"day" balance values in `economy.json` into ticks.

## Saving

`SaveSystem` handles JSON file I/O in `user://`; `WorldSnapshot` owns snapshot
encoding, typed field validation and version migration. `SimulationWorld`
retains the public `to_data()`/`from_data()` API and commits a staged world only
after successful loading. **Current version 20** contains the terrain/grid, inventories,
worker professions/homes/cargo/cooldowns, tree ages and field ages from earlier
formats, plus field kind, finite deposits, `economy_enabled`, worker condition,
construction remaining/delivered material, school payment, selected recipe,
production queue/active order and service queues. Tower guard assignments use
the worker home reference. Active processing retains already-consumed inputs.
Version 8 adds shared corner heights, version 9 adds per-site construction cost
revisions, version 10 validates exclusive profession-compatible workplaces,
and version 11 stores retained trail wear, absolute decay timestamps and actual
directional links. Loading restores the periodic decay scan phase without
aging or adding traffic, preventing a reload from changing regrowth timing.
Version 12 adds `inside_building_id` and `indoor_wait_ticks` (0–6). A visit is
separate from `home_id`: an Inn visitor still owns their normal workplace.
Indoor positions refer to the exact entrance of an existing completed building
but own no outdoor tile reservation. Multiple indoor people and a single
outdoor door occupant can coexist. Restoring indoors uses the same worker
initializer without reserving that outdoor tile. Outdoor workers must have
zero indoor wait. Job resets preserve visits; exit first acquires a free tile.
Transient tasks, paths and planting targets are rebuilt after loading.

Version 13 adds meals and reserved military deliveries; version 14 adds the
partially consumed `meal_course`. Version 15 adds `sleep_home_id`, validates
completed compatible accommodation, and permits deferred civilian cargo during
a meal. Loading at night preserves cargo without executing an immediate
delivery. Sleep is inferred from the saved clock and indoor home; return routes
are rebuilt on the next tick. Pre-v15 saves start with no sleeping assignment
and choose one through the same schedule without resetting the clock.

Version 23 removes `sleep_home_id`, wolves and the Workers' Cottage. Loading
older saves ignores those fields, drops cottage buildings without refunding
materials and moves any former resident to the nearest free outdoor cell.

Versions 1–14 remain loadable through explicit defaults and migrations. Pre-v12
workers restore outdoors instead of inferring a visit from a nearby house. Before
v6 there are no fields; pre-v7 fields become wheat and deposits are empty.
Historical buildings are complete and advanced costs/condition remain disabled
rather than inventing debts or deposits. Legacy worlds still use current
catalog recipes/professions. Earlier terrain, road, profession and mature-tree
migrations remain in place. Pre-v8 terrain becomes flat; pre-v9 sites retain
historical prices. Pre-v10 workplace conflicts keep the first valid owner in
entity-ID order and release other claims without deleting workers or cargo.
Pre-v11 trails retain their mature state and start aging from the saved tick;
old partial wear stays partial. Missing historical direction data is reconstructed
only between existing mature surfaces, then naturally ages away if unused.
Current fields and arrays are validated rather than silently accepting missing
required state.

Loading is transactional: a snapshot is fully parsed and validated in a staged
world before any live simulation references are replaced. A rejected save
therefore cannot leave the model or terrain renderer attached to partial state.
Collections, coordinate lengths, finite integral numbers, resource IDs,
inventories, processing/training/construction timers, paid flags, queue kinds,
field/deposit terrain and amounts, condition, entity references and occupancy are
validated before acceptance. Integral JSON floats are supported. New and loaded
workers share `spawn_worker()` initialization, avoiding separate runtime schemas.

Before saves become a compatibility promise, add:

- standalone historical fixtures for every released save version;
- build/version metadata and definition hashes;
- RNG state and queued player commands;
- atomic write-to-temp then rename;
- fuzzed corruption tests beyond the existing malformed-shape/value cases;
- canonical ordering for deterministic state hashes.

## Testing

The current suite inventory and dated verification results are maintained in
[tests/README.md](../tests/README.md).
`game/tests/test_runner.tscn` runs inside the actual Godot project. The root
`tests/run-headless.sh` invokes it. The runner includes the original 34 cases
and dedicated movement, snapshot, grid configuration, viewport input and
long-running invariant suites, plus the field/production, finite-deposit and
classic-economy suites. Current coverage proves:

- a work source cannot be reserved by two workers;
- lumberjack and carrier accept disjoint work and logs pass through the hut;
- a worker blocked from a source releases it and chooses another reachable one;
- pathfinding detours around blockers and may choose a longer, faster road;
- carrier passes form a trail overlay while lumberjack passes do not;
- movement duration is strictly base ground `6` > trail `4` > stone road `2`;
- the complete tree → hut → sawmill → warehouse chain stores planks;
- school training is validated, FIFO, tick-exact and safe when every exit is blocked;
- gardeners choose weighted nearest sites deterministically, reserve them exclusively and retry safely;
- sapling/young/mature boundaries are tick-exact and only mature trees are harvested;
- the catalog-driven resource HUD refreshes total stock and its warehouse/building/carried breakdown for every ware, with warehouse-only payment and transfer-conservation checks;
- version 12 round-trips indoor visits, directional trail wear/aging, exclusive workplaces, corner heights,
  tree/field/deposit state, paid training, per-site construction prices,
  processing/orders, condition, cargo and cooldowns; versions 1–10 migrate
  without repricing existing sites or duplicating workplace ownership;
- farmers exclusively claim prepared or ripe fields within eight tiles of their
  farm, and carriers move grain through the mill and bakery into stored bread;
- extractors require reachable matching finite deposits and correct professions;
  repeated/stale completion cannot duplicate yield, exhaustion stops work and
  source/home capacity remains reserved;
- all processing ratios, alternative equipment orders and all recruitment
  equipment requirements are checked against independent expectations;
- carriers supply building sites before Builder work, school payment survives
  saves, hunger/Inn/starvation works and market quotes drive physical trades;
- a Recruit occupies a supplied Watchtower, retains its post through meals and
  saves and is not consumed by unrelated Barracks orders;
- swaps preserve full movement duration in either ID order, including one-tick steps;
- blocked deliveries retain cargo and recover to a newly reachable destination;
- malformed save shapes, numbers and references are rejected without live changes;
- actual viewport dispatch preserves Space pause and Enter/button actions;
- default and expanded economies preserve reservations/inventories over 3,000 ticks
  each, including resumed JSON snapshots.

Tests that rely on project resources must continue to run through the headless
project/test scene, not isolated `--script` mode. Future suites should add
randomized long-run map seeds, save-after-every-state tests and a
golden replay hash.

## Deterministic multiplayer plan

1. Define serializable player commands (`build`, `road`, policy changes,
   military orders) containing execution tick and stable IDs/cells.
2. Route local single-player input through the same command queue.
3. Introduce a project-owned deterministic PRNG; forbid ambient `rand*` calls
   in simulation code.
4. Canonically serialize authoritative state and compute periodic hashes.
5. Record command logs and build headless replay/hash tests on multiple OSes.
6. Add lockstep networking with negotiated input delay. Advance tick N only
   when every peer has submitted its command packet (including empty packets).
7. Add desync diagnostics and snapshot-based rejoin only after lockstep is
   proven stable.

Floats are acceptable for camera and interpolation, but simulation decisions
should use integers or explicitly specified fixed-point arithmetic.

## Remaining roadmap

The earlier roadmap's farms/mines, food condition, paid training, economic
equipment graph and material/Builder construction are now implemented. Remaining
work includes:

- broader housing, household consumption and richer worker/settlement needs;
- multi-cell buildings and physical road/vine material-delivery jobs;
- detailed per-animal feeding/growth instead of aggregate recipes;
- richer warehouse policies and distribution priorities;
- unlock progression and siege production;
- combat/projectiles/formations;
- fog of war, minimap and AI observation;
- scenario scripting and native map editor;
- validated external-data importer that never writes proprietary assets into
  the repository.

## Historical scope and balance boundaries

The first wood/terrain milestone used versions 1–5. The first four-building
field expansion on 2026-09-05 used v6; it had an unlimited quarry cycle, no
food/construction/gold consumption and a one-plank sawmill yield. Those are
historical behaviors. The current v7 catalog has finite extraction, economic
services and a two-plank sawmill yield. The full dated handover preserves the
original roadmap.

Production/extraction/growth/construction durations remain this project's
balance values. As of 2026-09-05, construction material costs use the
[documented KaM table](construction-costs.md). Each site records a price
revision: revision 1 preserves the old prototype table, revision 2 uses the
source-backed catalog. Save v9 validates deliveries against that site's price;
loading v1–8 keeps historical prices and never refunds or discards materials.
Swine/horse breeding aggregates four grain
per animal, vine processing is folded into harvest, roads/vines pay instantly
from warehouses, and economic recruitment has no additional timer. Combat and
siege engines remain unimplemented. See [economy-expansion.md](economy-expansion.md)
for the implemented graph and reference provenance.
