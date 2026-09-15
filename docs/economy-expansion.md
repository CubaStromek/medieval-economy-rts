# KaM-style economy expansion

## Current scope — 2026-09-09

The playable catalog contains **30 buildings, 28 wares, 15 civilian professions,
19 processing recipes and 14 military recruitment types**. The starting village
is **34 × 30 tiles**. The implementation covers the economic branches of the
public KaM Remake reference in this project's own fixed-tick simulation. It is
not a claim of complete KaM behavior, balance, graphics or combat parity.

Buildings are organized as follows:

| Category | Buildings |
|---|---|
| Infrastructure | Warehouse, Lumberjack Hut, Forester Hut, Sawmill, School, Marketplace |
| Food | Farm, Mill, Bakery, Vineyard, Fisherman's Hut, Swine Farm, Butcher, Inn |
| Mining | Quarry, Coal Mine, Iron Mine, Gold Mine, Iron Smithy, Metallurgist |
| Military | Tannery, Stables, Weapon Workshop, Armour Workshop, Weapon Smithy, Armour Smithy, Barracks, Town Hall, Watchtower |

The catalog is authoritative for UI grouping and rules. The separately
placeable wheat/vine plots and stone roads are not counted as buildings.
Gardeners are an original extension: they act as autonomous foresters and
plant new trees near their own Forester Hut. They are available through
**Train Gardener** at a School; a completed vacant hut is required to work.
The extra hut is project-balanced; see [hut rules](forester-and-fisher-huts.md).

## Fields, trees and finite extraction

A wheat field starts prepared and empty. A farmer from a completed Farm within
Manhattan distance 8 walks to a reachable plot, spends 20 ticks sowing it,
then leaves the wheat to grow for 200 ticks. Harvesting takes 30 ticks and
produces one Grain, which the farmer carries to the Farm. The plot becomes
empty and can be sown again. Carriers move the Farm's grain onward.

Vine plots belong to nearby Vineyards. They grow for 160 ticks, are harvested
by a farmer in 30 ticks and regrow after harvesting. The vineyard branch
abstracts grape pressing into the harvest/delivery operation and delivers
Wine; grapes are not a separate ware. Field growth continues independently
of workers. Wheat and vine plots remain walkable and do not turn into trails.
They cannot overlap buildings, trees, deposits, roads, trails or entrances.

Lumberjacks cut mature trees and carry logs to a Lumberjack Hut. Gardeners
choose reachable free planting sites within eight tiles of their own Forester
Hut without a player target, reserve them
exclusively, plant a sapling and wait before planting again. Trees mature
through the existing sapling/young/adult stages.

Stone, Iron Ore and Gold Ore deposits occupy rock; Coal deposits occupy grass
or dirt; fish stocks occupy water. Extraction buildings need a matching,
nonempty deposit in their catalog radius and a reachable work position.
Stonemasons, miners and fishermen travel to the deposit or its accessible
edge/bank, complete an exclusive harvesting task, subtract exactly one finite
unit and carry that ware to a compatible home building. Carriers take over
between buildings. Exhausted deposits stop generating work. This replaces the
v6 quarry's unlimited internal stone cycle.

## Processing recipes

Every row is a complete batch. Timings are prototype balance values at
10 simulation ticks per second; travel, staff availability and carrier waits
add to the total elapsed time.

