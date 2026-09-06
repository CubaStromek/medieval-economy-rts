extends Node

const ImportedTerrainTests = preload("res://tests/imported_terrain_tests.gd")
const ImportedTerrainViewTests = preload("res://tests/imported_terrain_view_tests.gd")
const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const TaskBoardClass = preload("res://scripts/simulation/task_board.gd")
const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const GridPathfinderClass = preload("res://scripts/simulation/grid_pathfinder.gd")
const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const TerrainRendererClass = preload("res://scripts/view/terrain_renderer.gd")
const WorkerMovementTests = preload("res://tests/worker_movement_tests.gd")
const EightWayPathTests = preload("res://tests/eight_way_path_tests.gd")
const DiagonalMovementTests = preload("res://tests/diagonal_movement_tests.gd")
const DiagonalTrailTests = preload("res://tests/diagonal_trail_tests.gd")
const IdleYieldTests = preload("res://tests/idle_yield_tests.gd")
const CorridorYieldTests = preload("res://tests/corridor_yield_tests.gd")
const IdleMovementRecoveryTests = preload("res://tests/idle_movement_recovery_tests.gd")
const YieldReplanTests = preload("res://tests/yield_replan_tests.gd")
const TrailTrafficTests = preload("res://tests/trail_traffic_tests.gd")
const TrailSaveTests = preload("res://tests/trail_save_tests.gd")
const TrailWearTests = preload("res://tests/trail_wear_tests.gd")
const TrailRenderTests = preload("res://tests/trail_render_tests.gd")
const WorkplaceTests = preload("res://tests/workplace_tests.gd")
const WorkplaceSaveTests = preload("res://tests/workplace_save_tests.gd")
const HutUiTests = preload("res://tests/hut_ui_tests.gd")
const ForesterHutTests = preload("res://tests/forester_hut_tests.gd")
const FisherHutTests = preload("res://tests/fisher_hut_tests.gd")
const IndoorSaveTests = preload("res://tests/indoor_save_tests.gd")
const IndoorViewTests = preload("res://tests/indoor_view_tests.gd")
const IndoorWorkerTests = preload("res://tests/indoor_worker_tests.gd")
const DayCycleTests = preload("res://tests/day_cycle_tests.gd")
const DayClockViewTests = preload("res://tests/day_clock_view_tests.gd")
const NightScheduleSaveTests = preload("res://tests/night_schedule_save_tests.gd")
const NightFoodTests = preload("res://tests/night_food_tests.gd")
const NightScheduleViewTests = preload("res://tests/night_schedule_view_tests.gd")
const NightScheduleTests = preload("res://tests/night_schedule_tests.gd")
const SolarCycleTests = preload("res://tests/solar_cycle_tests.gd")
const SkyClockViewTests = preload("res://tests/sky_clock_view_tests.gd")
const SolarLightingViewTests = preload("res://tests/solar_lighting_view_tests.gd")
const SaveValidationTests = preload("res://tests/save_validation_tests.gd")
const GridConfigTests = preload("res://tests/grid_config_tests.gd")
const ViewInputTests = preload("res://tests/view_input_tests.gd")
const EconomyInvariantTests = preload("res://tests/economy_invariant_tests.gd")
const ProductionChainTests = preload("res://tests/production_chain_tests.gd")
const DepositsTests = preload("res://tests/deposits_tests.gd")
const ClassicEconomyTests = preload("res://tests/classic_economy_tests.gd")
const HudLayoutTests = preload("res://tests/hud_layout_tests.gd")
const WindowLayoutTests = preload("res://tests/window_layout_tests.gd")
const MainMenuTests = preload("res://tests/main_menu_tests.gd")
const TerrainHeightTests = preload("res://tests/terrain_height_tests.gd")
const TerrainRenderTests = preload("res://tests/terrain_render_tests.gd")
const TerrainChangeTests = preload("res://tests/terrain_change_tests.gd")
const TerrainCacheTests = preload("res://tests/terrain_cache_tests.gd")
const ReliefDemoTests = preload("res://tests/relief_demo_tests.gd")
const ReliefViewTests = preload("res://tests/relief_view_tests.gd")
const SlopeReadabilityTests = preload("res://tests/slope_readability_tests.gd")
const ResourceStockTests = preload("res://tests/resource_stock_tests.gd")
const UnitSpriteTests = preload("res://tests/unit_sprite_tests.gd")
const EnvironmentGraphicsTests = preload("res://tests/environment_graphics_tests.gd")
const TestLevelTests = preload("res://tests/test_level_tests.gd")
const ConstructionCancelUiTests = preload("res://tests/construction_cancel_ui_tests.gd")
const ConstructionCancelTests = preload("res://tests/construction_cancel_tests.gd")
const ConstructionCostTests = preload("res://tests/construction_cost_tests.gd")
const ConstructionCostCompatibilityTests = preload("res://tests/construction_cost_compatibility_tests.gd")
const InnFeedingTests = preload("res://tests/inn_feeding_tests.gd")
const SoldierFoodTests = preload("res://tests/soldier_food_tests.gd")
const FoodSaveTests = preload("res://tests/food_save_tests.gd")
const FoodUiTests = preload("res://tests/food_ui_tests.gd")
const HungerCycleTests = preload("res://tests/hunger_cycle_tests.gd")
const HungerUiTests = preload("res://tests/hunger_ui_tests.gd")

const BuildingFootprintTests = preload("res://tests/building_footprint_tests.gd")
const FootprintSaveTests = preload("res://tests/footprint_save_tests.gd")
const FootprintIntegrationTests = preload("res://tests/footprint_integration_tests.gd")
const FoundationViewTests = preload("res://tests/foundation_view_tests.gd")
const FoundationTests = preload("res://tests/foundation_tests.gd")
const FoundationSaveTests = preload("res://tests/foundation_save_tests.gd")
const FootprintViewTests = preload("res://tests/footprint_view_tests.gd")

var failures: Array[String] = []
var test_count: int = 0


func _ready() -> void:
	var original_tests: Array[Callable] = [
		_test_task_reservation_is_exclusive,
		_test_pathfinder_detours_and_prefers_roads,
		_test_pathfinder_chooses_longer_faster_road,
		_test_nearest_path_search_uses_weighted_cost,
		_test_surface_wear_and_speed_tiers,
		_test_base_terrain_layers_and_rules,
		_test_terrain_controls_placement_and_pathfinding,
		_test_terrain_save_round_trip_and_v3_migration,
		_test_square_projection_round_trip,
		_test_transition_masks_are_deterministic,
		_test_real_carrier_steps_form_contiguous_trail,
		_test_swap_waits_for_both_steps_and_uses_each_surface,
		_test_worker_replans_when_building_invalidates_path,
		_test_carrier_replans_around_blocker_to_occupied_entrance,
		_test_roles_split_harvest_and_transport,
		_test_school_training_validation_and_timing,
		_test_school_training_is_fifo,
		_test_school_training_waits_for_a_free_exit,
		_test_training_save_round_trip_and_v2_migration,
		_test_school_ui_command_path,
		_test_resource_hud,
		_test_building_inventory_ui,
		_test_economy_reaches_stored_planks,
		_test_save_round_trip,
		_test_v1_save_migrates_roles,
		_test_worker_interpolation_never_rewinds,
		_test_blocked_worker_selects_another_source,
		_test_blocked_chokepoint_selects_nearby_source,
		_test_carrier_uses_occupied_entrance_from_adjacent_cell,
		_test_gardener_selects_and_plants_autonomously,
		_test_multiple_gardeners_reserve_distinct_sites,
		_test_gardener_waits_and_retries_without_a_site,
		_test_tree_growth_gates_lumberjack_harvest,
		_test_gardener_growth_save_round_trip_and_v4_migration,
	]
	for test: Callable in original_tests:
		test.call()
		test_count += 1
	_record_suite("Imported terrain", ImportedTerrainTests.TEST_COUNT, ImportedTerrainTests.run())
	_record_suite("Imported terrain view", ImportedTerrainViewTests.TEST_COUNT, await ImportedTerrainViewTests.run(self))
	_record_suite("Main menu and saved sessions", MainMenuTests.TEST_COUNT, await MainMenuTests.run(self))
	_record_suite("Foundation presentation", FoundationViewTests.TEST_COUNT, await FoundationViewTests.run(self))
	_record_suite("Foundation preparation", FoundationTests.TEST_COUNT, FoundationTests.run())
	_record_suite("Foundation saves", FoundationSaveTests.TEST_COUNT, FoundationSaveTests.run())
	_record_suite("Building footprints", BuildingFootprintTests.TEST_COUNT, BuildingFootprintTests.run())
	_record_suite("Footprint saves", FootprintSaveTests.TEST_COUNT, FootprintSaveTests.run())
	_record_suite("Footprint economy integration", FootprintIntegrationTests.TEST_COUNT, FootprintIntegrationTests.run())
	_record_suite("Footprint rendering and input", FootprintViewTests.TEST_COUNT, await FootprintViewTests.run(self))
	_record_suite("Worker movement", WorkerMovementTests.TEST_COUNT, WorkerMovementTests.run())
	_record_suite("Eight-way paths", EightWayPathTests.TEST_COUNT, EightWayPathTests.run())
	_record_suite("Diagonal movement", DiagonalMovementTests.TEST_COUNT, DiagonalMovementTests.run())
	_record_suite("Diagonal trails", DiagonalTrailTests.TEST_COUNT, DiagonalTrailTests.run())
	_record_suite("Idle yielding", IdleYieldTests.TEST_COUNT, IdleYieldTests.run())
	_record_suite("Narrow-lane yielding", CorridorYieldTests.TEST_COUNT, CorridorYieldTests.run())
	_record_suite("Idle movement recovery", IdleMovementRecoveryTests.TEST_COUNT, IdleMovementRecoveryTests.run())
	_record_suite("Yield destination recovery", YieldReplanTests.TEST_COUNT, YieldReplanTests.run())
	_record_suite("Sustained carrier traffic", TrailTrafficTests.TEST_COUNT, TrailTrafficTests.run())
	_record_suite("Trail save compatibility", TrailSaveTests.TEST_COUNT, TrailSaveTests.run())
	_record_suite("Natural trail wear", TrailWearTests.TEST_COUNT, TrailWearTests.run())
	_record_suite("Natural trail rendering", TrailRenderTests.TEST_COUNT, TrailRenderTests.run())
	_record_suite("One worker per workplace", WorkplaceTests.TEST_COUNT, WorkplaceTests.run())
	_record_suite("Workplace save compatibility", WorkplaceSaveTests.TEST_COUNT, WorkplaceSaveTests.run())
	_record_suite("Forester and fisher hut UI", HutUiTests.TEST_COUNT, HutUiTests.run())
	_record_suite("Forester hut", ForesterHutTests.TEST_COUNT, ForesterHutTests.run())
	_record_suite("Fisher hut", FisherHutTests.TEST_COUNT, FisherHutTests.run())
	_record_suite("Indoor save compatibility", IndoorSaveTests.TEST_COUNT, IndoorSaveTests.run())
	_record_suite("Indoor worker lifecycle", IndoorWorkerTests.TEST_COUNT, IndoorWorkerTests.run())
	_record_suite("Calendar clock", DayCycleTests.TEST_COUNT, DayCycleTests.run())
	_record_suite("Solar light cycle", SolarCycleTests.TEST_COUNT, SolarCycleTests.run())
	_record_suite("Civilian daily schedule", NightScheduleTests.TEST_COUNT, NightScheduleTests.run())
	_record_suite("Night schedule save compatibility", NightScheduleSaveTests.TEST_COUNT, NightScheduleSaveTests.run())
	_record_suite("Night meals and deferred cargo", NightFoodTests.TEST_COUNT, NightFoodTests.run())
	_record_suite("Save validation", SaveValidationTests.TEST_COUNT, SaveValidationTests.run())
	_record_suite("Grid configuration", GridConfigTests.TEST_COUNT, GridConfigTests.run())
	_record_suite("Economy invariants", EconomyInvariantTests.TEST_COUNT, EconomyInvariantTests.run())
	_record_suite("Production chains", ProductionChainTests.TEST_COUNT, ProductionChainTests.run())
	_record_suite("Natural deposits and saves", DepositsTests.TEST_COUNT, DepositsTests.run())
	_record_suite("Classic economy", ClassicEconomyTests.TEST_COUNT, ClassicEconomyTests.run())
	_record_suite("Civilian inn meals", InnFeedingTests.TEST_COUNT, InnFeedingTests.run())
	_record_suite("Military food deliveries", SoldierFoodTests.TEST_COUNT, SoldierFoodTests.run())
	_record_suite("Food save compatibility", FoodSaveTests.TEST_COUNT, FoodSaveTests.run())
	_record_suite("Food controls", FoodUiTests.TEST_COUNT, FoodUiTests.run())
	_record_suite("Daily hunger", HungerCycleTests.TEST_COUNT, HungerCycleTests.run())
	_record_suite("Visible satiety", HungerUiTests.TEST_COUNT, HungerUiTests.run())
	_record_suite("KaM construction prices", ConstructionCostTests.TEST_COUNT, ConstructionCostTests.run())
	_record_suite("Construction cost compatibility", ConstructionCostCompatibilityTests.TEST_COUNT, ConstructionCostCompatibilityTests.run())
	_record_suite("Construction cancellation", ConstructionCancelTests.TEST_COUNT, ConstructionCancelTests.run())
	_record_suite("Resource stock accounting", ResourceStockTests.TEST_COUNT, ResourceStockTests.run())
	_record_suite("Terrain heights", TerrainHeightTests.TEST_COUNT, TerrainHeightTests.run())
	_record_suite("Terrain rendering", TerrainRenderTests.TEST_COUNT, TerrainRenderTests.run())
	_record_suite("Terrain change tracking", TerrainChangeTests.TEST_COUNT, TerrainChangeTests.run())
	_record_suite("Relief demo", ReliefDemoTests.TEST_COUNT, ReliefDemoTests.run())
	_record_suite("Minimal test level", TestLevelTests.TEST_COUNT, TestLevelTests.run(self))
	var input_failures: Array[String] = await ViewInputTests.run(self)
	_record_suite("Viewport input", ViewInputTests.TEST_COUNT, input_failures)
	_record_suite("HUD layout and navigation", HudLayoutTests.TEST_COUNT, await HudLayoutTests.run(self))
	_record_suite("Calendar clock HUD", DayClockViewTests.TEST_COUNT, await DayClockViewTests.run(self))
	_record_suite("Night schedule HUD", NightScheduleViewTests.TEST_COUNT, await NightScheduleViewTests.run(self))
	_record_suite("Sky clock HUD", SkyClockViewTests.TEST_COUNT, await SkyClockViewTests.run(self))
	_record_suite("Solar lighting and shadows", SolarLightingViewTests.TEST_COUNT, await SolarLightingViewTests.run(self))
	_record_suite("Responsive window layout", WindowLayoutTests.TEST_COUNT, await WindowLayoutTests.run(self))
	_record_suite("Construction cancellation UI", ConstructionCancelUiTests.TEST_COUNT, await ConstructionCancelUiTests.run(self))
	_record_suite("Relief viewport", ReliefViewTests.TEST_COUNT, await ReliefViewTests.run(self))
	_record_suite("Square terrain and slope readability", SlopeReadabilityTests.TEST_COUNT, await SlopeReadabilityTests.run(self))
	_record_suite("Unit sprites", UnitSpriteTests.TEST_COUNT, await UnitSpriteTests.run(self))
	_record_suite("Indoor unit visibility", IndoorViewTests.TEST_COUNT, await IndoorViewTests.run(self))
	_record_suite("Environment graphics", EnvironmentGraphicsTests.TEST_COUNT, await EnvironmentGraphicsTests.run(self))
	_record_suite("Retained terrain cache", TerrainCacheTests.TEST_COUNT, await TerrainCacheTests.run(self))

	if failures.is_empty():
		print("TEST RESULT: %d/%d passed" % [test_count, test_count])
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: %d failure(s)" % failures.size())
		get_tree().quit(1)


