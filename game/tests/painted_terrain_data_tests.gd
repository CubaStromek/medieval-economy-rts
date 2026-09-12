extends RefCounted

const Data = preload("res://scripts/view/painted_terrain_data.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Materials = preload("res://scripts/view/modern_terrain_materials.gd")
const Sample = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_generic_centers, _test_shared_edges, _test_source_weights,
		_test_source_light, _test_generic_incremental, _test_source_incremental,
		_test_invalid_source, _test_immutable]:
		test.call(failures)
	return failures


static func _test_generic_centers(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(5, 5))
	grid.set_base_terrain(Vector2i(2, 2), "water")
	grid.set_base_terrain(Vector2i(3, 3), "rock")
	grid.set_base_terrain(Vector2i(1, 1), "dirt")
	var data := Data.new()
	_check(data.configure(grid) and not data.source_active and data.weight_scale == 2.0, "Generic materials need a half-cell lattice", failures)
	_check(data.weight_dimensions == Vector2(11, 11) and data.light.get_size() == Vector2i(6, 6), "Weight and light images have independent correct sizes", failures)
	_check(data.high.get_pixel(5, 5).g == 1.0 and data.low.get_pixel(7, 7).b == 1.0, "Isolated water and rock retain pure material centers", failures)
	_check(data.low.get_pixel(3, 3).a == 1.0, "Prototype dirt uses packed-soil art, not vegetated original-map dirt", failures)


static func _test_shared_edges(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 1))
	grid.set_base_terrain(Vector2i(1, 0), "rock")
	var data := Data.new()
	data.configure(grid)
	for y: int in range(3):
		var edge: Color = data.low.get_pixel(2, y)
		_check(edge.r == 0.5 and edge.b == 0.5, "Touching materials share one continuous edge value", failures)
	for y: int in range(3):
		for x: int in range(5):
			var a: Color = data.low.get_pixel(x, y)
			var b: Color = data.high.get_pixel(x, y)
			_check(is_equal_approx(a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a, 1.0), "Every material sample is normalized including map edges", failures)


static func _test_source_weights(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 2))
	var patch: Dictionary = {"size": [2, 2], "tile_rows": [[[66, 1], [157, 0]], [[34, 0], [237, 2]]]}
	var source: Dictionary = _source(grid)
	for y: int in range(2):
		for x: int in range(2):
			var tile: Array = patch["tile_rows"][y][x]
			source["corner_kinds"][y][x] = "".join(Materials.world_corner_kinds(int(tile[0]), int(tile[1])))
	grid.set_meta(Data.SOURCE_META, source)
	var data := Data.new()
	data.configure(grid)
	var expected: Dictionary = Materials.build_weights(patch)
	_check(data.source_active and data.weight_scale == 1.0, "Source maps retain the sandbox's shared-vertex lattice", failures)
	_check(data.low.get_data() == expected["low"].get_data() and data.high.get_data() == expected["high"].get_data(), "Production source weights must match the approved sandbox exactly", failures)


static func _test_source_light(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 2))
	var source: Dictionary = _source(grid)
	source["raw_heights"] = [[40, 33, 31], [37, 34, 29], [35, 35, 30]]
	source["water_vertices"][1][1] = true
	var halo: Array = []
	var water_halo: Array = []
	for y: int in range(5):
		var row: Array = []
		var water: Array = []
		for x: int in range(5):
			row.append(source["raw_heights"][clampi(y - 1, 0, 2)][clampi(x - 1, 0, 2)])
			water.append(source["water_vertices"][clampi(y - 1, 0, 2)][clampi(x - 1, 0, 2)])
		halo.append(row)
		water_halo.append(water)
	source["raw_height_halo"] = halo
	grid.set_meta(Data.SOURCE_META, source)
	var data := Data.new()
	data.configure(grid)
	for y: int in range(3):
		for x: int in range(3):
			_check(is_equal_approx(data.light.get_pixel(x, y).r, Sample.vertex_light(halo, water_halo, x, y)), "Production signed vertex lighting must match sandbox stencil and water offset", failures)
	var before: float = data.light.get_pixel(1, 1).r
	grid.set_vertex_height(Vector2i(1, 1), 1)
	data.update_terrain(grid.cells_touching_vertex(Vector2i(1, 1)))
	_check(is_equal_approx(data.light.get_pixel(1, 1).r, before + 2.0 / 0.15 / 44.0 * 1.3), "Earthwork changes source detail by the exact simulation height delta", failures)


