extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Fog = preload("res://scripts/simulation/fog_of_war.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_bare_and_empty_worlds, _test_circular_owned_sight,
		_test_movement_keeps_land_but_hides_enemies, _test_building_completion_and_footprints,
		_test_indoor_and_removed_sources, _test_death_removes_vision,
		_test_source_cache_and_unchanged_union, _test_revision_deltas,
		_test_foreign_economy_is_inert, _test_perspective_and_strict_restore]:
		test.call(failures)
	return failures


static func _test_bare_and_empty_worlds(failures: Array[String]) -> void:
	var world = World.new(Vector2i(20, 16))
	_check(not world.fog.enabled and world.is_cell_visible(Vector2i(19, 15)), "Bare authoring worlds must retain their normal unfogged behavior", failures)
	world.enable_fog()
	_check(world.fog.enabled and world.fog.visible.is_empty() and world.fog.explored.is_empty(), "Enabling fog without observers must leave the whole map unexplored", failures)
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(19, 15), Vector2i(-1, 0), Vector2i(20, 0)]:
		_check(world.fog_state(cell) == Fog.UNEXPLORED, "Empty or off-map cells must not expose visibility: %s" % cell, failures)
	var revision: int = world.fog.revision
	world.update_visibility()
	_check(world.fog.revision == revision, "An unchanged empty view must not increment its revision", failures)


static func _test_circular_owned_sight(failures: Array[String]) -> void:
	var world = World.new(Vector2i(40, 30))
	world.spawn_worker(Vector2i(10, 10), "carrier")
	world.spawn_worker(Vector2i(30, 20), "carrier", 0, true, 0, 2)
	world.spawn_worker(Vector2i(30, 2), "carrier", 0, true, 0, 0)
	world.enable_fog()
	for cell: Vector2i in [Vector2i(10, 10), Vector2i(16, 10), Vector2i(4, 10), Vector2i(14, 14)]:
		_check(world.is_cell_visible(cell), "Owned unit must reveal every tested point inside radius six: %s" % cell, failures)
	for cell: Vector2i in [Vector2i(16, 11), Vector2i(3, 10), Vector2i(30, 20), Vector2i(30, 2)]:
		_check(not world.is_cell_explored(cell), "Sight must be circular and exclude enemy/neutral observers: %s" % cell, failures)


static func _test_movement_keeps_land_but_hides_enemies(failures: Array[String]) -> void:
	var world = _legacy(Vector2i(35, 24))
	var scout: int = world.spawn_worker(Vector2i(10, 10), "carrier")
	var enemy: int = world.spawn_worker(Vector2i(7, 10), "carrier", 0, true, 0, 2)
	var enemy_hut: int = world.place_building("lumber_hut", Vector2i(6, 12), 2)
	var tree: int = world.add_tree(Vector2i(7, 9), 3)
	world.enable_fog()
	_check(enemy_hut != 0 and tree != 0 and world.is_entity_visible(world.workers[enemy])
		and world.is_entity_visible(world.buildings[enemy_hut]), "An enemy in actual line of sight must initially be visible", failures)
	if not world._move_worker_to(world.workers[scout], Vector2i(22, 10)):
		failures.append("Fog movement fixture must have a real walkable scout route")
		return
	for _tick: int in range(160):
		world.step_tick()
		if world.workers[scout]["position"] == Vector2i(22, 10) and world.workers[scout]["state"] == "idle":
			break
	_check(world.workers[scout]["position"] == Vector2i(22, 10) and world.fog_state(Vector2i(7, 10)) == Fog.EXPLORED,
		"An actual scout walk must preserve discovered land behind its moving sight circle", failures)
	_check(not world.is_entity_visible(world.workers[enemy]) and not world.is_entity_visible(world.buildings[enemy_hut])
		and world.is_entity_visible(world.trees[tree]), "Remembered terrain/resources must remain known while enemies disappear when sight leaves", failures)


