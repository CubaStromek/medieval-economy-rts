extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 8


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_unchanged_and_transforms(failures)
	_test_wear_and_road_neighbors(failures)
	_test_base_transitions(failures)
	_test_shared_height_and_removed_roads(failures)
	_test_definition_and_rebind(failures)
	_test_untracked_and_manual_invalidation(failures)
	_test_retained_mesh_contents_and_order(failures)
	await _test_retained_frames(host, failures)
	return failures


static func _test_unchanged_and_transforms(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(12, 10))
	grid.add_road(Vector2i(6, 5))
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var builds: int = renderer.geometry_build_count
	var base_builds: int = renderer.base_cell_build_count
	var surface_builds: int = renderer.surface_cell_build_count
	var row_builds: int = renderer.row_mesh_build_count
	var base_meshes: Dictionary = _mesh_ids(renderer, "base")
	var surface_meshes: Dictionary = _mesh_ids(renderer, "surface")
	var revision: int = grid.revision
	var snapshot: Dictionary = _command_snapshot(renderer)
	for index: int in range(20):
		# Camera panning and zoom alter only the CanvasItem transform. Geometry
		# must remain in map coordinates and must never be resubmitted for it.
		renderer.position = Vector2(index * 3.5, -index * 2.0)
		renderer.scale = Vector2.ONE * (0.7 + float(index) / 20.0)
		renderer._process(1.0 / 60.0)
		renderer.cell_polygon(Vector2i(6, 5))
		renderer.pick_cell(renderer.cell_center(Vector2i(6, 5)))
		renderer.map_bounds()
	_expect(renderer.geometry_build_count == builds,
		"Panning, zooming and unchanged frame queries must not rebuild cached terrain", failures)
	_expect(renderer.base_cell_build_count == base_builds and renderer.surface_cell_build_count == surface_builds
		and renderer.row_mesh_build_count == row_builds and _mesh_ids(renderer, "base") == base_meshes
		and _mesh_ids(renderer, "surface") == surface_meshes,
		"Unchanged frames and presentation transforms must retain actual row mesh objects in both layers", failures)
	_expect(_command_snapshot(renderer) == snapshot and grid.revision == revision,
		"Presentation transforms must preserve exact map-space geometry and simulation state", failures)
	renderer.free()


