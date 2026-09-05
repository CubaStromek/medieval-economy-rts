# Basic roads and trees — 2026-09-05

Original raster assets generated with the **built-in imagegen tool** for this
prototype. No original Knights and Merchants game assets were imported.

## Source artwork

- `trees-basic-v1.png`: transparent 3 × 3 atlas. Columns: oak, beech, spruce.
  Rows: sapling, young, mature. Species are visual variants of the existing
  generic timber tree; no new resource, growth or save-game rules.
- `stone-road-basic-v1.png`: opaque repeating warm-grey cobblestone texture.
  The renderer owns connectivity, shoulders, intersections and slope projection;
  the texture contains only the material, not a baked road shape.

Both PNGs are preserved as generated. Godot uses trimmed atlas regions and
mipmaps to keep the small tree silhouettes clean at overview zoom. Tree roots
remain attached to the relief surface and existing depth ordering. Roads
retain their existing movement speeds and traffic-wear behavior.

This is basic environment art, not seasonal foliage, animated falling trees
or a complete terrain-texture replacement.

## Production prompts

### Tree atlas

```text
Use case: stylized-concept
Asset type: transparent 2D sprite atlas for a small-scale medieval economy RTS.
Primary request: basic, readable hand-painted trees matching simple medieval worker sprites, not extra detailed.
Composition: exactly NINE isolated tree sprites in a precise 3-column by 3-row uniform grid on a square canvas. Columns left to right: broad rounded oak; narrower oval deciduous beech; pointed layered spruce conifer. Rows top to bottom: tiny sapling with slender visible stem and few leaves; young tree with partial canopy; mature full-grown tree. The SAME species must develop down its column.
Style: old-school fixed-view 2.5D RTS, three-quarter orthographic camera looking downward about 35 degrees, chunky irregular leaf clusters using three or four clean shade masses; subtle dark silhouette edge, slightly painterly but deliberately low detail, warm brown trunks with minimal roots, muted natural forest and olive greens, lit from upper left.
Layout constraints: keep each tree FULLY inside its own grid cell, centered horizontally, ROOT at bottom-center of its sprite. Leave at least 12% empty space around every sprite; fully transparent horizontal and vertical gutters; no touching, no overlapping. Saplings simple and small, young medium, mature broad; no exaggerated giant canopies. Each sprite separate, complete trunk and roots visible.
Background: genuinely TRANSPARENT alpha, including between leaves and under all trees. No ground, no grass clumps, no soil islands, no drop shadows, no gradient, no background color, no scene, no checkerboard drawn into image.
Avoid: labels, lettering, UI, grid lines, borders, watermarks, photorealism, individual leaf microdetail, fantasy glowing colors, cropped canopies, duplicate sprites. Deliver only the transparent atlas.
```

### Road material

```text
Use case: stylized-concept
Asset type: seamless opaque repeatable albedo texture for medieval RTS cobbled paths, square image.
Primary request: basic hand-painted irregular cobblestone road surface, subdued warm grey stones in narrow brown earth joints, to match simple small medieval worker sprites.
Composition: flat top-down orthographic material texture covering every pixel, edge-to-edge seamless repeat horizontally and vertically. Roughly 12 stones across and 12 stones vertically, irregular rounded rectangular pavers with slight size variation, loosely staggered rows, tiny worn bevels. Readable broad shapes and restrained texture, not a photo. Warm gray/taupe stone tops with modest values, narrow dark earthy joints, very few muted moss flecks.
Lighting: softly lit from upper left with subtle baked bevel shading only; uniform global brightness across the square. No perspective, horizon, vignette or gradients.
Constraints: actual opaque square texture, no road outline or separate isolated path, no grass borders, no text, no objects, no characters, no footprints, no seams or frame, no white background, no watermark. Natural low-contrast painterly basic game art, avoid thick black cracks or large polygon slabs.
```
