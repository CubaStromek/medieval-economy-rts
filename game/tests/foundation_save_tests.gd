extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Foundations = preload("res://scripts/simulation/building_foundations.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_partial_work_round_trip,
		_test_builder_resumes_saved_earthwork,
		_test_v16_migration_preserves_existing_work,
		_test_completed_foundation_round_trip,
		_test_missing_and_invalid_foundation_fields,
		_test_corrupt_progress_rejects_atomically,
		_test_work_cannot_be_moved_outside_footprint,
		_test_neighbor_entities_remain_protected,
		_test_eventual_entrance_must_remain_walkable,
	]:
		test.call(failures)
	return failures


static func _fixture(with_builder: bool = true) -> Dictionary:
	var world = World.new(Vector2i(20, 16))
	for y: int in range(17):
		for x: int in range(21):
			world.grid.set_vertex_height(Vector2i(x, y), 2)
	var store: int = world.place_building("warehouse", Vector2i(1, 3))
	world.grid.set_vertex_height(Vector2i(9, 6), 3)
	world.grid.set_vertex_height(Vector2i(11, 7), 1)
	world.economy_enabled = true
	var site: int = world.place_building("sawmill", Vector2i(8, 7))
	var builder: int = 0
	if site != 0 and with_builder:
		builder = world.spawn_worker(world.buildings[site]["entrance"], "builder", 0, false)
	return {"world": world, "store": store, "site": site, "builder": builder}


static func _valid_fixture(fixture: Dictionary, failures: Array[String], needs_builder: bool = true) -> bool:
	if int(fixture["store"]) == 0 or int(fixture["site"]) == 0 or (needs_builder and int(fixture["builder"]) == 0):
		failures.append("Foundation save fixture must create the real warehouse, uneven sawmill site and required Builder")
		return false
	var site: Dictionary = fixture["world"].buildings[fixture["site"]]
	_check(int(site["foundation_target_height"]) == 2 and int(site["foundation_work_total"]) == 16,
		"Two independent height-unit corrections must produce a deterministic 16-tick level-2 foundation", failures)
	return true


static func _partial_checkpoint(fixture: Dictionary, failures: Array[String]) -> bool:
	var world: Variant = fixture["world"]
	var site: Dictionary = world.buildings[fixture["site"]]
	var reached: bool = _until(world, func() -> bool: return int(site["foundation_work_remaining"]) == 7, 160)
	_check(reached and world.grid.vertex_height(Vector2i(9, 6)) == 2 and world.grid.vertex_height(Vector2i(11, 7)) == 1,
		"A real Builder must complete the first ordered vertex correction and retain seven ticks on the second", failures)
	return reached


static func _test_partial_work_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures) or not _partial_checkpoint(fixture, failures):
		return
	var source: Variant = fixture["world"]
	var before: Dictionary = source.to_data()
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("V17 must load an actually worked, still uneven foundation through JSON")
		return
	_check(restored.to_data() == before and int(before["version"]) == 17,
		"Loading must preserve exact terrain, partial earthwork ticks, construction, materials and citizens without advancing anything", failures)
	var site: Dictionary = restored.buildings[fixture["site"]]
	for cell: Vector2i in restored.building_cells(site):
		_check(restored.building_id_at(cell) == int(site["id"]) and not restored.grid.is_walkable(cell),
			"All tiles of a restored pending foundation must retain their actual occupancy", failures)
	for _repeat: int in range(3):
		var next = World.new()
		_check(next.from_data(_json(restored)) and next.to_data() == before,
			"Repeated saving and loading must not flatten, finish, recharge or erase pending earthwork", failures)
		restored = next


static func _test_builder_resumes_saved_earthwork(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures) or not _partial_checkpoint(fixture, failures):
		return
	var restored = World.new()
	if not restored.from_data(_json(fixture["world"])):
		failures.append("The resumable foundation checkpoint must load")
		return
	var site: Dictionary = restored.buildings[fixture["site"]]
	var construction: int = int(site["construction_remaining"])
	var builder: Dictionary = restored.workers[fixture["builder"]]
	_check(int(builder["task_id"]) == 0, "Saved task reservations are rebuilt, never revived as stale task identifiers", failures)
	var finished: bool = _until(restored, func() -> bool: return int(site["foundation_work_remaining"]) == 0, 160)
	_check(finished and int(site["foundation_work_total"]) == 16,
		"The restored physical Builder must reclaim and finish the remaining earthwork without restarting it", failures)
	_check(int(site["construction_remaining"]) == construction and (site["construction_delivered"] as Dictionary).is_empty(),
		"Restoring and leveling cannot grant materials or construction progress", failures)
	for vertex: Vector2i in Foundations.vertices_for_cells(restored.building_cells(site)):
		_check(restored.grid.vertex_height(vertex) == 2, "Resumed earthwork must truly flatten every shared foundation vertex", failures)


