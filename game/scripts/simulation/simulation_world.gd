class_name SimulationWorld
extends RefCounted

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const GridPathfinderClass = preload("res://scripts/simulation/grid_pathfinder.gd")
const TaskBoardClass = preload("res://scripts/simulation/task_board.gd")
const WorldSnapshotClass = preload("res://scripts/simulation/world_snapshot.gd")

const DEFAULT_MAP_SIZE := Vector2i(20, 16)
const LUMBERJACK_TASKS: Array[String] = ["harvest_tree"]
const CARRIER_TASKS: Array[String] = ["transport_log", "transport_plank"]
const BLOCKED_REPLAN_TICKS: int = 6
const TREE_STAGE_SAPLING: int = 0
const TREE_STAGE_YOUNG: int = 1
const TREE_STAGE_MATURE: int = 2
const TREE_YOUNG_AGE_TICKS: int = 80
const TREE_MATURE_AGE_TICKS: int = 200
const SAVE_VERSION: int = WorldSnapshotClass.SAVE_VERSION
const MAX_MAP_SIZE: Vector2i = WorldSnapshotClass.MAX_MAP_SIZE

var tick: int = 0
var catalog: DefinitionCatalogClass
var grid: GridMapSimClass
var task_board: TaskBoardClass
var buildings: Dictionary = {}
var trees: Dictionary = {}
var workers: Dictionary = {}
var tile_reservations: Dictionary = {}
var planting_reservations: Dictionary = {}
var event_log: Array[String] = []

var _next_entity_id: int = 1
var _workers_updated_this_tick: Dictionary = {}


func _init(map_size: Vector2i = DEFAULT_MAP_SIZE) -> void:
	catalog = DefinitionCatalogClass.new()
	grid = GridMapSimClass.new(map_size)
	grid.configure_movement(catalog.movement)
	task_board = TaskBoardClass.new()


func setup_demo() -> void:
	_setup_demo_terrain()
	for tree_cell: Vector2i in [
		Vector2i(7, 3), Vector2i(9, 3), Vector2i(11, 4), Vector2i(13, 3),
		Vector2i(15, 5), Vector2i(16, 7), Vector2i(14, 9), Vector2i(11, 11),
	]:
		add_tree(tree_cell, 3)

	place_building("warehouse", Vector2i(3, 8))
	var lumber_hut_id: int = place_building("lumber_hut", Vector2i(7, 8))
	place_building("sawmill", Vector2i(11, 8))
	spawn_worker(Vector2i(5, 10), "lumberjack", lumber_hut_id)
	spawn_worker(Vector2i(7, 10), "carrier")
	spawn_worker(Vector2i(9, 10), "gardener")
	_push_event("Workers harvest, transport, and autonomously replant the woodland.")


func step_tick() -> void:
	tick += 1
	_workers_updated_this_tick.clear()
	_update_worker_visual_progress()
	_tick_trees()
	_tick_buildings()
	_generate_tasks()
	var worker_ids: Array = workers.keys()
	worker_ids.sort()
	for worker_id_variant: Variant in worker_ids:
		var worker_id: int = int(worker_id_variant)
		if _workers_updated_this_tick.has(worker_id):
			continue
		_workers_updated_this_tick[worker_id] = true
		_tick_worker(worker_id)


func add_tree(cell: Vector2i, amount: int = 3) -> int:
	if not grid.allows_trees(cell) or _tree_at(cell) != 0:
		return 0
	return _create_tree(cell, amount, TREE_MATURE_AGE_TICKS)


func can_plant_sapling(cell: Vector2i) -> bool:
	return _can_plant_sapling(cell, 0)


func tree_growth_stage(tree: Dictionary) -> int:
	var age_ticks: int = int(tree.get("age_ticks", TREE_MATURE_AGE_TICKS))
	if age_ticks < TREE_YOUNG_AGE_TICKS:
		return TREE_STAGE_SAPLING
	if age_ticks < TREE_MATURE_AGE_TICKS:
		return TREE_STAGE_YOUNG
	return TREE_STAGE_MATURE


func is_tree_mature(tree: Dictionary) -> bool:
	return tree_growth_stage(tree) == TREE_STAGE_MATURE


func _create_tree(cell: Vector2i, amount: int, age_ticks: int) -> int:
	var entity_id: int = _take_entity_id()
	trees[entity_id] = {
		"id": entity_id,
		"position": cell,
		"amount": maxi(1, amount),
		"age_ticks": clampi(age_ticks, 0, TREE_MATURE_AGE_TICKS),
	}
	return entity_id


