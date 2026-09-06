extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_exact_boundaries_and_professions,
		_test_outdoor_specialists_sleep_at_their_own_huts,
		_test_shared_warehouse_routes_and_morning_exits,
		_test_consumed_recipe_pauses_without_restarting,
		_test_construction_preserves_completed_progress,
		_test_sleeping_cargo_does_not_reserve_inputs,
		_test_missing_home_does_not_permit_night_work,
		_test_blocked_sleep_route_preserves_cargo,
		_test_night_finishes_the_visible_movement_step,
		_test_guard_reports_to_its_tower_at_night,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 600) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _reservations_valid(world: Variant) -> bool:
	var expected: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if world.is_worker_inside(worker):
			if int(world.tile_reservations.get(worker["position"], 0)) == int(worker["id"]):
				return false
		else:
			if expected.has(worker["position"]):
				return false
			expected[worker["position"]] = int(worker["id"])
	return expected == world.tile_reservations


static func _test_exact_boundaries_and_professions(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(40, 8))
	var roles: Array = world.catalog.units.keys()
	roles.append_array(world.catalog.soldiers.keys())
	var index: int = 0
	for role: String in roles:
		world.spawn_worker(Vector2i(index + 1, 4), role)
		index += 1
	for sample: Array in [[3749, false], [3750, true], [4749, true], [4750, true], [5999, true], [6000, false]]:
		world.tick = int(sample[0])
		_check(world.is_night_rest_time() == bool(sample[1]),
			"Night rest must follow the exact 20:00 and 05:00 boundaries, including midnight, at tick %d" % world.tick, failures)
		for worker: Dictionary in world.workers.values():
			var civilian: bool = worker["type"] != "recruit" and not world.catalog.soldiers.has(String(worker["type"]))
			_check(world.follows_daily_schedule(worker) == civilian
				and world.can_worker_work(worker) == (not bool(sample[1]) or not civilian),
				"Only civilian %s work must be suspended during the exact night interval at tick %d" % [worker["type"], world.tick], failures)
	world.tick = 3749
	world.step_tick()
	_check(world.is_night_rest_time(), "The actual simulation update reaching 20:00 must immediately apply night rest", failures)
	world.tick = 5999
	world.step_tick()
	_check(not world.is_night_rest_time(), "The actual simulation update reaching 05:00 must end night rest", failures)


static func _test_outdoor_specialists_sleep_at_their_own_huts(failures: Array[String]) -> void:
	for row: Array in [["lumberjack", "lumber_hut"], ["gardener", "forester_hut"], ["fisherman", "fisher_hut"]]:
		var world = LegacyFixture.create(Vector2i(18, 12))
		var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
		var resource: int = 0
		if row[0] == "lumberjack":
			resource = world.add_tree(Vector2i(12, 7), 3)
		elif row[0] == "fisherman":
			world.grid.set_base_terrain(Vector2i(10, 4), "water")
			resource = world.add_deposit(Vector2i(10, 4), "fish", 3)
		var hut: int = world.place_building(row[1], Vector2i(8, 3))
		if hut == 0:
			failures.append("The %s fixture must place a valid completed hut near its resource" % row[0])
			continue
		var id: int = world.spawn_worker(Vector2i(11, 7), row[0], hut)
		if id == 0:
			failures.append("The %s fixture must spawn its actual assigned hut owner" % row[0])
			continue
		var worker: Dictionary = world.workers[id]
		world.economy_enabled = true
		if not _until(world, func() -> bool: return worker["state"] == "working"):
			failures.append("The %s fixture must reach real outdoor work before night" % row[0])
			continue
		world.tick = 3749
		world.step_tick()
		_check(int(worker["task_id"]) == 0 and world.planting_reservations.is_empty(),
			"Night must release %s work and planting reservations without releasing employment" % row[0], failures)
		_check(_until(world, func() -> bool: return world.is_worker_sleeping(worker)),
			"The %s must physically travel from its work site into its own hut" % row[0], failures)
		_check(int(worker["inside_building_id"]) == hut and int(worker["sleep_home_id"]) == hut
			and int(worker["inside_building_id"]) != warehouse and world.owns_workplace(worker, hut)
			and _reservations_valid(world),
			"The %s must retain its own workplace and sleep there without claiming an outdoor tile" % row[0], failures)
		_advance(world, 120)
		if row[0] == "lumberjack":
			_check(int(world.trees[resource]["amount"]) == 3 and world.resource_stock("log")["total"] == 0,
				"A sleeping lumberjack must not finish the interrupted tree harvest", failures)
		elif row[0] == "fisherman":
			_check(int(world.deposits[resource]["amount"]) == 3 and world.resource_stock("fish")["total"] == 0,
				"A sleeping fisherman must not extract fish from its interrupted catch", failures)
		else:
			_check(world.trees.is_empty(), "A sleeping forester must not complete its interrupted planting", failures)
		world.tick = 5999
		world.step_tick()
		_check(_until(world, func() -> bool:
			if row[0] == "lumberjack":
				return int(world.trees[resource]["amount"]) < 3
			if row[0] == "fisherman":
				return int(world.deposits[resource]["amount"]) < 3
			return not world.trees.is_empty()
		), "The %s must leave its hut and resume real outdoor work after 05:00" % row[0], failures)


