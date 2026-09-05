extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const Main = preload("res://scripts/view/main_view.gd")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_inn_menu_and_real_occupancy(failures)
	_test_soldier_button_dispatch(failures)
	_test_army_button_dispatch(failures)
	_test_catalog_driven_indicators(failures)
	_test_visible_unit_selection(failures)
	_test_delivery_status_and_population(failures)
	return failures


static func _test_inn_menu_and_real_occupancy(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	var citizen: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
	world.workers[citizen]["hunger"] = 100
	world.buildings[inn]["inputs"]["bread"] = 2
	world.economy_enabled = true
	var hud := Hud.new()
	hud.configure(world.catalog)
	var button: Button = hud.find_child("Build_inn", true, false) as Button
	_expect(button != null and button.get_parent() == hud._build_groups["food"], "The Inn must be reachable in the real Food build menu", failures)
	hud._category_buttons[Hud.CATEGORIES.find("food")].pressed.emit()
	_expect((hud._build_groups["food"] as Control).visible and button.tooltip_text.contains("automatically") and button.tooltip_text.contains("carriers"), "The Food category and Inn tooltip must explain automatic meals and carrier supplies", failures)
	var placed: Array[String] = []
	hud.build_mode_requested.connect(func(mode: String) -> void: placed.append(mode))
	button.pressed.emit()
	_expect(placed == ["inn"], "The actual Inn build button must forward its existing placement command", failures)
	for _tick: int in range(100):
		world.step_tick()
		if world.inn_occupied_seats(inn) > 0:
			break
	hud.refresh(world, Vector2i(4, 3), "", 1.0, World.TICK_SECONDS)
	_expect(world.inn_occupied_seats(inn) == 1 and hud.production_detail_label.text.contains("1/6 occupied"), "The selected Inn must show a real eating citizen occupying one of six seats", failures)
	_expect(hud.building_inventory_label.text.contains("Bread: 1") and not hud.building_inventory_label.text.contains("Inventory: empty"), "An Inn's inventory must show its remaining edible input stock after a real meal", failures)
	_expect(hud.production_detail_label.text.contains("%d different foods" % int(world.catalog.economy["max_meals_per_visit"])) and hud.production_detail_label.text.contains("Supply food"), "Inn guidance must explain civilian meals and soldiers' separate supply command", failures)
	hud.free()


static func _main(world: World) -> Main:
	var main := Main.new()
	main.world = world
	main._build_ui()
	return main


static func _test_soldier_button_dispatch(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	var soldier: int = world.spawn_worker(Vector2i(8, 5), "militia")
	var civilian: int = world.spawn_worker(Vector2i(3, 5), "recruit")
	world.economy_enabled = true
	var main: Main = _main(world)
	main.selected_unit_id = soldier
	world.workers[soldier]["hunger"] = 1485
	main._update_ui()
	var button: Button = main.hud.find_child("SupplySoldierFood", true, false) as Button
	_expect(button != null and button.disabled and main.hud._soldier_food_panel.visible, "A selected soldier at exactly 55 percent must show a disabled Supply food button", failures)
	world.workers[soldier]["hunger"] = 1484
	main._update_ui()
	_expect(not button.disabled and button.tooltip_text.contains("restores full satiety"), "Below 55 percent, the real unit button must enable and explain full restoration", failures)
	button.pressed.emit()
	_expect(bool(world.workers[soldier].get("food_requested", false)) and button.disabled, "The real HUD-to-main signal must request the selected soldier once and immediately disable repeated requests", failures)
	_expect(main.hud.production_detail_label.text.contains("Food requested"), "A pending request must remain visible even before a carrier or food is available", failures)
	main.selected_unit_id = civilian
	main._update_ui()
	_expect(not main.hud._soldier_food_panel.visible and not bool(world.workers[civilian].get("food_requested", false)), "A Recruit remains a civilian and must not receive the soldier supply action", failures)
	main.free()


static func _test_army_button_dispatch(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	var low: int = world.spawn_worker(Vector2i(7, 5), "militia")
	var full: int = world.spawn_worker(Vector2i(8, 5), "bowman")
	var citizen: int = world.spawn_worker(Vector2i(3, 5), "carrier")
	world.workers[low]["hunger"] = 1000
	world.workers[full]["hunger"] = 2700
	world.workers[citizen]["hunger"] = 100
	world.economy_enabled = true
	var main: Main = _main(world)
	main._update_ui()
	var button: Button = main.hud.find_child("SupplyArmy", true, false) as Button
	main.hud._category_buttons[Hud.CATEGORIES.find("military")].pressed.emit()
	_expect(button != null and not button.disabled and button.get_parent() == main.hud._build_groups["military"], "Military controls must expose an enabled Supply army command when a soldier needs food", failures)
	button.pressed.emit()
	_expect(bool(world.workers[low].get("food_requested", false)) and not bool(world.workers[full].get("food_requested", false)) and not bool(world.workers[citizen].get("food_requested", false)), "The real global command must supply eligible soldiers only, leaving full soldiers and civilians unchanged", failures)
	_expect(button.disabled, "Supply army must disable when every eligible soldier already has a request", failures)
	main.free()


static func _test_catalog_driven_indicators(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	world.catalog.economy["condition_hungry"] = 200
	world.catalog.economy["soldier_food_request_threshold"] = 1000
	var citizen: int = world.spawn_worker(Vector2i(2, 5), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(8, 5), "militia")
	world.economy_enabled = true
	var main: Main = _main(world)
	world.workers[citizen]["hunger"] = 201
	world.workers[soldier]["hunger"] = 201
	var civil_bar: Dictionary = main.worker_satiety_presentation(world.workers[citizen], Vector2.ZERO)
	var soldier_bar: Dictionary = main.worker_satiety_presentation(world.workers[soldier], Vector2.ZERO)
	_expect(civil_bar["color"] == soldier_bar["color"] and bool(civil_bar["visible"]) and bool(soldier_bar["visible"]), "Civilian and soldier satiety bars must use the same hunger thresholds, separately from military supply eligibility", failures)
	world.workers[citizen]["hunger"] = 200
	world.workers[soldier]["hunger"] = 200
	var hungry: Color = main.worker_satiety_presentation(world.workers[soldier], Vector2.ZERO)["color"]
	_expect(main.worker_satiety_presentation(world.workers[citizen], Vector2.ZERO)["color"] == hungry and hungry != civil_bar["color"], "Both types' visible bars must react at the configured inclusive hungry threshold", failures)
	world.workers[soldier]["food_requested"] = true
	_expect(main._worker_food_marker_color(world.workers[soldier]).a > 0.0 and main.worker_satiety_presentation(world.workers[soldier], Vector2.ZERO)["color"] == hungry, "A requested delivery must add its own indicator while preserving the soldier's real satiety color", failures)
	main.free()


static func _test_visible_unit_selection(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	var soldier: int = world.spawn_worker(Vector2i(8, 5), "militia")
	var main: Main = _main(world)
	main.terrain_renderer = Terrain.new()
	main.add_child(main.terrain_renderer)
	main.terrain_renderer.bind_grid(world.grid)
	var point: Vector2 = main.terrain_renderer.cell_center(Vector2i(8, 5))
	var rect: Rect2 = main.worker_presentation(world.workers[soldier], point)["rect"]
	_expect(main._worker_id_at_visual_position(rect.get_center()) == soldier, "Clicking the actual drawn soldier body must resolve its stable unit ID", failures)
	main.selected_unit_id = soldier
	main._update_ui()
	_expect(main.hud.building_inventory_label.text.contains("Militia #%d" % soldier) and main.hud._satiety_label.text.contains("Satiety"), "Selected unit details must display the actual soldier and satiety instead of the terrain underneath", failures)
	main.free()


static func _test_delivery_status_and_population(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	var store: int = world.place_building("warehouse", Vector2i(2, 2))
	world.buildings[store]["storage"]["bread"] = 1
	var carrier: int = world.spawn_worker(Vector2i(2, 4), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(9, 6), "militia")
	world.workers[soldier]["hunger"] = 1000
	world.economy_enabled = true
	var main: Main = _main(world)
	main.selected_unit_id = soldier
	main._update_ui()
	main.hud._soldier_food_button.pressed.emit()
	_expect(int(world.buildings[store]["storage"]["bread"]) == 1, "The food button must only place an order, never consume food remotely", failures)
	for _tick: int in range(500):
		world.step_tick()
		if (world.workers[carrier].get("ration_delivery", {}) as Dictionary).get("phase", "") == "deliver":
			break
	main._update_ui()
	_expect(main.hud.production_detail_label.text.contains("Food on the way") and main.hud._citizens_label.text.contains("food arriving"), "A real collected ration must update both unit details and the settlement food-arriving status", failures)
	_expect(main.hud._citizens_label.text.contains("1 citizens") and main.hud._citizens_label.text.contains("1 soldiers"), "The settlement overview must count citizens and soldiers separately", failures)
	main.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