func spawn_worker(cell: Vector2i, unit_type: String = "carrier", home_id: int = 0) -> int:
	if (
		catalog.unit(unit_type).is_empty()
		or not grid.is_walkable(cell)
		or tile_reservations.has(cell)
		or planting_reservations.has(cell)
	):
		return 0
	if unit_type == "lumberjack" and home_id == 0:
		home_id = _nearest_building("lumber_hut", cell)
	var entity_id: int = _take_entity_id()
	workers[entity_id] = {
		"id": entity_id,
		"type": unit_type,
		"home_id": home_id,
		"position": cell,
		"previous_position": cell,
		"state": "idle",
		"action": "",
		"task_id": 0,
		"source_id": 0,
		"destination_id": 0,
		"carrying": "",
		"path": [],
		"path_index": 0,
		"move_cooldown": 0,
		"work_remaining": 0,
		"visual_progress_ticks": 1,
		"visual_duration_ticks": 1,
		"blocked_ticks": 0,
		"target_cell": cell,
		"plant_target": Vector2i(-1, -1),
		"planting_cooldown": 0,
	}
	tile_reservations[cell] = entity_id
	return entity_id


func can_place_building(building_type: String, cell: Vector2i) -> bool:
	if catalog.building(building_type).is_empty() or not grid.is_buildable(cell):
		return false
	if _tree_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	for building_variant: Variant in buildings.values():
		var existing_building: Dictionary = building_variant as Dictionary
		if existing_building["entrance"] as Vector2i == cell:
			return false
	return _find_entrance(cell) != Vector2i(-1, -1)


func place_building(building_type: String, cell: Vector2i) -> int:
	if not can_place_building(building_type, cell):
		return 0
	var entrance: Vector2i = _find_entrance(cell)
	var entity_id: int = _take_entity_id()
	buildings[entity_id] = {
		"id": entity_id,
		"type": building_type,
		"position": cell,
		"entrance": entrance,
		"storage": {"log": 0, "plank": 0, "stone": 0},
		"inputs": {"log": 0},
		"outputs": {"log": 0, "plank": 0},
		"process_remaining": 0,
		"training_queue": [],
		"training_remaining": 0,
	}
	grid.block(cell, entity_id)
	_push_event("Built %s." % String(catalog.building(building_type).get("display_name", building_type)))
	return entity_id


func place_road(cell: Vector2i) -> bool:
	if _tree_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	return grid.add_road(cell)


func set_base_terrain(cell: Vector2i, terrain_id: String) -> bool:
	# Authoring commands must guard entity layers that GridMapSim intentionally
	# does not own. Loading and initial map setup may use the grid setter before
	# entities exist.
	if _tree_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	for building_variant: Variant in buildings.values():
		if ((building_variant as Dictionary)["entrance"] as Vector2i) == cell:
			return false
	return grid.set_base_terrain(cell, terrain_id)


func stored_amount(resource_id: String) -> int:
	var total: int = 0
	for building_variant: Variant in buildings.values():
		var building: Dictionary = building_variant as Dictionary
		if String(building["type"]) == "warehouse":
			var storage: Dictionary = building["storage"] as Dictionary
			total += int(storage.get(resource_id, 0))
	return total


func pipeline_amount(resource_id: String) -> int:
	var total: int = 0
	for worker_variant: Variant in workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		if String(worker["carrying"]) == resource_id:
			total += 1
	for building_variant: Variant in buildings.values():
		var building: Dictionary = building_variant as Dictionary
		var inputs: Dictionary = building["inputs"] as Dictionary
		var outputs: Dictionary = building["outputs"] as Dictionary
		total += int(inputs.get(resource_id, 0)) + int(outputs.get(resource_id, 0))
	return total


func has_building(building_type: String) -> bool:
	return _first_building(building_type) != 0


func building_id_at(cell: Vector2i) -> int:
	var building_ids: Array = buildings.keys()
	building_ids.sort()
	for building_id_variant: Variant in building_ids:
		var building_id: int = int(building_id_variant)
		var building: Dictionary = buildings[building_id] as Dictionary
		if building["position"] as Vector2i == cell:
			return building_id
	return 0


func queue_unit_training(building_id: int, unit_type: String) -> bool:
	if not buildings.has(building_id):
		return false
	var unit_definition: Dictionary = catalog.unit(unit_type)
	if unit_definition.is_empty():
		return false
	var building: Dictionary = buildings[building_id] as Dictionary
	var building_definition: Dictionary = catalog.building(String(building["type"]))
	var trainable_units: Array = building_definition.get("trains", []) as Array
	if not trainable_units.has(unit_type):
		return false
	var training_queue: Array = building.get("training_queue", []) as Array
	var queue_capacity: int = maxi(1, int(building_definition.get("queue_capacity", 1)))
	if training_queue.size() >= queue_capacity:
		return false
	training_queue.append(unit_type)
	building["training_queue"] = training_queue
	if training_queue.size() == 1:
		building["training_remaining"] = _training_ticks_for(unit_type)
	_push_event(
		"Queued %s at %s." % [
			String(unit_definition.get("display_name", unit_type)),
			String(building_definition.get("display_name", building["type"])),
		]
	)
	return true


