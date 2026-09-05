# Godot architecture

## Design goals

Medieval Economy RTS targets Godot 4.6 with typed GDScript. Authoritative game
state must be testable without graphics, advance on a fixed tick, use integer
grid coordinates and remain suitable for deterministic replays/multiplayer.
The first vertical slice is deliberately small but uses the same boundaries
intended for the full game.

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
  only the view applies those commands. Its fixed top-right resource
  HUD is generated from catalog definitions and shows stored and in-pipeline
  amounts; the left panel shows build mode, tick, task count and recent events.
- **Data** (`game/data/*.json`) defines resources, buildings, recipes, unit
  tuning and surface movement costs in one place.

There is no gameplay Autoload in milestone one. A scene owns its
`SimulationWorld`, making multiple worlds and tests possible without hidden
global state.

## Fixed simulation time

The view accumulates real seconds and calls `step_tick()` at 10 Hz, with a
bounded catch-up loop. Tests call the same method directly. Visual workers lerp
between `previous_position` and `position`; interpolation never changes the
integer logical cell.

The tick rate is a presentation/configuration concern. Recipe and movement
durations are integer ticks. Future speed controls should change how quickly
ticks are requested, never scale individual economic deltas by frame time.

## Terrain grid, trails, roads and placement

`GridMapSim` owns three independent layers. Base terrain is a dense row-major
array of stable IDs (`grass`, `dirt`, `water`, `rock`), surface infrastructure
is a sparse overlay (`trail`, `stone_road`) and building occupancy is held in
`blocked_by`. Grass and dirt are currently walkable/buildable; water and rock
are neither. A surface overlay can change movement cost but can never make an
impassable base cell walkable.

The grid exposes buildability, walkability, deterministic cardinal neighbours,
weighted path cost and authoritative movement duration. Both A* and the unit
state machine read the same data-driven values: ordinary grass/dirt `6`, trail
`4`, stone road `2` ticks/cost per tile. `surface_at()` is retained only as a
legacy compatibility wrapper; new systems read `base_terrain_at()` and
`overlay_at()` separately.

`movement.json` is the shared source of defaults for standalone grids and live
worlds. `DefinitionCatalog` caches the parsed defaults and returns independent
deep copies; partial tuning overrides preserve omitted terrain properties.

Only completed carrier steps on roadable grass or base dirt add traffic wear.
At four passes, the cell gains a dirt-trail overlay; the threshold-crossing step
still uses the previous surface speed. Stone construction replaces trail/wear
state and is always the fastest tier. A building resolves an adjacent entrance
before its one-cell footprint is blocked, and placement clears any surface
state underneath it.

`TerrainRenderer` is a read-only `Node2D` client of this model. A shared
`MapProjection` maps the flat grid to 48 × 48 screen cells and keeps future
corner-height offsets behind one API. The current renderer uses cached 1 px
color textures, deterministic coordinate variants and priority-based automatic
edge/corner transitions. Grid revisions trigger redraws; the invalidation API
can later back 16 × 16 cached chunks without changing callers.

Next terrain increments:

- painted source textures and mask atlases after scale/projection approval;
- shared corner heights, slopes, cliffs and deposits;
- multi-cell rotated footprints and construction states;
- connected-region cache for quick reachability rejection;
- stone-road construction tasks instead of immediate completion;
- trail decay/terrain-dependent wear thresholds if playtesting needs them;
- terrain revision integration with cached path invalidation.

## Entities and definitions

Entities have monotonically increasing integer IDs. Runtime dictionaries are
keyed by that ID and update loops sort their keys. Entity dictionaries are an
expedient prototype representation; the planned promotion is one typed
simulation class per domain (`BuildingState`, `WorkerState`, `TreeState`) or
typed value objects, still independent of scene nodes.

Definitions are loaded by `DefinitionCatalog`:

- `resources.json`: stable resource ID, display name, placeholder color and HUD order;
- `buildings.json`: display data, footprint, accepted resources, recipe or trainable unit IDs;
- `recipes.json`: input/output quantities and duration in ticks;
- `units.json`: profession, training/harvest/planting/carrying parameters and display data.
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

Workers have explicit professions and execute these milestone state machines:

```text
lumberjack: idle → claim tree → harvest → carry log → own lumberjack hut
carrier:    idle → claim hut log → carry log → sawmill (warehouse fallback)
carrier:    idle → claim plank → carry plank → warehouse
gardener:   idle → find nearest valid site → walk → plant sapling → cooldown
```

Gardeners need no player target command. Their weighted nearest-goal search
considers authored terrain, overlays, buildings and entrances, worker occupancy
and exclusive planting-site reservations. Planted trees advance through
sapling and young phases on simulation ticks. Only the mature phase produces a
normal `harvest_tree` task, so the existing lumberjack pipeline needs no
special planted-tree branch.

Production buildings consume recipe inputs, count down integer ticks and expose
outputs. The hut's log output and sawmill's plank output each create a reserved
transport offer. A carrier's actual steps reinforce its route; lumberjack
steps do not.

