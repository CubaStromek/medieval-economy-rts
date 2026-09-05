class_name IndoorWorkers
extends RefCounted

const DWELL_TICKS: int = 6
const OUTDOOR_SPECIALISTS: Array[String] = ["lumberjack", "gardener", "farmer", "stonemason", "miner", "fisherman"]


static func is_inside(worker: Dictionary) -> bool:
	return int(worker.get("inside_building_id", 0)) != 0


static func valid_location(world: Variant, cell: Vector2i, building_id: int) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	return not building.is_empty() and world.is_building_complete(building) \
		and cell == building["entrance"] and world.grid.is_walkable(cell)


static func enter(world: Variant, worker: Dictionary, building_id: int, dwell_ticks: int = 0) -> bool:
	if not valid_location(world, worker["position"], building_id):
		return false
	if is_inside(worker):
		return int(worker["inside_building_id"]) == building_id
	if int(worker["move_cooldown"]) != 0 \
			or int(worker["visual_progress_ticks"]) < int(worker["visual_duration_ticks"]) \
			or int(world.tile_reservations.get(worker["position"], 0)) != int(worker["id"]):
		return false
	world._release_worker_tile(worker)
	worker["inside_building_id"] = building_id
	worker["indoor_wait_ticks"] = clampi(dwell_ticks, 0, DWELL_TICKS)
	worker["previous_position"] = worker["position"]
	return true


static func enter_waiting_home(world: Variant, worker: Dictionary) -> bool:
	if is_inside(worker) or not String(worker["carrying"]).is_empty():
		return false
	var home: int = int(worker["home_id"])
	if not world.owns_workplace(worker, home):
		return false
	return enter(world, worker, home, DWELL_TICKS if OUTDOOR_SPECIALISTS.has(String(worker["type"])) else 0)


static func can_resolve_here(worker: Dictionary) -> bool:
	var inside: int = int(worker.get("inside_building_id", 0))
	if inside == 0:
		return false
	var action: String = String(worker["action"])
	if action == "operate":
		return int(worker["source_id"]) == inside
	if action.begins_with("deliver_") or action in ["eat", "report_barracks"]:
		return int(worker["destination_id"]) == inside
	return false


static func leave(world: Variant, worker: Dictionary) -> bool:
	if not is_inside(worker):
		return true
	if int(worker.get("indoor_wait_ticks", 0)) > 0 \
			or not valid_location(world, worker["position"], int(worker["inside_building_id"])):
		return false
	var door: Vector2i = worker["position"]
	var occupant: int = int(world.tile_reservations.get(door, 0))
	if occupant != 0:
		world._try_yield_building_exit(worker, occupant)
		return false
	if world._yielding_origins.has(door) or world.planting_reservations.has(door):
		return false
	world.tile_reservations[door] = int(worker["id"])
	worker["inside_building_id"] = 0
	worker["indoor_wait_ticks"] = 0
	worker["previous_position"] = door
	worker["move_cooldown"] = 0
	worker["visual_progress_ticks"] = 1
	worker["visual_duration_ticks"] = 1
	world._workers_moved_this_tick[int(worker["id"])] = true
	world._workers_updated_this_tick[int(worker["id"])] = true
	return true