static func _test_shared_warehouse_routes_and_morning_exits(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(36, 22))
	var warehouse: int = world.place_building("warehouse", Vector2i(18, 7))
	var ids: Array[int] = []
	for index: int in range(6):
		ids.append(world.spawn_worker(Vector2i(10 + index * 2, 12), "carrier" if index % 2 == 0 else "builder"))
	world.tick = 3750
	world.economy_enabled = true
	var valid: bool = true
	var all_inside: bool = false
	for _tick: int in range(1000):
		world.step_tick()
		valid = valid and _reservations_valid(world)
		all_inside = true
		for id: int in ids:
			all_inside = all_inside and world.is_worker_sleeping(world.workers[id])
		if all_inside:
			break
	_check(all_inside and valid and world.tile_reservations.is_empty() and world.workers.size() == 6,
		"Six carriers and builders must share one warehouse through its real door without collisions or lost reservations", failures)
	for id: int in ids:
		_check(int(world.workers[id]["inside_building_id"]) == warehouse and int(world.workers[id]["home_id"]) == 0,
			"Communal sleeping must not turn the warehouse into an exclusive carrier or builder workplace", failures)
	# Supply three distinct construction jobs and three flour destinations so
	# every sleeper has actual daytime work requiring a physical departure.
	world.buildings[warehouse]["storage"]["flour"] = 12
	for x: int in [6, 18, 30]:
		world.economy_enabled = false
		world.place_building("bakery", Vector2i(x, 17))
		world.economy_enabled = true
		var site: int = world.place_building("lumber_hut", Vector2i(x, 2))
		world.buildings[site]["construction_delivered"] = world.construction_cost(world.buildings[site]).duplicate(true)
	world.tick = 5999
	var departed: Dictionary = {}
	for _tick: int in range(1200):
		world.step_tick()
		valid = valid and _reservations_valid(world)
		for id: int in ids:
			if not world.is_worker_inside(world.workers[id]):
				departed[id] = true
		if departed.size() == ids.size():
			break
	_check(departed.size() == 6 and valid and world.workers.size() == 6,
		"All six warehouse sleepers must physically depart for morning work while preserving unique outdoor reservations", failures)


static func _test_consumed_recipe_pauses_without_restarting(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(12, 10))
	var bakery: int = world.place_building("bakery", Vector2i(5, 3))
	var building: Dictionary = world.buildings[bakery]
	building["inputs"]["flour"] = 1
	var id: int = world.spawn_worker(building["entrance"], "baker", bakery)
	var baker: Dictionary = world.workers[id]
	world.economy_enabled = true
	if not _until(world, func() -> bool: return int(building["process_remaining"]) > 0):
		failures.append("The pause fixture must consume flour and begin an actual bread batch")
		return
	_advance(world, 20)
	world.tick = 3748
	var before_evening_tick: int = int(building["process_remaining"])
	world.step_tick()
	var remaining: int = int(building["process_remaining"])
	_check(remaining == before_evening_tick - 1, "The final work tick before 20:00 must still advance production", failures)
	world.step_tick()
	_advance(world, 200)
	_check(int(building["process_remaining"]) == remaining and int(building["inputs"]["flour"]) == 0
		and int(building["outputs"]["bread"]) == 0 and world.is_worker_sleeping(baker),
		"20:00 must freeze the partly completed bread batch, retaining its consumed flour and sleeping operator", failures)
	world.tick = 5999
	var resumed_at: int = world.tick
	_check(_until(world, func() -> bool: return int(building["outputs"]["bread"]) == 2, remaining + 10),
		"05:00 must resume the remaining bread time instead of restarting or discarding the batch", failures)
	_check(world.tick - resumed_at >= remaining and int(building["inputs"]["flour"]) == 0
		and int(building["outputs"]["bread"]) == 2,
		"The resumed bread batch must finish its outstanding work and consume its single input only once", failures)