func _record_suite(label: String, count: int, suite_failures: Array[String]) -> void:
	test_count += count
	for failure: String in suite_failures:
		failures.append("%s: %s" % [label, failure])
	print("%s: %d cases, %d failures" % [label, count, suite_failures.size()])


func _test_task_reservation_is_exclusive() -> void:
	var board: TaskBoardClass = TaskBoardClass.new()
	board.create_task("harvest_tree", "tree:7", Vector2i(4, 4), 7)
	var first: Dictionary = board.reserve_next(101, ["harvest_tree"])
	var second: Dictionary = board.reserve_next(102, ["harvest_tree"])
	_expect(not first.is_empty(), "First worker should reserve the tree task")
	_expect(second.is_empty(), "Second worker must not reserve an already claimed tree")
	_expect(board.reservation_count_for_source("tree:7") == 1, "A source must have exactly one reservation")


func _test_pathfinder_detours_and_prefers_roads() -> void:
	var grid: GridMapSimClass = GridMapSimClass.new(Vector2i(7, 5))
	grid.block(Vector2i(3, 2), 99)
	for x: int in range(7):
		grid.add_road(Vector2i(x, 1))
	var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, Vector2i(0, 2), Vector2i(6, 2))
	_expect(not path.is_empty(), "Pathfinder should find a route around an obstacle")
	_expect(not path.has(Vector2i(3, 2)), "Pathfinder route must not cross blocked cells")
	_expect(path.has(Vector2i(3, 1)), "Cheaper road corridor should be selected deterministically")


func _test_pathfinder_chooses_longer_faster_road() -> void:
	var grid: GridMapSimClass = GridMapSimClass.new(Vector2i(7, 4))
	for x: int in range(7):
		grid.add_road(Vector2i(x, 0))
	var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, Vector2i(0, 2), Vector2i(6, 2))
	_expect(path.size() > 6, "A longer route should be valid when its travel time is lower")
	_expect(path.has(Vector2i(3, 0)), "A* should optimize weighted travel time, not tile count")


func _test_nearest_path_search_uses_weighted_cost() -> void:
	var grid: GridMapSimClass = GridMapSimClass.new(Vector2i(7, 4))
	var start := Vector2i(0, 2)
	var geometrically_near := Vector2i(2, 2)
	var travel_time_near := Vector2i(3, 0)
	for road_cell: Vector2i in [
		Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(2, 0), Vector2i(3, 0),
	]:
		grid.add_road(road_cell)
	var goals: Dictionary = {geometrically_near: true, travel_time_near: true}
	var path: Array[Vector2i] = GridPathfinderClass.find_path_to_nearest(
		grid,
		start,
		func(cell: Vector2i) -> bool: return goals.has(cell)
	)
	_expect(not path.is_empty(), "Nearest-goal search should find a reachable candidate")
	_expect(path[path.size() - 1] == travel_time_near, "Nearest-goal search should choose weighted travel time over Manhattan distance")
	_expect(GridPathfinderClass.path_cost(grid, path, start) < 12, "Chosen planting route should be cheaper than the geometrically nearer grass route")


func _test_surface_wear_and_speed_tiers() -> void:
	var simulation := LegacyFixture.create(Vector2i(5, 5))
	var cell := Vector2i(2, 2)
	var grass_ticks: int = simulation.grid.movement_duration_ticks(cell)
	var threshold: int = simulation.grid.carrier_passes_to_form_trail()
	for _pass: int in range(threshold - 1):
		simulation.grid.record_carrier_traffic(cell)
	_expect(simulation.grid.overlay_at(cell).is_empty(), "A trail must not form before the pass threshold")
	simulation.grid.record_carrier_traffic(cell)
	var dirt_ticks: int = simulation.grid.movement_duration_ticks(cell)
	_expect(simulation.grid.overlay_at(cell) == "trail", "Repeated carrier traffic should form a dirt trail")
	_expect(simulation.grid.base_terrain_at(cell) == "grass", "A dirt trail must not replace its base terrain")

	var lumberjack: Dictionary = {"type": "lumberjack"}
	var untouched_cell := Vector2i(1, 1)
	simulation._record_worker_traffic(lumberjack, untouched_cell)
	_expect(not simulation.grid.traffic_wear.has(untouched_cell), "Lumberjack steps must not trample carrier trails")

	simulation.grid.add_road(cell)
	var stone_ticks: int = simulation.grid.movement_duration_ticks(cell)
	_expect(grass_ticks > dirt_ticks and dirt_ticks > stone_ticks, "Movement must satisfy grass > dirt > stone duration")
	_expect(simulation.grid.overlay_at(cell) == "stone_road", "A player road should replace the trail overlay")
	_expect(simulation.grid.base_terrain_at(cell) == "grass", "A stone road must preserve its base terrain")
	_expect(not simulation.grid.traffic_wear.has(cell), "Stone road construction should clear obsolete trail wear")


