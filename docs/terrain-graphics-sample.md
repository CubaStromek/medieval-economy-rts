# KaM terrain graphics sample

Created 2026-09-06 as a **small visual reference**, not a replacement for the
production renderer or a claim that all KaM rendering has been implemented.

## View

Update 2026-09-06: the launcher now opens the extended
[graphics sandbox](terrain-graphics-sandbox.md). The original static comparison
below remains available through its scene path.

On macOS, double-click `Terrain Graphics Sample.command` in the project root.
Or open `game/scenes/terrain_graphics_sample.tscn` in Godot and run that scene.

```sh
godot --path game res://scenes/terrain_graphics_sample.tscn
```

Choose **Louka a skála** / **Břeh jezírka**, or use keys 1 / 2. Each screen
compares the same 22 × 18 source cells: the current four-material renderer on
the left and a source-informed reference renderer on the right. It creates no
citizens/buildings, loads no saves and does not modify the ordinary game.

Required **local external data**, intentionally ignored by Git:

- `game/external_assets/terrain-sample/tiles1.tga` — the unchanged 512 × 512 atlas
  from the reference repository's `Utils/_KaM Editor/Resource/Tiles1.tga`.
- `game/external_assets/terrain-sample/patches.json` — two small crops of the
  original Mountainous Region, with tile IDs, rotations and raw corner heights.
- Previews in the same external-data directory.

Missing external data produces an explanatory message. The ordinary game does
not need these assets. Original asset rights are not inferred from the engine
license; the atlas, map crops and their rendered previews stay outside Git.

## What the reference sample implements

- Source texture IDs and all four rotations, preserving authored grass/soil,
  rock/ore and shoreline transition artwork rather than reducing it to four
  generic materials.
- 32 × 32 source texture pixels over 40 × 40 ground cells, nearest filtering.
  Tile textures are isolated in memory to avoid bleeding between atlas cells.
- Raw-height projection: `screen_y = 40*y - raw_height*40/33.333`.
  Terrain geometry is not smoothed or procedurally redesigned.
- Shared corner vertices and the TL–BR triangle split.
- KaM Remake's signed per-vertex height lighting, interpolated across the
  triangles before the highlight/shadow gradient is evaluated. A source-data
  halo supplies the neighboring heights, so cropped edges are not treated as
  real black map borders.
- Retained native Godot meshes and a small CanvasItem shader, not an AI-painted
  concept image or a screenshot from the original game.

The present production view on the left keeps its existing rounded height
levels, procedural textures, flat triangle lighting and contour accents.
Neither view includes tree sprites, cast object shadows, buildings or fog of war.
Water is **static**: this old editor atlas does not provide the full animation
frames and layered water effects used by the current Remake. This is not a
pixel-exact reproduction of its complete modern rendering pipeline.

## Source references

Engine snapshot: [KaM Remake](https://github.com/reyandme/kam_remake/tree/a3b3e5268e1475460e4561f9143df6f1a532e681),
especially `src/render/KM_RenderTerrain.pas`, `src/terrain/KM_Terrain.pas`,
`src/res/KM_ResSprites.pas` and `src/common/KM_Defaults.pas`.

Atlas SHA-256:
`95a36f60966bba4e2a6f1dc602d8eeb461841b7041dc9d3f0532a050637a40a3`.

Map: [Mountainous Region](https://github.com/reyandme/kam_remake_maps/blob/aed738dcaba06070a16ecfb73ca8977ad285b674/MapsMP/Mountainous%20Region/Mountainous%20Region.map),
SHA-256 `cf70c8b222632e7281a10935125b325a0367b36a68f29aae3c4792777b397bb4`.
Crop origins are (13,59) and (65,49) in zero-based map coordinates.

For complete integration, the game would additionally need a source-detail
terrain representation compatible with editing, prepared foundations and saves;
the full texture/transition catalog; terrain-layer and overlay rendering; water
animation; object integration and occlusion; and performance/regression checks
on large maps. This experiment changes none of those simulation systems.

## Verification (2026-09-06)

- Standalone synthetic suite: 8 cases, 0 failures, without original assets.
- Native OpenGL rendering: both actual scene crops captured at 1900 × 1000;
  visually checked for tile orientation, continuous transitions and smooth light.
- Native shader probe: 27 pixels across flat, positive-light and negative-light
  planes; maximum channel difference from the CPU reference was 0.53/255.
- Scene controls: both buttons, direct number keys, Space toggle, malformed-patch
  recovery and retained geometry checked successfully.
- No production scene, simulation, save format or default startup was changed.

Run the isolated regression suite with:

```sh
godot --headless --path game res://tests/kam_terrain_sample_runner.tscn
```