func to_data() -> Dictionary:
	return WorldSnapshotClass.to_data(self)


func from_data(data: Dictionary) -> bool:
	var staged_world: Variant = (get_script() as Script).new()
	staged_world.catalog = catalog
	if not WorldSnapshotClass.load_into(staged_world, data):
		return false
	tick = staged_world.tick
	catalog = staged_world.catalog
	grid = staged_world.grid
	task_board = staged_world.task_board
	buildings = staged_world.buildings
	trees = staged_world.trees
	workers = staged_world.workers
	tile_reservations = staged_world.tile_reservations
	planting_reservations = staged_world.planting_reservations
	event_log = staged_world.event_log
	_next_entity_id = staged_world._next_entity_id
	return true


func _tick_trees() -> void:
	var tree_ids: Array = trees.keys()
	tree_ids.sort()
	for tree_id_variant: Variant in tree_ids:
		var tree_id: int = int(tree_id_variant)
		var tree: Dictionary = trees[tree_id] as Dictionary
		if is_tree_mature(tree):
			continue
		var previous_stage: int = tree_growth_stage(tree)
		tree["age_ticks"] = mini(
			TREE_MATURE_AGE_TICKS,
			int(tree.get("age_ticks", 0)) + 1
		)
		var current_stage: int = tree_growth_stage(tree)
		if current_stage == previous_stage:
			continue
		if current_stage == TREE_STAGE_YOUNG:
			_push_event("Sapling #%d grew into a young tree." % tree_id)
		elif current_stage == TREE_STAGE_MATURE:
			_push_event("Tree #%d matured and can now be harvested." % tree_id)


func _tick_buildings() -> void:
	var building_ids: Array = buildings.keys()
	building_ids.sort()
	for building_id_variant: Variant in building_ids:
		var building: Dictionary = buildings[int(building_id_variant)] as Dictionary
		if String(building["type"]) == "sawmill":
			var recipe: Dictionary = catalog.recipe("saw_planks")
			var remaining: int = int(building["process_remaining"])
			if remaining > 0:
				remaining -= 1
				building["process_remaining"] = remaining
				if remaining == 0:
					var outputs: Dictionary = building["outputs"] as Dictionary
					outputs["plank"] = int(outputs["plank"]) + 1
					_push_event("Sawmill produced a plank.")
			else:
				var inputs: Dictionary = building["inputs"] as Dictionary
				if int(inputs["log"]) > 0:
					inputs["log"] = int(inputs["log"]) - 1
					building["process_remaining"] = int(recipe.get("duration_ticks", 60))
		_tick_unit_training(building)


func _tick_unit_training(building: Dictionary) -> void:
	var building_definition: Dictionary = catalog.building(String(building["type"]))
	if (building_definition.get("trains", []) as Array).is_empty():
		return
	var training_queue: Array = building.get("training_queue", []) as Array
	if training_queue.is_empty():
		building["training_remaining"] = 0
		return
	var remaining: int = maxi(0, int(building.get("training_remaining", 0)))
	if remaining > 0:
		remaining -= 1
		building["training_remaining"] = remaining
	if remaining > 0:
		return

	var spawn_cell: Vector2i = _find_unit_spawn_cell(building)
	if spawn_cell == Vector2i(-1, -1):
		return
	var unit_type: String = String(training_queue[0])
	if spawn_worker(spawn_cell, unit_type) == 0:
		return
	training_queue.pop_front()
	building["training_queue"] = training_queue
	building["training_remaining"] = (
		0 if training_queue.is_empty() else _training_ticks_for(String(training_queue[0]))
	)
	_push_event(
		"%s trained a %s." % [
			String(building_definition.get("display_name", building["type"])),
			String(catalog.unit(unit_type).get("display_name", unit_type)),
		]
	)


func _generate_tasks() -> void:
	if has_building("lumber_hut"):
		var tree_ids: Array = trees.keys()
		tree_ids.sort()
		for tree_id_variant: Variant in tree_ids:
			var tree_id: int = int(tree_id_variant)
			var tree: Dictionary = trees[tree_id] as Dictionary
			if int(tree["amount"]) > 0 and is_tree_mature(tree):
				task_board.create_task("harvest_tree", "tree:%d" % tree_id, tree["position"] as Vector2i, tree_id)

	if has_building("sawmill") or has_building("warehouse"):
		var hut_ids: Array = buildings.keys()
		hut_ids.sort()
		for hut_id_variant: Variant in hut_ids:
			var hut_id: int = int(hut_id_variant)
			var hut: Dictionary = buildings[hut_id] as Dictionary
			if String(hut["type"]) != "lumber_hut":
				continue
			var hut_outputs: Dictionary = hut["outputs"] as Dictionary
			if int(hut_outputs.get("log", 0)) > 0:
				task_board.create_task(
					"transport_log",
					"lumber_hut:%d:log" % hut_id,
					hut["entrance"] as Vector2i,
					hut_id
				)

	if has_building("warehouse"):
		var building_ids: Array = buildings.keys()
		building_ids.sort()
		for building_id_variant: Variant in building_ids:
			var building_id: int = int(building_id_variant)
			var building: Dictionary = buildings[building_id] as Dictionary
			if String(building["type"]) == "sawmill":
				var outputs: Dictionary = building["outputs"] as Dictionary
				if int(outputs["plank"]) > 0:
					task_board.create_task(
						"transport_plank",
						"sawmill:%d:plank" % building_id,
						building["entrance"] as Vector2i,
						building_id
					)