func _test_base_terrain_layers_and_rules() -> void:
	var grid: GridMapSimClass = GridMapSimClass.new(Vector2i(5, 5))
	var cell := Vector2i(2, 2)
	_expect(grid.base_terrain_at(cell) == "grass", "New maps should default every base cell to grass")
	_expect(grid.set_base_terrain(cell, "dirt"), "Base terrain should accept authored dirt")
	var base_ticks: int = grid.movement_duration_ticks(cell)
	_expect(grid.add_dirt_trail(cell), "Walkable dirt should accept a trail overlay")
	_expect(grid.base_terrain_at(cell) == "dirt", "Trail placement must preserve authored dirt")
	_expect(grid.overlay_at(cell) == "trail", "Trail should occupy only the overlay layer")
	var trail_ticks: int = grid.movement_duration_ticks(cell)
	_expect(grid.add_road(cell), "Walkable dirt should accept a stone-road overlay")
	_expect(grid.base_terrain_at(cell) == "dirt", "Road placement must preserve authored dirt")
	_expect(grid.overlay_at(cell) == "stone_road", "Stone road should replace only the prior overlay")
	_expect(base_ticks > trail_ticks and trail_ticks > grid.movement_duration_ticks(cell), "Overlay speeds should override, not replace, base terrain rules")

	grid.block(cell, 99)
	_expect(grid.base_terrain_at(cell) == "dirt", "Occupancy changes must never erase base terrain")
	_expect(grid.overlay_at(cell).is_empty(), "Building occupancy should clear incompatible surface overlays")
	grid.unblock(cell)
	_expect(grid.is_walkable(cell) and grid.is_buildable(cell), "Authored dirt should remain usable after unblock")

	var water_cell := Vector2i(1, 1)
	var rock_cell := Vector2i(3, 1)
	_expect(grid.set_base_terrain(water_cell, "water"), "Base terrain should accept water")
	_expect(grid.set_base_terrain(rock_cell, "rock"), "Base terrain should accept rock")
	_expect(not grid.is_walkable(water_cell) and not grid.is_buildable(water_cell), "Water must be impassable and unbuildable")
	_expect(not grid.is_walkable(rock_cell) and not grid.is_buildable(rock_cell), "Rock must be impassable and unbuildable")
	_expect(not grid.add_road(water_cell) and not grid.add_dirt_trail(rock_cell), "Surface overlays must not make forbidden base terrain usable")
	var changed_cell := Vector2i(4, 4)
	grid.set_traffic_wear(changed_cell, 2)
	var revision_before_water: int = grid.revision
	_expect(grid.set_base_terrain(changed_cell, "water"), "Authored water should replace a valid unoccupied base cell")
	_expect(grid.overlay_at(changed_cell).is_empty() and grid.traffic_wear_at(changed_cell) == 0, "Making a cell impassable must clear wear and every surface overlay")
	_expect(grid.revision > revision_before_water, "A real base-terrain change should advance the grid revision")
	var revision_before_invalid: int = grid.revision
	_expect(not grid.set_base_terrain(changed_cell, "lava"), "Unknown base-terrain IDs must be rejected")
	_expect(grid.base_terrain_at(changed_cell) == "water" and grid.revision == revision_before_invalid, "Rejected terrain changes must leave state and revision untouched")
	_expect(not grid.is_walkable(Vector2i(-1, 0)) and not grid.is_buildable(Vector2i(5, 0)), "Out-of-bounds cells must reject terrain actions")

	var configured := GridMapSimClass.new(Vector2i(2, 2))
	configured.configure_movement({
		"terrain": {
			"grass": {"walkable": true, "buildable": true, "allows_trees": true, "roadable": true, "move_ticks": 11},
			"water": {"walkable": true, "buildable": true, "allows_trees": false, "roadable": true, "move_ticks": 9},
		},
		"overlays": {
			"trail": {"move_ticks": 3},
			"stone_road": {"move_ticks": 1},
		},
		"trail": {"carrier_passes_to_form": 2},
	})
	_expect(configured.movement_duration_ticks(Vector2i(0, 0)) == 11, "Base movement cost should come from data definitions")
	configured.set_base_terrain(Vector2i(1, 1), "water")
	_expect(configured.is_walkable(Vector2i(1, 1)) and configured.is_buildable(Vector2i(1, 1)), "Walkability and buildability should come from data definitions")
	configured.add_dirt_trail(Vector2i(0, 0))
	_expect(configured.movement_duration_ticks(Vector2i(0, 0)) == 3, "Trail cost should come from data definitions")
	configured.add_road(Vector2i(0, 0))
	_expect(configured.movement_duration_ticks(Vector2i(0, 0)) == 1, "Stone-road cost should come from data definitions")


func _test_terrain_controls_placement_and_pathfinding() -> void:
	var simulation := LegacyFixture.create(Vector2i(7, 5))
	for y: int in range(4):
		simulation.grid.set_base_terrain(Vector2i(3, y), "water")
	simulation.grid.set_base_terrain(Vector2i(5, 1), "rock")
	var path: Array[Vector2i] = GridPathfinderClass.find_path(
		simulation.grid,
		Vector2i(0, 2),
		Vector2i(6, 2)
	)
	_expect(not path.is_empty(), "Pathfinder should route around a base-terrain barrier")
	_expect(path.has(Vector2i(3, 4)), "Pathfinder should use the only walkable gap in a water barrier")
	for path_cell: Vector2i in path:
		_expect(simulation.grid.is_walkable(path_cell), "Pathfinder must never cross forbidden base terrain")

	_expect(not simulation.can_place_building("warehouse", Vector2i(3, 2)), "Buildings must reject water")
	_expect(not simulation.can_place_building("warehouse", Vector2i(5, 1)), "Buildings must reject rock")
	_expect(not simulation.place_road(Vector2i(3, 2)), "Road construction must reject water")
	_expect(simulation.add_tree(Vector2i(5, 1)) == 0, "Trees must reject rock")
	var dirt_cell := Vector2i(1, 1)
	simulation.set_base_terrain(dirt_cell, "dirt")
	var warehouse_id: int = simulation.place_building("warehouse", dirt_cell)
	_expect(warehouse_id != 0, "Buildings should remain valid on authored dirt")
	var warehouse_entrance: Vector2i = (simulation.buildings[warehouse_id] as Dictionary)["entrance"] as Vector2i
	_expect(not simulation.set_base_terrain(warehouse_entrance, "water"), "Terrain authoring must preserve a building's walkable entrance")
	var worker_cell := Vector2i(0, 0)
	var tree_cell := Vector2i(0, 1)
	simulation.spawn_worker(worker_cell, "carrier")
	simulation.add_tree(tree_cell)
	_expect(not simulation.set_base_terrain(worker_cell, "water"), "Terrain authoring must not make an occupied worker cell impassable")
	_expect(not simulation.set_base_terrain(tree_cell, "water"), "Terrain authoring must not replace the base under a tree")

	var training_simulation := LegacyFixture.create(Vector2i(7, 7))
	var school_id: int = training_simulation.place_building("school", Vector2i(3, 3))
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		training_simulation.grid.set_base_terrain(Vector2i(3, 3) + direction, "water")
	var only_exit := Vector2i(2, 3)
	training_simulation.grid.set_base_terrain(only_exit, "dirt")
	training_simulation.queue_unit_training(school_id, "carrier")
	for _tick: int in range(int(training_simulation.catalog.unit("carrier")["training_ticks"])):
		training_simulation.step_tick()
	var trained_worker: Dictionary = training_simulation.workers.values()[0] as Dictionary
	_expect(trained_worker["position"] as Vector2i == only_exit, "School spawning must skip water and use the only walkable authored exit")


func _test_terrain_save_round_trip_and_v3_migration() -> void:
	var source := LegacyFixture.create(Vector2i(5, 4))
	source.grid.set_base_terrain(Vector2i(1, 1), "dirt")
	source.grid.set_base_terrain(Vector2i(2, 1), "water")
	source.grid.set_base_terrain(Vector2i(3, 1), "rock")
	source.grid.add_road(Vector2i(0, 0))
	source.grid.add_dirt_trail(Vector2i(1, 2))
	source.grid.set_traffic_wear(Vector2i(2, 2), 2)
	var snapshot: Dictionary = source.to_data()
	_expect(int(snapshot["version"]) == SimulationWorldClass.SAVE_VERSION, "Terrain snapshots should use the current save schema")
	var restored := LegacyFixture.create()
	_expect(restored.from_data(snapshot), "Version 4 terrain snapshot should load")
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		_expect(restored.grid.base_terrain_at(cell) == source.grid.base_terrain_at(cell), "Save must preserve every authored base terrain ID")
	_expect(restored.grid.overlay_at(Vector2i(0, 0)) == "stone_road", "Save must preserve stone-road overlays")
	_expect(restored.grid.overlay_at(Vector2i(1, 2)) == "trail", "Save must preserve trail overlays")
	_expect(restored.grid.traffic_wear_at(Vector2i(2, 2)) == 2, "Save must preserve partial traffic wear")

	var guarded_world := LegacyFixture.create()
	guarded_world.setup_demo()
	var original_grid: GridMapSimClass = guarded_world.grid
	var original_tick: int = guarded_world.tick
	var original_building_count: int = guarded_world.buildings.size()
	var invalid_snapshot: Dictionary = guarded_world.to_data().duplicate(true)
	var invalid_building: Dictionary = (invalid_snapshot["buildings"] as Array)[0] as Dictionary
	var invalid_position: Array = invalid_building["position"] as Array
	var invalid_terrain: Dictionary = invalid_snapshot["terrain"] as Dictionary
	var invalid_rows: Array = invalid_terrain["base"] as Array
	(invalid_rows[int(invalid_position[1])] as Array)[int(invalid_position[0])] = "water"
	_expect(not guarded_world.from_data(invalid_snapshot), "Invalid current save should be rejected")
	_expect(guarded_world.grid == original_grid, "Rejected save must preserve the live grid instance")
	_expect(guarded_world.tick == original_tick, "Rejected save must preserve the live tick")
	_expect(guarded_world.buildings.size() == original_building_count, "Rejected save must preserve live entities")
	var invalid_payloads: Array[Dictionary] = []
	var unknown_terrain: Dictionary = guarded_world.to_data().duplicate(true)
	((((unknown_terrain["terrain"] as Dictionary)["base"] as Array)[0] as Array))[0] = "lava"
	invalid_payloads.append({"label": "unknown terrain", "data": unknown_terrain})
	var ragged_terrain: Dictionary = guarded_world.to_data().duplicate(true)
	(((ragged_terrain["terrain"] as Dictionary)["base"] as Array)[0] as Array).pop_back()
	invalid_payloads.append({"label": "ragged terrain", "data": ragged_terrain})
	var road_on_water: Dictionary = guarded_world.to_data().duplicate(true)
	(road_on_water["roads"] as Array).append([16, 12])
	invalid_payloads.append({"label": "road on water", "data": road_on_water})
	var oversized_map: Dictionary = guarded_world.to_data().duplicate(true)
	oversized_map["map_size"] = [257, 1]
	invalid_payloads.append({"label": "oversized map", "data": oversized_map})
	var duplicate_entity_id: Dictionary = guarded_world.to_data().duplicate(true)
	var duplicate_buildings: Array = duplicate_entity_id["buildings"] as Array
	(duplicate_buildings[1] as Dictionary)["id"] = int((duplicate_buildings[0] as Dictionary)["id"])
	invalid_payloads.append({"label": "duplicate entity ID", "data": duplicate_entity_id})
	var invalid_entrance: Dictionary = guarded_world.to_data().duplicate(true)
	((invalid_entrance["buildings"] as Array)[0] as Dictionary)["entrance"] = [0, 0]
	invalid_payloads.append({"label": "invalid entrance", "data": invalid_entrance})
	var colliding_next_id: Dictionary = guarded_world.to_data().duplicate(true)
	colliding_next_id["next_entity_id"] = 1
	invalid_payloads.append({"label": "colliding next entity ID", "data": colliding_next_id})
	for invalid_case: Dictionary in invalid_payloads:
		_expect(
			not guarded_world.from_data(invalid_case["data"] as Dictionary),
			"Version 4 should reject %s" % String(invalid_case["label"])
		)
		_expect(
			guarded_world.grid == original_grid
			and guarded_world.tick == original_tick
			and guarded_world.buildings.size() == original_building_count,
			"Rejected %s must preserve the complete live world" % String(invalid_case["label"])
		)

	var legacy_source := LegacyFixture.create(Vector2i(7, 7))
	var school_id: int = legacy_source.place_building("school", Vector2i(3, 3))
	legacy_source.queue_unit_training(school_id, "carrier")
	for _tick: int in range(9):
		legacy_source.step_tick()
	legacy_source.grid.add_road(Vector2i(0, 0))
	legacy_source.grid.add_dirt_trail(Vector2i(1, 0))
	legacy_source.grid.set_traffic_wear(Vector2i(2, 0), 2)
	var expected_remaining: int = int((legacy_source.buildings[school_id] as Dictionary)["training_remaining"])
	var version_3_data: Dictionary = legacy_source.to_data()
	version_3_data["version"] = 3
	version_3_data.erase("terrain")
	var migrated := LegacyFixture.create()
	_expect(migrated.from_data(version_3_data), "Version 3 save should migrate to an all-grass base map")
	for y: int in range(migrated.grid.size.y):
		for x: int in range(migrated.grid.size.x):
			_expect(migrated.grid.base_terrain_at(Vector2i(x, y)) == "grass", "Pre-terrain saves should migrate each base cell to grass")
	var migrated_school: Dictionary = migrated.buildings[school_id] as Dictionary
	_expect((migrated_school["training_queue"] as Array) == ["carrier"], "Terrain migration must preserve version 3 training queues")
	_expect(int(migrated_school["training_remaining"]) == expected_remaining, "Terrain migration must preserve exact training progress")
	_expect(migrated.grid.overlay_at(Vector2i(0, 0)) == "stone_road", "Version 3 migration must preserve stone roads as overlays")
	_expect(migrated.grid.overlay_at(Vector2i(1, 0)) == "trail", "Version 3 migration must preserve dirt trails as overlays")
	_expect(migrated.grid.traffic_wear_at(Vector2i(2, 0)) == 2, "Version 3 migration must preserve partial traffic wear")


