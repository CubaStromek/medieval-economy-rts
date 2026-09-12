class_name ResourceDeposits
extends RefCounted

const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const RESOURCES: Array[String] = ["stone", "iron_ore", "coal", "gold_ore", "fish"]
const NO_CELL := Vector2i(-1, -1)


static func add(world: Variant, cell: Vector2i, resource: String, amount: int) -> int:
	if amount <= 0 or not RESOURCES.has(resource) or not world.catalog.resources.has(resource):
		return 0
	if cell.x < 0 or cell.y < 0 or cell.x >= world.grid.size.x or cell.y >= world.grid.size.y or id_at(world, cell) != 0:
		return 0
	var terrain: String = world.grid.base_terrain_at(cell)
	if resource == "fish" and terrain != "water":
		return 0
	if resource == "coal" and not ["grass", "dirt"].has(terrain):
		return 0
	if resource in ["stone", "iron_ore", "gold_ore"] and terrain != "rock":
		return 0
	if world.building_id_at(cell) != 0 or world._tree_at(cell) != 0 or world.field_id_at(cell) != 0:
		return 0
	if world.tile_reservations.has(cell) or world.planting_reservations.has(cell) or not world.grid.overlay_at(cell).is_empty():
		return 0
	for building: Dictionary in world.buildings.values():
		if building["entrance"] == cell:
			return 0
	# A legal authored deposit replaces faint footprints just as a prepared
	# field does; stale direction records must not make its snapshot invalid.
	world.grid.clear_trail(cell)
	var id: int = world._take_entity_id()
	world.deposits[id] = {"id": id, "position": cell, "resource": resource, "amount": amount}
	return id


static func id_at(world: Variant, cell: Vector2i) -> int:
	for id: int in world.deposits:
		if world.deposits[id]["position"] == cell:
			return id
	return 0


static func placement_valid(world: Variant, building_type: String, cell: Vector2i, entrance: Vector2i = NO_CELL, proposed_footprint: Dictionary = {}) -> bool:
	var definition: Dictionary = world.catalog.building(building_type)
	var resource: String = String(definition.get("extract_resource", ""))
	if resource.is_empty():
		return true
	var range_cells: Array[Vector2i] = []
	for occupied: Vector2i in proposed_footprint:
		range_cells.append(occupied)
	for deposit: Dictionary in world.deposits.values():
		if deposit["resource"] == resource and int(deposit["amount"]) > 0 and _in_range(definition, cell, deposit["position"], range_cells):
			# Placement must test the route that remains after the walls exist.
			# Modern gathering radius starts at the nearest occupied house tile;
			# historical placement without a mask keeps its one-cell anchor.
			if candidate_work_cell(world, deposit, cell if entrance == NO_CELL else entrance, proposed_footprint) != NO_CELL:
				return true
	return false


# Target selection is per worker: impassable mineral and water cells are worked
# from a reachable bank/edge, while a walkable coal tile can be entered directly.
static func candidate_work_cell(world: Variant, deposit: Dictionary, from: Vector2i, blockers: Dictionary = {}) -> Vector2i:
	var center: Vector2i = deposit["position"]
	var cells: Array[Vector2i] = []
	if world.grid.is_walkable(center):
		cells.append(center)
	for direction: Vector2i in Grid.CARDINAL_DIRECTIONS:
		cells.append(center + direction)
	var best: Vector2i = NO_CELL
	var best_cost: int = 2147483647
	for cell: Vector2i in cells:
		if not world.grid.can_reach_resource(cell, center) or (blockers.has(cell) and cell != from):
			continue
		var path: Array[Vector2i] = world._path_with_yielding(from, cell, blockers, 0)
		if from != cell and path.is_empty():
			continue
		var cost: int = Pathfinder.path_cost(world.grid, path, from)
		if cost < best_cost:
			best = cell
			best_cost = cost
	return best


static func generate_tasks(world: Variant) -> void:
	var ids: Array = world.deposits.keys()
	ids.sort()
	for id: int in ids:
		var deposit: Dictionary = world.deposits[id]
		if int(deposit["amount"]) <= 0:
			continue
		for building: Dictionary in world.buildings.values():
			if not world.is_local_entity(building) or not world.is_building_enabled(building):
				continue
			var definition: Dictionary = world.catalog.building(String(building["type"]))
			if _serves(world, definition, building, deposit):
				world.task_board.create_task("harvest_deposit", "deposit:%d" % id, deposit["position"], id)
				break


static func task_available(world: Variant, task: Dictionary, worker: Dictionary) -> bool:
	var deposit: Dictionary = world.deposits.get(int(task["source_id"]), {})
	if task.get("kind", "") != "harvest_deposit" or deposit.is_empty() or int(deposit["amount"]) <= 0 or not String(worker["carrying"]).is_empty():
		return false
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	return home_for(world, deposit, worker, blockers) != 0 and candidate_work_cell(world, deposit, worker["position"], blockers) != NO_CELL


