extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Legacy = preload("res://tests/legacy_world_fixture.gd")
const NutritionModel = preload("res://scripts/simulation/nutrition.gd")
const Feeding = preload("res://scripts/simulation/inn_feeding.gd")
const DayCycle = preload("res://scripts/simulation/day_cycle.gd")
const TEST_COUNT: int = 13


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_every_new_profession_is_fed,
		_test_seven_complete_days_with_real_sleep_and_fog,
		_test_sleep_reduces_appetite_not_calendar_reserve,
		_test_small_food_portions_do_not_reset_starvation,
		_test_work_efficiency_boundaries,
		_test_hungry_movement_is_unchanged,
		_test_outdoor_production_keeps_eighty_percent,
		_test_indoor_production_keeps_eighty_percent,
		_test_construction_keeps_eighty_percent,
		_test_earthwork_keeps_eighty_percent,
		_test_zero_satiety_soldier_can_be_rescued,
		_test_real_meal_progressively_recovers_strength,
		_test_disabled_needs_and_foreign_units_stay_unchanged,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
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


static func _weaken(worker: Dictionary) -> void:
	worker["hunger"] = 0
	worker["nutrition_deficit_ticks"] = 24000
	worker["work_effort_remainder"] = 0


static func _test_every_new_profession_is_fed(failures: Array[String]) -> void:
	var world = World.new(Vector2i(40, 8))
	var roles: Array = world.catalog.units.keys() + world.catalog.soldiers.keys()
	for index: int in range(roles.size()):
		var id: int = world.spawn_worker(Vector2i(index + 1, 4), roles[index])
		_check(id != 0, "Each catalog profession must spawn for nutrition verification", failures)
		if id == 0:
			continue
		var worker: Dictionary = world.workers[id]
		_check(int(worker["hunger"]) == 2700 and int(worker["nutrition_deficit_ticks"]) == 0,
			"New %s must start fully fed with a fresh seven-day reserve" % roles[index], failures)


static func _test_seven_complete_days_with_real_sleep_and_fog(failures: Array[String]) -> void:
	var world = World.new(Vector2i(16, 12))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	var civilian: int = world.spawn_worker(Vector2i(2, 7), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(12, 8), "militia")
	world.tick = 137 # Survival is elapsed time since spawn, not calendar midnight.
	world.economy_enabled = true
	world.enable_fog()
	var slept: bool = false
	var woke: bool = false
	for elapsed: int in range(1, 42000):
		world.step_tick()
		if not world.workers.has(civilian) or not world.workers.has(soldier):
			failures.append("Neither sleeping civilians nor awake soldiers may die before seven complete food-free days")
			return
		var worker: Dictionary = world.workers[civilian]
		slept = slept or world.is_worker_sleeping(worker)
		woke = woke or (slept and not world.is_night_rest_time() and worker["state"] != "sleeping")
		if elapsed % 6000 == 0:
			_check(int(worker["nutrition_deficit_ticks"]) == elapsed,
				"A day's real sleep, fog and movement must preserve the exact unfed calendar reserve", failures)
	_check(slept and woke and store != 0 and int(world.workers[civilian]["hunger"]) == 0,
		"An empty-stomach civilian must live through real nights and wake again", failures)
	world.step_tick()
	_check(world.tick == 42137 and not world.workers.has(civilian) and not world.workers.has(soldier),
		"Death must occur on the 42000th unfed tick for both civilians and soldiers", failures)
	_check(world.tile_reservations.is_empty(), "Seven-day starvation must release all outdoor occupied cells", failures)


static func _test_sleep_reduces_appetite_not_calendar_reserve(failures: Array[String]) -> void:
	var world = World.new(Vector2i(16, 12))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	var sleeper: int = world.spawn_worker(world.buildings[store]["entrance"], "carrier", 0, true, store)
	var guard: int = world.spawn_worker(Vector2i(12, 8), "militia")
	world.workers[sleeper]["sleep_home_id"] = store
	world.workers[sleeper]["state"] = "sleeping"
	world.tick = 4000
	world.economy_enabled = true
	_advance(world, 100)
	_check(int(world.workers[sleeper]["hunger"]) == 2676 and int(world.workers[guard]["hunger"]) == 2652,
		"One hundred real sleeping ticks must consume 24 condition versus an awake guard's 48", failures)
	_check(int(world.workers[sleeper]["nutrition_deficit_ticks"]) == 100 and int(world.workers[guard]["nutrition_deficit_ticks"]) == 100,
		"Night's lower appetite must not silently extend the agreed seven calendar days", failures)


