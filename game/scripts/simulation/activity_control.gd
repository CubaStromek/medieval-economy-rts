class_name ActivityControl
extends RefCounted

const Feeding = preload("res://scripts/simulation/inn_feeding.gd")
const UiTextClass = preload("res://scripts/ui_text.gd")
const RETRY_TICKS: int = 20
const PERSONAL_ACTIONS: Array[String] = ["eat", "yield", "pause_return", "leave_building"]


static func building_enabled(building: Dictionary) -> bool:
	return not building.is_empty() and bool(building.get("enabled", true))


static func worker_paused(world: Variant, worker: Dictionary) -> bool:
	if worker.is_empty():
		return false
	if not bool(worker.get("enabled", true)):
		return true
	var home: Dictionary = world.buildings.get(int(worker.get("home_id", 0)), {})
	return not home.is_empty() and not building_enabled(home)


static func set_worker_enabled(world: Variant, id: int, enabled: bool) -> bool:
	var worker: Dictionary = world.workers.get(id, {})
	if not world.is_local_entity(worker):
		return false
	if bool(worker.get("enabled", true)) == enabled:
		return true
	worker["enabled"] = enabled
	worker.erase("_pause_retry_until")
	world._push_event("%s #%d: %s." % [UiTextClass.unit_name(world.catalog, String(worker["type"])), id, "práce povolena" if enabled else "práce pozastavena"])
	return true


static func set_building_enabled(world: Variant, id: int, enabled: bool) -> bool:
	var building: Dictionary = world.buildings.get(id, {})
	if not world.is_local_entity(building):
		return false
	if bool(building.get("enabled", true)) == enabled:
		return true
	building["enabled"] = enabled
	world._push_event("%s #%d: %s." % [UiTextClass.building_name(world.catalog, String(building["type"])), id, "provoz povolen" if enabled else "provoz pozastaven"])
	return true


# Stop assignments before production ticks. A committed visible movement edge
# keeps its clock; cancellation never teleports, spends stock, or unclaims home.
static func prepare_tick(world: Variant) -> void:
	for worker: Dictionary in world.workers.values():
		if not world.is_local_entity(worker):
			continue
		var action: String = String(worker["action"])
		var source: Dictionary = world.buildings.get(int(worker["source_id"]), {})
		var stopped_target: bool = action in ["build_site", "operate"] and not source.is_empty() and not building_enabled(source)
		if not worker_paused(world, worker) and not stopped_target:
			continue
		if int(worker.get("meal_ticks_left", 0)) > 0 or action in PERSONAL_ACTIONS:
			continue
		if not String(worker["carrying"]).is_empty():
			continue
		# Release uncollected military reservations; a physically held ration
		# remains deliverable, just like every other already-carried ware.
		worker["ration_delivery"] = {}
		if not action.is_empty() or int(worker["task_id"]) != 0:
			world._release_worker_task(worker)


static func handle_worker(world: Variant, worker: Dictionary) -> bool:
	var paused: bool = worker_paused(world, worker)
	if not paused and worker["action"] != "pause_return":
		return false
	if worker["action"] in ["eat", "yield", "leave_building"]:
		world._advance_worker(worker)
		return true
	if int(worker["move_cooldown"]) > 0:
		worker["move_cooldown"] = int(worker["move_cooldown"]) - 1
		return true
	if int(worker["visual_progress_ticks"]) < int(worker["visual_duration_ticks"]):
		return true
	if not paused:
		world._release_worker_task(worker)
		return false
	if not String(worker["carrying"]).is_empty():
		if worker["state"] == "moving" and String(worker["action"]).begins_with("deliver_"):
			world._advance_worker(worker)
		elif Feeding.handle_idle(world, worker, true):
			return true
		elif int(worker["blocked_ticks"]) > 0:
			worker["blocked_ticks"] = int(worker["blocked_ticks"]) - 1
		else:
			world._resume_carried_ware(worker)
		return true
	if worker["action"] == "pause_return":
		world._advance_worker(worker)
		return true
	if Feeding.handle_idle(world, worker, true):
		return true
	if world.is_worker_inside(worker):
		var inside: Dictionary = world.buildings.get(int(worker["inside_building_id"]), {})
		if inside.get("type", "") == "inn":
			world._try_exit_worker_building(worker)
		return true
	if world.tick < int(worker.get("_pause_retry_until", 0)) or world.tick < int(worker.get("yield_rest_until", 0)):
		return true
	var home: int = int(worker.get("home_id", 0))
	if home == 0 and worker["type"] != "recruit" and not world.catalog.soldiers.has(String(worker["type"])):
		home = world._nearest_building("warehouse", worker["position"])
	var building: Dictionary = world.buildings.get(home, {})
	worker["_pause_retry_until"] = world.tick + RETRY_TICKS
	if not world.is_local_entity(building) or not world.is_building_complete(building):
		return true
	worker["action"] = "pause_return"
	worker["destination_id"] = home
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	blockers.erase(building["entrance"])
	if not world._move_worker_to(worker, building["entrance"], blockers):
		world._release_worker_task(worker)
	return true


static func arrive(world: Variant, worker: Dictionary) -> bool:
	if worker["action"] != "pause_return":
		return false
	var home: int = int(worker["destination_id"])
	var building: Dictionary = world.buildings.get(home, {})
	if not worker_paused(world, worker) or not world.is_local_entity(building) or not world.is_building_complete(building):
		world._release_worker_task(worker)
	elif world._enter_worker_building(worker, home):
		world._release_worker_task(worker)
	return true


static func reconsider_blocked(world: Variant, worker: Dictionary) -> bool:
	if worker["action"] != "pause_return":
		return false
	world._release_worker_task(worker)
	worker["_pause_retry_until"] = world.tick + RETRY_TICKS
	return true
