extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Economy = preload("res://scripts/simulation/classic_economy.gd")
const Feeding = preload("res://scripts/simulation/inn_feeding.gd")
const DayCycle = preload("res://scripts/simulation/day_cycle.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_calendar_derived_loss, _test_real_daily_hunger_onset,
		_test_every_profession_and_soldier, _test_eta_accounts_for_tick_phase,
		_test_status_boundaries, _test_disabled_economy,
		_test_meals_pause_daily_decay,
		_test_two_days_of_work_food_and_sleep,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _test_calendar_derived_loss(failures: Array[String]) -> void:
	var world = LegacyFixture.create()
	_check(world.hunger_loss_per_interval() == 5,
		"Awake interval inspection must round up the actual 4.8 condition loss", failures)
	world.catalog.economy["condition_daily_hunger_fraction"] = 2.0
	_check(world.hunger_loss_per_interval() == 3,
		"The hunger loss must follow the configured fraction of a calendar day", failures)
	world.catalog.economy["condition_interval_ticks"] = 20
	_check(world.hunger_loss_per_interval() == 5,
		"Changing the needs-check interval must preserve the intended calendar pace", failures)


static func _test_real_daily_hunger_onset(failures: Array[String]) -> void:
	for initial: int in [2700, 1620]:
		var world = LegacyFixture.create(Vector2i(5, 5))
		var id: int = world.spawn_worker(Vector2i(2, 2), "carrier")
		world.workers[id]["hunger"] = initial
		world.economy_enabled = true
		var predicted: int = int(world.hunger_status(world.workers[id])["remaining_to_hungry_ticks"])
		var expected: int = 4875 if initial == 2700 else 2625
		_check(predicted == expected and predicted < DayCycle.TICKS_PER_DAY,
			"A %d-condition citizen must need food within one game day" % initial, failures)
		_advance(world, predicted - 1)
		_check(int(world.workers[id]["hunger"]) > 360,
			"Daily hunger must not reach its threshold before the predicted tick", failures)
		world.step_tick()
		_check(int(world.workers[id]["hunger"]) == 360 and world.hunger_status(world.workers[id])["state"] == "Hungry",
			"Daily hunger must reach its threshold on the predicted simulation tick", failures)


static func _test_every_profession_and_soldier(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(10, 10))
	var roles: Array = world.catalog.units.keys()
	roles.append_array(world.catalog.soldiers.keys())
	roles.sort()
	var index: int = 0
	for role: String in roles:
		var id: int = world.spawn_worker(Vector2i(index % 10, int(index / 10)), role)
		world.workers[id]["hunger"] = 1620
		index += 1
	world.economy_enabled = true
	_advance(world, 10)
	for worker: Dictionary in world.workers.values():
		_check(int(worker["hunger"]) == 1616 and int(worker["condition_decay_remainder"]) == 800,
			"Daily hunger must apply equally to %s" % worker["type"], failures)
		_check(not bool(worker["food_requested"]),
			"Faster hunger must not create automatic military food orders", failures)


static func _test_eta_accounts_for_tick_phase(failures: Array[String]) -> void:
	var world = LegacyFixture.create()
	world.economy_enabled = true
	var worker: Dictionary = {"hunger": 370, "meal_ticks_left": 0, "condition_decay_remainder": 0}
	for pair: Array in [[0, 21], [3, 21], [9, 21], [10, 21]]:
		world.tick = int(pair[0])
		_check(int(world.hunger_status(worker)["remaining_to_hungry_ticks"]) == int(pair[1]),
			"Per-tick hunger ETA must not depend on the old ten-tick global phase %d" % world.tick, failures)
	world.tick = 3
	worker["hunger"] = 361
	worker["condition_decay_remainder"] = 600
	_check(int(world.hunger_status(worker)["remaining_to_hungry_ticks"]) == 1,
		"A partial condition point must preserve its exact remaining fraction in the ETA", failures)
	worker["hunger"] = 6
	worker["nutrition_deficit_ticks"] = 41983
	_check(int(world.hunger_status(worker)["remaining_to_starve_ticks"]) == 17,
		"Starvation ETA must use the independent seven-day reserve", failures)
	worker["hunger"] = 5
	worker["nutrition_deficit_ticks"] = 41993
	_check(int(world.hunger_status(worker)["remaining_to_starve_ticks"]) == 7,
		"Seven remaining reserve ticks must not be rounded to a global interval", failures)
	worker["hunger"] = 0
	worker["nutrition_deficit_ticks"] = 0
	_check(int(world.hunger_status(worker)["remaining_to_starve_ticks"]) == 42000,
		"An empty stomach alone must not remove the seven-day survival reserve", failures)


static func _test_status_boundaries(failures: Array[String]) -> void:
	var world = LegacyFixture.create()
	world.economy_enabled = true
	for pair: Array in [[2700, "Fed"], [1351, "Fed"], [1350, "Getting hungry"], [361, "Getting hungry"], [360, "Hungry"], [121, "Hungry"], [120, "Hungry"], [0, "Hungry"]]:
		var status: Dictionary = world.hunger_status({"hunger": int(pair[0])})
		_check(status["state"] == pair[1] and int(status["hungry_at"]) == 360,
			"Satiety state must not confuse an empty stomach with imminent death at %d" % pair[0], failures)
	_check(is_equal_approx(float(world.hunger_status({"hunger": 1350})["satiety_percent"]), 50.0),
		"The shared satiety percentage must use the configured maximum", failures)


static func _test_disabled_economy(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(5, 5))
	var id: int = world.spawn_worker(Vector2i(2, 2), "carrier")
	var before: int = int(world.workers[id]["hunger"])
	_advance(world, 100)
	var status: Dictionary = world.hunger_status(world.workers[id])
	_check(int(world.workers[id]["hunger"]) == before,
		"Disabled economy must not apply the accelerated condition loss", failures)
	_check(int(status["remaining_to_hungry_ticks"]) == -1 and int(status["remaining_to_starve_ticks"]) == -1,
		"Disabled hunger needs must not expose a running countdown", failures)


static func _test_meals_pause_daily_decay(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(8, 8))
	var inn: int = world.place_building("inn", Vector2i(3, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 100
	worker["action"] = "eat"
	worker["destination_id"] = inn
	world.economy_enabled = true
	Feeding.arrive(world, worker)
	_check(int(worker["meal_ticks_left"]) > 0,
		"Meal pause fixture must start a real course inside the inn", failures)
	_advance(world, 10)
	var applied: int = int((worker.get("meal_course", {}) as Dictionary).get("applied", 0))
	_check(int(worker["hunger"]) == 100 + applied and applied > 0,
		"A progressive meal must restore nutrition without subtracting daily hunger", failures)
	_check(int(world.hunger_status(worker)["remaining_to_starve_ticks"]) == -1,
		"An active progressive meal must not advertise a starvation countdown", failures)


static func _test_two_days_of_work_food_and_sleep(failures: Array[String]) -> void:
	for menu: Array in [["bread", "sausage"], ["bread", "wine", "fish"]]:
		var world = LegacyFixture.create(Vector2i(16, 12))
		var warehouse: int = world.place_building("warehouse", Vector2i(2, 3))
		var sawmill: int = world.place_building("sawmill", Vector2i(5, 3))
		var inn: int = world.place_building("inn", Vector2i(10, 3))
		world.buildings[warehouse]["storage"]["log"] = 200
		world.buildings[sawmill]["inputs"]["log"] = 4
		for food: String in menu:
			world.buildings[warehouse]["storage"][food] = 32
			world.buildings[inn]["inputs"][food] = 5
		var id: int = world.spawn_worker(world.buildings[sawmill]["entrance"], "carpenter", sawmill)
		world.workers[id]["hunger"] = 2700
		world.spawn_worker(Vector2i(1, 8), "carrier")
		world.spawn_worker(Vector2i(3, 8), "carrier")
		world.economy_enabled = true
		var last_visit: int = 0
		var visits: int = 0
		var returns: int = 0
		var was_eating: bool = false
		var awaiting_work_return: bool = false
		var slept: bool = false
		for _tick: int in range(DayCycle.TICKS_PER_DAY * 3):
			world.step_tick()
			if not world.workers.has(id):
				failures.append("A daily-fed carpenter must survive two days with menu %s" % str(menu))
				break
			var worker: Dictionary = world.workers[id]
			var eating: bool = int(worker["meal_ticks_left"]) > 0
			if eating and not was_eating:
				_check(world.tick - last_visit <= DayCycle.TICKS_PER_DAY + 1000,
					"Daily meals may include travel and the preceding meal's actual duration", failures)
				last_visit = world.tick
				visits += 1
			if was_eating and not eating:
				awaiting_work_return = true
			if awaiting_work_return and worker["action"] == "operate" and int(worker["source_id"]) == sawmill:
				returns += 1
				awaiting_work_return = false
			slept = slept or world.is_worker_sleeping(worker)
			if int(worker["home_id"]) != sawmill:
				failures.append("Daily meals and sleep must retain the carpenter's original workplace")
				break
			was_eating = eating
		_check(visits >= 2 and world.tick - last_visit <= DayCycle.TICKS_PER_DAY + 1000,
			"Both two-course and three-course menus must support approximately daily visits", failures)
		_check(returns >= 1 and world.stored_amount("plank") > 0,
			"A fed carpenter must resume real production and send its planks to storage", failures)
		_check(slept,
			"A daily-fed citizen must still return home for nightly rest", failures)
