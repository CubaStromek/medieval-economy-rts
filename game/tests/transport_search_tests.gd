extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 5


class CountingWorld:
	extends World
	var route_searches: int = 0
	var route_checks: int = 0

	func _path_with_yielding(from: Vector2i, to: Vector2i, blockers: Dictionary, worker_id: int) -> Array[Vector2i]:
		route_searches += 1
		return super._path_with_yielding(from, to, blockers, worker_id)

	func _route_exists(from: Vector2i, to: Vector2i) -> bool:
		route_checks += 1
		return super._route_exists(from, to)


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_existence_stops_early_but_pickup_still_ranks,
		_test_unreachable_consumer_does_not_hide_reachable_one,
		_test_warehouse_sources_require_consumers,
		_test_disabled_foreign_full_and_reserved_consumers,
		_test_queries_are_read_only,
	]:
		test.call(failures)
	return failures


static func _fixture() -> Dictionary:
	var world := CountingWorld.new(Vector2i(54, 16))
	var source: int = world.place_building("lumber_hut", Vector2i(3, 4))
	world.buildings[source]["outputs"]["log"] = 2
	var targets: Array[int] = []
	# The closest consumer has the last ID, so stopping early must never
	# replace the full ranked selection used when a carrier actually picks up.
	for x: int in [45, 40, 35, 30, 25, 20, 15, 10]:
		targets.append(world.place_building("sawmill", Vector2i(x, 4)))
	var carrier: int = world.spawn_worker(Vector2i(3, 12), "carrier")
	return {"world": world, "source": source, "targets": targets, "carrier": carrier}


static func _task(fixture: Dictionary) -> Dictionary:
	return {"kind": "transport_log", "source_id": fixture["source"]}


static func _available(fixture: Dictionary) -> bool:
	var world: CountingWorld = fixture["world"]
	return world._task_is_useful(_task(fixture), world.workers[fixture["carrier"]])


static func _test_existence_stops_early_but_pickup_still_ranks(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: CountingWorld = fixture["world"]
	var source: int = fixture["source"]
	var targets: Array[int] = fixture["targets"]
	_check(source != 0 and not targets.has(0), "Transport fixture must place every production footprint", failures)
	world.route_searches = 0
	world.route_checks = 0
	world._generate_economy_tasks()
	var generation_searches: int = world.route_searches
	var generation_checks: int = world.route_checks
	_check(world.task_board.has_source("lumber_hut:%d:log" % source), "Reachable consumer must create a transport task", failures)
	world.route_searches = 0
	world.route_checks = 0
	_check(_available(fixture), "Carrier must accept a transport task with reachable consumers", failures)
	var validation_searches: int = world.route_searches
	var validation_checks: int = world.route_checks
	world.route_searches = 0
	var worker: Dictionary = world.workers[fixture["carrier"]]
	worker["source_id"] = source
	world._pickup_ware(worker, "log")
	_check(worker["destination_id"] == targets.back() and worker["carrying"] == "log",
		"Real pickup must still choose the nearest consumer even when its ID is last", failures)
	_check(int(world.buildings[source]["outputs"]["log"]) == 1, "Real pickup must transfer exactly one physical log", failures)
	print("TRANSPORT SEARCH WORK: generation=%d/%d, validation=%d/%d, pickup=%d route searches/reachability checks for 8 consumers" % [generation_searches, generation_checks, validation_searches, validation_checks, world.route_searches])
	_check(generation_searches == 0 and validation_searches == 0 and generation_checks == 1 and validation_checks == 1,
		"Existence checks must stop after the first reachable consumer without building routes", failures)
	_check(world.route_searches >= targets.size(), "Pickup must retain full destination ranking", failures)


static func _test_unreachable_consumer_does_not_hide_reachable_one(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: CountingWorld = fixture["world"]
	var targets: Array[int] = fixture["targets"]
	for x: int in range(0, world.grid.size.x):
		world.grid.set_base_terrain(Vector2i(x, 8), "water")
	# Block only the earliest consumer, leaving the later consumers reachable
	# from the source above the water. A failed first search is not a failure.
	world.grid.block(world.buildings[targets[0]]["entrance"], 999999)
	_check(_available(fixture), "Unreachable first consumer must not hide later reachable consumers", failures)
	for id: int in targets:
		world.grid.block(world.buildings[id]["entrance"], 999999)
	_check(not _available(fixture), "Transport validation must reject entirely unreachable consumers", failures)
	world._generate_economy_tasks()
	_check(not world.task_board.has_source("lumber_hut:%d:log" % int(fixture["source"])),
		"No task may be generated without a reachable destination", failures)


static func _test_warehouse_sources_require_consumers(failures: Array[String]) -> void:
	var world := CountingWorld.new(Vector2i(28, 16))
	var source: int = world.place_building("warehouse", Vector2i(3, 4))
	var other: int = world.place_building("warehouse", Vector2i(12, 4))
	var hut: int = world.place_building("lumber_hut", Vector2i(21, 4))
	var carrier: int = world.spawn_worker(Vector2i(3, 12), "carrier")
	world.buildings[source]["storage"]["log"] = 1
	world.buildings[hut]["outputs"]["log"] = 1
	var fixture: Dictionary = {"world": world, "source": source, "carrier": carrier}
	_check(other != 0 and not _available(fixture), "Warehouse stock must not create warehouse-to-warehouse transport", failures)
	fixture["source"] = hut
	_check(_available(fixture), "Producer stock may fall back to a warehouse when no consumer exists", failures)
	world.catalog.economy["stock_capacity_per_ware"] = 1
	world.buildings[other]["storage"]["log"] = 1
	_check(not _available(fixture), "Full warehouses cannot accept a producer's fallback delivery", failures)


static func _test_disabled_foreign_full_and_reserved_consumers(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: CountingWorld = fixture["world"]
	var targets: Array[int] = fixture["targets"]
	for id: int in targets:
		world.buildings[id]["enabled"] = false
	_check(not _available(fixture), "Disabled consumers cannot make a task useful", failures)
	var target: int = targets[0]
	world.buildings[target]["enabled"] = true
	world.buildings[target]["owner_id"] = 2
	_check(not _available(fixture), "Foreign consumers cannot make a local transport task useful", failures)
	world.buildings[target]["owner_id"] = 1
	var capacity: int = int(world.catalog.building("sawmill")["input_capacity"])
	world.buildings[target]["inputs"]["log"] = capacity
	_check(not _available(fixture), "A full consumer cannot accept a delivery", failures)
	world.buildings[target]["inputs"]["log"] = capacity - 1
	var incoming: int = world.spawn_worker(Vector2i(6, 12), "carrier")
	world.workers[incoming]["destination_id"] = target
	world.workers[incoming]["carrying"] = "log"
	world.workers[incoming]["action"] = "deliver_log"
	_check(not _available(fixture), "A physically incoming log must reserve the consumer's last slot", failures)
	world.workers[incoming]["destination_id"] = 0
	_check(_available(fixture), "Releasing the last incoming reservation must immediately make the task useful", failures)


static func _test_queries_are_read_only(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: CountingWorld = fixture["world"]
	var before: Dictionary = world.to_data()
	_check(_available(fixture), "Read-only query fixture needs an actual reachable destination", failures)
	_check(world.to_data() == before, "Existence validation must not change inventories, reservations, paths or saved state", failures)
	world._ware_destination("log", world.buildings[fixture["source"]]["entrance"], {}, 0, fixture["source"])
	_check(world.to_data() == before, "Ranked destination inspection must remain read-only", failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