static func _test_wear_and_road_neighbors(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(14, 12))
	grid.configure_movement({"trail": {"carrier_passes_to_form": 36}})
	var center := Vector2i(7, 6)
	grid.add_road(center + Vector2i.LEFT)
	grid.add_road(center + Vector2i.UP)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var before_neighbor: Array = _cell_commands(renderer, center + Vector2i.LEFT)
	var base_builds: int = renderer.base_cell_build_count
	var surface_builds: int = renderer.surface_cell_build_count
	var row_builds: int = renderer.row_mesh_build_count
	var base_meshes: Dictionary = _mesh_ids(renderer, "base")
	var surface_meshes: Dictionary = _mesh_ids(renderer, "surface")
	grid.record_carrier_traffic(center)
	_assert_matches_fresh(renderer, "First footstep", failures)
	_expect(renderer.base_cell_build_count == base_builds and _mesh_ids(renderer, "base") == base_meshes,
		"One footstep must preserve every cached base-terrain triangle and GPU mesh", failures)
	var changed_cells: int = renderer.surface_cell_build_count - surface_builds
	var changed_rows: int = renderer.row_mesh_build_count - row_builds
	_expect(changed_cells > 0 and changed_cells <= 9 and changed_rows > 0 and changed_rows <= 3,
		"One footstep may refresh only its eight-neighbor surface neighborhood and at most three surface rows", failures)
	var refreshed_surface_meshes: Dictionary = _mesh_ids(renderer, "surface")
	for row: int in surface_meshes:
		if absi(row - center.y) > 1:
			_expect(surface_meshes[row] == refreshed_surface_meshes[row],
				"A footstep must preserve surface mesh identities on unrelated distant rows", failures)
	_expect(not _has_layer(renderer, center, "wear") and grid.overlay_at(center).is_empty(),
		"An isolated first footstep must leave grass visually untouched", failures)
	grid.set_traffic_wear(center, 12)
	_assert_matches_fresh(renderer, "Growing partial wear", failures)
	_expect(_has_layer(renderer, center, "wear") and grid.overlay_at(center).is_empty(),
		"Repeated subthreshold traffic must eventually produce a faint wear patch without a full trail", failures)
	grid.set_traffic_wear(center, 0)
	_assert_matches_fresh(renderer, "Removed partial wear", failures)
	_expect(not _has_layer(renderer, center, "wear"),
		"Resetting partial wear must remove its cached surface triangles", failures)
	grid.add_dirt_trail(center)
	_assert_matches_fresh(renderer, "Trail connection", failures)
	_expect(_cell_commands(renderer, center + Vector2i.LEFT) != before_neighbor,
		"Joining a trail must actually extend the previously isolated neighboring road", failures)
	grid.add_road(center)
	_assert_matches_fresh(renderer, "Trail upgraded to stone", failures)
	_expect(_has_layer(renderer, center, "road_core") and not _has_layer(renderer, center, "trail_core"),
		"Paving must replace the dirt core and retain neighboring connections", failures)
	grid.block(center, 901)
	_assert_matches_fresh(renderer, "Blocked former junction", failures)
	_expect(renderer.surface_connection_mask_for(center + Vector2i.LEFT) == 0,
		"Placing a building over a junction must remove the neighboring road arm", failures)
	_expect(renderer.base_cell_build_count == base_builds and _mesh_ids(renderer, "base") == base_meshes,
		"Wear, trail formation, paving and occupancy-only changes must all leave base terrain retained", failures)
	renderer.free()


static func _test_base_transitions(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(14, 12))
	var center := Vector2i(7, 6)
	grid.add_road(center)
	grid.add_road(center + Vector2i.RIGHT)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var diagonal: Vector2i = center + Vector2i(-1, -1)
	var before_diagonal: Array = _cell_commands(renderer, diagonal)
	var base_builds: int = renderer.base_cell_build_count
	grid.set_base_terrain(center, "water")
	_assert_matches_fresh(renderer, "Water replacing a road", failures)
	_expect(renderer.base_cell_build_count - base_builds > 0 and renderer.base_cell_build_count - base_builds <= 9,
		"One material change must refresh at most its 3-by-3 base transition neighborhood", failures)
	_expect(_cell_commands(renderer, diagonal) != before_diagonal,
		"A base-terrain edit must refresh the diagonal corner blend, not only cardinal neighbors", failures)
	_expect(not _has_layer(renderer, center, "road_core"),
		"Changing a paved tile to water must remove the old cached road", failures)
	grid.set_base_terrain(center + Vector2i.RIGHT, "rock")
	_assert_matches_fresh(renderer, "Adjacent higher-priority terrain", failures)
	grid.set_base_terrain(center, "grass")
	_assert_matches_fresh(renderer, "Terrain transition removed", failures)
	renderer.free()


