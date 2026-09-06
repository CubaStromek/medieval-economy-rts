extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Supply = preload("res://scripts/simulation/soldier_food_supply.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_night_releases_uncollected_ration,
		_test_carried_ration_waits_until_morning,
		_test_night_meal_with_cargo_survives_save,
		_test_evening_diner_returns_to_own_hut,
		_test_dawn_does_not_interrupt_cargo_meal,
		_test_empty_inn_does_not_start_night_logistics,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _until(world: Variant, condition: Callable, ticks: int = 600) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _ration_fixture() -> Dictionary:
	var world = LegacyFixture.create(Vector2i(20, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
	var carrier: int = world.spawn_worker(Vector2i(2, 9), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(16, 7), "militia")
	world.buildings[warehouse]["storage"]["bread"] = 1
	world.workers[soldier]["hunger"] = 1000
	world.economy_enabled = true
	world.request_soldier_food(soldier)
	return {"world": world, "warehouse": warehouse, "carrier": carrier, "soldier": soldier}


static func _meal_fixture(type: String = "carrier", cargo: String = "log") -> Dictionary:
	var world = LegacyFixture.create(Vector2i(19, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
	var hut: int = world.place_building("lumber_hut", Vector2i(9, 3)) if type == "lumberjack" else 0
	var inn: int = world.place_building("inn", Vector2i(14, 3))
	var worker: int = world.spawn_worker(world.buildings[inn]["entrance"], type, hut)
	world.buildings[inn]["inputs"]["bread"] = 2
	world.workers[worker]["hunger"] = 100
	world.workers[worker]["carrying"] = cargo
	world.economy_enabled = true
	return {"world": world, "warehouse": warehouse, "hut": hut, "inn": inn, "worker": worker}


static func _test_night_releases_uncollected_ration(failures: Array[String]) -> void:
	var f: Dictionary = _ration_fixture()
	var world: Variant = f["world"]
	var carrier: Dictionary = world.workers[f["carrier"]]
	world.tick = 3748
	world.step_tick()
	_check(carrier["ration_delivery"].get("phase", "") == "pickup"
		and Supply.source_reserved(world, f["warehouse"], "bread") == 1,
		"The evening fixture must contain a real uncollected military ration reservation", failures)
	world.step_tick()
	_check((carrier["ration_delivery"] as Dictionary).is_empty()
		and Supply.source_reserved(world, f["warehouse"], "bread") == 0,
		"20:00 must release the carrier's uncollected military ration reservation", failures)
	_check(carrier["carrying"] == "" and world.stored_amount("bread") == 1
		and bool(world.workers[f["soldier"]]["food_requested"]),
		"Night cancellation must leave the uncollected food in storage and keep the soldier's request pending", failures)
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(carrier)),
		"A carrier whose ration pickup was cancelled must physically return to sleep", failures)
	_advance(world, 80)
	_check(int(carrier["inside_building_id"]) == int(f["warehouse"])
		and (carrier["ration_delivery"] as Dictionary).is_empty() and world.stored_amount("bread") == 1,
		"A sleeping carrier must not reserve or collect the waiting ration again during the night", failures)


static func _test_carried_ration_waits_until_morning(failures: Array[String]) -> void:
	var f: Dictionary = _ration_fixture()
	var world: Variant = f["world"]
	var carrier: Dictionary = world.workers[f["carrier"]]
	var soldier: Dictionary = world.workers[f["soldier"]]
	if not _until(world, func() -> bool: return carrier["carrying"] == "bread"):
		failures.append("The night ration fixture must first physically collect one serving")
		return
	world.tick = 3749
	world.step_tick()
	_check((carrier["ration_delivery"] as Dictionary).is_empty() and carrier["carrying"] == "bread"
		and world.stored_amount("bread") == 0 and int(world.resource_stock("bread")["total"]) == 1,
		"Night must cancel an in-flight ration without losing, refunding or duplicating its physical cargo", failures)
	# The supply updater runs before individual NPC updates. A moving recipient
	# must not make it override the carrier's new route home during the night.
	world._release_worker_tile(soldier)
	soldier["position"] = Vector2i(17, 2)
	soldier["previous_position"] = soldier["position"]
	world.tile_reservations[soldier["position"]] = int(soldier["id"])
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(carrier)),
		"A ration carrier must reach its warehouse even when the former recipient moves", failures)
	_advance(world, 60)
	_check(int(carrier["inside_building_id"]) == int(f["warehouse"])
		and carrier["carrying"] == "bread" and bool(soldier["food_requested"])
		and int(soldier["hunger"]) < 1100 and int(world.resource_stock("bread")["total"]) == 1,
		"The sleeping carrier must retain its ration until dawn without feeding a distant soldier", failures)
	world.tick = 5999
	world.step_tick()
	_check(_until(world, func() -> bool: return not bool(soldier["food_requested"]), 1200),
		"Morning logistics must eventually satisfy the soldier's pending order without another player click", failures)
	_check(int(world.resource_stock("bread")["total"]) == 0 and int(soldier["hunger"]) > 2600,
		"The ration retained overnight must be delivered and consumed exactly once after dawn", failures)


static func _test_night_meal_with_cargo_survives_save(failures: Array[String]) -> void:
	var f: Dictionary = _meal_fixture()
	var world: Variant = f["world"]
	var id: int = int(f["worker"])
	world.tick = 3800
	if not _until(world, func() -> bool: return int(world.workers[id]["meal_ticks_left"]) > 0, 60):
		failures.append("A hungry carrier must be allowed to start a night meal while keeping its log")
		return
	_advance(world, 20)
	var before: Dictionary = world.workers[id]
	var remaining: int = int(before["meal_ticks_left"])
	var hunger: int = int(before["hunger"])
	var course: Dictionary = (before["meal_course"] as Dictionary).duplicate(true)
	var restored = LegacyFixture.create()
	if not restored.from_data(JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary):
		failures.append("A genuine night meal with physical cargo must survive JSON save/load")
		return
	var carrier: Dictionary = restored.workers[id]
	_check(int(carrier["meal_ticks_left"]) == remaining and int(carrier["hunger"]) == hunger
		and carrier["meal_course"] == course and carrier["carrying"] == "log"
		and restored.inn_occupied_seats(f["inn"]) == 1,
		"Loading a night cargo meal must retain the same course, nutrition, seat, countdown and log", failures)
	_check(_until(restored, func() -> bool: return restored.is_worker_sleeping(carrier)),
		"After its saved night meal a carrier must leave the inn and reach its sleeping place", failures)
	_check(int(carrier["inside_building_id"]) == int(f["warehouse"])
		and carrier["carrying"] == "log" and restored.inn_occupied_seats(f["inn"]) == 0
		and int(restored.buildings[f["inn"]]["inputs"]["bread"]) == 1
		and int(restored.resource_stock("log")["total"]) == 1 and restored.stored_amount("log") == 0,
		"Finishing a saved night meal must consume one serving, preserve cargo and sleep in the warehouse rather than the inn", failures)


static func _test_evening_diner_returns_to_own_hut(failures: Array[String]) -> void:
	var f: Dictionary = _meal_fixture("lumberjack", "")
	var world: Variant = f["world"]
	var worker: Dictionary = world.workers[f["worker"]]
	world.tick = 3748
	world.step_tick()
	var remaining: int = int(worker["meal_ticks_left"])
	_check(remaining > 0 and int(worker["inside_building_id"]) == int(f["inn"]),
		"The specialist fixture must start its meal before the 20:00 work boundary", failures)
	world.step_tick()
	_check(int(worker["meal_ticks_left"]) == remaining - 1 and worker["action"] == "eat",
		"20:00 must let an already seated specialist finish its current meal", failures)
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(worker)),
		"The evening diner must leave the inn and travel to its own hut after eating", failures)
	_check(int(worker["inside_building_id"]) == int(f["hut"])
		and int(worker["home_id"]) == int(f["hut"]) and world.owns_workplace(worker, f["hut"])
		and world.inn_occupied_seats(f["inn"]) == 0,
		"A specialist must sleep in its assigned hut while retaining exclusive workplace ownership", failures)