| Building | Inputs | Outputs | Work ticks |
|---|---|---|---|
| Sawmill | 1 Logs | 2 Planks | 60 |
| Mill | 1 Grain | 1 Flour | 80 |
| Bakery | 1 Flour | 2 Bread | 100 |
| Iron Smithy | 1 Iron Ore + 1 Coal | 1 Iron | 100 |
| Metallurgist | 1 Gold Ore + 1 Coal | 2 Gold | 100 |
| Swine Farm | 4 Grain | 1 Pigs + 1 Raw Skins | 240 |
| Butcher | 1 Pigs | 3 Sausages | 100 |
| Tannery | 1 Raw Skins | 2 Leather | 100 |
| Stables | 4 Grain | 1 Horses | 240 |
| Weapon Workshop | 2 Planks | 1 Axes | 100 |
| Weapon Workshop | 2 Planks | 1 Lances | 100 |
| Weapon Workshop | 2 Planks | 1 Bows | 100 |
| Armour Workshop | 1 Planks | 1 Wooden Shields | 100 |
| Armour Workshop | 1 Leather | 1 Leather Armour | 100 |
| Weapon Smithy | 1 Iron + 1 Coal | 1 Swords | 120 |
| Weapon Smithy | 1 Iron + 1 Coal | 1 Pikes | 120 |
| Weapon Smithy | 1 Iron + 1 Coal | 1 Crossbows | 120 |
| Armour Smithy | 1 Iron + 1 Coal | 1 Iron Shields | 120 |
| Armour Smithy | 1 Iron + 1 Coal | 1 Iron Armour | 120 |

A required specialist must reach the building before processing. Input wares
are consumed once at batch start; a saved active batch retains its countdown.
New batches wait for ingredients, staff and output room. Most producers use
four units of input capacity and six of output capacity; service buildings
have their own catalog limits. Incoming carrier cargo and reserved harvests
are accounted for before another delivery or harvest is accepted.

Weapon and armour workshops require player orders. Each button queues a
recipe; FIFO order controls which output is produced next. A workshop with no
orders does not repeatedly manufacture its default recipe. Warehouses can
redistribute stored ingredients to new consumers, construction sites and
services. Carrier destinations prefer compatible demand before storage and
use route cost plus current/incoming supply to spread deliveries.

Swine Farms and Stables use **one aggregate four-grain batch** per animal.
This reproduces the total feed-to-output relationship, including the pig's
raw skin, but does not simulate KaM's individual animals and four feeding/age
stages. Raw skin comes from the Swine Farm, not the Butcher.

## Construction, school, food and services

### Construction

With the expanded economy enabled, placing a building creates a blocked
one-tile construction site with an entrance. Carriers deliver the catalog's
Plank/Stone requirements to `construction_delivered`; a Builder then works
through `construction_ticks`. Production, training and services wait until
completion. The inspector shows missing materials and progress, and the map
shows scaffolding.

**Stone roads and vine plots are deliberate exceptions:** one Stone per road
or one Plank per vine plot is deducted directly from completed warehouse
stock and the tile appears immediately. They do not yet have physical
material-delivery/build tasks. Wheat preparation has no ware cost.

The authored demo's buildings are already complete before the full economy
is enabled. Later player buildings use the construction flow.

### School and tree planting

The School trains 15 civilian professions: Carrier, Lumberjack, Gardener,
Farmer, Baker, Stonemason, Miner, Metallurgist, Smith, Butcher, Animal Breeder,
Fisherman, Carpenter, Builder and Recruit. Each costs one Gold delivered to the
School. A queued order waits for payment, pays once, then advances its training
timer. A finished worker waits safely for a free exit. The paid flag and exact
remaining time survive saves, preventing duplicate payment after loading.

The Sawmill employs a Carpenter. Mills and Bakeries both employ Bakers.
Since 2026-09-05 each producer has exactly one specialist slot: each Mill and
Bakery needs a different Baker. Newly trained citizens claim a compatible
vacant building, or wait if all are occupied. Employment persists through
batch completion, full/empty buffers, blocked routes and meals; carriers and
builders still serve the whole settlement. The inspector exposes the owner
and 0/1 or 1/1 occupancy. Save v10 preserves this association and normalizes
older shared homes without losing people or carried wares.
Gardener/forester is a prototype extension, not an extra original KaM
profession; the School description and gardener icon explain its role.

### Food

Workers have a condition value up to 2700, initially 1620. It decreases on
fixed simulation ticks, one point per 10 ticks. At 360 or below, an idle worker
without cargo looks for a reachable completed Inn with food. Carriers supply
Bread, Sausages, Wine and Fish. A visit consumes up to two available food types
in catalog order, restoring condition up to the configured maximum. A worker
whose condition reaches zero starves and is removed with reservations released.
Housing and residential needs are not simulated; the Workers' Cottage was
removed with the day/night cycle on 2026-09-14.

