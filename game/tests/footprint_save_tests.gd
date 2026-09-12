extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_irregular_geometry_round_trip,
		_test_v15_keeps_crowded_settlement,
		_test_mixed_versions_and_instance_geometry,
		_test_invalid_versions_are_atomic,
		_test_invalid_geometry_is_atomic,
		_test_non_anchor_occupants_are_rejected,
		_test_loaded_blocking_and_paid_construction,
		_test_modern_indoor_operator_round_trip,
	]:
		test.call(failures)
	return failures


static func _fixture() -> Dictionary:
	var world = World.new(Vector2i(24, 16))
	world.grid.set_base_terrain(Vector2i(3, 6), "water")
	var fish: int = world.add_deposit(Vector2i(3, 6), "fish", 20)
	var hut: int = world.place_building("fisher_hut", Vector2i(4, 4))
	var store: int = world.place_building("warehouse", Vector2i(12, 4))
	var sawmill: int = world.place_building("sawmill", Vector2i(12, 9))
	var worker: int = world.spawn_worker(Vector2i(1, 9), "carrier", 0, false)
	if store != 0:
		world.buildings[store]["storage"]["plank"] = 15
	if hut != 0:
		world.buildings[hut]["outputs"]["fish"] = 2
	return {"world": world, "fish": fish, "hut": hut, "store": store, "sawmill": sawmill, "worker": worker}


static func _valid_fixture(fixture: Dictionary, failures: Array[String]) -> bool:
	for key: String in ["fish", "hut", "store", "sawmill", "worker"]:
		if int(fixture[key]) == 0:
			failures.append("Footprint save fixture must create its real " + key)
			return false
	return true


static func _test_irregular_geometry_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures):
		return
	var source: Variant = fixture["world"]
	var hut: Dictionary = source.buildings[fixture["hut"]]
	var occupied: Array[Vector2i] = source.building_cells(hut)
	_check(occupied.size() == 5, "The real fisher hut must save the five occupied tiles in its irregular 3 by 2 mask", failures)
	var empty_corner := Vector2i(-1, -1)
	for y: int in range(3, 5):
		for x: int in range(4, 7):
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				empty_corner = cell
	_check(empty_corner != Vector2i(-1, -1), "The fisher hut fixture must include the catalog's unoccupied corner", failures)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("V16 must load actual irregular and rectangular building footprints through JSON")
		return
	_check(restored.to_data() == source.to_data() and int(restored.to_data()["version"]) == World.SAVE_VERSION,
		"Footprint JSON round trip must preserve every position, entrance, inventory, citizen and resource", failures)
	for cell: Vector2i in occupied:
		_check(restored.building_id_at(cell) == int(hut["id"]) and not restored.grid.is_walkable(cell),
			"Loading must reconstruct blocking and selection on every occupied fisher hut tile", failures)
	_check(restored.grid.is_walkable(empty_corner) and restored.building_id_at(empty_corner) == 0,
		"The irregular free corner must stay walkable after loading", failures)
	_check(restored.grid.is_walkable(hut["entrance"])
		and restored.building_door_cell(restored.buildings[hut["id"]]) + Vector2i.DOWN == hut["entrance"],
		"The fixed door and its exterior approach must survive the save", failures)


static func _legacy_fixture() -> Variant:
	var world = World.new(Vector2i(20, 12))
	world.default_footprint_version = 0
	var store: int = world.place_building("warehouse", Vector2i(1, 1))
	world.place_building("sawmill", Vector2i(2, 1))
	world.add_tree(Vector2i(3, 1), 4)
	world.place_road(Vector2i(1, 2))
	world.place_field(Vector2i(2, 2))
	world.spawn_worker(Vector2i(0, 4), "carrier", 0, false)
	if store != 0:
		world.buildings[store]["storage"]["plank"] = 9
		world.buildings[store]["entrance"] = Vector2i(0, 1)
	return world


static func _test_v15_keeps_crowded_settlement(failures: Array[String]) -> void:
	var source: Variant = _legacy_fixture()
	if source.buildings.size() != 2 or source.fields.size() != 1 or source.trees.size() != 1 or source.workers.size() != 1:
		failures.append("Legacy migration fixture must contain tightly adjacent buildings, field, tree, road and citizen")
		return
	var data: Dictionary = _json(source)
	data["version"] = 15
	for building: Dictionary in data["buildings"]:
		building.erase("footprint_version")
	var restored = World.new()
	if not restored.from_data(data):
		failures.append("A real v15 crowded settlement must load without enlarging its historic buildings")
		return
	_check(restored.to_data() == LegacyFixture.expected_pre_fog_migration(source.to_data()) and restored.grid.blocked_by.size() == 2,
		"V15 migration must preserve every entity, inventory, arbitrary adjacent entrance and tile without shifting or loss", failures)
	var new_id: int = restored.place_building("warehouse", Vector2i(9, 6))
	_check(new_id != 0 and int(restored.buildings[new_id]["footprint_version"]) == 1
		and restored.building_cells(restored.buildings[new_id]).size() == 9,
		"New construction after loading v15 must use the modern footprint while old buildings remain compact", failures)


