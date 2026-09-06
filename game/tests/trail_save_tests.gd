extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_exact_round_trip_and_no_loading_traffic,
		_test_decay_remainder_survives_reload,
		_test_v10_preserves_mature_and_weak_tracks,
		_test_v1_preserves_roads_and_citizens,
		_test_cell_corruption_is_transactional,
		_test_link_corruption_is_transactional,
		_test_links_validate_loaded_building_flanks,
		_test_legacy_links_do_not_cross_blocked_corners,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


static func _fixture() -> Variant:
	var world = LegacyFixture.create(Vector2i(12, 10))
	world.tick = 1000
	var warehouse: int = world.place_building("warehouse", Vector2i(9, 7))
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 7))
	world.buildings[warehouse]["storage"]["plank"] = 7
	world.buildings[hut]["outputs"]["log"] = 2
	var lumberjack: int = world.spawn_worker(Vector2i(3, 8), "lumberjack", hut)
	var carrier: int = world.spawn_worker(Vector2i(0, 9), "carrier")
	world.workers[lumberjack]["carrying"] = "log"
	world.workers[carrier]["carrying"] = "stone"
	world.grid.add_road(Vector2i(4, 2))
	world.grid.set_trail_state(Vector2i(1, 1), 3, 850, false)
	world.grid.set_trail_state(Vector2i(2, 1), 16, 700, true)
	world.grid.set_trail_state(Vector2i(3, 2), 36, 800, true)
	world.grid.set_trail_state(Vector2i(4, 1), 36, 990, true)
	world.grid.set_trail_state(Vector2i(5, 1), 1, 999, false)
	world.grid.set_trail_link(Vector2i(1, 1), Vector2i(2, 1), 2, 875, false)
	world.grid.set_trail_link(Vector2i(2, 1), Vector2i(3, 2), 16, 700, true)
	world.grid.set_trail_link(Vector2i(3, 2), Vector2i(4, 2), 36, 800, true)
	# Direction evidence may have a bare departure endpoint: this is valid and
	# must not require inventing an additional worn cell when loading it.
	world.grid.set_trail_link(Vector2i(6, 2), Vector2i(7, 2), 1, 950, false)
	return world


static func _trail_data(world: Variant) -> Dictionary:
	var data: Dictionary = world.to_data()
	return {
		"roads": data["roads"], "trails": data["dirt_trails"], "wear": data["traffic_wear"],
		"decay": data["trail_last_decay"], "links": data["trail_links"],
	}


static func _test_exact_round_trip_and_no_loading_traffic(failures: Array[String]) -> void:
	var source = _fixture()
	var snapshot: Dictionary = source.to_data()
	_check(snapshot["version"] == World.SAVE_VERSION and int(snapshot["version"]) >= 11 and snapshot["trail_links"].size() == 4 and snapshot["trail_last_decay"].size() == 5,
		"The v11 fixture must contain precise cell ages and four independently observed direction links", failures)
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(snapshot)):
		failures.append("A valid v11 directional-trail snapshot must load")
		return
	_check(restored.to_data() == snapshot, "Loading and planning carried-ware delivery must not record a new passage or change trail ages", failures)
	_check(restored.workers.size() == 2 and restored.buildings.size() == 2
		and int(restored.resource_stock("log")["total"]) == 3 and int(restored.resource_stock("stone")["total"]) == 1
		and restored.stored_amount("plank") == 7,
		"Trail migration must preserve all citizens, buildings, stock and carried wares", failures)
	_check(not restored.grid.trail_connection_active(Vector2i(4, 1), Vector2i(3, 2)),
		"Adjacent mature v11 tiles without a saved link must not acquire a fabricated direction while loading", failures)


