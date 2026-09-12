class_name Residences
extends RefCounted

const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")


static func capacity(world: Variant, building_id: int) -> int:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty():
		return 0
	return maxi(0, int(world.catalog.building(String(building["type"])).get("residence_capacity", 0)))


static func supports(world: Variant, building_id: int, worker: Dictionary) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty() or int(worker.get("owner_id", 1)) != int(building.get("owner_id", 1)):
		return false
	var resident_types: Array = world.catalog.building(String(building["type"])).get("resident_types", [])
	return capacity(world, building_id) > 0 and resident_types.has(String(worker.get("type", "")))


static func residents(world: Variant, building_id: int) -> Array[int]:
	var result: Array[int] = []
	if capacity(world, building_id) == 0:
		return result
	for id_variant: Variant in world.workers.keys():
		var id: int = int(id_variant)
		var worker: Dictionary = world.workers[id]
		if int(worker.get("sleep_home_id", 0)) == building_id and supports(world, building_id, worker):
			result.append(id)
	result.sort()
	return result


static func occupancy(world: Variant, building_id: int) -> Dictionary:
	var assigned: Array[int] = residents(world, building_id)
	return {
		"occupied": assigned.size(),
		"capacity": capacity(world, building_id),
		"residents": assigned,
	}


static func has_room(world: Variant, building_id: int, worker_id: int = 0) -> bool:
	var assigned: Array[int] = residents(world, building_id)
	if worker_id != 0 and assigned.has(worker_id):
		return assigned.find(worker_id) < capacity(world, building_id)
	return assigned.size() < capacity(world, building_id)


static func valid_home(world: Variant, worker: Dictionary, building_id: int) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty() or not world.is_building_complete(building) \
			or not world.is_building_enabled(building) or not supports(world, building_id, worker):
		return false
	if not has_room(world, building_id, int(worker.get("id", 0))):
		return false
	var from_cell: Vector2i = worker.get("position", Vector2i(-1, -1))
	var entrance: Vector2i = building["entrance"]
	return from_cell == entrance or not Pathfinder.find_path(world.grid, from_cell, entrance).is_empty()


static func nearest_available(world: Variant, worker: Dictionary) -> int:
	var best_id: int = 0
	var best_cost: int = 2147483647
	var ids: Array = world.buildings.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var building_id: int = int(id_variant)
		if not valid_home(world, worker, building_id):
			continue
		var entrance: Vector2i = world.buildings[building_id]["entrance"]
		var path: Array[Vector2i] = Pathfinder.find_path(world.grid, worker["position"], entrance)
		if worker["position"] != entrance and path.is_empty():
			continue
		var route_cost: int = Pathfinder.path_cost(world.grid, path, worker["position"])
		if route_cost < best_cost or (route_cost == best_cost and (best_id == 0 or building_id < best_id)):
			best_id = building_id
			best_cost = route_cost
	return best_id
