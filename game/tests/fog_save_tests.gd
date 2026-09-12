extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_exploration_and_owners_round_trip,
		_test_visibility_is_rebuilt_from_current_sources,
		_test_intentionally_disabled_fog_stays_disabled,
		_test_local_player_and_owner_boundaries,
		_test_legacy_maps_remain_explored_on_activation,
		_test_malformed_fog_is_transactional,
		_test_malformed_owners_are_transactional,
		_test_supported_map_size_boundaries,
		_test_serialization_is_observational,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data()))


static func _fixture() -> Dictionary:
	var world = World.new(Vector2i(40, 24))
	var store: int = world.place_building("warehouse", Vector2i(5, 17), 1)
	var foreign: int = world.place_building("watchtower", Vector2i(30, 17), 2)
	var own: int = world.spawn_worker(Vector2i(3, 3), "builder", 0, false, 0, 1)
	var enemy: int = world.spawn_worker(Vector2i(30, 3), "builder", 0, false, 0, 2)
	var neutral: int = world.spawn_worker(Vector2i(20, 20), "builder", 0, false, 0, 0)
	world.buildings[store]["storage"]["stone"] = 7
	world.enable_fog()
	return {"world": world, "store": store, "foreign": foreign, "own": own, "enemy": enemy, "neutral": neutral}


static func _test_exploration_and_owners_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var worker: Dictionary = world.workers[fixture["own"]]
	worker["action"] = "test_fog_walk"
	_check(world._move_worker_to(worker, Vector2i(12, 3)), "A fog save fixture must begin a real exploration walk", failures)
	for _tick: int in range(100):
		world.step_tick()
	_check(world.is_cell_explored(Vector2i(0, 3)) and not world.is_cell_visible(Vector2i(0, 3))
		and world.is_cell_visible(Vector2i(12, 3)) and not world.is_cell_explored(Vector2i(39, 0)),
		"The save must contain explored darkness, current sight and never-explored land after actual movement", failures)
	var restored = World.new()
	_check(restored.from_data(_json(world)), "V18 must load a real partially explored settlement", failures)
	_check(restored.to_data() == world.to_data() and restored.tick == world.tick
		and restored.tile_reservations == world.tile_reservations,
		"Fog JSON round trip must retain exact exploration, owners, clock, stock and worker reservations", failures)
	_check(restored.fog.visible == world.fog.visible and not restored.is_cell_visible(Vector2i(30, 3))
		and not restored.is_cell_visible(Vector2i(30, 17)) and not restored.is_cell_visible(Vector2i(20, 20)),
		"Loaded current sight must come only from local sources, not foreign units, foreign towers or neutral citizens", failures)
	_check(int(restored.workers[fixture["enemy"]]["owner_id"]) == 2
		and int(restored.workers[fixture["neutral"]]["owner_id"]) == 0
		and int(restored.buildings[fixture["foreign"]]["owner_id"]) == 2,
		"Worker and building allegiance must survive independently of whether those entities are visible", failures)


static func _test_visibility_is_rebuilt_from_current_sources(failures: Array[String]) -> void:
	var world = World.new(Vector2i(32, 16))
	world.spawn_worker(Vector2i(3, 3), "builder", 0, false)
	world.enable_fog()
	var saved: Dictionary = _json(world)
	_check(not saved["fog"].has("visible") and int(saved["version"]) == World.SAVE_VERSION,
		"The v18 save stores explored knowledge, never a trusted live visibility mask", failures)
	# Move the serialized source but keep its former explored area. Loading
	# must derive sight from the current source, not from old exploration.
	saved["workers"][0]["position"] = [20, 3]
	saved["tick"] = 123
	var restored = World.new()
	_check(restored.from_data(saved) and restored.tick == 123,
		"Rebuilding visibility while loading must not advance simulation time", failures)
	_check(restored.is_cell_visible(Vector2i(20, 3)) and restored.is_cell_explored(Vector2i(20, 3))
		and restored.is_cell_explored(Vector2i(3, 3)) and not restored.is_cell_visible(Vector2i(3, 3)),
		"Only the restored source position lights the map while old discovered cells retain their exploration", failures)


static func _test_intentionally_disabled_fog_stays_disabled(failures: Array[String]) -> void:
	var world = World.new(Vector2i(10, 8))
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(4, 4)]
	world.fog.restore_explored(cells)
	world.fog.local_player_id = 2
	var restored = World.new()
	_check(restored.from_data(_json(world)) and not restored.fog.enabled
		and not restored.fog.legacy_reveal_pending and restored.to_data() == world.to_data(),
		"An intentionally disabled v18 save preserves its exploration/player setting and is not mistaken for a legacy game needing activation", failures)
	var reversed: Dictionary = _json(world)
	reversed["fog"]["explored"].reverse()
	_check(restored.from_data(reversed) and restored.to_data() == world.to_data(),
		"Unique explored cells may load in any input order and serialize deterministically", failures)


