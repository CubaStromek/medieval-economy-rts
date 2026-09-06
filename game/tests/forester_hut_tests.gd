extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Relief = preload("res://scripts/simulation/relief_demo.gd")
const TEST_COUNT: int = 11


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_homeless_gardener_waits_for_a_hut,
		_test_unfinished_hut_has_no_worker,
		_test_hut_ownership_is_exclusive,
		_test_planting_radius_is_anchored_to_the_hut,
		_test_blocked_target_is_released_and_replaced,
		_test_arrival_rechecks_home,
		_test_arrival_rechecks_planting_radius,
		_test_finish_rechecks_home_and_radius,
		_test_save_preserves_home_and_resumes_local_planting,
		_test_paid_construction_and_school_training,
		_test_authored_demos_house_existing_gardeners,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 160) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _fixture() -> Dictionary:
	var world := LegacyFixture.create(Vector2i(14, 10))
	var hut: int = world.place_building("forester_hut", Vector2i(3, 3))
	var id: int = world.spawn_worker(Vector2i(5, 4), "gardener", hut)
	return {"world": world, "hut": hut, "id": id, "worker": world.workers[id]}


static func _test_homeless_gardener_waits_for_a_hut(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 8))
	var id: int = world.spawn_worker(Vector2i(5, 4), "gardener")
	var worker: Dictionary = world.workers[id]
	_advance(world, 100)
	_check(worker["state"] == "idle" and int(worker["home_id"]) == 0
		and world.trees.is_empty() and world.planting_reservations.is_empty(),
		"A trained gardener without a forester hut must wait without planting or reserving land", failures)
	var hut: int = world.place_building("forester_hut", Vector2i(3, 3))
	_check(_until(world, func() -> bool: return not world.trees.is_empty())
		and int(worker["home_id"]) == hut,
		"Completing a free hut lets the waiting gardener claim it and begin planting", failures)


static func _test_unfinished_hut_has_no_worker(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(10, 8))
	var hut: int = world.place_building("forester_hut", Vector2i(3, 3))
	world.buildings[hut]["construction_remaining"] = 1
	var id: int = world.spawn_worker(Vector2i(5, 4), "gardener")
	_advance(world, 40)
	_check(int(world.workers[id]["home_id"]) == 0 and world.workplace_worker(hut).is_empty()
		and world.trees.is_empty(), "An unfinished forester hut cannot employ a gardener", failures)
	world.buildings[hut]["construction_remaining"] = 0
	world.step_tick()
	_check(int(world.workers[id]["home_id"]) == hut and world.workers[id]["action"] == "plant_sapling",
		"The newly completed hut has exactly one available planting workplace", failures)


static func _test_hut_ownership_is_exclusive(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(16, 10))
	var first_hut: int = world.place_building("forester_hut", Vector2i(3, 3))
	var first: int = world.spawn_worker(Vector2i(4, 5), "gardener")
	var second: int = world.spawn_worker(Vector2i(11, 5), "gardener")
	_check(int(world.workers[first]["home_id"]) == first_hut and int(world.workers[second]["home_id"]) == 0,
		"One forester hut cannot be shared by two gardeners", failures)
	var second_hut: int = world.place_building("forester_hut", Vector2i(11, 3))
	world.step_tick()
	_check(int(world.workers[first]["home_id"]) == first_hut and int(world.workers[second]["home_id"]) == second_hut
		and int(world.workplace_worker(first_hut).get("id", 0)) == first
		and int(world.workplace_worker(second_hut).get("id", 0)) == second,
		"A second hut employs the waiting gardener without changing the first gardener's home", failures)
	_check(world.planting_reservations.size() == 2, "Each employed gardener independently reserves one planting site", failures)
	_advance(world, 160)
	_check(int(world.workers[first]["home_id"]) == first_hut and int(world.workers[second]["home_id"]) == second_hut,
		"Finishing planting and resting never exchange forester workplaces", failures)


