extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const MapProjection = preload("res://scripts/view/map_projection.gd")
const CacheTests = preload("res://tests/terrain_cache_tests.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_all_diagonal_connections(failures)
	_test_mixed_surface_joins(failures)
	_test_blocked_corners(failures)
	_test_terrain_conforming_fragments(failures)
	_test_incremental_neighbors(failures)
	_test_carrier_wear_forms_diagonal(failures)
	return failures


static func _test_all_diagonal_connections(failures: Array[String]) -> void:
	for direction: Vector2i in Renderer.DIAGONAL_DIRECTIONS:
		for stone: bool in [false, true]:
			var grid := Grid.new(Vector2i(7, 7))
			var first := Vector2i(3, 3)
			var second: Vector2i = first + direction
			_add_surface(grid, first, stone)
			_add_surface(grid, second, stone)
			var renderer := Renderer.new()
			renderer.bind_grid(grid)
			var expected_mask: int = 1 << Renderer.DIAGONAL_DIRECTIONS.find(direction)
			_expect(renderer.diagonal_surface_connection_mask_for(first) == expected_mask,
				"Each of the four diagonal headings must create exactly its own surface connection", failures)
			_expect(renderer.surface_connection_mask_for(first) == 0,
				"A diagonal route must not invent cardinal exits on either endpoint", failures)
			_assert_continuous(renderer, first, direction, failures)
			for side: Vector2i in [first + Vector2i(direction.x, 0), first + Vector2i(0, direction.y)]:
				_expect(grid.overlay_at(side).is_empty() and grid.traffic_wear_at(side) == 0,
					"Clipped diagonal corners are visual footprints, never extra worn simulation cells", failures)
				_expect(_has_core(renderer, side),
					"Both side cells must own their portion of the diagonal strip at the shared corner", failures)
			renderer.free()


static func _test_mixed_surface_joins(failures: Array[String]) -> void:
	for direction: Vector2i in Renderer.DIAGONAL_DIRECTIONS:
		for first_stone: bool in [false, true]:
			var grid := Grid.new(Vector2i(7, 7))
			var first := Vector2i(3, 3)
			var second: Vector2i = first + direction
			_add_surface(grid, first, first_stone)
			_add_surface(grid, second, not first_stone)
			grid.set_trail_link(first, second, grid.carrier_passes_to_form_trail(), 0, true)
			var renderer := Renderer.new()
			renderer.bind_grid(grid)
			var first_width: float = renderer.surface_edge_half_width(first, direction)
			_expect(first_width > 0.0 and is_equal_approx(first_width, renderer.surface_edge_half_width(second, -direction)),
				"Dirt and stone halves must agree on their diagonal join width in both directions", failures)
			_assert_continuous(renderer, first, direction, failures)
			var stone_cell: Vector2i = first if first_stone else second
			var trail_cell: Vector2i = second if first_stone else first
			_expect(_core_covers(renderer, Vector2(stone_cell) + Vector2(0.5, 0.5), "road_core")
				and _core_covers(renderer, Vector2(trail_cell) + Vector2(0.5, 0.5), "trail_core"),
				"A mixed diagonal connection must preserve stone and dirt material on its respective halves", failures)
			renderer.free()


static func _test_blocked_corners(failures: Array[String]) -> void:
	for direction: Vector2i in Renderer.DIAGONAL_DIRECTIONS:
		for side_direction: Vector2i in [Vector2i(direction.x, 0), Vector2i(0, direction.y)]:
			for blocker: String in ["building", "water", "steep"]:
				var grid := Grid.new(Vector2i(7, 7))
				var first := Vector2i(3, 3)
				var second: Vector2i = first + direction
				var side: Vector2i = first + side_direction
				grid.add_dirt_trail(first)
				grid.add_dirt_trail(second)
				var renderer := Renderer.new()
				renderer.bind_grid(grid)
				_expect(renderer.diagonal_surface_connection_mask_for(first) != 0,
					"Blocked-corner fixture must begin with a real visible diagonal connection", failures)
				match blocker:
					"building": grid.block(side, 701)
					"water": grid.set_base_terrain(side, "water")
					"steep":
						# Raise the far side corner, not the shared path corner.
						var far_vertex: Vector2i = side + Vector2i(1 if side_direction.x > 0 else 0, 1 if side_direction.y > 0 else 0)
						grid.set_vertex_height(far_vertex, 9)
				renderer.map_bounds()
				_expect(renderer.diagonal_surface_connection_mask_for(first) == 0
					and renderer.diagonal_surface_connection_mask_for(second) == 0,
					"A building, water or steep side cell must remove both directions of the visual corner connection", failures)
				_expect(not _has_core(renderer, side),
					"No diagonal road fragment may paint across a blocked corner side cell", failures)
				CacheTests._assert_matches_fresh(renderer, "Blocked diagonal " + blocker, failures)
				renderer.free()


static func _test_terrain_conforming_fragments(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(6, 6))
	for y: int in range(7):
		for x: int in range(7):
			grid.set_vertex_height(Vector2i(x, y), y)
	# A local twist makes a single unsplit diagonal quad observably incorrect.
	grid.set_vertex_height(Vector2i(3, 3), 4)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(3, 2)]:
		grid.add_dirt_trail(cell)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var triangle_count: int = 0
	for cell: Vector2i in renderer._cells:
		for command: Dictionary in renderer._cells[cell]["surface_draws"]:
			var uvs: PackedVector2Array = command["uvs"]
			var points: PackedVector2Array = command["points"]
			var texture_uvs: PackedVector2Array = command["texture_uvs"]
			var upper: bool = true
			var lower: bool = true
			for index: int in range(uvs.size()):
				var uv: Vector2 = uvs[index]
				_expect(uv.x >= -0.0001 and uv.x <= 1.0001 and uv.y >= -0.0001 and uv.y <= 1.0001,
					"Every diagonal fragment must stay inside the ground cell owning its retained row", failures)
				upper = upper and uv.x >= uv.y - 0.0001
				lower = lower and uv.x <= uv.y + 0.0001
				var world_point: Vector2 = Vector2(cell) + uv
				var expected: Vector2 = world_point * MapProjection.CELL_SIZE - Vector2(0, grid.height_at(world_point) * MapProjection.HEIGHT_STEP_PIXELS)
				_expect(points[index].is_equal_approx(expected),
					"Diagonal road fragments must lie exactly on their actual terrain triangle", failures)
				_expect(texture_uvs[index].is_equal_approx(world_point / Renderer.ROAD_TEXTURE_SPAN),
					"Diagonal joins must retain world-aligned texture coordinates without per-cell seams", failures)
			_expect(upper or lower, "A diagonal road triangle must never straddle a twisted terrain diagonal", failures)
			triangle_count += 1
	_expect(triangle_count > 50, "Slope fixture must exercise actual diagonal road and shoulder geometry", failures)
	renderer.free()


