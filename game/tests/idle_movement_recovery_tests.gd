extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_cancelled_movement_clock_finishes_while_idle(failures)
	_test_cancelled_builder_yields_only_after_landing(failures)
	_test_new_work_waits_for_the_committed_step(failures)
	_test_idle_cooldown_survives_dawn(failures)
	return failures


static func _test_cancelled_movement_clock_finishes_while_idle(failures: Array[String]) -> void:
	var fixture: Dictionary = _cancel_fixture(false, failures)
	if fixture.is_empty():
		return
	var world: Variant = fixture["world"]
	var builder: Dictionary = world.workers[int(fixture["builder"])]
	var position: Vector2i = builder["position"]
	var duration: int = int(builder["visual_duration_ticks"])
	for _tick: int in range(duration + 4):
		world.step_tick()
	_check(builder["state"] == "idle" and builder["position"] == position and int(builder["move_cooldown"]) == 0
		and int(builder["visual_progress_ticks"]) == duration,
		"Cancelling committed movement must finish its remaining clock while idle without taking an extra step", failures)
	_check(world._idle_can_yield(builder), "A released builder must become yieldable after landing even if no new job exists", failures)
	_check(int(world.tile_reservations.get(position, 0)) == int(builder["id"])
		and world.stored_amount("plank") == 4 and world.stored_amount("stone") == 3,
		"Movement recovery must preserve the occupied tile and actual construction refund", failures)


static func _test_cancelled_builder_yields_only_after_landing(failures: Array[String]) -> void:
	for carrier_first: bool in [false, true]:
		var fixture: Dictionary = _cancel_fixture(carrier_first, failures)
		if fixture.is_empty():
			continue
		var world: Variant = fixture["world"]
		var builder: Dictionary = world.workers[int(fixture["builder"])]
		var carrier: Dictionary = world.workers[int(fixture["carrier"])]
		_check((int(carrier["id"]) < int(builder["id"])) == carrier_first,
			"Cancellation-yield regression must exercise both actual worker update orders", failures)
		var origin: Vector2i = builder["position"]
		var destination := Vector2i(3, 4)
		# Isolate execution from route selection: the waiting carrier already
		# has a legal route through the just-cancelled builder's destination.
		var path: Array[Vector2i] = [origin, destination]
		world._begin_worker_move(carrier, path, destination)
		_check(not world._try_yield_idle_worker(carrier, int(builder["id"])),
			"A cancelled builder must not yield before its committed step visibly lands", failures)
		var duration: int = int(builder["visual_duration_ticks"])
		for _tick: int in range(duration - 1):
			world.step_tick()
			_check(builder["position"] == origin and builder["action"] == "",
				"Deferred yielding must not replace unfinished interpolation with a premature sidestep", failures)
		for _tick: int in range(80):
			world.step_tick()
			_check(_outdoor_reservations_valid(world), "Recovered traffic must not overlap or steal another worker's tile", failures)
			if carrier["position"] == destination and carrier["state"] == "idle":
				break
		_check(carrier["position"] == destination and builder["position"] != origin,
			"Once the cancelled step lands, the builder must yield and the carrier must pass in either ID order", failures)
		_check(builder["carrying"] == "" and carrier["carrying"] == "" and int(builder["home_id"]) == 0
			and world.stored_amount("plank") == 4 and world.stored_amount("stone") == 3,
			"Yielding after cancellation must preserve employment, cargo and refunded materials", failures)