static func _test_shared_height_and_removed_roads(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(14, 12))
	var vertex := Vector2i(7, 6)
	var removed_road := Vector2i(6, 5)
	var surviving_road := Vector2i(5, 5)
	grid.add_road(removed_road)
	grid.add_road(surviving_road)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var old_arm: Array = _cell_commands(renderer, surviving_road)
	var base_builds: int = renderer.base_cell_build_count
	grid.set_vertex_height(vertex, 6)
	_assert_matches_fresh(renderer, "Shared raised vertex", failures)
	_expect(renderer.base_cell_build_count - base_builds > 0 and renderer.base_cell_build_count - base_builds <= 16,
		"One shared vertex must not force a whole-map base rebuild", failures)
	_expect(grid.overlay_at(removed_road).is_empty() and grid.overlay_at(surviving_road) == Grid.OVERLAY_STONE_ROAD,
		"Height fixture must remove an affected steep road while leaving the next road outside the shared corner", failures)
	_expect(_cell_commands(renderer, surviving_road) != old_arm,
		"Height invalidation must also update the arm on a surviving road beyond its four directly affected cells", failures)
	grid.set_vertex_height(Vector2i(0, 0), 20)
	_assert_matches_fresh(renderer, "Raised map boundary", failures)
	_expect(is_equal_approx(renderer.map_bounds().position.y, -160.0),
		"Incremental height changes must expand camera bounds beyond the original flat map", failures)
	grid.set_vertex_height(Vector2i(0, 0), 0)
	_assert_matches_fresh(renderer, "Lowered map boundary", failures)
	_expect(is_equal_approx(renderer.map_bounds().position.y, 0.0),
		"Lowering the extreme height must shrink bounds instead of keeping stale map extents", failures)
	renderer.free()


static func _test_definition_and_rebind(failures: Array[String]) -> void:
	var world := World.new(Vector2i(10, 8))
	world.grid.add_road(Vector2i(6, 5))
	world.grid.set_base_terrain(Vector2i(5, 5), "water")
	world.grid.set_vertex_height(Vector2i(1, 1), 2)
	var renderer := Renderer.new()
	renderer.external_painter = true
	renderer.bind_grid(world.grid)
	var old_texture: Texture2D = renderer._textures["grass"] as Texture2D
	var old_pixel: Color = old_texture.get_image().get_pixel(0, 0)
	var base_builds: int = renderer.base_cell_build_count
	var surface_builds: int = renderer.surface_cell_build_count
	world.grid.configure_movement({"terrain": {"grass": {"color": "a03050", "transition_priority": 99}}})
	_assert_matches_fresh(renderer, "Changed texture and transition definitions", failures)
	_expect(renderer.base_cell_build_count - base_builds == 80 and renderer.surface_cell_build_count - surface_builds == 80,
		"Definition changes must rebuild both layers for the complete map", failures)
	var new_texture: Texture2D = renderer._textures["grass"] as Texture2D
	_expect(new_texture != old_texture and new_texture.get_image().get_pixel(0, 0) != old_pixel,
		"Definition invalidation must replace the actual texture pixels, not only acknowledge its revision", failures)
	var restored := World.new()
	_expect(restored.from_data(JSON.parse_string(JSON.stringify(world.to_data()))),
		"Renderer rebind fixture must load a genuine serialized world", failures)
	renderer.bind_grid(restored.grid)
	_assert_matches_fresh(renderer, "Loaded replacement grid", failures)
	var smaller := Grid.new(Vector2i(2, 3))
	renderer.bind_grid(smaller)
	_assert_matches_fresh(renderer, "Smaller replacement map", failures)
	_expect(renderer._cells.size() == 6 and renderer.cell_polygon(Vector2i(6, 5)).is_empty(),
		"Rebinding a smaller map must discard stale cells outside the new dimensions", failures)
	_expect(renderer._row_batches.size() == 3 and renderer._row_canvases.size() == 3,
		"Rebinding must discard old retained mesh rows and their drawing nodes", failures)
	var retained_meshes: Dictionary = _mesh_ids(renderer, "base")
	renderer.external_painter = false
	_expect(renderer._row_canvases.is_empty(), "Standalone painting must remove the layered row canvases", failures)
	renderer.external_painter = true
	_expect(renderer._row_canvases.size() == 3 and _mesh_ids(renderer, "base") == retained_meshes,
		"Changing painting mode after binding must restore rows without rebuilding their meshes", failures)
	renderer.bind_grid(null)
	_expect(renderer._cells.is_empty() and renderer.map_bounds() == Rect2(),
		"Unbinding must clear the old map and reset its bounds", failures)
	_expect(renderer._row_batches.is_empty() and renderer._row_canvases.is_empty(),
		"Unbinding must remove retained rendering batches and row nodes", failures)
	renderer.free()


