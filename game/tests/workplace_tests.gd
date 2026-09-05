extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Jobs = preload("res://scripts/simulation/workplaces.gd")
const TEST_COUNT: int = 20


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_one_hut_one_lumberjack,
		_test_free_huts_are_claimed_once,
		_test_shared_professions_keep_distinct_workplaces,
		_test_unemployed_specialist_cannot_work,
		_test_newly_completed_building_hires_waiting_worker,
		_test_obstructed_home_stays_owned,
		_test_full_home_stays_owned,
		_test_meal_preserves_ownership,
		_test_starvation_releases_the_vacancy,
		_test_explicit_claims_are_atomic,
		_test_transient_blockers_do_not_change_employment,
		_test_lumberjacks_deliver_to_their_own_huts,
		_test_one_baker_cannot_run_two_buildings,
		_test_communal_workers_do_not_claim_buildings,
		_test_carried_ware_limits_new_workplace,
		_test_failed_search_is_cached_despite_surface_traffic,
		_test_new_vacancies_wake_failed_searches,
		_test_connectivity_changes_invalidate_failed_searches,
		_test_failed_search_tracks_position_cargo_and_grid,
		_test_equal_cost_chooses_lowest_building_id,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 800) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _home(world: Variant, worker_id: int) -> int:
	return int((world.workers.get(worker_id, {}) as Dictionary).get("home_id", 0))


static func _test_one_hut_one_lumberjack(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 2))
	var first: int = world.spawn_worker(Vector2i(2, 4), "lumberjack")
	var second: int = world.spawn_worker(Vector2i(6, 4), "lumberjack")
	_check(first != 0 and second != 0, "Excess trained lumberjacks must remain living unemployed citizens", failures)
	_check(_home(world, first) == hut and _home(world, second) == 0, "One hut must claim exactly one lumberjack", failures)
	_check(int(Jobs.occupant(world, hut).get("id", 0)) == first, "The hut must expose the same unique owner as its worker", failures)
	_advance(world, 100)
	_check(_home(world, first) == hut and _home(world, second) == 0, "Idle workers must not rotate through an already occupied hut", failures)


static func _test_free_huts_are_claimed_once(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 8))
	var first_hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var second_hut: int = world.place_building("lumber_hut", Vector2i(10, 2))
	var first: int = world.spawn_worker(Vector2i(1, 4), "lumberjack")
	var second: int = world.spawn_worker(Vector2i(2, 4), "lumberjack")
	var third: int = world.spawn_worker(Vector2i(9, 4), "lumberjack")
	_check(_home(world, first) == first_hut and _home(world, second) == second_hut and _home(world, third) == 0,
		"Two free huts must fill by reachable travel cost, leaving the third lumberjack unemployed", failures)
	_check(not Jobs.claim(world, world.workers[first], second_hut), "An employed lumberjack cannot take another hut", failures)


static func _test_shared_professions_keep_distinct_workplaces(failures: Array[String]) -> void:
	for entry: Array in [
		["baker", "mill", "bakery"], ["farmer", "farm", "vineyard"],
		["carpenter", "sawmill", "weapon_workshop"], ["metallurgist", "iron_smithy", "metallurgist"],
		["butcher", "butcher", "tannery"], ["animal_breeder", "swine_farm", "stables"],
		["smith", "weapon_smithy", "armour_smithy"],
	]:
		var world = World.new(Vector2i(14, 8))
		var first_home: int = world.place_building(String(entry[1]), Vector2i(2, 2))
		var second_home: int = world.place_building(String(entry[2]), Vector2i(10, 2))
		var first: int = world.spawn_worker(Vector2i(2, 4), String(entry[0]))
		var second: int = world.spawn_worker(Vector2i(10, 4), String(entry[0]))
		_check(_home(world, first) == first_home and _home(world, second) == second_home,
			"Each %s must claim one distinct building despite sharing a profession" % entry[0], failures)
		_advance(world, 25)
		_check(_home(world, first) == first_home and _home(world, second) == second_home,
			"Empty inputs or missing fields must not exchange %s workplaces" % entry[0], failures)


