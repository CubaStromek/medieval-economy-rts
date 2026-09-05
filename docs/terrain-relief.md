# Playable terrain relief — 2026-09-05

This first terrain milestone uses a fixed, foreshortened 2.5D view, not a
rotatable 3D camera or a diamond-tile conversion. The simulation remains an
orthogonal grid. Original procedural textures and the existing upright
placeholder buildings/units are retained; final painted art is a later stage.

## Try it

Run `godot --path game -- --relief-demo` for the populated 28 × 22 relief village.
The sawmill sits on the upper meadow; the warehouse and lumberjack hut are
below it. Carriers climb the connecting road with logs and return with planks.
The rocky eastern ridge is impassable except for its two-cell low pass.

The default launch uses this landscape for the minimal test level: only a
completed Warehouse and School, no citizens or roads, 20 each of logs, planks
and stone in the Warehouse, and 50 gold total (49 in the Warehouse, one in the
School for training the first Carrier). All other starting stocks are zero.

- **Terrain / F2** toggles green level ground, amber walkable slopes and red
  blocked cells. This describes terrain/occupancy, not affordability or all
  building-specific siting requirements.
- Select empty ground to inspect its height, slope and walk/build status.
- Use **1** to extend a road along a gentle slope. Buildings and fields need
  flat foundations; high plateaus are valid, while steep grass is not.
- **R** resets the selected demo. **F5 / F9** save/load, including heights.
- The complete 34 × 24 economy demo remains available with
  `godot --path game -- --economy-demo`.

The small village has starter food, construction materials, a School, an Inn,
four carriers, a lumberjack, a carpenter, a gardener with a Forester Hut and a builder. The normal
construction, training, hunger and transport rules are active. This is not a
self-sustaining food economy; use R to restart or expand it normally.

## Shared terrain contract

`GridMapSim` stores integer heights 0–64 on a shared `(width+1) × (height+1)`
corner lattice. The diagonal runs top-left to bottom-right in every cell;
rendering and continuous unit positions sample those same two triangles.
Corner edits increment the grid revision. The safe world-level setter protects
entities, foundations, entrances and reserved/moving positions; there is no
player terrain-editing tool yet.

Slope is the maximum minus minimum of a cell's four corners. Walking/roads
allow slope up to 3; foundations/fields require 0. Absolute altitude does not
block walking or construction. Rock and water remain blocked by material.
Path searches, actual movement, swaps, building exits and adjacent resource
interactions enforce compatible height rules. Movement times stay unchanged
(grass 6, dirt trail 4, stone road 2 ticks); no extra uphill cost is introduced.

## Rendering and picking

The projection uses 40 × 40 ground units with 8 vertical pixels per height
unit. Geometry, terrain transitions and road surfaces conform to the triangles.
Directional slope shading and surface-following elevation cues make relief visible.
Building/field tools add a temporary slope hatch and live placement feedback;
flat plateaus remain valid. See [square-terrain.md](square-terrain.md). Static terrain and road/wear
surfaces have independent cell caches and retained row meshes. Consecutive
triangles with the same texture share a mesh without changing their order.

Terrain rows keep their drawing commands between frames, including while the
camera moves or zooms. Only dynamic object rows repaint for animation. Even
terrain depths and odd object depths interleave from back to front. Depth uses
logical ground position, never height-shifted screen Y.
Worker interpolation occurs in ground coordinates before height sampling.
Picking tests the visible terrain triangles in reverse painter order; building
hit tests reject roof/wall points hidden by foreground terrain. Selection and
fields follow the projected ground rather than flat bounding rectangles.

There is no full 3D depth buffer, camera rotation, bridge/overhang support or
large-map chunk/culling system in this milestone. A footstep changes only its
surface cell and cardinal neighbours (at most five cells / three rows); base
terrain stays untouched. Terrain/height edits also update transition neighbours.
Definition changes, loading a replacement grid and untracked legacy revision
edits conservatively rebuild the complete cache. The grid's multi-reader change
stamps use fixed memory proportional to map size, not elapsed play time.

See [render-performance.md](render-performance.md) for measured results and the
repeatable native profile command.

## Compatibility and validation

Save version 8 adds required corner-height rows. Versions 1–7 load with zero
heights and retain their economic state. Invalid dimensions, non-integer or
out-of-range heights and incompatible entities are rejected transactionally.

New suites cover height sampling, steep barriers and ramps, plateau foundations,
real worker rerouting, swaps/interactions, resource reach, protected editing,
v8 round trips and legacy migrations, projection/picking/cache invalidation,
the demo's 2,000-tick uphill production chain, and in-viewport relief controls.
Existing economy and UI scenarios continue to run on the original economy
fixture, explicitly selected by the tests.
