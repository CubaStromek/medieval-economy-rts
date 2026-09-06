extends RefCounted

const Sample = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_projection, _test_rotations, _test_source_halo,
		_test_water_lighting, _test_gradient, _test_configuration,
		_test_invalid_schema, _test_retained_mesh]:
		test.call(failures)
	return failures


static func fixture() -> Dictionary:
	var heights: Array = []
	var water: Array = []
	for y: int in range(5):
		var heights_row: Array = []
		var water_row: Array = []
		for x: int in range(5):
			heights_row.append(30)
			water_row.append(false)
		heights.append(heights_row)
		water.append(water_row)
	return {"name": "Synthetic reference patch", "origin": [3, 7], "size": [2, 2],
		"height_halo": heights, "water_halo": water,
		"tile_rows": [[[0, 0], [1, 1]], [[16, 2], [237, 3]]],
		"prototype_terrain": ["gd", "rw"]}


static func _atlas() -> Image:
	var atlas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.2, 0.6, 0.2))
	atlas.fill_rect(Rect2i(32, 0, 32, 32), Color.RED)
	atlas.fill_rect(Rect2i(0, 32, 32, 32), Color.BLUE)
	atlas.fill_rect(Rect2i(416, 448, 32, 32), Color.YELLOW)
	return atlas


static func _test_projection(failures: Array[String]) -> void:
	var point: Vector2 = Sample.project_vertex(Vector2i(3, 2), 10.0)
	_check(is_equal_approx(point.x, 120.0) and is_equal_approx(point.y, 80.0 - 400.0 / 33.333),
		"Reference projection must keep 40-pixel axes and the original raw-height divisor without map rotation", failures)
	var delta: Vector2 = Sample.project_vertex(Vector2i(3, 2), 11.0) - point
	_check(is_zero_approx(delta.x) and is_equal_approx(delta.y, -40.0 / 33.333),
		"One raw source height step must remain about 1.2 pixels, not round into an 8-pixel prototype step", failures)


static func _test_rotations(failures: Array[String]) -> void:
	var uv := Vector2(0.2, 0.7)
	var expected: Array[Vector2] = [Vector2(0.2, 0.7), Vector2(0.7, 0.8), Vector2(0.8, 0.3), Vector2(0.3, 0.2)]
	for rotation: int in range(4):
		_check(Sample.rotate_uv(uv, rotation).is_equal_approx(expected[rotation]),
			"Reference UV rotations must match the source's four corner assignments", failures)
	_check(Sample.rotate_uv(Vector2.ZERO, 1) == Vector2.DOWN and Sample.rotate_uv(uv, 4).is_equal_approx(uv),
		"Rotated top-left UV must address the original bottom-left and repeat after four rotations", failures)


static func _test_source_halo(failures: Array[String]) -> void:
	var patch: Dictionary = fixture()
	var heights: Array = patch["height_halo"]
	var water: Array = patch["water_halo"]
	_check(is_zero_approx(Sample.vertex_light(heights, water, 0, 0)),
		"An interior crop border must use its real halo, never fade to artificial black", failures)
	heights[1][1] = 50
	heights[1][0] = 28
	heights[2][1] = 28
	_check(is_equal_approx(Sample.vertex_light(heights, water, 0, 0), 1.0),
		"Lighting must read the actual west and south source vertices through the crop halo", failures)
	heights[3][3] = 35
	heights[3][2] = 31
	heights[4][3] = 33
	_check(is_equal_approx(Sample.vertex_light(heights, water, 2, 2), 3.0 / 22.0),
		"The final crop vertex must include the extra source row for its southern lighting neighbor", failures)


static func _test_water_lighting(failures: Array[String]) -> void:
	var patch: Dictionary = fixture()
	var heights: Array = patch["height_halo"]
	var water: Array = patch["water_halo"]
	water[2][2] = true
	_check(is_equal_approx(Sample.vertex_light(heights, water, 1, 1), 0.1),
		"Flat source water must receive the original +0.1 light offset", failures)
	heights[2][2] = 255
	_check(Sample.vertex_light(heights, water, 1, 1) == 1.0,
		"Bright source water must clamp after its 1.3 contrast multiplier", failures)
	heights[2][2] = 0
	heights[2][1] = 255
	heights[3][2] = 255
	_check(Sample.vertex_light(heights, water, 1, 1) == -1.0,
		"Dark source water must stay within the original signed-light range", failures)


static func _test_gradient(failures: Array[String]) -> void:
	_check(Sample.gradient_value(-1.0) == 0.0 and Sample.gradient_value(0.0) == 0.0 and Sample.gradient_value(1.0) == 1.0,
		"The nearest 256-entry Remake lookup must clamp its coordinate at both ends", failures)
	_check(is_equal_approx(Sample.gradient_value(40.0 / 256.0), 26.0 / 255.0)
		and is_equal_approx(Sample.gradient_value(24.0 / 256.0), 10.0 / 255.0),
		"Halfway lookup values must use documented Pascal-default ties-to-even rounding", failures)
	_check(is_equal_approx(Sample.light_multiplier(0.5), 1.0 + 120.0 / 255.0)
		and is_equal_approx(Sample.light_multiplier(-0.5), 1.0 - 120.0 / 255.0)
		and Sample.light_multiplier(0.0) == 1.0,
		"Signed lighting must apply separate original highlight and shadow blend factors", failures)
	_check(Sample.LIGHT_SHADER.contains("varying float terrain_light")
		and Sample.LIGHT_SHADER.contains("light_gradient(terrain_light)"),
		"The native shader must interpolate signed light before the nonlinear fragment lookup", failures)