static func _test_new_work_waits_for_the_committed_step(failures: Array[String]) -> void:
	var fixture: Dictionary = _cancel_fixture(false, failures)
	if fixture.is_empty():
		return
	var world: Variant = fixture["world"]
	var builder: Dictionary = world.workers[int(fixture["builder"])]
	var replacement: int = world.place_building("sawmill", Vector2i(9, 5))
	if replacement == 0:
		failures.append("The cancelled footprint must accept replacement construction")
		return
	# Re-use the actual refund to author ready work; this case tests when its
	# builder may accept a task, not another carrier material-delivery cycle.
	var store: Dictionary = world.buildings[int(fixture["warehouse"])]["storage"]
	for resource: String in ["plank", "stone"]:
		world.buildings[replacement]["construction_delivered"][resource] = int(store[resource])
		store[resource] = 0
	var position: Vector2i = builder["position"]
	var duration: int = int(builder["visual_duration_ticks"])
	for _tick: int in range(duration - 1):
		world.step_tick()
		_check(builder["position"] == position and builder["state"] == "idle" and int(builder["task_id"]) == 0,
			"Available work must not reset the unfinished step's cooldown or start another movement early", failures)
	for _tick: int in range(240):
		world.step_tick()
		if world.is_building_complete(world.buildings[replacement]):
			break
	_check(world.is_building_complete(world.buildings[replacement]),
		"After landing, the same released builder must accept and finish replacement work", failures)


static func _test_idle_cooldown_survives_dawn(failures: Array[String]) -> void:
	var fixture: Dictionary = _cancel_fixture(false, failures)
	if fixture.is_empty():
		return
	var world: Variant = fixture["world"]
	var builder: Dictionary = world.workers[int(fixture["builder"])]
	var position: Vector2i = builder["position"]
	# Keep the real just-cancelled step across the final nighttime update.
	# Night owns one cooldown tick, and daytime must finish the remaining ones.
	world.tick = 5998
	world.step_tick()
	_check(world.is_night_rest_time() and int(builder["move_cooldown"]) > 0 and builder["state"] == "idle",
		"Dawn fixture must reach the boundary with a genuinely unfinished idle movement", failures)
	for _tick: int in range(12):
		world.step_tick()
	_check(not world.is_night_rest_time() and builder["position"] == position
		and int(builder["move_cooldown"]) == 0 and world._idle_can_yield(builder),
		"Dawn must not strand a visually finished idle civilian with a permanent movement cooldown", failures)


static func _cancel_fixture(carrier_first: bool, failures: Array[String]) -> Dictionary:
	var world = LegacyFixture.create(Vector2i(14, 10))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	world.economy_enabled = true
	var site: int = world.place_building("sawmill", Vector2i(9, 5))
	if warehouse == 0 or site == 0:
		failures.append("Recovery fixture must create a warehouse and a real unfinished sawmill")
		return {}
	world.buildings[site]["construction_delivered"] = {"plank": 4, "stone": 3}
	var carrier: int = 0
	if carrier_first:
		carrier = world.spawn_worker(Vector2i(5, 5), "carrier")
	var builder: int = world.spawn_worker(Vector2i(3, 4), "builder")
	if not carrier_first:
		carrier = world.spawn_worker(Vector2i(5, 5), "carrier")
	if builder == 0 or carrier == 0:
		failures.append("Recovery fixture must create both distinct citizens")
		return {}
	for _tick: int in range(20):
		world.step_tick()
		if int(world.workers[builder]["move_cooldown"]) > 0:
			break
	var worker: Dictionary = world.workers[builder]
	if worker["action"] != "build_site" or worker["state"] != "moving" or int(worker["source_id"]) != site \
			or int(worker["task_id"]) == 0 or worker["position"] != Vector2i(4, 4) \
			or int(worker["move_cooldown"]) <= 0 or int(worker["visual_progress_ticks"]) != 0:
		failures.append("Cancellation must occur during a real committed construction-task step, not an artificial idle timer")
		return {}
	if not world.cancel_construction(site):
		failures.append("Cancelling the in-flight builder's supplied site must succeed")
		return {}
	if worker["state"] != "idle" or int(worker["task_id"]) != 0 or int(worker["move_cooldown"]) <= 0:
		failures.append("Actual cancellation must release the task while preserving its unfinished movement")
		return {}
	return {"world": world, "warehouse": warehouse, "builder": builder, "carrier": carrier}


static func _outdoor_reservations_valid(world: Variant) -> bool:
	var seen: Dictionary = {}
	for id: int in world.workers:
		var worker: Dictionary = world.workers[id]
		if world.is_worker_inside(worker):
			continue
		if seen.has(worker["position"]) or int(world.tile_reservations.get(worker["position"], 0)) != id:
			return false
		seen[worker["position"]] = true
	return true


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