func _test_square_projection_round_trip() -> void:
	var origin: Vector2 = MapProjectionClass.cell_center(Vector2i(0, 0))
	var right: Vector2 = MapProjectionClass.cell_center(Vector2i(1, 0))
	var down: Vector2 = MapProjectionClass.cell_center(Vector2i(0, 1))
	_expect(right - origin == Vector2(40.0, 0.0), "One map column must span exactly 40 horizontal drawing units")
	_expect(down - origin == Vector2(0.0, 40.0), "One map row must span exactly 40 vertical drawing units")
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(19, 15)]:
		_expect(MapProjectionClass.world_to_cell(MapProjectionClass.cell_center(cell)) == cell, "Projection should round-trip cell centers")
	_expect(MapProjectionClass.world_to_cell(MapProjectionClass.CELL_SIZE - Vector2(0.01, 0.01)) == Vector2i(0, 0), "Picking should keep points just inside a cell")
	_expect(MapProjectionClass.world_to_cell(MapProjectionClass.CELL_SIZE) == Vector2i(1, 1), "Picking should cross on the exact cell boundary")
	_expect(MapProjectionClass.world_to_cell(Vector2(-0.01, MapProjectionClass.CELL_SIZE.y * 0.5)) == Vector2i(-1, 0), "Picking must floor negative coordinates instead of truncating them")
	_expect(MapProjectionClass.corner_position(Vector2i(1, 1), 1).y < MapProjectionClass.corner_position(Vector2i(1, 1), 0).y, "Future corner height should project upward behind the shared API")


func _test_transition_masks_are_deterministic() -> void:
	var grid := GridMapSimClass.new(Vector2i(3, 3))
	grid.set_base_terrain(Vector2i(1, 0), "water")
	grid.set_base_terrain(Vector2i(2, 1), "rock")
	var renderer: TerrainRendererClass = TerrainRendererClass.new()
	var revision_before_bind: int = grid.revision
	renderer.bind_grid(grid)
	_expect(grid.revision == revision_before_bind, "Binding the read-only renderer must not mutate terrain state")
	var first_mask: int = renderer.transition_mask_for(Vector2i(1, 1))
	var second_mask: int = renderer.transition_mask_for(Vector2i(1, 1))
	_expect(first_mask == 3, "North and east higher-priority materials should set the first two transition bits")
	_expect(second_mask == first_mask, "Identical terrain neighborhoods must return deterministic transition masks")
	_expect(renderer.transition_mask_for(Vector2i(0, 2)) == 0, "Homogeneous terrain should not request a transition mask")
	var variant: int = grid.visual_variant_at(Vector2i(1, 1), 3)
	_expect(variant == grid.visual_variant_at(Vector2i(1, 1), 3) and variant >= 0 and variant < 3, "Visual variants must be stable and remain inside the requested range")

	var corner_grid := GridMapSimClass.new(Vector2i(3, 3))
	corner_grid.set_base_terrain(Vector2i(2, 2), "water")
	renderer.bind_grid(corner_grid)
	_expect(renderer.corner_transition_id_for(Vector2i(1, 1), Vector2i(1, 1)) == "water", "A diagonal-only higher-priority material should create a corner transition")
	corner_grid.set_base_terrain(Vector2i(2, 2), "rock")
	corner_grid.set_base_terrain(Vector2i(2, 1), "water")
	_expect(renderer.corner_transition_id_for(Vector2i(1, 1), Vector2i(1, 1)).is_empty(), "A higher-priority cardinal edge should suppress a lower-priority diagonal corner")
	renderer.free()


func _test_real_carrier_steps_form_contiguous_trail() -> void:
	var simulation := LegacyFixture.create(Vector2i(11, 7))
	# A short legacy delivery fixture tests step-local trail continuity, not the
	# production wear balance (covered by the sustained-traffic suite).
	simulation.grid.configure_movement({"trail": {"carrier_passes_to_form": 4, "weak_decay_ticks": 10000, "established_decay_ticks": 10000}})
	var hut_id: int = simulation.place_building("lumber_hut", Vector2i(2, 4))
	simulation.place_building("sawmill", Vector2i(7, 4))
	var hut_outputs: Dictionary = (simulation.buildings[hut_id] as Dictionary)["outputs"] as Dictionary
	hut_outputs["log"] = 3
	simulation.spawn_worker(Vector2i(2, 3), "carrier")

	for _tick: int in range(500):
		simulation.step_tick()
		if int(hut_outputs["log"]) == 0:
			var all_corridor_dirt: bool = true
			for x: int in range(3, 7):
				if simulation.grid.overlay_at(Vector2i(x, 3)) != "trail":
					all_corridor_dirt = false
					break
			if all_corridor_dirt:
				break
	_expect(int(hut_outputs["log"]) == 0, "Carrier should collect each offered hut log")
	for x: int in range(3, 7):
		_expect(
			simulation.grid.overlay_at(Vector2i(x, 3)) == "trail",
			"Repeated real carrier steps should form a contiguous hut-to-sawmill trail"
		)


func _test_swap_waits_for_both_steps_and_uses_each_surface() -> void:
	var simulation := LegacyFixture.create(Vector2i(4, 3))
	var first_id: int = simulation.spawn_worker(Vector2i(0, 1), "carrier")
	var second_id: int = simulation.spawn_worker(Vector2i(1, 1), "carrier")
	var first: Dictionary = simulation.workers[first_id] as Dictionary
	var second: Dictionary = simulation.workers[second_id] as Dictionary
	first["state"] = "moving"
	first["path"] = [Vector2i(1, 1)]
	first["path_index"] = 0
	second["state"] = "moving"
	second["path"] = [Vector2i(0, 1)]
	second["path_index"] = 0
	second["move_cooldown"] = 3
	simulation.grid.add_road(Vector2i(1, 1))

	var swapped_early: bool = simulation._try_swap_workers(first, second_id, Vector2i(1, 1))
	_expect(not swapped_early, "A worker must not swap with another unit still completing its step")
	var first_position: Vector2i = first["position"] as Vector2i
	var second_position: Vector2i = second["position"] as Vector2i
	_expect(first_position == Vector2i(0, 1), "Rejected swap must preserve the first position")
	_expect(second_position == Vector2i(1, 1), "Rejected swap must preserve the second position")

	second["move_cooldown"] = 0
	var swapped: bool = simulation._try_swap_workers(first, second_id, Vector2i(1, 1))
	_expect(swapped, "Head-on workers should swap once both are ready")
	_expect(int(first["visual_duration_ticks"]) == 2, "Worker entering stone should use stone duration during a swap")
	_expect(int(second["visual_duration_ticks"]) == 6, "Worker entering grass should use grass duration during a swap")


func _test_worker_replans_when_building_invalidates_path() -> void:
	var simulation := LegacyFixture.create(Vector2i(5, 3))
	var worker_id: int = simulation.spawn_worker(Vector2i(0, 1), "carrier")
	var worker: Dictionary = simulation.workers[worker_id] as Dictionary
	var target := Vector2i(4, 1)
	worker["state"] = "moving"
	worker["target_cell"] = target
	worker["path"] = GridPathfinderClass.find_path(simulation.grid, worker["position"] as Vector2i, target)
	worker["path_index"] = 0
	var invalidated_cell := Vector2i(1, 1)
	simulation.grid.block(invalidated_cell, 999)

	simulation._advance_worker(worker)
	var current_position: Vector2i = worker["position"] as Vector2i
	var replanned_path: Array = worker["path"] as Array
	_expect(current_position == Vector2i(0, 1), "Worker must not step into a newly placed building")
	_expect(not replanned_path.has(invalidated_cell), "Worker should immediately replan around a newly blocked path cell")
	_expect(not replanned_path.is_empty(), "Worker should keep moving when an alternate route exists")


func _test_carrier_replans_around_blocker_to_occupied_entrance() -> void:
	var simulation := LegacyFixture.create(Vector2i(8, 5))
	var warehouse_id: int = simulation.place_building("warehouse", Vector2i(6, 2))
	var entrance: Vector2i = (simulation.buildings[warehouse_id] as Dictionary)["entrance"] as Vector2i
	var entrance_blocker_id: int = simulation.spawn_worker(entrance, "carrier")
	var entrance_blocker: Dictionary = simulation.workers[entrance_blocker_id] as Dictionary
	entrance_blocker["state"] = "idle"
	var route_blocker_id: int = simulation.spawn_worker(Vector2i(3, 1), "carrier")
	var route_blocker: Dictionary = simulation.workers[route_blocker_id] as Dictionary
	route_blocker["state"] = "working"
	route_blocker["action"] = "test_blocker"
	route_blocker["work_remaining"] = 999
	var carrier_id: int = simulation.spawn_worker(Vector2i(2, 1), "carrier")
	var carrier: Dictionary = simulation.workers[carrier_id] as Dictionary
	carrier["carrying"] = "plank"
	simulation._resume_carried_ware(carrier)

	for _attempt: int in range(SimulationWorldClass.BLOCKED_REPLAN_TICKS):
		simulation._advance_worker(carrier)
	var replanned_path: Array = carrier["path"] as Array
	_expect(not replanned_path.has(Vector2i(3, 1)), "Carrier replan should avoid an occupied intermediate cell")
	_expect(replanned_path.has(entrance), "Occupied building entrance must remain a valid service goal during replan")

	for _tick: int in range(100):
		simulation.step_tick()
		if simulation.stored_amount("plank") > 0:
			break
	_expect(simulation.stored_amount("plank") == 1, "Carrier should complete delivery beside the occupied entrance after detouring")