static func _test_planting_radius_is_anchored_to_the_hut(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(22, 22))
	var center := Vector2i(10, 10)
	var hut: int = world.place_building("forester_hut", center)
	var id: int = world.spawn_worker(Vector2i(17, 10), "gardener", hut)
	var worker: Dictionary = world.workers[id]
	_check(world.gardener_can_plant(worker, Vector2i(18, 10))
		and world.gardener_can_plant(worker, Vector2i(14, 14)),
		"The default hut accepts cardinal and diagonal cells at exactly Manhattan distance eight", failures)
	_check(not world.gardener_can_plant(worker, Vector2i(18, 11))
		and not world.gardener_can_plant(worker, Vector2i(15, 14)),
		"A gardener standing near the edge cannot extend its planting range away from the hut", failures)
	for _tick: int in range(420):
		world.step_tick()
		if worker["action"] == "plant_sapling":
			var target: Vector2i = worker["plant_target"]
			_check(absi(target.x - center.x) + absi(target.y - center.y) <= 8,
				"Actual target selection stays inside the assigned hut's planting radius", failures)
	_check(world.trees.size() >= 3, "A forester really plants several trees near the range boundary", failures)
	for tree: Dictionary in world.trees.values():
		var cell: Vector2i = tree["position"]
		_check(absi(cell.x - center.x) + absi(cell.y - center.y) <= 8,
			"Every newly planted tree is inside its worker's hut radius", failures)