static func _test_local_player_and_owner_boundaries(failures: Array[String]) -> void:
	var world = World.new(Vector2i(36, 18))
	var local: int = world.spawn_worker(Vector2i(3, 3), "builder", 0, false, 0, 16)
	var other: int = world.spawn_worker(Vector2i(30, 3), "builder", 0, false, 0, 1)
	var neutral: int = world.place_building("warehouse", Vector2i(25, 13), 0)
	world.enable_fog(16)
	var restored = World.new()
	_check(restored.from_data(_json(world)) and int(restored.fog.local_player_id) == 16
		and int(restored.workers[local]["owner_id"]) == 16 and int(restored.workers[other]["owner_id"]) == 1
		and int(restored.buildings[neutral]["owner_id"]) == 0,
		"Owner zero and maximum player sixteen are valid persistent allegiance values", failures)
	_check(restored.is_cell_visible(Vector2i(3, 3)) and not restored.is_cell_visible(Vector2i(30, 3))
		and not restored.is_cell_visible(Vector2i(25, 13)),
		"Loading player sixteen must not accidentally restore player-one or neutral vision", failures)


static func _test_legacy_maps_remain_explored_on_activation(failures: Array[String]) -> void:
	for version: int in [1, 9, 15, 16, 17]:
		var source = World.new(Vector2i(30, 18))
		source.default_footprint_version = 0
		source.place_building("warehouse", Vector2i(2, 2))
		source.spawn_worker(Vector2i(4, 4), "carrier", 0, false)
		var legacy: Dictionary = _json(source)
		legacy["version"] = version
		legacy.erase("fog")
		for entity: Dictionary in legacy["workers"] + legacy["buildings"]:
			entity.erase("owner_id")
		var restored = World.new()
		if not restored.from_data(legacy):
			failures.append("A genuine pre-fog v%d save without fog/owner fields must load" % version)
			continue
		_check(not restored.fog.enabled and restored.fog.legacy_reveal_pending
			and restored.fog.explored.size() == 30 * 18,
			"Legacy raw loading keeps fog disabled and seeds the entire formerly visible map as explored", failures)
		for entity: Dictionary in restored.workers.values() + restored.buildings.values():
			_check(int(entity["owner_id"]) == 1, "Legacy citizens and buildings default to the original local player", failures)
		restored.enable_fog()
		_check(restored.is_cell_visible(Vector2i(4, 4)) and not restored.is_cell_visible(Vector2i(29, 17))
			and restored.is_cell_explored(Vector2i(29, 17)),
			"Activating an old game keeps discovered terrain but only current local sources provide live sight", failures)


static func _reject_atomically(data: Dictionary, label: String, failures: Array[String]) -> void:
	var live = World.new(Vector2i(10, 10))
	var store: int = live.place_building("warehouse", Vector2i(3, 3))
	live.buildings[store]["storage"]["stone"] = 5
	live.spawn_worker(Vector2i(8, 8), "builder", 0, false)
	live.enable_fog()
	var before: Dictionary = live.to_data()
	var fog: Variant = live.fog
	var visible: Dictionary = live.fog.visible.duplicate()
	var grid: Variant = live.grid
	var reservations: Dictionary = live.tile_reservations.duplicate()
	var workers: Dictionary = live.workers.duplicate(true)
	var events: Array = live.event_log.duplicate()
	_check(not live.from_data(data), "Fog validation must reject " + label, failures)
	_check(live.to_data() == before and live.fog == fog and live.fog.visible == visible and live.grid == grid
		and live.tile_reservations == reservations and live.workers == workers and live.event_log == events,
		"Rejecting " + label + " must leave the live fog, world objects, stock, workers and reservations untouched", failures)