func _tick_worker(worker_id: int) -> void:
	var worker: Dictionary = workers[worker_id] as Dictionary
	var state: String = String(worker["state"])
	if state == "idle":
		if String(worker["type"]) == "gardener":
			_tick_idle_gardener(worker)
		elif String(worker["carrying"]).is_empty():
			_assign_task(worker)
		else:
			if int(worker["blocked_ticks"]) > 0:
				worker["blocked_ticks"] = int(worker["blocked_ticks"]) - 1
			else:
				_resume_carried_ware(worker)
	elif state == "moving":
		_advance_worker(worker)
	elif state == "working":
		var remaining: int = int(worker["work_remaining"]) - 1
		worker["work_remaining"] = remaining
		if remaining <= 0:
			_finish_work(worker)


func _tick_idle_gardener(worker: Dictionary) -> void:
	var cooldown: int = maxi(0, int(worker.get("planting_cooldown", 0)))
	if cooldown > 0:
		cooldown -= 1
		worker["planting_cooldown"] = cooldown
		if cooldown > 0:
			return
	var worker_id: int = int(worker["id"])
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	for reserved_cell_variant: Variant in planting_reservations.keys():
		var reserved_cell: Vector2i = reserved_cell_variant as Vector2i
		if int(planting_reservations[reserved_cell]) != worker_id:
			blockers[reserved_cell] = true
	var goal_test: Callable = Callable(self, "_is_available_planting_goal").bind(worker_id)
	var path: Array[Vector2i] = GridPathfinderClass.find_path_to_nearest(
		grid,
		worker["position"] as Vector2i,
		goal_test,
		blockers
	)
	if path.is_empty():
		worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
		return
	var target: Vector2i = path[path.size() - 1]
	planting_reservations[target] = worker_id
	worker["plant_target"] = target
	worker["action"] = "plant_sapling"
	_begin_worker_move(worker, path, target)


func _is_available_planting_goal(cell: Vector2i, _worker_id: int) -> bool:
	return can_plant_sapling(cell)


func _gardener_timing(worker: Dictionary, field: String, fallback: int) -> int:
	var definition: Dictionary = catalog.unit(String(worker["type"]))
	return maxi(1, int(definition.get(field, fallback)))


func _assign_task(worker: Dictionary) -> void:
	var worker_id: int = int(worker["id"])
	var start: Vector2i = worker["position"] as Vector2i
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	var accepted_tasks: Array[String] = _accepted_tasks_for_worker(worker)
	if accepted_tasks.is_empty():
		return
	var best_task: Dictionary = {}
	var best_path: Array[Vector2i] = []
	var best_cost: int = 2147483647
	for candidate: Dictionary in task_board.available_tasks(accepted_tasks):
		var target: Vector2i = candidate["target"] as Vector2i
		var candidate_blockers: Dictionary = blockers.duplicate()
		if String(candidate["kind"]).begins_with("transport_"):
			candidate_blockers.erase(target)
		var candidate_path: Array[Vector2i] = GridPathfinderClass.find_path(
			grid,
			start,
			target,
			candidate_blockers
		)
		if start != target and candidate_path.is_empty():
			continue
		var route_cost: int = GridPathfinderClass.path_cost(grid, candidate_path)
		if route_cost < best_cost or (
			route_cost == best_cost
			and (best_task.is_empty() or int(candidate["id"]) < int(best_task["id"]))
		):
			best_task = candidate
			best_path = candidate_path
			best_cost = route_cost
	if best_task.is_empty():
		return
	var task: Dictionary = task_board.reserve_task(int(best_task["id"]), worker_id)
	if task.is_empty():
		return
	worker["task_id"] = int(task["id"])
	worker["source_id"] = int(task["source_id"])
	match String(task["kind"]):
		"harvest_tree":
			worker["action"] = "harvest"
		"transport_log":
			worker["action"] = "pickup_log"
		"transport_plank":
			worker["action"] = "pickup_plank"
	_begin_worker_move(worker, best_path, task["target"] as Vector2i)


