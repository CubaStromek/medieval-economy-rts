extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_entry_requires_actual_completed_door,
		_test_operator_finishes_last_outdoor_step,
		_test_operator_stays_inside_between_batches,
		_test_home_assignment_does_not_hide_remote_workers,
		_test_lumberjack_returns_rests_and_leaves,
		_test_busy_exit_preserves_occupant_and_cargo,
		_test_exit_waits_for_idle_yield_animation,
		_test_virtual_exit_is_not_a_carrier_passage,
		_test_diner_enters_then_returns_to_work,
		_test_guard_reports_through_the_actual_door,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 200) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _reservations_valid(world: Variant) -> bool:
	var outside: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if world.is_worker_inside(worker):
			if int(world.tile_reservations.get(worker["position"], 0)) == int(worker["id"]):
				return false
		else:
			if outside.has(worker["position"]):
				return false
			outside[worker["position"]] = int(worker["id"])
	return outside == world.tile_reservations


static func _test_entry_requires_actual_completed_door(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 9))
	var hut: int = world.place_building("lumber_hut", Vector2i(5, 4))
	var door: Vector2i = world.buildings[hut]["entrance"]
	var id: int = world.spawn_worker(door + Vector2i.LEFT, "lumberjack", hut)
	var worker: Dictionary = world.workers[id]
	_check(not world._enter_worker_building(worker, hut) and not world.is_worker_inside(worker),
		"Assigning a home or standing next to its door must not teleport a worker inside", failures)
	_check(world.spawn_worker(door + Vector2i.RIGHT, "carrier", 0, 0, hut) == 0
		and world.spawn_worker(door, "carrier", 0, 0, 9999) == 0,
		"Indoor spawning validates the exact doorway and an existing completed building", failures)
	world.buildings[hut]["construction_remaining"] = 1
	_check(world.spawn_worker(door, "carrier", 0, 0, hut) == 0,
		"An unfinished building cannot receive an indoor visitor", failures)
	world.buildings[hut]["construction_remaining"] = 0
	var visitor: int = world.spawn_worker(door, "carrier", 0, 0, hut)
	var second: int = world.spawn_worker(door, "builder", 0, 0, hut)
	var outside: int = world.spawn_worker(door, "builder")
	_check(visitor != 0 and second != 0 and outside != 0 and _reservations_valid(world),
		"Several indoor visitors can share a virtual doorway while exactly one outdoor worker owns the tile", failures)
	world._release_worker_tile(world.workers[visitor])
	_check(int(world.tile_reservations.get(door, 0)) == outside,
		"Releasing an indoor virtual location cannot release an outdoor worker's tile", failures)


static func _test_operator_finishes_last_outdoor_step(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 9))
	var sawmill: int = world.place_building("sawmill", Vector2i(5, 4))
	var door: Vector2i = world.buildings[sawmill]["entrance"]
	world.buildings[sawmill]["inputs"]["log"] = 1
	var id: int = world.spawn_worker(door + Vector2i.LEFT, "carpenter", sawmill)
	var worker: Dictionary = world.workers[id]
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return worker["position"] == door),
		"A real carpenter must route to its sawmill door", failures)
	_check(not world.is_worker_inside(worker) and int(worker["visual_progress_ticks"]) == 0
		and int(world.tile_reservations.get(door, 0)) == id,
		"The final logical step to a doorway stays visible and reserved while its animation starts", failures)
	for _tick: int in range(int(worker["visual_duration_ticks"]) - 1):
		world.step_tick()
		_check(not world.is_worker_inside(worker), "Entry cannot truncate the final outdoor interpolation", failures)
	world.step_tick()
	_check(world.is_worker_inside(worker) and worker["state"] == "working" and not world.tile_reservations.has(door),
		"Only the fully completed last movement step enters the sawmill and releases its outdoor door", failures)