func _test_roles_split_harvest_and_transport() -> void:
	var simulation := LegacyFixture.create(Vector2i(13, 8))
	var hut_id: int = simulation.place_building("lumber_hut", Vector2i(2, 4))
	var sawmill_id: int = simulation.place_building("sawmill", Vector2i(7, 4))
	simulation.place_building("warehouse", Vector2i(10, 4))
	simulation.add_tree(Vector2i(2, 1), 1)
	var lumberjack_id: int = simulation.spawn_worker(Vector2i(1, 3), "lumberjack", hut_id)
	var lumberjack: Dictionary = simulation.workers[lumberjack_id] as Dictionary
	_expect(
		simulation._accepted_tasks_for_worker(lumberjack) == SimulationWorldClass.LUMBERJACK_TASKS,
		"Lumberjack should accept only harvest work"
	)

	for _tick: int in range(400):
		simulation.step_tick()
		var hut_outputs: Dictionary = (simulation.buildings[hut_id] as Dictionary)["outputs"] as Dictionary
		if int(hut_outputs["log"]) > 0:
			break
	var hut_outputs: Dictionary = (simulation.buildings[hut_id] as Dictionary)["outputs"] as Dictionary
	var sawmill_inputs: Dictionary = (simulation.buildings[sawmill_id] as Dictionary)["inputs"] as Dictionary
	_expect(int(hut_outputs["log"]) == 1, "Lumberjack must return the felled log to his own hut")
	_expect(int(sawmill_inputs["log"]) == 0, "A lumberjack must not deliver logs directly to the sawmill")

	var carrier_id: int = simulation.spawn_worker(Vector2i(3, 3), "carrier")
	var carrier: Dictionary = simulation.workers[carrier_id] as Dictionary
	var carrier_tasks: Array[String] = simulation._accepted_tasks_for_worker(carrier)
	_expect(
		carrier_tasks.size() == simulation.catalog.resources.size(),
		"Carrier should accept one transport kind for every defined ware"
	)
	for resource: String in simulation.catalog.resources:
		_expect(carrier_tasks.has("transport_" + resource), "Carrier must transport %s without accepting specialist work" % resource)
	for _tick: int in range(1200):
		simulation.step_tick()
		if simulation.stored_amount("plank") > 0:
			break
	_expect(simulation.stored_amount("plank") > 0, "Carrier should move hut log → sawmill and plank → warehouse")


func _test_school_training_validation_and_timing() -> void:
	var simulation := LegacyFixture.create(Vector2i(9, 9))
	var warehouse_id: int = simulation.place_building("warehouse", Vector2i(1, 1))
	var school_cell := Vector2i(4, 4)
	var school_id: int = simulation.place_building("school", school_cell)
	var school: Dictionary = simulation.buildings[school_id] as Dictionary
	_expect(school_id != 0, "School should use the generic building placement flow")
	_expect(simulation.building_id_at(school_cell) == school_id, "Placed school should be selectable by cell")
	_expect(not simulation.queue_unit_training(9999, "carrier"), "Unknown building cannot train a unit")
	_expect(not simulation.queue_unit_training(warehouse_id, "carrier"), "A non-training building cannot train a unit")
	_expect(not simulation.queue_unit_training(school_id, "unknown"), "Unknown unit type cannot enter training")
	_expect(simulation.queue_unit_training(school_id, "carrier"), "School should accept an allowed carrier")

	var training_ticks: int = int(simulation.catalog.unit("carrier")["training_ticks"])
	for _tick: int in range(training_ticks - 1):
		simulation.step_tick()
	_expect(simulation.workers.is_empty(), "Carrier must not spawn before its full training time")
	_expect(int(school["training_remaining"]) == 1, "Training countdown should preserve exact tick progress")
	simulation.step_tick()
	_expect(simulation.workers.size() == 1, "Carrier should spawn exactly on its completion tick")
	var worker: Dictionary = simulation.workers.values()[0] as Dictionary
	var entrance: Vector2i = school["entrance"] as Vector2i
	_expect(String(worker["type"]) == "carrier", "School should spawn the queued unit type")
	_expect(worker["position"] as Vector2i == entrance, "The authored entrance should be the preferred spawn cell")
	_expect(int(simulation.tile_reservations.get(entrance, 0)) == int(worker["id"]), "Spawned unit must reserve its tile")

	for index: int in range(5):
		var queued_type: String = "carrier" if index % 2 == 0 else "lumberjack"
		_expect(simulation.queue_unit_training(school_id, queued_type), "School queue should accept up to its capacity")
	_expect(not simulation.queue_unit_training(school_id, "carrier"), "School queue must reject orders above capacity")


func _test_school_training_is_fifo() -> void:
	var simulation := LegacyFixture.create(Vector2i(10, 8))
	var hut_id: int = simulation.place_building("lumber_hut", Vector2i(1, 4))
	var school_id: int = simulation.place_building("school", Vector2i(5, 4))
	var school: Dictionary = simulation.buildings[school_id] as Dictionary
	_expect(simulation.queue_unit_training(school_id, "carrier"), "First FIFO unit should queue")
	_expect(simulation.queue_unit_training(school_id, "lumberjack"), "Second FIFO unit should queue")

	var carrier_ticks: int = int(simulation.catalog.unit("carrier")["training_ticks"])
	var lumberjack_ticks: int = int(simulation.catalog.unit("lumberjack")["training_ticks"])
	for _tick: int in range(carrier_ticks):
		simulation.step_tick()
	_expect(simulation.workers.size() == 1, "First queued unit should finish before the second starts")
	_expect(int(school["training_remaining"]) == lumberjack_ticks, "Second FIFO timer starts only after the first spawn")
	for _tick: int in range(lumberjack_ticks - 1):
		simulation.step_tick()
	_expect(simulation.workers.size() == 1, "Second queued unit must receive its full independent duration")
	simulation.step_tick()

	var worker_ids: Array = simulation.workers.keys()
	worker_ids.sort()
	var first_worker: Dictionary = simulation.workers[int(worker_ids[0])] as Dictionary
	var second_worker: Dictionary = simulation.workers[int(worker_ids[1])] as Dictionary
	_expect(String(first_worker["type"]) == "carrier", "Training queue must preserve FIFO order")
	_expect(String(second_worker["type"]) == "lumberjack", "Second FIFO entry should retain its type")
	_expect(int(second_worker["home_id"]) == hut_id, "Trained lumberjack should bind to the nearest lumber hut")
	_expect((school["training_queue"] as Array).is_empty(), "Completed FIFO queue should be empty")


func _test_school_training_waits_for_a_free_exit() -> void:
	var simulation := LegacyFixture.create(Vector2i(7, 7))
	var school_id: int = simulation.place_building("school", Vector2i(3, 3))
	var school: Dictionary = simulation.buildings[school_id] as Dictionary
	var exit_cells: Array[Vector2i] = []
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		exit_cells.append((school["position"] as Vector2i) + direction)
	for exit_cell: Vector2i in exit_cells:
		_expect(simulation.spawn_worker(exit_cell, "carrier") != 0, "Test should occupy every school exit")
	_expect(simulation.queue_unit_training(school_id, "carrier"), "Blocked school should still accept training")

	var training_ticks: int = int(simulation.catalog.unit("carrier")["training_ticks"])
	for _tick: int in range(training_ticks):
		simulation.step_tick()
	var next_entity_id_before_retry: int = simulation._next_entity_id
	_expect(simulation.workers.size() == 4, "Completed unit must wait while every exit is occupied")
	_expect(int(school["training_remaining"]) == 0, "Blocked completed training should remain ready at zero ticks")
	_expect((school["training_queue"] as Array).size() == 1, "Blocked completed unit must remain in the queue")
	for _tick: int in range(3):
		simulation.step_tick()
	_expect(simulation._next_entity_id == next_entity_id_before_retry, "Blocked retries must not consume or duplicate entity IDs")
	var pending_snapshot: Dictionary = simulation.to_data()
	var pending_restored := LegacyFixture.create()
	_expect(pending_restored.from_data(pending_snapshot), "A completed blocked training order should load")
	simulation = pending_restored
	school = simulation.buildings[school_id] as Dictionary
	_expect(int(school["training_remaining"]) == 0, "Save must preserve a completed order waiting for an exit")
	_expect((school["training_queue"] as Array).size() == 1, "Save must preserve the blocked queue head")

	var entrance: Vector2i = school["entrance"] as Vector2i
	var blocker_id: int = int(simulation.tile_reservations[entrance])
	var blocker: Dictionary = simulation.workers[blocker_id] as Dictionary
	var relocated_cell := Vector2i(0, 0)
	simulation.tile_reservations.erase(entrance)
	blocker["position"] = relocated_cell
	blocker["previous_position"] = relocated_cell
	simulation.tile_reservations[relocated_cell] = blocker_id
	simulation.step_tick()
	_expect(simulation.workers.size() == 5, "Ready unit should spawn once a deterministic exit becomes free")
	_expect((school["training_queue"] as Array).is_empty(), "Successful retry must consume exactly one queued unit")
	_expect(simulation._next_entity_id == next_entity_id_before_retry + 1, "Successful retry should consume one entity ID")


func _test_training_save_round_trip_and_v2_migration() -> void:
	var source := LegacyFixture.create(Vector2i(9, 9))
	var school_id: int = source.place_building("school", Vector2i(4, 4))
	_expect(source.queue_unit_training(school_id, "lumberjack"), "Save test should queue a lumberjack")
	for _tick: int in range(23):
		source.step_tick()
	var source_school: Dictionary = source.buildings[school_id] as Dictionary
	var expected_remaining: int = int(source_school["training_remaining"])
	var snapshot: Dictionary = source.to_data()
	_expect(
		int(snapshot["version"]) == SimulationWorldClass.SAVE_VERSION,
		"Unit training state should use the current save version"
	)

	var test_path: String = OS.get_temp_dir().path_join("medieval_economy_rts_training_test_%d.json" % OS.get_process_id())
	var saved: bool = SaveSystemClass.save_world(source, test_path)
	var restored := LegacyFixture.create()
	var loaded: bool = SaveSystemClass.load_world(restored, test_path)
	if saved:
		_expect(DirAccess.remove_absolute(test_path) == OK, "Test should clean up its own temporary save")
	_expect(saved, "SaveSystem should serialize in-progress training")
	_expect(loaded, "Current save with in-progress training should load")
	if not saved or not loaded:
		return
	var invalid_training_head: Dictionary = snapshot.duplicate(true)
	var invalid_school: Dictionary = (invalid_training_head["buildings"] as Array)[0] as Dictionary
	invalid_school["training_queue"] = ["unknown", "lumberjack"]
	invalid_school["training_remaining"] = 1
	_expect(not LegacyFixture.create().from_data(invalid_training_head), "Version 4 must reject an invalid training queue head")
	var oversized_training_queue: Dictionary = snapshot.duplicate(true)
	var oversized_school: Dictionary = (oversized_training_queue["buildings"] as Array)[0] as Dictionary
	oversized_school["training_queue"] = ["carrier", "carrier", "carrier", "carrier", "carrier", "carrier"]
	oversized_school["training_remaining"] = 1
	_expect(not LegacyFixture.create().from_data(oversized_training_queue), "Version 4 must reject training queues above building capacity")
	var restored_school: Dictionary = restored.buildings[school_id] as Dictionary
	_expect((restored_school["training_queue"] as Array) == ["lumberjack"], "Save must preserve the training queue")
	_expect(int(restored_school["training_remaining"]) == expected_remaining, "Save must preserve exact training progress")
	for _tick: int in range(expected_remaining - 1):
		restored.step_tick()
	_expect(restored.workers.is_empty(), "Restored unit must not complete one tick early")
	restored.step_tick()
	_expect(restored.workers.size() == 1, "Restored training should finish after the saved remaining ticks")
	var restored_worker: Dictionary = restored.workers.values()[0] as Dictionary
	_expect(String(restored_worker["type"]) == "lumberjack", "Restored queue should spawn its original unit type")

	var legacy_path: String = OS.get_temp_dir().path_join("medieval_economy_rts_v2_fixture_%d.json" % OS.get_process_id())
	var legacy_file: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE)
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify({
			"version": 2,
			"tick": 17,
			"next_entity_id": 2,
			"map_size": [7, 7],
			"roads": [[0, 0]],
			"dirt_trails": [[1, 0]],
			"traffic_wear": [[2, 0, 2]],
			"buildings": [{
				"id": 1,
				"type": "warehouse",
				"position": [3, 3],
				"entrance": [3, 2],
				"storage": {"log": 0, "plank": 0},
				"inputs": {"log": 0},
				"outputs": {"log": 0, "plank": 0},
				"process_remaining": 0,
			}],
			"trees": [],
			"workers": [],
		}, "  "))
		legacy_file.close()
	_expect(legacy_file != null, "Historical v2 fixture should be writable")
	var migrated := LegacyFixture.create()
	var legacy_loaded: bool = SaveSystemClass.load_world(migrated, legacy_path)
	if legacy_file != null:
		_expect(DirAccess.remove_absolute(legacy_path) == OK, "Test should clean up its own v2 fixture")
	_expect(legacy_loaded, "Historical version 2 JSON should migrate through SaveSystem")
	var migrated_building: Dictionary = migrated.buildings.get(1, {}) as Dictionary
	_expect((migrated_building.get("training_queue", []) as Array).is_empty(), "Migrated v2 building should gain an empty training queue")
	_expect(int(migrated_building.get("training_remaining", -1)) == 0, "Migrated v2 building should gain idle training progress")
	_expect(migrated.grid.overlay_at(Vector2i(0, 0)) == "stone_road", "Historical v2 migration should preserve a stone road")
	_expect(migrated.grid.overlay_at(Vector2i(1, 0)) == "trail", "Historical v2 migration should preserve a dirt trail")
	_expect(migrated.grid.traffic_wear_at(Vector2i(2, 0)) == 2, "Historical v2 migration should preserve partial wear")


