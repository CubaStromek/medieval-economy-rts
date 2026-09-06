extends RefCounted

const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const RegionScene = preload("res://scenes/mountainous_region.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
const TestLevel = preload("res://scripts/simulation/test_level.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const SaveSystem = preload("res://scripts/simulation/save_system.gd")
const TEST_COUNT: int = 9


# Public tests author their own small map; proprietary external map data is not
# a requirement for importing, running or testing the open-source project.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var fixture_root: String = OS.get_environment("TMPDIR")
	if fixture_root.is_empty():
		fixture_root = "/tmp"
	var fixture_path: String = fixture_root.path_join("terrain-view-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	var file: FileAccess = FileAccess.open(fixture_path, FileAccess.WRITE)
	if file == null:
		failures.append("Imported view fixture must open its own temporary JSON file")
		return failures
	file.store_string(JSON.stringify(_fixture()))
	file.close()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = RegionScene.instantiate() as MainView
	main.terrain_map_path = fixture_path
	main.honor_launch_arguments = false
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.camera.force_update_scroll()
	await _settle(host)
	_test_loaded_scene(main, failures)
	_test_isolated_save_slot(main, failures)
	await _test_save_load_input(host, main, viewport, fixture_path + ".save", failures)
	await _test_reset(host, main, failures)
	await _test_failure(host, main, fixture_path + ".missing", failures)
	await _test_large_fit(host, main, viewport, failures)
	await _test_camera_controls(host, main, viewport, failures)
	await _test_large_map_tree_culling(host, main, viewport, failures)
	viewport.free()
	await _test_default_unchanged(host, failures)
	var removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	_expect(removed == OK, "Imported view suite must remove only its own temporary JSON", failures)
	return failures


static func _fixture() -> Dictionary:
	var heights: Array = []
	for _y: int in range(6):
		heights.append([0, 0, 0, 0, 0, 0, 0])
	return {
		"format": "medieval-terrain-v1",
		"name": "Synthetic terrain view fixture",
		"source": {
			"url": "https://example.test/map",
			"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
			"revision": 11222, "vertex_size": [7, 6], "height_scale": 0.15, "height_offset": 0,
		},
		"map_size": [6, 5],
		"heights": heights,
		"terrain": ["gggggg", "gggggg", "gggggg", "gggggg", "wgddrr"],
		"trees": [[1, 1, 0], [3, 2, 1], [4, 3, 2]],
	}


static func _test_loaded_scene(main: MainView, failures: Array[String]) -> void:
	_expect(main.demo_kind == "mountainous-region" and main.terrain_load_error.is_empty()
		and main.world.grid.size == Vector2i(6, 5),
		"The inherited Mountainous Region scene must load its overridden external terrain file", failures)
	_expect(main.world.workers.is_empty() and main.world.buildings.is_empty()
		and main.world.deposits.is_empty() and main.world.grid.roads.is_empty()
		and main.world.trees.size() == 3,
		"Imported terrain scene must retain trees without silently adding a settlement, deposits or roads", failures)
	_expect(main.world.grid.base_terrain_at(Vector2i(0, 4)) == "water"
		and main.world.grid.base_terrain_at(Vector2i(2, 4)) == "dirt"
		and main.world.grid.base_terrain_at(Vector2i(4, 4)) == "rock",
		"The actual scene must display the loader's terrain categories", failures)


static func _test_isolated_save_slot(main: MainView, failures: Array[String]) -> void:
	_expect(main._save_game_path() == MainView.TERRAIN_STUDY_SAVE_PATH
		and main._save_game_path() != SaveSystem.DEFAULT_PATH,
		"Mountainous Region must use a separate save slot from the normal settlement", failures)
	main.save_path = "res://custom-session-save-never-opened.json"
	_expect(main._save_game_path() == main.save_path,
		"An explicit session save path must take precedence over the landscape default", failures)
	main.save_path_override = "res://custom-scene-save-never-opened.json"
	_expect(main._save_game_path() == main.save_path_override,
		"The scene-specific override must take precedence over a custom session save path", failures)
	main.save_path = SaveSystem.DEFAULT_PATH
	main.save_path_override = ""
	var normal: MainView = MainScene.instantiate() as MainView
	_expect(normal._save_game_path() == SaveSystem.DEFAULT_PATH,
		"Ordinary play must retain its original save location", failures)
	normal.free()


static func _test_save_load_input(host: Node, main: MainView, viewport: SubViewport,
		path: String, failures: Array[String]) -> void:
	# No real user save is opened or written: exercise the exact key dispatch
	# with the scene's isolated save-path override targeting our own fixture.
	main.save_path_override = path
	main.set_process(true) # Paused simulation, but normal UI refresh after F5.
	var before: Dictionary = main.world.to_data()
	_key(viewport, KEY_F5)
	await _settle(host)
	_expect(FileAccess.file_exists(path) and main.event_label.text.contains("Game saved."),
		"F5 through normal viewport dispatch must write the selected isolated save path", failures)
	if FileAccess.file_exists(path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_expect(saved is Dictionary and saved.get("scenario_id") == "mountainous-region",
			"F5 must preserve the imported scenario identity in the new menu metadata", failures)
		if saved is Dictionary:
			saved.erase("scenario_id")
		_expect(saved is Dictionary and saved == JSON.parse_string(JSON.stringify(before)),
			"F5 must save the actual imported world rather than merely acknowledge the key", failures)
	main.world.grid.set_vertex_height(Vector2i(5, 4), 1)
	main.world.tick += 1
	_expect(main.world.to_data() != before,
		"The F9 fixture must first change terrain and simulation time", failures)
	_key(viewport, KEY_F9)
	await _settle(host)
	_expect(main.world.to_data() == before and main.demo_kind == "mountainous-region"
		and main.event_label.text.contains("Game loaded."),
		"F9 through normal viewport dispatch must restore terrain from the same isolated slot", failures)
	main.set_process(false)
	main.save_path_override = ""
	if FileAccess.file_exists(path):
		_expect(DirAccess.remove_absolute(path) == OK,
			"The save-input test must remove only its own temporary save file", failures)


static func _test_reset(host: Node, main: MainView, failures: Array[String]) -> void:
	var saved: Dictionary = main.world.to_data()
	var previous_id: int = main.world.get_instance_id()
	_expect(main.world.grid.set_vertex_height(Vector2i(5, 4), 1),
		"The reset fixture must first genuinely change the imported terrain", failures)
	main._reset_demo()
	main.camera.force_update_scroll()
	await _settle(host)
	_expect(main.demo_kind == "mountainous-region" and main.terrain_load_error.is_empty()
		and main.world.get_instance_id() != previous_id and main.world.to_data() == saved,
		"Reset must reload the selected external terrain instead of reverting to the default test level", failures)


static func _test_failure(host: Node, main: MainView, missing_path: String, failures: Array[String]) -> void:
	main.terrain_map_path = missing_path
	main._reset_demo()
	main.camera.force_update_scroll()
	await _settle(host)
	_expect(main.demo_kind == "test" and not main.terrain_load_error.is_empty()
		and main.world.grid.size == TestLevel.MAP_SIZE,
		"A missing source must explicitly reset the scenario identity and use the existing test level", failures)
	_expect(main.event_label.text.contains("Mountainous Region could not be loaded")
		and main.event_label.text.contains("Showing the test level"),
		"The actual visible HUD must explain missing source data rather than claiming the replica loaded", failures)


static func _test_large_fit(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	# Same dimensions as the source's playable cells, but wholly synthetic data.
	main.world = World.new(Vector2i(143, 127))
	main.world.grid.set_vertex_height(Vector2i(0, 0), 8)
	main.terrain_renderer.bind_grid(main.world.grid)
	main._center_camera()
	main.camera.force_update_scroll()
	await _settle(host)
	var bounds: Rect2 = main.terrain_renderer.map_bounds().grow(44.0)
	var screen_bounds: Rect2 = viewport.get_canvas_transform() * bounds
	var available := Rect2(Vector2(Hud.MAP_LEFT, Hud.MAP_TOP),
		Vector2(viewport.size) - Vector2(Hud.MAP_LEFT + 12.0, Hud.MAP_TOP + Hud.MAP_BOTTOM))
	_expect(main.camera.zoom.x < 0.30 and main.camera.zoom.x > 0.0
		and available.grow(1.0).encloses(screen_bounds),
		"The full 143 by 127 terrain, including raised borders, must fit outside the HUD", failures)
	_expect(screen_bounds.get_center().distance_to(available.get_center()) < 1.0
		and (absf(screen_bounds.size.x - available.size.x) < 1.0
			or absf(screen_bounds.size.y - available.size.y) < 1.0),
		"Large-map overview must be centered and use the available width or height", failures)


static func _test_camera_controls(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	var saved: Dictionary = main.world.to_data()
	var counts: Array[int] = [main.terrain_renderer.geometry_build_count,
		main.terrain_renderer.row_mesh_build_count]
	var fit: float = main.camera.zoom.x
	_wheel(viewport, MOUSE_BUTTON_WHEEL_UP)
	await _settle(host)
	_expect(main.camera.zoom.x > fit,
		"Actual wheel input must zoom into the imported region from its overview", failures)
	for _index: int in range(12):
		_wheel(viewport, MOUSE_BUTTON_WHEEL_DOWN)
	await _settle(host)
	_expect(is_equal_approx(main.camera.zoom.x, fit),
		"Actual wheel input must reach and stop at the large-map overview minimum", failures)
	main._set_zoom(100.0)
	_expect(is_equal_approx(main.camera.zoom.x, 2.4),
		"Imported map support must preserve the existing maximum zoom", failures)
	var position: Vector2 = main.camera.position
	viewport.size = Vector2i(1680, 900)
	await _settle(host)
	_expect(main.camera.position.is_equal_approx(position) and is_equal_approx(main.camera.zoom.x, 2.4),
		"Resizing after manual large-map navigation must preserve the player's framing", failures)
	_expect(main.world.to_data() == saved and counts == [main.terrain_renderer.geometry_build_count,
		main.terrain_renderer.row_mesh_build_count],
		"Large-map camera controls must change neither simulation data nor retained terrain meshes", failures)


static func _test_large_map_tree_culling(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	viewport.size = Vector2i(1152, 720)
	var visible: int = main.world.add_tree(Vector2i(70, 60))
	var caster: int = main.world.add_tree(Vector2i(55, 60))
	var distant: int = main.world.add_tree(Vector2i(4, 5))
	var worker: int = main.world.spawn_worker(Vector2i(5, 5), "carrier")
	main.world.tick = 1000
	main._update_day_lighting()
	main._set_zoom(1.0)
	main.camera.position = main.terrain_renderer.cell_center(Vector2i(70, 60))
	main.camera.force_update_scroll()
	main.queue_redraw()
	await _settle(host)
	var saved: Dictionary = main.world.to_data()
	var full: Array[Dictionary] = main._world_draw_entries()
	var filtered: Array[Dictionary] = main._world_draw_entries(true)
	var full_ids: Array[int] = _tree_ids(full)
	var filtered_ids: Array[int] = _tree_ids(filtered)
	_expect(visible != 0 and caster != 0 and distant != 0 and worker != 0
		and full_ids.size() == 3 and full_ids.has(distant),
		"Large-map culling must retain the uncropped entry API and use genuine tree fixtures", failures)
	var caster_point: Vector2 = viewport.get_canvas_transform() * main.terrain_renderer.cell_center(Vector2i(55, 60))
	_expect(not Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(caster_point)
		and filtered_ids.has(caster) and filtered_ids.has(visible) and not filtered_ids.has(distant),
		"Culling must omit distant trees while retaining a visible tree and an offscreen caster near the edge", failures)
	var retained_worker: bool = false
	for entry: Dictionary in filtered:
		retained_worker = retained_worker or (entry["kind"] == "worker" and int(entry["id"]) == worker)
	var drawn: Array[Dictionary] = []
	for entries: Array in main._row_entries.values():
		drawn.append_array(entries)
	_expect(retained_worker and _tree_ids(drawn) == filtered_ids and main.world.to_data() == saved,
		"The real draw pipeline must apply tree-only filtering without culling citizens or changing simulation", failures)


static func _tree_ids(entries: Array[Dictionary]) -> Array[int]:
	var ids: Array[int] = []
	for entry: Dictionary in entries:
		if entry["kind"] == "tree":
			ids.append(int(entry["id"]))
	return ids


static func _test_default_unchanged(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.camera.force_update_scroll()
	await _settle(host)
	_expect(main.demo_kind == "test" and main.world.grid.size == TestLevel.MAP_SIZE
		and main.world.buildings.size() == 2 and main.world.workers.is_empty(),
		"The normal main scene must still open its unchanged Warehouse and School test level", failures)
	main._set_zoom(0.001)
	_expect(is_equal_approx(main.camera.zoom.x, 0.30),
		"Small maps must retain the familiar 0.30 minimum zoom", failures)
	viewport.free()


static func _key(viewport: SubViewport, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	viewport.push_input(event, true)
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	viewport.push_input(event, true)


static func _wheel(viewport: SubViewport, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = Vector2(900, 410)
	event.global_position = event.position
	viewport.push_input(event, true)


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
