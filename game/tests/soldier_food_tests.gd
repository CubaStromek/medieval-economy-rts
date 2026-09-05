extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Supply = preload("res://scripts/simulation/soldier_food_supply.gd")
const TEST_COUNT: int = 14


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_manual_threshold, _test_physical_delivery, _test_all_food_types,
		_test_single_reservations, _test_inn_is_not_a_source,
		_test_producer_source, _test_moving_soldier,
		_test_dead_recipient_preserves_cargo, _test_source_removed_before_pickup,
		_test_carried_save_and_resume,
		_test_source_removed_after_pickup, _test_blocked_handoff_preserves_cargo,
		_test_pending_request_save, _test_pickup_reservation_save,
	]:
		test.call(failures)
	return failures


static func _fixture(ware: String = "bread", amount: int = 1) -> Dictionary:
	var world = World.new(Vector2i(20, 12))
	var source: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[source]["storage"][ware] = amount
	var soldier: int = world.spawn_worker(Vector2i(16, 7), "militia")
	var carrier: int = world.spawn_worker(Vector2i(2, 9), "carrier")
	world.workers[soldier]["hunger"] = 1000
	world.economy_enabled = true
	return {"world": world, "source": source, "soldier": soldier, "carrier": carrier}


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _until(world: Variant, condition: Callable, ticks: int = 1600) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _mission_count(world: Variant) -> int:
	var result: int = 0
	for worker: Dictionary in world.workers.values():
		if not (worker.get("ration_delivery", {}) as Dictionary).is_empty():
			result += 1
	return result


static func _food_total(world: Variant, ware: String) -> int:
	var result: int = 0
	for building: Dictionary in world.buildings.values():
		for field: String in ["storage", "inputs", "outputs"]:
			result += int((building[field] as Dictionary).get(ware, 0))
	for worker: Dictionary in world.workers.values():
		if worker["carrying"] == ware:
			result += 1
	return result


