extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Feeding = preload("res://scripts/simulation/inn_feeding.gd")
const Economy = preload("res://scripts/simulation/classic_economy.gd")
const TEST_COUNT: int = 12


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_meal_occupies_seat_and_pauses_hunger,
		_test_three_distinct_courses_and_no_replay,
		_test_six_seats_and_alternative_inn,
		_test_last_serving_is_consumed_once,
		_test_soldiers_never_use_the_inn,
		_test_carrying_worker_finishes_delivery_first,
		_test_blocked_visit_can_choose_another_inn,
		_test_specialist_returns_to_same_workplace,
		_test_save_during_meal_preserves_timer,
		_test_varied_meal_restores_more_than_single_food,
		_test_new_deliveries_are_selected_between_courses,
		_test_legacy_paid_meal_only_finishes_countdown,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _index: int in range(ticks):
		world.step_tick()


static func _start_inside(world: Variant, inn_id: int, type: String = "carrier", home_id: int = 0) -> int:
	var id: int = world.spawn_worker(world.buildings[inn_id]["entrance"], type, home_id, false, inn_id)
	if id == 0:
		return 0
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 100
	worker["action"] = "eat"
	worker["destination_id"] = inn_id
	Feeding.arrive(world, worker)
	return id


static func _test_meal_occupies_seat_and_pauses_hunger(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	var id: int = _start_inside(world, inn)
	world.economy_enabled = true
	_check(id != 0 and int(world.workers[id]["hunger"]) == 100 and int(world.buildings[inn]["inputs"]["bread"]) == 0,
		"Starting a course must deduct one bread without instantly restoring its condition", failures)
	_check(Feeding.occupied_seats(world, inn) == 1 and int(world.workers[id]["meal_ticks_left"]) == 116,
		"The civilian must occupy a real indoor seat for one serving's duration", failures)
	_advance(world, 58)
	_check(int(world.workers[id]["hunger"]) == 640 and world.is_worker_inside(world.workers[id]),
		"Half a bread course must restore half its nutrition while the diner stays inside", failures)
	_advance(world, 57)
	_check(Feeding.occupied_seats(world, inn) == 1 and int(world.workers[id]["hunger"]) == 1170,
		"Eating must pause hunger decay and keep its seat through the penultimate tick", failures)
	world.step_tick()
	_check(Feeding.occupied_seats(world, inn) == 0 and int(world.workers[id]["meal_ticks_left"]) == 0 \
		and int(world.workers[id]["hunger"]) == 1180 and (world.workers[id]["meal_course"] as Dictionary).is_empty(),
		"The last meal tick must apply the exact remaining nutrition and release the seat", failures)
	_check(world.workers[id]["state"] == "idle", "Completing a meal must resume normal idle scheduling", failures)


static func _test_three_distinct_courses_and_no_replay(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	for food: String in ["bread", "sausage", "wine", "fish"]:
		world.buildings[inn]["inputs"][food] = 2
	var id: int = _start_inside(world, inn)
	world.economy_enabled = true
	_check(int(world.workers[id]["hunger"]) == 100 and int(world.workers[id]["meal_ticks_left"]) == 116,
		"A varied meal must start with a single course rather than consuming every course at arrival", failures)
	Feeding.arrive(world, world.workers[id])
	_check(int(world.buildings[inn]["inputs"]["bread"]) == 1 and int(world.buildings[inn]["inputs"]["sausage"]) == 2 \
		and int(world.buildings[inn]["inputs"]["wine"]) == 2 and int(world.buildings[inn]["inputs"]["fish"]) == 2,
		"Repeated arrival must not replay the current course or preconsume a later one", failures)
	_advance(world, 116)
	_check(int(world.workers[id]["hunger"]) == 1180 and world.workers[id]["meal_course"]["food"] == "wine" \
		and int(world.workers[id]["meal_ticks_left"]) == 116 and Feeding.occupied_seats(world, inn) == 1,
		"Bread must finish before wine begins, with no gap in seat occupancy", failures)
	_advance(world, 116)
	_check(int(world.workers[id]["hunger"]) == 1990 and world.workers[id]["meal_course"]["food"] == "sausage" \
		and world.workers[id]["meal_course"]["foods_eaten"] == ["bread", "wine", "sausage"],
		"A third distinct course must follow bread and wine while condition remains below the target", failures)
	_advance(world, 116)
	_check(int(world.workers[id]["hunger"]) == 2700 and int(world.workers[id]["meal_ticks_left"]) == 0 \
		and int(world.buildings[inn]["inputs"]["fish"]) == 2 and int(world.buildings[inn]["inputs"]["bread"]) == 1,
		"The three-course visit must cap condition and leave the fourth food and repeated bread untouched", failures)


static func _test_six_seats_and_alternative_inn(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(15, 9))
	var full: int = world.place_building("inn", Vector2i(4, 3))
	var other: int = world.place_building("inn", Vector2i(11, 3))
	world.buildings[full]["inputs"]["bread"] = 6
	world.buildings[other]["inputs"]["bread"] = 1
	for _index: int in range(6):
		_start_inside(world, full)
	world.buildings[full]["inputs"]["bread"] = 1
	var waiting: int = world.spawn_worker(world.buildings[full]["entrance"], "carrier")
	world.workers[waiting]["hunger"] = 100
	world.workers[waiting]["action"] = "eat"
	world.workers[waiting]["destination_id"] = full
	world.economy_enabled = true
	Feeding.arrive(world, world.workers[waiting])
	_check(Feeding.occupied_seats(world, full) == 6 and not world.is_worker_inside(world.workers[waiting]),
		"A seventh civilian must not consume a meal or enter an occupied seat", failures)
	_check(int(world.workers[waiting]["destination_id"]) == other and world.workers[waiting]["state"] == "moving",
		"A full inn must redirect its arriving civilian to another supplied inn", failures)
	_check(int(world.buildings[full]["inputs"]["bread"]) == 1, "A rejected guest must not consume a serving", failures)


static func _test_last_serving_is_consumed_once(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["fish"] = 1
	var first: int = _start_inside(world, inn)
	var second: int = _start_inside(world, inn)
	_check(int(world.buildings[inn]["inputs"]["fish"]) == 0 and Feeding.occupied_seats(world, inn) == 1,
		"An empty inn must neither create food nor claim a second eating seat", failures)
	_advance(world, 116)
	_check(int(world.workers[first]["hunger"]) == 1450 and int(world.workers[second]["hunger"]) == 100,
		"The last physical serving must restore exactly one civilian over its course", failures)


static func _test_soldiers_never_use_the_inn(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "militia")
	world.workers[id]["hunger"] = 100
	world.economy_enabled = true
	_check(not Feeding.handle_idle(world, world.workers[id]), "A hungry soldier must wait for delivery instead of walking to an inn", failures)
	world.workers[id]["action"] = "eat"
	world.workers[id]["destination_id"] = inn
	Feeding.arrive(world, world.workers[id])
	_check(int(world.buildings[inn]["inputs"]["bread"]) == 1 and not world.is_worker_inside(world.workers[id]),
		"A stale soldier meal action must not consume civilian food or enter the inn", failures)


static func _test_carrying_worker_finishes_delivery_first(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
	world.workers[id]["hunger"] = 100
	world.workers[id]["carrying"] = "log"
	world.economy_enabled = true
	_check(not Economy.handle_idle(world, world.workers[id]), "A carrying civilian must finish its delivery before normal feeding", failures)
	_check(world.workers[id]["carrying"] == "log" and int(world.buildings[inn]["inputs"]["bread"]) == 1,
		"Checking hunger must preserve the carried ware and physical food", failures)


static func _test_blocked_visit_can_choose_another_inn(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(15, 9))
	var first: int = world.place_building("inn", Vector2i(4, 3))
	var other: int = world.place_building("inn", Vector2i(11, 3))
	world.buildings[first]["inputs"]["bread"] = 1
	world.buildings[other]["inputs"]["bread"] = 1
	var id: int = world.spawn_worker(Vector2i(5, 6), "carrier")
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 100
	worker["action"] = "eat"
	worker["destination_id"] = first
	world.economy_enabled = true
	Feeding.retry_after_blocked(world, worker)
	_check(worker["state"] == "idle" and not Feeding.handle_idle(world, worker),
		"A failed meal route must release its target and back off instead of retrying every tick", failures)
	world.tick += Feeding.SEARCH_RETRY_TICKS
	_check(Feeding.handle_idle(world, worker) and int(worker["destination_id"]) == other,
		"A blocked meal route must allow another inn after the retry delay", failures)


static func _test_specialist_returns_to_same_workplace(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(15, 9))
	var bakery: int = world.place_building("bakery", Vector2i(3, 3))
	var inn: int = world.place_building("inn", Vector2i(9, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	world.buildings[bakery]["inputs"]["flour"] = 1
	var id: int = _start_inside(world, inn, "baker", bakery)
	world.economy_enabled = true
	_advance(world, 115)
	_check(int(world.workers[id]["home_id"]) == bakery and int(world.buildings[bakery]["outputs"]["bread"]) == 0,
		"A specialist's workplace must remain owned while its operator is eating", failures)
	_advance(world, 600)
	_check(int(world.workers[id]["home_id"]) == bakery and int(world.buildings[bakery]["outputs"]["bread"]) == 2,
		"After the meal the same specialist must return and operate its own bakery", failures)


static func _test_save_during_meal_preserves_timer(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["wine"] = 2
	var id: int = _start_inside(world, inn)
	world.economy_enabled = true
	_advance(world, 40)
	var before: int = int(world.workers[id]["meal_ticks_left"])
	var condition_before: int = int(world.workers[id]["hunger"])
	var course_before: Dictionary = (world.workers[id]["meal_course"] as Dictionary).duplicate(true)
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary
	_check(world.from_data(data), "An active meal must survive JSON save/load", failures)
	_check(int(world.workers[id].get("meal_ticks_left", 0)) == before and Feeding.occupied_seats(world, inn) == 1 \
		and int(world.workers[id]["hunger"]) == condition_before and world.workers[id]["meal_course"] == course_before,
		"Loading must preserve course progress, partial restoration, remaining duration and seat", failures)
	_advance(world, before)
	_check(int(world.workers[id]["hunger"]) == 910 and int(world.buildings[inn]["inputs"]["wine"]) == 1 \
		and Feeding.occupied_seats(world, inn) == 0,
		"A loaded meal must finish its remaining nutrition without repeating its ware or nutrition transaction", failures)


static func _test_varied_meal_restores_more_than_single_food(failures: Array[String]) -> void:
	var results: Array[int] = []
	for foods: Array in [["wine"], ["fish"], ["bread", "wine", "fish"]]:
		var world = LegacyFixture.create(Vector2i(9, 9))
		var inn: int = world.place_building("inn", Vector2i(4, 3))
		for food: String in foods:
			world.buildings[inn]["inputs"][food] = 3
		var id: int = _start_inside(world, inn)
		_advance(world, 116 * foods.size())
		results.append(int(world.workers[id]["hunger"]))
	_check(results == [910, 1450, 2700],
		"Wine alone, fish alone and bread/wine/fish must produce distinct nutrition; variety must restore more", failures)


static func _test_new_deliveries_are_selected_between_courses(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["bread"] = 2
	var id: int = _start_inside(world, inn)
	_advance(world, 58)
	world.buildings[inn]["inputs"]["wine"] = 1
	_check(int(world.buildings[inn]["inputs"]["wine"]) == 1,
		"A newly delivered second food must remain available during the current course", failures)
	_advance(world, 58)
	_check(world.workers[id]["meal_course"]["food"] == "wine" and int(world.buildings[inn]["inputs"]["wine"]) == 0 \
		and int(world.buildings[inn]["inputs"]["bread"]) == 1,
		"The next course must select a newly delivered different food, never a repeated portion of bread", failures)
	_advance(world, 116)
	_check(int(world.workers[id]["hunger"]) == 1990 and int(world.workers[id]["meal_ticks_left"]) == 0,
		"Without a third distinct food the diner must finish after the two available courses", failures)


static func _test_legacy_paid_meal_only_finishes_countdown(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier", 0, false, inn)
	world.buildings[inn]["inputs"]["wine"] = 1
	world.workers[id]["hunger"] = 1180
	world.workers[id]["meal_ticks_left"] = 7
	world.workers[id]["meal_course"] = {}
	world.workers[id]["action"] = "eat"
	world.workers[id]["state"] = "working"
	world.workers[id]["destination_id"] = inn
	world.economy_enabled = true
	_advance(world, 7)
	_check(int(world.workers[id]["hunger"]) == 1180 and int(world.workers[id]["meal_ticks_left"]) == 0 \
		and int(world.buildings[inn]["inputs"]["wine"]) == 1 and (world.workers[id]["meal_course"] as Dictionary).is_empty(),
		"A v13 meal already paid and restored must only finish its old countdown, without starting any new course", failures)
