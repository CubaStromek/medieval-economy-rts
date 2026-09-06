extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Main = preload("res://scripts/view/main_view.gd")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_bars_for_every_profession(failures)
	_test_selected_progress_and_states(failures)
	_test_game_time_and_speed_estimate(failures)
	_test_indoor_worker_inspection(failures)
	_test_progressive_meal_details(failures)
	_test_shared_hunger_and_supply_summary(failures)
	return failures


static func _main(world: World) -> Main:
	var main := Main.new()
	main.world = world
	main._build_ui()
	return main


static func _test_bars_for_every_profession(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(18, 12))
	var main: Main = _main(world)
	var roles: Array = world.catalog.units.keys() + world.catalog.soldiers.keys()
	for index: int in range(roles.size()):
		var role: String = String(roles[index])
		var id: int = world.spawn_worker(Vector2i(2 + index % 10, 2 + index / 10), role)
		if id == 0:
			failures.append("Satiety bar fixture must spawn real catalog profession " + role)
			continue
		var worker: Dictionary = world.workers[id]
		worker["hunger"] = 1350
		var feet := Vector2(120, 120)
		var sprite: Dictionary = main.worker_presentation(worker, feet)
		var bar: Dictionary = main.worker_satiety_presentation(worker, feet)
		var rect: Rect2 = bar["rect"]
		var fill: Rect2 = bar["fill_rect"]
		_expect(bool(bar["visible"]) and rect.end.y < (sprite["rect"] as Rect2).position.y, "A visible satiety bar must sit above the entire sprite for " + role, failures)
		_expect(is_equal_approx(fill.size.x, rect.size.x * 0.5) and bar["caption"] == "", "Unselected units must show their actual half-full bar without a percentage label: " + role, failures)
		main.selected_unit_id = id
		bar = main.worker_satiety_presentation(worker, feet)
		_expect(bar["caption"] == "Satiety 50%", "Only the selected unit should display a clearly named map percentage", failures)
		main.selected_unit_id = 0
	var before: Dictionary = world.to_data()
	var workers_before: Dictionary = world.workers.duplicate(true)
	for worker: Dictionary in world.workers.values():
		main.worker_satiety_presentation(worker, Vector2.ZERO)
	_expect(world.to_data() == before and world.workers == workers_before, "Drawing satiety for every catalog unit must not alter saved or transient simulation state", failures)
	main.free()


