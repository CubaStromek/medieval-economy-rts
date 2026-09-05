extends RefCounted

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const TerrainRendererClass = preload("res://scripts/view/terrain_renderer.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_shared_corners_and_bounds(failures)
	_test_elevated_picking_and_motion(failures)
	_test_frontmost_ridge_occlusion(failures)
	_test_overlay_surface_and_cache(failures)
	return failures


static func _test_shared_corners_and_bounds(failures: Array[String]) -> void:
	var grid := GridMapSimClass.new(Vector2i(4, 4))
	grid.set_vertex_height(Vector2i(1, 1), 3)
	grid.set_vertex_height(Vector2i(2, 1), 4)
	grid.set_vertex_height(Vector2i(2, 2), 2)
	grid.set_vertex_height(Vector2i(2, 0), 12)
	var renderer := TerrainRendererClass.new()
	renderer.bind_grid(grid)
	for y: int in range(grid.size.y):
		for x: int in range(grid.size.x):
			var cell := Vector2i(x, y)
			var quad: PackedVector2Array = renderer.cell_polygon(cell)
			if x + 1 < grid.size.x:
				var right: PackedVector2Array = renderer.cell_polygon(cell + Vector2i.RIGHT)
				_expect(quad[1] == right[0] and quad[2] == right[3],
					"Raised east/west edges must share exactly identical screen vertices", failures)
			if y + 1 < grid.size.y:
				var below: PackedVector2Array = renderer.cell_polygon(cell + Vector2i.DOWN)
				_expect(quad[2] == below[1] and quad[3] == below[0],
					"Raised north/south edges must share exactly identical screen vertices", failures)
			for point: Vector2 in quad:
				_expect(renderer.map_bounds().grow(0.01).has_point(point),
					"Camera bounds must contain every deformed terrain vertex", failures)
	_expect(renderer.map_bounds().position.y == -96.0,
		"Camera bounds must extend above the flat origin for a raised northern mountain", failures)
	_expect(renderer.cell_rect(Vector2i(1, 0)).size.y > MapProjectionClass.CELL_SIZE.y,
		"Compatibility bounds must describe the actual raised cell instead of a flat rectangle", failures)
	renderer.free()


static func _test_elevated_picking_and_motion(failures: Array[String]) -> void:
	var grid := GridMapSimClass.new(Vector2i(6, 6))
	for y: int in range(grid.size.y + 1):
		for x: int in range(grid.size.x + 1):
			grid.set_vertex_height(Vector2i(x, y), 3 + y)
	var renderer := TerrainRendererClass.new()
	renderer.bind_grid(grid)
	for y: int in range(grid.size.y):
		for x: int in range(grid.size.x):
			var cell := Vector2i(x, y)
			_expect(renderer.pick_cell(renderer.cell_center(cell)) == cell,
				"Every visible slope cell must round-trip from its raised center through picking", failures)
			for offset: Vector2 in [Vector2(-0.28, -0.11), Vector2(0.18, 0.29)]:
				var projected: Vector2 = renderer.project_grid_position(Vector2(cell) + offset)
				_expect(renderer.pick_cell(projected) == cell,
					"Picking must resolve both triangles inside the raised cell", failures)
	var position := Vector2(2.2, 1.65)
	var expected_height: float = 3.0 + position.y + 0.5
	var expected: Vector2 = (position + Vector2(0.5, 0.5)) * MapProjectionClass.CELL_SIZE - Vector2(0, expected_height * 8.0)
	_expect(renderer.project_grid_position(position).is_equal_approx(expected),
		"Moving feet must follow continuously sampled ground height between cell centers", failures)
	_expect(renderer.pick_cell(Vector2(-1, 0)) == Vector2i(-1, -1),
		"Picking outside the map must produce the invalid sentinel", failures)
	_expect(renderer.pick_cell(Vector2(10, -200)) == Vector2i(-1, -1),
		"Empty space above the projected terrain must not pick a flat fallback tile", failures)
	renderer.free()


static func _test_frontmost_ridge_occlusion(failures: Array[String]) -> void:
	var grid := GridMapSimClass.new(Vector2i(3, 5))
	for x: int in range(grid.size.x + 1):
		grid.set_vertex_height(Vector2i(x, 3), 12)
	for x: int in range(grid.size.x):
		grid.set_base_terrain(Vector2i(x, 2), "rock")
		grid.set_base_terrain(Vector2i(x, 3), "rock")
	var renderer := TerrainRendererClass.new()
	renderer.bind_grid(grid)
	var hidden_ground := Vector2(1, 1)
	var hidden_feet: Vector2 = renderer.project_grid_position(hidden_ground)
	_expect(renderer.pick_cell(hidden_feet) == Vector2i(1, 3),
		"A click on overlapping relief must hit the foreground rock face, not the hidden tile", failures)
	_expect(renderer.point_occluded(hidden_feet, hidden_ground),
		"Foreground ridge must block selecting a worker's covered feet", failures)
	_expect(not renderer.point_occluded(hidden_feet - Vector2(0, 80), hidden_ground),
		"Object pixels protruding above a ridge must remain selectable", failures)
	var foreground := Vector2(1, 4)
	_expect(not renderer.point_occluded(renderer.project_grid_position(foreground), foreground),
		"A worker in front of the ridge must remain visible/selectable", failures)
	_expect(not renderer.point_occluded(renderer.cell_center(Vector2i(1, 3)), Vector2(1, 2.75)),
		"Fractional movement must share the painter's nearest ground-cell row convention", failures)
	renderer.free()


static func _test_overlay_surface_and_cache(failures: Array[String]) -> void:
	var grid := GridMapSimClass.new(Vector2i(3, 3))
	grid.set_vertex_height(Vector2i(1, 1), 1)
	grid.set_vertex_height(Vector2i(2, 1), 2)
	grid.set_vertex_height(Vector2i(2, 2), 3)
	grid.set_vertex_height(Vector2i(1, 2), 1)
	grid.add_road(Vector2i(1, 1))
	grid.add_road(Vector2i(2, 1))
	grid.set_base_terrain(Vector2i(1, 0), "dirt")
	var renderer := TerrainRendererClass.new()
	renderer.bind_grid(grid)
	var build_count: int = renderer.geometry_build_count
	var cell := Vector2i(1, 1)
	# Inspect the submitted mesh geometry, not just the public height helper:
	# roads and transitions must be cut before projection on a twisted quad.
	var commands: Array = (renderer._cells[cell] as Dictionary)["draws"] as Array
	_expect(commands.size() > 4, "Fixture must include real road and transition draw geometry", failures)
	for command: Dictionary in commands:
		var points: PackedVector2Array = command["points"] as PackedVector2Array
		var uvs: PackedVector2Array = command["uvs"] as PackedVector2Array
		_expect(points.size() == 3, "Every submitted surface piece must be one explicit terrain triangle", failures)
		var upper: bool = true
		var lower: bool = true
		for index: int in range(uvs.size()):
			var uv: Vector2 = uvs[index]
			upper = upper and uv.x >= uv.y - 0.0001
			lower = lower and uv.x <= uv.y + 0.0001
			var grid_point: Vector2 = Vector2(cell) + uv
			var height: float = (1.0 + uv.x + uv.y) if uv.x >= uv.y else (1.0 + 2.0 * uv.x)
			var expected: Vector2 = grid_point * MapProjectionClass.CELL_SIZE - Vector2(0, height * 8.0)
			_expect(points[index].is_equal_approx(expected),
				"Road/transition mesh vertices must lie exactly on the underlying triangle plane", failures)
		_expect(upper or lower, "Road/transition triangles must never straddle the twisted cell diagonal", failures)
	for _repeat: int in range(10):
		renderer.cell_polygon(cell)
		renderer.pick_cell(renderer.cell_center(cell))
		renderer.map_bounds()
	_expect(renderer.geometry_build_count == build_count,
		"Repeated frame queries must reuse the terrain mesh cache", failures)
	grid.set_vertex_height(Vector2i(1, 1), 2)
	renderer.cell_polygon(cell)
	_expect(renderer.geometry_build_count == build_count + 1,
		"Changing a shared height must rebuild cached geometry exactly once on next access", failures)
	grid.configure_movement({"terrain": {"grass": {"color": "90a060"}}})
	renderer.cell_polygon(cell)
	_expect(renderer.geometry_build_count == build_count + 2,
		"Definition changes must also invalidate terrain textures and mesh colors", failures)
	renderer.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
