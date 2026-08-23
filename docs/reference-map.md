# Reference-to-Godot map

Reference snapshot: `reyandme/kam_remake` commit
`a3b3e5268e1475460e4561f9143df6f1a532e681` (2026-08-23).

“Adapt” means preserving the responsibility/invariant with a Godot-native
design. “New” means the system is designed from project requirements rather
than mirroring the Delphi structure. “Later” is outside the first milestone.

| Delphi file/class | Responsibility in KaM Remake | Godot target | Choice |
|---|---|---|---|
| `KM_Game.pas` / `TKMGame` | Game modes, tick scheduling, top-level update, save orchestration | `SimulationWorld` plus scene-owned fixed-step accumulator | Adapt |
| `KM_GameApp.pas` / `TKMGameApp` | Application lifetime and real-time updates | Godot scene tree / project configuration | New |
| `KM_GameParams.pas` | Authoritative tick and match parameters | Future `MatchConfig` and simulation clock | Adapt later |
| `game/gip/KM_GameInputProcess.pas` | Validate, store and replay gameplay commands | Future typed `CommandQueue` used by SP and MP | Adapt later |
| `game/gip/KM_GameInputProcess_Multi.pas` | Lockstep schedule, delay, random checks | Future lockstep peer coordinator | Adapt later |
| `terrain/KM_Terrain.pas` / `TKMTerrain` | Tile authority, terrain changes, passability | `GridMapSim` | Adapt, simplified |
| `terrain/KM_TerrainTypes.pas` / `TKMTerrainTile` | Layers, height, object, field/tree age, locks, occupancy | Future typed `TerrainCell`; current flat grid/tree entities | Adapt |
| `terrain/KM_TerrainWalkConnect.pas` | Connected walk regions | Future reachability-region cache | Adapt later |
| `terrain/KM_TerrainDeposits.pas` | Mineable terrain deposits | Future resource-node system | Adapt later |
| `pathfinding/KM_PathFinding.pas` | Common pathfinding state/maintenance | `GridPathfinder` interface boundary | Adapt |
| `KM_PathFindingAStarNew.pas` | Unit A* search | Deterministic four-neighbour A* | Adapt, rewritten |
| `KM_PathFindingJPS.pas` | Faster grid search strategy | Optional optimized strategy after profiling | Reconsider later |
| `KM_PathFindingRoad.pas` | Road-aware routing | Weighted surface cost in `GridMapSim`; emergent trails are a new project rule | Adapt/new |
| `navmesh/*` | Army-scale pathing/positioning/influences | Future formation/navigation system | New/adapt later |
| `units/KM_Units.pas` / `TKMUnit` | Persistent unit state and update | Future typed unit states; current worker dictionaries | Adapt |
| `TKMUnitTask` | Multi-tick resumable unit job | Worker state machine + `TaskBoard` assignment | Adapt |
| `TKMUnitAction` | Atomic walk/stay/fight action | Current movement/work transitions; future action objects | Adapt |
| `units/KM_UnitWorkPlan.pas` | Inputs, products and worker/house work sequence | `recipes.json`, `units.json`, production state | Adapt, data-driven |
| `units/tasks/KM_UnitTaskDelivery.pas` | Carry ware from offer to demand | Transport task and worker carry state | Adapt, simplified |
| `units/tasks/KM_UnitTaskMining.pas` | Gather natural resources | Harvest-tree task | Adapt, simplified |
| `units/actions/KM_UnitActionWalkTo.pas` | Occupancy-aware movement | A* path + per-cell reservation | Adapt |
| `units/KM_UnitWarrior.pas` | Warrior perception/orders/state | Future combat unit model | Later |
| `KM_UnitActionFight.pas` | Melee/ranged combat resolution | Future deterministic combat resolver | Adapt later |
| `KM_Projectiles.pas` | Tick-updated projectile state | Future simulation projectiles + visual proxy | Adapt later |
| `houses/KM_Houses.pas` / `TKMHouse` | Construction, inventory slots, demands, worker | Future typed `BuildingState`; current building dictionaries | Adapt |
| `houses/KM_HouseStore.pas` | General ware storage and policies | Warehouse storage; policy system later | Adapt |
| `houses/KM_HouseWoodcutters.pas` | Woodcutter-specific behaviour | Lumberjack returns logs to his own hut output | Adapt, simplified |
| `houses/KM_HouseCollection.pas` | House creation, collection update/save | `SimulationWorld.buildings` + definition catalog | Adapt |
| `res/KM_ResTypes.pas` | Stable ware/house identifiers | Stable string IDs in JSON | Adapt |
| `res/KM_ResHouses.pas` | House specifications | `data/buildings.json` | Adapt, new format |
| `res/KM_ResUnits.pas` | Unit specifications | `data/units.json` | Adapt, new format |
| `res/KM_ResWares.pas` | Ware metadata and rates | `data/resources.json`, `data/recipes.json` | Adapt, new format |
| `hands/KM_Hand.pas` / `TKMHand` | Player aggregate and update order | Future `PlayerState` with owned entity IDs | Adapt later |
| `hands/KM_HandLogistics.pas` / `TKMDeliveries` | Offer/demand graph, route bidding, delivery queue | `TaskBoard`; future logistics matcher | Adapt, simplified |
| `hands/KM_HandLocks.pas` | Construction/entity access locks | Task/source/tile reservation authorities | Adapt |
| `hands/KM_WareDistribution.pas` | Distribution priorities | Future player logistics policy | Adapt later |
| `ai/KM_AI.pas` / `TKMHandAI` | Coordinates economic and military AI | Future AI controller issuing normal commands | Adapt later |
| `ai/KM_AIMayor.pas` | Economic planning | Future economy planner | Reimplement later |
| `ai/KM_AIGoals.pas` | Goal evaluation | Future utility/goal layer | Reimplement later |
| `ai/KM_AIAttacks.pas` | Attack planning | Future military planner | Reimplement later |
| `ai/KM_AIInfluences.pas` | Spatial influence maps | Future analysis grids | Adapt later |
| `game/KM_FogOfWar.pas` | Visibility state | Future deterministic visibility grid | Adapt later |
| `mission/KM_Maps.pas` | Map metadata, discovery and CRC | Native map manifest + content hash | New format |
| `mission/KM_MissionScript_Standard.pas` | Load `.map`/`.dat` mission pair | Future safe external importer; native JSON map | New |
| `mission/KM_Campaigns.pas` | Campaign specification/data | Future native campaign manifests | New |
| `scripting/KM_Scripting.pas` | Scenario scripting lifecycle | Future sandboxed scenario API | Reimplement later |
| `res/KM_Saves.pas` and `TKMGame.Save/Load` | Versioned saves, scanning, reconstruction | `SaveSystem`, migrations later | Adapt, simplified |
| `net/KM_Networking.pas` | Lobby, transport, file transfer, lifecycle | Future Godot networking adapter | New around lockstep core |
| `render/*` | OpenGL rendering | Godot `CanvasItem`/scene rendering | New |
| `gui/*` / `KM_Viewport.pas` | UI and viewport controls | `main_view.gd`, `Camera2D`, Godot Controls | New |
| `minimap/*` | Terrain/entity minimap | Future view-only minimap fed by snapshot | Reimplement later |

## Explicit non-goals

- Do not compile or modify the Delphi reference as the game product.
- Do not reproduce legacy formats unless a user-owned external installation
  needs a read-only importer.
- Do not commit original graphics, sounds, music, maps or campaigns.
- Do not make scene nodes authoritative for economy, pathfinding or combat.