static func _test_untracked_and_manual_invalidation(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(10, 8))
	var cell := Vector2i(5, 4)
	grid.add_road(cell)
	grid.add_road(cell + Vector2i.RIGHT)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	# Old editor/tests still mutate public dictionaries and revision directly.
	# An incomplete journal must fail safely to a full refresh, not hide edits.
	grid.roads.erase(cell)
	grid.revision += 1
	_assert_matches_fresh(renderer, "Untracked revision edit", failures)
	_expect(not _has_layer(renderer, cell, "road_core"),
		"Untracked grid edits must not leave a cached stone road visible", failures)
	grid.roads[cell] = true
	renderer.invalidate_cell(cell)
	_assert_matches_fresh(renderer, "Explicit cell invalidation without a revision", failures)
	_expect(_has_layer(renderer, cell, "road_core"),
		"Explicit cell invalidation must refresh legacy edits even if no grid revision changed", failures)
	renderer.free()


static func _test_retained_mesh_contents_and_order(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(6, 4))
	grid.set_base_terrain(Vector2i(2, 1), "water")
	grid.set_base_terrain(Vector2i(4, 2), "rock")
	grid.set_vertex_height(Vector2i(1, 2), 1)
	grid.set_vertex_height(Vector2i(2, 2), 2)
	grid.set_vertex_height(Vector2i(2, 3), 3)
	grid.add_road(Vector2i(1, 2))
	grid.add_dirt_trail(Vector2i(2, 2))
	grid.add_road(Vector2i(3, 2))
	var renderer := Renderer.new()
	renderer.external_painter = true
	renderer.bind_grid(grid)
	var repeated_texture_run: bool = false
	var checked_triangles: int = 0
	for row: int in range(grid.size.y):
		var row_canvas: Node2D = renderer._row_canvases[row] as Node2D
		_expect(row_canvas.z_index == row * 2,
			"Retained terrain row depth must leave the following odd depth for dynamic objects", failures)
		_expect(row_canvas.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED,
			"Retained row canvases must repeat the world-space road UVs", failures)
		for layer: String in ["base", "surface"]:
			var commands: Array[Dictionary] = []
			for column: int in range(grid.size.x):
				var cell_data: Dictionary = renderer._cells[Vector2i(column, row)] as Dictionary
				for command: Dictionary in cell_data[layer + "_draws"] as Array:
					commands.append(command)
			var expected_runs: Array[Dictionary] = []
			var seen_textures: Array[Texture2D] = []
			for command: Dictionary in commands:
				var texture: Texture2D = command["texture"] as Texture2D
				if expected_runs.is_empty() or expected_runs.back()["texture"] != texture:
					repeated_texture_run = repeated_texture_run or texture in seen_textures
					seen_textures.append(texture)
					expected_runs.append({"texture": texture, "commands": []})
				(expected_runs.back()["commands"] as Array).append(command)
			var batches: Array = (renderer._row_batches[row] as Dictionary)[layer] as Array
			_expect(batches.size() == expected_runs.size(),
				"Batching must merge exactly contiguous equal-texture runs without reordering separated A-B-A layers", failures)
			for batch_index: int in range(mini(batches.size(), expected_runs.size())):
				var batch: Dictionary = batches[batch_index] as Dictionary
				var expected: Dictionary = expected_runs[batch_index]
				_expect(batch["texture"] == expected["texture"],
					"Each retained batch must use the texture at its original painter position", failures)
				checked_triangles += _check_batch_mesh(batch, expected["commands"] as Array, failures)
	_expect(repeated_texture_run and checked_triangles > 100,
		"Mesh-order fixture must actually exercise separated repeated textures and substantial road/transition geometry", failures)
	renderer.free()