static func _test_v16_migration_preserves_existing_work(failures: Array[String]) -> void:
	for footprint_version: int in [0, 1]:
		var world = World.new(Vector2i(20, 16))
		world.default_footprint_version = footprint_version
		var store: int = world.place_building("warehouse", Vector2i(1, 3))
		world.economy_enabled = true
		var site: int = world.place_building("sawmill", Vector2i(8, 7))
		if store == 0 or site == 0:
			failures.append("Legacy foundation migration fixture must contain its real buildings")
			continue
		world.buildings[store]["storage"]["plank"] = 11
		world.buildings[site]["construction_remaining"] = 47
		world.buildings[site]["construction_delivered"] = {"plank": 2, "stone": 1}
		world.grid.set_vertex_height(Vector2i(17, 12), 5)
		var legacy: Dictionary = _json(world)
		legacy["version"] = 16
		for building: Dictionary in legacy["buildings"]:
			for key: String in ["foundation_target_height", "foundation_work_total", "foundation_work_remaining"]:
				building.erase(key)
		var expected: Dictionary = world.to_data()
		for building: Dictionary in expected["buildings"]:
			building["foundation_target_height"] = -1
			building["foundation_work_total"] = 0
			building["foundation_work_remaining"] = 0
		var restored = World.new()
		_check(restored.from_data(legacy) and restored.to_data() == expected,
			"V16 migration must preserve footprint version %d, all terrain, paid materials and existing construction without starting earthwork" % footprint_version, failures)
		var again = World.new()
		_check(again.from_data(_json(restored)) and again.to_data() == expected,
			"Migrated unknown foundations must survive V17 resaving without synthetic heights or work", failures)


static func _test_completed_foundation_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures):
		return
	var world: Variant = fixture["world"]
	var site: Dictionary = world.buildings[fixture["site"]]
	if not _until(world, func() -> bool: return int(site["foundation_work_remaining"]) == 0, 160):
		failures.append("The real Builder must finish leveling before completed-foundation save tests")
		return
	for completed: bool in [false, true]:
		if completed:
			for resource: String in world.construction_cost(site):
				site["construction_delivered"][resource] = int(world.construction_cost(site)[resource])
			_check(_until(world, func() -> bool: return world.is_building_complete(site), 400),
				"The real Builder must construct the fully supplied, already-level building", failures)
		var restored = World.new()
		_check(restored.from_data(_json(world)) and restored.to_data() == world.to_data(),
			"Finished earthwork must retain its target and historical work count both before and after building completion", failures)
		_check(int(site["foundation_work_total"]) == 16 and int(site["foundation_work_remaining"]) == 0,
			"Construction must never erase or replay completed earthwork", failures)


