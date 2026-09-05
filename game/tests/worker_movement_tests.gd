extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_swaps_consume_one_tick(failures)
	_test_swap_waits_in_both_id_orders(failures)
	_test_reroute_after_construction(failures, "plank", "carrier", "warehouse")
	_test_reroute_after_construction(failures, "log", "carrier", "sawmill")
	_test_reroute_after_construction(failures, "log", "lumberjack", "lumber_hut")
	_test_reroute_around_idle_worker(failures)
	return failures


static func _test_swaps_consume_one_tick(failures: Array[String]) -> void:
	for duration: int in [1, 2, 4, 6]:
		for reverse_ids: bool in [false, true]:
			var world := World.new(Vector2i(4, 3))
			world.grid.configure_movement({"terrain": {"grass": {"move_ticks": duration}}})
			var positions: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
			if reverse_ids:
				positions.reverse()
			for cell: Vector2i in positions:
				var id: int = world.spawn_worker(cell)
				_expect(id != 0, "Swap fixture should spawn on configured grass", failures)
				if id == 0:
					return
				world._move_worker_to(world.workers[id], Vector2i(3 if cell.x == 1 else 0, 1))
			world.step_tick()
			for id: int in world.workers:
				var worker: Dictionary = world.workers[id]
				_expect(int(worker["move_cooldown"]) == duration - 1,
					"Both swap participants must retain a full cooldown (duration %d, reversed %s)" % [duration, reverse_ids], failures)
				_expect((worker["position"] as Vector2i).x == 3 - positions[id - 1].x,
					"Each swap participant must move exactly one tile", failures)
			for elapsed: int in range(1, duration):
				world.step_tick()
				for id: int in world.workers:
					var worker: Dictionary = world.workers[id]
					_expect((worker["position"] as Vector2i).x == 3 - positions[id - 1].x,
						"Neither participant may start its next step before the swap duration", failures)
					_expect(int(worker["visual_progress_ticks"]) == elapsed,
						"Both swapped workers must preserve the same interpolation progress", failures)
			world.step_tick()
			for id: int in world.workers:
				var worker: Dictionary = world.workers[id]
				var target_x: int = 3 if positions[id - 1].x == 1 else 0
				_expect(worker["position"] == Vector2i(target_x, 1), "Both workers must resume on the same tick", failures)
				_expect(int(world.tile_reservations.get(worker["position"], 0)) == id, "Swap must preserve reservation ownership", failures)


static func _test_swap_waits_in_both_id_orders(failures: Array[String]) -> void:
	for waiting_id: int in [1, 2]:
		var world := World.new(Vector2i(4, 3))
		for x: int in range(4):
			world.place_road(Vector2i(x, 1))
		var left_id: int = world.spawn_worker(Vector2i(1, 1))
		var right_id: int = world.spawn_worker(Vector2i(2, 1))
		world._move_worker_to(world.workers[left_id], Vector2i(3, 1))
		world._move_worker_to(world.workers[right_id], Vector2i(0, 1))
		world.workers[waiting_id]["move_cooldown"] = 1
		world.step_tick()
		_expect(world.workers[left_id]["position"] == Vector2i(1, 1)
			and world.workers[right_id]["position"] == Vector2i(2, 1),
			"A cooldown consumed this tick must not make a worker eligible for an immediate swap", failures)
		world.step_tick()
		_expect(world.workers[left_id]["position"] == Vector2i(2, 1)
			and world.workers[right_id]["position"] == Vector2i(1, 1),
			"Swap should proceed once both workers were ready at the start of the tick", failures)
		_expect(world.workers[left_id]["move_cooldown"] == 1 and world.workers[right_id]["move_cooldown"] == 1,
			"ID ordering must not shorten either cooldown after a delayed swap", failures)


