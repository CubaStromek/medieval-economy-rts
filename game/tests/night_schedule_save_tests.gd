extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_owned_hut_sleep_round_trip,
		_test_shared_sleep_keeps_cargo_until_dawn,
		_test_return_home_route_is_rebuilt,
		_test_legacy_night_saves_keep_goods,
		_test_legacy_rations_pause_before_resuming,
		_test_invalid_sleep_homes_are_transactional,
		_test_sleepers_share_virtual_doorway_after_load,
		_test_night_meal_keeps_cargo_after_load,
		_test_workplace_claim_updates_previous_warehouse_bed,
	]:
		test.call(failures)
	return failures


static func _test_owned_hut_sleep_round_trip(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(14, 10))
	var hut: int = source.place_building("lumber_hut", Vector2i(5, 3))
	var worker_id: int = source.spawn_worker(Vector2i(9, 7), "lumberjack", hut)
	source.tick = 3750
	if not _until(source, func() -> bool: return source.is_worker_sleeping(source.workers[worker_id])):
		failures.append("The save fixture's real lumberjack must reach and sleep inside its owned hut")
		return
	var before: Dictionary = source.to_data()
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(source)):
		failures.append("A real worker sleeping in its own hut must survive JSON loading")
		return
	_check(restored.to_data() == before and restored.workers[worker_id]["sleep_home_id"] == hut
		and restored.workers[worker_id]["home_id"] == hut
		and restored.workers[worker_id]["inside_building_id"] == hut
		and restored.tile_reservations.is_empty(),
		"Loading a hut sleeper must preserve its clock, owned workplace and hidden location without an invisible road blocker", failures)
	_advance(restored, 40)
	_check(restored.is_worker_sleeping(restored.workers[worker_id])
		and restored.workers[worker_id]["inside_building_id"] == hut,
		"A restored outdoor specialist must remain asleep instead of automatically starting work inside its hut", failures)


static func _test_shared_sleep_keeps_cargo_until_dawn(failures: Array[String]) -> void:
	var f: Dictionary = _warehouse_sleep_fixture()
	var source: Variant = f["world"]
	var carrier: int = int(f["carrier"])
	var builder: int = int(f["builder"])
	if not _until(source, func() -> bool:
		return source.is_worker_sleeping(source.workers[carrier]) and source.is_worker_sleeping(source.workers[builder])
	):
		failures.append("The carrier and builder must both physically enter their shared warehouse before the save test")
		return
	var restored: Variant = source
	for _load: int in range(3):
		var before: Dictionary = restored.to_data()
		var next = LegacyFixture.create()
		if not next.from_data(_json(restored)):
			failures.append("Two warehouse sleepers sharing one virtual entrance must survive repeated loading")
			return
		_check(next.to_data() == before and next.workers[carrier]["carrying"] == "stone"
			and next.stored_amount("stone") == 0,
			"Night loading must not deliver a sleeper's carried stone as a zero-length warehouse path side effect", failures)
		restored = next
		_advance(restored, 10)
	restored.tick = 5998
	restored.step_tick()
	_check(restored.is_worker_sleeping(restored.workers[carrier])
		and restored.is_worker_sleeping(restored.workers[builder])
		and restored.workers[carrier]["carrying"] == "stone",
		"Repeatedly restored civilian workers must still sleep with their original cargo at 04:59", failures)
	restored.step_tick()
	_check(not restored.is_worker_sleeping(restored.workers[carrier])
		and not restored.is_worker_sleeping(restored.workers[builder]),
		"The saved shared warehouse sleepers must wake when the restored clock reaches 05:00", failures)
	_check(_until(restored, func() -> bool: return restored.stored_amount("stone") == 1, 100)
		and int(restored.resource_stock("stone")["total"]) == 1,
		"After dawn the saved carrier must deliver its original stone exactly once", failures)


