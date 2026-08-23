extends Node

const TaskBoardClass = preload("res://scripts/simulation/task_board.gd")
const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const GridPathfinderClass = preload("res://scripts/simulation/grid_pathfinder.gd")
const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const MainViewClass = preload("res://scripts/view/main_view.gd")

var failures: Array[String] = []


func _ready() -> void:
	_test_task_reservation_is_exclusive()
	_test_pathfinder_detours_and_prefers_roads()
	_test_pathfinder_chooses_longer_faster_road()
	_test_surface_wear_and_speed_tiers()
	_test_real_carrier_steps_form_contiguous_trail()
	_test_swap_waits_for_both_steps_and_uses_each_surface()
	_test_worker_replans_when_building_invalidates_path()
	_test_carrier_replans_around_blocker_to_occupied_entrance()
	_test_roles_split_harvest_and_transport()
	_test_economy_reaches_stored_planks()
	_test_save_round_trip()
	_test_v1_save_migrates_roles()
	_test_worker_interpolation_never_rewinds()
	_test_blocked_worker_selects_another_source()
	_test_blocked_chokepoint_selects_nearby_source()
	_test_carrier_uses_occupied_entrance_from_adjacent_cell()

	if failures.is_empty():
		print("TEST RESULT: 16/16 passed")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("TEST RESULT: %d failure(s)" % failures.size())
		get_tree().quit(1)


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


func _test_surface_wear_and_speed_tiers() -> void:
	var simulation := SimulationWorldClass.new(Vector2i(5, 5))
	var cell := Vector2i(2, 2)
	var grass_ticks: int = simulation.grid.movement_duration_ticks(cell)
	var threshold: int = simulation.grid.carrier_passes_to_form_trail()
	for _pass: int in range(threshold - 1):
		simulation.grid.record_carrier_traffic(cell)
	_expect(simulation.grid.surface_at(cell) == "grass", "A trail must not form before the pass threshold")
	simulation.grid.record_carrier_traffic(cell)
	var dirt_ticks: int = simulation.grid.movement_duration_ticks(cell)
	_expect(simulation.grid.surface_at(cell) == "dirt", "Repeated carrier traffic should form a dirt trail")

	var lumberjack: Dictionary = {"type": "lumberjack"}
	var untouched_cell := Vector2i(1, 1)
	simulation._record_worker_traffic(lumberjack, untouched_cell)
	_expect(not simulation.grid.traffic_wear.has(untouched_cell), "Lumberjack steps must not trample carrier trails")

	simulation.grid.add_road(cell)
	var stone_ticks: int = simulation.grid.movement_duration_ticks(cell)
	_expect(grass_ticks > dirt_ticks and dirt_ticks > stone_ticks, "Movement must satisfy grass > dirt > stone duration")
	_expect(simulation.grid.surface_at(cell) == "stone", "A player road should replace dirt with stone")
	_expect(not simulation.grid.traffic_wear.has(cell), "Stone road construction should clear obsolete trail wear")


func _test_real_carrier_steps_form_contiguous_trail() -> void:
	var simulation := SimulationWorldClass.new(Vector2i(11, 7))
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
				if simulation.grid.surface_at(Vector2i(x, 3)) != "dirt":
					all_corridor_dirt = false
					break
			if all_corridor_dirt:
				break
	_expect(int(hut_outputs["log"]) == 0, "Carrier should collect each offered hut log")
	for x: int in range(3, 7):
		_expect(
			simulation.grid.surface_at(Vector2i(x, 3)) == "dirt",
			"Repeated real carrier steps should form a contiguous hut-to-sawmill trail"
		)


