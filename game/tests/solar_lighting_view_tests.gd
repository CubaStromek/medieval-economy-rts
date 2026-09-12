extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Shadows = preload("res://scripts/view/solar_shadows.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const TEST_COUNT: int = 8


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	_rebind(main, _world())
	await _settle(host, main)
	_test_palette_is_presentation_only(main, failures)
	_test_actual_speed_and_pause(main, failures)
	await _test_retained_terrain(host, main, failures)
	await _test_hud_canvas(host, main, viewport, failures)
	await _test_indoor_shadow_sources(host, main, failures)
	await _test_ground_projection(host, main, failures)
	_test_load_and_world_replacement(main, failures)
	_test_tangent_shadow_strip(failures)
	viewport.free()
	return failures


static func _test_tangent_shadow_strip(failures: Array[String]) -> void:
	# Captured from the normal relief-map return route, tick 87, worker 24.
	# This exact nonempty row-17 clip caused the native canvas to reject it.
	var tangent := PackedVector2Array([
		Vector2(343.510131835938, 720.0), Vector2(343.394165039062, 720.0),
		Vector2(343.43017578125, 719.996032714844),
	])
	_expect(Geometry2D.triangulate_polygon(tangent).is_empty(),
		"The recorded tangent shadow must reproduce the native triangulation failure", failures)
	var second := PackedVector2Array([
		Vector2(561.1865234375, 640.027465820312), Vector2(560.693969726562, 640.0),
		Vector2(561.454772949219, 640.0),
	])
	for recorded: PackedVector2Array in [tangent, second]:
		var local: PackedVector2Array = Shadows._local_outline(recorded)
		_expect(not Geometry2D.triangulate_polygon(local).is_empty(),
			"Recorded tangent strips must triangulate in local drawing coordinates", failures)
		for index: int in range(recorded.size()):
			_expect(local[index] + recorded[0] == recorded[index],
				"Local drawing and its origin must preserve every actual projected vertex", failures)
	var visible := PackedVector2Array([
		Vector2(343.5, 720.0), Vector2(343.0, 720.0), Vector2(343.2, 719.5),
	])
	_expect(not Geometry2D.triangulate_polygon(Shadows._local_outline(visible)).is_empty(),
		"A nearby visible triangular shadow must remain drawable", failures)
	visible.reverse()
	_expect(not Geometry2D.triangulate_polygon(Shadows._local_outline(visible)).is_empty(),
		"Local shadow drawing must preserve both polygon windings", failures)


static func _world() -> World:
	var world := LegacyFixture.create(Vector2i(14, 10))
	world.place_building("warehouse", Vector2i(4, 3))
	world.add_tree(Vector2i(9, 4))
	world.spawn_worker(Vector2i(7, 6), "carrier")
	return world


static func _rebind(main: MainView, world: World) -> void:
	main.world = world
	main.accumulator = 0.0
	main.simulation_speed = 0.0
	main.selected_unit_id = 0
	main.selected_cell = Vector2i(-1, -1)
	main.terrain_renderer.bind_grid(world.grid)
	main._center_camera()
	main.camera.force_update_scroll()
	main._update_ui()
	main.queue_redraw()


static func _test_palette_is_presentation_only(main: MainView, failures: Array[String]) -> void:
	var palettes: Array[Color] = []
	for tick: int in [0, 1750, 3375, 4750]:
		main.world.tick = tick
		var saved: Dictionary = main.world.to_data()
		var workers: Dictionary = main.world.workers.duplicate(true)
		main._update_ui()
		palettes.append(main.modulate)
		_expect(main.modulate == main.solar_state.get("ambient"),
			"Refreshing the real HUD must immediately apply the clock's ambient light to the map", failures)
		_expect(main.world.to_data() == saved and main.world.workers == workers,
			"Lighting updates must preserve both saved simulation data and transient worker state", failures)
	_expect(palettes[1].get_luminance() > palettes[3].get_luminance() + 0.20
		and palettes[0] != palettes[1] and palettes[2] != palettes[1],
		"The actual scene must show distinguishable dawn, midday, dusk and a darker readable night", failures)


static func _test_actual_speed_and_pause(main: MainView, failures: Array[String]) -> void:
	var samples: Array[Dictionary] = []
	for speed: float in [0.5, 1.0, 2.0]:
		main.world.tick = 125
		main.accumulator = 0.0
		main._set_simulation_speed(speed)
		var before: Dictionary = main.solar_state.duplicate(true)
		main._process(0.025)
		_expect(main.world.tick == 125 and is_equal_approx(main.accumulator, 0.025 * speed)
			and main.solar_state != before,
			"At %s×, actual frame processing must move the sunlight between fixed simulation ticks" % speed, failures)
		samples.append(main.solar_state.duplicate(true))
	_expect(samples[0] != samples[1] and samples[1] != samples[2],
		"Half, normal and double speed must produce different solar movement over the same frame duration", failures)
	main._set_simulation_speed(0.0)
	var frozen: Dictionary = main.solar_state.duplicate(true)
	var saved: Dictionary = main.world.to_data()
	for _frame: int in range(20):
		main._process(0.033)
	_expect(main.solar_state == frozen and main.world.to_data() == saved,
		"Pausing must freeze the partially advanced sun as well as the fixed simulation clock", failures)
	main.accumulator = MainView.FIXED_TICK_SECONDS
	main._update_day_lighting()
	var capped: Dictionary = main.solar_state.duplicate(true)
	main.accumulator = MainView.FIXED_TICK_SECONDS * 100.0
	main._update_day_lighting()
	_expect(main.solar_state == capped,
		"A queued or oversized frame remainder must never extrapolate lighting beyond one simulation tick", failures)
	main.accumulator = 0.0


static func _test_retained_terrain(host: Node, main: MainView, failures: Array[String]) -> void:
	await _settle(host, main)
	var renderer: Node2D = main.terrain_renderer
	var before: Array[int] = _cache_counts(main)
	var meshes: Array[int] = _mesh_ids(main)
	var canvas_ids: Array[int] = []
	for canvas: Node2D in renderer._row_canvases.values():
		canvas_ids.append(canvas.get_instance_id())
	var lit_frames: int = 0
	for frame: int in range(24):
		main.world.tick = frame * 250
		main._update_ui()
		await _settle(host, main)
		if not main._row_shadows.is_empty():
			lit_frames += 1
	_expect(_cache_counts(main) == before and _mesh_ids(main) == meshes,
		"Changing sunlight across a whole day must retain terrain geometry, surfaces and existing mesh instances", failures)
	var after_canvas_ids: Array[int] = []
	for canvas: Node2D in renderer._row_canvases.values():
		after_canvas_ids.append(canvas.get_instance_id())
	_expect(canvas_ids == after_canvas_ids and lit_frames > 5,
		"Lighting frames must reuse retained terrain rows while drawing live object shadows", failures)


static func _test_hud_canvas(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	var probe := ColorRect.new()
	probe.position = Vector2(1090, 95)
	probe.size = Vector2(20, 20)
	probe.color = Color(0.8, 0.5, 0.25)
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.hud.add_child(probe)
	var clock: Label = main.find_child("DayClockLabel", true, false) as Label
	var original_font: Color = clock.get_theme_color("font_color")
	main.world.tick = 1750
	main._update_ui()
	await _settle(host, main)
	var day_pixel: Color = Color.TRANSPARENT
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		day_pixel = viewport.get_texture().get_image().get_pixel(1100, 105)
	main.world.tick = 4750
	main._update_ui()
	await _settle(host, main)
	_expect(main.hud is CanvasLayer and probe.get_canvas() != main.get_canvas()
		and clock.get_canvas() == probe.get_canvas() and probe.modulate == Color.WHITE
		and clock.modulate == Color.WHITE and clock.get_theme_color("font_color") == original_font
		and main.modulate.get_luminance() < 0.8,
		"Night tint must affect the map canvas while the HUD, labels and controls retain their own untinted canvas", failures)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var night_pixel: Color = viewport.get_texture().get_image().get_pixel(1100, 105)
		_expect(day_pixel.a > 0.99 and day_pixel.is_equal_approx(night_pixel),
			"Native rendering must leave an actual HUD color unchanged between midday and midnight", failures)
	probe.free()


static func _test_indoor_shadow_sources(host: Node, main: MainView, failures: Array[String]) -> void:
	var world: World = _world()
	var house: int = int(world.buildings.keys()[0])
	var worker_id: int = world.spawn_worker(world.buildings[house]["entrance"], "builder")
	var worker: Dictionary = world.workers[worker_id]
	world.tick = 750
	_rebind(main, world)
	await _settle(host, main)
	var stale_entry: Dictionary = {}
	for entry: Dictionary in main._world_draw_entries():
		if entry["kind"] == "worker" and int(entry["id"]) == worker_id:
			stale_entry = entry
	_expect(_shadow_worker_ids(main).has(worker_id) and not stale_entry.is_empty(),
		"The shadow fixture must actually cast a shadow for a visible worker at the building doorway", failures)
	_expect(world._enter_worker_building(worker, house),
		"The lighting fixture must enter a real completed building through its doorway", failures)
	_expect(Shadows.rows_for(main.terrain_renderer, stale_entry, main.solar_state).is_empty(),
		"A stale outdoor draw entry must stop generating shadows as soon as its citizen is indoors", failures)
	await _settle(host, main)
	_expect(not _shadow_worker_ids(main).has(worker_id) and not _shadow_worker_ids(main).is_empty(),
		"Actual retained shadow rows must hide the indoor resident while retaining outdoor citizens", failures)
	_expect(world._try_exit_worker_building(worker), "The shadow fixture must exit through its free doorway", failures)
	await _settle(host, main)
	_expect(_shadow_worker_ids(main).has(worker_id),
		"An exiting citizen must regain its shadow through the real scene's redraw pipeline", failures)


static func _test_ground_projection(host: Node, main: MainView, failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(8, 7))
	world.place_building("warehouse", Vector2i(5, 3))
	world.tick = 750
	_rebind(main, world)
	await _settle(host, main)
	var flat_rows: Dictionary = main._row_shadows.duplicate(true)
	_expect(not flat_rows.is_empty(), "The raised-ground test requires a real building shadow", failures)
	for y: int in range(world.grid.size.y + 1):
		for x: int in range(world.grid.size.x + 1):
			world.grid.set_vertex_height(Vector2i(x, y), 1 + x % 3)
	main.terrain_renderer.rebuild()
	await _settle(host, main)
	var warped_points: int = 0
	for row: int in flat_rows:
		var flat_shadows: Array = flat_rows[row]
		var raised_shadows: Array = main._row_shadows.get(row, [])
		_expect(flat_shadows.size() == raised_shadows.size(),
			"Terrain elevation must retain the logical row ownership of each cast shadow", failures)
		for index: int in range(mini(flat_shadows.size(), raised_shadows.size())):
			var flat: PackedVector2Array = flat_shadows[index]["points"]
			var raised: PackedVector2Array = raised_shadows[index]["points"]
			_expect(flat.size() == raised.size(), "Height sampling must retain the outline's ground samples", failures)
			for point_index: int in range(mini(flat.size(), raised.size())):
				var corner_position: Vector2 = flat[point_index] / MapProjectionClass.CELL_SIZE
				var expected: Vector2 = flat[point_index] - Vector2(0.0, world.grid.height_at(corner_position) * MapProjectionClass.HEIGHT_STEP_PIXELS)
				_expect(raised[point_index].distance_to(expected) < 0.001,
					"Every cast-shadow sample must follow the actual nonplanar terrain heightfield", failures)
				warped_points += 1
	_expect(warped_points > 10, "The projection check must sample a full rendered shadow, including its long edges", failures)
	# Force a long diagonal near the map edge to exercise multiple row clips,
	# independent of the current artistic sun path's chosen north/south angle.
	var entry: Dictionary = main._world_draw_entries()[0]
	var clipped: Dictionary = Shadows.rows_for(main.terrain_renderer, entry,
		{"shadow_opacity": 0.3, "shadow_vector": Vector2(8.0, 5.0)})
	_expect(clipped.size() >= 2, "A long diagonal shadow must be split over separate ground rows", failures)
	var map_bounds: Rect2 = main.terrain_renderer.map_bounds().grow(0.01)
	for row: int in clipped:
		_expect(row >= 0 and row < world.grid.size.y, "Clipped shadows must retain only rows inside the map", failures)
		for shadow: Dictionary in clipped[row]:
			for point: Vector2 in shadow["points"]:
				_expect(map_bounds.has_point(point), "Projected shadow strips must stay inside the map's rendered bounds", failures)


static func _test_load_and_world_replacement(main: MainView, failures: Array[String]) -> void:
	var replacement: World = _world()
	replacement.tick = 4750
	_rebind(main, replacement)
	var midnight: Dictionary = main.solar_state.duplicate(true)
	var data: Dictionary = JSON.parse_string(JSON.stringify(replacement.to_data())) as Dictionary
	main.world.tick = 1750
	main._update_ui()
	_expect(main.solar_state != midnight, "Loading fixture must first display a different time of day", failures)
	_expect(main.world.from_data(data), "The real JSON snapshot loader must accept the lighting fixture", failures)
	main.terrain_renderer.bind_grid(main.world.grid)
	main.accumulator = 0.0
	main._update_ui()
	_expect(main.solar_state == midnight and main.modulate == midnight["ambient"]
		and (main.find_child("DayClockLabel", true, false) as Label).text.contains("00:00"),
		"Reloading must immediately synchronize the paused map lighting and visible clock to the saved time", failures)
	var dawn_world: World = _world()
	_rebind(main, dawn_world)
	var dawn_color: Color = main.modulate
	_expect(main.solar_state != midnight and main.world.tick == 0,
		"Replacing the entire world must discard the previous world's nighttime lighting", failures)
	main.world.tick = 4750
	main._update_ui()
	main._reset_demo()
	_expect(main.world.tick == 0 and main.modulate == dawn_color,
		"Resetting a paused game must display the new dawn immediately without waiting for a simulation step", failures)


static func _cache_counts(main: MainView) -> Array[int]:
	return [main.terrain_renderer.geometry_build_count, main.terrain_renderer.base_cell_build_count,
		main.terrain_renderer.surface_cell_build_count, main.terrain_renderer.row_mesh_build_count]


static func _mesh_ids(main: MainView) -> Array[int]:
	var ids: Array[int] = []
	for row: Dictionary in main.terrain_renderer._row_batches.values():
		for layer: String in ["base", "surface"]:
			for batch: Dictionary in row[layer]:
				ids.append((batch["mesh"] as ArrayMesh).get_instance_id())
	return ids


static func _shadow_worker_ids(main: MainView) -> Array[int]:
	var ids: Array[int] = []
	for row: Array in main._row_shadows.values():
		for shadow: Dictionary in row:
			if shadow["kind"] == "worker" and not ids.has(int(shadow["state"]["id"])):
				ids.append(int(shadow["state"]["id"]))
	return ids


static func _settle(host: Node, main: MainView) -> void:
	main.queue_redraw()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
