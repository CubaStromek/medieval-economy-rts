extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_real_operator_resumes_inside,
		_test_visitors_and_outdoor_door_occupant_round_trip,
		_test_corrupt_indoor_state_is_transactional,
		_test_v11_remains_outdoors,
		_test_indoor_death_preserves_outdoor_reservation,
		_test_blocked_exit_survives_load_and_eventually_delivers,
	]:
		test.call(failures)
	return failures


static func _test_real_operator_resumes_inside(failures: Array[String]) -> void:
	var source = World.new(Vector2i(12, 9))
	var sawmill: int = source.place_building("sawmill", Vector2i(5, 4))
	var carpenter: int = source.spawn_worker(Vector2i(2, 6), "carpenter", sawmill)
	if sawmill == 0 or carpenter == 0:
		failures.append("Indoor carpenter fixture must initialize a real owned sawmill")
		return
	source.buildings[sawmill]["inputs"]["log"] = 1
	source.economy_enabled = true
	if not _until(source, func() -> bool:
		return source.is_worker_inside(source.workers[carpenter]) and int(source.buildings[sawmill]["process_remaining"]) > 0
	, 200):
		failures.append("A real carpenter must walk into the sawmill and start its supplied batch before the save test")
		return
	_advance(source, 7)
	var remaining: int = int(source.buildings[sawmill]["process_remaining"])
	_check(remaining > 0 and int(source.buildings[sawmill]["inputs"]["log"]) == 0,
		"The indoor save must pause an in-flight batch whose single log was already consumed", failures)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("An actual working indoor carpenter must survive JSON save/load")
		return
	_check(restored.is_worker_inside(restored.workers[carpenter])
		and int(restored.workers[carpenter]["inside_building_id"]) == sawmill
		and int(restored.workers[carpenter]["home_id"]) == sawmill
		and int(restored.buildings[sawmill]["process_remaining"]) == remaining
		and restored.tile_reservations.is_empty(),
		"Loading must retain the carpenter's indoor location, exclusive workplace and exact paid batch remainder without an invisible blocker", failures)
	_advance(restored, 250)
	_check(int(restored.buildings[sawmill]["outputs"]["plank"]) == 2
		and int(restored.buildings[sawmill]["inputs"]["log"]) == 0,
		"An indoor saved batch must produce its two planks exactly once without consuming the log again", failures)
	_check(restored.is_worker_inside(restored.workers[carpenter])
		and int(restored.workers[carpenter]["home_id"]) == sawmill,
		"An operator waiting for more inputs must stay inside its own workplace after loading", failures)


static func _test_visitors_and_outdoor_door_occupant_round_trip(failures: Array[String]) -> void:
	for outside_first: bool in [false, true]:
		var fixture: Dictionary = _door_fixture(outside_first)
		if not _fixture_valid(fixture, failures):
			continue
		var source: Variant = fixture["world"]
		var inside: int = int(fixture["inside"])
		source.workers[inside]["indoor_wait_ticks"] = 4
		for reversed: bool in [false, true]:
			var snapshot: Dictionary = _json(source)
			if reversed:
				snapshot["workers"].reverse()
			var restored = World.new()
			if not restored.from_data(snapshot):
				failures.append("Two indoor visitors and one outdoor person sharing the virtual doorway must load independently of IDs and JSON array order")
				continue
			_check(restored.workers.size() == 3 and restored.tile_reservations.size() == 1
				and int(restored.tile_reservations.get(fixture["door"], 0)) == int(fixture["outside"]),
				"Only the outdoor visitor may reserve the doorway after loading overlapping virtual indoor positions", failures)
			_check(restored.is_worker_inside(restored.workers[inside])
				and restored.is_worker_inside(restored.workers[int(fixture["visitor"])])
				and not restored.is_worker_inside(restored.workers[int(fixture["outside"])])
				and int(restored.workers[inside]["indoor_wait_ticks"]) == 4,
				"JSON round trip must preserve both indoor visitors, outdoor visibility and the exact remaining indoor dwell", failures)
			_check(restored.to_data() == source.to_data(),
				"Restoring indoor visitors must not mutate cargo, citizens, locations or persistent simulation state", failures)