static func _check_batch_mesh(batch: Dictionary, commands: Array, failures: Array[String]) -> int:
	var mesh: ArrayMesh = batch["mesh"] as ArrayMesh
	var modulation: Color = batch.get("modulate", Color.WHITE) as Color
	if mesh == null or mesh.get_surface_count() != 1:
		failures.append("Each retained terrain batch must contain one actual readable mesh surface")
		return 0
	_expect(mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES,
		"Retained terrain batches must use explicit triangles, including folded slopes", failures)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var count: int = vertices.size() if indices.is_empty() else indices.size()
	_expect(count == commands.size() * 3,
		"Retained batches must contain every original triangle exactly once", failures)
	if count != commands.size() * 3 or colors.size() != vertices.size() or uvs.size() != vertices.size():
		failures.append("Retained mesh vertex, UV and color arrays must cover the whole original stream")
		return 0
	var ordinal: int = 0
	for command: Dictionary in commands:
		var expected_points: PackedVector2Array = command["points"] as PackedVector2Array
		var expected_uvs: PackedVector2Array = command["texture_uvs"] as PackedVector2Array
		var expected_colors: PackedColorArray = command["colors"] as PackedColorArray
		for corner: int in range(3):
			var index: int = ordinal if indices.is_empty() else indices[ordinal]
			var actual_point := Vector2(vertices[index].x, vertices[index].y)
			var expected_color: Color = expected_colors[0] if expected_colors.size() == 1 else expected_colors[corner]
			_expect(actual_point.is_equal_approx(expected_points[corner]) and uvs[index].is_equal_approx(expected_uvs[corner]),
				"Actual retained mesh vertices and UVs must preserve original triangle and painter order", failures)
			var restored_color: Color = colors[index] * modulation
			var rgb_tolerance: float = maxf(modulation.r, maxf(modulation.g, modulation.b)) / 255.0 + 0.00001
			_expect(absf(restored_color.r - expected_color.r) <= rgb_tolerance
				and absf(restored_color.g - expected_color.g) <= rgb_tolerance
				and absf(restored_color.b - expected_color.b) <= rgb_tolerance
				and absf(restored_color.a - expected_color.a) <= 1.0 / 255.0 + 0.00001,
				"Actual mesh color times its draw modulation must preserve shading within one GPU color step", failures)
			if maxf(expected_color.r, maxf(expected_color.g, expected_color.b)) > 1.01:
				_expect(maxf(restored_color.r, maxf(restored_color.g, restored_color.b)) > 1.0,
					"Highlights above one must survive the mesh color format instead of being silently clamped", failures)
			ordinal += 1
	return commands.size()