static func _test_decay_remainder_survives_reload(failures: Array[String]) -> void:
	var source = _fixture()
	# Save between scans. Without restoring the scan clock, a fresh grid would
	# incorrectly run an extra scan at 1050 and decay before the live world.
	source.grid.tick_trails(1040)
	source.tick = 1049
	var restored = LegacyFixture.create()
	if not restored.from_data(_json(source.to_data())):
		failures.append("Decay-remainder fixture must reload")
		return
	for now: int in [1049, 1050, 1059, 1060, 1099, 1100, 1199, 1200]:
		source.grid.tick_trails(now)
		restored.grid.tick_trails(now)
		source.tick = now
		restored.tick = now
		_check(_trail_data(source) == _trail_data(restored),
			"Reloaded trail decay must match uninterrupted decay exactly at tick %d" % now, failures)
		if now == 1049:
			_check(restored.grid.traffic_wear_at(Vector2i(1, 1)) == 3,
				"Weak wear must retain the remaining fraction of its 200-tick decay interval", failures)
		if now == 1050:
			_check(restored.grid.traffic_wear_at(Vector2i(1, 1)) == 3,
				"A reload between scans must not run an extra same-interval scan or prematurely age a trail", failures)
		if now == 1060:
			_check(restored.grid.traffic_wear_at(Vector2i(1, 1)) == 2
				and int(restored.grid.trail_last_decay[Vector2i(1, 1)]) == 1050,
				"A scheduled decay scan must retain the exact 1050 due timestamp and its fractional remainder", failures)
		if now == 1100:
			_check(restored.grid.traffic_wear_at(Vector2i(2, 1)) == 15 and not restored.grid.dirt_trails.has(Vector2i(2, 1)),
				"An established trail crossing below retained wear sixteen must become weak at its original due tick", failures)


static func _test_v10_preserves_mature_and_weak_tracks(failures: Array[String]) -> void:
	var source = _fixture()
	var legacy: Dictionary = _json(source.to_data())
	legacy["version"] = 10
	legacy.erase("trail_last_decay")
	legacy.erase("trail_links")
	legacy["roads"] = [[4, 2]]
	legacy["dirt_trails"] = [[2, 1], [3, 2]]
	legacy["traffic_wear"] = [[1, 1, 1], [2, 1, 4], [3, 2, 4], [5, 1, 3]]
	var restored = LegacyFixture.create()
	if not restored.from_data(legacy):
		failures.append("A real v10 snapshot with four-pass trails must migrate")
		return
	_check(restored.grid.traffic_wear_at(Vector2i(2, 1)) == 36 and restored.grid.traffic_wear_at(Vector2i(3, 2)) == 36,
		"Already mature historical trails must remain established at the new mature score", failures)
	_check(restored.grid.traffic_wear_at(Vector2i(1, 1)) == 1 and restored.grid.traffic_wear_at(Vector2i(5, 1)) == 3
		and not restored.grid.dirt_trails.has(Vector2i(1, 1)) and not restored.grid.dirt_trails.has(Vector2i(5, 1)),
		"Old weak one-to-three-pass tracks must remain weak instead of receiving free mature trails", failures)
	for cell: Vector2i in restored.grid.traffic_wear:
		_check(int(restored.grid.trail_last_decay[cell]) == 1000, "Legacy trail decay starts at its saved tick", failures)
	_check(restored.grid.trail_connection_active(Vector2i(2, 1), Vector2i(3, 2))
		and restored.grid.trail_connection_active(Vector2i(3, 2), Vector2i(4, 2))
		and not restored.grid.trail_connection_active(Vector2i(1, 1), Vector2i(2, 1)),
		"Directionless legacy saves may reconstruct only legal mature-trail/stone adjacencies, not weak tracks", failures)
	_check(restored.workers.size() == source.workers.size() and restored.resource_stock("log") == source.resource_stock("log")
		and restored.resource_stock("stone") == source.resource_stock("stone"),
		"Legacy trail conversion must preserve all people and their wares", failures)


