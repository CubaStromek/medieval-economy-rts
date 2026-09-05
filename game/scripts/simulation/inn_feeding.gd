class_name InnFeeding
extends RefCounted

const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const SEARCH_RETRY_TICKS: int = 20


static func occupied_seats(world: Variant, inn_id: int) -> int:
	var count: int = 0
	for worker: Dictionary in world.workers.values():
		if int(worker.get("inside_building_id", 0)) == inn_id and int(worker.get("meal_ticks_left", 0)) > 0:
			count += 1
	return count


static func tick_worker(world: Variant, worker: Dictionary) -> bool:
	var remaining: int = int(worker.get("meal_ticks_left", 0))
	if remaining <= 0:
		return false
	var course: Dictionary = worker.get("meal_course", {})
	worker["meal_ticks_left"] = remaining - 1
	if course.is_empty():
		# A v13 visit was already paid and fully restored before saving. Finish
		# only its old countdown; never turn that saved meal into new servings.
		if remaining == 1:
			_finish_visit(world, worker)
		return true
	var duration: int = int(course["duration_ticks"])
	var elapsed: int = duration - int(worker["meal_ticks_left"])
	@warning_ignore("integer_division")
	var target_restore: int = int(course["restore"]) * elapsed / duration
	var added: int = target_restore - int(course["applied"])
	worker["hunger"] = mini(int(world.catalog.economy["condition_max"]), int(worker["hunger"]) + added)
	# Track the raw restored amount even when saturation caps the visible gain.
	# A snapshot can then resume the exact integer curve without double feeding.
	course["applied"] = target_restore
	if remaining == 1 and not _start_next_course(world, worker, course["foods_eaten"]):
		_finish_visit(world, worker)
	return true


static func handle_idle(world: Variant, worker: Dictionary, allow_cargo: bool = false) -> bool:
	if not world.economy_enabled or world.catalog.soldiers.has(String(worker["type"])) \
			or (not allow_cargo and not String(worker["carrying"]).is_empty()) \
			or int(worker["hunger"]) > int(world.catalog.economy.get("condition_hungry", 360)):
		return false
	if world.tick < int(worker.get("_meal_retry_until", 0)):
		return false
	var inn_id: int = _find_inn(world, worker)
	if inn_id == 0:
		worker["_meal_retry_until"] = world.tick + SEARCH_RETRY_TICKS
		return false
	worker["action"] = "eat"
	worker["destination_id"] = inn_id
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	blockers.erase(world.buildings[inn_id]["entrance"])
	if world._move_worker_to(worker, world.buildings[inn_id]["entrance"], blockers):
		return true
	retry_after_blocked(world, worker)
	return false


static func arrive(world: Variant, worker: Dictionary) -> bool:
	if worker["action"] != "eat":
		return false
	if int(worker.get("meal_ticks_left", 0)) > 0:
		return true
	var inn_id: int = int(worker["destination_id"])
	var inn: Dictionary = world.buildings.get(inn_id, {})
	if world.catalog.soldiers.has(String(worker["type"])) \
			or not _can_serve(world, inn):
		# Seats are claimed at arrival. Someone else may have taken the last
		# seat or serving while this civilian walked here; try another inn.
		retry_after_blocked(world, worker)
		worker["_meal_retry_until"] = world.tick
		handle_idle(world, worker)
		return true
	if not world._enter_worker_building(worker, inn_id):
		worker["state"] = "moving"
		return true
	if not _start_next_course(world, worker, []):
		retry_after_blocked(world, worker)
		return true
	worker["indoor_wait_ticks"] = 0
	worker["state"] = "working"
	worker["path"] = []
	worker["path_index"] = 0
	worker.erase("_meal_retry_until")
	worker.erase("_meal_avoid_inn")
	worker.erase("_meal_avoid_until")
	return true


static func _start_next_course(world: Variant, worker: Dictionary, foods_eaten: Array) -> bool:
	if int(worker["hunger"]) >= int(world.catalog.economy["condition_full_threshold"]) \
			or foods_eaten.size() >= int(world.catalog.economy["max_meals_per_visit"]):
		return false
	var inn: Dictionary = world.buildings.get(int(worker.get("inside_building_id", 0)), {})
	if inn.is_empty() or inn["type"] != "inn" or not world.is_building_complete(inn):
		return false
	for resource: String in world.catalog.economy["food_order"]:
		if foods_eaten.has(resource) or int(inn["inputs"].get(resource, 0)) <= 0:
			continue
		var eaten: Array = foods_eaten.duplicate()
		eaten.append(resource)
		var duration: int = maxi(1, int(world.catalog.building("inn").get("meal_duration_ticks", 116)))
		# Only the current course is claimed. Later choices use the stock that
		# is actually available after this course finishes, including new food.
		inn["inputs"][resource] = int(inn["inputs"][resource]) - 1
		worker["meal_course"] = {
			"food": resource, "duration_ticks": duration,
			"restore": int(world.catalog.resources[resource]["food_restore"]),
			"applied": 0, "foods_eaten": eaten,
		}
		worker["meal_ticks_left"] = duration
		return true
	return false


static func _finish_visit(world: Variant, worker: Dictionary) -> void:
	worker["meal_ticks_left"] = 0
	worker["meal_course"] = {}
	world._reset_worker(worker)


static func retry_after_blocked(world: Variant, worker: Dictionary) -> void:
	var failed_inn: int = int(worker.get("destination_id", 0))
	world._reset_worker(worker)
	worker["_meal_retry_until"] = world.tick + SEARCH_RETRY_TICKS
	worker["_meal_avoid_inn"] = failed_inn
	worker["_meal_avoid_until"] = world.tick + SEARCH_RETRY_TICKS * 2


static func _can_serve(world: Variant, inn: Dictionary) -> bool:
	if inn.is_empty() or inn["type"] != "inn" or not world.is_building_complete(inn):
		return false
	if occupied_seats(world, int(inn["id"])) >= int(world.catalog.building("inn").get("seating_capacity", 6)):
		return false
	for resource: String in world.catalog.economy["food_order"]:
		if int(inn["inputs"].get(resource, 0)) > 0:
			return true
	return false


static func _find_inn(world: Variant, worker: Dictionary) -> int:
	var best: int = 0
	var cost: int = 2147483647
	var ids: Array = world.buildings.keys()
	ids.sort()
	for id: int in ids:
		if id == int(worker.get("_meal_avoid_inn", 0)) and world.tick < int(worker.get("_meal_avoid_until", 0)):
			continue
		var inn: Dictionary = world.buildings[id]
		if not _can_serve(world, inn):
			continue
		var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
		blockers.erase(inn["entrance"])
		var path: Array[Vector2i] = world._path_with_yielding(worker["position"], inn["entrance"], blockers, int(worker["id"]))
		if worker["position"] != inn["entrance"] and path.is_empty():
			continue
		var route_cost: int = Pathfinder.path_cost(world.grid, path, worker["position"])
		if route_cost < cost:
			best = id
			cost = route_cost
	return best
