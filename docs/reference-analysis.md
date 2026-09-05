# KaM Remake reference analysis

## Scope and provenance

This analysis describes the public `reyandme/kam_remake` repository at commit
`a3b3e5268e1475460e4561f9143df6f1a532e681` (checked out on 2026-08-23). The
reference is a from-scratch Delphi/OpenGL engine under AGPL-3.0; its own
technical notes state that a lawful installation of the original game is still
required for original resources. This project does not copy or distribute
those resources.

The reference was read to identify responsibilities, invariants and data flow.
The Godot code is a new implementation and is not a line-by-line translation.

## Main parts of the Delphi project

- `src/KM_GameApp.pas`, `src/KM_Main.pas` and `src/game/KM_Game.pas` own
  application lifetime, game mode, tick scheduling and the top-level update.
- `src/terrain/` owns the tile map, terrain editing, deposits, selection,
  passability and connected walk regions.
- `src/hands/` represents a player/side. A hand aggregates units, houses,
  constructions, logistics, statistics, locks and AI.
- `src/units/`, `src/units/actions/` and `src/units/tasks/` implement unit
  state, atomic actions and longer jobs such as delivery, building and mining.
- `src/houses/` implements the common house lifecycle and specialized storage,
  production, training and market behaviour.
- `src/res/` contains data/specification loaders for houses, units, wares,
  terrain, sprites, sounds and localization.
- `src/pathfinding/` contains base pathfinding, A*, JPS and road-specific
  variants; `src/navmesh/` adds army-scale positioning and influence tools.
- `src/ai/` separates observation/influences, goals, attacks, defence, city
  planning and economic mayor logic.
- `src/game/gip/` is the command/replay boundary. `src/net/` handles lobby,
  transport, file transfer, dedicated server and lockstep scheduling.
- `src/mission/` and `src/scripting/` load maps, campaigns, mission scripts and
  script extensions. `src/render/`, `src/gui/` and `src/minimap/` are visual/UI
  concerns rather than simulation authority.

## Game loop

`TKMGame.UpdateGame` compares elapsed real time with the expected simulation
tick and may execute bounded catch-up ticks. `TKMGame.PlayGameTick` increments
the authoritative tick, takes planned commands, then updates scripting,
terrain, AI fields, hands, spectator state, pathfinding, projectiles and the
game-input process in a fixed order. Rendering is separate and receives a tick
lag for interpolation.

Multiplayer does not advance merely because a frame was rendered. In
`PlayNextTick`, a multiplayer client first checks that commands for the next
tick have arrived. `KM_GameInputProcess_Multi.pas` schedules commands in ring
buffers, imposes a small input delay and compares random checks between peers.

Implication for the Godot remake: `_process(delta)` may accumulate time, but
only `SimulationWorld.step_tick()` changes authoritative state. Simulation
tests call ticks directly and are independent of FPS.

## Map and tiles

`TKMTerrain` owns a bounded integer grid. `TKMTerrainTile` in
`KM_TerrainTypes.pas` contains base/overlay terrain layers, height, map object,
tree and field age, construction/road overlay state, owner, unit occupancy,
passability and connected-region identifiers. Render-only lighting and render
height are split into an extended record.

Passability is recalculated after terrain/building changes. Walk-connect data
quickly rejects impossible destinations before detailed pathfinding. Roads are
terrain state and influence movement/logistics; construction can reserve or
lock tiles. The first prototype reduces this to a flat `Vector2i` grid with
blocked cells and a road movement cost while keeping the same authority split.

## Units, actions and work

`TKMUnit` is the persistent entity base. Civil units, serfs, workers, animals
and warriors specialize it. A unit owns one long-lived `TKMUnitTask`, while a
task emits smaller `TKMUnitAction` steps such as walking, staying, entering a
house or fighting. Task `Execute` methods are resumable state machines and can
abandon work when their preconditions become invalid.

`TKMUnitWorkPlan` is a data-oriented bridge between worker/house type and a
production sequence. It records required resources, produced wares, work
animations and work locations. Notably, the woodcutter plan produces
`wtTrunk`, and the carpenter in `htSawmill` consumes one trunk to produce
`wtTimber`.

The Godot prototype uses the same separation at smaller scale: the `TaskBoard`
owns claimable work, while each unit has a deterministic movement/work state
machine. A lumberjack harvests a tree and returns the trunk to his own hut. A
separate carrier moves it from that output to the sawmill. The board prevents
two units from claiming the same source.

## Houses, wares and production chains

`TKMHouse` stores construction state, damage, ownership, worker association,
input/output ware slots and delivery demand. Specialized subclasses implement
stores, barracks, schools, markets and selected workshops. `KM_ResTypes.pas`
defines stable ware and house identifiers; `KM_ResWares.pas` centralizes ware
metadata and rates rather than scattering values across UI code.