### Marketplace

The Marketplace queues explicit give/receive pairs. Its quote comes from
`resources.json` market prices, the 2.2 trade-off factor and special rates in
`economy.json`; for example, the reference exception exchanges 3 Logs for
1 Gold Ore. The UI displays the actual integer quote from the simulation.
Carriers bring payment, the service waits for enough input and output room,
and received wares become a physical output for collection. No separate
processing timer is applied to a ready exchange.

### Military economy

Barracks accept Recruits trained at School plus the selected unit's equipment.
The Recruit walks to the Barracks; once present with the required delivered
wares, the service consumes equipment and changes that same worker into the
military type. Town Halls instead consume the corresponding gold payment and
spawn a unit when an exit is free. Queues and requirements are data driven.

There is **no additional recruitment countdown** once these requirements are
ready. The military catalog's `training_ticks` field is not an active service
timer. The tooltip describes the actual instant-on-ready behavior.

The 14 recruitment definitions cover the current Barracks/Town Hall choices.
Soldiers are economic end products: **combat, player military move orders,
formations, enemy AI, siege engines and projectiles are not implemented**.
An unassigned Recruit can occupy an empty Watchtower when Barracks orders
do not require that recruit. The guard keeps its post, can visit an Inn and
return, and its assignment survives saves. The Watchtower accepts Stone as
ammunition stock; without combat it does not fire or consume ammunition.

## UI and starting village

The left 390-pixel panel has Infrastructure/Food/Mining/Military building
categories and independent scrolling for the build menu and selected-building
inspector. School training, production orders, recruitment and trading appear
inside that inspector. School help remains visible above the menu. Existing
shortcuts 1–9 and wheat-field shortcut 0 remain; vine plots use the Food menu.

The All stocks popup groups all 28 wares into Materials/Food/Equipment. Its
480-pixel panel uses five columns so every ware in a category fits without
scrolling at the minimum window size. Main numbers show total settlement stock;
each ware also lists warehouse, building and carried quantities separately.
Consumed recipe inputs and committed construction deliveries are excluded.
Every ware has an original procedural icon. Fields, deposits, scaffolds, specialist marks and
building motifs are drawn from authoritative state; visual animation does not
advance the simulation.

`setup_economy_demo()` creates the authored village with all 29 building types
represented by 29 instances and 238 occupied building tiles, plus wheat/vine plots, the five kinds of finite resource
deposits, starter
food/material/gold stocks, specialists, carriers, builders, a gardener and a
recruit. Example equipment and recruitment orders are queued. The older
`setup_demo()` remains a compact compatibility/invariant fixture.

## Save format and compatibility

Version **7** adds finite deposits, field `kind` (`wheat`/`vine`), the
`economy_enabled` flag, worker condition, construction progress and delivered
materials, paid-school-training state, selected recipe, production queue and
active-order state, and market/recruitment service queues. Entity and field
collections serialize in canonical ID order. A carried ware and its compatible
home can resume delivery after loading.

`WorldSnapshot` validates the complete staged world before replacing live
state, including finite deposit stock/terrain, field ages, construction
quantities, queue types/recipes, inventories, condition, shared entity IDs,
references and occupancy. Tasks, paths and temporary reservations are rebuilt.
The format supports versions 1–6 through explicit defaults/migration; old saves
do not invent fields or deposits, old fields become wheat, existing buildings
are complete and advanced costs/needs remain disabled for compatibility.
Legacy snapshots still use the current catalog's recipes and professions.

## Scope and provenance boundaries

- The economic graph and material relationships use the inspected KaM Remake
  source. All production/extraction/field/construction timings remain the
  prototype's own balance. As of 2026-09-05, building material costs follow the
  [documented KaM table](construction-costs.md), with old saved sites retaining
  their historical material price under save v9.
- Animal development is an aggregate recipe; vine processing is folded into
  harvesting; roads/vines use immediate warehouse payment.
- No KaM unlock tree, demolition, terrain-deformation mining, broad household
  economy, siege workshop or original campaign is included. Exhausted deposits
  remain visible; terrain does not erode.
