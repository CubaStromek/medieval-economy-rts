# Medieval Economy RTS

An open-source, fan-made economy RTS prototype built from scratch with Godot
4.6 and typed GDScript. It is inspired by the economic simulation style of
classic medieval strategy games and uses the public KaM Remake source as a
technical reference for responsibilities and invariants.

This is not an official Knights and Merchants product. No original game code,
graphics, audio, maps or campaigns are included.

## Playable milestone

The current vertical slice starts with a live orthogonal 2.5D economy foundation:

- fixed-step simulation on an integer grid with independent base-terrain,
  surface-overlay and occupancy layers;
- authored grass, dirt, water and rock with data-driven walkability and
  buildability;
- camera pan/drag/zoom and tile selection;
- buildable stone roads, warehouses, lumberjack huts, sawmills and schools;
- distinct lumberjack/carrier/gardener professions, deterministic weighted pathfinding, exclusive reservations and blocked-path replanning;
- FIFO school training for carriers, lumberjacks and gardeners, including deterministic blocked-exit handling;
- autonomous gardeners that find the nearest reachable free site, plant a sapling and wait before planting again;
- visible sapling, young-tree and mature-tree phases; lumberjacks only claim mature trees;
- tree → lumberjack hut → carrier → sawmill → carrier → warehouse production chain;
- carrier traffic that gradually tramples grass into a faster dirt trail;
- three movement tiers: grass (slow), dirt trail (faster), stone road (fastest);
- a fixed top-right resource HUD with procedural log, plank and stone icons,
  showing stored stock and in-pipeline flow from live simulation state;
- versioned JSON save/load;
- a separate read-only terrain renderer with 48 × 48 orthogonal projection,
  deterministic color variants and automatic material transitions;
- procedural placeholder textures and vector entities, with no external assets.

The demo already contains each building required by the resource chain so
production and replanting begin immediately. Build and select a school to queue
additional carriers, lumberjacks or gardeners.

## Requirements and run

- Target project format: Godot 4.6. The gardener and tree-growth work is covered
  by the headless suite on Godot 4.6.1.

From the repository root:

```sh
godot --path game
```

Or import `game/project.godot` in the Godot editor and run the project.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select/build on a tile |
| Middle mouse drag | Pan camera |
| Mouse wheel | Zoom |
| WASD / arrows | Pan camera |
| 1 / 2 / 3 / 4 / 5 | Stone road / warehouse / lumberjack hut / sawmill / school |
| School UI buttons | Queue a carrier, lumberjack or gardener at the selected school |
| Escape | Leave build mode |
| F5 / F9 | Save / load |
| R | Reset the demo |
| Space | Pause/resume simulation |

The prototype starts at a relaxed `0.5×` speed. The UI also offers pause,
`1×` and `2×` controls. The authoritative simulation still uses a fixed 10 Hz
step; speed only controls how quickly those steps are requested in real time.

## Tests

Tests run through a real headless Godot project scene, so project resources and
engine initialization match the game:

```sh
./tests/run-headless.sh
```

Equivalent command:

```sh
godot --headless --path game --scene res://tests/test_runner.tscn
```

The suite covers terrain layers and projection, exclusive task claims, weighted
pathfinding, profession boundaries, unit-training timing and queues, autonomous
gardener target selection/reservations/retry timing, tree-growth boundaries and
lumberjack maturity gating, the catalog-driven resource HUD, the end-to-end
production chain, trail formation, all movement tiers, blocked-worker recovery,
version 5 round-trips and migrations from versions 1–4.

The suite now runs 50 cases, including full-tick swap timing, delivery recovery
after construction, malformed-save rejection, actual viewport keyboard/button
dispatch and two 3,000-tick economy invariant scenarios. Snapshot handling lives
in `WorldSnapshot`; the view delegates UI construction and text to `GameHud`.

## Repository layout

```text
game/                   Godot project and placeholder visuals
  data/                 Data-driven resources, buildings, recipes and units
  scripts/simulation/   FPS-independent authoritative model
  scripts/view/         Shared projection, terrain renderer, camera, input and UI
  tests/                Godot test scene
docs/                   Reference analysis and architecture
reference/kam_remake/   Ignored, unmodified local reference clone
tests/                   Headless test launcher
tools/                   Future provenance-safe importers/analyzers
```

Architecture and reference notes:

- [`docs/reference-analysis.md`](docs/reference-analysis.md)
- [`docs/godot-architecture.md`](docs/godot-architecture.md)
- [`docs/reference-map.md`](docs/reference-map.md)

## Original game data

Do not add proprietary game data to this repository. If a future compatibility
tool needs data from a lawfully purchased installation, it must read a
user-selected external directory and keep derived/imported assets outside Git.
The ignore rules reserve common local directories for that purpose.

## Reference and license

KaM Remake (`reyandme/kam_remake`) is a separately written Delphi/OpenGL engine
licensed under AGPL-3.0. The analyzed local snapshot is commit
`a3b3e5268e1475460e4561f9143df6f1a532e681` from 2026-08-23. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Medieval Economy RTS is licensed under the GNU Affero General Public License,
version 3. See [`LICENSE`](LICENSE).