static func _test_missing_and_invalid_foundation_fields(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	if not _valid_fixture(fixture, failures, false):
		return
	var baseline: Dictionary = _json(fixture["world"])
	for key: String in ["foundation_target_height", "foundation_work_total", "foundation_work_remaining"]:
		var missing: Dictionary = baseline.duplicate(true)
		_saved_building(missing, fixture["site"]).erase(key)
		_reject_atomically(missing, "missing V17 " + key, failures)
		for value: Variant in [null, true, "2", 0.5, -2, INF, NAN, [], {}]:
			var invalid: Dictionary = baseline.duplicate(true)
			_saved_building(invalid, fixture["site"])[key] = value
			_reject_atomically(invalid, "invalid %s = %s" % [key, str(value)], failures)


static func _test_corrupt_progress_rejects_atomically(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	if not _valid_fixture(fixture, failures, false):
		return
	var baseline: Dictionary = _json(fixture["world"])
	for entry: Dictionary in [
		{"foundation_target_height": -1},
		{"foundation_target_height": 4},
		{"foundation_target_height": 65},
		{"foundation_work_total": 15},
		{"foundation_work_total": 1000000},
		{"foundation_work_remaining": 17},
		{"foundation_work_remaining": 0},
		{"foundation_work_remaining": 7},
		{"construction_remaining": 1},
		{"construction_delivered": {"plank": 1}},
		{"footprint_version": 0},
	]:
		var invalid: Dictionary = baseline.duplicate(true)
		_saved_building(invalid, fixture["site"]).merge(entry, true)
		_reject_atomically(invalid, "inconsistent foundation work " + str(entry), failures)
	var steep: Dictionary = baseline.duplicate(true)
	steep["terrain"]["corner_heights"][6][9] = 5
	_saved_building(steep, fixture["site"])["foundation_work_total"] = 32
	_saved_building(steep, fixture["site"])["foundation_work_remaining"] = 32
	_reject_atomically(steep, "earthwork spanning more than two height units", failures)


static func _test_work_cannot_be_moved_outside_footprint(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	if not _valid_fixture(fixture, failures, false):
		return
	var world: Variant = fixture["world"]
	var invalid: Dictionary = _json(world)
	for vertex: Vector2i in Foundations.vertices_for_cells(world.building_cells(world.buildings[fixture["site"]])):
		invalid["terrain"]["corner_heights"][vertex.y][vertex.x] = 2
	invalid["terrain"]["corner_heights"][0][0] = 4
	_reject_atomically(invalid, "work relocated to an unrelated vertex outside the building footprint", failures)
	var outside: Dictionary = _json(world)
	_saved_building(outside, fixture["site"])["position"] = [18, 7]
	_saved_building(outside, fixture["site"])["entrance"] = [19, 8]
	_reject_atomically(outside, "pending foundation extending outside the map", failures)


static func _test_neighbor_entities_remain_protected(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	if not _valid_fixture(fixture, failures, false):
		return
	var baseline: Dictionary = _json(fixture["world"])
	for kind: String in ["tree", "deposit", "water"]:
		var invalid: Dictionary = baseline.duplicate(true)
		var id: int = int(invalid["next_entity_id"])
		invalid["next_entity_id"] = id + 1
		match kind:
			"tree": invalid["trees"].append({"id": id, "position": [9, 5], "amount": 3, "age_ticks": World.TREE_MATURE_AGE_TICKS})
			"deposit": invalid["deposits"].append({"id": id, "position": [9, 5], "resource": "coal", "amount": 5})
			"water": invalid["terrain"]["base"][5][9] = "water"
		_reject_atomically(invalid, "pending vertex change under neighboring " + kind, failures)
	# The neighbor is currently a valid flat legacy foundation; only the future
	# change shared with the pending modern site would undermine it.
	var neighbor: Dictionary = baseline.duplicate(true)
	for vertex: Vector2i in [Vector2i(8, 5), Vector2i(9, 5), Vector2i(8, 6), Vector2i(9, 6)]:
		neighbor["terrain"]["corner_heights"][vertex.y][vertex.x] = 3
	_saved_building(neighbor, fixture["site"])["foundation_work_total"] = 24
	_saved_building(neighbor, fixture["site"])["foundation_work_remaining"] = 24
	var old: Dictionary = _saved_building(neighbor, fixture["store"]).duplicate(true)
	old["id"] = int(neighbor["next_entity_id"])
	neighbor["next_entity_id"] += 1
	old["position"] = [8, 5]
	old["entrance"] = [7, 5]
	old["footprint_version"] = 0
	old["foundation_target_height"] = -1
	old["foundation_work_total"] = 0
	old["foundation_work_remaining"] = 0
	neighbor["buildings"].append(old)
	_reject_atomically(neighbor, "future leveling undermines a currently level neighboring building", failures)
	neighbor["buildings"].reverse()
	_reject_atomically(neighbor, "future leveling undermines an earlier-loaded neighboring building", failures)


static func _test_eventual_entrance_must_remain_walkable(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	if not _valid_fixture(fixture, failures, false):
		return
	var world: Variant = fixture["world"]
	var invalid: Dictionary = _json(world)
	for vertex: Vector2i in Foundations.vertices_for_cells(world.building_cells(world.buildings[fixture["site"]])):
		invalid["terrain"]["corner_heights"][vertex.y][vertex.x] = 2
	for x: int in [9, 10]:
		invalid["terrain"]["corner_heights"][8][x] = 3
		invalid["terrain"]["corner_heights"][9][x] = 6
	_reject_atomically(invalid, "walkable current entrance becomes impassable after flattening its shared edge", failures)


static func _reject_atomically(data: Dictionary, label: String, failures: Array[String]) -> void:
	var live = World.new(Vector2i(12, 12))
	live.place_building("warehouse", Vector2i(1, 3))
	live.spawn_worker(Vector2i(7, 7), "carrier", 0, false)
	var before: Dictionary = live.to_data()
	var original_grid: Variant = live.grid
	var blockers: Dictionary = live.grid.blocked_by.duplicate(true)
	var events: Array = live.event_log.duplicate()
	_check(not live.from_data(data), "V17 must reject " + label, failures)
	_check(live.to_data() == before and live.grid == original_grid and live.grid.blocked_by == blockers and live.event_log == events,
		"Rejected " + label + " must preserve live geometry, citizens, materials, events and grid identity", failures)


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _saved_building(data: Dictionary, id: int) -> Dictionary:
	for building: Dictionary in data["buildings"]:
		if int(building["id"]) == id:
			return building
	return {}


static func _until(world: Variant, predicate: Callable, limit: int) -> bool:
	for _tick: int in range(limit):
		if predicate.call():
			return true
		world.step_tick()
	return predicate.call()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