- Economic recruitment is available, combat is not. A ready recruit/trade is
  resolved by the next simulation service update, with no separate duration.
- Gardeners are an original forestry extension. All graphics are original
  procedural placeholders. No original game data or Delphi code is imported.

## Reference and evidence

The source reference is the public
[reyandme/kam_remake repository](https://github.com/reyandme/kam_remake) at
commit `a3b3e5268e1475460e4561f9143df6f1a532e681` (2026-08-23).
The local read-only checkout was inspected on 2026-09-05 at
`reference/kam_remake/`; its working tree was clean and its configured origin
matched that repository. This records the inspected revision, not a claim that
it is the latest remote revision.

The following line references are relative to that checkout and commit:

| Evidence | Source |
|---|---|
| House input/output types and unlock relationships | `src/res/KM_ResHouses.pas:234` |
| Farm produces grain | `src/res/KM_ResHouses.pas:301` |
| Mill consumes grain and produces flour | `src/res/KM_ResHouses.pas:389` |
| Bakery consumes flour and produces bread | `src/res/KM_ResHouses.pas:257` |
| Quarry produces stone | `src/res/KM_ResHouses.pas:400` |
| Farmer performs separate sowing and harvesting work | `src/units/KM_UnitWorkPlan.pas:350` |
| Baker serves mill and bakery; each consumes one input ware | `src/units/KM_UnitWorkPlan.pas:452` |
| Stonemason finds stone and walks to work there | `src/units/KM_UnitWorkPlan.pas:500` |
| Grain-to-flour 1:1 and flour-to-bread 1:2 ratios | `src/res/KM_ResWares.pas:297` |
| Trunk-to-timber 1:2 ratio | `src/res/KM_ResWares.pas:289` |
| Grain and vine growth stages | `src/res/KM_ResMapElements.pas:85` |
| Inn consumes food | `src/units/tasks/KM_UnitTaskGoEat.pas:135` |

The price formulas in `KM_ResWares.pas` corroborate material conversion ratios;
its production-rate table is an average measured on a test map, not a table of
work-cycle durations. `TKMUnitWorkPlan.ResourcePlan` takes output quantities
from each house's `ResProductionX` (`src/units/KM_UnitWorkPlan.pas:124`).
That field, original construction costs and other legacy house properties are
loaded from `data/defines/houses.dat` (`src/res/KM_ResHouses.pas:23`, `:799`,
`:902`). The file is absent from this source checkout. The prototype's one-ware extraction yield and work durations are chosen
balance values; they are not presented as verified original house-data values.
The current building catalog records construction-cost provenance explicitly.

For broader architecture and provenance, see
[reference-analysis.md](reference-analysis.md) and
[reference-map.md](reference-map.md).

## Milestone history and remaining roadmap

- **2026-08-23 to 2026-09-04:** wood chain, terrain, gardener/tree growth,
  school and movement/save/UI fixes; snapshot versions 1–5.
- **2026-09-05, first expansion:** quarry/farm/mill/bakery, separate wheat
  fields and six civilian professions; snapshot version 6. The earlier
  four-building release passed 67 tests. Its unlimited quarry, free
  construction/training and absent food demand are historical behavior.
- **2026-09-05, current expansion:** the broader production graph, finite
  deposits, construction, food, gold, trading and military equipment consumers;
  snapshot version 7. The Sawmill changes from the earlier prototype's 1:1
  conversion to 1 Log → 2 Planks.

The earlier roadmap's food, wine, fish, pigs, leather, horses, metals, gold,
weapons/armour, paid school, barracks, town hall, marketplace and material
construction branches are now implemented within the boundaries above.
Remaining work includes multi-tile/rotatable buildings, physical road/vine
construction, detailed per-animal feeding, unlock progression, richer warehouse
policies, broader housing and household consumption, combat/formations/projectiles, siege production, scenario
scripting and production art. The terrain/lockstep roadmap is retained in
[godot-architecture.md](godot-architecture.md) and the dated [handover](../HANDOVER.md).
