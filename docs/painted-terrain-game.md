# Full V1 terrain rendering in the game — 2026-09-07

V1 is enabled by the common game scene for all four New Game maps and saved
worlds. This supersedes the earlier **material-only** integration: gameplay now
uses the sandbox's actual eight-material compositor and smooth lighting.

## Rendering

- `ModernTerrainShader.FUNCTIONS` is shared by the sandbox and game. It contains
  the exact mirrored four-cell atlas addressing, world-space blend noise,
  normalized weight sharpening and nonlinear light lookup.
- Signed vertex light is interpolated **before** the nonlinear lookup.
  The game no longer overlays its old flat triangle shading, random cell tints,
  transition strips or slope contour stripes on V1 ground.
- Optional Mountainous Region metadata preserves source corner materials and
  raw lighting heights. The two approved crops match at all 714 interior
  vertices: eight material weights and signed light, with zero mismatches.
- Built-in maps use their own terrain types with continuous half-cell weights.
  Pure cell centers keep isolated water and rock readable. Their dirt remains
  packed soil; source-map Dirt/GrassDirt use the approved vegetated mixtures.
- Source coal and ore use the appropriate V1 atlas slots. Source Moss maps to
  the vegetated mixture and the two source cobblestone corners to limestone.
- Ground UVs carry a reserved 1024 offset. The row shader recognizes that tag;
  roads, trails, transparent guidance and other normal UVs pass through with
  their original texture and tint. The same terrain/object row order remains.
- The approved PNG is unchanged (SHA-256
  `869cccdce464913fcbbdf63ba1946edc530ed1d3bea3e5676bfe1e8eb30c825c`).
  No image generation, original bitmap copying or asset recoloring occurred.

## Simulation and caching

Terrain polygons, integer gameplay heights, picking, passability, earthwork,
building placement, movement costs and save format are unchanged. Source light
responds to earthwork through the difference from baseline gameplay heights.
Consequently the game still has up to roughly four pixels of vertical rounding
relative to the raw-height sandbox at 1× zoom; this is not a texture mismatch.

Camera motion and daylight retain existing meshes and material data. Road wear
updates surface rows only. Terrain edits update bounded CPU weight/light
regions and existing GPU textures. Configured terrain palette colors remain
supported. Bare historical renderers still default to the original procedural
mode, and a missing atlas falls back to it. Water is still static.

## Optional source metadata

`PaintedTerrainSource` validates the local
`game/external_assets/maps/mountainous-region.visual.json` before attaching
presentation-only grid metadata. MainView restores it on New Game, reset and
saved-world load, only for the explicitly selected supported map. Missing or
invalid metadata safely uses the generic V1 map materials instead. It does not
affect other maps or migrate saves.

The sidecar is ignored external source data, like the existing converted map.
To reproduce it from the user's local map and the local reference definitions:

```sh
node tools/export-painted-visual.cjs \
  --map "/absolute/path/to/Mountainous Region.map" \
  --tiles reference/kam_remake/data/defines/tiles.json \
  --out game/external_assets/maps/mountainous-region.visual.json
```

The exporter refuses to overwrite an existing output; move any old output
aside explicitly before regenerating. No source artwork or mission code is
exported. Definitions absent from the approved interpretation fail explicitly.

## Verification

```sh
godot --headless --path game res://tests/test_runner.tscn
godot --headless --path game res://tests/terrain_sandbox_runner.tscn
node --test tools/export-painted-visual.test.cjs
```

Verified 2026-09-07:

- Full game suite: **589/589 passed**; sandbox: **40/40**; exporter: **6/6**.
- Nine native road/guidance comparisons under white/day/night modulation were
  byte-identical to the ordinary renderer. Day/night affects V1 ground without
  rebuilding meshes or material data.

- Twelve renderer, eight material-data and seven metadata test groups cover
  real atlas use, shared shader formulas, source/generic weights, exact signed
  light, missing/invalid metadata, simulation immutability, road preservation,
  custom tints, bounded cache updates, fresh-build equivalence and save data.
- Native GPU checks open all four maps through the actual New Game controls,
  verify the complete compositor and source-mode selection, and inspect real
  game screenshots at overview and detail zoom.
- Native V1/legacy switching preserves all terrain polygons/rules, sampled
  picking, camera and world state; restoring V1 reproduces the paused frame.
  Twenty simulation ticks match an untouched snapshot copy.
- Side-by-side native captures of both sandbox crops and the actual production
  terrain were visually inspected; the small geometry rounding remains.
- Existing user saves and pre-existing game/sandbox windows were untouched.

Built-in previews are in `docs/previews/painted-v1-*.jpg`. Imported-source
previews remain local/ignored under
`game/external_assets/terrain-sandbox/previews/`.
