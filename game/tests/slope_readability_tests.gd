extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Demo = preload("res://scripts/simulation/relief_demo.gd")
const TEST_COUNT: int = 8
const MAP_POINTER := Vector2(810, 410)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_square_projection(failures)
	_test_normal_contour_geometry(failures)
	await _test_retained_slope_frames(host, failures)
	await _test_hover_input(host, failures)
	return failures


static func _test_square_projection(failures: Array[String]) -> void:
	_expect(MapProjectionClass.CELL_SIZE == Vector2(40, 40),
		"Unzoomed flat terrain must use an exact 40-by-40-pixel square", failures)
	var grid := Grid.new(Vector2i(8, 6))
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var flat := Vector2i(3, 3)
	var polygon: PackedVector2Array = renderer.cell_polygon(flat)
	_expect(polygon == PackedVector2Array([Vector2(120, 120), Vector2(160, 120),
		Vector2(160, 160), Vector2(120, 160)]),
		"Actual renderer corners, not only a constant, must form a 40-pixel square", failures)
	_expect(renderer.map_bounds() == Rect2(0, 0, 320, 240),
		"Flat map bounds must follow both square-cell axes exactly", failures)
	# A genuine tilted square with a nonplanar TL-BR split exercises both halves.
	_set_corners(grid, flat, [1, 3, 4, 2])
	for uv: Vector2 in [Vector2(0.23, 0.71), Vector2(0.76, 0.28), Vector2(0.5, 0.5)]:
		var coordinate: Vector2 = Vector2(flat) + uv
		var expected: Vector2 = coordinate * Vector2(40, 40) - Vector2(0, grid.height_at(coordinate) * 8.0)
		var actual: Vector2 = renderer.project_grid_position(coordinate - Vector2(0.5, 0.5))
		_expect(actual.is_equal_approx(expected) and renderer.pick_cell(actual) == flat,
			"Square-cell projection and picking must agree on both real sloped triangles", failures)
	renderer.free()


static func _test_normal_contour_geometry(failures: Array[String]) -> void:
	var grid := _contour_grid()
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	_expect(not renderer.show_passability and not renderer.show_buildability,
		"Contour fixture must exercise the normal view without either debug/build overlay", failures)
	var checked: int = 0
	var dark: int = 0
	var light: int = 0
	var actual_mesh_vertices: int = 0
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(2, 4), Vector2i(6, 2)]:
		var contours: Array[Dictionary] = _contours(renderer, cell)
		_expect(not contours.is_empty(), "Both grassy and dirt slopes need real normal-view contour geometry", failures)
		for command: Dictionary in contours:
			var points: PackedVector2Array = command["points"] as PackedVector2Array
			var uvs: PackedVector2Array = command["uvs"] as PackedVector2Array
			var color: Color = (command["colors"] as PackedColorArray)[0]
			_expect(points.size() == 3 and uvs.size() == 3 and color.a >= 0.12 and color.a < 1.0,
				"Normal slope accents must be visible translucent triangles, not a terrain recolor or metadata only", failures)
			if points.size() != 3 or uvs.size() != 3:
				continue
			_expect(absf((uvs[1] - uvs[0]).cross(uvs[2] - uvs[0])) > 0.0000001,
				"Contour ribbon triangles must have actual nonzero area", failures)
			var minimum: float = INF
			var maximum: float = -INF
			var above: bool = false
			var below: bool = false
			for index: int in range(3):
				var uv: Vector2 = uvs[index]
				var height: float = grid.height_at(Vector2(cell) + uv)
				var expected: Vector2 = (Vector2(cell) + uv) * Vector2(40, 40) - Vector2(0, height * 8.0)
				_expect(uv.x >= -0.0001 and uv.x <= 1.0001 and uv.y >= -0.0001 and uv.y <= 1.0001
					and points[index].distance_to(expected) < 0.005,
					"Every contour vertex must remain inside its cell and exactly on the authoritative height mesh", failures)
				above = above or uv.x - uv.y > 0.0001
				below = below or uv.y - uv.x > 0.0001
				minimum = minf(minimum, height)
				maximum = maxf(maximum, height)
				if _retained_has_vertex(renderer, cell.y, points[index]):
					actual_mesh_vertices += 1
			_expect(not (above and below) and maximum - minimum < 0.65,
				"Contour bands must be narrow constant-height accents clipped separately at the TL-BR crease", failures)
			if command["layer"] == "slope_contour":
				dark += 1
			else:
				light += 1
			checked += 1
	_expect(checked >= 8 and dark > 0 and light > 0 and actual_mesh_vertices == checked * 3,
		"Contour checks must reach substantial dark/light geometry present in the actual retained GPU meshes", failures)
	for flat: Vector2i in [Vector2i(0, 6), Vector2i(2, 6)]:
		_expect(grid.cell_slope(flat) == 0 and _contours(renderer, flat).is_empty(),
			"Neither low flat ground nor a flat raised plateau may acquire fake contour steps", failures)
	_expect((renderer._cells[Vector2i(0, 6)]["base_draws"] as Array).size() == 2,
		"The untouched flat-grass control must retain its original two ground triangles", failures)
	_expect(_contours(renderer, Vector2i(9, 2)).is_empty(),
		"Rock slopes must keep their material treatment instead of receiving grassy contour ribbons", failures)
	renderer.free()


