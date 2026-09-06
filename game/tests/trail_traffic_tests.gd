extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 7


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_a_few_real_trips_do_not_make_a_road,
		_test_sustained_real_traffic_earns_a_trail,
		_test_world_time_regrows_abandoned_trails,
		_test_yielding_carriers_leave_no_wear,
		_test_trail_speed_requires_the_used_connection,
		_test_fields_remove_all_trail_memory,
		_test_deposit_placement_clears_old_footprints,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _lane() -> Dictionary:
	var world := LegacyFixture.create(Vector2i(10, 5))
	for y: int in range(5):
		if y != 2:
			for x: int in range(10):
				world.grid.set_base_terrain(Vector2i(x, y), "water")
	var id: int = world.spawn_worker(Vector2i(1, 2), "carrier")
	return {"world": world, "worker": world.workers[id]}


static func _trip(world: Variant, worker: Dictionary, destination: Vector2i, failures: Array[String]) -> void:
	_check(world._move_worker_to(worker, destination), "A controlled carrier trip must be reachable", failures)
	for elapsed: int in range(100):
		world.step_tick()
		if worker["state"] == "idle":
			break
	_check(worker["position"] == destination and worker["state"] == "idle", "A carrier must finish each real trip", failures)


static func _test_a_few_real_trips_do_not_make_a_road(failures: Array[String]) -> void:
	var fixture := _lane()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	_check(world.grid.carrier_passes_to_form_trail() == 36, "Production balance requires 36 retained passes, not four", failures)
	for destination: Vector2i in [Vector2i(7, 2), Vector2i(1, 2), Vector2i(7, 2), Vector2i(1, 2)]:
		_trip(world, worker, destination, failures)
	_check(world.grid.dirt_trails.is_empty(), "Two return trips must not create a functional dirt road", failures)
	_check(world.grid.step_duration_ticks(Vector2i(3, 2), Vector2i(4, 2)) == 6,
		"A handful of actual passes must not give a speed bonus", failures)
	for cell: Vector2i in world.grid.traffic_wear:
		_check(cell.y == 2 and cell.x >= 1 and cell.x <= 7,
			"Traffic memory is limited to physically visited route cells", failures)


static func _test_sustained_real_traffic_earns_a_trail(failures: Array[String]) -> void:
	var fixture := _lane()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	for journey: int in range(80):
		_trip(world, worker, Vector2i(7 if journey % 2 == 0 else 1, 2), failures)
	_check(world.grid.trail_connection_active(Vector2i(3, 2), Vector2i(4, 2)),
		"Regular real carrier traffic must eventually establish its actual undirected route", failures)
	_check(world.grid.step_duration_ticks(Vector2i(3, 2), Vector2i(4, 2)) == 4,
		"A frequently used established trail must reward carriers with the faster movement tier", failures)
	_check(world.workers.size() == 1 and worker["carrying"] == "" and world.tile_reservations.size() == 1,
		"Trail development cannot duplicate units, cargo or occupancy", failures)


static func _test_world_time_regrows_abandoned_trails(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(8, 4))
	world.grid.configure_movement({"trail": {"carrier_passes_to_form": 6,
		"established_min_wear": 2, "weak_decay_ticks": 2, "established_decay_ticks": 4}})
	var from := Vector2i(2, 2)
	var to := Vector2i(3, 2)
	world.grid.add_dirt_trail(from)
	world.grid.add_dirt_trail(to)
	world.grid.add_road(Vector2i(5, 2))
	var before: Dictionary = world.to_data()
	_check(before == world.to_data(), "Reading or saving a paused world must not age trails", failures)
	for elapsed: int in range(100):
		world.step_tick()
	_check(world.grid.dirt_trails.is_empty() and world.grid.traffic_wear.is_empty()
		and world.grid.trail_last_decay.is_empty() and world.grid.trail_links.is_empty(),
		"Simulation ticks must fully regrow abandoned trails and remove their sparse memory", failures)
	_check(world.grid.overlay_at(Vector2i(5, 2)) == "stone_road",
		"Player-built stone roads must never decay with natural trails", failures)


static func _test_yielding_carriers_leave_no_wear(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(8, 6))
	var requester: int = world.spawn_worker(Vector2i(2, 2), "builder")
	var id: int = world.spawn_worker(Vector2i(3, 2), "carrier")
	var carrier: Dictionary = world.workers[id]
	world._move_worker_to(world.workers[requester], Vector2i(5, 2))
	world.step_tick()
	_check(carrier["action"] == "yield" and carrier["position"] != Vector2i(3, 2),
		"The no-wear fixture must actually sidestep an idle carrier", failures)
	for elapsed: int in range(50):
		world.step_tick()
	_check(world.grid.traffic_wear.is_empty() and world.grid.trail_links.is_empty(),
		"An interpolated carrier sidestep must leave neither cell wear nor a route link", failures)
	var start: Vector2i = carrier["position"]
	_trip(world, carrier, start + Vector2i.RIGHT, failures)
	_check(world.grid.traffic_wear_at(start + Vector2i.RIGHT) == 1 and world.grid.trail_links.size() == 1,
		"An empty carrier's ordinary return trip must still count after yielding", failures)


static func _test_trail_speed_requires_the_used_connection(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(7, 6))
	var a := Vector2i(2, 2)
	var b := Vector2i(3, 2)
	for pass_index: int in range(36):
		world.grid.record_carrier_traffic(b, a, 0)
		world.grid.record_carrier_traffic(a, b, 0)
	_check(world.grid.step_duration_ticks(a, b) == 4,
		"Recorded established links grant the dirt movement speed", failures)
	var id: int = world.spawn_worker(Vector2i(3, 3), "builder")
	var worker: Dictionary = world.workers[id]
	world._move_worker_to(worker, b)
	world.step_tick()
	_check(worker["position"] == b and worker["visual_duration_ticks"] == 6,
		"Crossing into a dirt tile from an untrampled direction must not invent a fast connector", failures)


static func _test_fields_remove_all_trail_memory(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(6, 6))
	var cell := Vector2i(2, 2)
	world.grid.record_carrier_traffic(cell, Vector2i(1, 2), 0)
	_check(world.place_field(cell) != 0, "A faint footprint must not prevent preparing a field", failures)
	_check(world.grid.traffic_wear_at(cell) == 0 and not world.grid.trail_last_decay.has(cell)
		and world.grid.trail_links.is_empty(), "Preparing a field removes incident wear and decay metadata", failures)
	var restored := LegacyFixture.create()
	_check(restored.from_data(world.to_data()), "Clearing trail state for a field must leave a reloadable world", failures)


static func _test_deposit_placement_clears_old_footprints(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(6, 6))
	var cell := Vector2i(3, 3)
	world.grid.record_carrier_traffic(cell, Vector2i(2, 3), 0)
	var deposit: int = world.add_deposit(cell, "coal", 3)
	_check(deposit != 0, "A faint footprint must not prevent legal deposit authoring", failures)
	_check(world.grid.traffic_wear_at(cell) == 0 and not world.grid.trail_last_decay.has(cell)
		and world.grid.trail_links.is_empty(), "An authored deposit must clear its obsolete trail metadata", failures)
	var restored := LegacyFixture.create()
	_check(restored.from_data(world.to_data()) and restored.deposits.has(deposit)
		and int(restored.deposits[deposit]["amount"]) == 3,
		"A deposit replacing weak footprints must remain reloadable with its resources intact", failures)
