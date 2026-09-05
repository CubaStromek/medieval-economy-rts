class_name DailySchedule
extends RefCounted

const Feeding = preload("res://scripts/simulation/inn_feeding.gd")
const RETRY_TICKS: int = 20


static func follows(world: Variant, worker: Dictionary) -> bool:
	var role: String = String(worker.get("type", ""))
	return role != "recruit" and world.catalog.units.has(role) and not world.catalog.soldiers.has(role)


# Run before building production and military supply replanning. A pending
# ration request belongs to the soldier; only the carrier's mission is released.
static func prepare_tick(world: Variant) -> void:
	if not world.is_night_rest_time():
		return
	for worker: Dictionary in world.workers.values():
		if not follows(world, worker):
			continue
		worker["ration_delivery"] = {}
		if int(worker.get("meal_ticks_left", 0)) > 0 or worker["action"] in ["eat", "go_sleep", "yield"] \
				or worker["state"] == "sleeping":
			continue
		# Reset preserves cargo, employment and the already committed visible
		# step. Its remaining cooldown is finished before choosing a new route.
		world._release_worker_task(worker)


static func sleeping(world: Variant, worker: Dictionary) -> bool:
	var home: int = int(worker.get("sleep_home_id", 0))
	return follows(world, worker) and world.is_night_rest_time() and home != 0 \
		and int(worker.get("inside_building_id", 0)) == home \
		and int(worker.get("meal_ticks_left", 0)) == 0 \
		and worker.get("state", "") == "sleeping"


static func status(world: Variant, worker: Dictionary) -> String:
	if not follows(world, worker) or not world.is_night_rest_time():
		return ""
	if sleeping(world, worker):
		return "Sleeping until 05:00"
	if int(worker.get("meal_ticks_left", 0)) > 0 or worker.get("action", "") == "eat":
		return "Eating before returning to sleep"
	if bool(worker.get("_sleep_route_blocked", false)):
		return "Cannot reach sleeping place"
	if int(worker.get("sleep_home_id", 0)) == 0:
		return "No sleeping place available"
	return "Going to sleep"


static func handle_worker(world: Variant, worker: Dictionary) -> bool:
	if not follows(world, worker):
		return false
	if not world.is_night_rest_time():
		if worker["state"] == "sleeping" or worker["action"] == "go_sleep":
			if not _step_finished(worker):
				return true
			world._release_worker_task(worker)
		worker.erase("_sleep_retry_until")
		worker.erase("_sleep_route_blocked")
		return false
	if int(worker.get("meal_ticks_left", 0)) > 0:
		return false # The shared feeding tick owns a meal, including after dawn.
	if world.is_worker_inside(worker) and int(worker.get("indoor_wait_ticks", 0)) > 0:
		worker["indoor_wait_ticks"] = int(worker["indoor_wait_ticks"]) - 1
		return true
	if worker["action"] in ["eat", "yield"]:
		world._advance_worker(worker)
		return true
	if worker["action"] == "go_sleep" and not _can_change_route(worker):
		world._advance_worker(worker)
		return true
	if worker["action"] != "go_sleep" and not _step_finished(worker):
		return true
	var home: int = _ensure_home(world, worker)
	# Personal meals remain possible with deferred cargo. This call only
	# routes to an inn; it never treats carried food as a free serving.
	if Feeding.handle_idle(world, worker, true):
		return true
	if worker["action"] == "go_sleep":
		if home != 0 and worker["target_cell"] == world.buildings[home]["entrance"]:
			world._advance_worker(worker)
			return true
		world._release_worker_task(worker)
	var inside: int = int(worker.get("inside_building_id", 0))
	if inside != 0:
		if inside == home:
			world._release_worker_task(worker)
			worker["state"] = "sleeping"
			worker.erase("_sleep_route_blocked")
		else:
			# An inn visit is not a home, nor is another worker's workshop.
			world._try_exit_worker_building(worker)
		return true
	if home == 0 or world.tick < int(worker.get("_sleep_retry_until", 0)):
		return true
	worker["action"] = "go_sleep"
	# destination_id is deliberately zero: carried cargo must not reserve
	# inputs at the sleeping place merely because this is a travel target.
	worker["destination_id"] = 0
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	blockers.erase(world.buildings[home]["entrance"])
	if not world._move_worker_to(worker, world.buildings[home]["entrance"], blockers):
		reconsider_blocked(world, worker)
	else:
		worker.erase("_sleep_route_blocked")
	return true


static func arrive(world: Variant, worker: Dictionary) -> bool:
	if worker["action"] != "go_sleep":
		return false
	var home: int = int(worker.get("sleep_home_id", 0))
	if not world.is_night_rest_time() or not valid_home(world, worker, home):
		world._release_worker_task(worker)
		return true
	if world._enter_worker_building(worker, home):
		world._release_worker_task(worker)
		worker["state"] = "sleeping"
		worker.erase("_sleep_route_blocked")
	else:
		worker["state"] = "moving"
	return true


static func reconsider_blocked(world: Variant, worker: Dictionary) -> bool:
	if worker["action"] != "go_sleep":
		return false
	world._release_worker_task(worker)
	worker["_sleep_retry_until"] = world.tick + RETRY_TICKS
	worker["_sleep_route_blocked"] = true
	return true


static func valid_home(world: Variant, worker: Dictionary, home: int) -> bool:
	if home == 0 or not follows(world, worker):
		return false
	var building: Dictionary = world.buildings.get(home, {})
	if building.is_empty() or not world.is_building_complete(building):
		return false
	var workplace: int = int(worker.get("home_id", 0))
	if world.owns_workplace(worker, workplace):
		return home == workplace
	return building["type"] == "warehouse"


static func _ensure_home(world: Variant, worker: Dictionary) -> int:
	var workplace: int = int(worker.get("home_id", 0))
	if world.owns_workplace(worker, workplace):
		worker["sleep_home_id"] = workplace
		return workplace
	var home: int = int(worker.get("sleep_home_id", 0))
	if valid_home(world, worker, home):
		return home
	worker["sleep_home_id"] = 0
	if world.tick < int(worker.get("_sleep_retry_until", 0)):
		return 0
	home = world._nearest_building("warehouse", worker["position"])
	worker["sleep_home_id"] = home
	if home == 0:
		worker["_sleep_retry_until"] = world.tick + RETRY_TICKS
	return home


static func _can_change_route(worker: Dictionary) -> bool:
	return int(worker["move_cooldown"]) == 0 \
		and int(worker["visual_progress_ticks"]) >= int(worker["visual_duration_ticks"])


static func _step_finished(worker: Dictionary) -> bool:
	if int(worker["move_cooldown"]) > 0:
		worker["move_cooldown"] = int(worker["move_cooldown"]) - 1
		return false
	return _can_change_route(worker)