static func _test_return_home_route_is_rebuilt(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(18, 12))
	var store: int = source.place_building("warehouse", Vector2i(2, 2))
	var worker_id: int = source.spawn_worker(Vector2i(15, 9), "carrier")
	source.tick = 4000
	source.step_tick()
	_check(source.workers[worker_id]["sleep_home_id"] == store
		and not source.is_worker_inside(source.workers[worker_id]),
		"The walking save fixture must have selected its real warehouse while still outside", failures)
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(source)):
		failures.append("A civilian already returning home must load without saving its transient route")
		return
	_check(restored.to_data() == source.to_data()
		and restored.workers[worker_id]["sleep_home_id"] == store,
		"Loading a return-home journey must retain the selected bedroom and exact saved world position", failures)
	_check(_until(restored, func() -> bool: return restored.is_worker_sleeping(restored.workers[worker_id]), 1000)
		and restored.workers[worker_id]["inside_building_id"] == store,
		"The loaded journey must rebuild a usable path and physically enter the previously selected warehouse", failures)


static func _test_legacy_night_saves_keep_goods(failures: Array[String]) -> void:
	for version: int in [13, 14]:
		var source = LegacyFixture.create(Vector2i(10, 8))
		var store: int = source.place_building("warehouse", Vector2i(4, 3))
		var worker_id: int = source.spawn_worker(source.buildings[store]["entrance"], "carrier")
		source.workers[worker_id]["carrying"] = "stone"
		source.buildings[store]["storage"]["log"] = 3
		source.tick = 10749
		var legacy: Dictionary = _json(source)
		legacy["version"] = version
		for worker: Dictionary in legacy["workers"]:
			worker.erase("sleep_home_id")
			if version < 14:
				worker.erase("meal_course")
		var restored = LegacyFixture.create()
		if not restored.from_data(legacy):
			failures.append("Historical v%d nighttime saves must load without sleep-home fields" % version)
			continue
		_check(restored.tick == source.tick and restored.to_data() == LegacyFixture.expected_pre_fog_migration(source.to_data())
			and restored.workers[worker_id]["sleep_home_id"] == 0
			and restored.workers[worker_id]["carrying"] == "stone",
			"Night migration must preserve all original goods and positions without assigning or entering a new home during loading", failures)
		_check(_until(restored, func() -> bool: return restored.is_worker_sleeping(restored.workers[worker_id]), 100)
			and restored.workers[worker_id]["inside_building_id"] == store
			and restored.stored_amount("stone") == 0 and restored.stored_amount("log") == 3,
			"On its next ticks a legacy sandbox citizen must adopt the night schedule without first unloading or losing cargo", failures)


static func _test_legacy_rations_pause_before_resuming(failures: Array[String]) -> void:
	for phase: String in ["pickup", "deliver"]:
		var source = LegacyFixture.create(Vector2i(18, 12))
		var store: int = source.place_building("warehouse", Vector2i(2, 2))
		var carrier: int = source.spawn_worker(Vector2i(8, 4), "carrier")
		var soldier: int = source.spawn_worker(Vector2i(14, 8), "militia")
		source.buildings[store]["storage"]["bread"] = 1
		source.workers[soldier]["hunger"] = 1000
		source.economy_enabled = true
		source.request_soldier_food(soldier)
		if not _until(source, func() -> bool: return source.workers[carrier]["ration_delivery"].get("phase", "") == phase):
			failures.append("The legacy night save fixture must first obtain a real %s food mission" % phase)
			continue
		source.tick = 4000
		var legacy: Dictionary = _json(source)
		legacy["version"] = 13
		for worker: Dictionary in legacy["workers"]:
			worker.erase("sleep_home_id")
			worker.erase("meal_course")
		var restored = LegacyFixture.create()
		if not restored.from_data(legacy):
			failures.append("A historical %s ration mission saved at night must load" % phase)
			continue
		_check(restored.to_data() == LegacyFixture.expected_pre_fog_migration(source.to_data()),
			"Loading a nighttime ration must preserve its original reserved or carried stock without executing the mission", failures)
		restored.step_tick()
		_check((restored.workers[carrier]["ration_delivery"] as Dictionary).is_empty()
			and bool(restored.workers[soldier]["food_requested"])
			and int(restored.resource_stock("bread")["total"]) == 1,
			"The first restored night tick must release the food assignment while retaining the soldier's request and actual bread", failures)
		_check(_until(restored, func() -> bool: return restored.is_worker_sleeping(restored.workers[carrier]), 700)
			and bool(restored.workers[soldier]["food_requested"])
			and restored.workers[carrier]["carrying"] == ("bread" if phase == "deliver" else ""),
			"The restored carrier must sleep without collecting another ration or feeding the soldier before dawn", failures)


