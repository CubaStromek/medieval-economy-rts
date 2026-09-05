# Construction material costs

Verified on **2026-09-05**. The catalog has 28 reference buildings plus the
project's Forester Hut (29 total). Costs below
use the project's resource IDs: `plank` is processed timber, not a raw `log`;
`stone` is building stone (called bricks in some older English manuals).

## Evidence and scope

- **Manual:** the published [English TPR 1.60 manual](https://www.knightsandmerchants.net/application/files/7315/6828/9445/manual_tpr_160_eng.pdf)
  gives the costs for 26 entries. Page references below are the printed page
  numbers, not zero-based PDF indices. The school cost is in its construction
  example on page 14. The original [TSK Mac manual, pages 14-15](https://www.knightsandmerchants.net/application/files/1315/6828/9401/manual_tsk_mac_eng.pdf)
  independently confirms the hut, quarry and sawmill costs.
- **Community:** the manuals inspected omit the storehouse cost. Its 6 planks
  and 5 stone come from the [Knights and Merchants NET building catalog](https://www.knightsandmerchants.net/information/buildings),
  a secondary source. This exception is explicitly distinguished in the data.
- **Remake source:** the marketplace is a Remake addition. Its 5 planks and
  6 stone are explicit in [KM_ResHouses.pas, lines 822-823](https://github.com/reyandme/kam_remake/blob/a3b3e5268e1475460e4561f9143df6f1a532e681/src/res/KM_ResHouses.pas#L822).
  The inspected checkout is pinned to `a3b3e5268e1475460e4561f9143df6f1a532e681`.

The other Remake house costs are loaded from `data/defines/houses.dat`, which
is absent from the source checkout. This is a documented reconstruction from
published cost facts, not a claim to have extracted or verified that binary.
No proprietary assets, binary game data or manual artwork are distributed.

## Complete catalog

All material quantities are for one completed building. Every row marked
with a page number uses the manual linked above.

| Building ID | Planks | Stone | Evidence |
|---|---:|---:|---|
| `warehouse` | 6 | 5 | Community: Storehouse |
| `lumber_hut` | 3 | 2 | Manual p. 23 |
| `forester_hut` | 3 | 2 | Project balance; [extension rules](forester-and-fisher-huts.md) |
| `sawmill` | 4 | 3 | Manual p. 24 |
| `school` | 6 | 5 | Manual p. 14 |
| `quarry` | 3 | 2 | Manual p. 22 |
| `farm` | 4 | 3 | Manual p. 27 |
| `mill` | 4 | 3 | Manual p. 28 |
| `bakery` | 4 | 3 | Manual p. 29 |
| `coal_mine` | 3 | 2 | Manual p. 36 |
| `iron_mine` | 3 | 2 | Manual p. 37 |
| `gold_mine` | 3 | 2 | Manual p. 38 |
| `iron_smithy` | 4 | 3 | Manual p. 41 |
| `metallurgist` | 4 | 3 | Manual p. 39 |
| `vineyard` | 4 | 3 | Manual p. 26 |
| `fisher_hut` | 4 | 3 | Manual p. 25 |
| `swine_farm` | 4 | 3 | Manual p. 30 |
| `butcher` | 4 | 3 | Manual p. 31 |
| `tannery` | 4 | 3 | Manual p. 32 |
| `stables` | 6 | 5 | Manual p. 33 |
| `weapon_workshop` | 4 | 3 | Manual p. 34 |
| `armour_workshop` | 4 | 3 | Manual p. 35 |
| `weapon_smithy` | 4 | 3 | Manual p. 42 |
| `armour_smithy` | 4 | 3 | Manual p. 43 |
| `inn` | 6 | 5 | Manual p. 21 |
| `barracks` | 6 | 6 | Manual p. 45 |
| `marketplace` | 5 | 6 | Remake source override |
| `town_hall` | 6 | 5 | Manual p. 40 |
| `watchtower` | 3 | 2 | Manual p. 46 |

The mapping retains the existing project IDs: Warehouse is Storehouse, School
is Schoolhouse, Lumberjack Hut is Woodcutter's, and Armour Workshop is Armoury
Workshop. Marketplace has no counterpart in the original playable catalog.

## Data contract and bootstrap

`game/data/buildings.json` is the runtime authority for these quantities.
`construction_cost_source` distinguishes `kam_manual`,
`kam_community_reference` and `kam_source_override`.
`construction_cost_reference` holds the supporting URL;
`construction_cost_reference_page`, when present, holds the printed manual page.

The lumberjack hut and quarry both need **3 planks + 2 stone**; the sawmill
needs **4 planks + 3 stone**. Removing stone from these buildings would be a
project balance change. A new scenario must supply initial construction wares
or existing production, so the first material-production chain can be built.
Resource shortages must be diagnosed separately from the authentic cost table.

The default test level starts with 20 logs, 20 planks, 20 stone and 50 gold.
Hut + sawmill + quarry + inn cost 16 planks
and 12 stone, leaving a reserve of 4/8. Two finite deposits at the western
foot of the ridge support further quarry production. These starter amounts
are scenario balance, not a claim about all original KaM scenarios. Existing
saved inventories are unchanged; only a new game/reset receives this setup.

Save v9 records `construction_cost_revision` for every building. New sites
use revision 2; v1–8 snapshots migrate to the explicit revision-1 historical
cost table. Delivery, builder readiness, inspector counters and validation all
use the site's own revision, while the build menu shows new-site costs.
Completed buildings also keep their delivered-material history. Loading
does not convert inventories, throw away surplus or refund the price difference;
cancelling an unfinished site returns only its actual delivered materials.

This cost correction changes 13 numerical entries and confirms 15 unchanged
entries. It does not change footprints, recipes, profession requirements,
construction work durations or production timing. Those remain separate
project rules documented in [the economy reference](kam-economy-reference.md).