static func _test_corrupt_indoor_state_is_transactional(failures: Array[String]) -> void:
	var fixture: Dictionary = _door_fixture(true)
	if not _fixture_valid(fixture, failures):
		return
	var source: Variant = fixture["world"]
	source.economy_enabled = true
	var unfinished: int = source.place_building("school", Vector2i(1, 6))
	if unfinished == 0 or source.is_building_complete(source.buildings[unfinished]):
		failures.append("Indoor corruption fixture must include a genuinely unfinished building")
		return
	var inside: int = int(fixture["inside"])
	var outside: int = int(fixture["outside"])
	var cases: Array[Dictionary] = [
		{"name": "missing inside reference", "change": func(data: Dictionary): _saved_worker(data, inside).erase("inside_building_id")},
		{"name": "missing dwell", "change": func(data: Dictionary): _saved_worker(data, inside).erase("indoor_wait_ticks")},
		{"name": "string inside reference", "change": func(data: Dictionary): _saved_worker(data, inside)["inside_building_id"] = "1"},
		{"name": "boolean inside reference", "change": func(data: Dictionary): _saved_worker(data, inside)["inside_building_id"] = true},
		{"name": "negative inside reference", "change": func(data: Dictionary): _saved_worker(data, inside)["inside_building_id"] = -1},
		{"name": "unknown building", "change": func(data: Dictionary): _saved_worker(data, inside)["inside_building_id"] = 99999},
		{"name": "unfinished building", "change": func(data: Dictionary): _saved_worker(data, inside)["inside_building_id"] = unfinished; _saved_worker(data, inside)["position"] = [1, 5]},
		{"name": "wrong virtual doorway", "change": func(data: Dictionary): _saved_worker(data, inside)["position"] = [0, 0]},
		{"name": "building footprint instead of doorway", "change": func(data: Dictionary): _saved_worker(data, inside)["position"] = [4, 3]},
		{"name": "negative dwell", "change": func(data: Dictionary): _saved_worker(data, inside)["indoor_wait_ticks"] = -1},
		{"name": "overlong dwell", "change": func(data: Dictionary): _saved_worker(data, inside)["indoor_wait_ticks"] = 7},
		{"name": "fractional dwell", "change": func(data: Dictionary): _saved_worker(data, inside)["indoor_wait_ticks"] = 1.5},
		{"name": "boolean dwell", "change": func(data: Dictionary): _saved_worker(data, inside)["indoor_wait_ticks"] = false},
		{"name": "outdoor dwell", "change": func(data: Dictionary): _saved_worker(data, outside)["indoor_wait_ticks"] = 1},
		{"name": "two outdoor doorway occupants", "change": func(data: Dictionary): _saved_worker(data, inside)["inside_building_id"] = 0; _saved_worker(data, inside)["indoor_wait_ticks"] = 0},
	]
	for test_case: Dictionary in cases:
		var invalid: Dictionary = _json(source)
		(test_case["change"] as Callable).call(invalid)
		var live = World.new(Vector2i(8, 8))
		var store: int = live.place_building("warehouse", Vector2i(2, 2))
		live.buildings[store]["storage"]["stone"] = 9
		live.spawn_worker(Vector2i(4, 5), "carrier")
		var before: Dictionary = live.to_data()
		var grid: Variant = live.grid
		var board: Variant = live.task_board
		var workers: Dictionary = live.workers.duplicate(true)
		var reservations: Dictionary = live.tile_reservations.duplicate()
		var events: Array = live.event_log.duplicate()
		_check(not live.from_data(invalid), "Indoor validation must reject " + test_case["name"], failures)
		_check(live.to_data() == before and live.grid == grid and live.task_board == board
			and live.workers == workers and live.tile_reservations == reservations and live.event_log == events,
			"Rejecting indoor corruption must leave the live game completely unchanged: " + test_case["name"], failures)


static func _test_v11_remains_outdoors(failures: Array[String]) -> void:
	var source = World.new(Vector2i(10, 8))
	var hut: int = source.place_building("lumber_hut", Vector2i(4, 3))
	var owner: int = source.spawn_worker(source.buildings[hut]["entrance"], "lumberjack", hut)
	var carrier: int = source.spawn_worker(Vector2i(7, 6), "carrier")
	if hut == 0 or owner == 0 or carrier == 0:
		failures.append("The v11 migration fixture must contain two real outdoor citizens")
		return
	var legacy: Dictionary = _json(source)
	legacy["version"] = 11
	for worker: Dictionary in legacy["workers"]:
		worker.erase("inside_building_id")
		worker.erase("indoor_wait_ticks")
	var restored = World.new()
	if not restored.from_data(legacy):
		failures.append("A genuine v11 snapshot without indoor fields must load")
		return
	_check(restored.workers.size() == 2 and restored.tile_reservations.size() == 2
		and not restored.is_worker_inside(restored.workers[owner]) and not restored.is_worker_inside(restored.workers[carrier])
		and restored.to_data() == source.to_data(),
		"Legacy outdoor workers, including one already at its hut entrance, must load visibly without fabricated indoor visits", failures)


