extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Legacy = preload("res://tests/legacy_world_fixture.gd")
const Feeding = preload("res://scripts/simulation/inn_feeding.gd")
const YieldTests = preload("res://tests/idle_yield_tests.gd")
const TEST_COUNT: int = 12


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_flags_and_ownership, _test_gardener_interrupt_and_resume,
		_test_independent_huts_and_vacancies, _test_committed_step,
		_test_held_goods_deliver, _test_cancel_uncollected_pickup,
		_test_closed_destination_reroutes, _test_closed_producer_exports,
		_test_paused_unit_lives_and_sleeps, _test_paused_inn_finishes_only_paid_course,
		_test_paused_idle_yields, _test_market_and_recruitment]:
		test.call(failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
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


static func _gardener() -> Dictionary:
	var world := World.new(Vector2i(26, 20))
	var hut: int = world.place_building("forester_hut", Vector2i(5, 4))
	var id: int = world.spawn_worker(Vector2i(14, 12), "gardener", hut)
	world.economy_enabled = true
	return {"world": world, "hut": hut, "id": id, "worker": world.workers[id]}


static func _test_flags_and_ownership(failures: Array[String]) -> void:
	var f: Dictionary = _gardener()
	var world: World = f["world"]
	var foreign: int = world.spawn_worker(Vector2i(22, 15), "carrier", 0, false, 0, 2)
	var enemy_hut: int = world.place_building("forester_hut", Vector2i(18, 4), 2)
	_check(bool(f["worker"]["enabled"]) and world.is_building_enabled(world.buildings[f["hut"]]),
		"New units and buildings start enabled", failures)
	_check(not world.set_worker_enabled(99999, false) and not world.set_building_enabled(99999, false)
		and not world.set_worker_enabled(foreign, false) and not world.set_building_enabled(enemy_hut, false),
		"Pause commands reject missing and foreign entities without changing ownership", failures)
	world.set_worker_enabled(f["id"], false)
	var events: int = world.event_log.size()
	_check(world.set_worker_enabled(f["id"], false) and events == world.event_log.size(),
		"Setting the same pause value twice is idempotent, not a second toggle or duplicate event", failures)
	world.set_building_enabled(f["hut"], false)
	world.set_worker_enabled(f["id"], true)
	_check(world.is_worker_work_paused(f["worker"]), "Resuming a unit does not resume its separately paused home", failures)
	world.set_worker_enabled(f["id"], false)
	world.set_building_enabled(f["hut"], true)
	_check(world.is_worker_work_paused(f["worker"]), "Resuming a building does not resume its separately paused employee", failures)


static func _test_gardener_interrupt_and_resume(failures: Array[String]) -> void:
	for pause_home: bool in [false, true]:
		var f: Dictionary = _gardener()
		var world: World = f["world"]
		var worker: Dictionary = f["worker"]
		if not _until(world, func() -> bool: return worker["state"] == "working"):
			failures.append("Gardener pause fixture must reach actual planting work")
			continue
		if pause_home:
			world.set_building_enabled(f["hut"], false)
		else:
			world.set_worker_enabled(f["id"], false)
		_advance(world, 200)
		_check(world.trees.is_empty() and world.planting_reservations.is_empty()
			and int(worker["task_id"]) == 0 and world.owns_workplace(worker, f["hut"])
			and int(worker["inside_building_id"]) == int(f["hut"]),
			"A paused working gardener cancels its sapling, frees the site and physically returns into the same hut", failures)
		world.set_building_enabled(f["hut"], true)
		world.set_worker_enabled(f["id"], true)
		_check(_until(world, func() -> bool: return not world.trees.is_empty()),
			"Resumed gardening must leave the real hut and plant again", failures)


static func _test_independent_huts_and_vacancies(failures: Array[String]) -> void:
	var world := World.new(Vector2i(42, 24))
	var closed: int = world.place_building("forester_hut", Vector2i(4, 4))
	var open: int = world.place_building("forester_hut", Vector2i(28, 4))
	var first: int = world.spawn_worker(Vector2i(10, 12), "gardener", closed)
	world.set_building_enabled(closed, false)
	var second: int = world.spawn_worker(Vector2i(20, 14), "gardener")
	world.economy_enabled = true
	_check(int(world.workers[second]["home_id"]) == open, "A new gardener chooses an enabled vacancy without replacing the paused hut's owner", failures)
	_advance(world, 260)
	_check(not world.trees.is_empty() and world.owns_workplace(world.workers[first], closed)
		and world.owns_workplace(world.workers[second], open), "Only the selected hut pauses; another gardener continues independently", failures)
	for tree: Dictionary in world.trees.values():
		var cell: Vector2i = tree["position"]
		_check(cell.x >= 20, "No tree is planted near the stopped gardener's distant hut", failures)
	var empty: int = world.place_building("forester_hut", Vector2i(16, 4))
	world.buildings[empty]["construction_remaining"] = 0
	world.set_building_enabled(empty, false)
	var third: int = world.spawn_worker(Vector2i(18, 18), "gardener")
	_check(int(world.workers[third]["home_id"]) == 0, "Disabled vacant workplaces are not automatically staffed", failures)
	world.set_building_enabled(empty, true)
	world.step_tick()
	_check(int(world.workers[third]["home_id"]) == empty, "Enabling a vacancy immediately makes it available to an unemployed specialist", failures)


static func _test_committed_step(failures: Array[String]) -> void:
	var f: Dictionary = _gardener()
	var world: World = f["world"]
	var worker: Dictionary = f["worker"]
	if not _until(world, func() -> bool: return int(worker["move_cooldown"]) > 2):
		failures.append("Movement pause fixture must commit a visible step")
		return
	var previous: Vector2i = worker["previous_position"]
	var position: Vector2i = worker["position"]
	var duration: int = int(worker["visual_duration_ticks"])
	var progress: int = int(worker["visual_progress_ticks"])
	world.set_worker_enabled(f["id"], false)
	world.step_tick()
	_check(worker["previous_position"] == previous and worker["position"] == position
		and int(worker["visual_duration_ticks"]) == duration and int(worker["visual_progress_ticks"]) == progress + 1
		and world.planting_reservations.is_empty(),
		"Pausing mid-step keeps its endpoints and monotonic animation while cancelling the planting reservation", failures)
	_check(_until(world, func() -> bool: return world.is_worker_inside(worker)),
		"A paused mid-step worker must finish its animation and reach shelter without teleporting or getting stuck", failures)


static func _test_held_goods_deliver(failures: Array[String]) -> void:
	for role: String in ["carrier", "lumberjack"]:
		var world := Legacy.create(Vector2i(18, 12))
		var store: int = world.place_building("warehouse", Vector2i(3, 3))
		var hut: int = world.place_building("lumber_hut", Vector2i(11, 3))
		var id: int = world.spawn_worker(Vector2i(8, 9), role, hut if role == "lumberjack" else 0)
		var worker: Dictionary = world.workers[id]
		worker["carrying"] = "log"
		world.set_worker_enabled(id, false)
		world.set_building_enabled(hut, false)
		world.economy_enabled = true
		_check(_until(world, func() -> bool: return String(worker["carrying"]).is_empty()),
			"Paused %s delivers an already held log instead of abandoning it or freezing logistics" % role, failures)
		_check(int(world.resource_stock("log")["total"]) == 1
			and (int(world.buildings[store]["storage"].get("log", 0)) == 1 if role == "carrier" else int(world.buildings[hut]["outputs"].get("log", 0)) == 1),
			"Cleanup delivers the one real log to the warehouse or the paused lumberjack's original hut", failures)


static func _test_cancel_uncollected_pickup(failures: Array[String]) -> void:
	var world := Legacy.create(Vector2i(20, 12))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	world.place_building("warehouse", Vector2i(16, 3))
	world.buildings[hut]["outputs"]["log"] = 3
	var id: int = world.spawn_worker(Vector2i(12, 9), "carrier")
	world.economy_enabled = true
	var worker: Dictionary = world.workers[id]
	if not _until(world, func() -> bool: return String(worker["action"]).begins_with("pickup_")):
		failures.append("Uncollected pause fixture must reserve a real transport task")
		return
	world.set_worker_enabled(id, false)
	_advance(world, 180)
	_check(String(worker["carrying"]).is_empty() and int(worker["task_id"]) == 0
		and int(world.buildings[hut]["outputs"]["log"]) == 3,
		"A paused carrier releases its uncollected assignment and does not remove goods from the source", failures)
	world.set_worker_enabled(id, true)
	_check(_until(world, func() -> bool: return world.stored_amount("log") > 0),
		"Resuming the carrier makes cancelled transport work available again", failures)


static func _test_closed_destination_reroutes(failures: Array[String]) -> void:
	var world := Legacy.create(Vector2i(20, 12))
	var mill: int = world.place_building("sawmill", Vector2i(3, 3))
	var store: int = world.place_building("warehouse", Vector2i(16, 3))
	var id: int = world.spawn_worker(Vector2i(8, 9), "carrier")
	var worker: Dictionary = world.workers[id]
	worker["carrying"] = "log"
	world._resume_carried_ware(worker)
	_check(int(worker["destination_id"]) == mill, "In-flight fixture initially routes the held log to a working consumer", failures)
	world.set_building_enabled(mill, false)
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return int(world.buildings[store]["storage"].get("log", 0)) == 1)
		and int(world.buildings[mill]["inputs"].get("log", 0)) == 0 and int(world.resource_stock("log")["total"]) == 1,
		"A destination paused during delivery refuses new input and the carrier safely reroutes the same physical ware", failures)