func _advance_worker(worker: Dictionary) -> void:
	var cooldown: int = int(worker["move_cooldown"])
	if cooldown > 0:
		worker["move_cooldown"] = cooldown - 1
		return
	var path: Array = worker["path"] as Array
	var path_index: int = int(worker["path_index"])
	if path_index >= path.size():
		_on_worker_arrived(worker)
		return

	var next_cell: Vector2i = path[path_index] as Vector2i
	var worker_id: int = int(worker["id"])
	if not grid.is_walkable(next_cell):
		worker["blocked_ticks"] = BLOCKED_REPLAN_TICKS
		_reconsider_blocked_worker(worker)
		return
	if tile_reservations.has(next_cell) and int(tile_reservations[next_cell]) != worker_id:
		if _can_interact_from_adjacent(worker, next_cell):
			worker["blocked_ticks"] = 0
			worker["path_index"] = path.size()
			_on_worker_arrived(worker)
		elif _try_swap_workers(worker, int(tile_reservations[next_cell]), next_cell):
			worker["blocked_ticks"] = 0
		else:
			worker["blocked_ticks"] = int(worker.get("blocked_ticks", 0)) + 1
			if int(worker["blocked_ticks"]) >= BLOCKED_REPLAN_TICKS:
				_reconsider_blocked_worker(worker)
		return
	var current: Vector2i = worker["position"] as Vector2i
	tile_reservations.erase(current)
	tile_reservations[next_cell] = worker_id
	worker["previous_position"] = current
	worker["position"] = next_cell
	worker["blocked_ticks"] = 0
	worker["path_index"] = path_index + 1
	var move_duration: int = _movement_duration_for(worker, next_cell)
	_record_worker_traffic(worker, next_cell)
	worker["move_cooldown"] = move_duration - 1
	worker["visual_progress_ticks"] = 0
	worker["visual_duration_ticks"] = move_duration


func _try_swap_workers(worker: Dictionary, other_worker_id: int, next_cell: Vector2i) -> bool:
	# A swap consumes both updates. In particular, a worker whose cooldown was
	# decremented earlier this tick must wait until the next tick to move.
	if not workers.has(other_worker_id) or _workers_updated_this_tick.has(other_worker_id):
		return false
	var other: Dictionary = workers[other_worker_id] as Dictionary
	if String(other["state"]) != "moving" or int(other["move_cooldown"]) > 0:
		return false
	var other_path: Array = other["path"] as Array
	var other_index: int = int(other["path_index"])
	if other_index >= other_path.size():
		return false
	var current: Vector2i = worker["position"] as Vector2i
	if other_path[other_index] as Vector2i != current:
		return false

	_workers_updated_this_tick[other_worker_id] = true
	var worker_id: int = int(worker["id"])
	worker["previous_position"] = current
	worker["position"] = next_cell
	worker["path_index"] = int(worker["path_index"]) + 1
	other["previous_position"] = next_cell
	other["position"] = current
	other["path_index"] = other_index + 1
	tile_reservations[current] = other_worker_id
	tile_reservations[next_cell] = worker_id
	var worker_move_duration: int = _movement_duration_for(worker, next_cell)
	var other_move_duration: int = _movement_duration_for(other, current)
	_record_worker_traffic(worker, next_cell)
	_record_worker_traffic(other, current)
	worker["move_cooldown"] = worker_move_duration - 1
	other["move_cooldown"] = other_move_duration - 1
	worker["blocked_ticks"] = 0
	other["blocked_ticks"] = 0
	worker["visual_progress_ticks"] = 0
	worker["visual_duration_ticks"] = worker_move_duration
	other["visual_progress_ticks"] = 0
	other["visual_duration_ticks"] = other_move_duration
	return true


func _update_worker_visual_progress() -> void:
	for worker_variant: Variant in workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
		worker["visual_duration_ticks"] = duration
		worker["visual_progress_ticks"] = mini(
			duration,
			int(worker.get("visual_progress_ticks", duration)) + 1
		)


func _reconsider_blocked_worker(worker: Dictionary) -> void:
	var worker_id: int = int(worker["id"])
	var current: Vector2i = worker["position"] as Vector2i
	var target: Vector2i = worker.get("target_cell", current) as Vector2i
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	if String(worker["action"]) == "plant_sapling":
		for reserved_cell_variant: Variant in planting_reservations.keys():
			var reserved_cell: Vector2i = reserved_cell_variant as Vector2i
			if int(planting_reservations[reserved_cell]) != worker_id:
				blockers[reserved_cell] = true
	if _worker_allows_occupied_target(worker):
		blockers.erase(target)
	var alternate_path: Array[Vector2i] = GridPathfinderClass.find_path(
		grid,
		current,
		target,
		blockers
	)
	if current == target or not alternate_path.is_empty():
		_begin_worker_move(worker, alternate_path, target)
		return

	if String(worker["action"]) == "plant_sapling":
		_reset_worker(worker)
		worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
		return

	if int(worker["task_id"]) != 0 and String(worker["carrying"]).is_empty():
		task_board.release(int(worker["task_id"]), worker_id)
		_reset_worker(worker)
	elif not String(worker["carrying"]).is_empty():
		# Keep the ware, but discard the unreachable destination. Selection must
		# consider current occupancy as well as permanent terrain/building blocks.
		_reset_worker(worker)
		_resume_carried_ware(worker)
	else:
		worker["blocked_ticks"] = 0