static func _test_invalid_sleep_homes_are_transactional(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(18, 12))
	var store: int = source.place_building("warehouse", Vector2i(2, 2))
	var hut: int = source.place_building("lumber_hut", Vector2i(6, 3))
	var other_hut: int = source.place_building("lumber_hut", Vector2i(10, 3))
	var carrier: int = source.spawn_worker(Vector2i(3, 8), "carrier")
	var specialist: int = source.spawn_worker(Vector2i(6, 8), "lumberjack", hut)
	var soldier: int = source.spawn_worker(Vector2i(9, 8), "militia")
	var recruit: int = source.spawn_worker(Vector2i(12, 8), "recruit")
	source.economy_enabled = true
	var unfinished: int = source.place_building("warehouse", Vector2i(14, 3))
	if unfinished == 0 or source.is_building_complete(source.buildings[unfinished]):
		failures.append("Sleep validation fixture must include a real unfinished warehouse")
		return
	var cases: Array[Dictionary] = [
		{"id": carrier, "value": null, "missing": true},
		{"id": carrier, "value": "1"}, {"id": carrier, "value": true},
		{"id": carrier, "value": -1}, {"id": carrier, "value": 1.5},
		{"id": carrier, "value": 99999}, {"id": carrier, "value": unfinished},
		{"id": carrier, "value": hut}, {"id": specialist, "value": other_hut},
		{"id": specialist, "value": store}, {"id": soldier, "value": store},
		{"id": recruit, "value": store},
	]
	for changes: Dictionary in cases:
		var invalid: Dictionary = _json(source)
		var saved: Dictionary = _saved_worker(invalid, int(changes["id"]))
		if bool(changes.get("missing", false)):
			saved.erase("sleep_home_id")
		else:
			saved["sleep_home_id"] = changes["value"]
		var live = LegacyFixture.create(Vector2i(8, 8))
		var live_store: int = live.place_building("warehouse", Vector2i(2, 2))
		live.buildings[live_store]["storage"]["stone"] = 9
		live.spawn_worker(Vector2i(5, 5), "builder")
		var before: Dictionary = live.to_data()
		var grid: Variant = live.grid
		var workers: Dictionary = live.workers.duplicate(true)
		var reservations: Dictionary = live.tile_reservations.duplicate()
		_check(not live.from_data(invalid) and live.to_data() == before
			and live.grid == grid and live.workers == workers and live.tile_reservations == reservations,
			"Invalid sleep-home data must be rejected transactionally: %s" % changes, failures)


static func _test_sleepers_share_virtual_doorway_after_load(failures: Array[String]) -> void:
	var f: Dictionary = _warehouse_sleep_fixture()
	var source: Variant = f["world"]
	var carrier: int = int(f["carrier"])
	var builder: int = int(f["builder"])
	if not _until(source, func() -> bool:
		return source.is_worker_sleeping(source.workers[carrier]) and source.is_worker_sleeping(source.workers[builder])
	):
		failures.append("Doorway save fixture must first contain two genuine shared warehouse sleepers")
		return
	var door: Vector2i = source.buildings[f["store"]]["entrance"]
	var outside: int = source.spawn_worker(door, "recruit")
	if outside == 0:
		failures.append("A visible recruit must be able to stand outside two sleeping warehouse occupants")
		return
	for reversed: bool in [false, true]:
		var data: Dictionary = _json(source)
		if reversed:
			data["workers"].reverse()
		var restored = LegacyFixture.create()
		if not restored.from_data(data):
			failures.append("Shared sleepers and their visible doorway occupant must load independently of saved worker order")
			continue
		_check(restored.to_data() == source.to_data() and restored.tile_reservations.size() == 1
			and int(restored.tile_reservations.get(door, 0)) == outside
			and restored.is_worker_inside(restored.workers[carrier])
			and restored.is_worker_inside(restored.workers[builder])
			and not restored.is_worker_inside(restored.workers[outside]),
			"Only the visible doorway occupant may reserve the tile after loading multiple sleeping residents", failures)