static func _test_incremental_neighbors(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(12, 10))
	var first := Vector2i(5, 4)
	var second: Vector2i = first + Vector2i.ONE
	grid.add_dirt_trail(first)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var before: Array = CacheTests._cell_commands(renderer, first)
	var base_meshes: Dictionary = CacheTests._mesh_ids(renderer, "base")
	var base_builds: int = renderer.base_cell_build_count
	var surface_builds: int = renderer.surface_cell_build_count
	var row_builds: int = renderer.row_mesh_build_count
	grid.add_dirt_trail(second)
	CacheTests._assert_matches_fresh(renderer, "New diagonal trail", failures)
	_expect(CacheTests._cell_commands(renderer, first) != before,
		"A newly formed trail must refresh the existing trail in its diagonal neighbor", failures)
	_expect(renderer.surface_cell_build_count - surface_builds <= 14
		and renderer.row_mesh_build_count - row_builds <= 4,
		"Adding a recorded diagonal connection may refresh only its two endpoint neighborhoods and at most four rows", failures)
	_expect(renderer.base_cell_build_count == base_builds and CacheTests._mesh_ids(renderer, "base") == base_meshes,
		"Diagonal trail updates must preserve every retained base-terrain cell and mesh", failures)
	grid.add_road(second)
	CacheTests._assert_matches_fresh(renderer, "Diagonal trail paved", failures)
	grid.block(first + Vector2i.RIGHT, 702)
	CacheTests._assert_matches_fresh(renderer, "Diagonal side occupied", failures)
	grid.unblock(first + Vector2i.RIGHT)
	CacheTests._assert_matches_fresh(renderer, "Diagonal side unoccupied", failures)
	grid.block(second, 703)
	CacheTests._assert_matches_fresh(renderer, "Diagonal endpoint removed", failures)
	_expect(renderer.base_cell_build_count == base_builds and CacheTests._mesh_ids(renderer, "base") == base_meshes,
		"Paving and blocked/unblocked diagonal corners must change surface meshes only", failures)
	renderer.free()