static func _test_small_food_portions_do_not_reset_starvation(failures: Array[String]) -> void:
	var world = World.new()
	var part: Dictionary = {"hunger": 0, "nutrition_deficit_ticks": 36000}
	NutritionModel.restore_food(world, part, 1)
	_check(int(part["nutrition_deficit_ticks"]) == 35998 and int(part["nutrition_recovery_remainder"]) == 1320,
		"A tiny bite must repay only its exact nutrition, not grant seven fresh days", failures)
	var whole: Dictionary = {"hunger": 0, "nutrition_deficit_ticks": 36000}
	NutritionModel.restore_food(world, whole, 1080)
	for _bite: int in range(1079):
		NutritionModel.restore_food(world, part, 1)
	_check(part == whole, "Splitting one paid serving into progressive bites must not change its total recovery", failures)
	NutritionModel.restore_food(world, part, 100000)
	_check(int(part["hunger"]) == 2700 and int(part["nutrition_deficit_ticks"]) == 0 and int(part["nutrition_recovery_remainder"]) == 0,
		"Recovery must cap at full reserve without storing extra future immunity", failures)


static func _test_work_efficiency_boundaries(failures: Array[String]) -> void:
	var world = World.new()
	world.economy_enabled = true
	for row: Array in [[0, 1000], [12000, 1000], [18000, 900], [24000, 800], [41999, 800]]:
		var worker: Dictionary = {"hunger": 0, "nutrition_deficit_ticks": row[0], "work_effort_remainder": 0}
		_check(NutritionModel.work_efficiency_permille(world, worker) == int(row[1]),
			"Long-term deficit must progressively cap work loss at twenty percent", failures)
		var worked: int = 0
		for _tick: int in range(1000):
			if NutritionModel.allow_work_tick(world, worker):
				worked += 1
		_check(worked == int(row[1]) and int(worker["work_effort_remainder"]) == 0,
			"Fixed-point productive work must deliver the exact promised efficiency", failures)


static func _test_hungry_movement_is_unchanged(failures: Array[String]) -> void:
	var fed = World.new(Vector2i(16, 12))
	var hungry = World.new(Vector2i(16, 12))
	var fed_id: int = fed.spawn_worker(Vector2i(2, 6), "carrier")
	var hungry_id: int = hungry.spawn_worker(Vector2i(2, 6), "carrier")
	fed.economy_enabled = true
	hungry.economy_enabled = true
	_weaken(hungry.workers[hungry_id])
	_check(fed._move_worker_to(fed.workers[fed_id], Vector2i(12, 6)) and hungry._move_worker_to(hungry.workers[hungry_id], Vector2i(12, 6)),
		"Both comparison carriers must receive the same real route", failures)
	for _tick: int in range(140):
		fed.step_tick()
		hungry.step_tick()
		for key: String in ["position", "previous_position", "move_cooldown", "visual_progress_ticks", "visual_duration_ticks"]:
			_check(fed.workers[fed_id][key] == hungry.workers[hungry_id][key],
				"Hunger must not alter carrier walking or animation timing: " + key, failures)
	_check(hungry.workers[hungry_id]["position"] == Vector2i(12, 6), "A weakened carrier must still reach its destination", failures)


static func _test_outdoor_production_keeps_eighty_percent(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(16, 12))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	world.add_tree(Vector2i(6, 5), 20)
	var id: int = world.spawn_worker(Vector2i(4, 5), "lumberjack", hut)
	world.economy_enabled = true
	if not _until(world, func() -> bool: return world.workers[id]["state"] == "working"):
		failures.append("The weakened outdoor worker fixture must reach a real tree harvest")
		return
	_weaken(world.workers[id])
	world.workers[id]["work_remaining"] = 1000
	_advance(world, 1000)
	_check(int(world.workers[id]["work_remaining"]) == 200,
		"A genuinely harvesting weakened worker must perform 800 work steps in 1000 ticks", failures)


static func _test_indoor_production_keeps_eighty_percent(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(16, 12))
	var saw: int = world.place_building("sawmill", Vector2i(3, 3))
	world.buildings[saw]["inputs"]["log"] = 2
	var id: int = world.spawn_worker(Vector2i(4, 5), "carpenter", saw)
	world.economy_enabled = true
	if not _until(world, func() -> bool: return int(world.buildings[saw]["process_remaining"]) > 0):
		failures.append("The weakened indoor worker fixture must begin its real paid recipe")
		return
	_weaken(world.workers[id])
	world.buildings[saw]["process_remaining"] = 1000
	var inputs: Dictionary = world.buildings[saw]["inputs"].duplicate()
	_advance(world, 1000)
	_check(int(world.buildings[saw]["process_remaining"]) == 200 and world.buildings[saw]["inputs"] == inputs,
		"Indoor weakness must slow progress to 80% without restarting or repaying the recipe", failures)