static func _test_reroute_after_construction(
	failures: Array[String], resource: String, profession: String, destination_type: String
) -> void:
	var world := World.new(Vector2i(8, 4))
	var old_destination: int = world.place_building(destination_type, Vector2i(6, 2))
	var id: int = world.spawn_worker(Vector2i(0, 1), profession, old_destination if profession == "lumberjack" else 0)
	var worker: Dictionary = world.workers[id]
	worker["carrying"] = resource
	world.step_tick()
	_expect(int(worker["destination_id"]) == old_destination, "Fixture must start delivery to the original destination", failures)
	# The specialist's obstruction is cancellable so the test can reopen the
	# route without destroying either completed workplace.
	world.economy_enabled = profession == "lumberjack"
	var crossing_site: int = 0
	for y: int in range(4):
		var site: int = world.place_building("school", Vector2i(3, y))
		_expect(site != 0, "Route obstruction must use valid building commands", failures)
		if y == 1:
			crossing_site = site
	world.economy_enabled = false
	for iteration: int in range(80):
		world.step_tick()
	_expect(worker["carrying"] == resource, "Ware must survive a period with no reachable destination", failures)
	var new_destination: int = world.place_building(destination_type, Vector2i(1, 3))
	_expect(new_destination != 0, "Replacement destination must be legal", failures)
	var expected_destination: int = new_destination
	if profession == "lumberjack":
		for iteration: int in range(200):
			world.step_tick()
		_expect(int(worker["home_id"]) == old_destination and worker["carrying"] == resource,
			"A blocked lumberjack must keep its assigned hut and carried log even when another hut is reachable", failures)
		_expect(int(world.buildings[new_destination]["outputs"][resource]) == 0,
			"A lumberjack must not deliver its log to an unassigned hut", failures)
		_expect(world.cancel_construction(crossing_site), "Cancelling the unfinished crossing must reopen the original route", failures)
		expected_destination = old_destination
	var delivered: bool = false
	for iteration: int in range(200):
		world.step_tick()
		if String(worker["carrying"]).is_empty():
			delivered = true
			break
	_expect(delivered, "%s must resume %s delivery when its valid destination is reachable" % [profession, resource], failures)
	var building: Dictionary = world.buildings[expected_destination]
	var stock: int = 0
	if destination_type == "warehouse":
		stock = int(building["storage"][resource])
	elif destination_type == "sawmill":
		stock = int(building["inputs"][resource])
	else:
		stock = int(building["outputs"][resource])
	_expect(stock == 1, "Rerouting must deliver the carried item exactly once", failures)
	if profession == "lumberjack":
		_expect(int(worker["home_id"]) == old_destination and int(world.buildings[new_destination]["outputs"][resource]) == 0,
			"Reopened access must let the lumberjack resume at its original hut without changing ownership", failures)


static func _test_reroute_around_idle_worker(failures: Array[String]) -> void:
	var world := World.new(Vector2i(8, 8))
	var old_destination: int = world.place_building("warehouse", Vector2i(5, 2))
	var id: int = world.spawn_worker(Vector2i(2, 1))
	var worker: Dictionary = world.workers[id]
	worker["carrying"] = "plank"
	world.step_tick()
	_expect(int(worker["destination_id"]) == old_destination, "Delivery must be underway before the chokepoint is blocked", failures)
	for y: int in range(8):
		if y != 1:
			_expect(world.set_base_terrain(Vector2i(3, y), "water"), "Fixture should close all but one crossing", failures)
	_expect(world.spawn_worker(Vector2i(3, 1)) != 0, "An idle carrier must occupy the remaining crossing", failures)
	# The reachable alternative is farther away, so ignoring the idle worker
	# would repeatedly choose the old warehouse even after this one is built.
	var new_destination: int = world.place_building("warehouse", Vector2i(0, 7))
	for iteration: int in range(200):
		world.step_tick()
	_expect(int(world.buildings[new_destination]["storage"]["plank"]) == 1,
		"Destination selection must consider worker occupancy, not repeatedly select the blocked nearer route", failures)
	_expect(String(worker["carrying"]).is_empty(), "Blocked-path recovery must not duplicate cargo", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
