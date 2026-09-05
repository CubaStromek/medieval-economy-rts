# KaM Remake economic catalog

## Reference and scope

The catalog prepared on 2026-09-05 uses **KaM Remake**, at source commit
`a3b3e5268e1475460e4561f9143df6f1a532e681`, as its reference. The local checkout
is `reference/kam_remake`, with origin
[reyandme/kam_remake](https://github.com/reyandme/kam_remake). Source references
below refer to that fixed revision, not to an assumed current remote version.

The data now describes all **28 buildings offered by that revision's normal
building menu**, its **28 economic wares**, the civilian professions, all nine
barracks equipment combinations and the five town-hall recruitment costs.
The 28-building list is explicit in `src/gui/KM_InterfaceGame.pas:107–114`.
The legacy siege-workshop enum remains in the source, but the building is absent
from that playable menu; siege production is therefore not included here.

This document supersedes the four-building scope recorded in
[economy-expansion.md](economy-expansion.md). It specifies the expanded catalog
and identifies which values are from source and which are project balance.
The catalog is not evidence of completed combat, enemy AI or identical original
animation and timing behavior. In particular, the watchtower's economic inputs
are a recruit and stone ammunition; no enemy/combat simulation is implied.

All art and implementation are original to this project. No proprietary game
assets or `houses.dat`/`units.dat` files are copied or distributed.

## Files and contracts

| File | Responsibility |
|---|---|
| `game/data/resources.json` | All 28 wares, display metadata, category, market value and food restoration |
| `game/data/buildings.json` | 28 reference buildings plus the project Forester Hut; inputs/outputs, professions, location requirements, recipe choices, capacities and construction costs |
| `game/data/recipes.json` | Material quantities and project work durations for 19 processing recipes |
| `game/data/units.json` | 15 civilian professions including the retained gardener, training times and compatible workplaces |
| `game/data/soldiers.json` | Nine barracks units and five town-hall units with economic recruitment requirements |
| `game/data/economy.json` | Flat global condition, food, market, field and road settings, plus provenance metadata |

Existing IDs are retained: `warehouse`, `lumber_hut`, `sawmill`, `school`,
`quarry`, `farm`, `mill`, `bakery`; and `log`, `plank`, `stone`, `grain`,
`flour`, `bread`. The gardener remains a separate trainable profession and
continues to replenish trees near its own Forester Hut. This additional hut and
forester role are project extensions; see [hut rules](forester-and-fisher-huts.md). KaM's
woodcutter normally combines tree cutting and planting.

Processing buildings define both `recipes: Array[String]` and `recipe` as the
first/default recipe. The four equipment workshops set `needs_order: true`.
Orders choose a recipe rather than consuming every ware listed in a building's
aggregate `inputs` array. For example, a wooden shield requires a plank; it does
not also consume leather simply because the armour workshop accepts both.

Gathering buildings use `extract_resource`, `extract_radius` and
`extract_amount`, with no processing recipe. Gathering consumes map deposits,
not an invented ingredient taken from a building inventory. Farms and vineyards
use `field_kind` and `field_radius` and receive the farmer's harvest.

Every unit has `home_buildings`, and school costs are declared in
`school.training_cost` and the matching unit `training_cost`. Soldiers are a
separate catalog: `building`, `equipment`, `requires_recruit` and
`training_ticks` describe their economic requirements. A recruit is a physical
citizen; it is not a ware delivered by a carrier.

## All production and service buildings

Quantities in this table are per completed material conversion. Ingredient and
product relationships are defined in `src/res/KM_ResHouses.pas:234–550` and
`src/units/KM_UnitWorkPlan.pas`. The source market-value formulas at
`src/res/KM_ResWares.pas:289–313` independently establish the conversion ratios.

| Building ID | Profession | Economic behavior |
|---|---|---|
| `warehouse` | Carrier service | Stores and redistributes all wares |
| `lumber_hut` | Lumberjack | Trees → logs; harvested logs return to the hut |
| `sawmill` | Carpenter | 1 log → 2 planks |
| `school` | Training service | 1 gold → 1 civilian of the selected profession |
| `quarry` | Stonemason | Finite stone deposit → stone |
| `farm` | Farmer | Sow and harvest wheat fields → grain |
| `mill` | Baker | 1 grain → 1 flour |
| `bakery` | Baker | 1 flour → 2 bread |
| `coal_mine` | Miner | Finite coal deposit → coal |
| `iron_mine` | Miner | Finite iron-ore deposit → iron ore |
| `gold_mine` | Miner | Finite gold-ore deposit → gold ore |
| `iron_smithy` | Metallurgist | 1 iron ore + 1 coal → 1 iron |
| `metallurgist` | Metallurgist | 1 gold ore + 1 coal → 2 gold |
| `vineyard` | Farmer | Vine fields → wine |
| `fisher_hut` | Fisherman | Finite fish stock in water → fish |
| `swine_farm` | Animal breeder | 4 grain → 1 pig + 1 raw skin |
| `butcher` | Butcher | 1 pig → 3 sausages |
| `tannery` | Butcher | 1 raw skin → 2 leather |
| `stables` | Animal breeder | 4 grain → 1 horse |
| `weapon_workshop` | Carpenter | 2 planks → 1 axe, lance or bow, selected by order |
| `armour_workshop` | Carpenter | 1 plank → 1 wooden shield, or 1 leather → 1 leather armour |
| `weapon_smithy` | Smith | 1 iron + 1 coal → 1 sword, pike or crossbow, selected by order |
| `armour_smithy` | Smith | 1 iron + 1 coal → 1 iron shield or iron armour |
| `inn` | Food service | Consumes delivered food to restore citizen condition |
| `barracks` | Recruitment service | One physical recruit + equipment → selected soldier |
| `marketplace` | Trading service | Exchanges delivered wares at the selected market ratio |
| `town_hall` | Recruitment service | Gold → selected auxiliary troop; no recruit required |
| `watchtower` | Recruit | Receives stone as ammunition stock |

The sawmill now uses the KaM **1:2** conversion and requires a carpenter.
The preceding prototype's **1:1** conversion is historical, not the current
catalog balance.

The same KaM profession serves multiple buildings. In particular, a baker
works in both mill and bakery; a butcher works in butcher and tannery; a
metallurgist works in both metal smelters; and a carpenter works in sawmill and
the two timber/leather equipment workshops. These mappings are explicit in
`src/gui/KM_InterfaceGame.pas:158–166` and their corresponding work plans.

The pig farm's two products are simultaneous: the raw skin does **not** come
from the butcher. In KaM, breeding spends one grain per feeding and increases
one animal's age; four feedings complete an animal
(`src/houses/KM_HouseSwineStable.pas:46–61`). The catalog records the aggregate
four-grain conversion in one timed recipe. Matching those material totals does
not reproduce KaM's five separately animated animal slots and random feeding
selection.

## Ware IDs

| Branch | IDs |
|---|---|
| Construction and wood | `log`, `plank`, `stone` |
| Mining and smelting | `coal`, `iron_ore`, `gold_ore`, `iron`, `gold` |
| Grain and food | `grain`, `flour`, `bread`, `wine`, `pig`, `sausage`, `fish` |
| Leather | `skin`, `leather` |
| Equipment | `wooden_shield`, `iron_shield`, `leather_armour`, `iron_armour`, `axe`, `sword`, `lance`, `pike`, `bow`, `crossbow`, `horse` |

`resources.category` is `materials`, `food` or `military` for inventory views.
`buildings.category` is `infrastructure`, `food`, `mining` or `military` for
construction views. `skin` means a raw hide and `leather` the processed product.
`iron_ore` and `gold_ore` are distinct from smelted `iron` and `gold`.
There is no separate grape ware in this reference: vineyards produce wine.

## Food and condition

`src/common/KM_Defaults.pas:380–397` establishes the Remake condition constants:

| Setting | Catalog value |
|---|---|
| Maximum condition | 2700 |
| Seek food below | 360 |
| Condition decrement interval | 10 simulation ticks |
| Initial condition | 1620, or 60% of maximum |
| Full-food threshold | 2430, or 90% of maximum |
| Bread restoration | 1080, or 40% |
| Sausage restoration | 1620, or 60% |
| Wine restoration | 810, or 30% |
| Fish restoration | 1350, or 50% |

The deterministic initial value omits Remake's ±10% random initial-condition
variation. The 30% wine restoration is specifically the Remake balance; the
source comment identifies original KaM wine as 20%.

The inn examines food in the order bread, sausage, wine, fish and permits up to
two different food servings per visit
(`src/units/tasks/KM_UnitTaskGoEat.pas:101–175`). Each serving consumes one ware.
Food restoration is capped by maximum condition. Merely storing food in a
warehouse does not feed a citizen; the inn must receive and serve it.

## Recruitment and equipment

The school consumes one gold for a completed training operation
(`src/houses/KM_HouseSchool.pas:255–276`). Its catalog includes carrier,
lumberjack, gardener, farmer, baker, stonemason, miner, metallurgist, smith,
butcher, animal breeder, fisherman, carpenter, builder and recruit.
The gardener is the intentional additional forestry profession.

Every barracks row below consumes **one recruit** and one of each listed ware.
Equipment combinations are copied as facts from
`src/res/KM_ResUnits.pas:168–177`; the recruit requirement and consumption are
explicit in `src/houses/KM_HouseBarracks.pas:331–371`.

| Soldier ID | Required equipment |
|---|---|
| `militia` | Axe |
| `axe_fighter` | Wooden shield, leather armour, axe |
| `sword_fighter` | Iron shield, iron armour, sword |
| `bowman` | Leather armour, bow |
| `crossbowman` | Iron armour, crossbow |
| `lance_carrier` | Leather armour, lance |
| `pikeman` | Iron armour, pike |
| `scout` | Wooden shield, leather armour, axe, horse |
| `knight` | Iron shield, iron armour, sword, horse |

Town-hall recruitment consumes gold directly and does not require a recruit:

| Soldier ID | Gold |
|---|---:|
| `rebel` | 2 |
| `rogue` | 3 |
| `vagabond` | 5 |
| `barbarian` | 8 |
| `warrior` | 8 |

These values are `TH_DEFAULT_TROOP_COST` in `src/res/KM_ResUnits.pas:215–216`.
The gold-consuming recruitment implementation is
`src/houses/KM_HouseTownHall.pas:113–161`. Soldier costs describe the economic
output; they do not provide unimplemented combat statistics or behavior.

## Market values and rounding

Each ware's `market_price` is calculated from the reference's measured
`PRODUCTION_RATE` table and `CalculateMarketPrice` formulas in
`src/res/KM_ResWares.pas:85–93` and `:278–314`. The rates are preserved as
`reference_production_per_minute` metadata. They are average test-map
throughputs, not timers to use for individual production actions.

The formulas add upstream input values, with nonrenewable-resource and
land-use adjustments. `market_tradeoff_factor` is **2.2**, from
`src/res/KM_ResWares.pas:51`. For source and destination values `S` and `D`:

```text
adjusted destination = D × 2.2
base = min(S, adjusted destination)
wares given = round(adjusted destination / base)
wares received = round(S / base)
```

This is the pair of calculations in `src/houses/KM_HouseMarket.pas:134–166`.
The reference's explicit exception is **3 logs → 1 gold ore**
(`:140–144`), stored in `market_special_rates`. Quotes must use both integer
quantities; comparing only unadjusted prices would permit incorrect trades.
The checked-in decimal values are calculated from the source formulas and
rounded to ten decimal places; they are not extracted binary single-precision
values from a running KaM installation.

## Construction, fields and selected project values

The reference construction task requests one stone for a road tile and one
plank for a vine-field tile (`src/units/tasks/KM_UnitTaskBuild.pas:241`, `:388`).
Ordinary wheat fields have no material recipe; creating and sowing a plot still
involves work. Building construction requests each house's timber and stone
costs at `:637–638`.

Building material costs were verified on **2026-09-05** against published
KaM manuals and the explicit Remake marketplace override. The complete
[construction cost table](construction-costs.md) covers all 28 buildings,
including source URLs and printed manual pages. Twenty-six costs have manual
evidence; the warehouse's **6 planks + 5 stone** is explicitly identified as a
secondary community reference because the inspected manuals omit its cost.
The marketplace retains the source override of **5 planks + 6 stone**
(`src/res/KM_ResHouses.pas:822–823`). The catalog records these distinctions in
`construction_cost_source` and `construction_cost_reference`.

The lumberjack hut and quarry both require **3 planks + 2 stone** in KaM,
and the sawmill requires **4 planks + 3 stone**. A scenario needs initial
construction supplies or existing producers to bootstrap those buildings;
making their construction stone-free would be a separate project rule.

Most original house costs, base work-animation durations and per-house output
multipliers are stored in `data/defines/houses.dat`. That binary is absent from
the inspected source checkout. The loader and packed record are in
`src/res/KM_ResHouses.pas:23–41`, `:799` and `:902–920`. The cost table is now
independently documented from published sources, but unavailable animation and
timing values must still not be presented as verified original timings.

Other project balance settings are construction work of 120 ticks, gathering
work of 100 ticks, an extraction radius of 3, crop radius of 8, wheat growth of
200 ticks, vine growth of 160 ticks, and the recipe and training timers in their
JSON files. Wheat sowing takes 20 ticks and harvest takes 30 ticks. Breeding
uses an aggregate 240-tick recipe for four grain. These timings make the
prototype reviewable; they are not claimed as original KaM timings.

Normal input/output capacities are currently four/six, with larger dedicated
service inventories. KaM's general `MAX_WARES_IN_HOUSE` constant is five
(`src/common/KM_Defaults.pas:310`), so the prototype limits are also explicit
balance choices. The grain and equipment conversion ratios, food restoration,
school gold cost, recruit equipment and town-hall gold costs above are the
source-backed economic relationships rather than those tuning choices.
