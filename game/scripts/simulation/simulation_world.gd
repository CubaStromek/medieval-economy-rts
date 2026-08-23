class_name SimulationWorld
extends RefCounted

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const GridPathfinderClass = preload("res://scripts/simulation/grid_pathfinder.gd")
const TaskBoardClass = preload("res://scripts/simulation/task_board.gd")

const DEFAULT_MAP_SIZE := Vector2i(20, 16)
const LUMBERJACK_TASKS: Array[String] = ["harvest_tree"]
const CARRIER_TASKS: Array[String] = ["transport_log", "transport_plank"]
const BLOCKED_REPLAN_TICKS: int = 6
const SAVE_VERSION: int = 2

var tick: int = 0
var catalog: DefinitionCatalogClass
var grid: GridMapSimClass
var task_board: TaskBoardClass
var buildings: Dictionary = {}
var trees: Dictionary = {}
var workers: Dictionary = {}
var tile_reservations: Dictionary = {}
var event_log: Array[String] = []

var _next_entity_id: int = 1


func _init(map_size: Vector2i = DEFAULT_MAP_SIZE) -> void:
	catalog = DefinitionCatalogClass.new()
	grid = GridMapSimClass.new(map_size)
	grid.configure_movement(catalog.movement)
	task_board = TaskBoardClass.new()


func setup_demo() -> void:
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
	_push_event("Lumberjack harvests; carrier handles transport from the hut.")


func step_tick() -> void:
	tick += 1
	_update_worker_visual_progress()
	_tick_buildings()
	_generate_tasks()
	var worker_ids: Array = workers.keys()
	worker_ids.sort()
	for worker_id_variant: Variant in worker_ids:
		_tick_worker(int(worker_id_variant))


func add_tree(cell: Vector2i, amount: int = 3) -> int:
	if not grid.contains(cell) or _tree_at(cell) != 0 or grid.blocked_by.has(cell):
		return 0
	var entity_id: int = _take_entity_id()
	trees[entity_id] = {"id": entity_id, "position": cell, "amount": amount}
	return entity_id


func spawn_worker(cell: Vector2i, unit_type: String = "carrier", home_id: int = 0) -> int:
	if catalog.unit(unit_type).is_empty() or not grid.is_walkable(cell) or tile_reservations.has(cell):
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
	}
	tile_reservations[cell] = entity_id
	return entity_id


func can_place_building(building_type: String, cell: Vector2i) -> bool:
	if catalog.building(building_type).is_empty() or not grid.is_walkable(cell):
		return false
	if _tree_at(cell) != 0 or tile_reservations.has(cell):
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
		"storage": {"log": 0, "plank": 0},
		"inputs": {"log": 0},
		"outputs": {"log": 0, "plank": 0},
		"process_remaining": 0,
	}
	grid.block(cell, entity_id)
	_push_event("Built %s." % String(catalog.building(building_type).get("display_name", building_type)))
	return entity_id


func place_road(cell: Vector2i) -> bool:
	if _tree_at(cell) != 0 or tile_reservations.has(cell):
		return false
	return grid.add_road(cell)


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


func to_data() -> Dictionary:
	var roads_data: Array[Array] = []
	for road_variant: Variant in grid.roads.keys():
		var road: Vector2i = road_variant as Vector2i
		roads_data.append([road.x, road.y])
	var dirt_trails_data: Array[Array] = []
	for trail_variant: Variant in grid.dirt_trails.keys():
		var trail: Vector2i = trail_variant as Vector2i
		dirt_trails_data.append([trail.x, trail.y])
	var traffic_wear_data: Array[Array] = []
	for wear_cell_variant: Variant in grid.traffic_wear.keys():
		var wear_cell: Vector2i = wear_cell_variant as Vector2i
		traffic_wear_data.append([wear_cell.x, wear_cell.y, int(grid.traffic_wear[wear_cell])])

	var buildings_data: Array[Dictionary] = []
	for building_variant: Variant in buildings.values():
		var building: Dictionary = (building_variant as Dictionary).duplicate(true)
		building["position"] = _vector_to_array(building["position"] as Vector2i)
		building["entrance"] = _vector_to_array(building["entrance"] as Vector2i)
		buildings_data.append(building)

	var trees_data: Array[Dictionary] = []
	for tree_variant: Variant in trees.values():
		var tree: Dictionary = (tree_variant as Dictionary).duplicate(true)
		tree["position"] = _vector_to_array(tree["position"] as Vector2i)
		trees_data.append(tree)

	var workers_data: Array[Dictionary] = []
	for worker_variant: Variant in workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		workers_data.append({
			"id": int(worker["id"]),
			"type": String(worker["type"]),
			"home_id": int(worker.get("home_id", 0)),
			"position": _vector_to_array(worker["position"] as Vector2i),
			"carrying": String(worker["carrying"]),
		})

	return {
		"version": SAVE_VERSION,
		"tick": tick,
		"next_entity_id": _next_entity_id,
		"map_size": [grid.size.x, grid.size.y],
		"roads": roads_data,
		"dirt_trails": dirt_trails_data,
		"traffic_wear": traffic_wear_data,
		"buildings": buildings_data,
		"trees": trees_data,
		"workers": workers_data,
	}