static func _test_operator_stays_inside_between_batches(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 9))
	var sawmill: int = world.place_building("sawmill", Vector2i(5, 4))
	world.buildings[sawmill]["inputs"]["log"] = 2
	var id: int = world.spawn_worker(Vector2i(2, 6), "carpenter", sawmill)
	var worker: Dictionary = world.workers[id]
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return world.is_worker_inside(worker)),
		"The supplied sawmill must admit its assigned carpenter", failures)
	for _tick: int in range(220):
		world.step_tick()
		_check(world.is_worker_inside(worker) and _reservations_valid(world),
			"A carpenter must remain hidden during production, batch transitions and idle input waiting", failures)
	_check(int(world.buildings[sawmill]["outputs"]["plank"]) == 4 and worker["state"] == "idle"
		and world.workers.size() == 1 and int(worker["home_id"]) == sawmill,
		"Two indoor batches conserve the operator's identity/home and turn exactly two logs into four planks", failures)
	world.buildings[sawmill]["inputs"]["log"] = 1
	for _tick: int in range(100):
		world.step_tick()
		_check(world.is_worker_inside(worker), "Replenished inputs restart indoor work without a one-tick visible flicker", failures)
	_check(int(world.buildings[sawmill]["outputs"]["plank"]) == 6,
		"A waiting indoor carpenter resumes production after its inputs are replenished", failures)


static func _test_home_assignment_does_not_hide_remote_workers(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 10))
	var sawmill: int = world.place_building("sawmill", Vector2i(5, 4))
	var id: int = world.spawn_worker(Vector2i(10, 7), "carpenter", sawmill)
	var worker: Dictionary = world.workers[id]
	_advance(world, 40)
	_check(not world.is_worker_inside(worker) and worker["position"] == Vector2i(10, 7)
		and int(worker["home_id"]) == sawmill and _reservations_valid(world),
		"A remote idle specialist remains outdoors; owning a building alone is not an indoor visit", failures)
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var waiting: int = world.spawn_worker(world.buildings[hut]["entrance"], "lumberjack", hut)
	world.step_tick()
	_check(world.is_worker_inside(world.workers[waiting]) and int(world.workers[waiting]["indoor_wait_ticks"]) == 6,
		"An idle owner actually standing at its own doorway can wait inside the empty hut", failures)


static func _test_lumberjack_returns_rests_and_leaves(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 10))
	var hut: int = world.place_building("lumber_hut", Vector2i(4, 4))
	var door: Vector2i = world.buildings[hut]["entrance"]
	world.add_tree(Vector2i(9, 3), 2)
	var id: int = world.spawn_worker(Vector2i(8, 3), "lumberjack", hut)
	var worker: Dictionary = world.workers[id]
	_check(_until(world, func() -> bool: return int(world.buildings[hut]["outputs"]["log"]) == 1, 250),
		"A real lumberjack must harvest and carry a log back to its own hut", failures)
	_check(world.is_worker_inside(worker) and worker["position"] == door and worker["carrying"] == ""
		and int(worker["indoor_wait_ticks"]) == 6 and _reservations_valid(world),
		"The lumberjack delivers only after reaching and entering its actual doorway, then rests inside", failures)
	for _tick: int in range(6):
		world.step_tick()
		_check(world.is_worker_inside(worker), "A returned lumberjack stays inside for the full six-tick dwell", failures)
	_check(_until(world, func() -> bool: return not world.is_worker_inside(worker), 10),
		"More wood to harvest gives the rested lumberjack a new outdoor job", failures)
	_check(worker["position"] == door and worker["previous_position"] == door
		and int(worker["path_index"]) == 0 and int(world.tile_reservations.get(door, 0)) == id,
		"Departing reappears at the reserved door without also advancing an outdoor step in that tick", failures)
	world.step_tick()
	_check(worker["position"] != door and int(worker["path_index"]) == 1,
		"The next tick starts the first normal visible step towards the next tree", failures)
	_check(_until(world, func() -> bool: return int(world.buildings[hut]["outputs"]["log"]) == 2, 250)
		and world.trees.is_empty() and world.workers.size() == 1 and int(worker["home_id"]) == hut
		and worker["carrying"] == "" and _reservations_valid(world),
		"Repeated harvest/indoor return/departure preserves one worker and delivers exactly the original two logs", failures)


