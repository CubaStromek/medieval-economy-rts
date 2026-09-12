extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_loaded_lumberjack_returns_through_large_building_gap,
		_test_multistep_yield_has_real_interpolation,
		_test_route_planning_remains_read_only,
		_test_no_reachable_clearing_waits_safely,
		_test_busy_workers_and_guards_keep_their_jobs,
		_test_mid_retreat_snapshot_resumes_delivery,
		_test_dead_end_doorway_uses_clearing_behind_requester,
		_test_inside_exit_uses_a_multistep_retreat,
		_test_concurrent_retreats_do_not_share_a_distant_target,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


# Revision-1 production footprints form both walls of a one-cell-wide passage.
# The idle person at (4,5) has no one-step off-route destination: the only
# clearing (6,6) requires first walking forward along the requested route.
# Water closes unrelated detours, while every authored foundation/door stays
# legal and the complete fixture can be round-tripped through the real loader.
static func _fixture(pocket: bool = true, blocker_first: bool = false, guard: bool = false, dead_end: bool = false, inside_exit: bool = false) -> Dictionary:
	var world = World.new(Vector2i(14, 12))
	# This regression preserves an existing settlement's exact corridor and
	# offset doorway. The new notched hut has its own movement coverage.
	world.default_footprint_version = 1
	var store: int = world.place_building("warehouse", Vector2i(3, 4))
	world.place_building("school", Vector2i(3, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(7, 4))
	var tower: int = world.place_building("watchtower", Vector2i(10, 9)) if guard else 0
	var keep: Dictionary = {Vector2i(4, 9): true, Vector2i(5, 9): true}
	if pocket:
		keep[Vector2i(6, 6)] = true
	for x: int in range(1, 10):
		keep[Vector2i(x, 5)] = true
	if not pocket:
		# No space behind the requester either: reciprocal passing must not
		# turn this safety case into a legitimately solvable reverse retreat.
		keep.erase(Vector2i(1, 5))
		keep.erase(Vector2i(2, 5))
	for building: Dictionary in world.buildings.values():
		for cell: Vector2i in world.building_cells(building):
			keep[cell] = true
		keep[building["entrance"]] = true
	if guard:
		keep[Vector2i(12, 10)] = true
	for y: int in range(12):
		for x: int in range(14):
			if not keep.has(Vector2i(x, y)):
				world.grid.set_base_terrain(Vector2i(x, y), "water")
	var requester: int = 0
	var blocker: int = 0
	var role: String = "recruit" if guard else "carrier"
	var requester_cell := Vector2i(8, 5) if dead_end else Vector2i(3, 5)
	if inside_exit:
		requester_cell = world.buildings[store]["entrance"]
	var blocker_cell := Vector2i(9, 5) if dead_end else Vector2i(4, 5)
	if blocker_first:
		blocker = world.spawn_worker(blocker_cell, role, tower)
		requester = world.spawn_worker(requester_cell, "lumberjack", hut, 0, store if inside_exit else 0)
	else:
		requester = world.spawn_worker(requester_cell, "lumberjack", hut, 0, store if inside_exit else 0)
		blocker = world.spawn_worker(blocker_cell, role, tower)
	world.workers[requester]["carrying"] = "log"
	return {"world": world, "hut": hut, "requester": requester, "blocker": blocker, "tower": tower}


static func _preplan(fixture: Dictionary) -> void:
	var world = fixture["world"]
	var worker: Dictionary = world.workers[fixture["requester"]]
	worker["action"] = "deliver_log"
	worker["destination_id"] = int(fixture["hut"])
	world._move_worker_to(worker, world.buildings[fixture["hut"]]["entrance"])


static func _safety(world: Variant) -> bool:
	var outside: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		var position: Vector2i = worker["position"]
		if not world.grid.is_walkable(position):
			return false
		if not world.is_worker_inside(worker):
			if outside.has(position):
				return false
			outside[position] = int(worker["id"])
			if int(world.tile_reservations.get(position, 0)) != int(worker["id"]):
				return false
		elif int(world.tile_reservations.get(position, 0)) == int(worker["id"]):
			return false
	return outside == world.tile_reservations


static func _deliver(fixture: Dictionary, failures: Array[String], limit: int = 220) -> bool:
	var world = fixture["world"]
	for _tick: int in range(limit):
		if int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1:
			return true
		world.step_tick()
		if not _safety(world):
			failures.append("Corridor yielding must preserve unique outdoor reservations and never enter a large building footprint")
			return false
	return int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1


static func _test_loaded_lumberjack_returns_through_large_building_gap(failures: Array[String]) -> void:
	for blocker_first: bool in [false, true]:
		var fixture: Dictionary = _fixture(true, blocker_first)
		var original = fixture["world"]
		var restored = World.new()
		if not restored.from_data(JSON.parse_string(JSON.stringify(original.to_data()))):
			failures.append("The regression must start from a real valid loaded large-footprint settlement")
			continue
		fixture["world"] = restored
		_check(restored.buildings.size() == 3 and restored.grid.blocked_by.size() == 24
			and restored.buildings[fixture["hut"]]["entrance"] == Vector2i(9, 5),
			"The corridor fixture must retain the saved revision-1 warehouse/school/hut footprints and the hut's offset door", failures)
		_check(_deliver(fixture, failures),
			"A loaded lumberjack carrying a log must get past the idle carrier and deliver to its hut when a clearing exists several steps away", failures)
		var worker: Dictionary = restored.workers[fixture["requester"]]
		_check(worker["carrying"] == "" and int(worker["home_id"]) == int(fixture["hut"])
			and int(restored.resource_stock("log")["total"]) == 1 and restored.workers.size() == 2,
			"Multi-step give-way must preserve the original worker/home and deliver the one carried log exactly once", failures)


static func _test_multistep_yield_has_real_interpolation(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	_preplan(fixture)
	var world = fixture["world"]
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	var previous: Vector2i = blocker["position"]
	var observed_steps: int = 0
	var pocket_reached: bool = false
	for _tick: int in range(180):
		world.step_tick()
		_check(_safety(world), "Every retreat frame must retain collision and building-footprint safety", failures)
		if blocker["position"] != previous:
			observed_steps += 1
			_check(world.grid.can_traverse(previous, blocker["position"])
				and blocker["previous_position"] == previous
				and int(blocker["visual_progress_ticks"]) == 0
				and int(blocker["visual_duration_ticks"]) == world.grid.step_duration_ticks(previous, blocker["position"]),
				"Each segment of a longer yield must be a normal adjacent, corner-safe, terrain-timed interpolated step", failures)
			_check(world._temporary_blockers_for(int(fixture["requester"])).has(previous),
				"Every yielding segment keeps its old visible position blocked until its interpolation clears", failures)
			previous = blocker["position"]
		if blocker["position"] == Vector2i(6, 6):
			pocket_reached = true
		if int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1:
			break
	_check(observed_steps >= 3 and pocket_reached,
		"The carrier must walk along the corridor and then enter the distant side pocket instead of teleporting or refusing to move", failures)
	_check(world.grid.traffic_wear.is_empty() and world.grid.trail_links.is_empty(),
		"A carrier's whole give-way maneuver is courtesy movement, not repeated transport traffic that creates a trail", failures)


static func _test_route_planning_remains_read_only(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var id: int = int(fixture["requester"])
	var worker: Dictionary = world.workers[id]
	var before: Dictionary = world.to_data()
	var worker_states: Dictionary = world.workers.duplicate(true)
	var tasks: Dictionary = world.task_board._tasks.duplicate(true)
	var reservations: Dictionary = world.tile_reservations.duplicate()
	var origins: Dictionary = world._yielding_origins.duplicate()
	var route: Array[Vector2i] = world._path_with_yielding(worker["position"], world.buildings[fixture["hut"]]["entrance"],
		world._temporary_blockers_for(id), id)
	_check(not route.is_empty(), "Read-only destination selection must recognize a feasible multi-step retreat to a distant clearing", failures)
	_check(world.to_data() == before and world.workers == worker_states and world.task_board._tasks == tasks
		and world.tile_reservations == reservations and world._yielding_origins == origins,
		"Scoring a yield-capable path must not move workers, reserve a retreat, mutate cargo or begin animations", failures)
	var repeated: Array[Vector2i] = world._path_with_yielding(worker["position"], world.buildings[fixture["hut"]]["entrance"],
		world._temporary_blockers_for(id), id)
	_check(repeated == route and world.to_data() == before,
		"Repeated corridor feasibility checks must be deterministic and free of gameplay side effects", failures)


static func _test_no_reachable_clearing_waits_safely(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(false)
	_preplan(fixture)
	var world = fixture["world"]
	for _tick: int in range(100):
		world.step_tick()
		_check(_safety(world), "A truly closed corridor must wait safely instead of forcing overlapping or corner-cutting units", failures)
	_check(world.workers[fixture["requester"]]["carrying"] == "log"
		and int(world.resource_stock("log")["total"]) == 1
		and int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 0,
		"If there is genuinely nowhere to pass, the lumberjack retains its one log and does not deliver through another worker", failures)


static func _test_busy_workers_and_guards_keep_their_jobs(failures: Array[String]) -> void:
	for change: Dictionary in [
		{"state": "working", "action": "build_site"}, {"carrying": "grain"},
		{"task_id": 999}, {"move_cooldown": 2},
		{"visual_progress_ticks": 0, "visual_duration_ticks": 6},
	]:
		var fixture: Dictionary = _fixture()
		_preplan(fixture)
		var world = fixture["world"]
		var blocker: Dictionary = world.workers[fixture["blocker"]]
		blocker.merge(change, true)
		var before: Dictionary = blocker.duplicate(true)
		_check(not world._try_yield_idle_worker(world.workers[fixture["requester"]], int(fixture["blocker"]))
			and blocker == before and _safety(world),
			"Distant-pocket yielding must not displace busy, loaded, task-reserved or still-animating workers: " + str(change), failures)
	var fixture: Dictionary = _fixture(true, false, true)
	_preplan(fixture)
	var world = fixture["world"]
	var guard: Dictionary = world.workers[fixture["blocker"]]
	_check(world.owns_workplace(guard, int(fixture["tower"]))
		and not world._try_yield_idle_worker(world.workers[fixture["requester"]], int(fixture["blocker"]))
		and guard["position"] == Vector2i(4, 5),
		"An assigned guard must retain its post even when a longer give-way path could be found", failures)


static func _test_mid_retreat_snapshot_resumes_delivery(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	_preplan(fixture)
	var world = fixture["world"]
	var started: bool = false
	for _tick: int in range(40):
		world.step_tick()
		if world.workers[fixture["blocker"]]["position"] != Vector2i(4, 5):
			started = true
			break
	if not started:
		failures.append("The save regression must first start a genuine longer give-way maneuver")
		return
	var restored = World.new()
	if not restored.from_data(JSON.parse_string(JSON.stringify(world.to_data()))):
		failures.append("A mid-retreat snapshot with large footprints must remain a valid save")
		return
	fixture["world"] = restored
	_check(_safety(restored) and restored._yielding_origins.is_empty(),
		"Loading must reconstruct unique worker positions without orphaned animation reservations", failures)
	_check(_deliver(fixture, failures) and int(restored.resource_stock("log")["total"]) == 1
		and int(restored.workers[fixture["requester"]]["home_id"]) == int(fixture["hut"]),
		"After loading during a retreat, the same lumberjack must finish its original delivery without stale courtesy state or lost cargo", failures)


static func _test_dead_end_doorway_uses_clearing_behind_requester(failures: Array[String]) -> void:
	for blocker_first: bool in [false, true]:
		var fixture: Dictionary = _fixture(true, blocker_first, false, true)
		var original = fixture["world"]
		var world = World.new()
		if not world.from_data(JSON.parse_string(JSON.stringify(original.to_data()))):
			failures.append("The dead-end door regression must load real workers and a valid fixed southern doorway")
			continue
		fixture["world"] = world
		var blocker: Dictionary = world.workers[fixture["blocker"]]
		var worker: Dictionary = world.workers[fixture["requester"]]
		var previous: Vector2i = blocker["position"]
		var delivered: bool = false
		var cleared: bool = false
		for _tick: int in range(240):
			world.step_tick()
			_check(_safety(world), "Coordinated movement out of a dead-end doorway must preserve unique reservations and solid building walls", failures)
			if blocker["position"] != previous:
				_check(world.grid.can_traverse(previous, blocker["position"])
					and blocker["previous_position"] == previous
					and int(blocker["visual_progress_ticks"]) == 0
					and int(blocker["visual_duration_ticks"]) == world.grid.step_duration_ticks(previous, blocker["position"]),
					"A coordinated dead-end give-way uses adjacent timed steps, including any reciprocal passing step", failures)
				previous = blocker["position"]
			delivered = delivered or int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1
			# After passing a requester whose whole goal is this doorway, (7,5)
			# is already a safe off-route resting cell; walking farther to the
			# lateral pocket is unnecessary. Either legal retreat is acceptable.
			cleared = cleared or blocker["position"] in [Vector2i(7, 5), Vector2i(6, 5), Vector2i(6, 6)]
			if delivered and cleared:
				break
		_check(delivered and cleared and int(worker["home_id"]) == int(fixture["hut"])
			and worker["carrying"] == "" and int(world.resource_stock("log")["total"]) == 1,
			"An idle carrier trapped at the hut door must clear back past the returning lumberjack to a real pocket so its log is delivered once", failures)


static func _test_inside_exit_uses_a_multistep_retreat(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(true, false, false, false, true)
	var world = fixture["world"]
	# At this door, the only exit is east through the carrier. Its first two
	# available tiles belong to the departing worker's planned walking route.
	world.grid.set_base_terrain(Vector2i(3, 5), "water")
	var worker: Dictionary = world.workers[fixture["requester"]]
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	var was_inside: bool = true
	var appeared_at_door: bool = false
	var pocket_reached: bool = false
	for _tick: int in range(180):
		world.step_tick()
		_check(_safety(world), "An indoor exit with a distant give-way pocket must preserve unique outdoor reservations", failures)
		if world._yielding_origins.has(Vector2i(4, 5)):
			_check(world.is_worker_inside(worker), "The indoor worker must wait while the yielding carrier visibly clears the doorway", failures)
		if was_inside and not world.is_worker_inside(worker):
			appeared_at_door = worker["position"] == Vector2i(4, 5) and int(worker["path_index"]) == 0
		was_inside = world.is_worker_inside(worker)
		pocket_reached = pocket_reached or blocker["position"] == Vector2i(6, 6)
		if int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1:
			break
	_check(appeared_at_door and pocket_reached and int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1
		and int(world.resource_stock("log")["total"]) == 1,
		"An indoor citizen must safely emerge at its real door after a multi-step retreat and complete its original cargo delivery", failures)


static func _test_concurrent_retreats_do_not_share_a_distant_target(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	for cell: Vector2i in [Vector2i(6, 7), Vector2i(6, 8), Vector2i(6, 9), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7)]:
		world.grid.set_base_terrain(cell, "grass")
	_preplan(fixture)
	var second: int = world.spawn_worker(Vector2i(6, 9), "builder")
	var second_blocker: int = world.spawn_worker(Vector2i(6, 8), "carrier")
	var requester: Dictionary = world.workers[second]
	requester["action"] = "test_cross_corridor"
	var route: Array[Vector2i] = [Vector2i(6, 8), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7)]
	world._begin_worker_move(requester, route, Vector2i(9, 7))
	_check(world._try_yield_idle_worker(world.workers[fixture["requester"]], int(fixture["blocker"]))
		and world.workers[fixture["blocker"]]["target_cell"] == Vector2i(6, 6),
		"The first real multi-step retreat must claim the shared distant pocket", failures)
	var accepted: bool = world._try_yield_idle_worker(requester, second_blocker)
	_check(not accepted or world.workers[second_blocker]["target_cell"] != Vector2i(6, 6),
		"A concurrent retreat must choose a different reachable resting cell or wait, never claim the first worker's distant target", failures)
	for _tick: int in range(80):
		world.step_tick()
		_check(_safety(world), "Concurrent distant retreat plans must retain unique logical positions throughout their actual walking steps", failures)