static func _test_configuration(failures: Array[String]) -> void:
	var renderer := Sample.new()
	var patch: Dictionary = fixture()
	var before: Dictionary = patch.duplicate(true)
	var atlas: Image = _atlas()
	var pixels: PackedByteArray = atlas.get_data()
	_check(renderer.configure(patch, atlas), "A valid synthetic reference patch must configure: " + renderer.last_error, failures)
	_check(renderer.tile_count() == 4 and renderer.texture_count() == 4 and renderer.sample_size == Vector2i(2, 2),
		"Reference renderer must retain all four tile IDs without reducing them to prototype material classes", failures)
	_check(patch == before and atlas.get_data() == pixels,
		"Reference study must never mutate its source patch or external tilesheet", failures)
	if renderer.texture_count() == 4:
		_check((renderer._textures[1] as ImageTexture).get_image().get_pixel(0, 0) == Color.RED
			and (renderer._textures[16] as ImageTexture).get_image().get_pixel(0, 0) == Color.BLUE
			and (renderer._textures[237] as ImageTexture).get_image().get_pixel(0, 0) == Color.YELLOW,
			"Row-major 32-pixel tile addresses must select the correct external pixels without exporting them", failures)
	renderer.free()


static func _test_invalid_schema(failures: Array[String]) -> void:
	var renderer := Sample.new()
	var atlas: Image = _atlas()
	for changes: Dictionary in [{"name": 1}, {"name": " "}, {"size": [2]}, {"size": [2.5, 2]},
		{"size": [true, 2]}, {"size": [65, 2]}, {"origin": [0, 2]}, {"origin": [INF, 2]},
		{"height_halo": []}, {"water_halo": []}, {"tile_rows": []}, {"prototype_terrain": ["gg", "gx"]}]:
		var patch: Dictionary = fixture()
		patch.merge(changes, true)
		_check(not renderer.configure(patch, atlas) and not renderer.last_error.is_empty(),
			"Malformed reference headers and grids must produce an explicit rejection", failures)
	for value: Variant in [-1, 256, 1.5, true, "3", NAN]:
		var patch: Dictionary = fixture()
		patch["height_halo"][1][1] = value
		_check(not renderer.configure(patch, atlas), "Invalid raw source heights must not reach mesh construction", failures)
	for tile: Variant in [[238, 0], [-1, 0], [0, 4], [true, 0], [0], "tile"]:
		var patch: Dictionary = fixture()
		patch["tile_rows"][0][0] = tile
		_check(not renderer.configure(patch, atlas), "Missing tiles and invalid rotations must not silently substitute artwork", failures)
	var bad_water: Dictionary = fixture()
	bad_water["water_halo"][1][1] = 1
	_check(not renderer.configure(bad_water, atlas) and not renderer.configure(fixture(), null)
		and not renderer.configure(fixture(), Image.create(32, 32, false, Image.FORMAT_RGBA8)),
		"Water flags and the external reference atlas dimensions must be checked explicitly", failures)
	renderer.free()


static func _test_retained_mesh(failures: Array[String]) -> void:
	var renderer := Sample.new()
	var patch: Dictionary = fixture()
	patch["height_halo"][1][1] = 31
	_check(renderer.configure(patch, _atlas()), "Retained mesh fixture must configure", failures)
	var first_mesh: ArrayMesh = renderer._batches[0]["mesh"]
	var arrays: Array = first_mesh.surface_get_arrays(0)
	var points: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	_check(points.size() == 6 and points[0] == points[3] and points[2] == points[4],
		"Static reference meshes must use the original shared TL-BR diagonal", failures)
	var expected_top: float = -31.0 * 40.0 / 33.333
	var expected_bottom: float = 80.0 - 30.0 * 40.0 / 33.333
	_check(is_equal_approx(renderer.bounds().position.y, expected_top)
		and is_equal_approx(renderer.bounds().end.y, expected_bottom) and renderer.bounds().size.x == 80.0,
		"Study bounds must include all projected raw-height corners", failures)
	var encoded: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var stencil: int = roundi(encoded[0].r * 255.0) * 256 + roundi(encoded[0].g * 255.0) - 510
	_check(stencil == 2, "Packed mesh colors must retain the exact source height stencil despite UNORM8 storage", failures)
	var invalid: Dictionary = fixture()
	invalid["tile_rows"][0][0][0] = 5000
	_check(not renderer.configure(invalid, _atlas()) and renderer._batches[0]["mesh"] == first_mesh
		and renderer.geometry_build_count == 1,
		"Rejected reconfiguration must leave the previous valid retained reference mesh untouched", failures)
	renderer.free()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