static func _test_v1_preserves_roads_and_citizens(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(8, 8))
	source.tick = 30
	var hut: int = source.place_building("lumber_hut", Vector2i(2, 2))
	source.place_building("warehouse", Vector2i(6, 5))
	source.spawn_worker(Vector2i(1, 3), "lumberjack", hut)
	source.spawn_worker(Vector2i(4, 3), "carrier")
	source.grid.add_road(Vector2i(3, 3))
	var legacy: Dictionary = _json(source.to_data())
	legacy["version"] = 1
	for key: String in ["dirt_trails", "traffic_wear", "trail_last_decay", "trail_links", "terrain"]:
		legacy.erase(key)
	for worker: Dictionary in legacy["workers"]:
		for key: String in ["type", "home_id", "planting_cooldown"]:
			worker.erase(key)
	var restored = LegacyFixture.create()
	_check(restored.from_data(legacy), "The original v1 schema without any trail fields must still load", failures)
	_check(restored.workers.size() == 2 and restored.grid.roads.has(Vector2i(3, 3))
		and restored.grid.traffic_wear.is_empty() and restored.grid.trail_last_decay.is_empty() and restored.grid.trail_links.is_empty(),
		"Migrating v1 must retain citizens and roads without inventing pedestrian trail history", failures)


static func _reject_cases(cases: Array[Dictionary], failures: Array[String]) -> void:
	for test_case: Dictionary in cases:
		var world = _fixture()
		var before: Dictionary = world.to_data()
		var original_grid = world.grid
		var original_workers: Dictionary = world.workers.duplicate(true)
		var invalid: Dictionary = _json(before)
		(test_case["mutate"] as Callable).call(invalid)
		_check(not world.from_data(invalid), "Trail snapshot must reject %s" % test_case["name"], failures)
		_check(world.grid == original_grid and world.to_data() == before and world.workers == original_workers,
			"Rejecting %s must be transactional and preserve all live state" % test_case["name"], failures)


static func _test_cell_corruption_is_transactional(failures: Array[String]) -> void:
	_reject_cases([
		{"name": "missing decay array", "mutate": func(d: Dictionary): d.erase("trail_last_decay")},
		{"name": "missing cell decay entry", "mutate": func(d: Dictionary): d["trail_last_decay"].pop_back()},
		{"name": "duplicate cell decay entry", "mutate": func(d: Dictionary): d["trail_last_decay"].append(d["trail_last_decay"][0])},
		{"name": "orphan decay entry", "mutate": func(d: Dictionary): d["trail_last_decay"].append([8, 1, 0])},
		{"name": "future cell decay", "mutate": func(d: Dictionary): d["trail_last_decay"][0][2] = 1001},
		{"name": "negative cell decay", "mutate": func(d: Dictionary): d["trail_last_decay"][0][2] = -1},
		{"name": "fractional cell decay", "mutate": func(d: Dictionary): d["trail_last_decay"][0][2] = 0.5},
		{"name": "over-cap cell wear", "mutate": func(d: Dictionary): d["traffic_wear"][0][2] = 37},
		{"name": "zero retained cell wear", "mutate": func(d: Dictionary): d["traffic_wear"][0][2] = 0},
		{"name": "mature flag on weak wear", "mutate": func(d: Dictionary): d["dirt_trails"].append([1, 1])},
		{"name": "missing mature flag on capped wear", "mutate": func(d: Dictionary): d["traffic_wear"][0][2] = 36},
		{"name": "mature tile without wear", "mutate": func(d: Dictionary): d["dirt_trails"].append([8, 1])},
		{"name": "duplicate wear cell", "mutate": func(d: Dictionary): d["traffic_wear"].append(d["traffic_wear"][0])},
	], failures)


