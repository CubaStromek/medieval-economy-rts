# Medieval Economy RTS

An open-source, fan-made economy RTS prototype built from scratch with Godot
4.7 and typed GDScript. It is inspired by the economic simulation style of
classic medieval strategy games and uses the public KaM Remake source as a
technical reference for responsibilities and invariants.

This is not an official Knights and Merchants product. No original game code,
graphics, audio, maps or campaigns are distributed with the public source.
Optional, user-selected map data stays in ignored external directories.

## Current handover — 2026-09-12

Start with [HANDOVER.md](HANDOVER.md) for the current implementation, decisions,
known limits, artwork acceptance status and next steps. The previous handover
is preserved as history, not current requirements.

This milestone includes painted V1 terrain, fog of war, seven-day nutrition,
individual work pause and the normal-game PixelLab
lumberjack (three activities × eight directions, 439 animation frames).
The lumber hut has 33 construction steps, visible 0–6 stored logs, and a
new nine-cell footprint; old saved huts retain their old geometry. Current
save format is **v23**. The 11 September refactor improves HUD aggregation and
transport availability checks without changing actual destination ranking.
The 12 September work rebuilt the HUD in Czech. On **14 September** the whole
day/night cycle was removed, including sleep, the Workers' Cottage, night
wolves, map tinting and moving sun shadows; see
[the removal notes](#daynight-cycle-removed--2026-09-14). The same day,
route searching moved to a packed index with identical routes: simulation
ticks on the player's save are about 5× cheaper and no longer spike above
16 ms; see [pathfinding performance](docs/pathfinding-performance.md).
Placeholder buildings now keep retained drawing and cached geometry, roughly
halving map frame time in the economy demo with pixel-identical captures; see
[render performance](docs/render-performance.md#retained-building-layers--2026-09-14).

Fresh Godot 4.7.2 checks after the day/night removal, pathfinding index and
retained building layers (2026-09-14): **782/782 headless**; the earlier **85/85 native rendering checks** were not rerun. The [publication verification](docs/release-verification-2026-09-12.md)
is a dated record of the earlier v21 publication pass, so its own counts are
historical; use it for commands, tool tests and clean-checkout status.
Historical test counts in the feature sections below describe their original
milestones.

Runtime assets live in `game/art/`; `docs/art/` also retains original project
concepts, rejected experiments and QA evidence. They are not all loaded by the
game or approved as an art-style reference. Original KaM data, API transport
logs, caches, local ZIP deliveries and a reproducible Blender QA scene remain
excluded from Git; see [publication scope](HANDOVER.md#8-co-se-publikuje-a-co-zůstává-lokální).

## Painted lumber hut construction — 2026-09-10

The normal game now draws the Lumberjack Hut with its own transparent artwork
and **12 timber + 21 finishing steps**, matching the counts measured in the
original KaM graphics. Place a Lumberjack Hut through **Stavět** or shortcut
**3**; after ground preparation and material delivery, actual Builder work
reveals the structure. This is enabled automatically on current footprints,
including existing saved construction, with unchanged costs and duration.
Historical one-cell footprints retain their compatible old appearance.

All stages share the same door and a separate stable depth point, so the next
grass row no longer erases the front of the house. The normal menu, starter
maps and loaded games use this renderer. See the
[in-game animation and QA](docs/art/qa/lumber-hut-construction-v1/README.md)
for verified behavior and the pilot's remaining slope-contact art calibration.

Future objects follow the [shared implementation workflow](docs/art/object-implementation-workflow.md),
with a reusable [integration record](docs/art/object-integration-template.md)
and [QA checklist](docs/art/object-qa-template.md). `AGENTS.md` makes these the
starting point for subsequent object work; building style remains governed
by the existing art guide.

## Unit thoughts and individual work pause — 2026-09-07

Select a citizen to see **Co si myslím**: short Czech first-person descriptions
of what they are doing now and what comes next. Pause/resume that unit's work,
or independently pause a building's operation or construction. Food and
safe movement continue; already-carried goods and paid work are preserved.
Save **v20** remembers each unit and building's separate setting. See
[controls, exact pause rules and compatibility](docs/unit-thoughts-and-pause.md).

## Fog of war — 2026-09-07

New games reveal only the surroundings of your settlement. Unexplored ground
is black; discovered ground remains visible, slightly darkened when outside
current sight. Foreign units disappear completely outside your vision.
Citizens and completed buildings provide sight; Watchtowers see farther.
Exploration survives saving/loading, and old saves retain knowledge of their
formerly visible map. See [rules, ownership and rendering](docs/fog-of-war.md).

## Graphics sandbox — 2026-09-07

Choose **Grafický sandbox** in the main menu. **Hlavní menu / Esc** returns
from the sandbox; an existing game remains paused and can be continued.
You can also open `Graphics Sandbox.command` on macOS, or run
`godot --path game res://scenes/terrain_graphics_sandbox.tscn`.
The isolated workbench compares the same two small terrain crops with today's
prototype or a fixed source-informed reference. Toggle textures and lighting,
adjust relief, zoom/pan, inspect tiles, and save local presets and screenshots.
Optional prototype trees, contact shadows, object markers and a grid are
explicitly experimental, not original KaM object graphics.

The public checkout contains the renderer, controls and synthetic tests, but
**not the original texture atlas or map crops**. Without local external data it
shows setup guidance; the normal game still runs independently. Water is static.
See [setup, controls, provenance and limitations](docs/terrain-graphics-sandbox.md).

## Mountainous Region starter map — 2026-09-07

An optional scene recreates the original map's layout and heights using our
terrain materials and trees. Choose **Nová hra · vybrat mapu → Mountainous Region
→ Spustit mapu** from the main menu. On macOS, you can also double-click `Mountainous Region.command`.
Or open `game/scenes/mountainous_region.tscn` and run that scene, or use `godot --path game res://scenes/mountainous_region.tscn`.
It contains the full source landscape (143 × 127 playable cells, 341 trees),
plus a playable start on the northeastern plateau: a completed **Warehouse and
School**, no citizens or roads, **50 gold**, and **20 each of logs, planks and
stone**. One gold is already inside the School so the first Carrier can be
trained; the other 49 and all materials are stored in the Warehouse. The normal
starter scene is unchanged, and the landscape uses its own save slot.

Original and converted map data remain local, external and ignored by Git.
See [setup, provenance and limitations](docs/mountainous-region.md).

## Main menu — 2026-09-07

The game now opens a simple Czech main menu. **Nová hra · vybrat mapu** offers four
maps: **Nová osada** (28 × 22, Warehouse and School), **Osídlené údolí**
(28 × 22, populated relief village), **Ekonomická ukázka** (34 × 30,
the complete production town), and **Mountainous Region** (143 × 127,
the locally imported mountain landscape with a starter settlement).
Select a map and press **Spustit mapu**. A missing or invalid Mountainous Region
import leaves the menu and current game intact.
**Načíst hru** opens the saved game, or offers a choice when both the ordinary
and Mountainous Region slots exist; it is unavailable before the first save.
A missing or invalid save displays an error and retains the current session.
**Grafický sandbox** opens the existing terrain workbench, with its own settings.

During play, **Menu / Esc** pauses the entire game and offers **Pokračovat ve
hře** and **Uložit hru**. Escape first cancels an active building tool or closes
an open HUD panel. Returning from the menu preserves the previous game speed.
**F5 / F9** save/load the current game's slot; Mountainous Region retains its
separate slot both in the menu and its standalone launcher. New saves remember the chosen
map for **R** (restart); old saves load normally and retain the former starter
map reset behavior. Starting a new map replaces the current session but does
not overwrite the saved game. The demo launch flags still start directly;
`--mountainous-region` and `--graphics-sandbox` also work through the main entry.

## Builder ground preparation — 2026-09-06

Buildings can now be placed on gently uneven ground. A gold preview shows
the required preparation. A physical **Builder first levels the whole
foundation**, then Carriers deliver materials and ordinary construction begins.
Steep slopes, mountains and protected neighboring objects remain unavailable.
Earthwork progress survives saves; cancelling a site keeps soil already moved.
The current map shape is unchanged. See [rules and verification](docs/foundation-preparation.md).

## Building footprints — 2026-09-06

New buildings now occupy their KaM Remake tile shapes: for example a Warehouse
is **3 × 3**, a Lumberjack Hut **3 × 2**, a Sawmill **4 × 2** and Barracks
**4 × 4**. All 28 reference types plus the Forester Hut
have their own masks,
including irregular corners and fixed southern doors. The building preview
shows the full area and a blue entrance tile. Citizens walk around the entire
building, and its foundation, roof and scaffolding follow the same footprint.

Build on level or safely preparable ground and leave the front entrance accessible. Existing saved
buildings keep their previous one-tile size; newly placed ones use full masks.
Save **v17** preserves both, including new ground-preparation progress. See [geometry, reference and compatibility](docs/building-footprints.md).

## Civilian Inns and army food supplies — updated 2026-09-07

Build an **Inn** under **Food** and keep it supplied with Bread, Sausages, Wine
or Fish. Hungry civilians eat there automatically, occupying one of six seats,
then leave and return to their own work. Specialists retain their workplaces.
Satiety is visible above outdoor units and in their details. Hunger declines at a
steady rate: a full civilian needs food again after about 10 minutes at 1×
(6,000 ticks). Diners remain
hidden inside while eating up to three different courses; bread, wine and fish
fill them more than a single food, with nutrition increasing during each course.

An empty satiety bar is **not an immediate death sentence**. New units start
fully fed; a separate long-term reserve allows **70 minutes without
food** at 1× (35 at 2×), counted by the balance data as seven 10-minute days.
After two days of nutritional deficit, productive work
gradually falls to a minimum of 80% by day four; walking never slows. Paid meals
rebuild the reserve proportionally and restore strength gradually, rather than
resetting seven days with one bite. Save v19 preserves the exact remaining
reserve and fractional progress; older games keep their satiety and stocks
and start with a fresh reserve because they recorded no deprivation history.

Soldiers receive food at their posts. Click a soldier and choose **Supply food**,
or use **Military → Supply army**. Below 55% condition, a Carrier reserves and
collects one real ration from a Warehouse or food producer and delivers it to
the soldier. Each ration fully feeds one soldier; orders remain pending when
supplies are unavailable. Saves preserve partial courses and military deliveries
without double consumption. See [food and military supply rules](docs/food-and-military-supply.md).

## Day/night cycle removed — 2026-09-14

The complete day/night mechanic has been removed at the user's request.
There is no calendar clock, sky display, map tinting or moving sun shadow,
and civilians no longer stop work at night or go to sleep. The Workers'
Cottage (which only provided beds) and the night wolves (which only existed
between dusk and dawn) were removed with it. Small fixed ground shadows under
trees and units remain; cast shadows are not drawn for now.

Simulation time still advances in 0.1-second ticks. Satiety declines at a
constant 390 milli-points per tick, the same daily food demand as the former
awake/asleep average; the seven-day nutrition reserve is shown in minutes at
1×. Save format **v23** stops writing sleeping places and wolves. Older saves
still load: their sleep and wolf data are ignored, and any Workers' Cottage is
dropped (its materials are not refunded) while former residents move to the
nearest free outdoor cell. The historical design notes remain in
[day/night analysis](docs/day-night-analysis.md),
[night wolves](docs/night-wolves.md) and [worker housing](docs/worker-housing.md).

## Adaptive game window — 2026-09-05

Standalone play starts maximized on the current monitor. The 1152 × 720 base
is a logical UI design size, not a fixed physical window: the viewport expands
to the available aspect ratio, without letterboxing or stretching the artwork.
The HUD follows the window edges and grows more slowly than the window, so a
larger monitor buys visible map rather than larger panels: roughly 1.2x at
1080p and 1.4x at 1440p instead of the raw 1.5x / 2.0x stretch. The initial map
overview refits on resize; after manually panning or zooming, resizing
preserves the chosen camera view.
Explicit `--windowed` / `--resolution` launch options remain available.

Godot's embedded Game view has its own sizing policy. In its top-right **⋮**
menu choose **Stretch to Fit** (configured for this local project). This is
stored as `[game_view] embed_size_mode=2` in local editor metadata, not in Git;
choose it again in a fresh checkout or after clearing `.godot`. The Windowed
editor override permits embedding; a normal standalone/editor-binary launch
still maximizes. See [Godot's embedded window sizing documentation](https://docs.godotengine.org/en/latest/tutorials/editor/game_embedding.html#embedded-window-sizing).

## Natural trails reward sustained traffic — 2026-09-05

A dirt trail now needs **36 retained carrier passes**, not four historical
footsteps. Weak wear loses one pass every 20 game seconds. Established trails
decay more slowly and keep their speed benefit down to 16 retained passes, so
maintaining a busy route is easier than creating one. The first three footsteps
are invisible; later traces gradually strengthen. Idle sidesteps do not count.

Natural dirt connections remember the directions actually walked. Nearby muddy
tiles no longer invent extra branches or diagonal crossings, and an untrampled
entry does not receive the trail speed bonus. Stone roads remain permanent and
fastest. Pausing the game also pauses regrowth; changes stay in local surface
layers without rebuilding the base map.

Save **v11 and later** preserves wear, direction and aging. Old saves keep their existing
roads and trails, which subsequently regrow if abandoned; no reset or inventory
change is required. See [natural trail rules](docs/natural-trails.md).

## Eight-way movement and yielding — 2026-09-05

Units travel in all eight directions. Diagonal steps take proportionally more
time: grass is 9 ticks, dirt trail 6 and stone road 3, versus 6/4/2 for straight
steps. Both sides of a corner must be clear, including terrain and other units.
Carriers wear continuous diagonal dirt trails; stone and mixed surfaces connect
diagonally too. Surface updates remain local and do not redraw the base map.

An idle, empty-handed citizen blocking a route can step into a free off-route
pocket. The move is interpolated, keeps their workplace assignment, and reserves
the old tile until they visibly clear it. Busy workers and posted tower guards
are not displaced. A short rest prevents repeated back-and-forth sidesteps.
Without a safe pocket, route selection keeps the obstacle and considers another
route or destination; it waits safely if none is available. Existing saves work.

## One specialist per workplace — 2026-09-05

Every completed production building has one permanent specialist slot. A
Lumberjack owns one Hut; that Hut cannot be used by a second Lumberjack.
The same rule applies to other producers: a Mill and Bakery each need their
own Baker, and different mines each need their own Miner.

New specialists choose the nearest reachable vacant compatible workplace.
If there is none, they wait until one is completed or becomes vacant. Empty
inputs, full output, a blocked route, completed work or an Inn visit never
change the assignment. Extra trained citizens are not deleted or charged
again. Carriers and Builders remain communal; Inn/School/Warehouse
visits are not ownership. Tower guards retain one exclusive tower post.

Building details show **0/1** or **1/1** and the assigned worker's ID. Save
v10 and later preserve those assignments; older shared claims migrate deterministically
without losing citizens or carried wares. No reset is required to use this rule.

Gardeners now own a **Forester Hut** (Infrastructure, 3 planks + 2 stone) and
plant only within eight tiles of it. **Fisherman's Hut** is under Food
(4 planks + 3 stone), owns one Fisherman and requires reachable fish nearby.
Train either profession at a School; huts do not supply free citizens.
See [forester and fisher huts](docs/forester-and-fisher-huts.md).

## Workers inside buildings — 2026-09-05

Workers disappear from the map only after actually entering a completed
building. Indoor operators stay inside between production batches; outdoor
specialists reappear when they leave their hut for another job. Hidden workers
do not reserve the doorway. If somebody is standing outside, an exiting worker
waits for room without overlapping or displacing their tile reservation.
Field work, planting, harvesting and construction remain visible.

Building details identify residents currently inside; citizen totals still
include them. Save **v12** preserves indoor visits separately from permanent
workplace ownership. Earlier saves load with their citizens outdoors and
continue normally, without requiring a new game.

## Minimal test level — 2026-09-05

The **Nová osada** map opens the 28 × 22 relief landscape with only a completed
**Warehouse and School**, no citizens or roads, **20 logs, 20 planks and
20 stone in the Warehouse**, and **50 gold total**. The Warehouse holds 49 gold
and one is already in the School. Select the School and **Train Carrier** first
so that citizen can deliver the remaining gold, then train a **Builder**. Place a Lumberjack Hut,
Sawmill and Quarry, then train their Lumberjack, Carpenter and Stonemason.
The western foot of the ridge contains two reachable stone deposits; place
the Quarry close to them. The southwestern pond also has two finite fish
deposits for a Fisherman's Hut on its bank. All other starting stocks are zero.

Construction uses finished **planks**, not raw **logs**. The original KaM
Lumberjack Hut and Quarry each cost **3 planks + 2 stone**, and the Sawmill
costs **4 + 3**. Starter supplies cover all three, an Inn and a reserve;
their quantities are this prototype's scenario balance, not a claimed universal
KaM starting inventory. All 28 reference prices and the project-balanced price
of the Forester Hut are listed in
[construction costs](docs/construction-costs.md). Materials still require
physical carrier deliveries before a Builder can finish a site.

New games/reset receive the corrected supplies and deposits. Existing saves
keep their inventories and the prices already agreed for older construction
sites; loading never grants free materials. **R** discards current progress
and restarts this level, so save any progress you want to retain first.

The populated terrain village remains available with
`godot --path game -- --relief-demo`; the full economy village uses
`godot --path game -- --economy-demo`.

## Retained terrain rendering — 2026-09-05

Static terrain is retained between frames, with separate locally updated
road/wear surfaces. Dynamic objects keep their original foreground/hill
occlusion. On the development Mac M4, the default relief scene improved from
8–10 FPS to roughly 86–90 FPS without simplifying the artwork. See
[performance measurements and reproduction](docs/render-performance.md).

## Square cells and readable slopes — 2026-09-05

Ground cells now use **40 × 40** drawing units. Height remains 8 vertical
pixels per stored level; this is a view-only change, not terrain flattening.

Normal terrain uses surface-following height cues to distinguish slopes from
flat plateaus. Selecting a building or field tool automatically marks unsuitable
slopes; a live placement outline and reason explain the tile under the pointer
before a click. Roads remain usable on gentle slopes. Manual F2 terrain rules
stay independent of the temporary building aid.

See [square terrain and slope feedback](docs/square-terrain.md).

## Basic roads and trees — 2026-09-05

Stone roads now use original painted cobbles with earthy shoulders, connected
corners and junctions. Dirt trails have softer, worn edges. All road surfaces
continue to conform to the shared-corner terrain relief.

Trees use nine transparent sprites: oak, beech and spruce appearances, each
with sapling, young and mature stages. Species are stable visual variants of
the existing generic tree; growth, timber yield, movement and saves are unchanged.
See [environment artwork and prompts](game/art/environment/README.md).

## Basic unit sprites — 2026-09-05

All **15 civilian professions and 14 military types** now have original
transparent raster sprites, including the three mounted types. Clothing and
tools replace the previous circle-and-letter bodies. Subtle movement,
horizontal facing, ground shadows, carried goods and hunger marks remain
presentation-only and leave simulation/save data unchanged.

This is one basic pose per type, not a complete directional animation set.
See [the sprite assets and generation prompts](game/art/units/README.md).
An in-engine contact sheet can be regenerated with
`godot --path game --script res://tools/preview_unit_sprites.gd -- --output=/absolute/path/units.jpg`.

## Terrain relief prototype — 2026-09-05

The `--relief-demo` option opens a **28 × 22 relief village**: an elevated meadow,
a walkable road up to its sawmill, and an impassable rocky ridge with a low pass.
Use **Terrain / F2** to reveal terrain rules; select ground for height/slope
details. Buildings need flat ground, including on raised plateaus.
The original full economy village remains available with
`godot --path game -- --economy-demo`.

This is the first fixed-view 2.5D terrain milestone with basic painted
units, trees and road material; other terrain/building art remains provisional. See [terrain-relief.md](docs/terrain-relief.md)
for controls, shared height rules, rendering and compatibility.

## Economy milestone — 2026-09-05

The economy demo now exercises **30 building types in 35 completed instances,
259 occupied building tiles, 28 wares, 15 civilian professions and 14 military
equipment/recruitment types**. It
contains the wood, bread, wine, fishing, livestock, leather, iron, gold,
weapons and armour branches of the KaM-style economy.

- Specialists harvest finite stone, coal, iron-ore, gold-ore and fish deposits
  from reachable work positions, then carry the yield to their home building.
  Carriers handle deliveries between buildings and warehouse redistribution.
- Farmers sow, grow and harvest player-placed wheat fields. Vine fields regrow
  after harvest. Gardeners are the prototype's autonomous foresters: they plant
  saplings near their own Forester Hut, and lumberjacks cut only mature trees.
- Recipe inputs, output buffers and incoming deliveries are bounded. The
  sawmill now yields 2 planks per log; grain becomes flour and then 2 bread.
  Workshops accept FIFO orders for alternative weapons and armour recipes.
- New building sites receive construction materials from carriers, then a
  builder completes the work. Schools consume gold and train citizens in FIFO
  order, waiting safely when their exit is blocked.
- Hungry workers seek a supplied inn and consume bread, sausages, wine or fish.
  Running out of food can lead to starvation. Marketplaces exchange physical
  wares using the catalog's prices and trade rules.
- Barracks turn arriving recruits and delivered equipment into soldiers;
  Town Halls recruit with gold. These are economic consumers, with no combat
  or military movement orders yet.
- The HUD is in Czech and has a top bar for key supplies and population, plus a
  280 px sidebar switching between **Stavět** (build) and **Detail**. A single
  row of category buttons organizes construction; selecting a building opens its
  inventory, progress and relevant actions. **Vše** opens Materiál, Jídlo and
  Výzbroj with total stock and a warehouse / buildings / carried breakdown, in a
  panel sized to the open category. Overview totals include goods waiting in
  production buildings, including lumberjack huts. Roads and vine fields still
  spend warehouse stock. The clock, latest event, time controls and **Ovládání**
  stay at the bottom. Catalog `display_name` values stay English: the Czech names
  live in `game/scripts/ui_text.gd`. See [HUD layout](docs/hud-layout.md).
- Deterministic 10 Hz simulation, weighted pathfinding, exclusive task/tile
  reservations, blocked-route recovery and three movement tiers remain shared
  across these systems. Carrier traffic creates dirt trails.
- Version 10 JSON saves preserve terrain corner heights, fields, deposits,
  exclusive workplaces, per-site construction prices, paid training, production/service queues and
  worker condition. Versions 1–8 retain their historical construction prices;
  versions 1–7 migrate explicitly with flat terrain.
- The fixed 40 × 40 ground projection adds shared-corner relief, slope shading,
  surface-conforming roads, depth ordering and height-aware picking. Buildings,
  fields, deposits and resource icons remain original placeholders; units now
  use the basic sprite atlases, alongside painted trees and road material.

The full economy demo starts with completed buildings, starter supplies, workers and sample
workshop/recruitment orders. Later player buildings require construction.
Select a **School** to train more citizens; **Train Gardener** adds a forester
who needs a completed, vacant **Forester Hut** before planting.
Place wheat fields within eight tiles of a Farm and vine fields near a Vineyard.
Mills and bakeries both employ bakers.

This implements the economic branches in this prototype's own simulation,
not full behavioral or timing parity with KaM. Work durations are project
balance values; reference-building construction prices follow the
[documented KaM table](docs/construction-costs.md). The extra Forester Hut
price is explicitly project-balanced. Livestock uses one aggregate four-grain
recipe per animal. Roads and vine fields pay directly from warehouse stock
and appear immediately. Military recruitment has no extra timer once its
requirements are present; combat, siege engines, unlock progression and
multi-cell buildings remain outside this milestone. See
[economy-expansion.md](docs/economy-expansion.md) for the precise boundaries.

## Requirements and run

The current project format is Godot **4.7**, verified with **4.7.2**. Earlier
milestones targeted Godot 4.6; the expanded current project uses 4.7.

From the repository root:

```sh
godot --path game
```

Or import `game/project.godot` in the Godot editor and run the project.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select/build on a tile |
| Middle mouse drag | Pan camera |
| Mouse wheel | Zoom |
| WASD / arrows | Pan camera |
| 1 / 2 / 3 / 4 / 5 | Stone road / warehouse / lumberjack hut / sawmill / school |
| 6 / 7 / 8 / 9 / 0 | Quarry / farm / mill / bakery / wheat field |
| Build category menu (Obec / Jídlo / Těžba / Armáda) | All 30 buildings, wheat fields and vine fields |
| School UI buttons | Queue one of 15 professions; each citizen costs 1 gold |
| Selected workshop / Barracks / Town Hall | Queue equipment production or recruitment |
| Selected Marketplace | Choose two wares, inspect the quote and queue an exchange |
| Unfinished building → Detail → Zrušit stavbu | Remove its site and return delivered materials to storage |
| Přestat umísťovat / Escape | Leave placement mode, close a panel, or open the main menu |
| Menu | Pause and open the main menu; resume or save there |
| Terén / F2 | Show level ground, walkable slopes and blocked terrain |
| F5 / F9 | Save / load |
| R | Restart the current level |
| Space | Pause/resume simulation |

The prototype starts at a relaxed `0.5×` speed. The UI also offers pause,
`1×` and `2×` controls. The authoritative simulation still uses a fixed 10 Hz
step; speed only controls how quickly those steps are requested in real time.

To cancel a placed construction site, select it on the map and use **Cancel
construction** in Details. Delivered materials return to reachable completed
warehouses; loaded carriers keep their goods and find a new destination.
If returned materials have no reachable warehouse space, cancellation is
refused without changing the site. Completed buildings cannot be removed by
this command.

## Tests

Tests run through a real headless Godot project scene, so project resources and
engine initialization match the game:

```sh
./tests/run-headless.sh
```

Equivalent command:

```sh
godot --headless --path game --scene res://tests/test_runner.tscn
```

The current Godot 4.7.2 suite and verified case count are recorded in
[tests/README.md](tests/README.md). The suite
covers terrain/projection, weighted movement and reservations,
blocked deliveries, citizen training and tree growth, the production graph,
finite deposits and fishing, wheat/vine cycles, carrier-supplied construction,
paid training, food and starvation, production/recruitment/trade orders and
version 15 snapshots with migrations from versions 1–14. Indoor-worker tests
cover entry/exit visibility, production, shared doorway safety and saved visits.
Natural-trail tests cover
sustained traffic, regrowth, directional connections and exact save/load timing.
Relief scenarios cover
uphill transport, plateau construction, steep barriers, visible triangle picking
and the actual keyboard/mouse controls. Viewport tests send
actual keyboard/mouse events; long-running invariant scenarios also resume
JSON snapshots. See [tests/README.md](tests/README.md) for the current suite.

## Repository layout

```text
game/                   Godot project and placeholder visuals
  data/                 Resources, buildings, recipes, units, soldiers and economy rules
  scripts/simulation/   FPS-independent authoritative model
  scripts/view/         Shared projection, terrain renderer, camera, input and UI
  tests/                Godot test scene
docs/                   Reference analysis and architecture
reference/kam_remake/   Ignored, unmodified local reference clone
tests/                   Headless test launcher
tools/                   Future provenance-safe importers/analyzers
```

Architecture and reference notes:

- [`docs/economy-expansion.md`](docs/economy-expansion.md) — current economic graph, rules, provenance and remaining work
- [`docs/reference-analysis.md`](docs/reference-analysis.md)
- [`docs/godot-architecture.md`](docs/godot-architecture.md)
- [`docs/reference-map.md`](docs/reference-map.md)

## Original game data

Do not add proprietary game data to this repository. If a future compatibility
tool needs data from a lawfully purchased installation, it must read a
user-selected external directory and keep derived/imported assets outside Git.
The ignore rules reserve common local directories for that purpose.

## Reference and license

KaM Remake (`reyandme/kam_remake`) is a separately written Delphi/OpenGL engine
licensed under AGPL-3.0. The analyzed local snapshot is commit
`a3b3e5268e1475460e4561f9143df6f1a532e681` from 2026-08-23. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Medieval Economy RTS is licensed under the GNU Affero General Public License,
version 3. See [`LICENSE`](LICENSE).