static func _test_closed_producer_exports(failures: Array[String]) -> void:
	var world := Legacy.create(Vector2i(16, 10))
	var mill: int = world.place_building("sawmill", Vector2i(3, 3))
	world.place_building("warehouse", Vector2i(11, 3))
	world.buildings[mill]["outputs"]["plank"] = 2
	world.buildings[mill]["inputs"]["log"] = 2
	world.spawn_worker(Vector2i(8, 7), "carrier")
	world.set_building_enabled(mill, false)
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return world.stored_amount("plank") == 2)
		and int(world.buildings[mill]["inputs"]["log"]) == 2 and not world._input_room(world.buildings[mill], "log", 0),
		"Pausing a producer keeps its inputs and blocks replenishment but permits collection of finished stored outputs", failures)
	var legacy := Legacy.create(Vector2i(12, 10))
	var legacy_mill: int = legacy.place_building("sawmill", Vector2i(3, 3))
	var carpenter: int = legacy.spawn_worker(Vector2i(7, 7), "carpenter", legacy_mill)
	legacy.buildings[legacy_mill]["inputs"]["log"] = 1
	legacy.set_worker_enabled(carpenter, false)
	_advance(legacy, 60)
	_check(int(legacy.buildings[legacy_mill]["inputs"]["log"]) == 1
		and int(legacy.buildings[legacy_mill]["process_remaining"]) == 0,
		"The historical automatic-sawmill fallback cannot bypass a real employee's explicit pause", failures)