func _test_school_ui_command_path() -> void:
	var main_view: MainViewClass = MainScene.instantiate() as MainViewClass
	main_view.demo_kind = "economy"
	add_child(main_view)
	_expect(main_view.terrain_renderer.grid == main_view.world.grid, "Main scene should bind TerrainRenderer to the authoritative grid")
	var initial_grid: GridMapSimClass = main_view.world.grid
	main_view._reset_demo()
	_expect(main_view.world.grid != initial_grid and main_view.terrain_renderer.grid == main_view.world.grid, "Reset should rebind TerrainRenderer to the replacement grid")
	# This fixture tests UI command dispatch; material construction and paid
	# training are covered through real ticks in ClassicEconomyTests.
	main_view.world.economy_enabled = false
	var school_key := InputEventKey.new()
	school_key.keycode = KEY_5
	school_key.pressed = true
	main_view._unhandled_input(school_key)
	_expect(main_view.build_mode == "school", "Keyboard shortcut 5 should select the School build tool")

	# Find a genuinely empty full-size school plot in the production demo.
	var school_cell := Vector2i(-1, -1)
	for y: int in range(main_view.world.grid.size.y):
		for x: int in range(main_view.world.grid.size.x):
			var candidate := Vector2i(x, y)
			if main_view.world.can_place_building("school", candidate):
				school_cell = candidate
				break
		if school_cell != Vector2i(-1, -1):
			break
	var school_canvas_position: Vector2 = main_view.terrain_renderer.to_global(
		main_view.terrain_renderer.cell_center(school_cell)
	)
	# Aim this command-path fixture at visible ground for any root aspect ratio
	# (the headless display is square). Never place by clicking through the HUD.
	var viewport_size: Vector2 = main_view.get_viewport_rect().size
	var map_point: Vector2 = viewport_size * Vector2(0.75, 0.5)
	main_view.camera.position_smoothing_enabled = false
	main_view.camera.position = school_canvas_position - (map_point - viewport_size * 0.5) / main_view.camera.zoom.x
	main_view.camera.force_update_scroll()
	var school_click := InputEventMouseButton.new()
	school_click.button_index = MOUSE_BUTTON_LEFT
	school_click.pressed = true
	school_click.position = main_view.get_viewport().get_canvas_transform() * school_canvas_position
	school_click.global_position = school_click.position
	_expect(not main_view.hud.blocks_map_point(school_click.position), "School command fixture must target unobstructed ground")
	main_view._unhandled_input(school_click)
	_expect(main_view.selected_cell == school_cell, "Terrain picking should select the clicked school cell")
	var school_id: int = main_view.world.building_id_at(school_cell)
	_expect(school_id != 0, "School build tool should place a school through the mouse command path")
	if school_id == 0:
		main_view.queue_free()
		return

	var carrier_button: Button = null
	var lumberjack_button: Button = null
	var gardener_button: Button = null
	for node: Node in main_view.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == "Train Carrier":
			carrier_button = button
		elif button.text == "Train Lumberjack":
			lumberjack_button = button
		elif button.text == "Train Gardener":
			gardener_button = button
	_expect(carrier_button != null, "School UI should expose the carrier training button")
	_expect(lumberjack_button != null, "School UI should expose the lumberjack training button")
	_expect(gardener_button != null, "School UI should expose the gardener training button")
	if carrier_button != null:
		_expect(not carrier_button.disabled and carrier_button.is_visible_in_tree(), "Carrier training button should be interactable")
	if lumberjack_button != null:
		_expect(not lumberjack_button.disabled and lumberjack_button.is_visible_in_tree(), "Lumberjack training button should be interactable")
	if gardener_button != null:
		_expect(not gardener_button.disabled and gardener_button.is_visible_in_tree(), "Gardener training button should be interactable")
	if carrier_button != null:
		carrier_button.pressed.emit()
	if lumberjack_button != null:
		lumberjack_button.pressed.emit()
	if gardener_button != null:
		gardener_button.pressed.emit()
	var school: Dictionary = main_view.world.buildings[school_id] as Dictionary
	_expect(
		(school["training_queue"] as Array) == ["carrier", "lumberjack", "gardener"],
		"School buttons should enqueue their unit types in click order"
	)
	main_view.queue_free()


func _test_resource_hud() -> void:
	var main_view: MainViewClass = MainScene.instantiate() as MainViewClass
	main_view.demo_kind = "economy"
	add_child(main_view)
	main_view.set_process(false)
	_expect(main_view.resource_hud_panel != null, "Main scene should create the resource status bar")
	_expect(main_view.resource_hud_panel.name == "ResourceStatusBar",
		"Resource status bar should expose a stable UI node name")
	_expect(main_view.resource_amount_labels.size() == main_view.world.catalog.resources.size(),
		"HUD should create one total-value label for every defined resource")
	_expect(main_view.resource_breakdown_labels.size() == main_view.world.catalog.resources.size(),
		"HUD should create one inventory breakdown for every defined resource")

	# Reproduce the reported bug before testing every other resource.
	main_view.world = LegacyFixture.create(Vector2i(12, 8))
	main_view.world.place_building("warehouse", Vector2i(2, 2))
	var hut: int = main_view.world.place_building("lumber_hut", Vector2i(8, 2))
	main_view.world.buildings[hut]["outputs"]["log"] = 6
	main_view.terrain_renderer.bind_grid(main_view.world.grid)
	main_view._update_ui()
	_expect((main_view.resource_amount_labels["log"] as Label).text == "6",
		"Six logs in the lumberjack hut must show LOGS 6 in detailed stocks")
	_expect((main_view.hud._summary_amounts["log"] as Label).text == "6",
		"Six logs in the lumberjack hut must also show LOGS 6 in the overview")
	_expect((main_view.resource_breakdown_labels["log"] as Label).text == "Warehouse: 0\nBuildings: 6\nCarried: 0",
		"The log detail must explicitly locate all six logs in buildings")

	var fixture: Dictionary = ResourceStockTests.all_resource_fixture()
	main_view.world = fixture["world"]
	main_view.terrain_renderer.bind_grid(main_view.world.grid)
	var expected: Dictionary = fixture["expected"]
	main_view._update_ui()
	for resource: String in expected:
		var stock: Dictionary = expected[resource]
		var breakdown: String = "Warehouse: %d\nBuildings: %d\nCarried: %d" % [
			int(stock["warehouse"]), int(stock["buildings"]), int(stock["carried"]),
		]
		_expect((main_view.resource_amount_labels[resource] as Label).text == str(stock["total"]),
			"HUD must show the independent expected total for " + resource)
		_expect((main_view.resource_breakdown_labels[resource] as Label).text == breakdown,
			"HUD must show explicit warehouse, building and carrier amounts for " + resource)
		var detail_item: Control = main_view.hud._resource_items[resource]
		_expect(detail_item.tooltip_text.contains(breakdown),
			"Detailed stock tooltip must explain each location for " + resource)
		if main_view.hud._summary_amounts.has(resource):
			var summary: Label = main_view.hud._summary_amounts[resource]
			_expect(summary.text == str(stock["total"]), "Overview must use the same total for " + resource)
			var summary_item: Control = main_view.hud._summary_items[resource]
			_expect(summary_item.tooltip_text.contains(breakdown),
				"Overview tooltip must explain the same breakdown for " + resource)
	main_view.queue_free()


func _test_building_inventory_ui() -> void:
	var main_view: MainViewClass = MainScene.instantiate() as MainViewClass
	main_view.demo_kind = "economy"
	add_child(main_view)
	var building_cells: Dictionary = {}
	for building_variant: Variant in main_view.world.buildings.values():
		var building: Dictionary = building_variant as Dictionary
		building_cells[String(building["type"])] = building["position"] as Vector2i
	var warehouse: Dictionary = main_view.world.buildings[
		main_view.world.building_id_at(building_cells["warehouse"] as Vector2i)
	] as Dictionary
	var lumber_hut: Dictionary = main_view.world.buildings[
		main_view.world.building_id_at(building_cells["lumber_hut"] as Vector2i)
	] as Dictionary
	var sawmill: Dictionary = main_view.world.buildings[
		main_view.world.building_id_at(building_cells["sawmill"] as Vector2i)
	] as Dictionary
	for resource: String in warehouse["storage"]:
		warehouse["storage"][resource] = 0
	(warehouse["storage"] as Dictionary)["log"] = 3
	(warehouse["storage"] as Dictionary)["plank"] = 5
	(warehouse["storage"] as Dictionary)["stone"] = 2
	(lumber_hut["outputs"] as Dictionary)["log"] = 7
	(sawmill["outputs"] as Dictionary)["plank"] = 11

	var expected_inventory_text: Dictionary = {
		"warehouse": "Warehouse\nInventory: Logs: 3  •  Planks: 5  •  Stone: 2",
		"lumber_hut": "Lumberjack Hut\nInventory: Logs: 7",
		"sawmill": "Sawmill\nInventory: Planks: 11",
	}
	main_view._set_build_mode("road")
	var event_count_before_selection: int = main_view.world.event_log.size()
	for building_type: String in expected_inventory_text:
		_expect(building_cells.has(building_type), "Demo should contain %s for its inventory UI test" % building_type)
		if not building_cells.has(building_type):
			continue
		var building_cell: Vector2i = building_cells[building_type] as Vector2i
		var canvas_position: Vector2 = main_view.terrain_renderer.to_global(
			main_view.terrain_renderer.cell_center(building_cell) + Vector2(0, -40)
		)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = main_view.get_viewport().get_canvas_transform() * canvas_position
		click.global_position = click.position
		main_view._unhandled_input(click)
		_expect(main_view.selected_cell == building_cell, "%s should be selected by clicking it" % building_type)
		_expect(
			main_view.building_inventory_label.text == String(expected_inventory_text[building_type]),
			"Selected %s should show only its current inventory" % building_type
		)
		_expect(main_view.building_inventory_label.visible, "Selected building inventory should be visible")
		_expect(
			main_view.world.event_log.size() == event_count_before_selection,
			"Inspecting a building should not attempt construction while a build tool is active"
		)

	main_view.selected_cell = building_cells["sawmill"] as Vector2i
	(sawmill["outputs"] as Dictionary)["plank"] = 12
	main_view._process(0.0)
	_expect(
		main_view.building_inventory_label.text == "Sawmill\nInventory: Planks: 12",
		"Selected building inventory should refresh when its stock changes"
	)

	main_view.selected_cell = Vector2i(0, 0)
	main_view._update_ui()
	_expect(main_view.building_inventory_label.visible
		and main_view.building_inventory_label.text == "Grass terrain\nHeight: 0.0 • slope: 0\nWalkable • Level, buildable ground",
		"Selecting empty level grass should show its height, slope, walking and foundation rules")
	main_view.selected_cell = Vector2i(-1, -1)
	main_view._update_ui()
	_expect(not main_view.building_inventory_label.visible, "Details should hide when there is no map selection")
	main_view.queue_free()