static func _test_carrier_wear_forms_diagonal(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(6, 6))
	grid.configure_movement({"trail": {"carrier_passes_to_form": 3}})
	var first := Vector2i(2, 2)
	var second := Vector2i(3, 3)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	for passes: int in range(3):
		grid.record_carrier_traffic(first, second)
		grid.record_carrier_traffic(second, first)
		CacheTests._assert_matches_fresh(renderer, "Diagonal wear pass %d" % passes, failures)
		if passes < 2:
			_expect(grid.overlay_at(first).is_empty() and renderer.diagonal_surface_connection_mask_for(first) == 0,
				"Subthreshold footsteps must remain wear patches, not prematurely claim a formed diagonal trail", failures)
	_expect(grid.overlay_at(first) == Grid.OVERLAY_TRAIL and grid.overlay_at(second) == Grid.OVERLAY_TRAIL,
		"The carrier traffic threshold must form both diagonal endpoint trail cells", failures)
	_assert_continuous(renderer, first, Vector2i.ONE, failures)
	renderer.free()


static func _assert_continuous(renderer: Renderer, first: Vector2i, direction: Vector2i, failures: Array[String]) -> void:
	var across := Vector2(-direction.y, direction.x).normalized()
	var width: float = renderer.surface_edge_half_width(first, direction)
	for step: int in range(21):
		var along: float = float(step) / 20.0
		var center: Vector2 = Vector2(first) + Vector2(0.5, 0.5) + Vector2(direction) * along
		for fraction: float in [-0.8, -0.4, 0.0, 0.4, 0.8]:
			_expect(_core_covers(renderer, center + across * width * fraction),
				"Actual diagonal core triangles must cover the whole route and shared corner without grass holes", failures)


static func _core_covers(renderer: Renderer, world_point: Vector2, layer: String = "") -> bool:
	var cell := Vector2i(floori(world_point.x), floori(world_point.y))
	if not renderer._cells.has(cell):
		return false
	var uv: Vector2 = world_point - Vector2(cell)
	for command: Dictionary in renderer._cells[cell]["surface_draws"]:
		if not String(command["layer"]).ends_with("_core") or (not layer.is_empty() and command["layer"] != layer):
			continue
		var vertices: PackedVector2Array = command["uvs"]
		if Renderer._point_in_triangle(uv, vertices[0], vertices[1], vertices[2]):
			return true
	return false


static func _has_core(renderer: Renderer, cell: Vector2i) -> bool:
	for command: Dictionary in renderer._cells[cell]["surface_draws"]:
		if String(command["layer"]).ends_with("_core"):
			return true
	return false


static func _add_surface(grid: Grid, cell: Vector2i, stone: bool) -> void:
	if stone:
		grid.add_road(cell)
	else:
		grid.add_dirt_trail(cell)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
