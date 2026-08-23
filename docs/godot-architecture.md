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
- **UI** is a `CanvasLayer` created by the view. It shows stored and in-pipeline
  resources, build mode, tick, task count and recent simulation events.
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

`GridMapSim` owns bounds, building blockers, traffic wear, formed dirt trails
and player-built stone roads. It exposes walkability, deterministic cardinal
neighbours, weighted path cost and authoritative movement duration. Both A*
and the unit state machine read the same data-driven tiers: grass `6`, dirt
`4`, stone `2` ticks/cost per tile.

Only completed carrier steps add traffic wear. At four passes, ordinary grass
becomes a dirt trail; the threshold-crossing step still uses the previous
surface speed. Stone construction replaces trail/wear state and is always the
fastest tier. A building resolves an adjacent entrance before its one-cell
footprint is blocked, and placement clears any surface state underneath it.

Next terrain increment:

- typed terrain definition (ground, water, slope, deposit);
- multi-cell rotated footprints and construction states;
- connected-region cache for quick reachability rejection;
- stone-road construction tasks instead of immediate completion;
- trail decay/terrain-dependent wear thresholds if playtesting needs them;
- change revision used to invalidate cached paths.

## Entities and definitions

Entities have monotonically increasing integer IDs. Runtime dictionaries are
keyed by that ID and update loops sort their keys. Entity dictionaries are an
expedient prototype representation; the planned promotion is one typed
simulation class per domain (`BuildingState`, `WorkerState`, `TreeState`) or
typed value objects, still independent of scene nodes.

Definitions are loaded by `DefinitionCatalog`:

- `resources.json`: stable resource ID, display name and placeholder color;
- `buildings.json`: display data, footprint, accepted resources or recipe;
- `recipes.json`: input/output quantities and duration in ticks;
- `units.json`: profession, harvest/carrying parameters and display data.
- `movement.json`: surface move ticks (also used as A* cost) and dirt-trail threshold.

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
```

Production buildings consume recipe inputs, count down integer ticks and expose
outputs. The hut's log output and sawmill's plank output each create a reserved
transport offer. A carrier's actual steps reinforce its route; lumberjack
steps do not.
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

`tile_reservations` records the worker occupying each cell. A worker only moves
after reserving the next cell. Head-on neighbours use an atomic swap: both
positions and both reservation owners change together. After a bounded wait,
a blocked worker replans while treating other workers as temporary obstacles.
If an unladen worker still cannot reach its claimed source, it releases that
task and selects the nearest currently reachable source. Future congestion work
can add wait-age priority and time-expanded reservations for narrow routes while
retaining the one-cell/one-owner invariant.

Building logistics may complete from a cardinally adjacent cell when the
building entrance itself is occupied. Idle workers carrying ware always resume
delivery before claiming new work, and placement protects existing entrance
cells from being covered by another building.

## UI, camera and controls

The placeholder view draws an isometric diamond map without proprietary
assets. The camera supports WASD/arrows, middle-mouse drag and wheel zoom.
Left-click selects a tile and applies the selected road/building tool.

UI must remain a client of simulation queries/commands. It must not directly
edit inventory dictionaries in later milestones. Signals or immutable
presentation snapshots can replace the current polling when the interface
grows.

## Saving

`SaveSystem` writes a versioned JSON snapshot to `user://`. Version 2 includes
map size, tick, entity ID counter, stone roads, traffic wear/dirt trails,
buildings/inventories, trees, worker profession and lumberjack home. Transient
tasks and paths are intentionally rebuilt after load. Version 1 remains
loadable: its roads become stone roads, the first worker becomes a lumberjack,
remaining workers become carriers and missing building output keys are
normalized.

Before saves become a compatibility promise, add:

- schema migration functions for every version;
- build/version metadata and definition hashes;
- RNG state and queued player commands;
- atomic write-to-temp then rename;
- corruption and old-version tests;
- canonical ordering for deterministic state hashes.

## Testing

`game/tests/test_runner.tscn` runs inside the actual Godot project. The root
`tests/run-headless.sh` invokes it. Current coverage proves:

- a work source cannot be reserved by two workers;
- lumberjack and carrier accept disjoint work and logs pass through the hut;
- a worker blocked from a source releases it and chooses another reachable one;
- pathfinding detours around blockers and may choose a longer, faster road;
- carrier passes form dirt while lumberjack passes do not;
- movement speed is strictly grass < dirt < stone;
- the complete tree → hut → sawmill → warehouse chain stores planks;
- version 2 round-trips new state and version 1 migrates safely.

Tests that rely on project resources must continue to run through the headless
project/test scene, not isolated `--script` mode. Future suites should add
long-run invariants, randomized map seeds, save-after-every-state tests and a
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