static func _test_indoor_death_preserves_outdoor_reservation(failures: Array[String]) -> void:
	var fixture: Dictionary = _door_fixture(true)
	if not _fixture_valid(fixture, failures):
		return
	var source: Variant = fixture["world"]
	var doomed: int = int(fixture["inside"])
	source.workers[doomed]["carrying"] = ""
	source.workers[doomed]["hunger"] = 1
	source.tick = int(source.catalog.economy.get("condition_interval_ticks", 10)) - 1
	source.economy_enabled = true
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A starving indoor visitor sharing a visible person's doorway must load")
		return
	_protect_door_occupant(restored, int(fixture["outside"]))
	restored.step_tick()
	_check(not restored.workers.has(doomed) and restored.workers.has(int(fixture["outside"]))
		and int(restored.tile_reservations.get(fixture["door"], 0)) == int(fixture["outside"]),
		"A hidden citizen's death must not remove the outdoor person's reservation at the same virtual doorway", failures)


static func _test_blocked_exit_survives_load_and_eventually_delivers(failures: Array[String]) -> void:
	var fixture: Dictionary = _door_fixture(true)
	if not _fixture_valid(fixture, failures):
		return
	var source: Variant = fixture["world"]
	var inside: int = int(fixture["inside"])
	source.workers[inside]["indoor_wait_ticks"] = 0
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A carrier waiting inside with cargo at an occupied exit must load")
		return
	_protect_door_occupant(restored, int(fixture["outside"]))
	_advance(restored, 20)
	_check(restored.is_worker_inside(restored.workers[inside]) and restored.workers[inside]["carrying"] == "log"
		and int(restored.tile_reservations.get(fixture["door"], 0)) == int(fixture["outside"]),
		"A blocked indoor exit must preserve hidden cargo and the outdoor occupant without overwriting or teleporting", failures)
	var outside: Dictionary = restored.workers[int(fixture["outside"])]
	restored._reset_worker(outside)
	if not restored._move_worker_to(outside, Vector2i(1, 2)):
		failures.append("The blocking outdoor visitor must have a legal route away from the doorway")
		return
	var saw_visible_carrier: bool = false
	for _tick: int in range(300):
		restored.step_tick()
		if not restored.is_worker_inside(restored.workers[inside]) and restored.workers[inside]["carrying"] == "log":
			saw_visible_carrier = true
			_check(int(restored.tile_reservations.get(restored.workers[inside]["position"], 0)) == inside,
				"A carrier leaving a saved indoor visit must become visible only with its own outdoor reservation", failures)
		if restored.stored_amount("log") == 1:
			break
	_check(saw_visible_carrier and restored.stored_amount("log") == 1
		and int(restored.resource_stock("log")["total"]) == 1,
		"Once the doorway clears, the saved carrier must visibly leave and deliver its one original log exactly once", failures)


static func _door_fixture(outside_first: bool) -> Dictionary:
	var world = World.new(Vector2i(12, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(4, 3))
	world.place_building("warehouse", Vector2i(9, 3))
	var door: Vector2i = world.buildings[hut]["entrance"]
	var outside: int = 0
	if outside_first:
		outside = world.spawn_worker(door, "builder")
	var inside: int = world.spawn_worker(door, "carrier", 0, false, hut)
	var visitor: int = world.spawn_worker(door, "builder", 0, false, hut)
	if not outside_first:
		outside = world.spawn_worker(door, "builder")
	if inside != 0:
		world.workers[inside]["carrying"] = "log"
		world.workers[inside]["indoor_wait_ticks"] = 6
	if visitor != 0:
		world.workers[visitor]["indoor_wait_ticks"] = 6
	return {"world": world, "hut": hut, "door": door, "inside": inside, "outside": outside, "visitor": visitor}


static func _fixture_valid(fixture: Dictionary, failures: Array[String]) -> bool:
	var valid: bool = int(fixture["hut"]) != 0 and int(fixture["inside"]) != 0
	valid = valid and int(fixture["outside"]) != 0 and int(fixture["visitor"]) != 0
	_check(valid, "Doorway fixture must create two genuine indoor visitors and one outdoor occupant", failures)
	return valid


static func _protect_door_occupant(world: Variant, id: int) -> void:
	# Isolate blocked-exit/death ownership from the separate legal idle-yield
	# behavior. This busy phase begins after loading because jobs are transient.
	var worker: Dictionary = world.workers[id]
	worker["state"] = "working"
	worker["action"] = "build_site"


static func _saved_worker(data: Dictionary, id: int) -> Dictionary:
	for worker: Dictionary in data["workers"]:
		if int(worker["id"]) == id:
			return worker
	return {}


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
