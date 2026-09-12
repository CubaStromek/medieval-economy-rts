# Terrain graphics sandbox

Created 2026-09-06. This extends the small terrain study into an isolated native
Godot workbench. It is not a second game world and never loads or writes game
saves. Production startup, terrain rendering and simulation are unchanged.

## Open on Mac

Choose **Grafický sandbox** in the main menu. The **Hlavní menu** button or
**Esc** returns to it. If a game was already running, it remains paused and
**Pokračovat ve hře** restores the same session. Opening and closing the sandbox
does not write game saves or sandbox presets.

You can also double-click `Graphics Sandbox.command`. The earlier `Terrain Graphics Sample.command`
also opens the sandbox. Godot is the only runtime required; the original Windows
game does not need to run on this Mac.

```sh
godot --path game res://scenes/terrain_graphics_sandbox.tscn
```

The earlier static comparison scene remains available as
`res://scenes/terrain_graphics_sample.tscn`.

## Controls

- Choose the same two 22 × 18 Mountainous Region crops: meadow/rock or lake shore.
- View only the working pane, compare with a fixed source-informed terrain
  reference, or compare with the historical four-material procedural prototype.
- Switch **SADA TEXTUR** between **Původní KaM** and **Naše malované · v1**.
  The latter is our own higher-resolution painterly atlas, not original pixels.
  See [artwork, provenance and prompt](modern-terrain-textures.md).
- Toggle textures, slope lighting, linear filtering and grid lines.
- Adjust visual relief and lighting strength independently. Relief also scales
  the slope-light stencil; it never changes source heights or walkability.
- Optional prototype trees, experimental contact shadows, object-position
  markers and tree scale. All experimental layers start OFF.
- Wheel zoom; left/middle drag pans both panes together; F recenters; 1/2 choose
  a crop. Hover inspects tile ID, rotation, raw corner height and source cell.
- Save settings explicitly to restore that preset on next launch. Reset affects
  the current session; it does not overwrite a saved preset until Save is used.
- Capture writes a PNG plus a JSON settings sidecar, including camera offset.

Local output, ignored by Git:

- `game/external_assets/terrain-sandbox/last-settings.json`
- `game/external_assets/terrain-sandbox/captures/`
- `game/external_assets/terrain-sandbox/previews/`

Numeric state is bounded and versioned (`kam-graphics-sandbox-v1`). Unknown keys,
wrong types and nonfinite values are ignored. Screenshots and presets do not
contain game saves or credentials. This is a development scene; exported game
packages would need a different writable destination and asset packaging.

## What is original, and what is not

The terrain uses the unmodified local `Tiles1.tga`, raw source heights, tile
rotations and signed interpolated source lighting described in
[the terrain study](terrain-graphics-sample.md). The fixed reference pane is
OUR rendering of that terrain, **not a screenshot of the running original game**.
Classic renderer output is pixel-identical to the preceding terrain study.
New/reset sandbox sessions select our modern painted pack with the fixed
reference beside it. Existing presets without a texture-pack field keep classic
mode; explicitly saving a preset also saves the selected pack.

The object fixture preserves source object IDs and cell positions. It contains:

| Crop origin | Source objects | Living trees |
| --- | ---: | ---: |
| (13,59) | 18 | 13 |
| (65,49) | 31 | 12 |

Tree classification follows `KM_ResMapElements.CHOPABLE_TREES`, independently
checked against `mapelem.dat.CuttableTree`. All selected living trees are mature.
Object 172 is intentionally not relabeled as a living tree.

The displayed tree sprites are **our existing prototype artwork**, not original
KaM sprites. The provisional root is the projected tile center; actual KaM uses
its original sprite sizes and pivots. Tree sorting uses projected roots, while
the whole optional overlay draws above terrain; full terrain/object occlusion
is not implemented. Ellipse contact shadows are also experimental, not the
original shadow rendering. These limitations are visible in the interface.

Water is deliberately STATIC. The local reference has animation definitions but
not the required bitmap frames. The audit also checked the old Tileset.rxx in
`Utils/MapUtil/MapUtil.7z`; the current crops' required ranges 5078–5101 and
5222–5240 are absent. It does not provide a verified replacement for them.
No original Trees.rx/rxx/rxa sprite pack exists in the available project data.

## External data and next fidelity step

Required local study files remain in `game/external_assets/terrain-sample/`:
`tiles1.tga`, `patches.json`, and optional `objects.json`.
Missing terrain data produces a message; absent object data yields zero optional
objects. Proprietary graphics, map crops and rendered previews remain ignored
by Git. Engine source licensing does not imply rights to redistribute artwork.

The next useful fidelity step is obtaining the appropriate graphic data from a
lawfully available original game / matching Remake installation, then decoding
its sprite frames, pivots and shadows and matching water animation definitions.
Only data files are needed for that import; a Windows game runtime is not a
requirement of this native Mac sandbox. No installer, compatibility layer or
game package has been downloaded or installed by this change.

## Production V1 rollout

As of 2026-09-07, the regular game uses the same authored V1 materials; see
[production integration](painted-terrain-game.md). Sandbox experiments remain
isolated. Its procedural comparison is now explicitly labeled as the original
prototype; original KaM / our V1 pack selection remains unchanged.

## Verification

```sh
godot --headless --path game res://tests/terrain_sandbox_runner.tscn
```

- Synthetic cases cover prior reference tests, visual controls, object layer,
  versioned state/pack migration and modern material semantics/transitions.
  No original game graphics are needed by these tests.
- Native old-vs-new default shader comparison: 0 differing pixels. Textures,
  lighting, strength, relief, filtering and reset checked against rendered pixels.
- Mesh/material identity retained while changing visual settings.
- Actual scene checks: both source crops, all comparison modes, control changes,
  source immutability, synchronized camera, projected picking, settings save.
- Native GUI dispatch: checkbox clicks and wheel zoom, 1900 × 1080 and 1100 × 720
  layouts, prototype trees/shadows/markers/grid, PNG capture + JSON sidecar.

## Primary references

- [KaM Remake source snapshot](https://github.com/reyandme/kam_remake/tree/a3b3e5268e1475460e4561f9143df6f1a532e681):
  `src/render/KM_RenderTerrain.pas`, `src/render/KM_RenderPool.pas`,
  `src/res/KM_ResMapElements.pas` and `src/terrain/KM_Terrain.pas`.
- [Original Mountainous Region data](https://github.com/reyandme/kam_remake_maps/blob/aed738dcaba06070a16ecfb73ca8977ad285b674/MapsMP/Mountainous%20Region/Mountainous%20Region.map).
- [KaM Remake FAQ](https://www.kamremake.com/faq/) describes a separate Wineskin
  route for running Remake on Mac. That is optional and not used by this sandbox.
