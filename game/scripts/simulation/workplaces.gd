class_name Workplaces
extends RefCounted

const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")


# home_id is the single source of truth. Deriving the reverse lookup avoids a
# stale second reservation after starvation, loading or removing a building.
static func profession(world: Variant, building_id: int) -> String:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty():
		return ""
	return String(world.catalog.building(String(building["type"])).get("worker", ""))


static func occupant(world: Variant, building_id: int) -> Dictionary:
	var building: Dictionary = world.buildings.get(building_id, {})
	var role: String = profession(world, building_id)
	if building.is_empty() or not world.is_building_complete(building) or role.is_empty():
		return {}
	var result: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if int(worker.get("owner_id", 1)) != int(building.get("owner_id", 1)) or int(worker.get("home_id", 0)) != building_id or String(worker["type"]) != role:
			continue
		if result.is_empty() or int(worker["id"]) < int(result["id"]):
			result = worker
	return result


static func requires_home(world: Variant, worker: Dictionary) -> bool:
	var role: String = String(worker["type"])
	# Recruits use the existing barracks-order priority when selecting a tower;
	# a barracks is a communal service, not a recruit's exclusive workplace.
	return role != "recruit" and not (world.catalog.unit(role).get("home_buildings", []) as Array).is_empty()


static func can_claim(world: Variant, worker: Dictionary, building_id: int) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty() or not world.is_building_complete(building):
		return false
	if int(worker.get("owner_id", 1)) != int(building.get("owner_id", 1)):
		return false
	var role: String = String(worker["type"])
	if profession(world, building_id) != role or role.is_empty():
		return false
	if not (world.catalog.unit(role).get("home_buildings", []) as Array).has(building["type"]):
		return false
	var previous: int = int(worker.get("home_id", 0))
	if previous != building_id and _owns(world, worker, previous):
		return false
	var resident: Dictionary = occupant(world, building_id)
	if not resident.is_empty() and int(resident["id"]) != int(worker["id"]):
		return false
	var carrying: String = String(worker.get("carrying", ""))
	return carrying.is_empty() or (world.catalog.building(String(building["type"])).get("outputs", []) as Array).has(carrying)


static func claim(world: Variant, worker: Dictionary, building_id: int) -> bool:
	if not can_claim(world, worker, building_id):
		return false
	worker["home_id"] = building_id
	return true


static func ensure(world: Variant, worker: Dictionary) -> int:
	var previous: int = int(worker.get("home_id", 0))
	# A workplace remains owned during a meal, an empty-input pause, full
	# outputs and even an inaccessible route. Those are not resignation events.
	if _owns(world, worker, previous):
		return previous
	worker["home_id"] = 0
	if not world.is_local_entity(worker) or world.is_worker_work_paused(worker) or not requires_home(world, worker):
		return 0
	var ids: Array = world.buildings.keys()
	ids.sort()
	var targets: Dictionary = {}
	for id: int in ids:
		if world.is_building_enabled(world.buildings[id]) and can_claim(world, worker, id):
			targets[id] = world.buildings[id]["entrance"]
	if targets.is_empty():
		worker.erase("_workplace_search_cache")
		return 0
	var signature: Dictionary = {
		"grid_id": world.grid.get_instance_id(),
		"connectivity_revision": world.grid.connectivity_revision,
		"position": worker["position"],
		"carrying": String(worker.get("carrying", "")),
		"targets": targets,
	}
	# Failed reachability cannot change while these bounded inputs are equal.
	# In particular, carrier traffic and road speed changes do not open a route.
	if worker.get("_workplace_search_cache", {}) == signature:
		return 0
	worker["_workplace_search_count"] = int(worker.get("_workplace_search_count", 0)) + 1
	var best: int = _nearest_vacancy(world.grid, worker["position"], targets)
	if best != 0 and claim(world, worker, best):
		worker.erase("_workplace_search_cache")
		return best
	worker["_workplace_search_cache"] = signature
	return 0


static func _nearest_vacancy(grid: Variant, start: Vector2i, targets: Dictionary) -> int:
	if not grid.is_walkable(start):
		return 0
	var target_cells: Dictionary = {}
	for id: int in targets:
		var entrance: Vector2i = targets[id]
		if not target_cells.has(entrance) or id < int(target_cells[entrance]):
			target_cells[entrance] = id
	var frontier: Array[Dictionary] = []
	Pathfinder._heap_push(frontier, {"cell": start, "cost": 0, "priority": 0})
	var costs: Dictionary = {start: 0}
	var best: int = 0
	var best_cost: int = 2147483647
	# One Dijkstra traversal answers all vacancies, including disconnected ones.
	# No transient unit reservations participate in permanent home selection.
	while not frontier.is_empty():
		var entry: Dictionary = Pathfinder._heap_pop(frontier)
		var current: Vector2i = entry["cell"]
		var cost: int = int(entry["cost"])
		if cost > best_cost:
			break
		if cost != int(costs.get(current, -1)):
			continue
		if target_cells.has(current):
			var id: int = int(target_cells[current])
			if best == 0 or cost < best_cost or (cost == best_cost and id < best):
				best = id
				best_cost = cost
		# Process every equal-cost target before stopping; heap cell order is not
		# an employment tie-break. Positive movement costs need no deeper expansion.
		if cost >= best_cost:
			continue
		for next_cell: Vector2i in grid.neighbors8(current):
			var next_cost: int = cost + int(grid.step_cost(current, next_cell))
			if next_cost <= best_cost and (not costs.has(next_cell) or next_cost < int(costs[next_cell])):
				costs[next_cell] = next_cost
				Pathfinder._heap_push(frontier, {"cell": next_cell, "cost": next_cost, "priority": next_cost})
	return best


static func _owns(world: Variant, worker: Dictionary, building_id: int) -> bool:
	if building_id == 0 or int(worker.get("home_id", 0)) != building_id:
		return false
	var resident: Dictionary = occupant(world, building_id)
	return not resident.is_empty() and int(resident["id"]) == int(worker["id"])
