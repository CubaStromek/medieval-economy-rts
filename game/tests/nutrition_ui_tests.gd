extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const Main = preload("res://scripts/view/main_view.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 5


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_empty_satiety_and_real_weakness(failures)
	_test_seven_day_reserve_and_speed(failures)
	_test_current_sleep_rate_not_reserve_extension(failures)
	_test_indoor_employee_nutrition(failures)
	_test_eating_rebuilds_reserve_progressively(failures)
	return failures


static func _main(world: World, selected: int) -> Main:
	var main := Main.new()
	main.world = world
	main._build_ui()
	main.selected_unit_id = selected
	main._update_ui()
	return main


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_empty_satiety_and_real_weakness(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	world.economy_enabled = true
	var id: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 0
	var main: Main = _main(world, id)
	_check(main.hud._satiety_label.text == "Satiety 0% · Hungry" and main.hud._satiety_bar.value == 0.0
		and main.hud._satiety_timing.text.contains("Food reserve: 7.0 / 7 game days")
		and main.hud._satiety_timing.text.contains("Work 100% · walking 100%")
		and not main.hud._satiety_timing.text.contains("Danger"),
		"Empty satiety with a fresh reserve must be Hungry, fully productive and explicitly seven days from exhausted reserves", failures)
	worker["nutrition_deficit_ticks"] = 18000
	main._update_ui()
	_check(main.hud._satiety_label.text.contains("Weakened") and main.hud._satiety_fill.bg_color == Hud.satiety_color("Weakened")
		and main.hud._satiety_timing.text.contains("Food reserve: 4.0 / 7 game days")
		and main.hud._satiety_timing.text.contains("Work 90% · walking 100%")
		and not main.hud._satiety_timing.text.contains("Danger"),
		"Three days of nutritional deficit must display the real 90% work efficiency without slowing walking or falsely declaring the last day", failures)
	worker["nutrition_deficit_ticks"] = 39000
	main.simulation_speed = 2.0
	main._update_ui()
	_check(main.hud._satiety_label.text.contains("Starving") and main.hud._satiety_fill.bg_color == Hud.satiety_color("Starving")
		and main.hud._satiety_timing.text.contains("Food reserve: 0.5 / 7 game days")
		and main.hud._satiety_timing.text.contains("Work 80% · walking 100%")
		and main.hud._satiety_timing.text.contains("12 h 00 min of game time until death without food")
		and main.hud._satiety_timing.text.contains("2 min 30 s at 2.0×"),
		"A genuinely exhausted reserve must show the exact remaining calendar time and actual capped work penalty", failures)
	world.economy_enabled = false
	main._update_ui()
	_check(main.hud._satiety_timing.text == "Food needs are disabled in this scenario."
		and main.hud._satiety_timing.tooltip_text.is_empty(),
		"Disabled food scenarios must not advertise an advancing death countdown", failures)
	main.free()


static func _test_seven_day_reserve_and_speed(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	world.economy_enabled = true
	var id: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	var main: Main = _main(world, id)
	var before: Dictionary = world.to_data()
	_check(main.hud._satiety_timing.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Reserve timing explanations must be reachable by hovering the label without blocking inspector scrolling", failures)
	for setting: Array in [[0.5, "140 min 00 s at 0.5×"], [1.0, "70 min 00 s at 1.0×"], [2.0, "35 min 00 s at 2.0×"]]:
		main.simulation_speed = float(setting[0])
		main._update_ui()
		_check(main.hud._satiety_timing.text.contains("Food reserve: 7.0 / 7 game days")
			and main.hud._satiety_timing.tooltip_text.contains("Reserve without further food: 168 h 00 min of game time")
			and main.hud._satiety_timing.tooltip_text.contains(String(setting[1])),
			"Seven-day reserve must stay in calendar time and convert correctly to the selected real-time speed", failures)
	main.simulation_speed = 0.0
	main._update_ui()
	_check(main.hud._satiety_timing.text.contains("Simulation paused")
		and main.hud._satiety_timing.tooltip_text.contains("Simulation paused")
		and not main.hud._satiety_timing.tooltip_text.contains("at 0.0×"),
		"Pausing must pause both hunger and reserve estimates without division by zero", failures)
	_check(world.to_data() == before, "UI refreshes at different speeds must not consume satiety or long-term nutrition", failures)
	main.free()


static func _test_current_sleep_rate_not_reserve_extension(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	world.tick = 3750
	var store: int = world.place_building("warehouse", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[store]["entrance"], "carrier")
	world.economy_enabled = true
	var worker: Dictionary = world.workers[id]
	worker["condition_decay_remainder"] = 240
	var main: Main = _main(world, id)
	var awake_ticks: int = int(world.hunger_status(worker)["remaining_to_hungry_ticks"])
	var awake_reserve_tooltip: String = main.hud._satiety_timing.tooltip_text
	_check(main.hud._satiety_timing.text.contains("Estimated hunger") and main.hud._satiety_timing.text.contains("current awake rate"),
		"Nighttime alone must not claim a sleeping satiety rate for an awake carrier", failures)
	worker["sleep_home_id"] = store
	_check(world._enter_worker_building(worker, store), "The sleep ETA fixture must enter a real completed warehouse", failures)
	worker["state"] = "sleeping"
	main._update_ui()
	var asleep_ticks: int = int(world.hunger_status(worker)["remaining_to_hungry_ticks"])
	_check(world.is_worker_sleeping(worker) and asleep_ticks == awake_ticks * 2 - 1
		and main.hud._satiety_timing.text.contains("Estimated hunger in 39 h 00 min of game time at the current sleeping rate")
		and main.hud._satiety_timing.tooltip_text == awake_reserve_tooltip,
		"Real sleep must use half-rate appetite with its saved fractional remainder, while preserving exactly the same seven-day reserve ETA", failures)
	_check(main.hud._satiety_timing.tooltip_text.contains("Sleep slows satiety loss, but does not extend the reserve clock")
		and main.hud._satiety_timing.tooltip_text.contains("current activity continues"),
		"Sleep hunger ETA must be explained as a current-rate estimate, not a prediction that the citizen will sleep for two days", failures)
	main.free()


static func _test_indoor_employee_nutrition(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	var home: int = world.place_building("sawmill", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[home]["entrance"], "carpenter", home)
	world.economy_enabled = true
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 0
	worker["nutrition_deficit_ticks"] = 18000
	world.enable_fog(1)
	_check(world._enter_worker_building(worker, home), "The nutrition fixture must put the actual assigned carpenter indoors", failures)
	var main: Main = _main(world, id)
	_check(main.selected_unit_id == id and main.hud._satiety_panel.visible
		and main.hud._satiety_timing.text.contains("Work 90%")
		and not bool(main.worker_satiety_presentation(worker, Vector2.ZERO)["visible"]),
		"An indoor owned worker must retain its nutrition inspector without leaking an outdoor map bar", failures)
	main.selected_unit_id = 0
	main.selected_cell = world.buildings[home]["position"]
	main._update_ui()
	_check(main.hud.production_detail_label.text.contains("Carpenter #%d • 1/1 • inside" % id)
		and main.hud.production_detail_label.text.contains("Satiety 0% · Weakened")
		and main.hud.production_detail_label.text.contains("Food reserve: 4.0 / 7 game days")
		and main.hud.production_detail_label.text.contains("Work 90% · walking 100%"),
		"Selecting an occupied workplace must expose its actual indoor employee's reserve and reduced productivity", failures)
	main.free()


static func _test_eating_rebuilds_reserve_progressively(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
	world.economy_enabled = true
	var worker: Dictionary = world.workers[id]
	worker["hunger"] = 0
	worker["nutrition_deficit_ticks"] = 30000
	world.step_tick()
	var main: Main = _main(world, id)
	_check(int(worker.get("meal_ticks_left", 0)) > 0 and main.hud._satiety_timing.text.contains("Eating Bread")
		and main.hud._satiety_timing.text.contains("Food reserve: 2.0 / 7 game days")
		and main.hud._satiety_timing.tooltip_text.contains("countdown is paused while eating")
		and not main.hud._satiety_timing.text.contains("Estimated hunger"),
		"A real course must show its nutrition reserve without an invented negative hunger or death ETA", failures)
	for _tick: int in range(58):
		world.step_tick()
	main._update_ui()
	_check(int(worker["nutrition_deficit_ticks"]) > 28000 and int(worker["nutrition_deficit_ticks"]) < 30000
		and main.hud._satiety_timing.text.contains("Food reserve: 2.2 / 7 game days")
		and main.hud._satiety_timing.text.contains("Work 80% · walking 100%")
		and main.hud._satiety_bar.value > 0.0,
		"Half a paid bread course must improve the reserve gradually instead of granting a fresh seven days or removing existing weakness", failures)
	main.selected_unit_id = 0
	main.selected_cell = world.buildings[inn]["position"]
	main._update_ui()
	_check(main.hud.production_detail_label.text.contains("Carrier #%d" % id)
		and main.hud.production_detail_label.text.contains("Food reserve: 2.2 / 7 game days")
		and main.hud.production_detail_label.text.contains("Eating Bread"),
		"The Inn diner list must expose the same progressively recovering reserve as the selected unit", failures)
	var before: Dictionary = world.to_data()
	for _frame: int in range(5):
		main._update_ui()
	_check(world.to_data() == before, "Repeated meal UI refresh must not apply any extra nutrition", failures)
	main.free()