static func _test_night_meal_keeps_cargo_after_load(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(10, 8))
	var inn: int = source.place_building("inn", Vector2i(4, 3))
	var carrier: int = source.spawn_worker(source.buildings[inn]["entrance"], "carrier")
	source.buildings[inn]["inputs"]["bread"] = 1
	source.buildings[inn]["inputs"]["sausage"] = 1
	source.workers[carrier]["carrying"] = "stone"
	source.workers[carrier]["hunger"] = 100
	source.economy_enabled = true
	source.tick = 4000
	if not _until(source, func() -> bool: return int(source.workers[carrier]["meal_ticks_left"]) > 0, 50):
		failures.append("A hungry nighttime carrier without a bedroom must be able to start a real meal while retaining cargo")
		return
	_advance(source, 5)
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(source)):
		failures.append("A legitimate nighttime meal with carried cargo must survive current-schema JSON loading")
		return
	_check(restored.to_data() == source.to_data()
		and restored.workers[carrier]["carrying"] == "stone"
		and restored.inn_occupied_seats(inn) == 1,
		"Night meal loading must preserve its exact paid course, occupied seat and original carried ware", failures)
	# Already-started meals remain valid when their countdown crosses dawn.
	restored.tick = 5999
	var dawn = LegacyFixture.create()
	if not dawn.from_data(_json(restored)):
		failures.append("A saved loaded meal with cargo must also remain valid immediately before dawn")
		return
	dawn.step_tick()
	var after_dawn = LegacyFixture.create()
	_check(after_dawn.from_data(_json(dawn))
		and after_dawn.workers[carrier]["carrying"] == "stone",
		"A civilian meal started at night must remain saveable with cargo after the clock reaches daytime", failures)


static func _test_workplace_claim_updates_previous_warehouse_bed(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(14, 10))
	var store: int = source.place_building("warehouse", Vector2i(3, 3))
	var worker_id: int = source.spawn_worker(Vector2i(8, 7), "lumberjack")
	source.tick = 4000
	if not _until(source, func() -> bool: return source.is_worker_sleeping(source.workers[worker_id])):
		failures.append("The unemployed specialist must first genuinely sleep in the communal warehouse")
		return
	_check(source.workers[worker_id]["home_id"] == 0
		and source.workers[worker_id]["sleep_home_id"] == store,
		"An unemployed specialist's first night must retain the warehouse as its actual saved bedroom", failures)
	source.tick = 5999
	source.step_tick()
	var hut: int = source.place_building("lumber_hut", Vector2i(9, 3))
	var assigned: int = source.ensure_workplace(source.workers[worker_id])
	_check(hut != 0 and assigned == hut and source.workers[worker_id]["home_id"] == hut
		and source.workers[worker_id]["sleep_home_id"] == hut,
		"Claiming a new daytime workplace must replace the unemployed specialist's previous warehouse bedroom with its owned hut", failures)
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(source)):
		failures.append("A specialist who acquired a workplace after warehouse sleep must remain JSON-saveable immediately after claiming the hut")
		return
	_check(restored.to_data() == source.to_data()
		and restored.workers[worker_id]["home_id"] == hut
		and restored.workers[worker_id]["sleep_home_id"] == hut,
		"Daytime workplace acquisition must round-trip with its updated bedroom and exact physical location", failures)
	restored.tick = 9750
	_check(_until(restored, func() -> bool: return restored.is_worker_sleeping(restored.workers[worker_id]))
		and restored.workers[worker_id]["inside_building_id"] == hut,
		"On the next night the restored specialist must physically sleep in the new hut instead of returning to its old warehouse bed", failures)


static func _warehouse_sleep_fixture() -> Dictionary:
	var world = LegacyFixture.create(Vector2i(12, 9))
	var store: int = world.place_building("warehouse", Vector2i(5, 3))
	var carrier: int = world.spawn_worker(Vector2i(2, 6), "carrier")
	var builder: int = world.spawn_worker(Vector2i(8, 6), "builder")
	world.workers[carrier]["carrying"] = "stone"
	world.tick = 4000
	return {"world": world, "store": store, "carrier": carrier, "builder": builder}


static func _saved_worker(data: Dictionary, id: int) -> Dictionary:
	for worker: Dictionary in data["workers"]:
		if int(worker["id"]) == id:
			return worker
	return {}


static func _until(world: Variant, condition: Callable, ticks: int = 700) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