static func _test_mixed_versions_and_instance_geometry(failures: Array[String]) -> void:
	var source: Variant = _legacy_fixture()
	source.default_footprint_version = 1
	var modern: int = source.place_building("warehouse", Vector2i(9, 6))
	if modern == 0:
		failures.append("Mixed save fixture must add a real modern warehouse to the legacy settlement")
		return
	var data: Dictionary = _json(source)
	for reverse: bool in [false, true]:
		var reordered: Dictionary = data.duplicate(true)
		if reverse:
			reordered["buildings"].reverse()
		var restored = World.new()
		restored.default_footprint_version = 0
		_check(restored.from_data(reordered) and restored.to_data() == source.to_data()
			and restored.grid.blocked_by.size() == 11,
			"Mixed V16 geometry must depend on each saved instance, independently of load order or the author's default", failures)


static func _test_invalid_versions_are_atomic(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures):
		return
	var baseline: Dictionary = _json(fixture["world"])
	for value: Variant in [null, "1", true, -1, 2, 0.5, INF, NAN, [], {}]:
		var invalid: Dictionary = baseline.duplicate(true)
		_saved_building(invalid, fixture["store"])["footprint_version"] = value
		_reject_atomically(invalid, "invalid footprint version %s" % str(value), failures)
	var missing: Dictionary = baseline.duplicate(true)
	_saved_building(missing, fixture["store"]).erase("footprint_version")
	_reject_atomically(missing, "missing V16 footprint version", failures)


static func _test_invalid_geometry_is_atomic(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures):
		return
	var baseline: Dictionary = _json(fixture["world"])
	var store: int = int(fixture["store"])
	var cases: Array[Dictionary] = [
		{"name": "moved fixed entrance", "mutate": func(data: Dictionary): _saved_building(data, store)["entrance"][0] += 1},
		{"name": "footprint extends above map", "mutate": func(data: Dictionary): _move_saved_building(data, store, Vector2i(0, -4))},
		{"name": "building overlap away from anchor", "mutate": func(data: Dictionary): _duplicate_building(data, store, Vector2i(1, 0))},
		{"name": "non-anchor water", "mutate": func(data: Dictionary): data["terrain"]["base"][2][13] = "water"},
		{"name": "non-anchor slope", "mutate": func(data: Dictionary): data["terrain"]["corner_heights"][2][14] = 1},
		{"name": "non-anchor road", "mutate": func(data: Dictionary): data["roads"].append([13, 2])},
	]
	for entry: Dictionary in cases:
		var invalid: Dictionary = baseline.duplicate(true)
		(entry["mutate"] as Callable).call(invalid)
		_reject_atomically(invalid, String(entry["name"]), failures)
	# A later footprint must not cover an earlier building's exterior approach.
	var blocked_door: Dictionary = baseline.duplicate(true)
	blocked_door["buildings"].erase(_saved_building(blocked_door, fixture["sawmill"]))
	_duplicate_building(blocked_door, store, Vector2i(0, 3))
	_reject_atomically(blocked_door, "later footprint covers an earlier entrance", failures)
	blocked_door["buildings"].reverse()
	_reject_atomically(blocked_door, "earlier footprint covers a later entrance", failures)
	var shared_door: Dictionary = baseline.duplicate(true)
	var compact: Dictionary = _saved_building(shared_door, store).duplicate(true)
	compact["id"] = shared_door["next_entity_id"]
	shared_door["next_entity_id"] += 1
	compact["footprint_version"] = 0
	compact["position"] = [compact["entrance"][0], compact["entrance"][1] + 1]
	shared_door["buildings"].append(compact)
	_reject_atomically(shared_door, "modern and legacy buildings share an entrance", failures)
	shared_door["buildings"].reverse()
	_reject_atomically(shared_door, "legacy and modern buildings share an entrance", failures)