func _test_economy_reaches_stored_planks() -> void:
	var simulation: SimulationWorldClass = LegacyFixture.create()
	simulation.setup_demo()
	for _tick: int in range(1600):
		simulation.step_tick()
	_expect(
		simulation.stored_amount("plank") > 0,
		"Harvest → sawmill → warehouse chain should store at least one plank (pipeline=%d, workers=%s)" % [
			simulation.pipeline_amount("plank"), str(simulation.workers.values())
		]
	)
	_expect(simulation.workers.size() >= 2, "Prototype must keep at least two workers")


func _test_save_round_trip() -> void:
	var source: SimulationWorldClass = LegacyFixture.create()
	source.setup_demo()
	for _tick: int in range(300):
		source.step_tick()
	var saved_dirt_cell := Vector2i(0, 0)
	for _pass: int in range(source.grid.carrier_passes_to_form_trail()):
		source.grid.record_carrier_traffic(saved_dirt_cell)
	var saved_road_cell := Vector2i(1, 0)
	source.grid.add_road(saved_road_cell)
	var partial_wear_cell := Vector2i(2, 0)
	for _pass: int in range(source.grid.carrier_passes_to_form_trail() - 1):
		source.grid.record_carrier_traffic(partial_wear_cell)
	var expected_partial_wear: int = int(source.grid.traffic_wear[partial_wear_cell])
	var test_path: String = OS.get_temp_dir().path_join("medieval_economy_rts_round_trip_test_%d.json" % OS.get_process_id())
	var saved: bool = SaveSystemClass.save_world(source, test_path)
	var restored: SimulationWorldClass = LegacyFixture.create()
	var loaded: bool = SaveSystemClass.load_world(restored, test_path)
	if saved:
		_expect(DirAccess.remove_absolute(test_path) == OK, "Test should clean up its own temporary save")
	_expect(saved, "SaveSystem should write a JSON snapshot")
	_expect(loaded, "Versioned simulation snapshot should load")
	if not saved or not loaded:
		return
	_expect(restored.tick == source.tick, "Loaded tick must match saved tick")
	_expect(restored.buildings.size() == source.buildings.size(), "Loaded buildings must match saved buildings")
	_expect(restored.trees.size() == source.trees.size(), "Loaded tree state must match saved tree state")
	_expect(restored.grid.dirt_trails.has(saved_dirt_cell), "Current save must preserve formed dirt trails")
	_expect(restored.grid.roads.has(saved_road_cell), "Current save must preserve player-built stone roads")
	_expect(restored.grid.base_terrain_at(Vector2i(0, 12)) == "dirt", "Current save must preserve authored dirt")
	_expect(restored.grid.base_terrain_at(Vector2i(16, 12)) == "water", "Current save must preserve authored water")
	_expect(restored.grid.base_terrain_at(Vector2i(17, 0)) == "rock", "Current save must preserve authored rock")
	_expect(
		int(restored.grid.traffic_wear.get(partial_wear_cell, 0)) == expected_partial_wear,
		"Current save must preserve exact partial wear below the trail threshold"
	)
	_expect(not restored.grid.dirt_trails.has(partial_wear_cell), "Partial saved wear must not load as a completed trail")
	var restored_types: Array[String] = []
	for worker_variant: Variant in restored.workers.values():
		restored_types.append(String((worker_variant as Dictionary)["type"]))
	_expect(restored_types.has("lumberjack") and restored_types.has("carrier"), "Current save must preserve worker roles")
	for _tick: int in range(1400):
		restored.step_tick()
	_expect(restored.stored_amount("plank") > 0, "Loaded workers should resume deliveries and production")


func _test_v1_save_migrates_roles() -> void:
	var source := LegacyFixture.create()
	source.setup_demo()
	source.grid.add_road(Vector2i(0, 0))
	var legacy_data: Dictionary = source.to_data()
	legacy_data["version"] = 1
	legacy_data.erase("terrain")
	legacy_data.erase("dirt_trails")
	legacy_data.erase("traffic_wear")
	for worker_variant: Variant in legacy_data["workers"]:
		var worker_data: Dictionary = worker_variant as Dictionary
		worker_data.erase("type")
		worker_data.erase("home_id")
	var legacy_workers: Array = legacy_data["workers"] as Array
	legacy_workers.reverse()
	for building_variant: Variant in legacy_data["buildings"]:
		var building_data: Dictionary = building_variant as Dictionary
		building_data.erase("training_queue")
		building_data.erase("training_remaining")
		var outputs: Dictionary = building_data["outputs"] as Dictionary
		outputs.erase("log")

	var restored := LegacyFixture.create()
	var loaded: bool = restored.from_data(legacy_data)
	_expect(loaded, "Version 1 saves should migrate instead of being rejected")
	var worker_ids: Array = restored.workers.keys()
	worker_ids.sort()
	_expect(String((restored.workers[int(worker_ids[0])] as Dictionary)["type"]) == "lumberjack", "First v1 worker should migrate to lumberjack")
	_expect(String((restored.workers[int(worker_ids[1])] as Dictionary)["type"]) == "carrier", "Remaining v1 workers should migrate to carriers")
	_expect(restored.grid.overlay_at(Vector2i(0, 0)) == "stone_road", "Version 1 roads should migrate to stone-road overlays")
	for building_variant: Variant in restored.buildings.values():
		var outputs: Dictionary = (building_variant as Dictionary)["outputs"] as Dictionary
		_expect(outputs.has("log"), "Migrated v1 buildings must gain a normalized log output")


func _test_worker_interpolation_never_rewinds() -> void:
	var worker: Dictionary = {
		"visual_progress_ticks": 0,
		"visual_duration_ticks": 4,
	}
	var previous_alpha: float = -1.0
	for progress: int in range(5):
		worker["visual_progress_ticks"] = progress
		for frame_fraction: float in [0.0, 0.5, 0.99]:
			var alpha: float = MainViewClass.worker_lerp_alpha(worker, frame_fraction)
			_expect(alpha >= previous_alpha, "Worker interpolation must never move backwards between ticks")
			previous_alpha = alpha


func _test_blocked_worker_selects_another_source() -> void:
	var simulation := LegacyFixture.create(Vector2i(10, 8))
	simulation.place_building("lumber_hut", Vector2i(1, 1))
	var blocked_tree_id: int = simulation.add_tree(Vector2i(3, 3), 3)
	var free_tree_id: int = simulation.add_tree(Vector2i(7, 3), 3)
	var active_worker_id: int = simulation.spawn_worker(Vector2i(2, 3), "lumberjack")
	simulation.step_tick()
	var active_worker: Dictionary = simulation.workers[active_worker_id] as Dictionary
	_expect(int(active_worker["source_id"]) == blocked_tree_id, "Worker should initially claim the nearest tree")

	var blocker_id: int = simulation.spawn_worker(Vector2i(3, 3))
	var blocker: Dictionary = simulation.workers[blocker_id] as Dictionary
	blocker["state"] = "working"
	blocker["action"] = "test_blocker"
	blocker["work_remaining"] = 999
	for _tick: int in range(SimulationWorldClass.BLOCKED_REPLAN_TICKS + 2):
		simulation.step_tick()

	_expect(
		int(active_worker["source_id"]) == free_tree_id,
		"Worker blocked from its target should release it and select another reachable source"
	)
	_expect(
		simulation.task_board.reservation_count_for_source("tree:%d" % blocked_tree_id) == 0,
		"Blocked source reservation must be released"
	)


func _test_blocked_chokepoint_selects_nearby_source() -> void:
	var simulation := LegacyFixture.create(Vector2i(8, 7))
	simulation.place_building("lumber_hut", Vector2i(1, 1))
	for y: int in range(7):
		if y != 3:
			simulation.grid.block(Vector2i(3, y), -100 - y)
	var far_tree_id: int = simulation.add_tree(Vector2i(5, 3), 3)
	var nearby_tree_id: int = simulation.add_tree(Vector2i(1, 6), 3)
	var active_worker_id: int = simulation.spawn_worker(Vector2i(2, 3), "lumberjack")
	simulation.step_tick()
	var active_worker: Dictionary = simulation.workers[active_worker_id] as Dictionary
	_expect(int(active_worker["source_id"]) == far_tree_id, "Worker should initially route through the open chokepoint")

	var blocker_id: int = simulation.spawn_worker(Vector2i(3, 3))
	var blocker: Dictionary = simulation.workers[blocker_id] as Dictionary
	blocker["state"] = "working"
	blocker["action"] = "test_blocker"
	blocker["work_remaining"] = 999
	for _tick: int in range(SimulationWorldClass.BLOCKED_REPLAN_TICKS + 2):
		simulation.step_tick()

	_expect(
		int(active_worker["source_id"]) == nearby_tree_id,
		"Worker blocked at an intermediate chokepoint should choose a reachable nearby source"
	)


func _test_carrier_uses_occupied_entrance_from_adjacent_cell() -> void:
	var simulation := LegacyFixture.create(Vector2i(8, 8))
	var warehouse_id: int = simulation.place_building("warehouse", Vector2i(4, 4))
	var entrance: Vector2i = (simulation.buildings[warehouse_id] as Dictionary)["entrance"] as Vector2i
	var blocker_id: int = simulation.spawn_worker(entrance)
	var blocker: Dictionary = simulation.workers[blocker_id] as Dictionary
	blocker["state"] = "idle"
	var carrier_id: int = simulation.spawn_worker(entrance + Vector2i(0, -1))
	var carrier: Dictionary = simulation.workers[carrier_id] as Dictionary
	carrier["carrying"] = "plank"
	for _tick: int in range(3):
		simulation.step_tick()

	_expect(simulation.stored_amount("plank") == 1, "Carrier should deliver from beside an occupied building entrance")
	_expect(String(carrier["carrying"]).is_empty(), "Delivered ware must leave the carrier inventory")


