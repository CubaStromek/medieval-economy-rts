extends RefCounted

const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 2 # Focused pause control; training via mouse and keyboard.


# Run through viewport dispatch, including GUI focus, rather than invoking the
# view's event callbacks or a button's pressed signal directly.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainViewClass = MainScene.instantiate() as MainViewClass
	viewport.add_child(main)
	main.set_process(false)
	await host.get_tree().process_frame
	await host.get_tree().process_frame

	var pause: Button = _button(main, "Pause")
	var train: Button = _button(main, "Train Carrier")
	var school_tool: Button = _button(main, "5  School")
	if pause == null or train == null or school_tool == null:
		failures.append("Input tests require the pause, training and school buttons")
		viewport.free()
		return failures

	_click(viewport, pause)
	_expect(pause.has_focus(), "Clicking Pause should preserve keyboard focus", failures)
	_expect(main.simulation_speed == 0.0, "Pause click should pause the simulation", failures)
	_key(viewport, KEY_SPACE, true)
	_expect(main.simulation_speed == 0.5, "Space press should resume from a focused Pause button", failures)
	for _repeat: int in range(3):
		_key(viewport, KEY_SPACE, true, true)
	_expect(main.simulation_speed == 0.5, "Repeated Space events must not toggle pause again", failures)
	_key(viewport, KEY_SPACE, false)
	_expect(main.simulation_speed == 0.5, "Space release must not reactivate the Pause button", failures)
	_key(viewport, KEY_SPACE, true)
	_expect(main.simulation_speed == 0.0, "The next distinct Space press should pause exactly once", failures)
	_key(viewport, KEY_SPACE, false)
	_expect(main.simulation_speed == 0.0, "Space release must leave the paused state unchanged", failures)

	_click(viewport, school_tool)
	_expect(main.build_mode == "school", "HUD build buttons should route commands to the view", failures)
	var school_cell := Vector2i(1, 1)
	var school_id: int = main.world.place_building("school", school_cell)
	if school_id == 0:
		failures.append("Input tests require a valid school placement")
		viewport.free()
		return failures
	main.selected_cell = school_cell
	main._update_ui()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var school: Dictionary = main.world.buildings[school_id] as Dictionary

	_click(viewport, train)
	_expect(train.has_focus(), "Clicking Train Carrier should preserve keyboard focus", failures)
	_expect(_queue_size(school) == 1, "Mouse click should enqueue one carrier", failures)
	_key(viewport, KEY_SPACE, true)
	_key(viewport, KEY_SPACE, true, true)
	_key(viewport, KEY_SPACE, false)
	_expect(main.simulation_speed == 0.5, "Space should resume while the training button is focused", failures)
	_expect(_queue_size(school) == 1, "Space and its repeats must not enqueue unintended units", failures)
	_key(viewport, KEY_SPACE, true)
	_key(viewport, KEY_SPACE, false)
	_expect(main.simulation_speed == 0.0, "Space should pause again while retaining training focus", failures)
	_expect(_queue_size(school) == 1, "A second Space press must not activate training", failures)

	_key(viewport, KEY_ENTER, true)
	_key(viewport, KEY_ENTER, false)
	_expect(_queue_size(school) == 2, "Enter must still activate the focused training button", failures)
	_expect(main.simulation_speed == 0.0, "Enter activation must not change simulation speed", failures)
	_click(viewport, train)
	_expect(_queue_size(school) == 3, "Mouse training should still work after keyboard interaction", failures)
	viewport.free()
	return failures


static func _button(main: MainViewClass, text: String) -> Button:
	for node: Node in main.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text:
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


static func _key(viewport: Viewport, code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	viewport.push_input(event, true)


static func _queue_size(school: Dictionary) -> int:
	return (school["training_queue"] as Array).size()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