static func home_for(world: Variant, deposit: Dictionary, worker: Dictionary, blockers: Dictionary = {}) -> int:
	var id: int = int(worker["home_id"])
	if not world.owns_workplace(worker, id):
		return 0
	var building: Dictionary = world.buildings[id]
	var definition: Dictionary = world.catalog.building(String(building["type"]))
	if not _serves(world, definition, building, deposit) or not _output_room(world, building, String(deposit["resource"]), int(worker["id"])):
		return 0
	var target: Vector2i = building["entrance"]
	var routes: Dictionary = blockers.duplicate()
	routes.erase(target)
	if worker["position"] != target and world._path_with_yielding(worker["position"], target, routes, int(worker["id"])).is_empty():
		return 0
	return id


# Called after the task board has exclusively reserved task/source IDs.
static func assign(world: Variant, worker: Dictionary, task: Dictionary) -> bool:
	var deposit: Dictionary = world.deposits.get(int(task["source_id"]), {})
	if deposit.is_empty():
		return false
	var home: int = home_for(world, deposit, worker, world._temporary_blockers_for(int(worker["id"])))
	if home == 0:
		return false
	worker["action"] = "harvest_deposit"
	return true


static func arrived(world: Variant, worker: Dictionary) -> void:
	var deposit: Dictionary = world.deposits.get(int(worker["source_id"]), {})
	if deposit.is_empty() or int(deposit["amount"]) <= 0 or not world.owns_workplace(worker, int(worker["home_id"])) or home_for(world, deposit, worker) == 0 or not _at_deposit(world, worker, deposit):
		world._release_worker_task(worker)
		return
	worker["state"] = "working"
	worker["work_remaining"] = maxi(1, int(world.catalog.unit(String(worker["type"])).get("extract_ticks", 100)))


static func finish(world: Variant, worker: Dictionary) -> void:
	var deposit: Dictionary = world.deposits.get(int(worker["source_id"]), {})
	var task: Dictionary = world.task_board._tasks.get(int(worker["task_id"]), {})
	if deposit.is_empty() or int(deposit["amount"]) <= 0 or not _at_deposit(world, worker, deposit) or int(task.get("reserved_by", 0)) != int(worker["id"]) or int(task.get("source_id", 0)) != int(worker["source_id"]) or task.get("kind", "") != "harvest_deposit" or not String(worker["carrying"]).is_empty():
		world._release_worker_task(worker)
		return
	var home: Dictionary = world.buildings.get(int(worker["home_id"]), {})
	var resource: String = String(deposit["resource"])
	if home.is_empty() or not world.owns_workplace(worker, int(home["id"])) or not _serves(world, world.catalog.building(String(home["type"])), home, deposit) or not _output_room(world, home, resource, int(worker["id"])):
		world._release_worker_task(worker)
		return
	# Claim and consume one finite unit together; clearing the reservation before
	# resuming delivery makes repeated/stale completion unable to mint another ware.
	if not world.task_board.complete(int(worker["task_id"]), int(worker["id"])):
		world._release_worker_task(worker)
		return
	deposit["amount"] = int(deposit["amount"]) - 1
	world._reset_worker(worker)
	worker["carrying"] = resource
	world._resume_carried_ware(worker)


static func _at_deposit(world: Variant, worker: Dictionary, deposit: Dictionary) -> bool:
	var cell: Vector2i = worker["position"]
	var target: Vector2i = deposit["position"]
	return world.grid.can_reach_resource(cell, target)


static func _serves(world: Variant, definition: Dictionary, building: Dictionary, deposit: Dictionary) -> bool:
	return String(definition.get("extract_resource", "")) == String(deposit["resource"]) and world.is_building_complete(building) and _in_range(definition, building["position"], deposit["position"], world.building_cells(building))


static func _in_range(definition: Dictionary, building_cell: Vector2i, deposit_cell: Vector2i, footprint_cells: Array[Vector2i] = []) -> bool:
	var radius: int = int(definition.get("extract_radius", 3))
	if footprint_cells.is_empty():
		return absi(building_cell.x - deposit_cell.x) + absi(building_cell.y - deposit_cell.y) <= radius
	for cell: Vector2i in footprint_cells:
		if absi(cell.x - deposit_cell.x) + absi(cell.y - deposit_cell.y) <= radius:
			return true
	return false


static func _output_room(world: Variant, building: Dictionary, resource: String, except_worker: int) -> bool:
	var amount: int = int(building["outputs"].get(resource, 0))
	for id: int in world.workers:
		if id == except_worker:
			continue
		var worker: Dictionary = world.workers[id]
		if int(worker.get("home_id", 0)) != int(building["id"]):
			continue
		if worker["carrying"] == resource:
			amount += 1
		elif worker["action"] == "harvest_deposit":
			var source: Dictionary = world.deposits.get(int(worker["source_id"]), {})
			if source.get("resource", "") == resource:
				amount += 1
	return amount < int(world.catalog.building(String(building["type"])).get("output_capacity", 6))