Schools are the first entity-producing building type. Their definition lists
trainable unit IDs and queue capacity, while each unit definition owns its
training duration. Explicit UI commands append to a FIFO queue. Training and
completion advance in fixed ticks; a completed unit tries the authored entrance
and then the other cardinal sides in canonical order. If every exit is blocked,
the completed queue head waits at zero ticks without consuming an entity ID.
The first slice has no training cost because inventory withdrawal does not yet
provide the atomic reservation required for deterministic spending.

Later, a logistics matcher should score compatible offers and demands by route
cost, priority, capacity and age. Reservation tokens should cover source
quantity, destination capacity and worker assignment as one transaction.

## Pathfinding and tile reservations

`GridPathfinder` is deterministic weighted A* on four neighbours. It minimizes
travel ticks across grass/dirt/stone and uses coordinate tie-breaking. Its
heuristic is derived from the minimum configured surface cost, so a longer
stone route can correctly beat a shorter grass route. A returned path excludes
the start and includes the destination. Task selection compares full weighted
route cost rather than tile count.

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

The tick scheduler tracks workers already updated in the current tick. A swap
consumes both participants' updates, and cannot involve a worker whose cooldown
was already decremented that tick. Movement duration is therefore independent
of which participant has the lower entity ID.

`planting_reservations` prevents two gardeners or a build/terrain command from
claiming the same future tree cell. It is released on completion or aborted
movement; if no site is reachable, the gardener remains idle and retries after
a data-driven fixed-tick delay.

Building logistics may complete from a cardinally adjacent cell when the
building entrance itself is occupied. Idle workers carrying ware always resume
delivery before claiming new work, and placement protects existing entrance
cells from being covered by another building.

If a delivery route becomes inaccessible, the worker retains its cargo and
selects a reachable compatible destination using current occupancy. A
lumberjack may change to another reachable hut; carriers prefer a reachable
sawmill for logs and a warehouse for planks. Without a destination they wait
for a bounded retry interval, allowing later construction to restore delivery.

## UI, camera and controls

The placeholder view draws an orthogonal 2.5D foundation without proprietary
assets. `TerrainRenderer` owns terrain presentation while `MainView` retains
entities, input and UI. The camera supports WASD/arrows, middle-mouse drag and
wheel zoom. Left-click uses the shared projection to select a tile and apply
the selected road/building tool. Successful load/reset operations rebind the
renderer because `SimulationWorld` replaces its grid object.

`GameHud` builds a fixed top-right `ResourceStatusBar`. Each catalog
resource receives a procedural icon plus a stored amount and a smaller `+N`
pipeline amount. `ResourceIcon` draws log, plank and stone placeholders without
external textures and provides a generic fallback for future resource IDs.
Stone is currently a warehouse-compatible zero/default resource; mining and
stone logistics remain future simulation work.

`MainView._input()` handles Space before GUI dispatch, consuming press, repeat
and release events. Only a distinct press toggles pause. Focused buttons remain
keyboard-accessible with Enter without also acting on the pause shortcut.

UI must remain a client of simulation queries/commands. It must not directly
edit inventory dictionaries in later milestones. Signals or immutable
presentation snapshots can replace the current polling when the interface
grows.

## Saving

`SaveSystem` handles JSON file I/O in `user://`; `WorldSnapshot` owns snapshot
encoding, typed field validation and version migration. `SimulationWorld`
retains the public `to_data()`/`from_data()` API and commits a staged world only
after successful loading. Version 5 includes
map size, tick, entity ID counter, base terrain, stone roads, traffic wear/dirt
trails, buildings/inventories, school training queues and progress, exact tree
growth ages, worker professions, gardener cooldowns and lumberjack homes.
Transient tasks, paths and active autonomous planting targets are intentionally
rebuilt after load. Versions 1–4 remain loadable: legacy saves
without base terrain load as grass and missing training state is normalized to
an idle queue; version 1 roads become stone roads, the first worker becomes a
lumberjack, remaining workers become carriers and missing building output keys
are normalized. Trees from versions 1–4 migrate as mature so existing saves do
not unexpectedly hide previously harvestable work.

Loading is transactional: a snapshot is fully parsed and validated in a staged
world before any live simulation references are replaced. A rejected save
therefore cannot leave the model or terrain renderer attached to partial state.
Collections, coordinate lengths, finite integral numbers, resource IDs,
inventories, processing/training timers, entity references and occupancy are
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

`game/tests/test_runner.tscn` runs inside the actual Godot project. The root
`tests/run-headless.sh` invokes it. The runner includes the original 34 cases
and dedicated movement, snapshot, grid configuration, viewport input and
long-running invariant suites, for 50 cases. Current coverage proves:

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
- the catalog-driven resource HUD refreshes stored and in-pipeline amounts and preserves stone stock through saves;
- version 5 round-trips growth/cooldown state and historical versions 1–4 migrate safely;
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

## Planned systems beyond milestone one

- worker needs, food and housing;
- construction materials and builder jobs;
- richer warehouse policies and distribution priorities;
- farms, mines, training and full production graph;
- combat/projectiles/formations;
- fog of war, minimap and AI observation;
- scenario scripting and native map editor;
- validated external-data importer that never writes proprietary assets into
  the repository.
