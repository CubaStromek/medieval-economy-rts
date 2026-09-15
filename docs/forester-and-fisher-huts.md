# Forester and Fisherman's Huts

Implemented on **2026-09-05**. The catalog now contains 28 reference buildings
plus the project's Forester Hut extension (29 total; the Workers' Cottage was removed on 2026-09-14).

| Building | Build menu | Materials | School profession | Work area |
|---|---|---|---|---|
| Forester Hut (`forester_hut`) | Infrastructure | 3 planks, 2 stone | Gardener | Planting within Manhattan distance 8 of the hut |
| Fisherman's Hut (`fisher_hut`) | Food | 4 planks, 3 stone | Fisherman | Reachable finite fish deposits within distance 3 |

The Forester Hut is an original project extension, not an original KaM house.
Its price is a **project balance** decision, matching the existing Lumberjack
Hut's material tier. The Fisherman's Hut retains its documented reference
price in [construction-costs.md](construction-costs.md).

Both huts use the existing construction pipeline: carriers deliver finished
planks and stone, then a Builder completes the site. Each completed hut has
one compatible worker slot. Training is separate, costs one gold per citizen
at a School, and does not create a free house. An extra specialist waits for
a reachable vacant hut; full stores or temporarily blocked paths do not
cause ownership changes.

The Gardener chooses valid reachable planting sites near their own hut,
reserves one at a time, plants a sapling and waits through the existing
cooldown. They cannot plant while homeless or use another Gardener's hut.
The normal terrain, entrance, overlay and occupancy protections still apply.
Lumberjacks remain responsible for cutting mature trees and carrying logs
to their own Lumberjack Huts; carriers transport those logs onward.

The Fisherman walks to a reachable bank, catches one fish from a finite
deposit, and brings it to their own hut. Carriers take the fish onward to
consumers or the Warehouse. A hut needs a reachable fish deposit at placement;
water alone is insufficient. The default level now supplies fish deposits
in its existing southwestern lake: two shoals of 40 fish each, at `(3,18)` and
`(3,20)`. A valid nearby hut site is `(5,19)`. No extra buildings, units or
starting inventory are granted.

Both huts were introduced using the v11 building and unique `home_id` fields.
The subsequent v12 indoor-worker update additionally preserves workers' actual
visits inside buildings. Old unassigned Gardeners remain alive and wait
for a completed Forester Hut. Existing saves retain their authored deposits;
new default-map fish stocks appear on a new game/reset, not by rewriting saves.
