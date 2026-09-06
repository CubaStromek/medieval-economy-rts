extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_pickup_round_trip, _test_carried_round_trip,
		_test_pending_order_without_stock, _test_meal_round_trip,
		_test_corrupt_feeding_is_transactional, _test_v12_migration,
		_test_course_corruption, _test_v13_paid_meal_migration]:
		test.call(failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _until(world: Variant, condition: Callable, ticks: int = 600) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _fixture() -> Dictionary:
	var world = LegacyFixture.create(Vector2i(18, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	var carrier: int = world.spawn_worker(Vector2i(8, 4), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(14, 8), "militia")
	world.buildings[warehouse]["storage"]["bread"] = 1
	world.workers[soldier]["hunger"] = 1000
	world.economy_enabled = true
	world.request_soldier_food(soldier)
	return {"world": world, "warehouse": warehouse, "carrier": carrier, "soldier": soldier}


static func _test_pickup_round_trip(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	var carrier: int = int(f["carrier"])
	var soldier: int = int(f["soldier"])
	world.step_tick()
	_check(world.workers[carrier]["ration_delivery"].get("phase", "") == "pickup",
		"A real carrier must reserve a physical ration before its pickup round trip", failures)
	var saved: Dictionary = _json(world)
	var restored = LegacyFixture.create()
	if not restored.from_data(saved):
		failures.append("A valid reservation before pickup must survive JSON loading")
		return
	_check(restored.to_data() == world.to_data() and restored.stored_amount("bread") == 1,
		"Loading a reserved ration must not pick it up, alter nutrition or invent a second unit", failures)
	_check(_until(restored, func() -> bool: return not bool(restored.workers[soldier]["food_requested"])),
		"The saved empty-handed carrier must resume its reserved pickup and feed its original recipient", failures)
	_check(restored.resource_stock("bread")["total"] == 0 and restored.workers[soldier]["hunger"] > 2600,
		"Exactly one saved ration must become one full military meal", failures)


static func _test_carried_round_trip(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	var carrier: int = int(f["carrier"])
	var soldier: int = int(f["soldier"])
	if not _until(world, func() -> bool: return world.workers[carrier]["carrying"] == "bread"):
		failures.append("The save fixture must physically collect its ration before testing in-flight saves")
		return
	var saved: Dictionary = _json(world)
	var restored = LegacyFixture.create()
	if not restored.from_data(saved):
		failures.append("A real carried ration and its intended soldier must load")
		return
	_check(restored.to_data() == world.to_data() and restored.resource_stock("bread")["carried"] == 1,
		"Loading must retain the carried ration without another withdrawal or delivery", failures)
	for _pass: int in range(3):
		restored.step_tick()
		var next = LegacyFixture.create()
		if not next.from_data(_json(restored)):
			failures.append("Repeated in-flight saves must remain reloadable")
			return
		restored = next
	_check(_until(restored, func() -> bool: return not bool(restored.workers[soldier]["food_requested"])),
		"Repeated loading cannot lose or strand the original soldier's ration", failures)
	_check(restored.resource_stock("bread")["total"] == 0 and restored.workers.size() == 2,
		"Repeated loading must not duplicate stock or units", failures)


static func _test_pending_order_without_stock(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	world.buildings[f["warehouse"]]["storage"]["bread"] = 0
	for _tick: int in range(10):
		world.step_tick()
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(world)):
		failures.append("An unfilled food request without a stock reservation must load")
		return
	_check(bool(restored.workers[f["soldier"]]["food_requested"]),
		"A pending manual order must persist through a temporary stock shortage", failures)
	restored.buildings[f["warehouse"]]["storage"]["bread"] = 1
	_check(_until(restored, func() -> bool: return not bool(restored.workers[f["soldier"]]["food_requested"])),
		"New stock must satisfy a previously saved food order without another player click", failures)


static func _test_meal_round_trip(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(10, 8))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "builder")
	world.buildings[inn]["inputs"]["bread"] = 2
	world.buildings[inn]["inputs"]["wine"] = 2
	world.buildings[inn]["inputs"]["fish"] = 2
	world.workers[id]["hunger"] = 100
	world.economy_enabled = true
	world.step_tick()
	for _tick: int in range(58):
		world.step_tick()
	var remaining: int = int(world.workers[id]["meal_ticks_left"])
	_check(remaining == 58 and world.inn_occupied_seats(inn) == 1 and world.workers[id]["hunger"] == 640,
		"Meal save fixture must contain a half-eaten bread course, with only half its nutrition applied", failures)
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(world)):
		failures.append("The middle of a progressive three-course meal must load")
		return
	_check(restored.to_data() == world.to_data(), "Loading must preserve exact partial nutrition without withdrawing another serving", failures)
	for segment: int in [58, 116, 57, 20, 39]:
		for _tick: int in range(segment):
			world.step_tick()
			restored.step_tick()
		_check(restored.to_data() == world.to_data(), "Meal continuation must match uninterrupted play at and between course boundaries", failures)
		var next = LegacyFixture.create()
		if not next.from_data(_json(restored)):
			failures.append("Every course boundary and the final seated state must remain loadable")
			return
		restored = next
	_check(restored.workers[id]["meal_ticks_left"] == 0 and restored.inn_occupied_seats(inn) == 0,
		"The exact saved meal timer must finish and release the seat", failures)
	_check(restored.buildings[inn]["inputs"]["bread"] == 1 and restored.buildings[inn]["inputs"]["wine"] == 1
		and restored.buildings[inn]["inputs"]["fish"] == 1
		and restored.workers[id]["hunger"] == 2700,
		"Finishing a saved meal consumes no extra servings and does not decay satiety while eating", failures)
	_check(_until(restored, func() -> bool: return not restored.is_worker_inside(restored.workers[id]), 30),
		"A diner must physically exit after eating even when there is no available work", failures)


static func _test_corrupt_feeding_is_transactional(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	world.step_tick()
	var id: int = int(f["carrier"])
	var cases: Array[Dictionary] = [
		{"meal_ticks_left": -1}, {"meal_ticks_left": 1},
		{"food_requested": true}, {"food_requested": "true"},
		{"ration_delivery": {"recipient_id": f["warehouse"], "source_id": f["warehouse"], "ware": "bread", "phase": "pickup"}},
		{"ration_delivery": {"recipient_id": f["soldier"], "source_id": f["warehouse"], "ware": "grain", "phase": "pickup"}},
		{"ration_delivery": {"recipient_id": f["soldier"], "source_id": f["warehouse"], "ware": "bread", "phase": "deliver"}},
		{"ration_delivery": {"recipient_id": f["soldier"], "source_id": 9999, "ware": "bread", "phase": "pickup"}},
	]
	for changes: Dictionary in cases:
		var saved: Dictionary = _json(world)
		for worker: Dictionary in saved["workers"]:
			if int(worker["id"]) == id:
				worker.merge(changes, true)
		var live = LegacyFixture.create()
		live.setup_demo()
		var before: Dictionary = live.to_data()
		_check(not live.from_data(saved) and live.to_data() == before,
			"Corrupt food state must be rejected without touching the live world: %s" % changes, failures)
	var duplicate: Dictionary = _json(world)
	var extra: Dictionary = (duplicate["workers"][0] as Dictionary).duplicate(true)
	extra["id"] = duplicate["next_entity_id"]
	extra["position"] = [8, 8]
	duplicate["next_entity_id"] = int(duplicate["next_entity_id"]) + 1
	duplicate["workers"].append(extra)
	_check(not LegacyFixture.create().from_data(duplicate), "Two carriers may not restore claims for one soldier's meal", failures)


static func _test_v12_migration(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	var saved: Dictionary = _json(world)
	saved["version"] = 12
	for worker: Dictionary in saved["workers"]:
		worker.erase("meal_ticks_left")
		worker.erase("meal_course")
		worker.erase("food_requested")
		worker.erase("ration_delivery")
	var restored = LegacyFixture.create()
	if not restored.from_data(saved):
		failures.append("V12 saves must load without new food fields")
		return
	_check(restored.stored_amount("bread") == 1 and restored.workers[f["soldier"]]["hunger"] == 1000,
		"Migrating an old save must preserve its actual food and satiety", failures)
	_check(not bool(restored.workers[f["soldier"]]["food_requested"])
		and (restored.workers[f["carrier"]]["ration_delivery"] as Dictionary).is_empty(),
		"Old saves begin with no invented food orders or reservations", failures)


static func _test_course_corruption(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(10, 8))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "builder")
	world.buildings[inn]["inputs"]["bread"] = 2
	world.workers[id]["hunger"] = 100
	world.economy_enabled = true
	world.step_tick()
	world.step_tick()
	var course: Dictionary = world.workers[id]["meal_course"]
	var corruptions: Array[Dictionary] = [
		{"food": "grain"}, {"food": "wine"}, {"duration_ticks": 0},
		{"duration_ticks": 117}, {"restore": 999999}, {"applied": 0},
		{"applied": 1080}, {"foods_eaten": []}, {"foods_eaten": "bread"},
		{"foods_eaten": ["bread", "bread"]}, {"foods_eaten": ["bread", "wine"]},
		{"foods_eaten": ["grain", "bread"]}, {"extra_payload": true},
	]
	for changes: Dictionary in corruptions:
		var saved: Dictionary = _json(world)
		var invalid_course: Dictionary = course.duplicate(true)
		invalid_course.merge(changes, true)
		saved["workers"][0]["meal_course"] = invalid_course
		var before: Dictionary = world.to_data()
		_check(not world.from_data(saved) and world.to_data() == before,
			"Malformed meal progress must fail transactionally: %s" % changes, failures)
	for field: String in ["meal_course", "meal_ticks_left"]:
		var missing: Dictionary = _json(world)
		missing["workers"][0].erase(field)
		_check(not LegacyFixture.create().from_data(missing), "V14 must require its saved meal fields: %s" % field, failures)
	var finished: Dictionary = _json(world)
	finished["workers"][0]["meal_ticks_left"] = 0
	_check(not LegacyFixture.create().from_data(finished), "A completed visit must not retain a live course", failures)


static func _test_v13_paid_meal_migration(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(10, 8))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "builder")
	world.buildings[inn]["inputs"]["bread"] = 2
	world.workers[id]["hunger"] = 100
	world.economy_enabled = true
	world.step_tick()
	var saved: Dictionary = _json(world)
	saved["version"] = 13
	saved["workers"][0].erase("meal_course")
	saved["workers"][0]["meal_ticks_left"] = 200
	saved["workers"][0]["hunger"] = 2700
	var restored = LegacyFixture.create()
	if not restored.from_data(saved):
		failures.append("V13 must retain its already-paid meal countdown without a new course")
		return
	for _tick: int in range(100):
		restored.step_tick()
	var next = LegacyFixture.create()
	if not next.from_data(_json(restored)):
		failures.append("A migrated legacy meal must also survive a v14 re-save")
		return
	for _tick: int in range(100):
		next.step_tick()
	_check(next.workers[id]["meal_ticks_left"] == 0 and next.workers[id]["hunger"] == 2700
		and next.buildings[inn]["inputs"]["bread"] == 1 and next.inn_occupied_seats(inn) == 0,
		"An already-paid legacy meal only finishes waiting: it cannot consume or restore twice", failures)