static func _test_construction_preserves_completed_progress(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(16, 11))
	world.place_building("warehouse", Vector2i(3, 3))
	world.economy_enabled = true
	var site: int = world.place_building("bakery", Vector2i(11, 3))
	var building: Dictionary = world.buildings[site]
	building["construction_delivered"] = world.construction_cost(building).duplicate(true)
	var materials: Dictionary = building["construction_delivered"].duplicate(true)
	var id: int = world.spawn_worker(building["entrance"], "builder")
	var builder: Dictionary = world.workers[id]
	_check(_until(world, func() -> bool: return builder["state"] == "working"),
		"A supplied construction site must be actively worked before testing night suspension", failures)
	_advance(world, 15)
	world.tick = 3748
	world.step_tick()
	var remaining: int = int(building["construction_remaining"])
	world.step_tick()
	_check(int(building["construction_remaining"]) == remaining and int(builder["task_id"]) == 0,
		"20:00 must stop construction before another progress tick and release the builder's work reservation", failures)
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(builder)),
		"The construction worker must travel to the warehouse after its shift", failures)
	_advance(world, 150)
	_check(int(building["construction_remaining"]) == remaining and building["construction_delivered"] == materials,
		"Sleeping must preserve the completed construction progress and already delivered materials", failures)
	world.tick = 5999
	_check(_until(world, func() -> bool: return world.is_building_complete(building)),
		"After 05:00 the same builder must return and complete its suspended construction", failures)
	_check(building["construction_delivered"] == materials and world.workers.size() == 1,
		"Morning construction must not charge the delivered materials again or replace its builder", failures)