static func _test_building_completion_and_footprints(failures: Array[String]) -> void:
	var world = World.new(Vector2i(40, 25))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	world.economy_enabled = true
	var school: int = world.place_building("school", Vector2i(17, 2))
	if warehouse == 0 or school == 0:
		failures.append("Fog geometry test requires real multi-tile warehouse and school footprints")
		return
	world.enable_fog()
	_check(world.building_cells(world.buildings[warehouse]).size() == 9 and world.is_cell_visible(Vector2i(9, 1))
		and not world.is_cell_visible(Vector2i(10, 1)), "Completed multi-tile building sight must be centered on its footprint, not the bottom-left anchor", failures)
	_check(not world.is_cell_explored(Vector2i(18, 3)), "An unfinished distant building must not act as a free scout", failures)
	world.buildings[school]["construction_remaining"] = 0
	world.buildings[school]["foundation_work_remaining"] = 0
	world.update_visibility()
	_check(world.is_cell_visible(Vector2i(24, 1)), "Completing a building must immediately add its circular sight source", failures)
	var tower_world = _legacy(Vector2i(40, 25))
	tower_world.place_building("watchtower", Vector2i(20, 10))
	tower_world.enable_fog()
	_check(tower_world.is_cell_visible(Vector2i(29, 10)) and not tower_world.is_cell_visible(Vector2i(30, 10)), "A completed watchtower must reveal radius nine", failures)


static func _test_indoor_and_removed_sources(failures: Array[String]) -> void:
	var world = _legacy(Vector2i(30, 24))
	var home: int = world.place_building("warehouse", Vector2i(10, 10))
	var worker: int = world.spawn_worker(Vector2i(10, 9), "carrier")
	world.enable_fog()
	_check(world.is_cell_visible(Vector2i(10, 3)), "Outdoor doorway visitor must contribute its own distinct sight circle", failures)
	if not world._enter_worker_building(world.workers[worker], home):
		failures.append("Fog indoor fixture must genuinely enter its completed building")
		return
	world.update_visibility()
	_check(world.fog_state(Vector2i(10, 3)) == Fog.EXPLORED and world.is_cell_visible(Vector2i(10, 10))
		and not world.is_entity_visible(world.workers[worker]), "An indoor worker must stop observing independently while its completed building retains sight", failures)
	world.workers.erase(worker)
	world.buildings.erase(home)
	world.grid.unblock(Vector2i(10, 10))
	world.update_visibility()
	_check(world.fog.visible.is_empty() and world.fog_state(Vector2i(10, 10)) == Fog.EXPLORED, "Removing the final building/source must clear current visibility but retain discovered land", failures)


static func _test_death_removes_vision(failures: Array[String]) -> void:
	var world = World.new(Vector2i(30, 20))
	var worker: int = world.spawn_worker(Vector2i(15, 10), "carrier")
	world.workers[worker]["hunger"] = 1
	world.workers[worker]["nutrition_deficit_ticks"] = 41999
	world.economy_enabled = true
	world.tick = int(world.catalog.economy["condition_interval_ticks"]) - 1
	world.enable_fog()
	world.step_tick()
	_check(not world.workers.has(worker) and world.fog.visible.is_empty()
		and world.fog_state(Vector2i(15, 10)) == Fog.EXPLORED, "Actual starvation must remove a dead observer in the same simulation tick without erasing exploration", failures)


static func _test_source_cache_and_unchanged_union(failures: Array[String]) -> void:
	var world = _legacy(Vector2i(40, 30))
	world.place_building("watchtower", Vector2i(20, 15))
	var worker: int = world.spawn_worker(Vector2i(20, 14), "carrier")
	world.enable_fog()
	var revision: int = world.fog.revision
	var builds: int = world.fog.rebuild_count
	for _query: int in range(100):
		world.update_visibility()
		world.is_cell_visible(Vector2i(20, 15))
		world.is_entity_visible(world.workers[worker])
	_check(world.fog.rebuild_count == builds and world.fog.revision == revision, "Repeated view refreshes and queries must not rasterize unchanged source circles", failures)
	_relocate(world, worker, Vector2i(21, 14))
	world.update_visibility()
	_check(world.fog.rebuild_count == builds + 1 and world.fog.revision == revision,
		"A changed observer entirely covered by a watchtower must not invalidate an unchanged visibility mask", failures)
	world.grid.record_carrier_traffic(Vector2i(2, 2))
	world.update_visibility()
	_check(world.fog.rebuild_count == builds + 1, "Unrelated road wear must not rebuild visibility", failures)


