extends RefCounted

const SessionScene = preload("res://scenes/game_session.tscn")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const WorldClass = preload("res://scripts/simulation/simulation_world.gd")
const ReliefClass = preload("res://scripts/simulation/relief_demo.gd")
const TEST_COUNT: int = 9


# Use the production session and viewport dispatch. Save fixtures are isolated
# from the player's default slot, including when a failure leaves the menu open.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for viewport_size: Vector2i in [Vector2i(1152, 720), Vector2i(1680, 720)]:
		await _test_navigation_and_layout(host, viewport_size, failures)
	for map_id: String in ["test", "relief", "economy"]:
		await _test_map_start(host, map_id, failures)
	await _test_pause_save_and_resume(host, failures)
	await _test_missing_save(host, failures)
	await _test_corrupt_save(host, failures)
	await _test_saved_session(host, failures)
	return failures


static func _test_navigation_and_layout(host: Node, size: Vector2i, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host, size)
	var session: Variant = _session(viewport, "navigation_%d" % size.x)
	await _settle(host)
	var home: Control = _control(session.menu, "HomePage", failures)
	var maps: Control = _control(session.menu, "MapsPage", failures)
	var new_game: Button = _button(session.menu, "NewGameButton", failures)
	var back: Button = _button(session.menu, "BackButton", failures)
	var load_game: Button = _button(session.menu, "LoadGameButton", failures)
	_expect(session.game == null, "Startup must show the menu before creating a simulation", failures)
	_expect(home != null and home.is_visible_in_tree(), "Startup must show the home page", failures)
	_expect(maps != null and not maps.is_visible_in_tree(), "Startup must hide map selection until New game", failures)
	_expect(load_game != null and load_game.disabled, "An absent save must disable the load button", failures)
	_check_layout(session.menu, viewport, ["NewGameButton", "LoadGameButton"], failures)
	if new_game != null and back != null and maps != null and home != null:
		_click(viewport, new_game)
		await _settle(host)
		_expect(maps.is_visible_in_tree() and not home.is_visible_in_tree(),
			"Clicking New game must open map selection", failures)
		_expect(session.game == null, "Browsing maps must not start the simulation", failures)
		_check_layout(session.menu, viewport, ["MapPicker", "StartMapButton", "BackButton"], failures)
		_click(viewport, back)
		await _settle(host)
		_expect(home.is_visible_in_tree() and not maps.is_visible_in_tree(),
			"Back must return to the home page without starting a map", failures)
		_expect(session.game == null, "Back must preserve the session-free home page", failures)
		new_game.grab_focus()
		_key(viewport, KEY_ENTER)
		await _settle(host)
		_expect(maps.is_visible_in_tree(), "Enter must activate the focused New game button", failures)
	_cleanup(viewport, session.save_path, failures)


static func _test_map_start(host: Node, map_id: String, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host)
	var session: Variant = _session(viewport, "map_" + map_id)
	await _settle(host)
	var new_game: Button = _button(session.menu, "NewGameButton", failures)
	if new_game != null:
		_click(viewport, new_game)
		await _settle(host)
	if _select_map(session.menu, map_id, failures):
		var start: Button = _button(session.menu, "StartMapButton", failures)
		if start != null:
			_click(viewport, start)
			await _settle(host)
	_expect(session.game != null, "Starting %s must create a game" % map_id, failures)
	if session.game != null:
		var game: Variant = session.game
		game.set_process(false)
		_expect(game.demo_kind == map_id, "The selected %s map must reach the game" % map_id, failures)
		var expected_size := Vector2i(34, 30) if map_id == "economy" else Vector2i(28, 22)
		_expect(game.world.grid.size == expected_size, "The %s map must use its authored dimensions" % map_id, failures)
		_expect(game.terrain_renderer.grid == game.world.grid, "Starting %s must bind the selected terrain" % map_id, failures)
		_expect(not session.menu.visible, "Starting %s must close the menu" % map_id, failures)
		if map_id == "test":
			_expect(game.world.buildings.size() == 2 and game.world.workers.is_empty(),
				"The starter map must retain only the warehouse and school", failures)
		else:
			_expect(game.world.buildings.size() > 2 and not game.world.workers.is_empty(),
				"The %s demonstration must include its populated village" % map_id, failures)
	_cleanup(viewport, session.save_path, failures)


