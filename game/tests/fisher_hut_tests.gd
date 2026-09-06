extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Level = preload("res://scripts/simulation/test_level.gd")
const Relief = preload("res://scripts/simulation/relief_demo.gd")
const TEST_COUNT: int = 5


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_existing_pond_and_paid_start(failures)
	_test_player_builds_trains_catches_and_transports(failures)
	_test_one_fisher_per_hut(failures)
	_test_completed_owned_hut_required(failures)
	_test_save_mid_catch_and_finite_stock(failures)
	return failures


static func _test_existing_pond_and_paid_start(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Level.MAP_SIZE)
	Level.setup(world)
	var terrain = LegacyFixture.create(Level.MAP_SIZE)
	Relief.setup_terrain(terrain)
	_check(world.buildings.size() == 2 and world.workers.is_empty(),
		"Fish availability must not grant a free fishing hut or citizen", failures)
	_check(world.building_id_at(Vector2i(3, 16)) != 0 and world.building_id_at(Vector2i(7, 16)) != 0
		and int(world.resource_stock("gold")["total"]) == 50,
		"Fishing must preserve the player's current school, warehouse and fifty starter gold", failures)
	for resource: String in ["log", "plank", "stone"]:
		_check(world.stored_amount(resource) == 20, "Fishing must preserve twenty starter " + resource, failures)
	for y: int in range(Level.MAP_SIZE.y):
		for x: int in range(Level.MAP_SIZE.x):
			var cell := Vector2i(x, y)
			_check(world.grid.base_terrain_at(cell) == terrain.grid.base_terrain_at(cell),
				"Stocking fish must not repaint the existing map at %s" % cell, failures)
	for y: int in range(Level.MAP_SIZE.y + 1):
		for x: int in range(Level.MAP_SIZE.x + 1):
			var vertex := Vector2i(x, y)
			_check(world.grid.vertex_height(vertex) == terrain.grid.vertex_height(vertex),
				"Stocking fish must not alter existing map heights at %s" % vertex, failures)
	_check(_remaining_fish(world) == 80 and int(world.resource_stock("fish")["total"]) == 0,
		"The pond must contain eighty finite natural fish, not free warehouse stock", failures)
	_check(world.can_place_building("fisher_hut", Level.FISHER_HUT_SITE),
		"The existing pond must have a buildable bank within fishing range", failures)


static func _test_player_builds_trains_catches_and_transports(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Level.MAP_SIZE)
	Level.setup(world)
	var school_id: int = world.building_id_at(Vector2i(3, 16))
	# Use only the commands available to a player: ordinary paid training,
	# delivered construction materials, unmodified work durations and movement.
	for role: String in ["carrier", "builder", "fisherman"]:
		_check(world.queue_unit_training(school_id, role), "School must accept fishing starter role " + role, failures)
	var hut: int = world.place_building("fisher_hut", Level.FISHER_HUT_SITE)
	if hut == 0:
		failures.append("The starter pond must accept a player-placed fishing hut")
		return
	_check(not world.is_building_complete(world.buildings[hut])
		and world.stored_amount("plank") == 20 and world.stored_amount("stone") == 20,
		"A fishing blueprint must require physical construction, without remote material consumption", failures)
	var saw_building_cargo: bool = false
	var saw_fishing_from_bank: bool = false
	var saw_catch_returning_home: bool = false
	var saw_hut_stock: bool = false
	var saw_carrier_fish: bool = false
	for _tick: int in range(4000):
		world.step_tick()
		saw_hut_stock = saw_hut_stock or int(world.buildings[hut]["outputs"].get("fish", 0)) > 0
		for worker: Dictionary in world.workers.values():
			if worker["type"] == "carrier":
				if worker["carrying"] in ["plank", "stone"] and int(worker["destination_id"]) == hut:
					saw_building_cargo = true
				if worker["carrying"] == "fish" and int(worker["source_id"]) == hut:
					saw_carrier_fish = true
			elif worker["type"] == "fisherman":
				if worker["state"] == "working" and worker["action"] == "harvest_deposit":
					saw_fishing_from_bank = world.grid.is_walkable(worker["position"]) and world.grid.base_terrain_at(worker["position"]) != "water"
				if worker["carrying"] == "fish" and int(worker["destination_id"]) == hut and world.owns_workplace(worker, hut):
					saw_catch_returning_home = true
		if world.stored_amount("fish") >= 1:
			break
	_check(world.is_building_complete(world.buildings[hut]) and world.stored_amount("fish") >= 1,
		"The untouched starter economy must construct the fishing hut and deliver a caught fish within 4000 ticks", failures)
	_check(saw_building_cargo and saw_fishing_from_bank and saw_catch_returning_home and saw_hut_stock and saw_carrier_fish,
		"Fishing must demonstrate the complete carrier construction → bank catch → own hut → carrier → warehouse chain", failures)
	_check(world.buildings[hut]["construction_delivered"] == {"plank": 4, "stone": 3}
		and world.stored_amount("plank") == 16 and world.stored_amount("stone") == 17 and world.stored_amount("log") == 20,
		"The fishing hut must consume exactly four planks and three stone, not raw logs", failures)
	_check(world.workers.size() == 3 and int(world.resource_stock("gold")["total"]) == 47,
		"Starting fishing must use exactly three paid citizens", failures)
	_check(_remaining_fish(world) + int(world.resource_stock("fish")["total"]) == 80,
		"Construction and fish logistics must conserve all eighty natural or caught fish", failures)
	var restored = LegacyFixture.create()
	_check(restored.from_data(_snapshot(world)), "The player-built fishing settlement must remain saveable", failures)