static func _test_malformed_fog_is_transactional(failures: Array[String]) -> void:
	var source = World.new(Vector2i(8, 6))
	source.enable_fog()
	var baseline: Dictionary = _json(source)
	var cases: Array[Dictionary] = [
		{"name": "missing fog", "mutate": func(data: Dictionary): data.erase("fog")},
		{"name": "non-object fog", "mutate": func(data: Dictionary): data["fog"] = []},
		{"name": "missing enabled", "mutate": func(data: Dictionary): data["fog"].erase("enabled")},
		{"name": "numeric enabled", "mutate": func(data: Dictionary): data["fog"]["enabled"] = 1},
		{"name": "missing player", "mutate": func(data: Dictionary): data["fog"].erase("local_player_id")},
		{"name": "neutral local player", "mutate": func(data: Dictionary): data["fog"]["local_player_id"] = 0},
		{"name": "unsupported local player", "mutate": func(data: Dictionary): data["fog"]["local_player_id"] = 17},
		{"name": "boolean local player", "mutate": func(data: Dictionary): data["fog"]["local_player_id"] = true},
		{"name": "fractional local player", "mutate": func(data: Dictionary): data["fog"]["local_player_id"] = 1.5},
		{"name": "string local player", "mutate": func(data: Dictionary): data["fog"]["local_player_id"] = "1"},
		{"name": "missing explored", "mutate": func(data: Dictionary): data["fog"].erase("explored")},
		{"name": "non-array explored", "mutate": func(data: Dictionary): data["fog"]["explored"] = {}},
		{"name": "duplicate explored cell", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[0, 0], [0, 0]]},
		{"name": "short explored coordinate", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[0]]},
		{"name": "long explored coordinate", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[0, 0, 1]]},
		{"name": "non-coordinate entry", "mutate": func(data: Dictionary): data["fog"]["explored"] = [null]},
		{"name": "negative explored x", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[-1, 0]]},
		{"name": "out-of-bounds explored x", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[8, 0]]},
		{"name": "out-of-bounds explored y", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[0, 6]]},
		{"name": "fractional explored x", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[0.5, 0]]},
		{"name": "boolean explored x", "mutate": func(data: Dictionary): data["fog"]["explored"] = [[true, 0]]},
		{"name": "oversized explored list", "mutate": func(data: Dictionary): data["fog"]["explored"] = []; data["fog"]["explored"].resize(49)},
		{"name": "forged live visibility", "mutate": func(data: Dictionary): data["fog"]["visible"] = [[7, 5]]},
	]
	for entry: Dictionary in cases:
		var invalid: Dictionary = baseline.duplicate(true)
		(entry["mutate"] as Callable).call(invalid)
		_reject_atomically(invalid, entry["name"], failures)


static func _test_malformed_owners_are_transactional(failures: Array[String]) -> void:
	var source = World.new(Vector2i(16, 12))
	var sawmill: int = source.place_building("sawmill", Vector2i(5, 5))
	source.spawn_worker(Vector2i(2, 8), "carpenter", sawmill)
	var baseline: Dictionary = _json(source)
	for collection: String in ["workers", "buildings"]:
		var missing: Dictionary = baseline.duplicate(true)
		missing[collection][0].erase("owner_id")
		_reject_atomically(missing, "missing v18 " + collection + " owner", failures)
		for value: Variant in [null, "1", true, -1, 17, 0.5, INF, NAN, [], {}]:
			var invalid: Dictionary = baseline.duplicate(true)
			invalid[collection][0]["owner_id"] = value
			_reject_atomically(invalid, "invalid " + collection + " owner " + str(value), failures)
	var wrong_home: Dictionary = baseline.duplicate(true)
	wrong_home["workers"][0]["owner_id"] = 2
	_reject_atomically(wrong_home, "a worker claiming another player's workplace", failures)


static func _test_supported_map_size_boundaries(failures: Array[String]) -> void:
	for size: Vector2i in [Vector2i(1, 1), Vector2i(256, 256)]:
		var source = World.new(size)
		var cells: Array[Vector2i] = []
		for y: int in range(size.y):
			for x: int in range(size.x):
				cells.append(Vector2i(x, y))
		_check(source.fog.restore_explored(cells), "Fog authoring must accept every cell at the supported map-size boundaries", failures)
		var restored = World.new()
		_check(restored.from_data(_json(source)) and restored.fog.explored.size() == size.x * size.y
			and restored.to_data() == source.to_data(),
			"The complete bounded exploration mask must JSON round-trip on both the smallest and largest supported map", failures)


static func _test_serialization_is_observational(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	# Allegiance changes have not yet been reflected in the transient mask.
	# Merely opening a save dialog must not act as a simulation/vision update.
	world.workers[fixture["own"]]["owner_id"] = 2
	var explored: Dictionary = world.fog.explored.duplicate()
	var visible: Dictionary = world.fog.visible.duplicate()
	var revision: int = int(world.fog.revision)
	var tick: int = world.tick
	var workers: Dictionary = world.workers.duplicate(true)
	var first: Dictionary = world.to_data()
	var second: Dictionary = world.to_data()
	_check(first == second and world.tick == tick and world.workers == workers
		and world.fog.explored == explored and world.fog.visible == visible and int(world.fog.revision) == revision,
		"Repeated serialization must not recompute fog, advance revisions/ticks, move workers or mutate exploration", failures)