func _temporary_blockers_for(worker_id: int) -> Dictionary:
	var blockers: Dictionary = {}
	for cell_variant: Variant in tile_reservations.keys():
		var cell: Vector2i = cell_variant as Vector2i
		if int(tile_reservations[cell]) != worker_id:
			blockers[cell] = true
	return blockers


func _can_interact_from_adjacent(worker: Dictionary, blocked_cell: Vector2i) -> bool:
	var target_cell: Vector2i = worker.get("target_cell", Vector2i(-1, -1)) as Vector2i
	if blocked_cell != target_cell:
		return false
	if not _worker_allows_occupied_target(worker):
		return false
	var current: Vector2i = worker["position"] as Vector2i
	return absi(current.x - blocked_cell.x) + absi(current.y - blocked_cell.y) == 1


func _worker_allows_occupied_target(worker: Dictionary) -> bool:
	return ["pickup_log", "pickup_plank", "deliver_log", "deliver_plank"].has(String(worker["action"]))


func _resume_carried_ware(worker: Dictionary) -> void:
	var carrying: String = String(worker["carrying"])
	var blockers: Dictionary = _temporary_blockers_for(int(worker["id"]))
	var destination_id: int = 0
	if carrying == "log":
		destination_id = _preferred_log_destination(worker, blockers)
		worker["action"] = "deliver_log"
	elif carrying == "plank":
		destination_id = _nearest_building("warehouse", worker["position"] as Vector2i, blockers)
		worker["action"] = "deliver_plank"
	else:
		return
	worker["destination_id"] = destination_id
	if destination_id != 0:
		var entrance: Vector2i = _building_entrance(destination_id)
		blockers.erase(entrance)
		if _move_worker_to(worker, entrance, blockers):
			return
	_reset_worker(worker)
	worker["blocked_ticks"] = BLOCKED_REPLAN_TICKS


func _on_worker_arrived(worker: Dictionary) -> void:
	match String(worker["action"]):
		"harvest":
			worker["state"] = "working"
			var unit_definition: Dictionary = catalog.unit(String(worker["type"]))
			worker["work_remaining"] = int(unit_definition.get("harvest_ticks", 30))
		"plant_sapling":
			var worker_id: int = int(worker["id"])
			var plant_target: Vector2i = worker.get("plant_target", Vector2i(-1, -1)) as Vector2i
			if not _can_plant_sapling(plant_target, worker_id):
				_reset_worker(worker)
				worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
				return
			worker["state"] = "working"
			worker["work_remaining"] = _gardener_timing(worker, "plant_ticks", 20)
		"pickup_log":
			_pickup_log(worker)
		"pickup_plank":
			_pickup_plank(worker)
		"deliver_log":
			_deliver_log(worker)
		"deliver_plank":
			_deliver_plank(worker)
		_:
			_reset_worker(worker)


func _finish_work(worker: Dictionary) -> void:
	if String(worker["action"]) == "plant_sapling":
		_finish_planting(worker)
		return
	if String(worker["action"]) != "harvest":
		_reset_worker(worker)
		return
	var tree_id: int = int(worker["source_id"])
	if not trees.has(tree_id):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	var tree: Dictionary = trees[tree_id] as Dictionary
	if not is_tree_mature(tree):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	tree["amount"] = int(tree["amount"]) - 1
	if int(tree["amount"]) <= 0:
		trees.erase(tree_id)
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	worker["task_id"] = 0
	worker["carrying"] = "log"
	_resume_carried_ware(worker)


func _finish_planting(worker: Dictionary) -> void:
	var worker_id: int = int(worker["id"])
	var target: Vector2i = worker.get("plant_target", Vector2i(-1, -1)) as Vector2i
	var planted: bool = false
	if _can_plant_sapling(target, worker_id):
		var tree_id: int = _create_tree(target, 3, 0)
		planted = tree_id != 0
		if planted:
			_push_event("Gardener planted sapling #%d." % tree_id)
	_reset_worker(worker)
	worker["planting_cooldown"] = _gardener_timing(
		worker,
		"plant_cooldown_ticks" if planted else "search_retry_ticks",
		80 if planted else 20
	)