static func _test_non_anchor_occupants_are_rejected(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	if not _valid_fixture(fixture, failures):
		return
	var baseline: Dictionary = _json(fixture["world"])
	for kind: String in ["tree", "field", "deposit", "worker", "entrance_tree"]:
		var invalid: Dictionary = baseline.duplicate(true)
		var id: int = int(invalid["next_entity_id"])
		invalid["next_entity_id"] = id + 1
		match kind:
			"tree", "entrance_tree":
				var cell: Array = [13, 2] if kind == "tree" else _saved_building(invalid, fixture["store"])["entrance"]
				invalid["trees"].append({"id": id, "position": cell, "amount": 3, "age_ticks": World.TREE_MATURE_AGE_TICKS})
			"field":
				invalid["fields"].append({"id": id, "position": [13, 2], "kind": "wheat", "age_ticks": -1})
			"deposit":
				invalid["deposits"].append({"id": id, "position": [13, 2], "resource": "coal", "amount": 5})
			"worker":
				invalid["workers"][0]["position"] = [13, 2]
		_reject_atomically(invalid, "occupied non-anchor cell: " + kind, failures)


static func _test_loaded_blocking_and_paid_construction(failures: Array[String]) -> void:
	var source = World.new(Vector2i(20, 14))
	source.economy_enabled = true
	var site: int = source.place_building("sawmill", Vector2i(5, 5))
	if site == 0:
		failures.append("Construction save test must place an unfinished modern sawmill")
		return
	source.buildings[site]["construction_delivered"] = {"plank": 2, "stone": 1}
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("An unfinished modern sawmill with delivered materials must load")
		return
	_check(restored.to_data() == source.to_data()
		and restored.buildings[site]["construction_delivered"] == {"plank": 2, "stone": 1},
		"Loading a multi-cell construction site must preserve its materials and remaining construction exactly", failures)
	var cells: Array[Vector2i] = restored.building_cells(restored.buildings[site])
	_check(cells.size() == 8, "A saved sawmill must reconstruct its full 4 by 2 site", failures)
	for cell: Vector2i in cells:
		_check(restored.building_id_at(cell) == site and restored.grid.blocked_by.get(cell, 0) == site
			and not restored.can_place_field(cell) and restored.spawn_worker(cell, "carrier", 0, false) == 0,
			"Loaded construction tiles must block selection conflicts, farming and outdoor citizen placement", failures)


static func _reject_atomically(data: Dictionary, label: String, failures: Array[String]) -> void:
	var live: Variant = _legacy_fixture()
	var unchanged: Dictionary = live.to_data()
	var grid: Variant = live.grid
	var blockers: Dictionary = live.grid.blocked_by.duplicate(true)
	var events: Array = live.event_log.duplicate()
	_check(not live.from_data(data), "V16 must reject " + label, failures)
	_check(live.to_data() == unchanged and live.grid == grid and live.grid.blocked_by == blockers and live.event_log == events,
		"Rejected " + label + " must leave live world and path blocking untouched", failures)


static func _test_modern_indoor_operator_round_trip(failures: Array[String]) -> void:
	var world = World.new(Vector2i(18, 12))
	var sawmill: int = world.place_building("sawmill", Vector2i(6, 5))
	if sawmill == 0:
		failures.append("Modern indoor save fixture must place a real sawmill")
		return
	var door: Vector2i = world.buildings[sawmill]["entrance"]
	var carpenter: int = world.spawn_worker(door, "carpenter", sawmill)
	if carpenter == 0:
		failures.append("Modern indoor save fixture must create its owned carpenter")
		return
	world.buildings[sawmill]["inputs"]["log"] = 1
	world.economy_enabled = true
	for _tick: int in range(30):
		world.step_tick()
		if world.is_worker_inside(world.workers[carpenter]) and int(world.buildings[sawmill]["process_remaining"]) > 0:
			break
	_check(world.is_worker_inside(world.workers[carpenter]) and int(world.buildings[sawmill]["process_remaining"]) > 0,
		"The actual modern carpenter must enter through the southern doorway and start its paid batch before saving", failures)
	var restored = World.new()
	if not restored.from_data(_json(world)):
		failures.append("An indoor owner working inside a multi-cell sawmill must load")
		return
	_check(restored.to_data() == world.to_data() and restored.tile_reservations.is_empty()
		and restored.workers[carpenter]["position"] == door and restored.grid.is_walkable(door),
		"Modern indoor loading must retain virtual entrance position and consumed batch without blocking the outdoor approach", failures)
	for _tick: int in range(200):
		restored.step_tick()
	_check(int(restored.buildings[sawmill]["outputs"]["plank"]) == 2 and int(restored.buildings[sawmill]["inputs"]["log"]) == 0,
		"The restored modern carpenter must finish the already-paid log exactly once", failures)


static func _move_saved_building(data: Dictionary, id: int, offset: Vector2i) -> void:
	var building: Dictionary = _saved_building(data, id)
	for key: String in ["position", "entrance"]:
		building[key][0] += offset.x
		building[key][1] += offset.y


static func _duplicate_building(data: Dictionary, id: int, offset: Vector2i) -> void:
	var duplicate: Dictionary = _saved_building(data, id).duplicate(true)
	duplicate["id"] = data["next_entity_id"]
	data["next_entity_id"] += 1
	data["buildings"].append(duplicate)
	_move_saved_building(data, int(duplicate["id"]), offset)


static func _saved_building(data: Dictionary, id: int) -> Dictionary:
	for building: Dictionary in data["buildings"]:
		if int(building["id"]) == id:
			return building
	return {}


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