static func _test_pause_save_and_resume(host: Node, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host)
	var session: Variant = _session(viewport, "pause")
	var default_save_before: String = _default_save_digest()
	session._start_new_game("test")
	await _settle(host)
	if session.game == null:
		failures.append("The pause fixture must start a game")
		_cleanup(viewport, session.save_path, failures)
		return
	var game: Variant = session.game
	game.simulation_speed = 2.0
	game.speed_before_pause = 2.0
	_key(viewport, KEY_ESCAPE)
	await _settle(host)
	_expect(session.menu.visible, "Escape in the game must open the main menu", failures)
	var paused_tick: int = game.world.tick
	var paused_cell: Vector2i = game.selected_cell
	var paused_camera: Vector2 = game.camera.position
	var paused_zoom: Vector2 = game.camera.zoom
	var paused_buildings: int = game.world.buildings.size()
	# Space normally activates a focused menu button. Release menu focus to
	# specifically test that gameplay shortcuts cannot reach the paused world.
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	_key(viewport, KEY_2)
	_key(viewport, KEY_R)
	_key(viewport, KEY_SPACE)
	_click_position(viewport, Vector2(1050, 420))
	_wheel(viewport, Vector2(1050, 420))
	for _frame: int in range(8):
		await host.get_tree().process_frame
	_expect(game.world.tick == paused_tick, "The simulation must stay still while its menu is open", failures)
	_expect(game.world.buildings.size() == paused_buildings and game.selected_cell == paused_cell
		and game.build_mode.is_empty(), "Menu input must not select, build or reset the underlying world", failures)
	_expect(game.camera.position == paused_camera and game.camera.zoom == paused_zoom,
		"Menu input must not move or zoom the underlying camera", failures)
	var save: Button = _button(session.menu, "SaveGameButton", failures)
	var resume: Button = _button(session.menu, "ResumeButton", failures)
	if save != null:
		_click(viewport, save)
		await _settle(host)
		_expect(FileAccess.file_exists(session.save_path), "The menu save button must write the session's save slot", failures)
		var restored := WorldClass.new()
		_expect(SaveSystemClass.load_world(restored, session.save_path) and restored.tick == paused_tick,
			"Saving from the menu must preserve the paused tick", failures)
	if resume != null:
		_click(viewport, resume)
		await _settle(host)
		_expect(not session.menu.visible and session.game == game,
			"Continue must close the menu and keep the same game", failures)
		_expect(game.simulation_speed == 2.0, "Continue must preserve the player's simulation speed", failures)
		game.set_process(false)
		var tick_before: int = game.world.tick
		game._process(0.2)
		_expect(game.world.tick > tick_before, "The continued game must advance again", failures)
	_expect(_default_save_digest() == default_save_before, "Menu fixtures must never overwrite the player's default save", failures)
	_cleanup(viewport, session.save_path, failures)


static func _test_missing_save(host: Node, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host)
	var session: Variant = _session(viewport, "missing")
	await _settle(host)
	# A missing file can race with an earlier menu refresh; the action itself
	# must still fail safely even though its ordinary button is disabled.
	session._load_saved_game()
	await _settle(host)
	_expect(session.game == null and session.menu.visible, "A missing save must leave the player in the menu", failures)
	_check_error(session.menu, failures)
	_expect(not FileAccess.file_exists(session.save_path), "Loading a missing save must not create a replacement file", failures)
	_cleanup(viewport, session.save_path, failures)


static func _test_corrupt_save(host: Node, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host)
	var path: String = _path("corrupt")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Unable to create the corrupt-save fixture")
		viewport.free()
		return
	file.store_string("{broken save")
	file.close()
	var session: Variant = _session(viewport, "corrupt", false)
	await _settle(host)
	var load_game: Button = _button(session.menu, "LoadGameButton", failures)
	if load_game != null and not load_game.disabled:
		_click(viewport, load_game)
	else:
		session._load_saved_game()
	await _settle(host)
	_expect(session.game == null and session.menu.visible, "A corrupt save must leave the player in the menu", failures)
	_check_error(session.menu, failures)
	_expect(FileAccess.get_file_as_string(path) == "{broken save", "Failed loading must leave the original save untouched", failures)
	_cleanup(viewport, path, failures)