static func _test_unemployed_specialist_cannot_work(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var tree: int = world.add_tree(Vector2i(6, 3), 2)
	var lumberjack: int = world.spawn_worker(Vector2i(5, 3), "lumberjack")
	_advance(world, 150)
	_check(_home(world, lumberjack) == 0 and int(world.trees[tree]["amount"]) == 2,
		"A lumberjack without a hut must wait without cutting or creating wares", failures)
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	_check(_until(world, func() -> bool: return _home(world, lumberjack) == hut, 20),
		"An unemployed specialist must notice a newly available matching workplace", failures)


static func _test_newly_completed_building_hires_waiting_worker(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 2))
	world.buildings[hut]["construction_remaining"] = 1
	var worker: int = world.spawn_worker(Vector2i(2, 4), "lumberjack")
	_check(_home(world, worker) == 0 and Jobs.occupant(world, hut).is_empty(),
		"An unfinished building must not claim a production specialist", failures)
	world.buildings[hut]["construction_remaining"] = 0
	world.step_tick()
	_check(_home(world, worker) == hut, "Completing a building must make its one workplace available", failures)


static func _test_obstructed_home_stays_owned(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var old_hut: int = world.place_building("lumber_hut", Vector2i(9, 2))
	var worker: int = world.spawn_worker(Vector2i(1, 4), "lumberjack", old_hut)
	world.workers[worker]["carrying"] = "log"
	for y: int in range(8):
		world.grid.set_base_terrain(Vector2i(5, y), "water")
	var free_hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	_advance(world, 100)
	_check(_home(world, worker) == old_hut and Jobs.occupant(world, free_hut).is_empty(),
		"Even a permanently obstructed route must not silently exchange a worker's home", failures)
	_check(world.workers[worker]["carrying"] == "log", "Waiting for the owned hut must retain the carried log", failures)


static func _test_full_home_stays_owned(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var full_hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var free_hut: int = world.place_building("lumber_hut", Vector2i(9, 2))
	var worker: int = world.spawn_worker(Vector2i(2, 4), "lumberjack", full_hut)
	world.buildings[full_hut]["outputs"]["log"] = int(world.catalog.building("lumber_hut")["output_capacity"])
	world.workers[worker]["carrying"] = "log"
	_advance(world, 80)
	_check(_home(world, worker) == full_hut and world.workers[worker]["carrying"] == "log",
		"A full home must preserve employment and the undelivered ware", failures)
	_check(int(world.buildings[free_hut]["outputs"]["log"]) == 0,
		"A specialist must not deliver to another compatible producer to evade backpressure", failures)


static func _test_meal_preserves_ownership(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var inn: int = world.place_building("inn", Vector2i(6, 2))
	var owner: int = world.spawn_worker(Vector2i(3, 4), "lumberjack", hut)
	var waiting: int = world.spawn_worker(Vector2i(9, 4), "lumberjack")
	world.buildings[inn]["inputs"]["bread"] = 1
	world.workers[owner]["hunger"] = int(world.catalog.economy["condition_hungry"])
	world.economy_enabled = true
	_check(_until(world, func() -> bool: return int(world.buildings[inn]["inputs"]["bread"]) == 0, 300),
		"The assigned worker must still be able to visit the communal inn", failures)
	_check(_home(world, owner) == hut and _home(world, waiting) == 0,
		"A trip to the inn must not make the worker's hut available to someone else", failures)


static func _test_starvation_releases_the_vacancy(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var owner: int = world.spawn_worker(Vector2i(3, 4), "lumberjack", hut)
	var waiting: int = world.spawn_worker(Vector2i(8, 4), "lumberjack")
	world.workers[owner]["hunger"] = 1
	world.economy_enabled = true
	_advance(world, int(world.catalog.economy["condition_interval_ticks"]) + 1)
	_check(not world.workers.has(owner) and _home(world, waiting) == hut,
		"A worker's death must free its workplace for the next unemployed specialist", failures)
	_check(int(Jobs.occupant(world, hut).get("id", 0)) == waiting,
		"Reverse ownership must not retain a stale dead-worker reservation", failures)


static func _test_explicit_claims_are_atomic(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var other_hut: int = world.place_building("lumber_hut", Vector2i(10, 2))
	var owner: int = world.spawn_worker(Vector2i(2, 4), "lumberjack", hut)
	_check(world.spawn_worker(Vector2i(4, 4), "lumberjack", hut) == 0,
		"An explicit request for an occupied workplace must fail without spawning a second owner", failures)
	_check(world.spawn_worker(Vector2i(5, 4), "baker", hut) == 0,
		"Explicit assignment must reject a mismatched profession", failures)
	_check(world.spawn_worker(Vector2i(6, 4), "lumberjack", 9999) == 0,
		"Explicit assignment must reject an absent workplace", failures)
	_check(not Jobs.claim(world, world.workers[owner], other_hut) and _home(world, owner) == hut,
		"A rejected second claim must leave the original assignment unchanged", failures)
	world.buildings[other_hut]["construction_remaining"] = 1
	_check(world.spawn_worker(Vector2i(7, 4), "lumberjack", other_hut) == 0,
		"Explicit assignment must reject an unfinished workplace", failures)
	_check(world.workers.size() == 1, "Rejected explicit assignments must not leave phantom workers behind", failures)


static func _test_transient_blockers_do_not_change_employment(failures: Array[String]) -> void:
	var world = World.new(Vector2i(12, 8))
	var near_hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	world.place_building("lumber_hut", Vector2i(9, 2))
	world.spawn_worker(world.buildings[near_hut]["entrance"], "carrier")
	var specialist: int = world.spawn_worker(Vector2i(2, 4), "lumberjack")
	_check(_home(world, specialist) == near_hut,
		"A carrier standing at the nearest hut entrance must not redirect employment elsewhere", failures)
	_check(Jobs.occupant(world, near_hut).get("type", "") == "lumberjack",
		"Communal visitors must not occupy a specialist's workplace slot", failures)


static func _test_lumberjacks_deliver_to_their_own_huts(failures: Array[String]) -> void:
	var world = World.new(Vector2i(16, 9))
	var first_hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	var second_hut: int = world.place_building("lumber_hut", Vector2i(12, 2))
	world.add_tree(Vector2i(3, 5), 1)
	world.add_tree(Vector2i(13, 5), 1)
	var first: int = world.spawn_worker(Vector2i(2, 5), "lumberjack", first_hut)
	var second: int = world.spawn_worker(Vector2i(12, 5), "lumberjack", second_hut)
	_check(_until(world, func() -> bool:
		return int(world.buildings[first_hut]["outputs"]["log"]) == 1 and int(world.buildings[second_hut]["outputs"]["log"]) == 1),
		"Two assigned lumberjacks must each harvest and deliver to their own hut", failures)
	_check(_home(world, first) == first_hut and _home(world, second) == second_hut,
		"Completing harvest and delivery must preserve both one-to-one assignments", failures)
	_check(world.pipeline_amount("log") == 2 and world.trees.is_empty(), "The independent hut cycles must conserve both finite logs", failures)


static func _test_one_baker_cannot_run_two_buildings(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 8))
	var mill: int = world.place_building("mill", Vector2i(2, 2))
	var bakery: int = world.place_building("bakery", Vector2i(10, 2))
	world.buildings[mill]["inputs"]["grain"] = 1
	world.buildings[bakery]["inputs"]["flour"] = 1
	var first: int = world.spawn_worker(Vector2i(2, 4), "baker", mill)
	world.economy_enabled = true
	_advance(world, 250)
	_check(int(world.buildings[mill]["outputs"]["flour"]) == 1, "The mill's assigned baker must complete its batch", failures)
	_check(int(world.buildings[bakery]["inputs"]["flour"]) == 1 and int(world.buildings[bakery]["outputs"]["bread"]) == 0,
		"Finishing one batch must not let the mill's baker operate an unstaffed bakery", failures)
	var second: int = world.spawn_worker(Vector2i(10, 4), "baker")
	_advance(world, 250)
	_check(_home(world, first) == mill and _home(world, second) == bakery and int(world.buildings[bakery]["outputs"]["bread"]) == 2,
		"A second baker must permanently staff the bakery and finish its independent batch", failures)


static func _test_communal_workers_do_not_claim_buildings(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 8))
	var hut: int = world.place_building("lumber_hut", Vector2i(2, 2))
	world.place_building("warehouse", Vector2i(7, 2))
	for index: int in range(2):
		var role: String = ["carrier", "builder"][index]
		var id: int = world.spawn_worker(Vector2i(2 + index * 3, 5), role)
		_check(_home(world, id) == 0 and not Jobs.requires_home(world, world.workers[id]) and not Jobs.claim(world, world.workers[id], hut),
			"Communal %s must not reserve or require a private building" % role, failures)
	_check(Jobs.occupant(world, hut).is_empty(), "Communal workers must leave production vacancies available", failures)
	var gardener: int = world.spawn_worker(Vector2i(9, 5), "gardener")
	_check(_home(world, gardener) == 0 and Jobs.requires_home(world, world.workers[gardener])
		and not Jobs.claim(world, world.workers[gardener], hut),
		"Gardeners must require their own Forester Hut, never claim a Lumberjack Hut", failures)


static func _test_carried_ware_limits_new_workplace(failures: Array[String]) -> void:
	var world = World.new(Vector2i(16, 9))
	world.grid.set_base_terrain(Vector2i(4, 2), "rock")
	world.add_deposit(Vector2i(4, 2), "iron_ore", 3)
	world.add_deposit(Vector2i(13, 2), "coal", 3)
	var iron_mine: int = world.place_building("iron_mine", Vector2i(2, 2))
	var coal_mine: int = world.place_building("coal_mine", Vector2i(11, 2))
	var id: int = world.spawn_worker(Vector2i(2, 5), "miner", 0, false)
	var worker: Dictionary = world.workers[id]
	worker["carrying"] = "coal"
	_check(not Jobs.can_claim(world, worker, iron_mine), "A homeless miner carrying coal must not claim an incompatible iron mine", failures)
	_check(Jobs.ensure(world, worker) == coal_mine and _home(world, id) == coal_mine,
		"A homeless specialist must select a vacant workplace that accepts its already carried output", failures)


static func _unreachable_fixture() -> Dictionary:
	var world = World.new(Vector2i(16, 10))
	for y: int in range(10):
		world.grid.set_base_terrain(Vector2i(8, y), "water")
	var farm: int = world.place_building("farm", Vector2i(12, 3))
	var worker: int = world.spawn_worker(Vector2i(2, 3), "farmer")
	return {"world": world, "worker": worker, "farm": farm}


static func _searches(worker: Dictionary) -> int:
	return int(worker.get("_workplace_search_count", 0))


static func _test_failed_search_is_cached_despite_surface_traffic(failures: Array[String]) -> void:
	var fixture: Dictionary = _unreachable_fixture()
	var world = fixture["world"]
	var worker: Dictionary = world.workers[fixture["worker"]]
	_check(_searches(worker) == 1 and int(worker["home_id"]) == 0,
		"The unreachable vacancy fixture must really perform and fail one search", failures)
	_advance(world, 20)
	_check(_searches(worker) == 1, "An unchanged unreachable vacancy must not trigger a full-map search each tick", failures)
	var connectivity: int = world.grid.connectivity_revision
	var render_revision: int = world.grid.revision
	world.grid.record_carrier_traffic(Vector2i(1, 6))
	world.grid.set_traffic_wear(Vector2i(2, 6), 2)
	world.grid.add_dirt_trail(Vector2i(3, 6))
	world.grid.add_road(Vector2i(4, 6))
	Jobs.ensure(world, worker)
	_check(world.grid.revision > render_revision and world.grid.connectivity_revision == connectivity,
		"Roads and traffic must change rendering without changing permanent connectivity", failures)
	_check(_searches(worker) == 1, "Road/trail/wear changes must retain a failed reachability cache", failures)
	var empty = World.new(Vector2i(8, 8))
	var unassigned: int = empty.spawn_worker(Vector2i(3, 3), "farmer")
	_advance(empty, 20)
	_check(_searches(empty.workers[unassigned]) == 0, "No candidate workplaces must require no path searches", failures)


static func _test_new_vacancies_wake_failed_searches(failures: Array[String]) -> void:
	for completion: bool in [false, true]:
		var fixture: Dictionary = _unreachable_fixture()
		var world = fixture["world"]
		var worker: Dictionary = world.workers[fixture["worker"]]
		var near_farm: int = world.place_building("farm", Vector2i(4, 6))
		var owner: int = 0
		if completion:
			world.buildings[near_farm]["construction_remaining"] = 1
		else:
			owner = world.spawn_worker(Vector2i(5, 6), "farmer", near_farm)
		Jobs.ensure(world, worker)
		var before: int = _searches(worker)
		var connectivity: int = world.grid.connectivity_revision
		if completion:
			world.buildings[near_farm]["construction_remaining"] = 0
		else:
			world.workers[owner]["hunger"] = 1
			world.economy_enabled = true
			world.tick = int(world.catalog.economy["condition_interval_ticks"]) - 1
			world.step_tick()
		Jobs.ensure(world, worker)
		_check(world.grid.connectivity_revision == connectivity,
			"A completed site or dead owner must expose a vacancy without pretending terrain changed", failures)
		_check(_searches(worker) == before + 1 and int(worker["home_id"]) == near_farm,
			"A newly completed or vacated home must immediately invalidate the failed target-set cache", failures)


static func _test_connectivity_changes_invalidate_failed_searches(failures: Array[String]) -> void:
	var fixture: Dictionary = _unreachable_fixture()
	var world = fixture["world"]
	var worker: Dictionary = world.workers[fixture["worker"]]
	var expected: int = _searches(worker)
	var connectivity: int = world.grid.connectivity_revision
	world.grid.set_base_terrain(Vector2i(0, 0), "grass")
	world.grid.set_vertex_height(Vector2i(0, 0), 0)
	world.grid.unblock(Vector2i(0, 0))
	Jobs.ensure(world, worker)
	_check(world.grid.connectivity_revision == connectivity and _searches(worker) == expected,
		"No-op terrain, height and unblock requests must retain the failed search", failures)
	for change: Callable in [
		func(): world.grid.set_base_terrain(Vector2i(0, 0), "dirt"),
		func(): world.grid.set_vertex_height(Vector2i(0, 0), 1),
		func(): world.grid.block(Vector2i(0, 0), 98765),
		func(): world.grid.unblock(Vector2i(0, 0)),
		func(): world.grid.configure_movement(world.catalog.movement),
	]:
		change.call()
		expected += 1
		Jobs.ensure(world, worker)
		_check(_searches(worker) == expected and int(worker["home_id"]) == 0,
			"Actual terrain/height/block/unblock/movement-definition changes must retry failed connectivity", failures)
		Jobs.ensure(world, worker)
		_check(_searches(worker) == expected, "Each connectivity revision must be searched at most once per unchanged worker", failures)
	world.grid.block(Vector2i(0, 0), 98765)
	Jobs.ensure(world, worker)
	expected = _searches(worker)
	connectivity = world.grid.connectivity_revision
	world.grid.block(Vector2i(0, 0), 98765)
	Jobs.ensure(world, worker)
	_check(world.grid.connectivity_revision == connectivity and _searches(worker) == expected,
		"Repeatedly blocking an already blocked tile must not invalidate cached reachability", failures)
	world.grid.set_base_terrain(Vector2i(8, 5), "grass")
	Jobs.ensure(world, worker)
	_check(_searches(worker) == expected + 1 and int(worker["home_id"]) == int(fixture["farm"]),
		"Opening a real gap in the water barrier must wake and successfully employ the waiting farmer", failures)


static func _test_failed_search_tracks_position_cargo_and_grid(failures: Array[String]) -> void:
	var fixture: Dictionary = _unreachable_fixture()
	var world = fixture["world"]
	var worker: Dictionary = world.workers[fixture["worker"]]
	var initial: int = _searches(worker)
	worker["carrying"] = "grain"
	Jobs.ensure(world, worker)
	_check(_searches(worker) == initial + 1, "Changing carried output must invalidate the failed-search signature", failures)
	world.tile_reservations.erase(worker["position"])
	worker["position"] = Vector2i(3, 4)
	world.tile_reservations[worker["position"]] = worker["id"]
	Jobs.ensure(world, worker)
	_check(_searches(worker) == initial + 2, "A moved unemployed worker must search from its new position", failures)
	var previous_grid = world.grid
	world.grid = previous_grid.get_script().new(previous_grid.size)
	world.grid.configure_movement(world.catalog.movement)
	for y: int in range(10):
		world.grid.set_base_terrain(Vector2i(8, y), "water")
	for building: Dictionary in world.buildings.values():
		world.grid.block(building["position"], building["id"])
	_check(world.grid.connectivity_revision == previous_grid.connectivity_revision,
		"Replacement-grid fixture must deliberately reuse the same numerical connectivity revision", failures)
	Jobs.ensure(world, worker)
	_check(_searches(worker) == initial + 3, "A different grid instance must invalidate a numerically identical failed-search revision", failures)
	var saved: Dictionary = world.to_data()
	_check(not saved["workers"][0].has("_workplace_search_cache") and not saved["workers"][0].has("_workplace_search_count"),
		"Search caches and profiling counts must remain transient and absent from saved games", failures)


static func _test_equal_cost_chooses_lowest_building_id(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 10))
	# The lower ID is deliberately on the right: the pathfinder's cell-order
	# heap tie-break otherwise encounters the left entrance first.
	var first: int = world.place_building("farm", Vector2i(10, 2))
	var second: int = world.place_building("farm", Vector2i(2, 2))
	var start := Vector2i(6, 5)
	var pathfinder: Script = load("res://scripts/simulation/grid_pathfinder.gd")
	var first_path: Array[Vector2i] = pathfinder.find_path(world.grid, start, world.buildings[first]["entrance"])
	var second_path: Array[Vector2i] = pathfinder.find_path(world.grid, start, world.buildings[second]["entrance"])
	_check(pathfinder.path_cost(world.grid, first_path, start) == pathfinder.path_cost(world.grid, second_path, start),
		"The tie-break fixture must present genuinely equal weighted travel costs", failures)
	var worker: int = world.spawn_worker(start, "farmer")
	_check(_home(world, worker) == first and _searches(world.workers[worker]) == 1,
		"One multi-target search must resolve equal weighted costs by lowest building ID", failures)