static func _test_blocked_target_is_released_and_replaced(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	world.step_tick()
	var old_target: Vector2i = worker["plant_target"]
	_check(worker["action"] == "plant_sapling", "Blocked-target fixture must begin a real planting job", failures)
	# Bypass the authoring guard to exercise defensive validation of a cached
	# target after terrain or occupancy becomes invalid.
	world.grid.block(old_target, 901)
	_check(_until(world, func() -> bool: return not world.trees.is_empty()),
		"A blocked forester releases its invalid target and finds another local planting site", failures)
	_check(world._tree_at(old_target) == 0 and not world.planting_reservations.has(old_target)
		and int(worker["home_id"]) == int(fixture["hut"]),
		"The blocked site stays unplanted and unreserved while the forester keeps its hut", failures)


static func _test_arrival_rechecks_home(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	world.step_tick()
	var target: Vector2i = worker["plant_target"]
	world.buildings[int(fixture["hut"])]["construction_remaining"] = 1
	_advance(world, 40)
	_check(world._tree_at(target) == 0 and world.trees.is_empty() and world.planting_reservations.is_empty()
		and worker["action"] == "",
		"Arriving at a formerly valid target cannot start work after the hut becomes unavailable", failures)


static func _test_arrival_rechecks_planting_radius(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	world.step_tick()
	var target: Vector2i = worker["plant_target"]
	world.catalog.buildings["forester_hut"]["planting_radius"] = 0
	_advance(world, 40)
	_check(world._tree_at(target) == 0 and world.planting_reservations.is_empty()
		and int(worker["home_id"]) == int(fixture["hut"]),
		"Arrival rechecks the hut radius and cancels an out-of-range target without giving up ownership", failures)


static func _test_finish_rechecks_home_and_radius(failures: Array[String]) -> void:
	for lose_home: bool in [false, true]:
		var fixture: Dictionary = _fixture()
		var world = fixture["world"]
		var worker: Dictionary = fixture["worker"]
		_check(_until(world, func() -> bool: return worker["state"] == "working"),
			"Finish validation must exercise a gardener already working at its selected site", failures)
		var target: Vector2i = worker["plant_target"]
		if lose_home:
			world.buildings[int(fixture["hut"])]["construction_remaining"] = 1
		else:
			world.catalog.buildings["forester_hut"]["planting_radius"] = 0
		world._finish_planting(worker)
		_check(world._tree_at(target) == 0 and world.planting_reservations.is_empty()
			and worker["state"] == "idle" and int(worker["home_id"]) == int(fixture["hut"]),
			"Finishing cannot plant without a valid home/radius, and resetting a job never rewrites the home", failures)


static func _test_save_preserves_home_and_resumes_local_planting(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	_check(_until(world, func() -> bool: return worker["state"] == "working"),
		"Save fixture must contain a real in-flight planting job", failures)
	var restored := LegacyFixture.create()
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_data()))
	_check(restored.from_data(data), "A save containing an assigned forester and hut can be loaded", failures)
	if not restored.workers.has(int(fixture["id"])):
		return
	var restored_worker: Dictionary = restored.workers[int(fixture["id"])]
	_check(int(restored_worker["home_id"]) == int(fixture["hut"])
		and int(restored.workplace_worker(int(fixture["hut"])).get("id", 0)) == int(fixture["id"]),
		"Save/load keeps both sides of the unique forester-hut ownership", failures)
	_check(_until(restored, func() -> bool: return not restored.trees.is_empty()),
		"The loaded forester resumes local planting after transient tasks are rebuilt", failures)
	for tree: Dictionary in restored.trees.values():
		var center: Vector2i = restored.buildings[int(fixture["hut"])]["position"]
		var cell: Vector2i = tree["position"]
		_check(absi(cell.x - center.x) + absi(cell.y - center.y) <= 8,
			"Planting after loading remains inside the saved hut's work area", failures)


static func _test_authored_demos_house_existing_gardeners(failures: Array[String]) -> void:
	for demo_kind: String in ["legacy", "relief", "economy"]:
		var world := LegacyFixture.create(Relief.MAP_SIZE if demo_kind == "relief" else World.DEFAULT_MAP_SIZE)
		match demo_kind:
			"legacy": world.setup_demo()
			"relief": Relief.setup(world)
			"economy": world.setup_economy_demo()
		var gardeners: int = 0
		for worker: Dictionary in world.workers.values():
			if worker["type"] != "gardener":
				continue
			gardeners += 1
			var hut: int = int(worker["home_id"])
			_check(hut != 0 and world.buildings[hut]["type"] == "forester_hut"
				and world.owns_workplace(worker, hut),
				"The %s authored demo gives its existing gardener one completed forester hut" % demo_kind, failures)
		_check(gardeners == 1, "The %s demo must not accidentally add a second free gardener" % demo_kind, failures)


static func _test_paid_construction_and_school_training(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
	var school: int = world.place_building("school", Vector2i(5, 3))
	world.buildings[warehouse]["storage"]["plank"] = 3
	world.buildings[warehouse]["storage"]["stone"] = 2
	world.buildings[warehouse]["storage"]["gold"] = 1
	world.spawn_worker(Vector2i(3, 5), "carrier")
	world.spawn_worker(Vector2i(4, 5), "builder")
	world.economy_enabled = true
	var hut: int = world.place_building("forester_hut", Vector2i(9, 3))
	_check(hut != 0 and not world.is_building_complete(world.buildings[hut]) and world.workers.size() == 2,
		"Placing a forester hut creates a paid construction site, not a free completed workplace or gardener", failures)
	_check(world.queue_unit_training(school, "gardener"), "A paid school accepts the forester's gardener profession", failures)
	world.step_tick()
	_check(int(world.buildings[school]["training_remaining"]) == 60 and not bool(world.buildings[school]["training_paid"]),
		"Gardener training cannot advance before the carrier physically delivers the gold", failures)
	var observed_payment: bool = false
	var trained_gardener: int = 0
	for _tick: int in range(1500):
		world.step_tick()
		observed_payment = observed_payment or bool(world.buildings[school]["training_paid"])
		for worker: Dictionary in world.workers.values():
			if worker["type"] == "gardener":
				trained_gardener = int(worker["id"])
		if not world.is_building_complete(world.buildings[hut]):
			_check(world.trees.is_empty() and (trained_gardener == 0 or int(world.workers[trained_gardener]["home_id"]) == 0),
				"A school-trained gardener waits until all construction deliveries and builder work are complete", failures)
		if world.is_building_complete(world.buildings[hut]) and not world.trees.is_empty():
			break
	_check(observed_payment and trained_gardener != 0 and world.workers.size() == 3,
		"One delivered gold trains exactly one gardener through the normal school workflow", failures)
	_check(world.is_building_complete(world.buildings[hut])
		and int(world.buildings[hut]["construction_delivered"].get("plank", 0)) == 3
		and int(world.buildings[hut]["construction_delivered"].get("stone", 0)) == 2,
		"Carriers deliver all three planks and two stone before the builder completes the hut", failures)
	_check(world.stored_amount("plank") == 0 and world.stored_amount("stone") == 0
		and int(world.resource_stock("gold")["total"]) == 0,
		"Construction and school training consume the exact supplied material and gold budget", failures)
	_check(trained_gardener != 0 and int(world.workers[trained_gardener]["home_id"]) == hut and not world.trees.is_empty(),
		"The paid, school-trained gardener claims the player's newly built hut and plants a real tree", failures)