static func _exit_fixture() -> Dictionary:
	var world = World.new(Vector2i(12, 9))
	var hut: int = world.place_building("lumber_hut", Vector2i(5, 4))
	var door: Vector2i = world.buildings[hut]["entrance"]
	var id: int = world.spawn_worker(door, "carrier", 0, 0, hut)
	var worker: Dictionary = world.workers[id]
	worker["action"] = "test_departure"
	world._move_worker_to(worker, door + Vector2i.LEFT * 3)
	return {"world": world, "hut": hut, "door": door, "id": id, "worker": worker}


static func _test_busy_exit_preserves_occupant_and_cargo(failures: Array[String]) -> void:
	var fixture: Dictionary = _exit_fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var door: Vector2i = fixture["door"]
	worker["carrying"] = "log"
	var outside: int = world.spawn_worker(door, "builder")
	world.workers[outside]["state"] = "working"
	world.workers[outside]["action"] = "build_site"
	_advance(world, 20)
	_check(world.is_worker_inside(worker) and worker["carrying"] == "log" and worker["position"] == door
		and int(world.tile_reservations.get(door, 0)) == outside and _reservations_valid(world),
		"A busy doorway blocks indoor departure without losing cargo, overwriting a tile or exiting through another side", failures)
	world._reset_worker(world.workers[outside])
	world.workers[outside]["action"] = "test_clear_door"
	world._move_worker_to(world.workers[outside], door + Vector2i.RIGHT * 3)
	_check(_until(world, func() -> bool: return not world.is_worker_inside(worker), 20)
		and worker["position"] == door and worker["carrying"] == "log" and _reservations_valid(world),
		"When the busy citizen moves away normally, the original hidden carrier safely appears with its cargo", failures)


static func _test_exit_waits_for_idle_yield_animation(failures: Array[String]) -> void:
	var fixture: Dictionary = _exit_fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var door: Vector2i = fixture["door"]
	var outside: int = world.spawn_worker(door, "builder")
	world.step_tick()
	_check(world.is_worker_inside(worker) and world.workers[outside]["action"] == "yield"
		and world._yielding_origins.has(door),
		"An indoor departure asks an idle door occupant to make a real sidestep", failures)
	for _tick: int in range(int(world.workers[outside]["visual_duration_ticks"]) - 1):
		world.step_tick()
		_check(world.is_worker_inside(worker) and _reservations_valid(world),
			"The hidden worker waits until the yielding person's old door position is visually clear", failures)
	_check(_until(world, func() -> bool: return not world.is_worker_inside(worker), 3)
		and worker["position"] == door and _reservations_valid(world),
		"The indoor worker appears only after the idle sidestep has fully cleared its entrance", failures)


static func _test_virtual_exit_is_not_a_carrier_passage(failures: Array[String]) -> void:
	var fixture: Dictionary = _exit_fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	world.step_tick()
	_check(not world.is_worker_inside(worker) and world.grid.traffic_wear.is_empty()
		and world.grid.trail_links.is_empty(),
		"Reserving a virtual indoor door on exit is not a walked carrier edge and cannot wear a trail", failures)
	world.step_tick()
	_check(int(world.grid.traffic_wear.get(worker["position"], 0)) == 1 and world.grid.trail_links.size() == 1,
		"Only the carrier's following real outdoor step records one cell and edge passage", failures)