static func _test_selected_progress_and_states(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	var id: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	world.economy_enabled = true
	var main: Main = _main(world)
	main.selected_unit_id = id
	var bar: ProgressBar = main.hud.find_child("UnitSatietyBar", true, false) as ProgressBar
	_expect(bar != null, "The selected person's inspector must contain an actual ProgressBar", failures)
	for row: Array in [[2700, "Fed"], [1350, "Getting hungry"], [360, "Hungry"], [120, "Starving"]]:
		world.workers[id]["hunger"] = int(row[0])
		main._update_ui()
		_expect(main.hud._satiety_panel.visible and is_equal_approx(bar.value, 100.0 * float(row[0]) / 2700.0) and main.hud._satiety_label.text.contains(String(row[1])), "Inspector satiety must reflect the actual numeric level and state " + String(row[1]), failures)
	_expect(bar.tooltip_text.contains("0% starving") and bar.tooltip_text.contains("100% full"), "The satiety control must explain both ends of its scale", failures)
	main.free()


static func _test_game_time_and_speed_estimate(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	var id: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	world.economy_enabled = true
	var main: Main = _main(world)
	main.selected_unit_id = id
	main.simulation_speed = 0.5
	main._update_ui()
	var timing: String = main.hud._satiety_timing.text
	_expect(timing.contains("10 h 05 min of game time") and timing.contains("8 min 24 s at 0.5×"), "The normal initial citizen must show its first meal against the game-day clock and current real-time speed", failures)
	main.simulation_speed = 1.0
	main._update_ui()
	_expect(main.hud._satiety_timing.text.contains("10 h 05 min of game time") and main.hud._satiety_timing.text.contains("4 min 12 s at 1.0×"), "Changing simulation speed must preserve game-time ETA and update the real waiting estimate", failures)
	main.simulation_speed = 0.0
	main._update_ui()
	_expect(main.hud._satiety_timing.text.contains("Simulation paused") and not main.hud._satiety_timing.text.contains("at 0.0×"), "Paused food estimates must say paused instead of dividing by zero or promising an active countdown", failures)
	world.workers[id]["hunger"] = 200
	world.workers[id]["carrying"] = "log"
	main._update_ui()
	_expect(main.hud._satiety_timing.text.contains("delivers its cargo"), "A hungry loaded carrier's inspector must explain why it finishes delivery before seeking food", failures)
	main.free()


static func _test_indoor_worker_inspection(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	var home: int = world.place_building("sawmill", Vector2i(4, 3))
	var id: int = world.spawn_worker(world.buildings[home]["entrance"], "carpenter", home)
	world.workers[id]["hunger"] = 1350
	var main: Main = _main(world)
	main.terrain_renderer = Terrain.new()
	main.add_child(main.terrain_renderer)
	main.terrain_renderer.bind_grid(world.grid)
	main.selected_unit_id = id
	world._enter_worker_building(world.workers[id], home)
	main._update_ui()
	_expect(main.selected_unit_id == id and main.hud._satiety_label.text.contains("Satiety 50%"), "Following a selected worker indoors must keep the same person's live satiety inspector", failures)
	_expect(not bool(main.worker_satiety_presentation(world.workers[id], Vector2.ZERO)["visible"]), "An indoor person must have no outdoor satiety bar", failures)
	var drawn: bool = false
	for entry: Dictionary in main._world_draw_entries():
		drawn = drawn or (entry["kind"] == "worker" and int(entry["id"]) == id)
	_expect(not drawn, "An indoor person's sprite, shadow, cargo and satiety bar must remain excluded from the map draw entries", failures)
	main.selected_unit_id = 0
	main.selected_cell = world.buildings[home]["position"]
	main._update_ui()
	_expect(main.hud.production_detail_label.text.contains("Carpenter #%d" % id) and main.hud.production_detail_label.text.contains("Satiety 50% · Getting hungry"), "A workplace inspector must expose its indoor employee's actual satiety", failures)
	main.free()


static func _test_progressive_meal_details(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(14, 10))
	var home: int = world.place_building("bakery", Vector2i(3, 3))
	var inn: int = world.place_building("inn", Vector2i(8, 3))
	world.buildings[inn]["inputs"]["bread"] = 1
	var id: int = world.spawn_worker(world.buildings[inn]["entrance"], "baker", home)
	world.workers[id]["hunger"] = 100
	world.economy_enabled = true
	var main: Main = _main(world)
	main.selected_unit_id = id
	world.step_tick()
	main._update_ui()
	var initial: float = main.hud._satiety_bar.value
	_expect(main.hud._satiety_timing.text.contains("Eating Bread") and not main.hud._satiety_timing.text.contains("Food needed in"), "An eating person's inspector must show its actual food course instead of a hunger ETA", failures)
	for _tick: int in range(58):
		world.step_tick()
	main._update_ui()
	_expect(main.hud._satiety_bar.value > initial and main.hud._satiety_bar.value < 45.0 and main.hud._satiety_timing.text.contains("5.8 s left at 1× speed"), "Halfway through a real bread course the satiety bar must visibly rise, with remaining time explicitly measured at 1× speed", failures)
	main.selected_unit_id = 0
	main.selected_cell = world.buildings[inn]["position"]
	main._update_ui()
	var details: String = main.hud.production_detail_label.text
	_expect(details.contains("Baker #%d" % id) and details.contains("Satiety") and details.contains("Eating Bread") and details.contains("5.8 s left at 1× speed"), "The Inn inspector must list each actual diner, its satiety, current food and remaining course time at an explicit speed", failures)
	var before: Dictionary = world.to_data()
	for _frame: int in range(5):
		main._update_ui()
	_expect(world.to_data() == before, "Refreshing an eating inspector while paused must not restore extra food or advance its course", failures)
	main.free()


static func _test_shared_hunger_and_supply_summary(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 10))
	var citizen: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(8, 5), "militia")
	world.workers[citizen]["hunger"] = 1620
	world.workers[soldier]["hunger"] = 1000
	world.economy_enabled = true
	var main: Main = _main(world)
	main._update_ui()
	_expect(not main.hud._citizens_label.text.contains("hungry") and not main.hud._supply_army_button.disabled, "A soldier eligible for an early ration must not count as actually hungry before the shared hunger threshold", failures)
	world.workers[citizen]["hunger"] = 360
	world.workers[soldier]["hunger"] = 360
	main._update_ui()
	_expect(main.hud._citizens_label.text.contains("2 hungry"), "The shared hunger threshold must count both civilian and soldier needs consistently", failures)
	main.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
