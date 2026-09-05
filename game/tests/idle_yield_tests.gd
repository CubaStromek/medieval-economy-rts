extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_narrow_lane_with_side_pocket,
		_test_no_pocket_waits_safely,
		_test_busy_workers_and_guards_are_protected,
		_test_yield_preserves_home_and_wares,
		_test_two_requests_cannot_share_one_pocket,
		_test_yield_has_no_idle_jitter,
		_test_snapshot_during_yield_is_legal,
		_test_idle_carrier_plans_through_a_yieldable_pocket,
		_test_idle_carrier_selects_an_accessible_alternative,
		_test_idle_carrier_with_only_blocked_destinations_waits,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _fixture(pocket: bool = true, blocker_first: bool = false, preplan: bool = true) -> Dictionary:
	var world = World.new(Vector2i(11, 7))
	for y: int in range(7):
		for x: int in range(11):
			if y != 3:
				world.grid.set_base_terrain(Vector2i(x, y), "water")
	if pocket:
		world.grid.set_base_terrain(Vector2i(4, 2), "grass")
	world.grid.set_base_terrain(Vector2i(8, 2), "grass")
	var warehouse: int = world.place_building("warehouse", Vector2i(8, 2))
	var requester: int = 0
	var blocker: int = 0
	if blocker_first:
		blocker = world.spawn_worker(Vector2i(4, 3), "farmer")
		requester = world.spawn_worker(Vector2i(3, 3), "carrier")
	else:
		requester = world.spawn_worker(Vector2i(3, 3), "carrier")
		blocker = world.spawn_worker(Vector2i(4, 3), "farmer")
	var worker: Dictionary = world.workers[requester]
	worker["carrying"] = "plank"
	if preplan:
		worker["destination_id"] = warehouse
		worker["action"] = "deliver_plank"
		world._move_worker_to(worker, world.buildings[warehouse]["entrance"])
	return {"world": world, "requester": requester, "blocker": blocker, "warehouse": warehouse}


static func _unique_worker_tiles(world: Variant) -> bool:
	var seen: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if seen.has(worker["position"]):
			return false
		seen[worker["position"]] = true
	return true


static func _test_narrow_lane_with_side_pocket(failures: Array[String]) -> void:
	for blocker_first: bool in [false, true]:
		var fixture: Dictionary = _fixture(true, blocker_first)
		var world = fixture["world"]
		var blocker: Dictionary = world.workers[fixture["blocker"]]
		_check((int(fixture["blocker"]) < int(fixture["requester"])) == blocker_first,
			"The yielding fixture must exercise both real worker-ID update orders", failures)
		world.step_tick()
		_check(blocker["position"] == Vector2i(4, 2),
			"A blocker must yield immediately even if its lower-ID idle update already ran this tick", failures)
		for _tick: int in range(179):
			world.step_tick()
			_check(_unique_worker_tiles(world), "Yielding traffic must never place two workers on one tile", failures)
		_check(world.stored_amount("plank") == 1 and world.pipeline_amount("plank") == 0,
			"An idle blocker must step into a side pocket so the carrier can finish the narrow-lane delivery", failures)
		_check(blocker["position"] == Vector2i(4, 2), "The idle blocker must use the only safe off-route side pocket", failures)


