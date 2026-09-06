extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_invalid_shapes(failures)
	_test_invalid_values(failures)
	_test_late_failure_is_transactional(failures)
	_test_valid_snapshots_and_migrations(failures)
	return failures


static func _fixture() -> Variant:
	var world = LegacyFixture.create(Vector2i(9, 7))
	world.place_building("school", Vector2i(1, 1))
	world.place_building("sawmill", Vector2i(5, 2))
	world.place_building("warehouse", Vector2i(7, 5))
	world.place_building("lumber_hut", Vector2i(2, 5))
	world.add_tree(Vector2i(5, 5), 3)
	world.spawn_worker(Vector2i(0, 3), "carrier")
	world.spawn_worker(Vector2i(2, 3), "lumberjack")
	world.spawn_worker(Vector2i(4, 3), "gardener")
	return world


static func _test_invalid_shapes(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"name": "missing version", "mutate": func(data: Dictionary): data.erase("version")},
		{"name": "missing tick", "mutate": func(data: Dictionary): data.erase("tick")},
		{"name": "missing next ID", "mutate": func(data: Dictionary): data.erase("next_entity_id")},
		{"name": "missing buildings", "mutate": func(data: Dictionary): data.erase("buildings")},
		{"name": "missing trees", "mutate": func(data: Dictionary): data.erase("trees")},
		{"name": "missing workers", "mutate": func(data: Dictionary): data.erase("workers")},
		{"name": "non-array buildings", "mutate": func(data: Dictionary): data["buildings"] = {}},
		{"name": "non-array trees", "mutate": func(data: Dictionary): data["trees"] = 1},
		{"name": "non-array workers", "mutate": func(data: Dictionary): data["workers"] = "[]"},
		{"name": "non-object building", "mutate": func(data: Dictionary): data["buildings"] = [null]},
		{"name": "non-object tree", "mutate": func(data: Dictionary): data["trees"] = [[]]},
		{"name": "non-object worker", "mutate": func(data: Dictionary): data["workers"] = [3]},
		{"name": "empty map size", "mutate": func(data: Dictionary): data["map_size"] = []},
		{"name": "empty building position", "mutate": func(data: Dictionary): data["buildings"][0]["position"] = []},
		{"name": "short entrance", "mutate": func(data: Dictionary): data["buildings"][0]["entrance"] = [0]},
		{"name": "tree position object", "mutate": func(data: Dictionary): data["trees"][0]["position"] = {}},
		{"name": "worker position null", "mutate": func(data: Dictionary): data["workers"][0]["position"] = null},
		{"name": "empty road coordinate", "mutate": func(data: Dictionary): data["roads"] = [[]]},
		{"name": "empty trail coordinate", "mutate": func(data: Dictionary): data["dirt_trails"] = [[]]},
		{"name": "short wear entry", "mutate": func(data: Dictionary): data["traffic_wear"] = [[0, 0]]},
		{"name": "missing production timer", "mutate": func(data: Dictionary): data["buildings"][1].erase("process_remaining")},
		{"name": "production timer array", "mutate": func(data: Dictionary): data["buildings"][1]["process_remaining"] = []},
		{"name": "inventory array", "mutate": func(data: Dictionary): data["buildings"][0]["storage"] = []},
		{"name": "input inventory null", "mutate": func(data: Dictionary): data["buildings"][0]["inputs"] = null},
		{"name": "output inventory string", "mutate": func(data: Dictionary): data["buildings"][0]["outputs"] = "log"},
		{"name": "queue string", "mutate": func(data: Dictionary): data["buildings"][0]["training_queue"] = "carrier"},
		{"name": "queue item object", "mutate": func(data: Dictionary): data["buildings"][0]["training_queue"] = [{}]},
		{"name": "terrain row object", "mutate": func(data: Dictionary): data["terrain"]["base"][0] = {}},
		{"name": "terrain cell numeric", "mutate": func(data: Dictionary): data["terrain"]["base"][0][0] = 0},
		{"name": "carried resource object", "mutate": func(data: Dictionary): data["workers"][0]["carrying"] = {}},
	]
	_check_rejections(cases, failures)