static func _test_paused_unit_lives_and_sleeps(failures: Array[String]) -> void:
	var world := Legacy.create(Vector2i(18, 12))
	var hut: int = world.place_building("forester_hut", Vector2i(4, 3))
	var inn: int = world.place_building("inn", Vector2i(12, 3))
	world.buildings[inn]["inputs"]["bread"] = 2
	world.buildings[inn]["inputs"]["fish"] = 2
	var id: int = world.spawn_worker(Vector2i(8, 8), "gardener", hut)
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 100
	world.set_worker_enabled(id, false)
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return int(worker["meal_ticks_left"]) > 0),
		"A voluntarily paused gardener still walks to an open inn and begins a real meal", failures)
	_check(_until(world, func() -> bool: return int(worker["meal_ticks_left"]) == 0 and int(worker["hunger"]) > 1000)
		and world.trees.is_empty(), "Paused work does not freeze paid feeding or resume planting", failures)
	world.tick = 3750
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(worker)),
		"A paused gardener still sleeps at night in its own hut", failures)
	world.tick = 5999
	_advance(world, 120)
	_check(not world.is_worker_sleeping(worker) and world.is_worker_work_paused(worker)
		and world.trees.is_empty() and world.is_worker_inside(worker),
		"Morning wakes the sleeper but does not silently enable the player's manually paused work", failures)
	world.set_worker_enabled(id, true)
	_check(_until(world, func() -> bool: return not world.trees.is_empty()),
		"Explicit resume after sleep restores actual planting", failures)