static func _test_sleeping_cargo_does_not_reserve_inputs(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(20, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(3, 3))
	var hut: int = world.place_building("lumber_hut", Vector2i(10, 3))
	var carrier: int = world.spawn_worker(Vector2i(6, 8), "carrier")
	var lumberjack: int = world.spawn_worker(Vector2i(14, 8), "lumberjack", hut)
	world.workers[carrier]["carrying"] = "log"
	world.workers[lumberjack]["carrying"] = "log"
	world.economy_enabled = true
	world.tick = 3750
	var valid: bool = true
	var both_asleep: bool = false
	for _tick: int in range(500):
		world.step_tick()
		valid = valid and world._incoming_amount(warehouse, "log") == 0 and world._incoming_amount(hut, "log") == 0
		valid = valid and int(world.resource_stock("log")["carried"]) == 2 and int(world.resource_stock("log")["total"]) == 2
		both_asleep = world.is_worker_sleeping(world.workers[carrier]) and world.is_worker_sleeping(world.workers[lumberjack])
		if both_asleep:
			break
	_check(both_asleep and valid and world.stored_amount("log") == 0 and int(world.buildings[hut]["outputs"]["log"]) == 0,
		"Travelling and sleeping with cargo must conserve two logs without creating incoming deliveries or depositing them at night", failures)


static func _test_missing_home_does_not_permit_night_work(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(15, 10))
	var sawmill: int = world.place_building("sawmill", Vector2i(10, 3))
	var id: int = world.spawn_worker(Vector2i(5, 7), "carrier")
	var carrier: Dictionary = world.workers[id]
	carrier["carrying"] = "log"
	world.economy_enabled = true
	world.tick = 3750
	_advance(world, 100)
	_check(int(carrier["sleep_home_id"]) == 0 and not world.is_worker_inside(carrier)
		and not world.is_worker_sleeping(carrier) and carrier["carrying"] == "log"
		and int(world.buildings[sawmill]["inputs"]["log"]) == 0 and int(carrier["task_id"]) == 0,
		"A missing sleeping place must not make a homeless carrier work, lose its log or disappear inside a nonexistent home", failures)
	_check(world.worker_schedule_status(carrier) == "No sleeping place available",
		"A civilian without housing must expose why it cannot go to sleep", failures)
	# An unfinished warehouse is also not a valid sleeping place.
	world.place_building("warehouse", Vector2i(2, 3))
	_advance(world, 100)
	_check(int(carrier["sleep_home_id"]) == 0 and carrier["carrying"] == "log",
		"A warehouse blueprint must not house a sleeper before construction is complete", failures)


static func _test_blocked_sleep_route_preserves_cargo(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(20, 12))
	world.place_building("warehouse", Vector2i(2, 3))
	var sawmill: int = world.place_building("sawmill", Vector2i(15, 3))
	var id: int = world.spawn_worker(Vector2i(13, 8), "carrier")
	var carrier: Dictionary = world.workers[id]
	carrier["carrying"] = "log"
	world.economy_enabled = true
	world.tick = 3750
	world.step_tick()
	_check(carrier["action"] == "go_sleep", "The blocked-route fixture must first choose a real route to its warehouse", failures)
	for y: int in range(world.grid.size.y):
		world.grid.set_base_terrain(Vector2i(8, y), "water")
	_advance(world, 250)
	_check(not world.is_worker_inside(carrier) and not world.is_worker_sleeping(carrier)
		and carrier["position"].x > 8 and carrier["carrying"] == "log"
		and int(world.buildings[sawmill]["inputs"]["log"]) == 0 and _reservations_valid(world),
		"A newly unreachable sleeping route must preserve cargo and outdoor occupancy without resuming nearby production deliveries", failures)
	_check(world.worker_schedule_status(carrier) == "Cannot reach sleeping place",
		"An unreachable assigned home must expose its blocked route instead of reporting a sleeping worker", failures)
	world.tick = 5999
	_check(_until(world, func() -> bool: return int(world.buildings[sawmill]["inputs"]["log"]) == 1),
		"Dawn must clear a failed sleeping route and allow a reachable daytime delivery", failures)


static func _test_night_finishes_the_visible_movement_step(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(18, 12))
	world.place_building("warehouse", Vector2i(14, 3))
	world.place_building("sawmill", Vector2i(2, 3))
	var id: int = world.spawn_worker(Vector2i(10, 8), "carrier")
	var carrier: Dictionary = world.workers[id]
	carrier["carrying"] = "log"
	world.economy_enabled = true
	if not _until(world, func() -> bool: return int(carrier["move_cooldown"]) > 0 \
		and int(carrier["visual_progress_ticks"]) < int(carrier["visual_duration_ticks"]), 40):
		failures.append("The night movement fixture must start an actual interpolated delivery step")
		return
	var from: Vector2i = carrier["previous_position"]
	var to: Vector2i = carrier["position"]
	var progress: int = int(carrier["visual_progress_ticks"])
	var duration: int = int(carrier["visual_duration_ticks"])
	world.tick = 3749
	world.step_tick()
	_check(carrier["previous_position"] == from and carrier["position"] == to
		and int(carrier["visual_progress_ticks"]) == progress + 1
		and int(carrier["visual_duration_ticks"]) == duration,
		"20:00 must finish the committed visible step without rewinding, snapping or resetting its interpolation", failures)
	while int(carrier["visual_progress_ticks"]) < duration:
		world.step_tick()
		_check(carrier["position"] == to and carrier["previous_position"] == from,
			"A night route change must wait until the original movement interpolation is fully complete", failures)
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(carrier)) and carrier["carrying"] == "log",
		"After its committed step finishes, the carrier must turn toward home while keeping its undelivered log", failures)


static func _test_guard_reports_to_its_tower_at_night(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(18, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
	var tower: int = world.place_building("watchtower", Vector2i(12, 3))
	var id: int = world.spawn_worker(Vector2i(8, 8), "recruit")
	var guard: Dictionary = world.workers[id]
	var soldier: int = world.spawn_worker(Vector2i(15, 8), "militia")
	world.economy_enabled = true
	world.tick = 3750
	_check(_until(world, func() -> bool: return int(guard["inside_building_id"]) == tower),
		"An exempt recruit must still walk to and enter its assigned watchtower during the night", failures)
	_check(int(guard["home_id"]) == tower and int(guard["sleep_home_id"]) == 0
		and not world.is_worker_sleeping(guard) and world.can_worker_work(guard)
		and int(guard["inside_building_id"]) != warehouse,
		"A night tower guard must retain its military post instead of sleeping in a civilian warehouse", failures)
	_check(world.can_worker_work(world.workers[soldier]) and not world.is_worker_sleeping(world.workers[soldier])
		and int(world.workers[soldier]["sleep_home_id"]) == 0 and _reservations_valid(world),
		"A military unit must remain active outdoors with a valid reservation throughout civilian night rest", failures)