static func _test_invalid_values(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"name": "fractional version", "mutate": func(data: Dictionary): data["version"] = 4.5},
		{"name": "string tick", "mutate": func(data: Dictionary): data["tick"] = "1"},
		{"name": "boolean tick", "mutate": func(data: Dictionary): data["tick"] = true},
		{"name": "negative tick", "mutate": func(data: Dictionary): data["tick"] = -1},
		{"name": "infinite tick", "mutate": func(data: Dictionary): data["tick"] = INF},
		{"name": "NaN tick", "mutate": func(data: Dictionary): data["tick"] = NAN},
		{"name": "unsafe numeric ID", "mutate": func(data: Dictionary): data["next_entity_id"] = 9007199254740992.0},
		{"name": "zero map width", "mutate": func(data: Dictionary): data["map_size"] = [0, 7]},
		{"name": "huge map width", "mutate": func(data: Dictionary): data["map_size"] = [257, 7]},
		{"name": "fractional coordinate", "mutate": func(data: Dictionary): data["workers"][0]["position"] = [0.5, 3]},
		{"name": "off-map coordinate", "mutate": func(data: Dictionary): data["workers"][0]["position"] = [9, 3]},
		{"name": "negative resource", "mutate": func(data: Dictionary): data["buildings"][0]["storage"]["log"] = -1},
		{"name": "fractional resource", "mutate": func(data: Dictionary): data["buildings"][0]["storage"]["log"] = 1.5},
		{"name": "unknown resource", "mutate": func(data: Dictionary): data["buildings"][0]["storage"]["unknown"] = 1},
		{"name": "negative process timer", "mutate": func(data: Dictionary): data["buildings"][1]["process_remaining"] = -1},
		{"name": "oversized process timer", "mutate": func(data: Dictionary): data["buildings"][1]["process_remaining"] = 99999},
		{"name": "negative training timer", "mutate": func(data: Dictionary): data["buildings"][0]["training_remaining"] = -1},
		{"name": "unknown building type", "mutate": func(data: Dictionary): data["buildings"][0]["type"] = "unknown"},
		{"name": "unknown worker type", "mutate": func(data: Dictionary): data["workers"][0]["type"] = "unknown"},
		{"name": "unsupported carried resource", "mutate": func(data: Dictionary): data["workers"][0]["carrying"] = "unknown"},
		{"name": "gardener carrying log", "mutate": func(data: Dictionary): data["workers"][2]["carrying"] = "log"},
		{"name": "duplicate IDs across entity types", "mutate": func(data: Dictionary): data["workers"][0]["id"] = data["trees"][0]["id"]},
		{"name": "reused next ID", "mutate": func(data: Dictionary): data["next_entity_id"] = 1},
		{"name": "invalid home reference", "mutate": func(data: Dictionary): data["workers"][1]["home_id"] = 999},
	]
	_check_rejections(cases, failures)


static func _check_rejections(cases: Array[Dictionary], failures: Array[String]) -> void:
	for test_case: Dictionary in cases:
		var live = _fixture()
		live.step_tick()
		var snapshot: Dictionary = live.to_data()
		var grid: Variant = live.grid
		var board: Variant = live.task_board
		var workers: Dictionary = live.workers.duplicate(true)
		var events: Array = live.event_log.duplicate()
		# JSON arrays are untyped; corruption must not be blocked by the typed
		# arrays returned by to_data before it reaches the snapshot validator.
		var invalid: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
		(test_case["mutate"] as Callable).call(invalid)
		if live.from_data(invalid):
			failures.append("Save validation accepted %s" % test_case["name"])
		if (
			live.to_data() != snapshot or live.grid != grid or live.task_board != board
			or live.workers != workers or live.event_log != events
		):
			failures.append("Rejected %s changed the live world" % test_case["name"])


static func _test_late_failure_is_transactional(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"name": "last worker overlaps building", "mutate": func(data: Dictionary): data["workers"][2]["position"] = data["buildings"][0]["position"]},
		{"name": "duplicate worker cell", "mutate": func(data: Dictionary): data["workers"][2]["position"] = data["workers"][0]["position"]},
		{"name": "duplicate tree cell", "mutate": _duplicate_tree_cell},
		{"name": "nonadjacent entrance", "mutate": func(data: Dictionary): data["buildings"][3]["entrance"] = [8, 0]},
		{"name": "road underneath building", "mutate": func(data: Dictionary): data["roads"] = [data["buildings"][0]["position"]]},
		{"name": "wear underneath building", "mutate": func(data: Dictionary): data["traffic_wear"] = [[1, 1, 1]]},
	]
	_check_rejections(cases, failures)


static func _duplicate_tree_cell(data: Dictionary) -> void:
	var duplicate: Dictionary = data["trees"][0].duplicate(true)
	duplicate["id"] = data["next_entity_id"]
	data["next_entity_id"] += 1
	data["trees"].append(duplicate)


static func _test_valid_snapshots_and_migrations(failures: Array[String]) -> void:
	var source = _fixture()
	source.queue_unit_training(1, "carrier")
	source.buildings[2]["inputs"]["log"] = 1
	for tick_index: int in range(7):
		source.step_tick()
	var snapshot: Dictionary = source.to_data()
	var from_json: Variant = JSON.parse_string(JSON.stringify(snapshot))
	var restored = LegacyFixture.create()
	if not restored.from_data(from_json):
		failures.append("Valid JSON snapshot with integral floats was rejected")
		return
	if restored.to_data() != snapshot:
		failures.append("Valid snapshot changed persistent state during round trip")
	for tick_index: int in range(100):
		restored.step_tick()
	if restored.workers.size() != 4:
		failures.append("Restored training did not finish with validated state")
	for version: int in range(1, 5):
		var legacy: Dictionary = snapshot.duplicate(true)
		legacy["version"] = version
		for tree: Dictionary in legacy["trees"]:
			tree.erase("age_ticks")
		for worker: Dictionary in legacy["workers"]:
			worker.erase("planting_cooldown")
			if version == 1:
				worker.erase("type")
				worker.erase("home_id")
		if version < 4:
			legacy.erase("terrain")
		if version < 3:
			for building: Dictionary in legacy["buildings"]:
				building.erase("training_queue")
				building.erase("training_remaining")
		if version == 1:
			legacy.erase("dirt_trails")
			legacy.erase("traffic_wear")
		var migrated = LegacyFixture.create()
		if not migrated.from_data(legacy):
			failures.append("Valid version %d save migration failed" % version)
			continue
		for tick_index: int in range(20):
			migrated.step_tick()
