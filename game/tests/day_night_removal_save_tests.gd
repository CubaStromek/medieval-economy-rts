extends RefCounted

## The day/night cycle, sleeping places, Workers' Cottage and night wolves were
## removed on 2026-09-14 (save v23). Older saves must keep loading.
const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_catalog_and_api_no_longer_offer_the_cycle,
		_test_v22_sleep_and_wolf_state_is_dropped,
		_test_v22_cottage_residents_move_outdoors,
		_test_work_continues_at_former_night_ticks]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _worker_data(data: Dictionary, id: int) -> Dictionary:
	for worker: Dictionary in data["workers"]:
		if int(worker["id"]) == id:
			return worker
	return {}


static func _test_catalog_and_api_no_longer_offer_the_cycle(failures: Array[String]) -> void:
	var world := World.new(Vector2i(16, 12))
	_check(not world.catalog.buildings.has("workers_house") and not world.catalog.economy.has("condition_sleep_multiplier"),
		"The catalog must no longer contain the Workers' Cottage or a sleeping appetite", failures)
	for method: String in ["calendar_time", "is_night_rest_time", "is_worker_sleeping", "follows_daily_schedule", "residence_occupancy"]:
		_check(not world.has_method(method), "The removed day/night query %s must not remain on the world" % method, failures)
	_check(not ("wolves" in world), "Night wolves must not remain world state", failures)
	var data: Dictionary = world.to_data()
	_check(int(data["version"]) == 23 and not data.has("wolves") and not data.has("wolves_spawned_night"),
		"Save v23 must not write wolf state", failures)


static func _test_v22_sleep_and_wolf_state_is_dropped(failures: Array[String]) -> void:
	var world := World.new(Vector2i(16, 12))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	var resident: int = world.spawn_worker(world.buildings[store]["entrance"], "carrier", 0, true, store)
	var outdoor: int = world.spawn_worker(Vector2i(12, 8), "carrier")
	if store == 0 or resident == 0 or outdoor == 0:
		failures.append("The v22 fixture must contain a real warehouse and two citizens")
		return
	world.tick = 4750
	var data: Dictionary = _json(world)
	data["version"] = 22
	_worker_data(data, resident)["sleep_home_id"] = store
	_worker_data(data, outdoor)["sleep_home_id"] = store
	data["wolves"] = [{"id": 99, "position": [14, 10], "previous_position": [14, 10], "target_cell": [14, 10],
		"prey_id": outdoor, "move_cooldown": 0, "leaving": false, "visit_until": 5000, "stops_left": 2,
		"stop_index": 0, "visual_progress_ticks": 1, "visual_duration_ticks": 1}]
	data["wolves_spawned_night"] = 1
	data["next_entity_id"] = 100
	var restored := World.new()
	_check(restored.from_data(data), "A v22 save with sleeping places and night wolves must still load", failures)
	if restored.workers.size() != 2:
		failures.append("Loading a v22 save must keep both citizens")
		return
	_check(restored.is_worker_inside(restored.workers[resident]) and not restored.is_worker_inside(restored.workers[outdoor])
		and restored.tick == 4750, "Loading must keep each citizen's real location and the saved tick", failures)
	var saved: Dictionary = restored.to_data()
	_check(int(saved["version"]) == 23 and not saved.has("wolves") and not saved.has("wolves_spawned_night")
		and not _worker_data(saved, resident).has("sleep_home_id"),
		"Re-saving must write v23 without wolves or sleeping places", failures)
	for _tick: int in range(20):
		restored.step_tick()
	_check(restored.workers.size() == 2, "A former night-time save must continue without any wolf attack", failures)


static func _test_v22_cottage_residents_move_outdoors(failures: Array[String]) -> void:
	var world := World.new(Vector2i(18, 12))
	var house: int = world.place_building("forester_hut", Vector2i(6, 4))
	var first: int = world.spawn_worker(Vector2i(1, 10), "carrier")
	var second: int = world.spawn_worker(Vector2i(2, 10), "builder")
	var bystander: int = world.spawn_worker(Vector2i(16, 10), "carrier")
	if house == 0 or first == 0 or second == 0 or bystander == 0:
		failures.append("The cottage migration fixture must contain a real house and three citizens")
		return
	var entrance: Vector2i = world.buildings[house]["entrance"]
	var data: Dictionary = _json(world)
	data["version"] = 22
	# Reuse genuine building geometry, but save it under the removed type.
	for building: Dictionary in data["buildings"]:
		if int(building["id"]) == house:
			building["type"] = "workers_house"
	for id: int in [first, second]:
		var worker: Dictionary = _worker_data(data, id)
		worker["position"] = [entrance.x, entrance.y]
		worker["inside_building_id"] = house
		worker["indoor_wait_ticks"] = 0
		worker["sleep_home_id"] = house
	var restored := World.new()
	_check(restored.from_data(data), "A v22 save with an occupied Workers' Cottage must load without it", failures)
	if restored.workers.size() != 3:
		failures.append("Cottage migration must keep both former residents and the bystander")
		return
	var a: Dictionary = restored.workers[first]
	var b: Dictionary = restored.workers[second]
	_check(restored.buildings.is_empty() and not restored.grid.blocked_by.values().has(house),
		"The removed cottage must neither load nor keep blocking its former cells", failures)
	_check(not restored.is_worker_inside(a) and not restored.is_worker_inside(b) and a["position"] != b["position"]
		and restored.grid.is_walkable(a["position"]) and restored.grid.is_walkable(b["position"])
		and int(restored.tile_reservations.get(a["position"], 0)) == first
		and int(restored.tile_reservations.get(b["position"], 0)) == second,
		"Both former residents must stand outdoors on distinct walkable reserved cells", failures)
	_check(a["position"] == entrance and (b["position"] as Vector2i).distance_to(entrance) < 2.0,
		"Relocation must start at the former doorway and use the nearest free cell", failures)
	var again := World.new()
	_check(again.from_data(_json(restored)) and _json(again) == _json(restored),
		"A migrated settlement must round-trip as a v23 save", failures)


static func _test_work_continues_at_former_night_ticks(failures: Array[String]) -> void:
	var world := World.new(Vector2i(18, 12))
	var hut: int = world.place_building("lumber_hut", Vector2i(6, 4))
	var id: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", hut)
	if hut == 0 or id == 0:
		failures.append("The work fixture must contain a real hut and lumberjack")
		return
	world.add_tree(Vector2i(13, 9), 3)
	world.tick = 3750 # The removed schedule's former 20:00.
	var harvested: bool = false
	for _tick: int in range(1500):
		world.step_tick()
		if int(world.buildings[hut]["outputs"].get("log", 0)) > 0:
			harvested = true
			break
	_check(harvested and world.can_worker_work(world.workers[id]),
		"Civilians must keep working at every tick, including the former night hours", failures)