func from_data(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		return false
	var map_size_data: Array = data["map_size"] as Array
	grid = GridMapSimClass.new(Vector2i(int(map_size_data[0]), int(map_size_data[1])))
	grid.configure_movement(catalog.movement)
	task_board = TaskBoardClass.new()
	buildings.clear()
	trees.clear()
	workers.clear()
	tile_reservations.clear()
	event_log.clear()
	tick = int(data["tick"])
	_next_entity_id = int(data["next_entity_id"])

	for road_variant: Variant in data.get("roads", []):
		grid.add_road(_array_to_vector(road_variant as Array))
	for trail_variant: Variant in data.get("dirt_trails", []):
		grid.add_dirt_trail(_array_to_vector(trail_variant as Array))
	for wear_variant: Variant in data.get("traffic_wear", []):
		var wear_data: Array = wear_variant as Array
		grid.set_traffic_wear(
			Vector2i(int(wear_data[0]), int(wear_data[1])),
			int(wear_data[2])
		)
	for building_variant: Variant in data["buildings"]:
		var building: Dictionary = (building_variant as Dictionary).duplicate(true)
		building["position"] = _array_to_vector(building["position"] as Array)
		building["entrance"] = _array_to_vector(building["entrance"] as Array)
		var inputs: Dictionary = building.get("inputs", {}) as Dictionary
		inputs["log"] = int(inputs.get("log", 0))
		building["inputs"] = inputs
		var outputs: Dictionary = building.get("outputs", {}) as Dictionary
		outputs["log"] = int(outputs.get("log", 0))
		outputs["plank"] = int(outputs.get("plank", 0))
		building["outputs"] = outputs
		var storage: Dictionary = building.get("storage", {}) as Dictionary
		storage["log"] = int(storage.get("log", 0))
		storage["plank"] = int(storage.get("plank", 0))
		building["storage"] = storage
		var building_id: int = int(building["id"])
		buildings[building_id] = building
		grid.block(building["position"] as Vector2i, building_id)
	for tree_variant: Variant in data["trees"]:
		var tree: Dictionary = (tree_variant as Dictionary).duplicate(true)
		tree["position"] = _array_to_vector(tree["position"] as Array)
		trees[int(tree["id"])] = tree
	var legacy_worker_index: int = 0
	var saved_workers: Array = (data["workers"] as Array).duplicate()
	saved_workers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"])
	)
	for worker_variant: Variant in saved_workers:
		var worker_data: Dictionary = worker_variant as Dictionary
		var position: Vector2i = _array_to_vector(worker_data["position"] as Array)
		var worker_id: int = int(worker_data["id"])
		var fallback_type: String = "lumberjack" if legacy_worker_index == 0 else "carrier"
		var unit_type: String = String(worker_data.get("type", fallback_type))
		if catalog.unit(unit_type).is_empty():
			unit_type = fallback_type
		var home_id: int = int(worker_data.get("home_id", 0))
		if unit_type == "lumberjack" and home_id == 0:
			home_id = _first_building("lumber_hut")
		workers[worker_id] = {
			"id": worker_id,
			"type": unit_type,
			"home_id": home_id,
			"position": position,
			"previous_position": position,
			"state": "idle",
			"action": "",
			"task_id": 0,
			"source_id": 0,
			"destination_id": 0,
			"carrying": String(worker_data.get("carrying", "")),
			"path": [],
			"path_index": 0,
			"move_cooldown": 0,
			"work_remaining": 0,
			"visual_progress_ticks": 1,
			"visual_duration_ticks": 1,
			"blocked_ticks": 0,
			"target_cell": position,
		}
		tile_reservations[position] = worker_id
		legacy_worker_index += 1
	for worker_variant: Variant in workers.values():
		var restored_worker: Dictionary = worker_variant as Dictionary
		if not String(restored_worker["carrying"]).is_empty():
			_resume_carried_ware(restored_worker)
	_push_event("Save loaded at tick %d." % tick)
	return true


