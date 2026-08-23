# Medieval Economy RTS

An open-source, fan-made economy RTS prototype built from scratch with Godot
4.6 and typed GDScript. It is inspired by the economic simulation style of
classic medieval strategy games and uses the public KaM Remake source as a
technical reference for responsibilities and invariants.

This is not an official Knights and Merchants product. No original game code,
graphics, audio, maps or campaigns are included.

## Playable milestone

The current vertical slice starts with a live isometric economy:

- fixed-step simulation on an integer grid;
- camera pan/drag/zoom and tile selection;
- buildable stone roads, warehouses, lumberjack huts and sawmills;
- distinct lumberjack/carrier professions, deterministic weighted A*, exclusive reservations and blocked-path replanning;
- tree → lumberjack hut → carrier → sawmill → carrier → warehouse production chain;
- carrier traffic that gradually tramples grass into a faster dirt trail;
- three movement tiers: grass (slow), dirt trail (faster), stone road (fastest);
- stored and in-pipeline log/plank UI;
- versioned JSON save/load;
- placeholder vector graphics drawn by Godot, with no external assets.

The demo already contains one of each required building so production begins
immediately. The build tools let you place more.

## Requirements and run

- Godot 4.6 (verified with 4.6.3 stable)

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
| 1 / 2 / 3 / 4 | Stone road / warehouse / lumberjack hut / sawmill |
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

The suite covers exclusive task claims, weighted pathfinding, profession
boundaries, the end-to-end production chain, trail formation, all movement
tiers, blocked-worker recovery and version 1/2 save compatibility.

## Repository layout

```text
game/                   Godot project and placeholder visuals
  data/                 Data-driven resources, buildings, recipes and units
  scripts/simulation/   FPS-independent authoritative model
  scripts/view/         Camera, input, UI and rendering
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