static func _test_paused_inn_finishes_only_paid_course(failures: Array[String]) -> void:
	var world := Legacy.create(Vector2i(14, 10))
	var inn: int = world.place_building("inn", Vector2i(5, 3))
	world.buildings[inn]["inputs"]["bread"] = 2
	world.buildings[inn]["inputs"]["fish"] = 2
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier", 0, false, inn)
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 100
	worker["action"] = "eat"
	worker["destination_id"] = inn
	Feeding.arrive(world, worker)
	var paid: Dictionary = world.buildings[inn]["inputs"].duplicate(true)
	world.set_building_enabled(inn, false)
	world.economy_enabled = true
	var guest: int = world.spawn_worker(Vector2i(10, 7), "builder")
	world.workers[guest]["hunger"] = 100
	_advance(world, 125)
	_check(int(worker["meal_ticks_left"]) == 0 and int(worker["hunger"]) > 100
		and world.buildings[inn]["inputs"] == paid and int(world.workers[guest]["meal_ticks_left"]) == 0,
		"A closed inn finishes only the already consumed course and serves neither a second course nor a new guest", failures)
	world.set_building_enabled(inn, true)
	_check(_until(world, func() -> bool: return int(world.workers[guest]["meal_ticks_left"]) > 0),
		"Reopening the same inn allows its waiting hungry civilian to eat", failures)


static func _test_paused_idle_yields(failures: Array[String]) -> void:
	var f: Dictionary = YieldTests._fixture()
	var world: World = f["world"]
	world.set_worker_enabled(f["blocker"], false)
	# Keep the paused homeless civilian here long enough to test yielding,
	# instead of first routing it away to the distant shared warehouse.
	world.workers[f["blocker"]]["_pause_retry_until"] = 500
	var yielded: bool = false
	for _tick: int in range(220):
		world.step_tick()
		yielded = yielded or world.workers[f["blocker"]]["action"] == "yield"
	_check(yielded and world.stored_amount("plank") == 1
		and not bool(world.workers[f["blocker"]]["enabled"]),
		"A paused idle citizen still steps into the side pocket for an active carrier without enabling its own work", failures)


static func _test_market_and_recruitment(failures: Array[String]) -> void:
	var world := Legacy.create(Vector2i(20, 12))
	var market: int = world.place_building("marketplace", Vector2i(3, 3))
	var barracks: int = world.place_building("barracks", Vector2i(13, 3))
	world.queue_trade(market, "log", "stone")
	world.buildings[market]["inputs"]["log"] = 20
	var recruit: int = world.spawn_worker(world.buildings[barracks]["entrance"], "recruit")
	world.queue_recruitment(barracks, "militia")
	world.buildings[barracks]["inputs"]["axe"] = 1
	world.set_building_enabled(market, false)
	world.set_worker_enabled(recruit, false)
	world.economy_enabled = true
	_advance(world, 50)
	_check(world.buildings[market]["service_queue"].size() == 1
		and int(world.buildings[market]["inputs"]["log"]) == 20
		and world.workers[recruit]["type"] == "recruit" and int(world.buildings[barracks]["inputs"]["axe"]) == 1,
		"A disabled marketplace preserves its order and goods; a paused recruit cannot be equipped by an enabled barracks", failures)
	world.set_building_enabled(market, true)
	world.set_worker_enabled(recruit, true)
	_check(_until(world, func() -> bool: return world.buildings[market]["service_queue"].is_empty() and world.workers[recruit]["type"] == "militia"),
		"Resuming the selected marketplace and recruit completes their preserved orders", failures)
