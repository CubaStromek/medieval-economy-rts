extends RefCounted

const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const SkyClockClass = preload("res://scripts/view/sky_clock.gd")
const TEST_COUNT: int = 5


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainViewClass = MainScene.instantiate() as MainViewClass
	main.demo_kind = "test"
	viewport.add_child(main)
	main.set_process(false)
	main.world.economy_enabled = false
	main.camera.position_smoothing_enabled = false
	await _settle(host)
	var sky: SkyClockClass = main.find_child("SkyClock", true, false) as SkyClockClass
	if sky == null:
		failures.append("The actual game HUD must expose its moving sun and moon")
		viewport.free()
		return failures
	_check_phases(main, sky, failures)
	_check_read_only_preview(main, sky, failures)
	_check_clock_controls(main, sky, failures)
	await _check_layout_and_overlays(host, main, viewport, sky, failures)
	await _check_map_input(host, main, viewport, sky, failures)
	viewport.free()
	return failures


static func _check_phases(main: MainViewClass, sky: SkyClockClass, failures: Array[String]) -> void:
	var sun_positions: Array[Vector2] = []
	for tick: int in [0, 1875, 3749]:
		main.world.tick = tick
		main._update_ui()
		_expect(bool(sky.solar_state["sun_visible"]), "The HUD must show the sun between 05:00 and 20:00", failures)
		sun_positions.append(sky.body_position)
	_expect(sun_positions[0].x < sun_positions[1].x and sun_positions[1].x < sun_positions[2].x
		and sun_positions[1].y < sun_positions[0].y - 25.0 and sun_positions[1].y < sun_positions[2].y - 25.0,
		"The sun must travel east to west and rise above the horizon around midday", failures)
	main.world.tick = 3750
	main._update_ui()
	_expect(not bool(sky.solar_state["sun_visible"]) and sky.body_position.x < sky.size.x * 0.25,
		"At 20:00 the moon must replace the setting sun at the eastern horizon", failures)
	main.world.tick = 4875
	main._update_ui()
	_expect(not bool(sky.solar_state["sun_visible"]) and absf(sky.body_position.x - sky.size.x * 0.5) < 1.0,
		"The moon must also travel across the sky during the night", failures)
	main.world.tick = 6000
	main._update_ui()
	_expect(bool(sky.solar_state["sun_visible"]) and sky.body_position.is_equal_approx(sun_positions[0]),
		"At the next dawn the same visible solar path must begin again", failures)


static func _check_read_only_preview(main: MainViewClass, sky: SkyClockClass, failures: Array[String]) -> void:
	var before: Dictionary = main.world.to_data().duplicate(true)
	main.hud.update_sky_time(900, 0.0)
	var first: Vector2 = sky.body_position
	main.hud.update_sky_time(900, 0.75)
	_expect(sky.body_position.x > first.x, "Fractional world ticks must move the sun smoothly between simulation steps", failures)
	main.hud.update_sky_time(4200, 0.4)
	_expect(not bool(sky.solar_state["sun_visible"]) and main.world.to_data() == before,
		"Previewing sky time must never change units, resources, saves or the authoritative world clock", failures)
	main.accumulator = 0.0
	main._update_ui()
	_expect(bool(sky.solar_state["sun_visible"]), "Refreshing the real world must replace a visual preview with authoritative time", failures)


static func _check_clock_controls(main: MainViewClass, sky: SkyClockClass, failures: Array[String]) -> void:
	main.world.tick = 900
	main.accumulator = 0.0
	main._set_simulation_speed(0.0)
	var paused: Vector2 = sky.body_position
	main._process(0.5)
	_expect(sky.body_position.is_equal_approx(paused) and main.world.tick == 900,
		"Pause must freeze the moving sky along with the world", failures)
	main._set_simulation_speed(2.0)
	main._process(0.025)
	_expect(main.world.tick == 900 and sky.body_position.x > paused.x,
		"At 2× the sky must use the same fractional progress as simulation time", failures)
	var moved: Vector2 = sky.body_position
	main._set_simulation_speed(0.0)
	main._process(0.5)
	_expect(sky.body_position.is_equal_approx(moved), "Pausing between ticks must preserve the exact displayed sun position", failures)


static func _check_layout_and_overlays(host: Node, main: MainViewClass, viewport: SubViewport, sky: SkyClockClass, failures: Array[String]) -> void:
	for viewport_size: Vector2i in [Vector2i(1152, 720), Vector2i(900, 720)]:
		viewport.size = viewport_size
		await _settle(host)
		var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_expect(sky.visible and bounds.encloses(sky.get_global_rect()), "The sky card must fit the actual %s viewport" % viewport_size, failures)
		for panel_name: String in ["OverviewBar", "VillagePanel", "StatusBar", "ActivityPanel"]:
			var panel: Control = main.find_child(panel_name, true, false) as Control
			_expect(not sky.get_global_rect().intersects(panel.get_global_rect()), "The sky must leave %s unobstructed at %s" % [panel_name, viewport_size], failures)
		for tick: int in [0, 1875, 3749, 3750, 4875, 5999]:
			main.hud.update_sky_time(tick)
			_expect(Rect2(Vector2.ZERO, sky.size).grow(-SkyClockClass.BODY_RADIUS).has_point(sky.body_position),
				"Neither sun nor moon may clip against the sky card's edges", failures)
		for toggle_name: String in ["StockpileToggle", "HelpToggle"]:
			var button: Button = main.find_child(toggle_name, true, false) as Button
			_click(viewport, button.get_global_rect().get_center())
			await _settle(host)
			_expect(not sky.visible and button.button_pressed, "Opening %s must hide the decorative sky" % toggle_name, failures)
			_click(viewport, button.get_global_rect().get_center())
			await _settle(host)
			_expect(sky.visible and not button.button_pressed, "Closing %s must restore the sky" % toggle_name, failures)


static func _check_map_input(host: Node, main: MainViewClass, viewport: SubViewport, sky: SkyClockClass, failures: Array[String]) -> void:
	_expect(sky.mouse_filter == Control.MOUSE_FILTER_IGNORE and sky.focus_mode == Control.FOCUS_NONE,
		"The sky display must neither capture map clicks nor steal keyboard focus", failures)
	main._set_build_mode("")
	var target := Vector2i(10, 10)
	var screen: Vector2 = sky.get_global_rect().get_center()
	main.camera.zoom = Vector2.ONE
	var world_position: Vector2 = main.terrain_renderer.to_global(main.terrain_renderer.cell_center(target))
	main.camera.position = world_position - (screen - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()
	await _settle(host)
	main.selected_cell = Vector2i(-999, -999)
	_click(viewport, screen)
	_expect(main.selected_cell == target, "A click through the visible sky card must select the map tile beneath it", failures)


static func _click(viewport: Viewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		viewport.push_input(event, true)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
