# Building footprints — updated 2026-09-10

New buildings use full tile masks with fixed south-facing entrances. Placement,
blocking, selection, construction cancellation, drawing and save restoration
share that geometry. Existing saved buildings retain their historical geometry.

## Reference

The original 28 reference building masks used `HOUSE_DAT_X.PlanYX` from KaM Remake commit
`a3b3e5268e1475460e4561f9143df6f1a532e681`, in
[`KM_ResHouses.pas`](https://github.com/reyandme/kam_remake/blob/a3b3e5268e1475460e4561f9143df6f1a532e681/src/res/KM_ResHouses.pas).
Empty outer rows/columns are trimmed, preserving every occupied tile and the
`2` door marker. The project-specific Forester Hut uses the Woodcutter shape;
the Workers' Cottage has its own compact 2 × 2 project-authored mask.
The normal-menu catalog includes the Remake Marketplace and excludes its unused
Siege Workshop. This is verified Remake geometry, not an assertion that every
original retail edition has identical definitions. Artwork is original to this
project; original game graphics and data archives are not included.

On 2026-09-10 the user authorized a project-authored revision of `lumber_hut`
to fit its existing ground contacts without regenerating its art or construction
set. Its old reference mask remains frozen as version 1. The current version 2
is documented in the [integration record](art/briefs/lumber-hut-footprint-v2-integration.md).
This is an explicit exception: future generated objects must fit their
predetermined footprint before construction or other variants are produced.

## Geometry contract

`game/data/buildings.json` contains `footprint: [width, height]`,
`footprint_mask`, and per-building provenance. Rows run north to south:
`#` is occupied ground, `E` is an occupied door tile, `.` is unoccupied ground.
The saved `position` is the bottom-left corner of the trimmed bounding box;
row `y`, column `x` lies at `position + (x, y - height + 1)`. The external
`entrance` is one tile south of `E`. Units stand outside the doorway when they
enter or leave; hidden residents do not occupy the building's blocked ground.
Doors face south; they may sit in a recess within the bounding box. Every cell
south of `E` in its column must be empty, so the approach leads out without
crossing occupied ground. The v2 lumber hut uses such a recess. Rotation is future work.

The `building_footprints.gd` helper defines geometry. SimulationWorld exposes
`placement_cells`, `placement_entrance`, `building_cells`, and
`building_door_cell`; callers use those rather than reconstructing bounds.
Masks remain authoritative: the empty corner of the Fisher Hut stays usable.
Definitions may declare `footprint_version` (default 1) and immutable historical
`footprint_revisions`. Helper `for_version` selects the saved building's geometry;
new placement uses each type's latest supported revision, not the global maximum
for every building type.

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
| `lumber_hut` (v2) | 4 × 3 | 9 | `.### / .##E / ###.` |
| `forester_hut` | 3 × 2 | 6 | `### / ##E` |
| `workers_house` | 2 × 2 | 4 | `## / #E` |
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

Save v16 introduced `footprint_version` per building. Current save **v21** adds
support for the lumber hut's version 2; saves v16–20 support geometry 0/1 only.
Version 0 preserves a single occupied anchor and its historical saved entrance.
Saves v1–15 migrate their buildings to 0 without moving anything, granting
materials, restarting work or expanding into neighboring entities.

Version 1 remains immutable. In the lumber hut definition it is stored as
`footprint_revisions["1"]`: 3 × 2, `### / ##E`, six occupied cells. Existing
v0/v1 huts keep their saved positions, entrances and collisions, even when saved
again as v21. They are not automatically expanded into a neighboring road or
building. Newly placed huts use v2, while every other current building type
continues to use v1. All three versions can coexist in one save.

The new hut has door offset `(3,-1)` and external entrance offset `(3,0)`.
For a new fixture with the same physical door as an old v1 hut, its bounding-box
anchor is `old_anchor + (-1,+1)`; this is used when authoring new demo/QA worlds,
not as a migration of saved buildings. At the same door and elevation, the
unchanged artwork retains its exact registration.

Loading validates every occupied tile, terrain/elevation, door, entity overlap
and surface state in a staged world, then replaces the live world only after
all checks pass. Unsupported geometry versions and malformed footprints fail
without partially changing the live map. Historical geometry revisions must
remain stable; further shape changes require an explicit version policy.

## Rendering and scenarios

The placement preview outlines every occupied tile and marks the exterior door
in blue. Foundation geometry follows the selected mask revision. Vector fallback
buildings derive their walls and scaffolding from that mask; the bitmap lumber
hut keeps its measured door registration and image scale across v1/v2 instead
of stretching the artwork to its new bounding box. Ground and visible building
geometry both support selection. Shadows use the building's ground geometry.
Original one-cell buildings keep their previous rendering when a historical save
is loaded. Construction PNGs, masks and the stock layers are unchanged by v2.

The starter School and Warehouse remain at their original anchors and have
nine occupied tiles each. The relief village has spaced buildings and connected
outside roads. The full economy demo represents all 30 types with 35 building
instances and 262 occupied tiles with the v2 hut (259 before this revision),
and clear door routes. Its resource and road authoring uses normal placement
rules to keep roads out of deposits.

## Verification

The original footprint milestone passed **483/483** combined cases on 2026-09-06. Native
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
that test helper. Current scenarios and footprint suites exercise each type's
latest revision, with explicit checks for v0/v1 historical buildings. The
[v2 hut QA record](art/qa/lumber-hut-footprint-v2/README.md) owns the new test
results and native evidence; the historical counts and images above are not
evidence for this revision. Revision v2 passed 12/12 focused geometry cases,
755/755 combined headless cases and 41/41 native regressions on 2026-09-10;
its QA record includes actual pointer placement and natural log delivery.