func _test_gardener_selects_and_plants_autonomously() -> void:
	var simulation := LegacyFixture.create(Vector2i(9, 7))
	simulation.place_building("forester_hut", Vector2i(1, 1))
	var gardener_cell := Vector2i(4, 3)
	var north_cell := Vector2i(4, 2)
	var west_cell := Vector2i(3, 3)
	var east_cell := Vector2i(5, 3)
	var expected_target := Vector2i(4, 4)
	simulation.grid.set_base_terrain(north_cell, "water")
	simulation.add_tree(west_cell)
	simulation.place_road(east_cell)
	var warehouse_id: int = simulation.place_building("warehouse", Vector2i(7, 5))
	var warehouse_entrance: Vector2i = (
		(simulation.buildings[warehouse_id] as Dictionary)["entrance"] as Vector2i
	)
	var gardener_id: int = simulation.spawn_worker(gardener_cell, "gardener")
	var gardener: Dictionary = simulation.workers[gardener_id] as Dictionary

	_expect(not simulation.can_plant_sapling(north_cell), "Gardener planting must reject forbidden terrain")
	_expect(not simulation.can_plant_sapling(west_cell), "Gardener planting must reject an existing tree")
	_expect(not simulation.can_plant_sapling(east_cell), "Gardener planting must reject road overlays")
	_expect(not simulation.can_plant_sapling(gardener_cell), "Gardener planting must reject occupied cells")
	_expect(not simulation.can_plant_sapling(warehouse_entrance), "Gardener planting must preserve building entrances")

	var initial_tree_count: int = simulation.trees.size()
	simulation.step_tick()
	_expect(String(gardener["action"]) == "plant_sapling", "An idle gardener should autonomously start a planting job")
	_expect(gardener["plant_target"] as Vector2i == expected_target, "Equal-cost planting sites should use deterministic cell ordering")
	_expect(int(simulation.planting_reservations.get(expected_target, 0)) == gardener_id, "An assigned planting site must be exclusively reserved")

	var planted_tree_id: int = 0
	for _tick: int in range(100):
		simulation.step_tick()
		planted_tree_id = simulation._tree_at(expected_target)
		if planted_tree_id != 0:
			break
	_expect(planted_tree_id != 0, "Gardener should walk to the selected site and plant a sapling")
	if planted_tree_id != 0:
		var planted_tree: Dictionary = simulation.trees[planted_tree_id] as Dictionary
		_expect(simulation.tree_growth_stage(planted_tree) == SimulationWorldClass.TREE_STAGE_SAPLING, "A newly planted tree must begin as a sapling")
	_expect(not simulation.planting_reservations.has(expected_target), "Completed planting must release the site reservation")
	var configured_cooldown: int = int(simulation.catalog.unit("gardener")["plant_cooldown_ticks"])
	_expect(int(gardener["planting_cooldown"]) == configured_cooldown, "Gardener should enter its data-driven planting cooldown")
	for _tick: int in range(10):
		simulation.step_tick()
	_expect(simulation.trees.size() == initial_tree_count + 1, "Planting cooldown must prevent immediate map filling")


func _test_gardener_waits_and_retries_without_a_site() -> void:
	var simulation := LegacyFixture.create(Vector2i(3, 3))
	var gardener_cell := Vector2i(1, 1)
	for y: int in range(simulation.grid.size.y):
		for x: int in range(simulation.grid.size.x):
			simulation.grid.set_base_terrain(Vector2i(x, y), "water")
	simulation.grid.set_base_terrain(gardener_cell, "grass")
	simulation.grid.set_base_terrain(Vector2i(0, 0), "grass")
	simulation.grid.set_base_terrain(Vector2i(0, 1), "grass")
	simulation.place_building("forester_hut", Vector2i(0, 0))
	var gardener_id: int = simulation.spawn_worker(gardener_cell, "gardener")
	var gardener: Dictionary = simulation.workers[gardener_id] as Dictionary
	simulation.step_tick()
	var retry_ticks: int = int(simulation.catalog.unit("gardener")["search_retry_ticks"])
	_expect(String(gardener["state"]) == "idle", "Gardener should safely remain idle when no planting site is reachable")
	_expect(int(gardener["planting_cooldown"]) == retry_ticks, "Failed planting search should use a bounded retry interval")
	_expect(simulation.planting_reservations.is_empty(), "Failed search must not leak a planting reservation")

	var opened_cell := Vector2i(1, 0)
	simulation.grid.set_base_terrain(opened_cell, "grass")
	for _tick: int in range(retry_ticks - 1):
		simulation.step_tick()
	_expect(String(gardener["state"]) == "idle", "Gardener should honor the full retry delay after a failed search")
	simulation.step_tick()
	_expect(String(gardener["action"]) == "plant_sapling", "Gardener should automatically search again after the retry delay")
	_expect(gardener["plant_target"] as Vector2i == opened_cell, "Retried search should take the newly reachable valid site")


func _test_multiple_gardeners_reserve_distinct_sites() -> void:
	var simulation := LegacyFixture.create(Vector2i(5, 4))
	simulation.place_building("forester_hut", Vector2i(0, 1))
	simulation.place_building("forester_hut", Vector2i(4, 1))
	var first_id: int = simulation.spawn_worker(Vector2i(2, 1), "gardener")
	var second_id: int = simulation.spawn_worker(Vector2i(2, 2), "gardener")
	simulation.step_tick()
	var first: Dictionary = simulation.workers[first_id] as Dictionary
	var second: Dictionary = simulation.workers[second_id] as Dictionary
	var first_target: Vector2i = first["plant_target"] as Vector2i
	var second_target: Vector2i = second["plant_target"] as Vector2i
	_expect(first_target == Vector2i(2, 0), "Lower gardener ID should choose the canonical nearest site first")
	_expect(second_target != first_target, "Concurrent gardeners must never claim the same planting site")
	_expect(simulation.planting_reservations.size() == 2, "Every active gardener should own one exclusive planting reservation")
	_expect(not simulation.place_road(first_target), "Road commands must not invalidate a reserved planting site")
	_expect(not simulation.can_place_building("warehouse", first_target), "Buildings must reject a reserved planting site")
	_expect(not simulation.set_base_terrain(first_target, "dirt"), "Terrain authoring must preserve a reserved planting site")


func _test_tree_growth_gates_lumberjack_harvest() -> void:
	var simulation := LegacyFixture.create(Vector2i(9, 7))
	var hut_id: int = simulation.place_building("lumber_hut", Vector2i(1, 1))
	var tree_cell := Vector2i(5, 3)
	var tree_id: int = simulation._create_tree(tree_cell, 1, 0)
	var lumberjack_id: int = simulation.spawn_worker(Vector2i(4, 3), "lumberjack", hut_id)
	var lumberjack: Dictionary = simulation.workers[lumberjack_id] as Dictionary
	var tree: Dictionary = simulation.trees[tree_id] as Dictionary

	for _tick: int in range(SimulationWorldClass.TREE_YOUNG_AGE_TICKS - 1):
		simulation.step_tick()
	_expect(simulation.tree_growth_stage(tree) == SimulationWorldClass.TREE_STAGE_SAPLING, "Sapling phase should last its exact configured tick range")
	_expect(int(lumberjack["source_id"]) == 0, "Lumberjack must ignore saplings")
	simulation.step_tick()
	_expect(simulation.tree_growth_stage(tree) == SimulationWorldClass.TREE_STAGE_YOUNG, "Tree should enter the young phase on the exact boundary tick")

	for _tick: int in range(
		SimulationWorldClass.TREE_MATURE_AGE_TICKS
		- SimulationWorldClass.TREE_YOUNG_AGE_TICKS
		- 1
	):
		simulation.step_tick()
	_expect(simulation.tree_growth_stage(tree) == SimulationWorldClass.TREE_STAGE_YOUNG, "Young trees must remain visually and logically distinct before maturity")
	_expect(int(lumberjack["source_id"]) == 0, "Lumberjack must ignore every immature growth phase")
	simulation.step_tick()
	_expect(simulation.is_tree_mature(tree), "Tree should become mature on its exact maturity tick")
	_expect(int(lumberjack["source_id"]) == tree_id, "A mature tree should immediately become ordinary lumberjack work")

	for _tick: int in range(100):
		simulation.step_tick()
		if not simulation.trees.has(tree_id):
			break
	_expect(not simulation.trees.has(tree_id), "Existing lumberjack logic should be able to fell the mature planted tree")


func _test_gardener_growth_save_round_trip_and_v4_migration() -> void:
	var source := LegacyFixture.create(Vector2i(7, 7))
	var tree_id: int = source._create_tree(Vector2i(2, 2), 3, 37)
	var gardener_id: int = source.spawn_worker(Vector2i(5, 5), "gardener")
	(source.workers[gardener_id] as Dictionary)["planting_cooldown"] = 29
	var snapshot: Dictionary = source.to_data()
	_expect(int(snapshot["version"]) == SimulationWorldClass.SAVE_VERSION, "Gardener growth snapshots should use the current save schema")

	var restored := LegacyFixture.create()
	_expect(restored.from_data(snapshot), "Version 5 should restore gardeners and partial tree growth")
	var restored_tree: Dictionary = restored.trees[tree_id] as Dictionary
	var restored_gardener: Dictionary = restored.workers[gardener_id] as Dictionary
	_expect(int(restored_tree["age_ticks"]) == 37, "Save must preserve exact tree growth age")
	_expect(String(restored_gardener["type"]) == "gardener", "Save must preserve the gardener profession")
	_expect(int(restored_gardener["planting_cooldown"]) == 29, "Save must preserve autonomous planting cooldown")
	restored.step_tick()
	_expect(int(restored_tree["age_ticks"]) == 38, "Restored tree growth should resume on the next simulation tick")

	var invalid_age: Dictionary = snapshot.duplicate(true)
	((invalid_age["trees"] as Array)[0] as Dictionary)["age_ticks"] = SimulationWorldClass.TREE_MATURE_AGE_TICKS + 1
	_expect(not LegacyFixture.create().from_data(invalid_age), "Version 5 must reject out-of-range tree ages")

	var version_4_data: Dictionary = snapshot.duplicate(true)
	version_4_data["version"] = 4
	for tree_variant: Variant in version_4_data["trees"]:
		(tree_variant as Dictionary).erase("age_ticks")
	for worker_variant: Variant in version_4_data["workers"]:
		(worker_variant as Dictionary).erase("planting_cooldown")
	var migrated := LegacyFixture.create()
	_expect(migrated.from_data(version_4_data), "Version 4 saves should migrate into the growth-aware schema")
	_expect(migrated.is_tree_mature(migrated.trees[tree_id] as Dictionary), "Pre-growth save trees must migrate as mature and remain harvestable")
	_expect(String((migrated.workers[gardener_id] as Dictionary)["type"]) == "gardener", "Compatible saves should retain known gardener unit IDs")

	var active_source := LegacyFixture.create(Vector2i(5, 5))
	active_source.place_building("forester_hut", Vector2i(0, 0))
	var active_gardener_id: int = active_source.spawn_worker(Vector2i(2, 2), "gardener")
	active_source.step_tick()
	_expect(not active_source.planting_reservations.is_empty(), "Fixture should save while autonomous planting is active")
	var active_restored := LegacyFixture.create()
	_expect(active_restored.from_data(active_source.to_data()), "An active autonomous gardener snapshot should load")
	var active_restored_gardener: Dictionary = active_restored.workers[active_gardener_id] as Dictionary
	_expect(active_restored.planting_reservations.is_empty(), "Transient planting reservations must not survive save/load as ghosts")
	_expect(String(active_restored_gardener["state"]) == "idle", "Active autonomous work should reload at the standard idle replan boundary")
	active_restored.step_tick()
	_expect(String(active_restored_gardener["action"]) == "plant_sapling", "Loaded gardener should autonomously rebuild its planting work")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