static func _test_generic_incremental(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(12, 10))
	var data := Data.new()
	data.configure(grid)
	var initial_writes: int = data.weight_write_count
	grid.set_base_terrain(Vector2i(6, 5), "water")
	data.update_terrain([Vector2i(6, 5)])
	_check(data.weight_write_count - initial_writes == 9, "One generic terrain change touches only its nine half-grid samples", failures)
	for point: Vector2i in [Vector2i(0, 0), Vector2i(12, 10), Vector2i(4, 4)]:
		grid.set_vertex_height(point, 2)
		data.update_terrain(grid.cells_touching_vertex(point))
	var fresh := Data.new()
	fresh.configure(grid)
	_check(_same_images(data, fresh), "Generic incremental updates must equal a fresh build including boundary height stencils", failures)
	var count: int = data.update_count
	data.update_terrain([])
	data.update_terrain([Vector2i(-1, -1)])
	_check(data.update_count == count, "Empty/out-of-map invalidations perform no image work", failures)


static func _test_source_incremental(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 6))
	var source: Dictionary = _source(grid)
	source["corner_kinds"][2][3] = "OOOO"
	grid.set_meta(Data.SOURCE_META, source)
	var data := Data.new()
	data.configure(grid)
	var before: float = data.high.get_pixel(3, 2).a
	grid.set_base_terrain(Vector2i(3, 2), "dirt")
	data.update_terrain([Vector2i(3, 2)])
	_check(before > 0.0 and data.high.get_pixel(3, 2).a == 0.0 and data.low.get_pixel(3, 2).a > 0.0, "Changed source material must discard obsolete source corner art", failures)
	for point: Vector2i in [Vector2i(0, 0), Vector2i(8, 6), Vector2i(3, 2)]:
		grid.set_vertex_height(point, 1)
		data.update_terrain(grid.cells_touching_vertex(point))
	var fresh := Data.new()
	fresh.configure(grid)
	_check(_same_images(data, fresh), "Source incremental material/earthwork updates must equal a full rebuild", failures)


static func _test_invalid_source(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 2))
	for changes: Dictionary in [{"size": [2.5, 2]}, {"corner_kinds": [["????"]]}, {"raw_heights": []}, {"water_vertices": [[true]]}, {"base_terrain": ["xx", "gg"]}]:
		var source: Dictionary = _source(grid)
		source.merge(changes, true)
		grid.set_meta(Data.SOURCE_META, source)
		var data := Data.new()
		_check(data.configure(grid) and not data.source_active and not data.last_error.is_empty(), "Malformed optional metadata falls back without breaking gameplay", failures)
	var invalid := Data.new()
	_check(not invalid.configure(null), "A null grid cannot build terrain textures", failures)


static func _test_immutable(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 2))
	var source: Dictionary = _source(grid)
	var before: Dictionary = source.duplicate(true)
	var terrain: PackedByteArray = grid._base_terrain.duplicate()
	var heights: PackedInt32Array = grid._vertex_heights.duplicate()
	var revision: int = grid.revision
	grid.set_meta(Data.SOURCE_META, source)
	var data := Data.new()
	data.configure(grid)
	data.update_terrain([Vector2i.ZERO])
	_check(source == before and grid._base_terrain == terrain and grid._vertex_heights == heights and grid.revision == revision, "Painted presentation data never modifies simulation or original metadata", failures)


static func _source(grid: Grid) -> Dictionary:
	var kinds: Array = []
	var raw: Array = []
	var base: Array = []
	var water: Array = []
	var terrain: Array = []
	for y: int in range(grid.size.y):
		var row: Array = []
		for x: int in range(grid.size.x):
			row.append("GGGG")
		kinds.append(row)
		terrain.append("g".repeat(grid.size.x))
	for y: int in range(grid.size.y + 1):
		var raw_row: Array = []
		var base_row: Array = []
		var water_row: Array = []
		for x: int in range(grid.size.x + 1):
			raw_row.append(30)
			base_row.append(grid.vertex_height(Vector2i(x, y)))
			water_row.append(false)
		raw.append(raw_row)
		base.append(base_row)
		water.append(water_row)
	return {"size": [grid.size.x, grid.size.y], "corner_kinds": kinds, "raw_heights": raw,
		"base_heights": base, "base_terrain": terrain, "water_vertices": water}


static func _same_images(a: Data, b: Data) -> bool:
	return a.low.get_data() == b.low.get_data() and a.high.get_data() == b.high.get_data() and a.light.get_data() == b.light.get_data()


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)
