# Our painted terrain materials — 2026-09-07

As of 2026-09-07, these same authored materials are also enabled in the regular
[game on existing maps](painted-terrain-game.md). The sections below describe
the original sandbox integration and its distinct material/lighting model.

## Try it

Open `Graphics Sandbox.command`. In the right sidebar, **SADA TEXTUR** switches
between **Původní KaM** (the unchanged local original atlas) and
**Naše malované · v1** (our new painted materials).
Use **Vedle terénní reference** for an original-textured baseline on the left;
the selected working version is on the right. Both map crops are supported.

The selector preserves the crop, heights, camera, lighting and object settings.
Save settings remembers the chosen pack. New/reset sessions use our pack and the
reference comparison; old saved presets without a pack keep their classic look.
The left reference remains fixed at its original lighting/relief defaults;
only the working pane follows experimental sliders.

The sandbox remains isolated from the production game. Its controls do not
change production rendering, maps, simulation or collision rules. Original local graphics are
neither modified nor added to Git. Missing/unsupported modern materials disable
that choice and retain the classic rendering.

## Artwork and provenance

`game/art/terrain/modern-materials-v1.png` is original raster artwork generated
with the **built-in imagegen tool**, using only the text prompt below. No original
KaM bitmap, transition mask or image was supplied, sampled or copied into it.
The generated PNG is preserved unchanged.

Actual returned resolution: **1774 × 887**, four columns by two rows.
The requested 2048 × 1024 is part of the prompt, not the delivered dimensions.
Rows, left to right:

1. Meadow grass, dry grass, limestone rock, packed earth.
2. Gravel, blue-green water, coal-bearing rock, ore-bearing rock.

The artwork uses subdued natural colors and fine painterly detail. It is a first
art-direction sample, not a finished full-game tileset. Water remains static.
Gravel is included in the atlas but is not assigned to these two map crops.

## Material rendering

The modern path uses the same terrain mesh, raw heights and signed slope-light
model as the classic path. Pack switching changes cached materials only.
Classic mode remains the existing 32-pixel-per-tile atlas path.

The modern atlas supplies roughly 111 source pixels per ground tile: each
material swatch spans four tiles. Normalized swatch coordinates support the
non-integer cell boundaries, with a two-pixel inset and mirrored repetition to
avoid cross-swatch bleed and hard wrap seams. Filtering is switchable in both
packs. Shared world-space coordinates keep material detail continuous across
triangles and tile boundaries.

Source tile IDs/rotations are interpreted as corner material types for the
42 IDs present in these two crops. Corner order is TL, TR, BR, BL; rotation
selects source corner `(i + 4 - rotation) % 4`. All tiles incident to a vertex
contribute to a shared material-weight value, interpolated continuously across
the terrain. This reconciles inconsistent source material labels on shared
edges. Transitions are our own smooth interpretation, **not pixel-exact original
KaM transition masks**. The source's dirt category is visually vegetated here:
our D corner weights are grass 0.45 / dry grass 0.40 / earth 0.15, and mixed M
corners use 0.65 / 0.25 / 0.10. These are artistic input weights, not final pixel
percentages: continuous noise and sharpening preserve crisp material detail.
Unknown tile IDs are rejected for this limited modern set.

Semantics were checked against the existing local source snapshot
`reference/kam_remake`, commit `a3b3e5268e1475460e4561f9143df6f1a532e681`:
`data/defines/tiles.json`, `src/terrain/KM_TerrainPainter.pas` and
`src/terrain/KM_Terrain.pas`. Engine source semantics and our artwork are
separate from the proprietary graphics retained only as local references.

## Reproduce checks

```sh
godot --headless --path game res://tests/terrain_sandbox_runner.tscn
```

Verified 2026-09-07:

- Graphics sandbox: **40 cases, 0 failures** (including 10 modern material and
  7 state/persistence groups); synthetic tests need no original bitmap.
- Production game: **552/552 passed**, with no production renderer changes.
- Native classic renderer vs pre-change renderer: byte-identical pixels in four
  lighting/height/filter configurations; neutral rendering matches both packs.
- Native modern rendering differs; nearest/linear filtering visibly changes
  output. Separate cached texture resources avoid the OpenGL sampler-state
  conflict when two differently filtered samplers reference one texture.
- Both real crops, pack switches, fixed classic reference, retained camera/mesh
  and other options; modern selection persists to JSON and capture metadata.
- GUI checkbox/wheel input and 1900 × 1080 / 1100 × 720 layouts checked.
- Missing atlas fallback, unavailable selection through the public setter,
  invalid-preset notice and legacy preset migration checked on the real scene.

Native checks additionally use the existing local source crops and original
atlas. Preview images remain in the ignored sandbox previews directory.

## Generation prompt

```text
Use case: stylized-concept
Asset type: ONE production-ready terrain material texture atlas for our own medieval economy RTS game, not a screenshot and not concept scenery.
Create original hand-painted high-resolution bitmap artwork with the warm natural character of late-1990s European medieval strategy games, but cleaner, richer and more refined at modern zoom levels. Do not copy any existing game pixels or layouts.
Composition: a precisely aligned 4-column by 2-row grid filling the entire 2048 x 1024 canvas. Eight equal square material swatches, each 512 x 512. No spaces, borders, separators, labels, text, frames or margins. Every swatch is a flat orthographic material surface filling its entire square. These are albedo textures to be lit by the game engine, not rendered terrain patches.
Exact swatch order left to right:
TOP ROW: 1) dense short meadow grass, olive and fresh moss greens, many fine painted blades with gentle tonal clusters, no flowers; 2) drier meadow turf, muted olive and straw-ochre grasses with a little exposed earth, restrained saturation; 3) weathered warm gray limestone bedrock, interlocking small fractured rock facets and fine cracks, a few mossy flecks, not brickwork or isolated boulders; 4) warm brown packed soil, fine earth grains and tiny scattered stones, no tracks.
BOTTOM ROW: 5) pale gray-beige rocky gravel and stony earth, varied small irregular mineral chips; 6) calm blue-green freshwater surface, small soft painterly ripple strokes, subtle depth variations, no shore, no objects, no large waves or bright white foam; 7) charcoal-gray coal-bearing bedrock, fractured rock with subdued dark mineral veins, detailed but not pure black; 8) warm gray mineral-bearing rock with sparse earthy ochre/gold flecks and narrow muted veins, not shiny jewelry or big gold nuggets.
All eight swatches must belong to one cohesive art direction. Fine readable painted detail, natural muted colors, moderate contrast. Uniform diffuse lighting across every swatch. Each individual swatch should tile seamlessly on all four edges, no focal center, no vignetting or macro gradients.
Avoid: pixel art, blocky low-resolution pixels, photorealistic scans, glossy 3D, dramatic baked shadows, isometric cubes, terrain silhouettes, trees, buildings, icons, watermarks, any writing.
```
