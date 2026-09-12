extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_empty_residence_contract,
		_test_exact_capacity_and_automatic_night_assignment,
		_test_specialists_and_soldiers_are_excluded,
		_test_only_valid_owned_reachable_residences_are_selected,
		_test_disabled_residence_releases_and_reassigns,
		_test_foreign_warehouse_is_not_a_sleeping_place,
		_test_residents_survive_save_load,
		_test_invalid_saved_residents_are_rejected_atomically,
		_test_residents_leave_for_real_daytime_work,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 1000) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _json_snapshot(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _saved_worker(data: Dictionary, id: int) -> Dictionary:
	for worker: Dictionary in data["workers"]:
		if int(worker["id"]) == id:
			return worker
	return {}


static func _resident_ids(world: Variant, residence: int) -> Array[int]:
	var result: Array[int] = []
	for id: Variant in world.residence_occupancy(residence).get("residents", []):
		result.append(int(id))
	result.sort()
	return result


static func _sleeping_count(world: Variant, ids: Array[int]) -> int:
	var count: int = 0
	for id: int in ids:
		if world.is_worker_sleeping(world.workers[id]):
			count += 1
	return count


static func _inventory_amount(inventory: Dictionary) -> int:
	var result: int = 0
	for amount: Variant in inventory.values():
		result += int(amount)
	return result


static func _test_empty_residence_contract(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(12, 9))
	var house: int = world.place_building("workers_house", Vector2i(5, 3))
	_check(house != 0 and not world.catalog.building("workers_house").is_empty(),
		"The workers' house must be a real placeable building definition", failures)
	if house == 0:
		return
	var occupancy: Dictionary = world.residence_occupancy(house)
	_check(int(occupancy.get("capacity", -1)) == 2
		and int(occupancy.get("occupied", -1)) == 0
		and (occupancy.get("residents", []) as Array).is_empty(),
		"A new workers' house must expose exactly two empty resident places", failures)


static func _test_exact_capacity_and_automatic_night_assignment(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(20, 12))
	var house: int = world.place_building("workers_house", Vector2i(8, 3))
	var carrier: int = world.spawn_worker(Vector2i(6, 9), "carrier", 0, false)
	var builder: int = world.spawn_worker(Vector2i(9, 9), "builder", 0, false)
	var surplus: int = world.spawn_worker(Vector2i(14, 9), "carrier", 0, false)
	world.economy_enabled = true
	_advance(world, 20)
	_check(_resident_ids(world, house).is_empty(),
		"Workers' houses must be assigned by the night schedule rather than claiming citizens during the workday", failures)
	world.tick = 3750
	var ids: Array[int] = [carrier, builder, surplus]
	var slept: bool = _until(world, func() -> bool:
		return _sleeping_count(world, ids) == 2
	)
	var occupancy: Dictionary = world.residence_occupancy(house)
	var residents: Array[int] = _resident_ids(world, house)
	_check(slept and int(occupancy.get("capacity", 0)) == 2
		and int(occupancy.get("occupied", 0)) == 2 and residents.size() == 2,
		"One workers' house must autonomously lodge exactly two eligible citizens at night", failures)
	_check(residents.has(carrier) and residents.has(builder) and not residents.has(surplus)
		and int(world.workers[surplus]["sleep_home_id"]) == 0,
		"The first carrier and builder may fill the two beds, while a third eligible citizen must remain unassigned", failures)
	_check(String(world.worker_schedule_status(world.workers[surplus])) == "No sleeping place available",
		"A third citizen must remain visibly homeless instead of silently exceeding house capacity", failures)


static func _test_specialists_and_soldiers_are_excluded(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(22, 12))
	var house: int = world.place_building("workers_house", Vector2i(9, 3))
	var ids: Array[int] = []
	for entry: Array in [
		["gardener", Vector2i(3, 9)],
		["farmer", Vector2i(7, 9)],
		["recruit", Vector2i(12, 9)],
		["militia", Vector2i(17, 9)],
	]:
		ids.append(world.spawn_worker(entry[1], String(entry[0]), 0, false))
	world.economy_enabled = true
	world.tick = 3750
	_advance(world, 160)
	var excluded: bool = true
	for id: int in ids:
		excluded = excluded and id != 0 and int(world.workers[id]["sleep_home_id"]) != house
	_check(excluded and _resident_ids(world, house).is_empty()
		and int(world.residence_occupancy(house).get("occupied", -1)) == 0,
		"Specialists, recruits and soldiers must never consume carrier-and-builder housing places", failures)


static func _test_only_valid_owned_reachable_residences_are_selected(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(24, 13))
	var valid: int = world.place_building("workers_house", Vector2i(2, 3))
	var disabled: int = world.place_building("workers_house", Vector2i(6, 3))
	var unfinished: int = world.place_building("workers_house", Vector2i(9, 3))
	var foreign: int = world.place_building("workers_house", Vector2i(12, 3), 2)
	var unreachable: int = world.place_building("workers_house", Vector2i(19, 3))
	world.set_building_enabled(disabled, false)
	world.buildings[unfinished]["construction_remaining"] = 1
	for y: int in range(world.grid.size.y):
		world.grid.set_base_terrain(Vector2i(15, y), "water")
	var carrier: int = world.spawn_worker(Vector2i(13, 10), "carrier", 0, false)
	_check(world.residence_has_room(valid, carrier)
		and not world.residence_has_room(disabled, carrier)
		and not world.residence_has_room(unfinished, carrier)
		and not world.residence_has_room(foreign, carrier)
		and not world.residence_has_room(unreachable, carrier),
		"The public vacancy query must include ownership, completion, activity and reachability rules", failures)
	world.economy_enabled = true
	world.tick = 3750
	var selected: bool = _until(world, func() -> bool:
		return world.is_worker_sleeping(world.workers[carrier])
	)
	_check(selected and int(world.workers[carrier]["sleep_home_id"]) == valid
		and int(world.workers[carrier]["inside_building_id"]) == valid,
		"Night housing must skip closer foreign, unfinished, disabled and unreachable houses in favor of a valid reachable one", failures)
	for invalid: int in [disabled, unfinished, foreign, unreachable]:
		_check(_resident_ids(world, invalid).is_empty(),
			"Invalid residence candidate %d must not reserve a bed" % invalid, failures)


static func _test_disabled_residence_releases_and_reassigns(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(26, 12))
	var first: int = world.place_building("workers_house", Vector2i(5, 3))
	var second: int = world.place_building("workers_house", Vector2i(13, 3))
	var warehouse: int = world.place_building("warehouse", Vector2i(21, 3))
	var carrier: int = world.spawn_worker(Vector2i(6, 9), "carrier", 0, false)
	world.economy_enabled = true
	world.tick = 3750
	if not _until(world, func() -> bool:
		return world.is_worker_sleeping(world.workers[carrier]) and int(world.workers[carrier]["sleep_home_id"]) == first
	):
		failures.append("The reassignment fixture must first sleep in its nearest enabled workers' house")
		return
	world.set_building_enabled(first, false)
	var moved: bool = _until(world, func() -> bool:
		return world.is_worker_sleeping(world.workers[carrier]) and int(world.workers[carrier]["sleep_home_id"]) == second
	)
	_check(moved and _resident_ids(world, first).is_empty() and _resident_ids(world, second) == [carrier],
		"Disabling an occupied residence must release its bed and move the citizen into another enabled house", failures)
	world.set_building_enabled(second, false)
	var used_fallback: bool = _until(world, func() -> bool:
		return world.is_worker_sleeping(world.workers[carrier]) and int(world.workers[carrier]["sleep_home_id"]) == warehouse
	)
	_check(used_fallback and _resident_ids(world, first).is_empty() and _resident_ids(world, second).is_empty(),
		"When every workers' house is disabled, the existing communal warehouse fallback must remain available", failures)


static func _test_foreign_warehouse_is_not_a_sleeping_place(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(22, 12))
	var foreign: int = world.place_building("warehouse", Vector2i(3, 3), 2)
	var local: int = world.place_building("warehouse", Vector2i(14, 3))
	var carrier: int = world.spawn_worker(Vector2i(6, 9), "carrier", 0, false)
	world.workers[carrier]["sleep_home_id"] = foreign
	world.economy_enabled = true
	world.tick = 3750
	var reassigned: bool = _until(world, func() -> bool:
		return world.is_worker_sleeping(world.workers[carrier])
	)
	_check(reassigned and int(world.workers[carrier]["sleep_home_id"]) == local
		and int(world.workers[carrier]["inside_building_id"]) == local,
		"A citizen must reject a foreign warehouse assignment and use an owned fallback", failures)
	var invalid: Dictionary = _json_snapshot(world)
	var invalid_worker: Dictionary = _saved_worker(invalid, carrier)
	invalid_worker["sleep_home_id"] = foreign
	invalid_worker["inside_building_id"] = 0
	invalid_worker["indoor_wait_ticks"] = 0
	var target: Variant = LegacyFixture.create()
	target.setup_demo()
	var unchanged: Dictionary = _json_snapshot(target)
	_check(not target.from_data(invalid) and _json_snapshot(target) == unchanged,
		"A current save must reject a foreign warehouse sleeping assignment atomically", failures)


static func _test_residents_survive_save_load(failures: Array[String]) -> void:
	var source: Variant = LegacyFixture.create(Vector2i(20, 12))
	var house: int = source.place_building("workers_house", Vector2i(8, 3))
	var ids: Array[int] = [
		source.spawn_worker(Vector2i(5, 9), "carrier", 0, false),
		source.spawn_worker(Vector2i(10, 9), "builder", 0, false),
		source.spawn_worker(Vector2i(15, 9), "carrier", 0, false),
	]
	source.economy_enabled = true
	source.tick = 3750
	if not _until(source, func() -> bool: return _sleeping_count(source, ids) == 2):
		failures.append("The housing save fixture must reach two real sleeping residents")
		return
	var before: Dictionary = _json_snapshot(source)
	var residents: Array[int] = _resident_ids(source, house)
	var restored: Variant = LegacyFixture.create()
	var accepted: bool = restored.from_data(before)
	_check(accepted, "A current save containing a full workers' house must load successfully", failures)
	if not accepted:
		return
	_check(_json_snapshot(restored) == before and _resident_ids(restored, house) == residents
		and int(restored.residence_occupancy(house).get("occupied", 0)) == 2,
		"Save/load must preserve both resident IDs and the exact two-person capacity without hidden building state", failures)
	_advance(restored, 120)
	var resident_tiles_clear: bool = true
	for resident: int in residents:
		resident_tiles_clear = resident_tiles_clear \
			and int(restored.tile_reservations.get(restored.workers[resident]["position"], 0)) != resident
	_check(_sleeping_count(restored, residents) == 2 and resident_tiles_clear
		and int(restored.workers[ids[2]]["sleep_home_id"]) == 0,
		"Loaded residents must remain indoors without reserving outdoor tiles while the third citizen remains outside the full residence", failures)


static func _test_invalid_saved_residents_are_rejected_atomically(failures: Array[String]) -> void:
	var source: Variant = LegacyFixture.create(Vector2i(20, 12))
	var house: int = source.place_building("workers_house", Vector2i(8, 3))
	var ids: Array[int] = [
		source.spawn_worker(Vector2i(5, 9), "carrier", 0, false),
		source.spawn_worker(Vector2i(10, 9), "builder", 0, false),
		source.spawn_worker(Vector2i(15, 9), "carrier", 0, false),
	]
	source.economy_enabled = true
	source.tick = 3750
	if not _until(source, func() -> bool: return _resident_ids(source, house).size() == 2):
		failures.append("The invalid-save fixture must first fill a real two-person workers' house")
		return
	var baseline: Dictionary = _json_snapshot(source)
	var residents: Array[int] = _resident_ids(source, house)
	var surplus: int = 0
	for id: int in ids:
		if not residents.has(id):
			surplus = id
	var over_capacity: Dictionary = baseline.duplicate(true)
	_saved_worker(over_capacity, surplus)["sleep_home_id"] = house
	var wrong_role: Dictionary = baseline.duplicate(true)
	_saved_worker(wrong_role, residents[0])["type"] = "gardener"
	for entry: Dictionary in [
		{"name": "third resident", "data": over_capacity},
		{"name": "specialist resident", "data": wrong_role},
	]:
		var target: Variant = LegacyFixture.create()
		target.setup_demo()
		var unchanged: Dictionary = _json_snapshot(target)
		_check(not target.from_data(entry["data"])
			and _json_snapshot(target) == unchanged,
			"Current saves must reject a %s without partially replacing the live world" % String(entry["name"]), failures)


static func _test_residents_leave_for_real_daytime_work(failures: Array[String]) -> void:
	var world: Variant = LegacyFixture.create(Vector2i(22, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
	var house: int = world.place_building("workers_house", Vector2i(9, 3))
	world.buildings[warehouse]["storage"]["plank"] = 12
	world.buildings[warehouse]["storage"]["stone"] = 12
	world.economy_enabled = true
	var site: int = world.place_building("bakery", Vector2i(17, 3))
	var carrier: int = world.spawn_worker(Vector2i(7, 9), "carrier", 0, false)
	var builder: int = world.spawn_worker(Vector2i(12, 9), "builder", 0, false)
	var residents: Array[int] = [carrier, builder]
	world.tick = 3750
	if not _until(world, func() -> bool: return _sleeping_count(world, residents) == 2):
		failures.append("The daytime-work fixture must first lodge both workers in their house")
		return
	var initial_remaining: int = int(world.buildings[site]["construction_remaining"])
	world.tick = 5999
	var both_departed: bool = false
	var supplied: bool = false
	var built: bool = false
	for _tick: int in range(2200):
		world.step_tick()
		both_departed = both_departed or (not world.is_worker_inside(world.workers[carrier])
			and not world.is_worker_inside(world.workers[builder]))
		supplied = supplied or _inventory_amount(world.buildings[site]["construction_delivered"]) > 0
		built = built or int(world.buildings[site]["construction_remaining"]) < initial_remaining
		if both_departed and supplied and built:
			break
	_check(both_departed and supplied and built,
		"At 05:00 the resident carrier must deliver real materials and the resident builder must resume real construction", failures)
	_check(_resident_ids(world, house) == residents
		and int(world.workers[carrier]["sleep_home_id"]) == house
		and int(world.workers[builder]["sleep_home_id"]) == house,
		"Daytime work must retain both permanent bed assignments for the following night", failures)