static func _test_construction_keeps_eighty_percent(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(16, 12))
	world.economy_enabled = true
	var site: int = world.place_building("lumber_hut", Vector2i(8, 4))
	var id: int = world.spawn_worker(Vector2i(5, 5), "builder")
	world.buildings[site]["construction_delivered"] = world.construction_cost(world.buildings[site]).duplicate()
	if not _until(world, func() -> bool: return world.workers[id]["action"] == "build_site" and world.workers[id]["state"] == "working"):
		failures.append("The weakened builder fixture must actually begin construction")
		return
	_weaken(world.workers[id])
	world.buildings[site]["construction_remaining"] = 1000
	_advance(world, 1000)
	_check(int(world.buildings[site]["construction_remaining"]) == 200,
		"A weakened builder must continue at 80% instead of stopping the rescue economy", failures)


static func _test_zero_satiety_soldier_can_be_rescued(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(16, 12))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[store]["storage"]["bread"] = 1
	var carrier: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(10, 5), "militia")
	_weaken(world.workers[carrier])
	_weaken(world.workers[soldier])
	world.economy_enabled = true
	_check(world.request_soldier_food(soldier), "A living zero-satiety soldier must still accept an explicit ration order", failures)
	_check(_until(world, func() -> bool: return int(world.workers[soldier]["hunger"]) == 2700),
		"A hungry carrier must deliver an actual serving to rescue an empty-stomach soldier", failures)
	_check(world.resource_stock("bread")["total"] == 0 and int(world.workers[soldier]["nutrition_deficit_ticks"]) < 24000,
		"A military meal must consume physical food and replenish long-term reserve as well as satiety", failures)


static func _test_earthwork_keeps_eighty_percent(failures: Array[String]) -> void:
	var world = World.new(Vector2i(24, 18))
	for y: int in range(7, 10):
		for x: int in range(10, 14):
			world.grid.set_vertex_height(Vector2i(x, y), (x + y) % 3)
	world.economy_enabled = true
	var site: int = world.place_building("lumber_hut", Vector2i(10, 8))
	var id: int = world.spawn_worker(Vector2i(12, 11), "builder")
	if site == 0 or not _until(world, func() -> bool: return world.workers[id]["action"] == "build_site" and world.workers[id]["state"] == "working"):
		failures.append("The nutrition earthwork fixture must begin a real full-footprint foundation")
		return
	_weaken(world.workers[id])
	var before: int = int(world.buildings[site]["foundation_work_remaining"])
	_advance(world, 10)
	_check(before > 8 and int(world.buildings[site]["foundation_work_remaining"]) == before - 8,
		"Modern earthwork must apply the 80% rate once, not twice through construction and foundation hooks", failures)


static func _test_real_meal_progressively_recovers_strength(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(12, 10))
	var inn: int = world.place_building("inn", Vector2i(3, 3))
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
	for food: String in ["bread", "wine", "sausage"]:
		world.buildings[inn]["inputs"][food] = 1
	world.economy_enabled = true
	var worker: Dictionary = world.workers[id]
	_weaken(worker)
	worker["action"] = "eat"
	worker["destination_id"] = inn
	Feeding.arrive(world, worker)
	world.step_tick()
	_check(int(worker["nutrition_deficit_ticks"]) < 24000 and int(worker["nutrition_deficit_ticks"]) > 23000,
		"The first real bite must start gradual recovery, not remove several days of malnutrition", failures)
	_check(_until(world, func() -> bool: return int(worker["meal_ticks_left"]) == 0),
		"A previously empty-stomach citizen must complete its real multi-course meal", failures)
	_check(int(worker["nutrition_deficit_ticks"]) == 15000 and NutritionModel.work_efficiency_permille(world, worker) == 950,
		"Three paid courses must repay 9000 deficit ticks and gradually restore work from80% to95%", failures)
	_check(int(worker["hunger"]) == 2700 and (world.buildings[inn]["inputs"] as Dictionary).values().all(func(value: Variant) -> bool: return int(value) == 0),
		"Real recovery must cap satiety and consume each of the three servings exactly once", failures)


static func _test_disabled_needs_and_foreign_units_stay_unchanged(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 12))
	var id: int = world.spawn_worker(Vector2i(2, 5), "carrier")
	var enemy: int = world.spawn_worker(Vector2i(10, 5), "militia", 0, true, 0, 2)
	_weaken(world.workers[id])
	_weaken(world.workers[enemy])
	_advance(world, 20)
	_check(int(world.workers[id]["nutrition_deficit_ticks"]) == 24000 and int(world.workers[id]["condition_decay_remainder"]) == 0,
		"Authoring worlds with needs disabled must not age the survival reserve", failures)
	world.economy_enabled = true
	var before: Dictionary = world.to_data()
	for _read: int in range(10):
		world.hunger_status(world.workers[id])
		world.hunger_status(world.workers[enemy])
	_check(world.to_data() == before, "Reading nutrition indicators must never advance needs, work or fractional state", failures)
	_advance(world, 20)
	_check(int(world.workers[enemy]["nutrition_deficit_ticks"]) == 24000 and int(world.workers[enemy]["condition_decay_remainder"]) == 0,
		"Foreign visibility placeholders must not receive local hunger simulation", failures)
