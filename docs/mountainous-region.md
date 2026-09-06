# Mountainous Region terrain study

Implemented 2026-09-06. An optional landscape imported from the original
Mountainous Region map, using this project's own terrain and tree artwork.
The default Warehouse + School starter scene is unchanged.

## Open the map

On macOS, double-click `Mountainous Region.command` at the project root.
Or open `game/scenes/mountainous_region.tscn` in Godot and run that scene (F6).
Alternatively, from the repository root:

```sh
godot --path game res://scenes/mountainous_region.tscn
```

The local imported data must exist at
`game/external_assets/maps/mountainous-region.json`. Missing or malformed data
produces a visible error and opens the normal test level; it never substitutes
a generated landscape under the Mountainous Region name.

The scene starts at 09:00 with the entire map in view. Use the mouse wheel to
zoom, arrows or middle-button dragging to pan, Space to pause, and F2 to inspect
terrain rules. R reloads the selected landscape and discards unsaved changes.
F5/F9 save/load this landscape in a separate slot from the normal starter map.

This is **terrain only**: no starting buildings, citizens, armies, resource
deposits, roads or mission logic. With no Warehouse/School or starting supplies,
it is a landscape to inspect, not yet a playable economic scenario. Construction
previews and the existing ground-preparation rules still inspect the real
heightfield. Starting positions and a balanced economy are a separate next step.

## Provenance and reproducibility

The map is listed as a 144 × 128, four-player original TSK map in
[Knights Tavern](https://www.knights-tavern.com/map/mountainous-region).
The actual terrain-only binary used here is from the
[KaM Remake map repository](https://github.com/reyandme/kam_remake_maps/blob/aed738dcaba06070a16ecfb73ca8977ad285b674/MapsMP/Mountainous%20Region/Mountainous%20Region.map):

- Repository commit: `aed738dcaba06070a16ecfb73ca8977ad285b674`.
- Path: `MapsMP/Mountainous Region/Mountainous Region.map`.
- Map revision: r11222; file size: 184,366 bytes.
- SHA-256: `cf70c8b222632e7281a10935125b325a0367b36a68f29aae3c4792777b397bb4`.
- Definitions/format reference: KaM Remake commit
  `a3b3e5268e1475460e4561f9143df6f1a532e681`, especially `KM_Utils`,
  `KM_TerrainUtils`, `KM_Terrain`, `KM_ResTilesetTypes` and `tiles.json`.

The 144 × 128 source records include the final boundary vertices: this is
**143 × 127 playable cells**, with all 18,432 original corner heights retained.
The importer does not invent a final strip of terrain. It reads 165,888 bytes
of tile data and ignores 18,448 bytes of trailing editor metadata. This source
has no layered tiles, custom tiles or road overlays. No mission script or
campaign logic is loaded or executed.

See [the converter instructions](../tools/README.md) to repeat the local import.
The source binary, converted JSON and local preview images stay in ignored
external-data directories; they are **not distributed with the public source**.
An engine's open-source license is not treated as permission to redistribute
original game assets. Obtain any source data with appropriate rights.

## What is preserved and what is adapted

| Element | This prototype |
| --- | --- |
| Map layout and orientation | Original positions, no rotation, resampling or smoothing |
| Heights | `round((source_height - minimum) × 0.15)`, 0–100 becomes 0–15 |
| Height projection | 8 pixels per game height, approximating source 1.2 pixels per height |
| Cells | Existing 40 × 40 ground projection |
| Surface appearance | Our grass/dirt/water/rock materials, not original texture tiles |
| Living trees | 341 at source positions, represented by our tree variants |
| Border object | One living tree on the unused final boundary omitted |
| Other objects | 211 small decorations omitted; no decorative collision masks imported |
| Resources | Source resource terrain appears as dirt/rock; no harvestable deposits inferred |

Material counts are grass 6,591, dirt 6,843, water 146 and rock 4,581.
All 13,434 source-material-walkable cells remain land, including 51 mixed
shore cells. The original's detailed mixed textures, tree species, decorative
objects, lighting and water presentation are not reproduced pixel-for-pixel.
The current faceted shading is visibly stronger than KaM's softer landscape.

Movement still follows **our** slope and collision rules. Against the source
material + height walkability check, rounding causes 70 formerly walkable cells
to exceed our slope limit and two steep cells to become walkable. The resulting
13,296 walkable cells contain a main connected region of 13,295 and one isolated
cell at (12, 93), using zero-based prototype coordinates. Omitted decorations
include six fully blocking and 38 diagonal-blocking source objects. Therefore
this is a faithful layout/height import with adapted gameplay, **not identical
KaM collision or mission compatibility**.

## Verification

- Public synthetic tests require no proprietary files: seven loader/simulation
  cases plus nine actual-scene camera, failure, reset, save-slot and tree-culling
  cases. Large maps avoid rendering distant trees; a conservative margin retains
  offscreen canopies and shadow casters, without changing simulation or terrain.
- Eighteen Node importer tests cover bounded decoding, malformed files, terrain
  classification, layers, shore preservation, tree stages and safe output.
  With the optional local source supplied, an independent fixed-record scanner
  checks every real height, material and tree rather than calling the converter
  to manufacture its own expected result.
- Actual Godot loading confirms 143 × 127 cells and 341 trees, no settlement.
  A normal JSON save v17 roundtrip preserves the complete world exactly; the
  loaded world continues through 20 ticks without adding actors or roads.
- Four real pathfinding routes, including opposite map corners and both sides
  of the central area, have every step checked before and after loading.
- Native Godot screenshots inspect full-map fit and closer terrain views;
  headless checks are not used as evidence for visible graphics.

Local screenshots are kept under `game/external_assets/previews/` with the
imported data, not embedded into the public repository.