static func _test_diner_enters_then_returns_to_work(failures: Array[String]) -> void:
	var world = World.new(Vector2i(16, 11))
	var sawmill: int = world.place_building("sawmill", Vector2i(10, 5))
	var inn: int = world.place_building("inn", Vector2i(4, 5))
	world.buildings[inn]["inputs"]["bread"] = 1
	world.buildings[sawmill]["inputs"]["log"] = 1
	var id: int = world.spawn_worker(Vector2i(2, 3), "carpenter", sawmill)
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 300
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return int(worker["inside_building_id"]) == inn),
		"A hungry worker really walks through an inn doorway before becoming an indoor diner", failures)
	var arrival_condition: int = int(worker["hunger"])
	_check(int(world.buildings[inn]["inputs"]["bread"]) == 0 and arrival_condition <= 300
		and int(worker["home_id"]) == sawmill and int(worker["meal_ticks_left"]) > 0,
		"Entering the inn starts one physical course and preserves employment without instantly refilling condition", failures)
	var meal_ticks: int = int(worker["meal_ticks_left"])
	_advance(world, maxi(0, meal_ticks - 1))
	_check(int(worker["inside_building_id"]) == inn and int(worker["meal_ticks_left"]) == 1
		and worker["action"] == "eat" and int(worker["hunger"]) > arrival_condition and _reservations_valid(world),
		"The diner must gain condition while remaining inside throughout the course, without an invisible outdoor reservation", failures)
	_check(_until(world, func() -> bool: return not world.is_worker_inside(worker), int(worker["meal_ticks_left"]) + 15)
		and worker["position"] == world.buildings[inn]["entrance"],
		"The fed carpenter visibly leaves the inn through its door when resuming a sawmill job", failures)
	_check(_until(world, func() -> bool: return int(world.buildings[sawmill]["outputs"]["plank"]) == 2, 250)
		and int(worker["inside_building_id"]) == sawmill and _reservations_valid(world),
		"The same fed worker returns to its own building and completes its original available production", failures)


static func _test_guard_reports_through_the_actual_door(failures: Array[String]) -> void:
	for at_door: bool in [false, true]:
		var world = World.new(Vector2i(12, 9))
		var tower: int = world.place_building("watchtower", Vector2i(5, 4))
		var door: Vector2i = world.buildings[tower]["entrance"]
		var id: int = world.spawn_worker(door if at_door else door + Vector2i.LEFT, "recruit", tower)
		var worker: Dictionary = world.workers[id]
		_check(_until(world, func() -> bool: return world.is_worker_inside(worker), 30)
			and int(worker["inside_building_id"]) == tower and worker["position"] == door
			and int(worker["home_id"]) == tower and _reservations_valid(world),
			"An adjacent or already-at-door guard enters its exact assigned tower, leaving no invisible outdoor blocker", failures)
		_advance(world, 30)
		_check(world.is_worker_inside(worker) and worker["state"] == "idle",
			"A posted tower guard remains inside between duties", failures)
	# A communal barracks visitor has no exclusive home. Starting exactly on
	# its doorway still enters; equipping inside then uses the same safe exit.
	var world = World.new(Vector2i(12, 9))
	var barracks: int = world.place_building("barracks", Vector2i(5, 4))
	var door: Vector2i = world.buildings[barracks]["entrance"]
	var id: int = world.spawn_worker(door, "recruit")
	var worker: Dictionary = world.workers[id]
	world.step_tick()
	_check(world.is_worker_inside(worker) and int(worker["inside_building_id"]) == barracks,
		"An unassigned recruit already at a barracks door enters rather than waiting outdoors", failures)
	var outside: int = world.spawn_worker(door, "builder")
	world.workers[outside]["state"] = "working"
	world.workers[outside]["action"] = "build_site"
	world.buildings[barracks]["inputs"]["axe"] = 1
	world.queue_recruitment(barracks, "militia")
	world.step_tick()
	_check(worker["type"] == "militia" and worker["state"] == "moving" and world.is_worker_inside(worker)
		and int(world.buildings[barracks]["inputs"]["axe"]) == 0 and _reservations_valid(world),
		"Equipping an indoor recruit consumes one axe and queues a safe exit while preserving the occupied door", failures)
	world._reset_worker(world.workers[outside])
	world.workers[outside]["action"] = "test_clear_door"
	world._move_worker_to(world.workers[outside], door + Vector2i.RIGHT * 3)
	_check(_until(world, func() -> bool: return not world.is_worker_inside(worker), 15)
		and worker["position"] == door and world.workers.size() == 2 and _reservations_valid(world),
		"The newly equipped original recruit emerges at the cleared barracks door without duplicating a citizen", failures)
