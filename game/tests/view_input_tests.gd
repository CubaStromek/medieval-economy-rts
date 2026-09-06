extends RefCounted

const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 4 # Pause, training, new professions, field/build shortcuts.


# Run through viewport dispatch, including GUI focus, rather than invoking the
# view's event callbacks or a button's pressed signal directly.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainViewClass = MainScene.instantiate() as MainViewClass
	main.demo_kind = "economy"
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
	# Keep this focused-input fixture independent of material construction and
	# gold payment, both exercised by the full classic economy integration suite.
	main.world.economy_enabled = false
	# Find a genuinely empty full-size school plot in the production demo.
	var school_cell := Vector2i(-1, -1)
	for y: int in range(main.world.grid.size.y):
		for x: int in range(main.world.grid.size.x):
			var candidate := Vector2i(x, y)
			if main.world.can_place_building("school", candidate):
				school_cell = candidate
				break
		if school_cell != Vector2i(-1, -1):
			break
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

	# A fresh queue isolates the new profession buttons from the capacity test.
	school["training_queue"] = []
	school["training_remaining"] = 0
	main._update_ui()
	for profession: String in ["Farmer", "Baker", "Stonemason"]:
		# Queue text changes the inspector's wrapped height after each click.
		# Wait for container layout before scrolling to the next real button.
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var profession_button: Button = _button(main, "Train " + profession)
		if profession_button == null:
			failures.append("School must expose Train " + profession)
			continue
		var ancestor: Node = profession_button.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				(ancestor as ScrollContainer).ensure_control_visible(profession_button)
			ancestor = ancestor.get_parent()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		_click(viewport, profession_button)
	_expect((school["training_queue"] as Array) == ["farmer", "baker", "stonemason"],
		"Actual clicks must enqueue new professions in the chosen order; got %s" % str(school["training_queue"]), failures)
	for entry: Array in [[KEY_6, "quarry"], [KEY_7, "farm"], [KEY_8, "mill"], [KEY_9, "bakery"], [KEY_0, "field"]]:
		_key(viewport, entry[0], true)
		_key(viewport, entry[0], false)
		_expect(main.build_mode == String(entry[1]), "Keyboard must select the %s build tool" % String(entry[1]), failures)
	var field_cell: Vector2i = Vector2i(-1, -1)
	var field_screen: Vector2 = Vector2.ZERO
	for y: int in range(main.world.grid.size.y):
		for x: int in range(main.world.grid.size.x):
			var cell := Vector2i(x, y)
			if not main.world.can_place_field(cell):
				continue
			var screen: Vector2 = viewport.get_canvas_transform() * main.terrain_renderer.to_global(main.terrain_renderer.cell_center(cell))
			if screen.x > 550 and screen.x < 1050 and screen.y > 190 and screen.y < 630:
				field_cell = cell
				field_screen = screen
				break
		if field_cell != Vector2i(-1, -1):
			break
	if field_cell == Vector2i(-1, -1):
		failures.append("Viewport fixture must expose buildable ground outside the HUD")
	else:
		_click_position(viewport, field_screen)
		_expect(main.world.field_id_at(field_cell) != 0,
			"Shortcut 0 followed by a real map click must create a wheat field", failures)
		_expect(main.selected_cell == field_cell, "Field placement must select the prepared cell", failures)
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
	_click_position(viewport, position)


static func _click_position(viewport: Viewport, position: Vector2) -> void:
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