func _tick_buildings() -> void:
	var building_ids: Array = buildings.keys()
	building_ids.sort()
	for building_id_variant: Variant in building_ids:
		var building: Dictionary = buildings[int(building_id_variant)] as Dictionary
		if String(building["type"]) != "sawmill":
			continue
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


func _generate_tasks() -> void:
	if has_building("lumber_hut"):
		var tree_ids: Array = trees.keys()
		tree_ids.sort()
		for tree_id_variant: Variant in tree_ids:
			var tree_id: int = int(tree_id_variant)
			var tree: Dictionary = trees[tree_id] as Dictionary
			if int(tree["amount"]) > 0:
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
		if String(worker["carrying"]).is_empty():
			_assign_task(worker)
		else:
			_resume_carried_ware(worker)
	elif state == "moving":
		_advance_worker(worker)
	elif state == "working":
		var remaining: int = int(worker["work_remaining"]) - 1
		worker["work_remaining"] = remaining
		if remaining <= 0:
			_finish_work(worker)


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
	if not workers.has(other_worker_id):
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

	if int(worker["task_id"]) != 0 and String(worker["carrying"]).is_empty():
		task_board.release(int(worker["task_id"]), worker_id)
		_reset_worker(worker)
	else:
		# A carrying worker cannot safely abandon its ware. Retry periodically
		# until the delivery entrance clears.
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
	var destination_id: int = 0
	if carrying == "log":
		destination_id = _preferred_log_destination(worker)
		worker["action"] = "deliver_log"
	elif carrying == "plank":
		destination_id = _nearest_building("warehouse", worker["position"] as Vector2i)
		worker["action"] = "deliver_plank"
	else:
		return
	worker["destination_id"] = destination_id
	if destination_id != 0:
		_move_worker_to(worker, _building_entrance(destination_id))


func _on_worker_arrived(worker: Dictionary) -> void:
	match String(worker["action"]):
		"harvest":
			worker["state"] = "working"
			var unit_definition: Dictionary = catalog.unit(String(worker["type"]))
			worker["work_remaining"] = int(unit_definition.get("harvest_ticks", 30))
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
	if String(worker["action"]) != "harvest":
		_reset_worker(worker)
		return
	var tree_id: int = int(worker["source_id"])
	if not trees.has(tree_id):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	var tree: Dictionary = trees[tree_id] as Dictionary
	tree["amount"] = int(tree["amount"]) - 1
	if int(tree["amount"]) <= 0:
		trees.erase(tree_id)
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	worker["task_id"] = 0
	worker["carrying"] = "log"
	worker["action"] = "deliver_log"
	var destination_id: int = _lumberjack_home(worker)
	worker["destination_id"] = destination_id
	if destination_id == 0 or not _move_worker_to(worker, _building_entrance(destination_id)):
		_reset_worker(worker)


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
	worker["action"] = "deliver_log"
	var destination_id: int = _preferred_log_destination(worker)
	worker["destination_id"] = destination_id
	if destination_id == 0 or not _move_worker_to(worker, _building_entrance(destination_id)):
		_reset_worker(worker)


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
	worker["action"] = "deliver_plank"
	var warehouse_id: int = _nearest_building("warehouse", worker["position"] as Vector2i)
	worker["destination_id"] = warehouse_id
	if warehouse_id == 0 or not _move_worker_to(worker, _building_entrance(warehouse_id)):
		_reset_worker(worker)


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


func _move_worker_to(worker: Dictionary, target: Vector2i) -> bool:
	var start: Vector2i = worker["position"] as Vector2i
	var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, start, target)
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


func _preferred_log_destination(worker: Dictionary) -> int:
	var position: Vector2i = worker["position"] as Vector2i
	if String(worker["type"]) == "lumberjack":
		return _lumberjack_home(worker)
	var destination_id: int = _nearest_building("sawmill", position)
	if destination_id == 0:
		destination_id = _nearest_building("warehouse", position)
	return destination_id


func _lumberjack_home(worker: Dictionary) -> int:
	var home_id: int = int(worker.get("home_id", 0))
	if buildings.has(home_id) and String((buildings[home_id] as Dictionary)["type"]) == "lumber_hut":
		return home_id
	var replacement_id: int = _nearest_building("lumber_hut", worker["position"] as Vector2i)
	worker["home_id"] = replacement_id
	return replacement_id


func _nearest_building(building_type: String, from_cell: Vector2i) -> int:
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
		var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, from_cell, target)
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


func _find_entrance(cell: Vector2i) -> Vector2i:
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if grid.is_walkable(candidate):
			return candidate
	return Vector2i(-1, -1)


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


static func _vector_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


static func _array_to_vector(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