func _pickup_log(worker: Dictionary) -> void:
	var hut_id: int = int(worker["source_id"])
	if not buildings.has(hut_id):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	var hut: Dictionary = buildings[hut_id] as Dictionary
	var outputs: Dictionary = hut["outputs"] as Dictionary
	if int(outputs.get("log", 0)) <= 0:
		task_board.complete(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	outputs["log"] = int(outputs["log"]) - 1
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	worker["task_id"] = 0
	worker["carrying"] = "log"
	_resume_carried_ware(worker)


func _pickup_plank(worker: Dictionary) -> void:
	var sawmill_id: int = int(worker["source_id"])
	if not buildings.has(sawmill_id):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	var sawmill: Dictionary = buildings[sawmill_id] as Dictionary
	var outputs: Dictionary = sawmill["outputs"] as Dictionary
	if int(outputs["plank"]) <= 0:
		task_board.complete(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	outputs["plank"] = int(outputs["plank"]) - 1
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	worker["task_id"] = 0
	worker["carrying"] = "plank"
	_resume_carried_ware(worker)


func _deliver_log(worker: Dictionary) -> void:
	var destination_id: int = int(worker["destination_id"])
	var delivered: bool = false
	if buildings.has(destination_id):
		var destination: Dictionary = buildings[destination_id] as Dictionary
		var destination_type: String = String(destination["type"])
		if destination_type == "lumber_hut":
			var outputs: Dictionary = destination["outputs"] as Dictionary
			outputs["log"] = int(outputs.get("log", 0)) + 1
			delivered = true
		elif destination_type == "sawmill":
			var inputs: Dictionary = destination["inputs"] as Dictionary
			inputs["log"] = int(inputs["log"]) + 1
			delivered = true
		elif destination_type == "warehouse":
			var storage: Dictionary = destination["storage"] as Dictionary
			storage["log"] = int(storage["log"]) + 1
			delivered = true
	if delivered:
		worker["carrying"] = ""
	_reset_worker(worker)


func _deliver_plank(worker: Dictionary) -> void:
	var destination_id: int = int(worker["destination_id"])
	var delivered: bool = false
	if buildings.has(destination_id):
		var destination: Dictionary = buildings[destination_id] as Dictionary
		if String(destination["type"]) == "warehouse":
			var storage: Dictionary = destination["storage"] as Dictionary
			storage["plank"] = int(storage["plank"]) + 1
			delivered = true
			_push_event("A plank reached the warehouse.")
	if delivered:
		worker["carrying"] = ""
	_reset_worker(worker)


func _move_worker_to(worker: Dictionary, target: Vector2i, blockers: Dictionary = {}) -> bool:
	var start: Vector2i = worker["position"] as Vector2i
	var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, start, target, blockers)
	if start != target and path.is_empty():
		return false
	_begin_worker_move(worker, path, target)
	return true


func _begin_worker_move(worker: Dictionary, path: Array[Vector2i], target: Vector2i) -> void:
	worker["path"] = path
	worker["path_index"] = 0
	worker["move_cooldown"] = 0
	worker["blocked_ticks"] = 0
	worker["target_cell"] = target
	worker["state"] = "moving"
	if path.is_empty():
		_on_worker_arrived(worker)


func _reset_worker(worker: Dictionary) -> void:
	_release_planting_reservation(worker)
	worker["state"] = "idle"
	worker["action"] = ""
	worker["task_id"] = 0
	worker["source_id"] = 0
	worker["destination_id"] = 0
	worker["path"] = []
	worker["path_index"] = 0
	worker["work_remaining"] = 0
	worker["blocked_ticks"] = 0
	worker["target_cell"] = worker["position"] as Vector2i
	worker["plant_target"] = Vector2i(-1, -1)


func _release_planting_reservation(worker: Dictionary) -> void:
	var target: Vector2i = worker.get("plant_target", Vector2i(-1, -1)) as Vector2i
	var worker_id: int = int(worker["id"])
	if int(planting_reservations.get(target, 0)) == worker_id:
		planting_reservations.erase(target)


func _accepted_tasks_for_worker(worker: Dictionary) -> Array[String]:
	match String(worker["type"]):
		"lumberjack":
			return LUMBERJACK_TASKS
		"carrier":
			return CARRIER_TASKS
	return []


func _movement_duration_for(_worker: Dictionary, destination: Vector2i) -> int:
	return maxi(1, grid.movement_duration_ticks(destination))


func _record_worker_traffic(worker: Dictionary, destination: Vector2i) -> void:
	if String(worker["type"]) == "carrier":
		grid.record_carrier_traffic(destination)


func _preferred_log_destination(worker: Dictionary, blockers: Dictionary = {}) -> int:
	var position: Vector2i = worker["position"] as Vector2i
	if String(worker["type"]) == "lumberjack":
		return _lumberjack_home(worker, blockers)
	var destination_id: int = _nearest_building("sawmill", position, blockers)
	if destination_id == 0:
		destination_id = _nearest_building("warehouse", position, blockers)
	return destination_id


func _lumberjack_home(worker: Dictionary, blockers: Dictionary = {}) -> int:
	var home_id: int = int(worker.get("home_id", 0))
	if buildings.has(home_id) and String((buildings[home_id] as Dictionary)["type"]) == "lumber_hut":
		var position: Vector2i = worker["position"] as Vector2i
		var entrance: Vector2i = _building_entrance(home_id)
		var home_blockers: Dictionary = blockers.duplicate()
		home_blockers.erase(entrance)
		if position == entrance or not GridPathfinderClass.find_path(grid, position, entrance, home_blockers).is_empty():
			return home_id
	var replacement_id: int = _nearest_building("lumber_hut", worker["position"] as Vector2i, blockers)
	worker["home_id"] = replacement_id
	return replacement_id


func _nearest_building(building_type: String, from_cell: Vector2i, blockers: Dictionary = {}) -> int:
	var best_id: int = 0
	var best_cost: int = 2147483647
	var ids: Array = buildings.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var building_id: int = int(id_variant)
		var building: Dictionary = buildings[building_id] as Dictionary
		if String(building["type"]) != building_type:
			continue
		var target: Vector2i = building["entrance"] as Vector2i
		var route_blockers: Dictionary = blockers.duplicate()
		route_blockers.erase(target)
		var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, from_cell, target, route_blockers)
		if from_cell != target and path.is_empty():
			continue
		var route_cost: int = GridPathfinderClass.path_cost(grid, path)
		if route_cost < best_cost or (route_cost == best_cost and (best_id == 0 or building_id < best_id)):
			best_id = building_id
			best_cost = route_cost
	return best_id