static func _test_retained_slope_frames(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var camera := Camera2D.new()
	camera.position = Vector2(240, 180)
	scene.add_child(camera)
	var renderer := Renderer.new()
	renderer.external_painter = true
	scene.add_child(renderer)
	var grid := _contour_grid()
	renderer.bind_grid(grid)
	await _settle(host)
	var draws: int = renderer.row_draw_count
	var builds: int = renderer.row_mesh_build_count
	var base_builds: int = renderer.base_cell_build_count
	var mesh_ids: Array[int] = _mesh_ids(renderer)
	_expect(draws >= grid.size.y and not _contours(renderer, Vector2i(2, 2)).is_empty(),
		"Slope-cache fixture must really render rows containing contour geometry before reuse is tested", failures)
	_expect(renderer.buildability_state(Vector2i(0, 6)) == "level"
		and renderer.buildability_state(Vector2i(2, 6)) == "level"
		and renderer.buildability_state(Vector2i(2, 2)) == "slope"
		and renderer.buildability_state(Vector2i(9, 2)) == "blocked",
		"Build overlay must distinguish level plateaus, walkable slopes and blocked material", failures)
	for frame: int in range(6):
		camera.position += Vector2(2, -1)
		camera.zoom = Vector2.ONE * (0.8 + 0.05 * frame)
		camera.force_update_scroll()
		scene.queue_redraw()
		await host.get_tree().process_frame
	_expect(renderer.row_draw_count == draws and renderer.row_mesh_build_count == builds
		and renderer.base_cell_build_count == base_builds and _mesh_ids(renderer) == mesh_ids,
		"Normal contour geometry and draw commands must remain retained through real camera/dynamic frames", failures)
	renderer.show_buildability = true
	await _settle(host)
	_expect(renderer.row_draw_count == draws + grid.size.y and renderer.row_mesh_build_count == builds
		and _mesh_ids(renderer) == mesh_ids,
		"Showing building hatches must redraw actual rows once without rebuilding contour or road meshes", failures)
	draws = renderer.row_draw_count
	renderer.show_buildability = true
	await _settle(host)
	_expect(renderer.row_draw_count == draws, "An unchanged building-overlay flag must not redraw terrain each frame", failures)
	renderer.show_passability = true
	renderer.show_buildability = false
	await _settle(host)
	_expect(renderer.show_passability and renderer.row_mesh_build_count == builds and _mesh_ids(renderer) == mesh_ids,
		"Leaving automatic build mode must preserve an independent manual overlay and all retained meshes", failures)
	grid.set_vertex_height(Vector2i(3, 3), 3)
	renderer.map_bounds()
	_expect(renderer.base_cell_build_count > base_builds and renderer.base_cell_build_count - base_builds <= 16,
		"Editing an actual slope must invalidate its contour neighborhood without a whole-map rebuild", failures)
	var fresh := Renderer.new()
	fresh.bind_grid(grid)
	for cell: Vector2i in renderer._cells:
		_expect(_contour_geometry(renderer, cell) == _contour_geometry(fresh, cell),
			"After a height edit, retained contour vertices must match a fresh build throughout the map", failures)
	fresh.free()
	viewport.free()


# Five input cases below share a deliberately paused real scene. No helper
# invokes view input callbacks: mouse and keyboard pass through normal dispatch.
static func _test_hover_input(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.demo_kind = "test"
	viewport.add_child(main)
	main.camera.position_smoothing_enabled = false
	main.simulation_speed = 0.0
	# These controls compare terrain/earthwork reasons on a surveyed landscape.
	# Unknown-footprint rejection is exercised independently by the fog suite.
	var surveyed: Array[Vector2i] = []
	for y: int in range(main.world.grid.size.y):
		for x: int in range(main.world.grid.size.x):
			surveyed.append(Vector2i(x, y))
	main.world.fog.restore_explored(surveyed)
	await _settle(host)
	_expect(main.is_processing() and main.world.tick == 0,
		"Paused-input fixture must keep actual Main frames running without advancing the world", failures)
	var label: Label = main.find_child("PlacementPreviewLabel", true, false) as Label
	var overlay: Node2D = main.find_child("PlacementPreview", true, false) as Node2D
	if label == null or overlay == null:
		failures.append("Real scene must expose its placement explanation label and actual preview drawing node")
		viewport.free()
		return
	var draw_observation: Array[int] = [0]
	overlay.draw.connect(func() -> void: draw_observation[0] += 1)
	_key(viewport, KEY_3)
	# Keep the original threshold at (10,3). The revised hut anchor moves left
	# and south; reusing (8,3) would extend its northern row onto the real slope.
	var plateau_site := Vector2i(7, 4)
	await _hover_case(host, main, viewport, label, draw_observation, plateau_site,
		"lumber_hut", true, "level ground", failures)
	_expect(main.terrain_renderer.show_buildability and not main.show_terrain_rules,
		"Choosing a building must automatically show buildability without changing the player's manual F2 choice", failures)
	for cell: Vector2i in main.world.placement_cells("lumber_hut", plateau_site):
		_expect(main.world.grid.cell_slope(cell) == 0
			and main.world.grid.cell_height(cell) == float(Demo.PLATEAU_HEIGHT),
			"Every occupied cell of the valid hover control must stand on the actual flat raised plateau", failures)
	var steep_site := Vector2i(15, 15)
	main.world.grid.set_vertex_height(Vector2i(16, 15), 3)
	await _hover_case(host, main, viewport, label, draw_observation, steep_site,
		"lumber_hut", false, "too uneven", failures)
	_expect(main.world.grid.is_walkable(steep_site) and main.world.grid.cell_slope(steep_site) > 0,
		"Rejected building control must be an otherwise walkable slope", failures)
	var before_rejection: Dictionary = main.world.to_data().duplicate(true)
	_click(viewport, MAP_POINTER)
	await _settle(host)
	var build_body: Control = main.find_child("BuildBody", true, false) as Control
	var inspector: Control = main.find_child("BuildingInspectorScroll", true, false) as Control
	_expect(build_body != null and build_body.is_visible_in_tree()
		and inspector != null and not inspector.is_visible_in_tree(),
		"Clicking a rejected slope must keep the build palette and its explanation open", failures)
	_expect(main.build_mode == "lumber_hut" and main.world.to_data() == before_rejection,
		"Rejected slope clicks must not spend resources, create a site or leave the selected tool", failures)
	# Separate material rejection from the authored ridge's simultaneous slope.
	var rock_cell := Vector2i(14, 18)
	main.world.grid.set_base_terrain(rock_cell, "rock")
	_expect(main.world.grid.cell_slope(rock_cell) == 0,
		"Blocked-material fixture must be flat so it cannot fail for the slope reason", failures)
	await _hover_case(host, main, viewport, label, draw_observation, rock_cell,
		"lumber_hut", false, "blocked", failures)
	_expect(main.world.grid.base_terrain_at(rock_cell) == "rock",
		"Blocked-hover control must reach actual impassable mountain material", failures)
	_key(viewport, KEY_1)
	await _hover_case(host, main, viewport, label, draw_observation, Demo.RAMP,
		"road", true, "road can be placed", failures)
	_expect(not main.terrain_renderer.show_buildability,
		"A road tool must not falsely label walkable slopes as unavailable building sites", failures)
	# Manual F2 remains independent of automatic placement mode in both orders.
	_key(viewport, KEY_F2)
	_key(viewport, KEY_3)
	await _settle(host)
	_expect(main.show_terrain_rules and main.terrain_renderer.show_passability and main.terrain_renderer.show_buildability,
		"Manual terrain rules and automatic building aid must coexist", failures)
	var before: Dictionary = _world_state(main)
	_key(viewport, KEY_ESCAPE)
	await _settle(host)
	_expect(main.build_mode.is_empty() and main.placement_preview.is_empty() and not label.visible
		and not main.terrain_renderer.show_buildability
		and main.show_terrain_rules and main.terrain_renderer.show_passability,
		"Escape must clear tool/preview/automatic hatches while preserving explicitly enabled F2", failures)
	_expect(_world_state(main) == before, "Cancelling a preview must not spend resources, append events or change paused simulation", failures)
	_key(viewport, KEY_3)
	_center_cell_at(main, viewport, Demo.RAMP)
	_motion(viewport, MAP_POINTER)
	await _settle(host)
	_expect(not main.placement_preview.is_empty(), "HUD-clear control must first create a genuine map preview", failures)
	var hud_button: Button = main.find_child("TerrainOverlayToggle", true, false) as Button
	if hud_button == null:
		failures.append("Hover-input fixture requires the real terrain HUD button")
	else:
		before = _world_state(main)
		_motion(viewport, hud_button.get_global_rect().get_center())
		await _settle(host)
		_expect(main.hovered_cell == Vector2i(-1, -1) and main.placement_preview.is_empty()
			and not overlay.visible and label.text.contains("Move onto the map"),
			"Moving onto actual HUD controls must remove map hover/drawing and restore the generic tool hint", failures)
		_expect(_world_state(main) == before, "HUD hover must remain presentation-only", failures)
	_key(viewport, KEY_ESCAPE)
	_key(viewport, KEY_F2)
	_key(viewport, KEY_3)
	_key(viewport, KEY_ESCAPE)
	_expect(not main.show_terrain_rules and not main.terrain_renderer.show_passability
		and not main.terrain_renderer.show_buildability,
		"Escape must also preserve the player's disabled F2 choice", failures)
	viewport.free()


static func _hover_case(host: Node, main: MainView, viewport: SubViewport, label: Label,
		draws: Array[int], cell: Vector2i, tool: String, valid: bool, reason: String,
		failures: Array[String]) -> void:
	_center_cell_at(main, viewport, cell)
	await _settle(host)
	var before: Dictionary = _world_state(main)
	var meshes: Array[int] = _mesh_ids(main.terrain_renderer)
	var builds: int = main.terrain_renderer.row_mesh_build_count
	var draw_before: int = draws[0]
	_motion(viewport, MAP_POINTER + Vector2(1, 1))
	_motion(viewport, MAP_POINTER)
	await _settle(host)
	var preview: Dictionary = main.placement_preview
	_expect(main.hovered_cell == cell and preview.get("cell", Vector2i(-1, -1)) == cell
		and preview.get("tool", "") == tool and preview.get("valid", not valid) == valid,
		"Dispatched " + tool + " hover must preview the actual " + str(cell) + " height-picked cell and validity", failures)
	_expect(String(preview.get("reason", "")).to_lower().contains(reason)
		and label.visible and label.text.to_lower().contains(reason),
		"Preview data and visible HUD must explain " + tool + " placement before clicking (" + reason + ")", failures)
	_expect(int(preview.get("slope", -1)) == main.world.grid.cell_slope(cell)
		and is_equal_approx(float(preview.get("height", -99)), main.world.grid.cell_height(cell)),
		"Hover explanation must report the real terrain height and slope", failures)
	_expect(draws[0] > draw_before,
		"Changing " + tool + " hover must execute the real placement CanvasItem draw callback", failures)
	for frame: int in range(4):
		_motion(viewport, MAP_POINTER + Vector2(float(frame % 2), 0))
		main.queue_redraw()
		await host.get_tree().process_frame
	_expect(_world_state(main) == before,
		"Repeated paused preview must not build, reserve, spend, log events or alter any serialized simulation state", failures)
	_expect(main.terrain_renderer.row_mesh_build_count == builds and _mesh_ids(main.terrain_renderer) == meshes,
		"Mouse preview and dynamic drawing must never rebuild static terrain/road meshes", failures)


# Save payloads deliberately omit transient tasks/reservations and the event
# log; capture them explicitly so "preview is read-only" cannot pass by omission.
static func _world_state(main: MainView) -> Dictionary:
	return {
		"save": main.world.to_data().duplicate(true),
		"events": main.world.event_log.duplicate(),
		"workers": main.world.workers.duplicate(true),
		"tile_reservations": main.world.tile_reservations.duplicate(true),
		"planting_reservations": main.world.planting_reservations.duplicate(true),
		"tasks": main.world.task_board._tasks.duplicate(true),
		"task_sources": main.world.task_board._task_by_source.duplicate(true),
		"next_task": main.world.task_board._next_id,
		"grid_revision": main.world.grid.revision,
		"occupied": main.world.grid.blocked_by.duplicate(true),
	}


static func _contour_grid() -> Grid:
	var grid := Grid.new(Vector2i(12, 8))
	_set_corners(grid, Vector2i(2, 2), [0, 0, 1, 1])
	_set_corners(grid, Vector2i(2, 4), [1, 1, 2, 2])
	_set_corners(grid, Vector2i(6, 2), [0, 2, 3, 1])
	grid.set_base_terrain(Vector2i(6, 2), "dirt")
	_set_corners(grid, Vector2i(2, 6), [4, 4, 4, 4])
	_set_corners(grid, Vector2i(9, 2), [0, 0, 3, 3])
	grid.set_base_terrain(Vector2i(9, 2), "rock")
	return grid


static func _set_corners(grid: Grid, cell: Vector2i, values: Array) -> void:
	for index: int in range(4):
		var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]
		grid.set_vertex_height(cell + offsets[index], int(values[index]))


static func _contours(renderer: Renderer, cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for command: Dictionary in renderer._cells[cell]["base_draws"] as Array:
		if String(command.get("layer", "")).begins_with("slope_contour"):
			result.append(command)
	return result


static func _contour_geometry(renderer: Renderer, cell: Vector2i) -> Array:
	var result: Array = []
	for command: Dictionary in _contours(renderer, cell):
		result.append([command["layer"], command["points"], command["uvs"], command["colors"]])
	return result


static func _retained_has_vertex(renderer: Renderer, row: int, point: Vector2) -> bool:
	for batch: Dictionary in renderer._row_batches[row]["base"] as Array:
		var arrays: Array = (batch["mesh"] as ArrayMesh).surface_get_arrays(0)
		for vertex: Variant in arrays[Mesh.ARRAY_VERTEX]:
			if Vector2(vertex.x, vertex.y).distance_to(point) < 0.005:
				return true
	return false


static func _mesh_ids(renderer: Renderer) -> Array[int]:
	var ids: Array[int] = []
	for row: int in renderer._row_batches:
		for layer: String in ["base", "surface"]:
			for batch: Dictionary in renderer._row_batches[row][layer] as Array:
				ids.append((batch["mesh"] as ArrayMesh).get_instance_id())
	return ids


static func _center_cell_at(main: MainView, viewport: SubViewport, cell: Vector2i) -> void:
	main.camera.zoom = Vector2.ONE
	var world_point: Vector2 = main.terrain_renderer.to_global(main.terrain_renderer.cell_center(cell))
	main.camera.position = world_point - (MAP_POINTER - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()


static func _settle(host: Node) -> void:
	for _frame: int in range(3):
		await host.get_tree().process_frame


static func _motion(viewport: Viewport, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	viewport.push_input(event, true)


static func _click(viewport: Viewport, position: Vector2) -> void:
	_motion(viewport, position)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
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


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