static func _test_manual_threshold(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	for _tick: int in range(100):
		world.step_tick()
	_check(_mission_count(world) == 0 and _food_total(world, "bread") == 1,
		"Hungry soldiers must not silently request food", failures)
	world.workers[f["soldier"]]["hunger"] = 1485
	_check(not Supply.request_food(world, f["soldier"]), "Exactly 55 percent must reject a food order", failures)
	world.workers[f["soldier"]]["hunger"] = 1484
	_check(Supply.request_food(world, f["soldier"]), "Below 55 percent must accept a food order", failures)
	_check(not Supply.request_food(world, f["soldier"]), "A pending food order must reject duplicate clicks", failures)
	_check(not Supply.request_food(world, f["carrier"]), "Civilian carriers must not accept a military food order", failures)


static func _test_physical_delivery(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	world.step_tick()
	_check(int(world.buildings[f["source"]]["storage"]["bread"]) == 1 and int(world.workers[f["soldier"]]["hunger"]) == 1000,
		"Ordering must reserve food without teleporting stock or feeding a distant soldier", failures)
	_check(_until(world, func() -> bool: return world.workers[f["carrier"]]["carrying"] == "bread"),
		"A carrier must physically pick up a military ration", failures)
	_check(_food_total(world, "bread") == 1 and int(world.workers[f["soldier"]]["hunger"]) < 1100,
		"Picked-up food remains cargo until the soldier is reached", failures)
	_check(_until(world, func() -> bool: return not bool(world.workers[f["soldier"]].get("food_requested", false))),
		"The carrier must complete the requested food delivery", failures)
	_check(int(world.workers[f["soldier"]]["hunger"]) == 2700 and _food_total(world, "bread") == 0,
		"One ration must feed to full and be consumed exactly once", failures)
	_check(world.workers[f["carrier"]]["position"] != world.workers[f["soldier"]]["position"],
		"Food handoff must not place the carrier on the soldier's tile", failures)


static func _test_all_food_types(failures: Array[String]) -> void:
	for ware: String in ["bread", "sausage", "wine", "fish"]:
		var f: Dictionary = _fixture(ware)
		var world: Variant = f["world"]
		Supply.request_food(world, f["soldier"])
		_check(_until(world, func() -> bool: return int(world.workers[f["soldier"]]["hunger"]) == 2700),
			"One %s must fully feed a soldier regardless of civilian nutrition" % ware, failures)
		_check(_food_total(world, ware) == 0, "Military %s ration must be consumed once" % ware, failures)


static func _test_single_reservations(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	var second: int = world.spawn_worker(Vector2i(17, 9), "bowman")
	world.workers[second]["hunger"] = 1000
	for x: int in [4, 6, 8]:
		world.spawn_worker(Vector2i(x, 10), "carrier")
	Supply.request_food(world, f["soldier"])
	Supply.request_food(world, second)
	world.step_tick()
	_check(_mission_count(world) == 1 and Supply.source_reserved(world, f["source"], "bread") == 1,
		"One available portion must reserve exactly one carrier and recipient", failures)
	_check(_until(world, func() -> bool: return _food_total(world, "bread") == 0), "The reserved portion must be delivered", failures)
	var fed: int = 0
	for id: int in [int(f["soldier"]), second]:
		if int(world.workers[id]["hunger"]) == 2700:
			fed += 1
	_check(fed == 1, "Competing soldiers must not duplicate a single ration", failures)


static func _test_inn_is_not_a_source(failures: Array[String]) -> void:
	var f: Dictionary = _fixture("bread", 0)
	var world: Variant = f["world"]
	world.economy_enabled = false
	var inn: int = world.place_building("inn", Vector2i(10, 3))
	world.economy_enabled = true
	world.buildings[inn]["inputs"]["bread"] = 3
	Supply.request_food(world, f["soldier"])
	for _tick: int in range(150):
		world.step_tick()
	_check(_mission_count(world) == 0 and int(world.buildings[inn]["inputs"]["bread"]) == 3,
		"Army supply must preserve the inn's civilian food stock", failures)
	_check(bool(world.workers[f["soldier"]]["food_requested"]), "A food order waits when no army supply exists", failures)


static func _test_producer_source(failures: Array[String]) -> void:
	var f: Dictionary = _fixture("wine", 0)
	var world: Variant = f["world"]
	world.economy_enabled = false
	var vineyard: int = world.place_building("vineyard", Vector2i(7, 3))
	world.economy_enabled = true
	world.buildings[vineyard]["outputs"]["wine"] = 1
	Supply.request_food(world, f["soldier"])
	world.step_tick()
	_check(int(world.workers[f["carrier"]].get("ration_delivery", {}).get("source_id", 0)) == vineyard,
		"Military food can be collected directly from a producer's output", failures)
	_check(_until(world, func() -> bool: return int(world.workers[f["soldier"]]["hunger"]) == 2700),
		"Producer food must physically reach the requested soldier", failures)
	_check(_food_total(world, "wine") == 0, "Direct production supply must not duplicate its ration", failures)


static func _test_moving_soldier(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	_check(_until(world, func() -> bool: return world.workers[f["carrier"]]["carrying"] == "bread"), "Moving-target fixture must reach pickup", failures)
	var soldier: Dictionary = world.workers[f["soldier"]]
	world._release_worker_tile(soldier)
	soldier["position"] = Vector2i(17, 2)
	soldier["previous_position"] = soldier["position"]
	world.tile_reservations[soldier["position"]] = int(soldier["id"])
	_check(_until(world, func() -> bool: return int(soldier["hunger"]) == 2700),
		"The carrier must follow a soldier who moved after pickup", failures)
	var delta: Vector2i = world.workers[f["carrier"]]["position"] - soldier["position"]
	_check(maxi(absi(delta.x), absi(delta.y)) == 1, "Food must be handed off beside the soldier's new position", failures)


static func _test_dead_recipient_preserves_cargo(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	_check(_until(world, func() -> bool: return world.workers[f["carrier"]]["carrying"] == "bread"), "Dead-recipient fixture must reach pickup", failures)
	world._release_worker_tile(world.workers[f["soldier"]])
	world.workers.erase(f["soldier"])
	Supply.tick(world)
	_check(_mission_count(world) == 0 and _food_total(world, "bread") == 1,
		"A dead recipient must release its mission without losing or refunding cargo", failures)
	_check(_until(world, func() -> bool: return int(world.buildings[f["source"]]["storage"]["bread"]) == 1),
		"Ordinary logistics must physically return the orphaned food to storage", failures)


static func _test_source_removed_before_pickup(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	world.step_tick()
	world.buildings.erase(f["source"])
	Supply.tick(world)
	_check(_mission_count(world) == 0 and world.workers[f["carrier"]]["carrying"] == "",
		"A source removed before pickup must release its reservation without creating cargo", failures)
	_check(bool(world.workers[f["soldier"]]["food_requested"]), "Source loss preserves the soldier's pending request", failures)


static func _test_carried_save_and_resume(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	_check(_until(world, func() -> bool: return world.workers[f["carrier"]]["carrying"] == "bread"), "Save fixture must reach pickup", failures)
	var before: int = int(world.workers[f["soldier"]]["hunger"])
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_data()))
	_check(world.from_data(data), "An in-flight ration must survive JSON save/load", failures)
	_check(_food_total(world, "bread") == 1 and int(world.workers[f["soldier"]]["hunger"]) == before,
		"Loading an in-flight ration must neither consume it nor feed its recipient", failures)
	_check(_until(world, func() -> bool: return int(world.workers[f["soldier"]]["hunger"]) == 2700),
		"The restored carrier must finish its military food delivery", failures)
	_check(_food_total(world, "bread") == 0, "A saved military ration must be consumed exactly once", failures)


static func _test_source_removed_after_pickup(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	_check(_until(world, func() -> bool: return world.workers[f["carrier"]]["carrying"] == "bread"), "Removed-source fixture must reach pickup", failures)
	world.buildings.erase(f["source"])
	Supply.tick(world)
	_check(_mission_count(world) == 1 and _food_total(world, "bread") == 1,
		"Removing a source after pickup must preserve the physical ration mission", failures)
	_check(_until(world, func() -> bool: return int(world.workers[f["soldier"]]["hunger"]) == 2700),
		"An already carried ration must reach the soldier after its source disappears", failures)


static func _test_blocked_handoff_preserves_cargo(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	_check(_until(world, func() -> bool: return world.workers[f["carrier"]]["carrying"] == "bread"), "Blocked-handoff fixture must reach pickup", failures)
	var soldier_position: Vector2i = world.workers[f["soldier"]]["position"]
	for offset: Vector2i in Supply.NEIGHBORS:
		world.grid.set_base_terrain(soldier_position + offset, "water")
	Supply.reconsider_blocked(world, world.workers[f["carrier"]])
	_check(_mission_count(world) == 0 and _food_total(world, "bread") == 1,
		"An unreachable handoff must release its reservation while retaining cargo", failures)
	_check(_until(world, func() -> bool: return int(world.buildings[f["source"]]["storage"]["bread"]) == 1),
		"Food for an unreachable soldier must travel back through normal logistics", failures)
	_check(bool(world.workers[f["soldier"]]["food_requested"]) and int(world.workers[f["soldier"]]["hunger"]) < 1100,
		"An unreachable soldier stays hungry with a pending request", failures)


static func _test_pending_request_save(failures: Array[String]) -> void:
	var f: Dictionary = _fixture("bread", 0)
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_data()))
	_check(world.from_data(data) and bool(world.workers[f["soldier"]].get("food_requested", false)),
		"A military food request must survive saving without available food", failures)
	world.buildings[f["source"]]["storage"]["bread"] = 1
	_check(_until(world, func() -> bool: return int(world.workers[f["soldier"]]["hunger"]) == 2700),
		"A restored pending request must start when food becomes available", failures)


static func _test_pickup_reservation_save(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: Variant = f["world"]
	Supply.request_food(world, f["soldier"])
	world.step_tick()
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_data()))
	_check(world.from_data(data), "A ration reservation must survive saving before pickup", failures)
	_check(Supply.source_reserved(world, f["source"], "bread") == 1 and int(world.buildings[f["source"]]["storage"]["bread"]) == 1,
		"Loading a pickup reservation must keep exactly one reservation and untouched source stock", failures)
	_check(_until(world, func() -> bool: return int(world.workers[f["soldier"]]["hunger"]) == 2700),
		"A restored pickup reservation must finish the physical delivery", failures)
	_check(_food_total(world, "bread") == 0, "A restored pickup reservation must consume one ration", failures)
