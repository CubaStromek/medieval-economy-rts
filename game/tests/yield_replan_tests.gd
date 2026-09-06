extends RefCounted

const CorridorFixtures = preload("res://tests/corridor_yield_tests.gd")
const TEST_COUNT: int = 3


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_closed_resting_cell_selects_new_pocket(failures)
	_test_new_busy_occupant_selects_new_pocket(failures)
	_test_no_remaining_pocket_releases_stale_retreat(failures)
	return failures


static func _started_retreat(failures: Array[String]) -> Dictionary:
	var fixture: Dictionary = CorridorFixtures._fixture()
	CorridorFixtures._preplan(fixture)
	var world = fixture["world"]
	world.step_tick()
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	_check(blocker["action"] == "yield" and blocker["position"] == Vector2i(5, 5)
		and blocker["target_cell"] == Vector2i(6, 6),
		"Replanning tests must first begin a genuine multi-step retreat toward the original pocket", failures)
	return fixture


static func _test_closed_resting_cell_selects_new_pocket(failures: Array[String]) -> void:
	var fixture: Dictionary = _started_retreat(failures)
	var world = fixture["world"]
	# The originally free target is no longer walkable after the retreat has
	# begun. A different, reachable clearing opens on the opposite side.
	world.grid.set_base_terrain(Vector2i(6, 6), "water")
	world.grid.set_base_terrain(Vector2i(6, 4), "grass")
	_check(_finish_after_replan(fixture, failures),
		"A retreat whose original pocket closes must choose the new safe pocket so the lumberjack can deliver", failures)


static func _test_new_busy_occupant_selects_new_pocket(failures: Array[String]) -> void:
	var fixture: Dictionary = _started_retreat(failures)
	var world = fixture["world"]
	world.grid.set_base_terrain(Vector2i(6, 4), "grass")
	var busy_id: int = world.spawn_worker(Vector2i(6, 6), "builder")
	_check(busy_id != 0, "The dynamic-obstacle fixture must occupy the retreat's distant target", failures)
	if busy_id == 0:
		return
	var busy: Dictionary = world.workers[busy_id]
	busy["state"] = "working"
	busy["action"] = "build_site"
	_check(_finish_after_replan(fixture, failures),
		"An unrelated worker beginning a job in the old pocket must trigger an alternate safe retreat", failures)
	_check(busy["position"] == Vector2i(6, 6) and busy["state"] == "working" and busy["action"] == "build_site",
		"Rerouting a courtesy retreat must never displace or cancel the new busy occupant", failures)


static func _finish_after_replan(fixture: Dictionary, failures: Array[String]) -> bool:
	var world = fixture["world"]
	var cleared: bool = false
	for frame: int in range(220):
		world.step_tick()
		_check(CorridorFixtures._safety(world),
			"Every replanned retreat step must preserve unique tile reservations and building-footprint collisions", failures)
		var blocker: Dictionary = world.workers[fixture["blocker"]]
		cleared = cleared or blocker["position"] == Vector2i(6, 4)
		if int(world.buildings[fixture["hut"]]["outputs"]["log"]) == 1 and cleared:
			_check(int(world.resource_stock("log")["total"]) == 1
				and world.workers[fixture["requester"]]["carrying"] == "",
				"Replanning must preserve and deliver the original log exactly once", failures)
			return true
	return false


static func _test_no_remaining_pocket_releases_stale_retreat(failures: Array[String]) -> void:
	var fixture: Dictionary = _started_retreat(failures)
	var world = fixture["world"]
	for cell: Vector2i in [Vector2i(6, 6), Vector2i(1, 5), Vector2i(2, 5)]:
		world.grid.set_base_terrain(cell, "water")
	# Keep the requester safely waiting on its original tile for this focused
	# recovery check. Advancing it would free a legitimate reverse-rest cell
	# behind the new live route, making the corridor solvable again.
	world.workers[fixture["requester"]]["move_cooldown"] = 200
	for frame: int in range(160):
		world.step_tick()
		_check(CorridorFixtures._safety(world),
			"Losing the final available clearing must leave workers safely separated", failures)
	var blocker: Dictionary = world.workers[fixture["blocker"]]
	_check(blocker["state"] == "idle" and blocker["action"] == "" and (blocker["path"] as Array).is_empty(),
		"An impossible old retreat must release its moving/yield state instead of retrying the dead target forever", failures)
	_check(world._yielding_origins.is_empty() and int(world.resource_stock("log")["total"]) == 1
		and world.workers[fixture["requester"]]["carrying"] == "log",
		"A safely waiting closed corridor must keep its cargo and release completed temporary movement origins", failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