static func _test_one_fisher_per_hut(failures: Array[String]) -> void:
	var world = _pond(4)
	var hut_a: int = world.place_building("fisher_hut", Vector2i(5, 3))
	var fisher_a: int = world.spawn_worker(Vector2i(4, 3), "fisherman", hut_a)
	var fisher_b: int = world.spawn_worker(Vector2i(10, 5), "fisherman")
	if hut_a == 0 or fisher_a == 0 or fisher_b == 0:
		failures.append("The two-fisher ownership fixture must initialize")
		return
	_check(int(world.workers[fisher_b]["home_id"]) == 0
		and world.spawn_worker(Vector2i(1, 1), "fisherman", hut_a) == 0,
		"An occupied fishing hut must reject a second owner, including explicit assignment", failures)
	for _tick: int in range(80):
		world.step_tick()
	_check(int(world.workers[fisher_b]["home_id"]) == 0 and world.workers[fisher_b]["carrying"] == ""
		and world.workers[fisher_b]["action"] != "harvest_deposit",
		"An extra fisherman must wait without borrowing the occupied hut or mining independently", failures)
	var hut_b: int = world.place_building("fisher_hut", Vector2i(9, 3))
	if hut_b == 0:
		failures.append("A second fishing hut must be placeable on the other bank")
		return
	for _tick: int in range(500):
		world.step_tick()
	_check(int(world.workers[fisher_a]["home_id"]) == hut_a and int(world.workers[fisher_b]["home_id"]) == hut_b
		and int(world.workplace_worker(hut_a).get("id", 0)) == fisher_a and int(world.workplace_worker(hut_b).get("id", 0)) == fisher_b,
		"Each fisherman must retain exactly one distinct fishing hut", failures)
	_check(int(world.buildings[hut_a]["outputs"].get("fish", 0)) > 0 and int(world.buildings[hut_b]["outputs"].get("fish", 0)) > 0,
		"Both owners must catch finite fish and return them to their own hut", failures)
	_check(_remaining_fish(world) + int(world.resource_stock("fish")["total"]) == 8,
		"Two fishing huts sharing shoals must not duplicate the eight available fish", failures)


static func _test_completed_owned_hut_required(failures: Array[String]) -> void:
	var world = _pond(2)
	var fisher: int = world.spawn_worker(Vector2i(4, 3), "fisherman")
	for _tick: int in range(200):
		world.step_tick()
	_check(_remaining_fish(world) == 4 and int(world.resource_stock("fish")["total"]) == 0
		and int(world.workers[fisher]["home_id"]) == 0,
		"A homeless fisherman must not extract fish without a hut", failures)
	world.economy_enabled = true
	var hut: int = world.place_building("fisher_hut", Vector2i(5, 3))
	for _tick: int in range(200):
		world.step_tick()
	_check(hut != 0 and not world.is_building_complete(world.buildings[hut])
		and int(world.workers[fisher]["home_id"]) == 0 and _remaining_fish(world) == 4
		and int(world.resource_stock("fish")["total"]) == 0,
		"An unfinished hut must neither claim a fisherman nor unlock fishing", failures)


static func _test_save_mid_catch_and_finite_stock(failures: Array[String]) -> void:
	var source = _pond(1)
	var hut: int = source.place_building("fisher_hut", Vector2i(5, 3))
	source.place_building("warehouse", Vector2i(2, 6))
	var fisher: int = source.spawn_worker(Vector2i(4, 3), "fisherman", hut)
	source.spawn_worker(Vector2i(2, 5), "carrier")
	for _tick: int in range(400):
		source.step_tick()
		if source.workers[fisher]["carrying"] == "fish":
			break
	_check(source.workers[fisher]["carrying"] == "fish" and _remaining_fish(source) == 1,
		"Save fixture must pause after an actual bank catch while the fisherman carries it home", failures)
	var restored = LegacyFixture.create()
	if not restored.from_data(_snapshot(source)):
		failures.append("A real fisherman carrying a caught fish must survive save/load")
		return
	_check(restored.workers.size() == 2 and int(restored.workers[fisher]["home_id"]) == hut
		and restored.workers[fisher]["carrying"] == "fish" and _remaining_fish(restored) == 1,
		"Loading must preserve the fisher's exclusive hut, carried catch and remaining finite shoal", failures)
	for _tick: int in range(1000):
		restored.step_tick()
	_check(restored.stored_amount("fish") == 2 and _remaining_fish(restored) == 0
		and int(restored.resource_stock("fish")["total"]) == 2,
		"After loading, both finite fish must reach the warehouse once and exhausted shoals must stop producing", failures)
	_check(int(restored.workers[fisher]["home_id"]) == hut,
		"Exhausting a shoal must not discard the fisherman's hut ownership", failures)


static func _pond(amount: int) -> Variant:
	var world = LegacyFixture.create(Vector2i(12, 8))
	for cell: Vector2i in [Vector2i(7, 2), Vector2i(7, 4)]:
		world.grid.set_base_terrain(cell, "water")
		world.add_deposit(cell, "fish", amount)
	return world


static func _remaining_fish(world: Variant) -> int:
	var total: int = 0
	for deposit: Dictionary in world.deposits.values():
		if deposit["resource"] == "fish":
			total += int(deposit["amount"])
	return total


static func _snapshot(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
