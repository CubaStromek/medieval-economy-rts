# Building footprints — 2026-09-06

New buildings use full tile masks with fixed south-facing entrances. Placement,
blocking, selection, construction cancellation, drawing and save restoration
share that geometry. Existing saved buildings retain their historical geometry.

## Reference

The 28 reference buildings use `HOUSE_DAT_X.PlanYX` from KaM Remake commit
`a3b3e5268e1475460e4561f9143df6f1a532e681`, in
[`KM_ResHouses.pas`](https://github.com/reyandme/kam_remake/blob/a3b3e5268e1475460e4561f9143df6f1a532e681/src/res/KM_ResHouses.pas).
Empty outer rows/columns are trimmed, preserving every occupied tile and the
`2` door marker. The project-specific Forester Hut uses the Woodcutter shape.
The normal-menu catalog includes the Remake Marketplace and excludes its unused
Siege Workshop. This is verified Remake geometry, not an assertion that every
original retail edition has identical definitions. Artwork is original to this
project; original game graphics and data archives are not included.

## Geometry contract

`game/data/buildings.json` contains `footprint: [width, height]`,
`footprint_mask`, and per-building provenance. Rows run north to south:
`#` is occupied ground, `E` is an occupied door tile, `.` is unoccupied ground.
The saved `position` is the bottom-left corner of the trimmed bounding box;
row `y`, column `x` lies at `position + (x, y - height + 1)`. The external
`entrance` is one tile south of `E`. Units stand outside the doorway when they
enter or leave; hidden residents do not occupy the building's blocked ground.
All currently referenced doors are on the southern edge. Rotation is future work.

The `building_footprints.gd` helper defines geometry. SimulationWorld exposes
`placement_cells`, `placement_entrance`, `building_cells`, and
`building_door_cell`; callers use those rather than reconstructing bounds.
Masks remain authoritative: the empty corner of the Fisher Hut stays usable.

Completed foundations use one flat elevation. New economy sites may begin on
safely preparable gentle terrain; a Builder must first level the whole mask
before materials arrive. See [ground-preparation rules](foundation-preparation.md).
All occupied cells must have suitable terrain and remain free of buildings,
resources, fields, trees, citizens and work reservations. Existing entrances
remain clear. The new entrance must be traversable and retain an outside
approach. Roads beneath a valid site are removed together with related trail
links. Cancelling a site refunds delivered materials under existing rules and
unblocks its entire mask. Modern extraction range is measured from the nearest
occupied footprint tile, while the exterior entrance must reach a deposit work
face after the proposed walls are blocked; legacy buildings keep anchor range.

## Catalog

Dimensions are bounding boxes. Occupied counts include the door tile. In mask
notation below, `/` separates north-to-south rows.

| Building | Size | Occupied | Mask |
|---|---:|---:|---|
| `warehouse` | 3 × 3 | 9 | `### / ### / #E#` |
| `lumber_hut` | 3 × 2 | 6 | `### / ##E` |
| `forester_hut` | 3 × 2 | 6 | `### / ##E` |
| `sawmill` | 4 × 2 | 8 | `#### / #E##` |
| `school` | 3 × 3 | 9 | `### / ### / #E#` |
| `quarry` | 3 × 2 | 6 | `### / #E#` |
| `farm` | 4 × 3 | 12 | `#### / #### / #E##` |
| `mill` | 3 × 2 | 6 | `### / #E#` |
| `bakery` | 3 × 3 | 9 | `### / ### / ##E` |
| `coal_mine` | 3 × 2 | 6 | `### / #E#` |
| `iron_mine` | 3 × 1 | 3 | `#E#` |
| `gold_mine` | 2 × 1 | 2 | `#E` |
| `iron_smithy` | 4 × 2 | 8 | `#### / ##E#` |
| `metallurgist` | 3 × 3 | 9 | `### / ### / #E#` |
| `vineyard` | 3 × 2 | 6 | `### / ##E` |
| `fisher_hut` | 3 × 2 | 5 | `##. / E##` |
| `swine_farm` | 4 × 3 | 11 | `.### / #### / ###E` |
| `butcher` | 3 × 3 | 8 | `##. / ### / ##E` |
| `tannery` | 3 × 2 | 6 | `### / #E#` |
| `stables` | 4 × 3 | 12 | `#### / #### / ##E#` |
| `weapon_workshop` | 4 × 2 | 8 | `#### / #E##` |
| `armour_workshop` | 3 × 3 | 8 | `##. / ### / E##` |
| `weapon_smithy` | 4 × 2 | 8 | `#### / #E##` |
| `armour_smithy` | 4 × 3 | 10 | `.##. / #### / #E##` |
| `inn` | 4 × 3 | 11 | `.### / #### / #E##` |
| `barracks` | 4 × 4 | 16 | `#### / #### / #### / #E##` |
| `marketplace` | 4 × 3 | 11 | `.### / #### / ###E` |
| `town_hall` | 4 × 3 | 12 | `#### / #### / #E##` |
| `watchtower` | 2 × 2 | 4 | `## / #E` |

## Saves and compatibility

Save v16 introduced, and v17 retains, `footprint_version` per building. Version 1 uses the catalog mask;
version 0 preserves a single occupied anchor and its historical saved entrance.
Versions 1–15 migrate their buildings to 0 without moving anything, granting
materials, restarting work or expanding into neighboring entities. New buildings
placed after loading use version 1, so both can coexist in the same settlement.

Loading validates every occupied tile, terrain/elevation, door, entity overlap
and surface state in a staged world, then replaces the live world only after
all checks pass. Unsupported geometry versions and malformed footprints fail
without partially changing the live map. Geometry version 1 must remain stable;
a future shape change requires an explicit migration/version policy.

## Rendering and scenarios

The placement preview outlines every occupied tile and marks the exterior door
in blue. Foundation, roof outline, windows, door and scaffolding scale to the
actual mask. Ground and visible building geometry both support selection.
Shadows use the building's full ground extent. Original one-cell buildings keep
their previous rendering when a historical save is loaded.

The starter School and Warehouse remain at their original anchors and have
nine occupied tiles each. The relief village has spaced buildings and connected
outside roads. The full economy demo contains all 29 types, 235 occupied tiles,
and clear door routes. Its resource and road authoring uses normal placement
rules to keep roads out of deposits.

## Verification

The footprint milestone passed **483/483** combined cases on 2026-09-06. Native
rendering and actual pointer placement were inspected in
[`building-footprints-village.png`](previews/building-footprints-village.png) and
[`building-footprints-placement.png`](previews/building-footprints-placement.png).

Dedicated suites use default production worlds: source masks and irregular
notches, all occupied-cell collision checks, blocked doors, slopes, cancellation,
real transport and indoor work, malformed and historical saves, every production
recipe, night departure, and actual viewport input/rendering. The real starter
scenario still trains paid citizens and builds its wood/stone chain through
player commands; the relief scenario runs uphill logistics and resumes after load.

Existing compact economy/movement fixtures explicitly opt into the supported
version-0 geometry through `tests/legacy_world_fixture.gd`. Their independent
expectations are retained as historical-save behavior; production never loads
that test helper. New scenarios and footprint suites exercise version 1.