static func _test_link_corruption_is_transactional(failures: Array[String]) -> void:
	_reject_cases([
		{"name": "missing directional links", "mutate": func(d: Dictionary): d.erase("trail_links")},
		{"name": "short directional link", "mutate": func(d: Dictionary): d["trail_links"][0].pop_back()},
		{"name": "duplicate directional link", "mutate": func(d: Dictionary): d["trail_links"].append(d["trail_links"][0])},
		{"name": "noncanonical reversed link", "mutate": func(d: Dictionary): d["trail_links"][0] = [2, 1, 1, 1, 2, 875, false]},
		{"name": "self link", "mutate": func(d: Dictionary): d["trail_links"][0] = [1, 1, 1, 1, 2, 875, false]},
		{"name": "nonadjacent link", "mutate": func(d: Dictionary): d["trail_links"][0] = [1, 1, 5, 1, 2, 875, false]},
		{"name": "future link decay", "mutate": func(d: Dictionary): d["trail_links"][0][5] = 1001},
		{"name": "negative link decay", "mutate": func(d: Dictionary): d["trail_links"][0][5] = -1},
		{"name": "over-cap link wear", "mutate": func(d: Dictionary): d["trail_links"][0][4] = 37},
		{"name": "zero retained link wear", "mutate": func(d: Dictionary): d["trail_links"][0][4] = 0},
		{"name": "established weak link", "mutate": func(d: Dictionary): d["trail_links"][0][6] = true},
		{"name": "unestablished capped link", "mutate": func(d: Dictionary): d["trail_links"][0][4] = 36},
		{"name": "nonboolean established flag", "mutate": func(d: Dictionary): d["trail_links"][0][6] = 1},
		{"name": "off-map link", "mutate": func(d: Dictionary): d["trail_links"][0] = [-1, 1, 0, 1, 2, 875, false]},
		{"name": "water endpoint link", "mutate": func(d: Dictionary): d["terrain"]["base"][2][6] = "water"},
		{"name": "blocked diagonal terrain flank", "mutate": func(d: Dictionary): d["terrain"]["base"][2][2] = "water"},
		{"name": "field endpoint link", "mutate": _add_link_endpoint_field},
		{"name": "deposit endpoint link", "mutate": _add_link_endpoint_deposit},
	], failures)


static func _add_link_endpoint_field(data: Dictionary) -> void:
	data["fields"].append({"id": data["next_entity_id"], "position": [6, 2], "age_ticks": -1, "kind": "wheat"})
	data["next_entity_id"] += 1


static func _add_link_endpoint_deposit(data: Dictionary) -> void:
	data["deposits"].append({"id": data["next_entity_id"], "position": [6, 2], "resource": "coal", "amount": 3})
	data["next_entity_id"] += 1


static func _test_links_validate_loaded_building_flanks(failures: Array[String]) -> void:
	var world = _fixture()
	var saved: Dictionary = _json(world.to_data())
	# Move the second building to a flank of (2,1)->(3,2), without overlapping
	# either endpoint. Validation must happen after this building blocks the map.
	saved["buildings"][1]["position"] = [2, 2]
	saved["buildings"][1]["entrance"] = [1, 2]
	var before: Dictionary = world.to_data()
	_check(not world.from_data(saved), "A saved diagonal trail may not pass through a subsequently loaded building flank", failures)
	_check(world.to_data() == before, "Late diagonal building-flank rejection must preserve all live resources and citizens", failures)


static func _test_legacy_links_do_not_cross_blocked_corners(failures: Array[String]) -> void:
	var world = _fixture()
	var legacy: Dictionary = _json(world.to_data())
	legacy["version"] = 10
	legacy.erase("trail_last_decay")
	legacy.erase("trail_links")
	legacy["buildings"][1]["position"] = [2, 2]
	legacy["buildings"][1]["entrance"] = [1, 2]
	var restored = LegacyFixture.create()
	_check(restored.from_data(legacy), "Legacy mature cells beside a blocked corner must load without inventing an illegal old direction", failures)
	_check(not restored.grid.trail_connection_active(Vector2i(2, 1), Vector2i(3, 2)),
		"Historical direction reconstruction must respect loaded building flanks", failures)