func _first_building(building_type: String) -> int:
	var ids: Array = buildings.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var building_id: int = int(id_variant)
		if String((buildings[building_id] as Dictionary)["type"]) == building_type:
			return building_id
	return 0


func _building_entrance(building_id: int) -> Vector2i:
	return (buildings[building_id] as Dictionary)["entrance"] as Vector2i


func _setup_demo_terrain() -> void:
	# Keep the economy corridor open while exposing every base material for
	# projection, scale and transition-mask evaluation.
	for y: int in range(12, 16):
		for x: int in range(0, 6):
			grid.set_base_terrain(Vector2i(x, y), "dirt")
	for y: int in range(12, 16):
		for x: int in range(16, 20):
			grid.set_base_terrain(Vector2i(x, y), "water")
	for y: int in range(0, 3):
		for x: int in range(17, 20):
			grid.set_base_terrain(Vector2i(x, y), "rock")


func _training_ticks_for(unit_type: String) -> int:
	return maxi(1, int(catalog.unit(unit_type).get("training_ticks", 1)))


func _find_unit_spawn_cell(building: Dictionary) -> Vector2i:
	# Unit producers currently have a one-cell footprint. Prefer the authored
	# entrance, then use the remaining sides in the grid's canonical order.
	var position: Vector2i = building["position"] as Vector2i
	var entrance: Vector2i = building["entrance"] as Vector2i
	var candidates: Array[Vector2i] = [entrance]
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		var candidate: Vector2i = position + direction
		if candidate != entrance:
			candidates.append(candidate)
	for candidate: Vector2i in candidates:
		if (
			grid.is_walkable(candidate)
			and not tile_reservations.has(candidate)
			and not planting_reservations.has(candidate)
			and _tree_at(candidate) == 0
		):
			return candidate
	return Vector2i(-1, -1)


func _find_entrance(cell: Vector2i) -> Vector2i:
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if grid.is_walkable(candidate) and not planting_reservations.has(candidate):
			return candidate
	return Vector2i(-1, -1)


func _can_plant_sapling(cell: Vector2i, allowed_worker_id: int) -> bool:
	if not grid.allows_trees(cell) or _tree_at(cell) != 0:
		return false
	if not grid.overlay_at(cell).is_empty():
		return false
	var occupying_worker_id: int = int(tile_reservations.get(cell, 0))
	if occupying_worker_id != 0 and occupying_worker_id != allowed_worker_id:
		return false
	var reserving_worker_id: int = int(planting_reservations.get(cell, 0))
	if reserving_worker_id != 0 and reserving_worker_id != allowed_worker_id:
		return false
	for building_variant: Variant in buildings.values():
		if (building_variant as Dictionary)["entrance"] as Vector2i == cell:
			return false
	return true


func _tree_at(cell: Vector2i) -> int:
	for tree_id_variant: Variant in trees.keys():
		var tree_id: int = int(tree_id_variant)
		if (trees[tree_id] as Dictionary)["position"] as Vector2i == cell:
			return tree_id
	return 0


func _take_entity_id() -> int:
	var result: int = _next_entity_id
	_next_entity_id += 1
	return result


func _push_event(message: String) -> void:
	event_log.push_front("[%d] %s" % [tick, message])
	if event_log.size() > 5:
		event_log.resize(5)