static func _test_saved_session(host: Node, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host)
	var path: String = _path("saved")
	var source := WorldClass.new(ReliefClass.MAP_SIZE)
	ReliefClass.setup(source)
	for _tick: int in range(17):
		source.step_tick()
	var stock: Dictionary = source.resource_stock("gold").duplicate(true)
	_expect(SaveSystemClass.save_world(source, path, "relief"), "The saved-session fixture must be writable", failures)
	var session: Variant = _session(viewport, "saved", false)
	await _settle(host)
	var load_game: Button = _button(session.menu, "LoadGameButton", failures)
	_expect(load_game != null and not load_game.disabled, "A saved game must be available from the home page", failures)
	if load_game != null:
		_click(viewport, load_game)
	# Stop processing before the next frame to compare the actual saved state.
	if session.game != null:
		session.game.set_process(false)
	await _settle(host)
	_expect(session.game != null, "Clicking Load game must create the saved session", failures)
	if session.game != null:
		var game: Variant = session.game
		game.set_process(false)
		_expect(game.world.tick == source.tick and game.world.resource_stock("gold") == stock,
			"Loading must restore the saved tick and inventory instead of starting a fresh map", failures)
		_expect(game.demo_kind == "relief", "Loading must retain the save's original map identity", failures)
		_expect(game.terrain_renderer.grid == game.world.grid and not session.menu.visible,
			"The loaded session must display its restored terrain and close the menu", failures)
		game._reset_demo()
		_expect(game.demo_kind == "relief" and game.world.grid.size == ReliefClass.MAP_SIZE
			and game.world.buildings.size() > 2, "Reset after loading must recreate the saved map type", failures)
	_cleanup(viewport, path, failures)


static func _viewport(host: Node, size: Vector2i = Vector2i(1152, 720)) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	return viewport


static func _session(viewport: SubViewport, suffix: String, clear_save: bool = true) -> Variant:
	var session: Variant = SessionScene.instantiate()
	session.honor_launch_arguments = false
	session.save_path = _path(suffix)
	if clear_save and FileAccess.file_exists(session.save_path):
		DirAccess.remove_absolute(session.save_path)
	viewport.add_child(session)
	return session


static func _path(suffix: String) -> String:
	return OS.get_temp_dir().path_join("medieval_economy_menu_%d_%s.json" % [OS.get_process_id(), suffix])


static func _cleanup(viewport: SubViewport, path: String, failures: Array[String]) -> void:
	viewport.free()
	if FileAccess.file_exists(path):
		_expect(DirAccess.remove_absolute(path) == OK, "Menu fixture must clean up its temporary save", failures)
	_expect(not FileAccess.file_exists(path), "No menu save fixture may remain after its test", failures)


static func _default_save_digest() -> String:
	return FileAccess.get_sha256(SaveSystemClass.DEFAULT_PATH) if FileAccess.file_exists(SaveSystemClass.DEFAULT_PATH) else "missing"


static func _control(root: Node, node_name: String, failures: Array[String]) -> Control:
	var control := root.find_child(node_name, true, false) as Control
	_expect(control != null, "Menu requires " + node_name, failures)
	return control


static func _button(root: Node, node_name: String, failures: Array[String]) -> Button:
	return _control(root, node_name, failures) as Button


static func _check_layout(root: Node, viewport: SubViewport, names: Array[String], failures: Array[String]) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(1.0)
	for node_name: String in names:
		var control: Control = _control(root, node_name, failures)
		if control != null:
			_expect(control.is_visible_in_tree() and bounds.encloses(control.get_global_rect()),
				"Menu %s must remain visible within the %s viewport" % [node_name, viewport.size], failures)


static func _check_error(root: Node, failures: Array[String]) -> void:
	var error := _control(root, "ErrorLabel", failures) as Label
	_expect(error != null and error.is_visible_in_tree() and not error.text.strip_edges().is_empty(),
		"Failed loading must explain the problem in the menu", failures)


static func _select_map(root: Node, map_id: String, failures: Array[String]) -> bool:
	var picker := _control(root, "MapPicker", failures) as OptionButton
	var index: int = ["test", "relief", "economy"].find(map_id)
	if picker != null and index >= 0 and index < picker.item_count:
		picker.select(index)
		picker.item_selected.emit(index)
		return true
	failures.append("Map picker must expose the %s scenario" % map_id)
	return false


static func _click(viewport: Viewport, button: Button) -> void:
	_click_position(viewport, button.get_global_rect().get_center())


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


static func _wheel(viewport: Viewport, position: Vector2) -> void:
	# Finish the wheel gesture so injected viewport input does not retain its
	# GUI mouse capture and swallow the later Save/Continue button clicks.
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.position = position
		event.global_position = position
		viewport.push_input(event, true)


static func _key(viewport: Viewport, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