func _test_swap_waits_for_both_steps_and_uses_each_surface() -> void:
	var simulation := SimulationWorldClass.new(Vector2i(4, 3))
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
	var simulation := SimulationWorldClass.new(Vector2i(5, 3))
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
	var simulation := SimulationWorldClass.new(Vector2i(8, 5))
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
	var simulation := SimulationWorldClass.new(Vector2i(13, 8))
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
	_expect(
		simulation._accepted_tasks_for_worker(carrier) == SimulationWorldClass.CARRIER_TASKS,
		"Carrier should accept only building-to-building transport"
	)
	for _tick: int in range(1200):
		simulation.step_tick()
		if simulation.stored_amount("plank") > 0:
			break
	_expect(simulation.stored_amount("plank") > 0, "Carrier should move hut log → sawmill and plank → warehouse")


func _test_economy_reaches_stored_planks() -> void:
	var simulation: SimulationWorldClass = SimulationWorldClass.new()
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
	var source: SimulationWorldClass = SimulationWorldClass.new()
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
	var test_path := "user://medieval_economy_rts_test_save.json"
	var saved: bool = SaveSystemClass.save_world(source, test_path)
	var restored: SimulationWorldClass = SimulationWorldClass.new()
	var loaded: bool = SaveSystemClass.load_world(restored, test_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	_expect(saved, "SaveSystem should write a JSON snapshot")
	_expect(loaded, "Versioned simulation snapshot should load")
	_expect(restored.tick == source.tick, "Loaded tick must match saved tick")
	_expect(restored.buildings.size() == source.buildings.size(), "Loaded buildings must match saved buildings")
	_expect(restored.trees.size() == source.trees.size(), "Loaded tree state must match saved tree state")
	_expect(restored.grid.dirt_trails.has(saved_dirt_cell), "Save v2 must preserve formed dirt trails")
	_expect(restored.grid.roads.has(saved_road_cell), "Save v2 must preserve player-built stone roads")
	_expect(
		int(restored.grid.traffic_wear.get(partial_wear_cell, 0)) == expected_partial_wear,
		"Save v2 must preserve exact partial wear below the trail threshold"
	)
	_expect(not restored.grid.dirt_trails.has(partial_wear_cell), "Partial saved wear must not load as a completed trail")
	var restored_types: Array[String] = []
	for worker_variant: Variant in restored.workers.values():
		restored_types.append(String((worker_variant as Dictionary)["type"]))
	_expect(restored_types.has("lumberjack") and restored_types.has("carrier"), "Save v2 must preserve worker roles")
	for _tick: int in range(1400):
		restored.step_tick()
	_expect(restored.stored_amount("plank") > 0, "Loaded workers should resume deliveries and production")


func _test_v1_save_migrates_roles() -> void:
	var source := SimulationWorldClass.new()
	source.setup_demo()
	var legacy_data: Dictionary = source.to_data()
	legacy_data["version"] = 1
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
		var outputs: Dictionary = building_data["outputs"] as Dictionary
		outputs.erase("log")

	var restored := SimulationWorldClass.new()
	var loaded: bool = restored.from_data(legacy_data)
	_expect(loaded, "Version 1 saves should migrate instead of being rejected")
	var worker_ids: Array = restored.workers.keys()
	worker_ids.sort()
	_expect(String((restored.workers[int(worker_ids[0])] as Dictionary)["type"]) == "lumberjack", "First v1 worker should migrate to lumberjack")
	_expect(String((restored.workers[int(worker_ids[1])] as Dictionary)["type"]) == "carrier", "Remaining v1 workers should migrate to carriers")
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
	var simulation := SimulationWorldClass.new(Vector2i(10, 8))
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
	var simulation := SimulationWorldClass.new(Vector2i(8, 7))
	simulation.place_building("lumber_hut", Vector2i(1, 1))
	for y: int in range(7):
		if y != 3:
			simulation.grid.block(Vector2i(3, y), -100 - y)
	var far_tree_id: int = simulation.add_tree(Vector2i(5, 3), 3)
	var nearby_tree_id: int = simulation.add_tree(Vector2i(1, 5), 3)
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
	var simulation := SimulationWorldClass.new(Vector2i(8, 8))
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
