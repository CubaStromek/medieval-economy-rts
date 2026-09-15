# Changelog

All notable changes to Medieval Economy RTS are recorded here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/) for its `0.y.z`
prototype releases; see [versioning and releases](docs/release-process.md).

Versions 0.1.0–0.5.0 were assigned on 2026-09-15 to the existing milestone
commits. Design notes, measurements and test counts live in the linked
documents, the dated sections of [README.md](README.md) and
[tests/README.md](tests/README.md), and each release verification record.

## [Unreleased]

Nothing yet.

## [0.6.0] — 2026-09-15

Work from 12–14 September 2026. Save format **v23** (was v21); older saves load.

### Added

- Painted sawmill (v2 active, v1 kept as history) with visible log and plank
  stocks, the workpiece in progress and a carpenter who works at the saw and
  rests at home with a breathing idle motion, contact shadow and sheltered
  lighting. The layers follow the building's real inventory, production and the
  worker's physical presence
  ([sawmill v2](docs/art/briefs/sawmill-v2-integration.md),
  [stocks and work](docs/art/briefs/sawmill-operation-v1-integration.md)).
- Painted warehouse (v2 active with corrected perspective, v1 kept) whose doors
  open and close ([warehouse v2](docs/art/briefs/warehouse-v2-integration.md)).
- Lumber hut presence layer: open door, resting lumberjack with head turns and
  an open window only while the worker is actually at home
  ([lumber hut life](docs/art/briefs/lumber-hut-life-v1-integration.md)), with a
  shared [production building life pattern](docs/art/production-building-life-pattern.md).
- Czech HUD names and a scaling policy that gives larger windows more visible
  map instead of larger buttons ([HUD layout](docs/hud-layout.md)).
- This changelog, release tags and a documented
  [release process](docs/release-process.md).

### Changed

- Game time keeps pace with real time like KaM Remake: ticks owed after a slow
  frame are replayed instead of slowing the game, with a 100-tick backlog cap
  and at most 100 ms of catch-up per frame; loading time is not replayed
  ([fixed simulation time](docs/godot-architecture.md#fixed-simulation-time)).
- Route searching uses a packed pathfinding index with identical routes and
  tie-breaking; simulation ticks on a typical settlement are about 5× cheaper
  ([pathfinding performance](docs/pathfinding-performance.md)).
- Placeholder buildings cache their geometry and keep their drawing until their
  inputs change, roughly halving map frame time in the economy demo with
  pixel-identical output
  ([render performance](docs/render-performance.md#retained-building-layers--2026-09-14)).
- Satiety declines at a constant 390 milli-points per tick, the former daily
  awake/asleep average; the seven-day reserve is shown in minutes at 1×.
- Bulky QA frame sequences stay out of Git; frames referenced by documentation,
  MP4 captures and reports are still published.

### Removed

- The day/night cycle: calendar clock and sky display, map tinting, night rest
  and sleeping places, moving sun shadows, and night window light and smoke.
  Small fixed ground shadows under trees and units remain
  ([removal notes](README.md#daynight-cycle-removed--2026-09-14)).
- The Workers' Cottage. Loading an older save drops existing cottages without
  refunding materials and moves their residents to the nearest free cell.
- Night wolves, which only existed in unreleased work after 0.5.0.

## [0.5.0] — 2026-09-12

Save format **v21**.

### Added

- Painted V1 terrain atlas in the normal game, shared with the graphics
  sandbox ([painted terrain](docs/painted-terrain-game.md)).
- Fog of war with unexplored, explored and visible ground
  ([fog of war](docs/fog-of-war.md)).
- Seven-day nutrition reserve that separates satiety from long-term deficit.
- First-person unit thoughts and independent work pause for units and
  buildings ([thoughts and pause](docs/unit-thoughts-and-pause.md)).
- Painted lumber hut with 12 timber and 21 finishing construction steps,
  0–6 visible stored logs and a nine-cell footprint v2 for newly built huts.
- PixelLab lumberjack in the normal game: axe walk, chopping and log carrying
  in eight directions (439 frames).
- Workers' Cottage housing ([worker housing](docs/worker-housing.md)).
- Mountainous Region starter map with its own save slot
  ([Mountainous Region](docs/mountainous-region.md)).

### Changed

- HUD stock aggregation and transport availability checks run in single passes
  without changing destination ranking
  ([refactor audit](docs/refactor-audit-2026-09-11.md)).

## [0.4.0] — 2026-09-07

Save format **v17**.

### Added

- Isolated terrain graphics sandbox and source-map import tooling
  ([sandbox](docs/terrain-graphics-sandbox.md)).
- Mountainous Region terrain study from optional external map data.
- Main menu with saved sessions.
- Multi-cell building footprints and builder foundation preparation
  ([footprints](docs/building-footprints.md),
  [foundations](docs/foundation-preparation.md)).
- Sunlight with moving shadows and a sky display.
- Recovery for idle workers blocking narrow lanes and doorways.

## [0.3.0] — 2026-09-05

Save format **v15**.

### Added

- Expanded classic economy: food, wine, fish, livestock, leather, mining and
  smelting, weapons and armour, marketplace trade, recruitment and equipment
  ([economy](docs/economy-expansion.md)).
- Civilian inns and army food deliveries
  ([food and military supply](docs/food-and-military-supply.md)).
- In-game calendar with a civilian daily schedule.
- Finite resource deposits, one specialist per workplace and workers who enter
  buildings.
- Eight-way movement with yielding, and natural trails that reward sustained
  traffic ([natural trails](docs/natural-trails.md)).
- Terrain relief, square cells with readable slopes, retained terrain rendering,
  basic roads, trees and unit sprites ([terrain relief](docs/terrain-relief.md)).
- Minimal test level and an adaptive game window.

## [0.2.0] — 2026-09-05

Save format **v5**.

### Added

- Independent base terrain, surface overlay and occupancy layers with authored
  grass, dirt, water and rock and data-driven walkability and buildability.
- Schools with FIFO training for carriers, lumberjacks and gardeners.
- Gardeners who plant saplings, and visible tree growth phases.
- Resource HUD with procedural icons showing stored and in-pipeline stock.
- Separate read-only terrain renderer with orthogonal projection and automatic
  material transitions.
- Validated, migrating world snapshots for saves.

## [0.1.0] — 2026-08-23

Save format **v2**.

### Added

- Godot vertical slice with a fixed-step 10 Hz simulation on an integer grid.
- Stone roads, warehouse, lumberjack hut and sawmill with the tree → hut →
  carrier → sawmill → warehouse production chain.
- Lumberjack and carrier professions with weighted A*, exclusive reservations
  and blocked-path replanning.
- Carrier traffic that tramples grass into faster dirt trails, and three
  movement tiers.
- Versioned JSON save and load, and procedural placeholder graphics.
- Project handover document.

[Unreleased]: https://github.com/CubaStromek/medieval-economy-rts/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/CubaStromek/medieval-economy-rts/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/CubaStromek/medieval-economy-rts/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/CubaStromek/medieval-economy-rts/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/CubaStromek/medieval-economy-rts/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/CubaStromek/medieval-economy-rts/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/CubaStromek/medieval-economy-rts/tree/v0.1.0
