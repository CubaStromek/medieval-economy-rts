extends RefCounted

const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 4 # Calendar display, actual speed controls, midnight, compact layout.


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
	if main.world == null:
		failures.append("Calendar view fixture must initialize the real simulation world")
		viewport.free()
		return failures
	main.world.economy_enabled = false
	await _settle(host)
	var clock_label: Label = main.find_child("DayClockLabel", true, false) as Label
	if clock_label == null:
		failures.append("The real game scene must expose a calendar clock in its HUD")
		viewport.free()
		return failures
	_check_calendar_display(main, clock_label, failures)
	_check_speed_controls(main, viewport, clock_label, failures)
	_check_midnight(main, clock_label, failures)
	await _check_layout(host, main, viewport, clock_label, failures)
	viewport.free()
	return failures


static func _check_calendar_display(main: MainViewClass, clock_label: Label, failures: Array[String]) -> void:
	# Independent expectations cover every named phase and both sides of dawn/day.
	for sample: Array in [
		[0, "Day 1 · 05:00 · Dawn"],
		[249, "Day 1 · 05:59 · Dawn"],
		[250, "Day 1 · 06:00 · Day"],
		[3250, "Day 1 · 18:00 · Dusk"],
		[3750, "Day 1 · 20:00 · Night"],
		[6000, "Day 2 · 05:00 · Dawn"],
	]:
		main.world.tick = int(sample[0])
		main._update_ui()
		_expect(clock_label.text == String(sample[1]),
			"Calendar HUD at tick %d must show %s; got %s" % [int(sample[0]), String(sample[1]), clock_label.text], failures)
	_expect(clock_label.tooltip_text.contains("Full day/night cycle: 10 minutes at 1×."),
		"Clock tooltip must explain the full 24-hour cycle's ten-minute duration at 1×", failures)
	_expect(clock_label.tooltip_text.contains("Elapsed simulation time: 00:10:00"),
		"The previous elapsed-time information must remain available separately from calendar time", failures)
	_expect(clock_label.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"Clock must accept pointer hover so its timing tooltip is actually reachable", failures)


static func _check_speed_controls(main: MainViewClass, viewport: SubViewport, clock_label: Label, failures: Array[String]) -> void:
	# Every sample simulates 60 seconds of frame time through the real view loop.
	# No unusually large delta may mask the existing per-frame catch-up limit.
	for sample: Array in [
		["Pause", 0.0, 0, "Day 1 · 05:00 · Dawn", "Simulation paused"],
		["0.5×", 0.5, 300, "Day 1 · 06:12 · Day", "Simulation speed: 0.5×"],
		["1×", 1.0, 600, "Day 1 · 07:24 · Day", "Simulation speed: 1.0×"],
		["2×", 2.0, 1200, "Day 1 · 09:48 · Day", "Simulation speed: 2.0×"],
	]:
		main.world.tick = 0
		main.accumulator = 0.0
		var speed_button: Button = _button(main, String(sample[0]))
		if speed_button == null:
			failures.append("Calendar test requires the real " + String(sample[0]) + " speed button")
			continue
		_click(viewport, speed_button)
		_expect(is_equal_approx(main.simulation_speed, float(sample[1])) and speed_button.button_pressed,
			"The %s button must select its actual simulation speed" % String(sample[0]), failures)
		for _frame: int in range(600):
			main._process(0.1)
		_expect(main.world.tick == int(sample[2]),
			"60 seconds at %s must advance %d ticks; got %d" % [String(sample[0]), int(sample[2]), main.world.tick], failures)
		_expect(clock_label.text == String(sample[3]),
			"Clock after 60 seconds at %s must show %s; got %s" % [String(sample[0]), String(sample[3]), clock_label.text], failures)
		_expect(clock_label.tooltip_text.contains(String(sample[4])),
			"Clock tooltip must reflect the selected %s speed" % String(sample[0]), failures)


static func _check_midnight(main: MainViewClass, clock_label: Label, failures: Array[String]) -> void:
	main.world.tick = 4749
	main.accumulator = 0.0
	main._set_simulation_speed(1.0)
	_expect(clock_label.text == "Day 1 · 23:59 · Night", "HUD must display the final minute of day one", failures)
	main._process(0.1)
	_expect(main.world.tick == 4750 and clock_label.text == "Day 2 · 00:00 · Night",
		"A real view tick crossing midnight must advance the calendar day while retaining the Night phase", failures)
	main._set_simulation_speed(0.0)
	main._process(0.7)
	_expect(main.world.tick == 4750 and clock_label.text == "Day 2 · 00:00 · Night",
		"Pausing at midnight must freeze both the world and the visible calendar", failures)


static func _check_layout(host: Node, main: MainViewClass, viewport: SubViewport, clock_label: Label, failures: Array[String]) -> void:
	# A four-digit day exercises more than the short startup label.
	main.world.tick = 999 * 6000 + 4749
	main._update_ui()
	for viewport_size: Vector2i in [Vector2i(1152, 720), Vector2i(900, 720)]:
		viewport.size = viewport_size
		await _settle(host)
		var status: Control = main.find_child("StatusBar", true, false) as Control
		if status == null:
			failures.append("Calendar layout requires the status bar")
			return
		var window_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var status_rect: Rect2 = status.get_global_rect()
		_expect(window_rect.encloses(status_rect),
			"Status bar with calendar must fit at %s" % viewport_size, failures)
		_expect(status_rect.encloses(clock_label.get_global_rect()),
			"Calendar must stay inside the status bar at %s" % viewport_size, failures)
		var font: Font = clock_label.get_theme_font("font")
		var font_size: int = clock_label.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(clock_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		_expect(clock_label.size.x >= text_width and clock_label.get_line_count() == 1,
			"Day, time and phase must remain readable on one line at %s" % viewport_size, failures)
		for node: Node in status.find_children("*", "Button", true, false):
			var button: Button = node as Button
			_expect(status_rect.encloses(button.get_global_rect()),
				"Calendar must leave %s reachable at %s" % [button.text, viewport_size], failures)
			_expect(not button.get_global_rect().intersects(clock_label.get_global_rect()),
				"Calendar must not overlap %s at %s" % [button.text, viewport_size], failures)


static func _button(main: MainViewClass, text_value: String) -> Button:
	for node: Node in main.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text_value:
			return button
	return null


static func _click(viewport: Viewport, button: Button) -> void:
	var position: Vector2 = button.get_global_rect().get_center()
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