static func _test_dawn_does_not_interrupt_cargo_meal(failures: Array[String]) -> void:
	var f: Dictionary = _meal_fixture()
	var world: Variant = f["world"]
	var carrier: Dictionary = world.workers[f["worker"]]
	world.tick = 5998
	world.step_tick()
	var remaining: int = int(carrier["meal_ticks_left"])
	var hunger: int = int(carrier["hunger"])
	_check(remaining > 0 and carrier["carrying"] == "log",
		"A carrier with cargo must be able to sit down for a meal immediately before 05:00", failures)
	world.step_tick()
	_check(int(carrier["meal_ticks_left"]) == remaining - 1 and int(carrier["hunger"]) > hunger
		and carrier["action"] == "eat" and carrier["carrying"] == "log"
		and int(carrier["inside_building_id"]) == int(f["inn"]),
		"Dawn must continue a night cargo meal without resetting its nutrition, interrupting its seat or starting delivery early", failures)
	_check(_until(world, func() -> bool: return carrier["carrying"] == ""),
		"After finishing its dawn meal the carrier must physically resume the retained delivery", failures)
	_check(world.stored_amount("log") == 1 and int(world.resource_stock("log")["total"]) == 1
		and int(world.buildings[f["inn"]]["inputs"]["bread"]) == 1 and world.inn_occupied_seats(f["inn"]) == 0,
		"The dawn transition must result in one completed log delivery and one consumed serving", failures)


static func _test_empty_inn_does_not_start_night_logistics(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(19, 12))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
	var sawmill: int = world.place_building("sawmill", Vector2i(9, 3))
	var inn: int = world.place_building("inn", Vector2i(14, 3))
	var id: int = world.spawn_worker(Vector2i(5, 8), "carrier")
	var carrier: Dictionary = world.workers[id]
	carrier["carrying"] = "log"
	carrier["hunger"] = 250
	world.economy_enabled = true
	world.tick = 3750
	_check(_until(world, func() -> bool: return world.is_worker_sleeping(carrier)),
		"An empty inn must not prevent a hungry carrier from reaching its night shelter", failures)
	_advance(world, 100)
	_check(int(carrier["inside_building_id"]) == warehouse and carrier["carrying"] == "log"
		and int(world.buildings[sawmill]["inputs"]["log"]) == 0 and world.inn_occupied_seats(inn) == 0,
		"Failed night meal searches must not release the cargo into ordinary production logistics", failures)
	world.tick = 5999
	world.step_tick()
	_check(_until(world, func() -> bool: return int(world.buildings[sawmill]["inputs"]["log"]) == 1),
		"With the inn still empty, dawn must let the hungry carrier resume the log delivery", failures)
	_check(carrier["carrying"] == "" and int(world.resource_stock("log")["total"]) == 1,
		"Resuming a delivery after failed night meals must conserve the single physical log", failures)