Stores maintain counts and per-ware accept/take-out policy. Production houses
advertise demand for inputs and offers for outputs. The prototype mirrors this
with JSON definitions for buildings, resources, recipes and units. Its first
chain is tree → lumberjack hut output → carrier → sawmill → carrier → warehouse.

## Logistics and reservations

`TKMHandLogistics` and `TKMDeliveries` maintain offer, demand and queue nodes.
Delivery bids evaluate routes between a source and a destination; selected
work is removed or reserved so another serf does not take the same delivery.
Routes are cached but can expire when state changes.

The first Godot milestone has two explicit reservation layers:

1. `TaskBoard` creates at most one task per source key and permits exactly one
   `reserved_by` worker.
2. `SimulationWorld.tile_reservations` permits one worker per occupied target
   tile. A deterministic atomic swap resolves two workers meeting head-on.

This is intentionally simpler than the reference bid system, but it preserves
the critical exclusivity invariant.

## Pathfinding

`TKM_PathFinding.pas` supplies common search state and maintenance.
`KM_PathFindingAStarNew.pas`, the old A* implementation, JPS and road-specific
search are interchangeable strategies. Terrain passability, diagonal vertex
usage, unit occupancy and congestion all affect a valid route. Army movement
uses separate navmesh/influence systems.

The prototype uses deterministic weighted four-neighbour A*. Grass, emergent
dirt trails and player-built stone roads cost `6/4/2`; the same values control
actual step duration. Ties are resolved by grid coordinates, so dictionary
iteration order cannot choose a different path. Buildings are blocked; their
adjacent entrance is the logistics target.

KaM Remake itself does not spontaneously create dirt trails and does not use
road surface as a physical speed multiplier; its roads primarily constrain and
guide civilian logistics. Traffic wear and the three speed tiers are therefore
an intentional new design requested for this project, not behavior attributed
to the reference.

## Combat and AI

Warriors and unit groups are separate from civil production. Fight actions
validate opponents, reserve diagonal vertices, handle ranged aiming/projectiles
and resolve melee hits from unit specifications plus the synchronized random
source. `TKMProjectiles` updates arrows, bolts and rocks inside the game tick.

`TKMHandAI` coordinates goals, mayor/economy, attacks, general/army state and
influence fields. The AI is decomposed into observation/evaluation and action
systems instead of being embedded in unit rendering. Combat and AI are outside
the first playable milestone; future implementations should preserve that
separation and issue the same command objects available to human players.

## Saving and loading

`TKMGame.Save` serializes a versioned state stream with markers. The body
includes the random seed, game parameters/options, UID tracking, script state,
terrain, hands, AI fields, spectator state, projectiles and pathfinding state.
Associated replay/input and save-point files are written separately and may be
compressed. Loading reconstructs object graphs and performs a synchronization
pass for references after entities exist.

The prototype uses a versioned JSON snapshot. Version 5 saves integer
simulation state, base terrain, surface overlays/wear, entities, inventories,
training queues, professions, gardener cooldowns, exact tree-growth ages and
home-hut associations. Transient paths/tasks are rebuilt after load, and
versions 1–4 have explicit compatibility paths. Future formats still need a
migration registry and deterministic RNG state.

## Multiplayer and determinism

KaM Remake uses command lockstep rather than streaming every entity transform.
The host distributes one random seed; commands are scheduled for future ticks;
all peers wait for required command packs. Per-tick random/state checks detect
desynchronization, while saves and map/script CRCs ensure compatible inputs.
The dedicated server is a packet hub and does not run the gameplay simulation.

Requirements carried into the Godot design are fixed ticks, integer logical
coordinates, stable IDs, sorted update order, deterministic path tie-breaking,
seeded RNG, command serialization, periodic state hashes and replay tests.

## Map and data formats

- A mission commonly combines a binary `.map` terrain file and `.dat` mission
  definition, plus `.script` and localized `.libx` text where present.
- Map metadata/cache code computes CRCs over terrain and supporting mission
  files; multiplayer strict parsing checks the full set.
- Campaigns use an `info.cmp` specification plus maps, scripts, text libraries
  and optional packed images/data.
- Saves use a main save stream plus replay/game-input and optional checkpoint,
  local multiplayer and RNG diagnostic files.
- Original graphics/resources use additional legacy containers. They are not a
  target for milestone one and must never be committed to this repository.

Any future importer belongs under `tools/`, reads only a user-selected external
directory and emits provenance-safe data. The native project format should
remain documented JSON/resources rather than reproducing legacy binary layouts.