static func _test_retained_frames(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var camera := Camera2D.new()
	camera.position = Vector2(280, 170)
	scene.add_child(camera)
	var grid := Grid.new(Vector2i(10, 8))
	grid.add_road(Vector2i(4, 4))
	var renderer := Renderer.new()
	renderer.external_painter = true
	scene.add_child(renderer)
	renderer.bind_grid(grid)
	for _frame: int in range(3):
		await host.get_tree().process_frame
	var draws: int = renderer.row_draw_count
	var builds: int = renderer.row_mesh_build_count
	_expect(draws >= grid.size.y,
		"Retained frame fixture must actually draw every terrain row before testing reuse", failures)
	for frame: int in range(8):
		camera.position += Vector2(3, -2)
		camera.zoom = Vector2.ONE * (0.8 + float(frame) * 0.04)
		camera.force_update_scroll()
		# Repainting the dynamic parent must not repaint its retained ground.
		scene.queue_redraw()
		await host.get_tree().process_frame
	_expect(renderer.row_draw_count == draws and renderer.row_mesh_build_count == builds,
		"Real rendered frames with moving/zooming camera and dynamic parent redraws must not resubmit terrain rows", failures)
	grid.record_carrier_traffic(Vector2i(5, 4))
	for _frame: int in range(3):
		await host.get_tree().process_frame
	_expect(renderer.row_draw_count > draws and renderer.row_draw_count - draws <= 3,
		"One changed trail tile must actually redraw only the affected three retained rows", failures)
	builds = renderer.row_mesh_build_count
	draws = renderer.row_draw_count
	renderer.show_passability = true
	for _frame: int in range(3):
		await host.get_tree().process_frame
	_expect(renderer.row_draw_count == draws + grid.size.y and renderer.row_mesh_build_count == builds,
		"Passability toggle must redraw all debug overlays without regenerating either terrain mesh layer", failures)
	draws = renderer.row_draw_count
	grid.block(Vector2i(1, 1), 902)
	for _frame: int in range(3):
		await host.get_tree().process_frame
	_expect(renderer.row_draw_count > draws and renderer.row_draw_count - draws <= 3,
		"Occupancy must visibly refresh the enabled passability overlay only near the changed tile", failures)
	viewport.free()


static func _mesh_ids(renderer: Renderer, layer: String) -> Dictionary:
	var result: Dictionary = {}
	for row: int in renderer._row_batches:
		var ids: Array[int] = []
		for batch: Dictionary in (renderer._row_batches[row] as Dictionary)[layer] as Array:
			ids.append((batch["mesh"] as ArrayMesh).get_instance_id())
		result[row] = ids
	return result


# Rebuilding a separate renderer is the deliberately simple oracle: compare
# every original cell triangle, including cells outside the invalidation halo.
# Texture object identities differ between renderers; use their actual role.
static func _assert_matches_fresh(renderer: Renderer, label: String, failures: Array[String]) -> void:
	renderer.map_bounds()
	var reference := Renderer.new()
	reference.bind_grid(renderer.grid)
	_expect(_command_snapshot(renderer) == _command_snapshot(reference),
		label + ": incremental cache must match a fresh build of every cell, color and UV", failures)
	_expect(_retained_snapshot(renderer) == _retained_snapshot(reference),
		label + ": actual retained GPU batches must also match a fresh build, not just their source commands", failures)
	_expect(renderer.map_bounds() == reference.map_bounds(),
		label + ": incremental camera bounds must match a complete rebuild", failures)
	reference.free()


static func _retained_snapshot(renderer: Renderer) -> Dictionary:
	var result: Dictionary = {}
	for row: int in renderer._row_batches:
		var row_data: Dictionary = {}
		for layer: String in ["base", "surface"]:
			var batches: Array = []
			for batch: Dictionary in (renderer._row_batches[row] as Dictionary)[layer] as Array:
				batches.append({
					"texture": renderer._textures.find_key(batch["texture"]),
					"modulate": batch.get("modulate", Color.WHITE),
					"arrays": (batch["mesh"] as ArrayMesh).surface_get_arrays(0),
				})
			row_data[layer] = batches
		result[row] = row_data
	return result


static func _command_snapshot(renderer: Renderer) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in renderer._cells:
		result[cell] = {
			"polygon": (renderer._cells[cell] as Dictionary)["polygon"],
			"bounds": (renderer._cells[cell] as Dictionary)["bounds"],
			"draws": _cell_commands(renderer, cell),
		}
	return result


static func _cell_commands(renderer: Renderer, cell: Vector2i) -> Array:
	var result: Array = []
	for command: Dictionary in (renderer._cells[cell] as Dictionary)["draws"] as Array:
		var record: Dictionary = command.duplicate()
		var texture: Texture2D = record["texture"] as Texture2D
		record["texture"] = renderer._textures.find_key(texture)
		result.append(record)
	return result


static func _has_layer(renderer: Renderer, cell: Vector2i, layer: String) -> bool:
	for command: Dictionary in (renderer._cells[cell] as Dictionary)["draws"] as Array:
		if String(command.get("layer", "")) == layer:
			return true
	return false


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