static func _test_no_pocket_waits_safely(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	var world = fixture["world"]
	var requester: Dictionary = world.workers[fixture["requester"]]
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	_check(not world._try_yield_idle_worker(requester, int(fixture["blocker"])),
		"A blocker with no safe side pocket must not move into the requester's upcoming route", failures)
	_advance(world, 120)
	_check(blocker["position"] == Vector2i(4, 3) and requester["carrying"] == "plank",
		"Without a pocket the blocker must stay put and the carrier must wait without losing cargo", failures)
	_check(_unique_worker_tiles(world) and world.stored_amount("plank") + world.pipeline_amount("plank") == 1,
		"Graceful waiting must conserve the ware and avoid overlapping workers", failures)


static func _test_busy_workers_and_guards_are_protected(failures: Array[String]) -> void:
	for change: Dictionary in [
		{"state": "working"}, {"state": "moving"}, {"carrying": "grain"},
		{"task_id": 123}, {"action": "operate"}, {"move_cooldown": 3},
		{"visual_progress_ticks": 0, "visual_duration_ticks": 6},
	]:
		var fixture: Dictionary = _fixture()
		var world = fixture["world"]
		var blocker: Dictionary = world.workers[fixture["blocker"]]
		blocker.merge(change, true)
		_check(not world._try_yield_idle_worker(world.workers[fixture["requester"]], int(fixture["blocker"])),
			"Yield requests must not interrupt working, moving, carrying, reserved or still-animating workers: %s" % str(change), failures)
		_check(blocker["position"] == Vector2i(4, 3), "Rejected yield requests must leave the protected worker in place", failures)
	var guard_world = World.new(Vector2i(10, 8))
	var tower: int = guard_world.place_building("watchtower", Vector2i(2, 2))
	var requester: int = guard_world.spawn_worker(Vector2i(5, 1), "carrier")
	var guard: int = guard_world.spawn_worker(Vector2i(4, 1), "recruit", tower)
	guard_world.workers[requester]["action"] = "deliver_stone"
	guard_world._move_worker_to(guard_world.workers[requester], guard_world.buildings[tower]["entrance"])
	_check(not guard_world._try_yield_idle_worker(guard_world.workers[requester], guard),
		"A stationed tower guard must not abandon its post for a yield request", failures)


static func _add_home(fixture: Dictionary) -> int:
	var world = fixture["world"]
	world.grid.set_base_terrain(Vector2i(1, 1), "grass")
	world.grid.set_base_terrain(Vector2i(1, 2), "grass")
	var farm: int = world.place_building("farm", Vector2i(1, 1))
	world.ensure_workplace(world.workers[fixture["blocker"]])
	return farm


static func _test_yield_preserves_home_and_wares(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var farm: int = _add_home(fixture)
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	_check(int(blocker["home_id"]) == farm, "Yield ownership fixture must begin with a genuinely assigned farmer", failures)
	_advance(world, 180)
	_check(int(blocker["home_id"]) == farm and int(world.workplace_worker(farm).get("id", 0)) == int(fixture["blocker"]),
		"Stepping aside must preserve the worker's permanent one-to-one workplace assignment", failures)
	_check(String(blocker["carrying"]).is_empty() and world.stored_amount("plank") == 1,
		"Stepping aside must neither take the carrier's ware nor create another resource", failures)


static func _test_two_requests_cannot_share_one_pocket(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	world.grid.set_base_terrain(Vector2i(5, 2), "grass")
	world.grid.set_base_terrain(Vector2i(6, 2), "grass")
	var second_blocker: int = world.spawn_worker(Vector2i(5, 2), "farmer")
	var second_requester: int = world.spawn_worker(Vector2i(6, 2), "carrier")
	var second: Dictionary = world.workers[second_requester]
	second["state"] = "moving"
	second["action"] = "deliver_plank"
	second["path"] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 3)]
	_check(world._try_yield_idle_worker(world.workers[fixture["requester"]], int(fixture["blocker"])),
		"The first yield request must reserve the shared side pocket", failures)
	_check(not world._try_yield_idle_worker(second, second_blocker),
		"The second idle worker must not enter a side pocket already reserved by the first", failures)
	_check(_unique_worker_tiles(world), "Simultaneous requests must not create overlapping workers", failures)
	_check(int(world.tile_reservations.get(Vector2i(4, 2), 0)) == int(fixture["blocker"]),
		"The side-pocket reservation must remain owned by the first yielding worker", failures)


static func _test_yield_has_no_idle_jitter(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var blocker_id: int = int(fixture["blocker"])
	var blocker: Dictionary = world.workers[blocker_id]
	var requester: Dictionary = world.workers[fixture["requester"]]
	_check(world._try_yield_idle_worker(requester, blocker_id), "A truly idle blocker must accept its first safe yield", failures)
	_check(blocker["previous_position"] == Vector2i(4, 3) and int(blocker["visual_progress_ticks"]) == 0
		and int(blocker["visual_duration_ticks"]) == world.grid.step_duration_ticks(Vector2i(4, 3), blocker["position"]),
		"A sidestep must use normal interpolated terrain-dependent movement timing rather than teleportation", failures)
	_check(not world._try_yield_idle_worker(requester, blocker_id),
		"A yielding or recently yielded worker must not accept repeated same-tick sidesteps", failures)
	_check(world._temporary_blockers_for(int(requester["id"])).has(Vector2i(4, 3)),
		"The vacated corridor tile must remain reserved until the sidestep animation completes", failures)
	_advance(world, 180)
	var resting: Vector2i = blocker["position"]
	_advance(world, 80)
	_check(blocker["position"] == resting and resting == Vector2i(4, 2),
		"Once traffic passes, an idle worker must stay settled instead of repeatedly jittering between tiles", failures)


static func _test_snapshot_during_yield_is_legal(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var farm: int = _add_home(fixture)
	_check(world._try_yield_idle_worker(world.workers[fixture["requester"]], int(fixture["blocker"])),
		"Save fixture must actually begin a yielding step", failures)
	var restored = World.new()
	_check(restored.from_data(JSON.parse_string(JSON.stringify(world.to_data()))),
		"Saving during a sidestep must produce a valid reloadable snapshot", failures)
	if not restored.workers.has(fixture["blocker"]):
		return
	_check(_unique_worker_tiles(restored) and int(restored.workers[fixture["blocker"]]["home_id"]) == farm,
		"Reloading a yield must preserve unique positions and the farmer's workplace", failures)
	_advance(restored, 180)
	_check(restored.stored_amount("plank") == 1 and restored.pipeline_amount("plank") == 0,
		"Reloaded carrier traffic must finish once without stale yield reservations or duplicated cargo", failures)


static func _test_idle_carrier_plans_through_a_yieldable_pocket(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(true, false, false)
	var world = fixture["world"]
	var carrier: Dictionary = world.workers[fixture["requester"]]
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	_check(carrier["state"] == "idle" and (carrier["path"] as Array).is_empty() and int(carrier["destination_id"]) == 0,
		"The soft-route fixture must start with cargo only, without a preselected destination or route", failures)
	var before: Dictionary = world.to_data()
	var route: Array[Vector2i] = world._path_with_yielding(carrier["position"], world.buildings[fixture["warehouse"]]["entrance"],
		world._temporary_blockers_for(int(carrier["id"])), int(carrier["id"]))
	_check(not route.is_empty() and world.to_data() == before,
		"Checking a possible yield route must find the pocket without moving workers, assigning tasks or changing wares", failures)
	world.step_tick()
	_check(int(carrier["destination_id"]) == int(fixture["warehouse"]) and carrier["state"] == "moving",
		"An idle carrier must select the warehouse behind an idle worker with a real off-route pocket", failures)
	_check(blocker["position"] == Vector2i(4, 3), "Route selection alone must not prematurely move its idle blocker", failures)
	_advance(world, 180)
	_check(blocker["position"] == Vector2i(4, 2) and world.stored_amount("plank") == 1 and world.pipeline_amount("plank") == 0,
		"Autonomous destination selection, yielding and delivery must complete the whole narrow-pocket route", failures)


static func _test_idle_carrier_selects_an_accessible_alternative(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false, false, false)
	var world = fixture["world"]
	# A bent approach makes this warehouse farther than the blocked one. Route
	# selection must reject the impossible short route, not win by distance alone.
	for cell: Vector2i in [Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)]:
		world.grid.set_base_terrain(cell, "grass")
	var alternative: int = world.place_building("warehouse", Vector2i(2, 0))
	var carrier: Dictionary = world.workers[fixture["requester"]]
	var pathfinder: Script = load("res://scripts/simulation/grid_pathfinder.gd")
	var start: Vector2i = carrier["position"]
	var tempting: Array[Vector2i] = pathfinder.find_path(world.grid, start, world.buildings[fixture["warehouse"]]["entrance"])
	var accessible: Array[Vector2i] = pathfinder.find_path(world.grid, start, world.buildings[alternative]["entrance"])
	_check(pathfinder.path_cost(world.grid, tempting, start) < pathfinder.path_cost(world.grid, accessible, start),
		"The blocked destination must really be cheaper before considering the idle worker's lack of a pocket", failures)
	world.step_tick()
	_check(int(carrier["destination_id"]) == alternative,
		"An idle carrier must choose a farther accessible warehouse when the nearest idle blocker cannot step aside", failures)
	_advance(world, 180)
	_check(int(world.buildings[alternative]["storage"]["plank"]) == 1 and int(world.buildings[fixture["warehouse"]]["storage"]["plank"]) == 0,
		"The selected alternative warehouse must receive the carried ware exactly once", failures)
	_check(world.workers[fixture["blocker"]]["position"] == Vector2i(4, 3) and world.pipeline_amount("plank") == 0,
		"Using an alternate destination must leave the trapped idle worker undisturbed", failures)


static func _test_idle_carrier_with_only_blocked_destinations_waits(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false, false, false)
	var world = fixture["world"]
	var carrier: Dictionary = world.workers[fixture["requester"]]
	world.step_tick()
	_check(carrier["state"] == "idle" and int(carrier["destination_id"]) == 0 and (carrier["path"] as Array).is_empty(),
		"A destination behind a no-pocket blocker must not be selected as an allegedly traversable route", failures)
	var retry: int = int(carrier["blocked_ticks"])
	_check(retry > 1, "A wholly blocked delivery must schedule a retry delay instead of repeatedly searching within one tick", failures)
	world.step_tick()
	_check(int(carrier["blocked_ticks"]) == retry - 1, "An unchanged blocked carrier must count down its retry delay", failures)
	_advance(world, 120)
	_check(world.tick == 122 and carrier["position"] == Vector2i(3, 3) and carrier["carrying"] == "plank",
		"Repeated no-pocket route checks must terminate, preserve cargo and wait without back-and-forth movement", failures)
	_check(world.stored_amount("plank") + world.pipeline_amount("plank") == 1 and _unique_worker_tiles(world),
		"All-blocked route selection must conserve resources and unique worker positions", failures)