static func _test_revision_deltas(failures: Array[String]) -> void:
	var world = World.new(Vector2i(45, 25))
	var worker: int = world.spawn_worker(Vector2i(10, 12), "carrier")
	world.enable_fog()
	var revision: int = world.fog.revision
	var old: Dictionary = world.fog.visible.duplicate()
	_relocate(world, worker, Vector2i(11, 12))
	world.update_visibility()
	var delta: Dictionary = world.fog.changes_since(revision)
	var expected: Dictionary = {}
	for cell: Vector2i in old:
		if not world.fog.visible.has(cell):
			expected[cell] = true
	for cell: Vector2i in world.fog.visible:
		if not old.has(cell):
			expected[cell] = true
	_check(not delta["full"] and delta["cells"].size() == expected.size(), "Incremental fog updates must report only changed view cells", failures)
	for cell: Vector2i in delta["cells"]:
		_check(expected.has(cell), "Delta must not include an unchanged tile", failures)
	for x: int in range(12, 23):
		_relocate(world, worker, Vector2i(x, 12))
		world.update_visibility()
	_check(world.fog.changes_since(revision)["full"] and world.fog.changes_since(world.fog.revision)["cells"].is_empty(),
		"Bounded delta history must fall back to full refresh only for an outdated renderer", failures)


static func _test_foreign_economy_is_inert(failures: Array[String]) -> void:
	var world = _legacy(Vector2i(35, 24))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	var store: int = world.place_building("warehouse", Vector2i(3, 10))
	var foreign_hut: int = world.place_building("lumber_hut", Vector2i(20, 3), 2)
	var foreign_store: int = world.place_building("warehouse", Vector2i(20, 10), 2)
	var foreign_saw: int = world.place_building("sawmill", Vector2i(24, 12), 2)
	world.buildings[foreign_hut]["outputs"]["log"] = 3
	world.buildings[foreign_saw]["inputs"]["log"] = 2
	world.buildings[store]["storage"]["gold"] = 2
	world.buildings[foreign_store]["storage"]["gold"] = 100
	var enemy: int = world.spawn_worker(Vector2i(18, 3), "lumberjack", 0, true, 0, 2)
	world.spawn_worker(Vector2i(4, 10), "carrier")
	_check(world.spawn_worker(Vector2i(5, 3), "lumberjack", hut, true, 0, 2) == 0
		and int(world.workers[enemy]["home_id"]) == 0, "Foreign specialists must not claim the player's home or auto-start another economy", failures)
	var hunger: int = int(world.workers[enemy]["hunger"])
	for _tick: int in range(100):
		world.step_tick()
	world.economy_enabled = true
	world.tick = 3750
	for _tick: int in range(20):
		world.step_tick()
	_check(world.workers[enemy]["position"] == Vector2i(18, 3) and world.workers[enemy]["state"] == "idle"
		and int(world.workers[enemy]["hunger"]) == hunger, "Foreign placeholders must not execute player work, sleep routing or starvation", failures)
	_check(int(world.buildings[foreign_hut]["outputs"]["log"]) == 3 and int(world.buildings[foreign_saw]["inputs"]["log"]) == 2
		and int(world.buildings[foreign_saw]["outputs"]["plank"]) == 0, "Local carriers and automatic processors must not consume foreign inventory", failures)
	_check(world.resource_stock("gold")["total"] == 2 and world.resource_stock("gold", 2)["total"] == 100,
		"Player totals must exclude foreign stock while explicit owner queries remain available", failures)


static func _test_perspective_and_strict_restore(failures: Array[String]) -> void:
	var world = World.new(Vector2i(40, 20))
	world.spawn_worker(Vector2i(4, 10), "carrier")
	world.spawn_worker(Vector2i(25, 10), "carrier", 0, true, 0, 2)
	world.enable_fog(2)
	_check(world.is_cell_visible(Vector2i(25, 10)) and not world.is_cell_explored(Vector2i(4, 10)), "Visibility must follow the configured local player rather than hard-coded owner one", failures)
	var before: Dictionary = world.fog.explored.duplicate()
	var duplicate: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 1)]
	var outside: Array[Vector2i] = [Vector2i(40, 0)]
	_check(not world.fog.restore_explored(duplicate) and not world.fog.restore_explored(outside)
		and world.fog.explored == before, "Fog restore must reject duplicate or off-map exploration atomically", failures)
	_check(world.spawn_worker(Vector2i(0, 0), "carrier", 0, true, 0, 17) == 0
		and world.place_building("warehouse", Vector2i(1, 1), -1) == 0, "Authored ownership must stay inside the save-supported neutral/player range", failures)


static func _legacy(size: Vector2i) -> Variant:
	var world = World.new(size)
	world.default_footprint_version = 0
	return world


static func _relocate(world: Variant, id: int, cell: Vector2i) -> void:
	world._release_worker_tile(world.workers[id])
	world.workers[id]["position"] = cell
	world.workers[id]["previous_position"] = cell
	world.tile_reservations[cell] = id


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
