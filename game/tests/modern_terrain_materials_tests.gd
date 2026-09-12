extends RefCounted

const Materials = preload("res://scripts/view/modern_terrain_materials.gd")
const Renderer = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const ReferenceTests = preload("res://tests/kam_terrain_sample_tests.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_catalogue, _test_rotation, _test_normalization,
		_test_shared_edges, _test_source_immutable, _test_invalid_metadata,
		_test_configuration, _test_atomic_rejection, _test_pack_retention, _test_visual_controls]:
		test.call(failures)
	return failures


static func fixture() -> Dictionary:
	var patch: Dictionary = ReferenceTests.fixture()
	patch["tile_rows"] = [[[0, 0], [2, 1]], [[16, 2], [237, 3]]]
	return patch


static func modern_atlas() -> Image:
	var atlas := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [Color.GREEN, Color.YELLOW, Color.WHITE, Color.RED,
		Color.GRAY, Color.BLUE, Color.BLACK, Color.MAGENTA]
	for index: int in range(8):
		atlas.fill_rect(Rect2i((index % 4) * 64, (index / 4) * 64, 64, 64), colors[index])
	return atlas


static func _reference_atlas() -> Image:
	var atlas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.2, 0.6, 0.2))
	return atlas


static func _test_catalogue(failures: Array[String]) -> void:
	_check(Materials.TILE_KINDS.size() == 42, "Modern metadata must explicitly cover exactly the 42 sandbox terrain IDs", failures)
	for entry: Array in [[0, "GGGG"], [16, "PPPP"], [34, "MMMM"], [35, "DDDD"], [146, "OOOO"],
		[152, "CCCC"], [157, "RRRR"], [192, "WWWW"], [236, "WRWW"], [237, "RRRW"]]:
		_check(Materials.TILE_KINDS[entry[0]] == entry[1], "Modern metadata must preserve source terrain kinds", failures)
	_check(Materials.world_corner_kinds(1, 0).is_empty(), "Unmapped IDs must not silently substitute grass", failures)
	var mixed: PackedFloat32Array = Materials.kind_weights("M")
	_check(is_equal_approx(mixed[0], 0.65) and is_equal_approx(mixed[1], 0.25) and is_equal_approx(mixed[3], 0.10), "Mixed soil must use the documented own grass/dirt interpretation", failures)
	var dirt: PackedFloat32Array = Materials.kind_weights("D")
	_check(is_equal_approx(dirt[0], 0.45) and is_equal_approx(dirt[1], 0.40) and is_equal_approx(dirt[3], 0.15),
		"Source dirt must retain its vegetated, olive-earth art direction instead of turning all shores bare brown", failures)


static func _test_rotation(failures: Array[String]) -> void:
	var expected: Array = [["G", "P", "G", "G"], ["G", "G", "P", "G"],
		["G", "G", "G", "P"], ["P", "G", "G", "G"]]
	for rotation: int in range(4):
		_check(Materials.world_corner_kinds(66, rotation) == expected[rotation],
			"Corner metadata rotation must match the existing clockwise source UV assignment", failures)
	_check(Materials.world_corner_kinds(66, -1).is_empty() and Materials.world_corner_kinds(66, 4).is_empty(),
		"Invalid rotations must be rejected", failures)


static func _test_normalization(failures: Array[String]) -> void:
	var result: Dictionary = Materials.build_weights(fixture())
	_check(result["error"] == "", "Synthetic weight fixture must build", failures)
	if result["error"] != "":
		return
	var low: Image = result["low"]
	var high: Image = result["high"]
	_check(low.get_size() == Vector2i(3, 3) and high.get_size() == Vector2i(3, 3)
		and low.get_format() == Image.FORMAT_RGBAF, "Shared material weights must retain float precision on the vertex grid", failures)
	for y: int in range(3):
		for x: int in range(3):
			var a: Color = low.get_pixel(x, y)
			var b: Color = high.get_pixel(x, y)
			_check(is_equal_approx(a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a, 1.0),
				"All source vertex weights must be normalized", failures)


static func _test_shared_edges(failures: Array[String]) -> void:
	var patch: Dictionary = fixture()
	patch["tile_rows"] = [[[0, 0], [157, 0]], [[0, 0], [157, 0]]]
	var result: Dictionary = Materials.build_weights(patch)
	var low: Image = result["low"]
	for y: int in range(3):
		var shared: Color = low.get_pixel(1, y)
		_check(is_equal_approx(shared.r, 0.5) and is_equal_approx(shared.b, 0.5),
			"Disagreeing touching grass/rock corners must reconcile into one shared edge value", failures)
	_check(low.get_pixel(0, 1).r == 1.0 and low.get_pixel(2, 1).b == 1.0,
		"Corner reconciliation must not contaminate unrelated pure material interiors", failures)
	_check(Renderer.MODERN_SHADER.contains("weights_low : filter_linear")
		and Renderer.MODERN_SHADER.contains("(terrain_grid * weight_scale + vec2(0.5)) / weight_dimensions")
		and Renderer.MODERN_SHADER.contains("uniform float weight_scale = 1.0;"),
		"Native shader must sample weights continuously at half-texel aligned vertices", failures)


static func _test_source_immutable(failures: Array[String]) -> void:
	var patch: Dictionary = fixture()
	var before: Dictionary = patch.duplicate(true)
	Materials.build_weights(patch)
	_check(patch == before, "Modern metadata extraction must not modify source map data", failures)
	_check(Renderer.MODERN_SHADER.contains("world_grid / 4.0") and Renderer.MODERN_SHADER.contains("vec2(2.0) / atlas_pixels"),
		"Modern atlas must use global four-cell mirrored swatches with safe normalized insets", failures)


static func _test_invalid_metadata(failures: Array[String]) -> void:
	for changes: Dictionary in [{"size": [0, 2]}, {"size": [2.5, 2]}, {"size": [true, 2]},
		{"tile_rows": []}, {"tile_rows": [[[999, 0], [0, 0]], [[0, 0], [0, 0]]]},
		{"tile_rows": [[[0, 5], [0, 0]], [[0, 0], [0, 0]]]},
		{"tile_rows": [[[1, 0], [0, 0]], [[0, 0], [0, 0]]]}]:
		var patch: Dictionary = fixture()
		patch.merge(changes, true)
		_check(not String(Materials.build_weights(patch)["error"]).is_empty(),
			"Malformed or unsupported modern terrain data must fail explicitly", failures)


static func _test_configuration(failures: Array[String]) -> void:
	var renderer := Renderer.new()
	var patch: Dictionary = fixture()
	var atlas: Image = modern_atlas()
	var pixels: PackedByteArray = atlas.get_data()
	_check(not renderer.configure_modern_materials(patch, atlas), "Modern configuration requires existing reference geometry", failures)
	_check(renderer.configure(patch, _reference_atlas()) and renderer.configure_modern_materials(patch, atlas),
		"Supported modern terrain fixture must configure: " + renderer.last_error, failures)
	_check(renderer.modern_available() and renderer.visual_options()["texture_pack"] == "classic"
		and renderer.material == renderer._classic_material, "Adding a modern pack must preserve the classic default", failures)
	_check(atlas.get_data() == pixels, "Configuring modern rendering must never rewrite the authored atlas", failures)
	var odd := Image.create(1774, 887, false, Image.FORMAT_RGBA8)
	odd.fill(Color.WHITE)
	_check(renderer.configure_modern_materials(patch, odd), "Half-pixel atlas cell boundaries must be accepted with normalized UVs", failures)
	renderer.free()


static func _test_atomic_rejection(failures: Array[String]) -> void:
	var renderer := Renderer.new()
	var patch: Dictionary = fixture()
	renderer.configure(patch, _reference_atlas())
	renderer.configure_modern_materials(patch, modern_atlas())
	renderer.set_visual_options({"texture_pack": "modern"})
	var previous: Material = renderer.material
	var invalid: Dictionary = patch.duplicate(true)
	invalid["tile_rows"][0][0][0] = 1
	_check(not renderer.configure_modern_materials(invalid, modern_atlas()) and renderer.material == previous,
		"A mismatched patch must not replace material state on retained geometry", failures)
	_check(not renderer.configure_modern_materials(patch, null)
		and not renderer.configure_modern_materials(patch, Image.create(64, 64, false, Image.FORMAT_RGBA8))
		and renderer.material == previous and renderer.modern_material_build_count == 1,
		"Invalid modern atlases must leave the previous usable pack untouched", failures)
	renderer.free()
	var unsupported := Renderer.new()
	var unsupported_patch: Dictionary = ReferenceTests.fixture()
	unsupported.configure(unsupported_patch, _reference_atlas())
	_check(not unsupported.configure_modern_materials(unsupported_patch, modern_atlas())
		and unsupported.last_error.contains("tile 1"), "Unsupported catalogue IDs must report the exact missing definition", failures)
	unsupported.set_visual_options({"texture_pack": "modern"})
	_check(unsupported.visual_options()["texture_pack"] == "classic", "Unavailable packs must not silently change active selection", failures)
	unsupported.free()


static func _test_pack_retention(failures: Array[String]) -> void:
	var renderer := Renderer.new()
	var patch: Dictionary = fixture()
	renderer.configure(patch, _reference_atlas())
	renderer.configure_modern_materials(patch, modern_atlas())
	var mesh: ArrayMesh = renderer._batches[0]["mesh"]
	var bounds: Rect2 = renderer.bounds()
	var classic: Material = renderer._classic_material
	var modern: Material = renderer._modern_material
	for iteration: int in range(10):
		renderer.set_visual_options({"texture_pack": "modern"})
		_check(renderer.material == modern, "Selecting own art must use the prepared modern material", failures)
		renderer.set_visual_options({"texture_pack": "classic"})
		_check(renderer.material == classic, "Selecting classic art must restore the exact original material resource", failures)
	_check(renderer._batches[0]["mesh"] == mesh and renderer.bounds() == bounds
		and renderer.geometry_build_count == 1 and renderer.modern_material_build_count == 1,
		"Repeated pack swaps must not rebuild meshes, textures, source data, or bounds", failures)
	renderer.set_visual_options({"texture_pack": "unknown"})
	_check(renderer.visual_options()["texture_pack"] == "classic", "Unknown pack choices must be ignored", failures)
	renderer.free()


static func _test_visual_controls(failures: Array[String]) -> void:
	var renderer := Renderer.new()
	var patch: Dictionary = fixture()
	renderer.configure(patch, _reference_atlas())
	renderer.configure_modern_materials(patch, modern_atlas())
	renderer.set_visual_options({"texture_pack": "modern", "textures": false, "lighting": false,
		"light_strength": 0.4, "relief_scale": 0.7, "linear_filter": true})
	for material: ShaderMaterial in [renderer._classic_material, renderer._modern_material]:
		_check(material.get_shader_parameter("use_textures") == false and material.get_shader_parameter("use_lighting") == false
			and is_equal_approx(material.get_shader_parameter("relief_scale"), 0.7),
			"Existing lighting, texture and height controls must update both cached packs", failures)
	var nearest_atlas: Texture2D = renderer._modern_material.get_shader_parameter("material_atlas_nearest")
	var linear_atlas: Texture2D = renderer._modern_material.get_shader_parameter("material_atlas_linear")
	_check(nearest_atlas.get_rid() != linear_atlas.get_rid(),
		"Compatibility rendering needs independent cached atlas RIDs for distinct sampler filters", failures)
	_check(renderer._modern_material.get_shader_parameter("linear_filter") == true
		and Renderer.MODERN_SHADER.contains("filter_nearest") and Renderer.MODERN_SHADER.contains("filter_linear"),
		"Modern material sampling must respect the nearest/linear filter control", failures)
	_check(Renderer.MODERN_SHADER.contains("light_gradient(terrain_light)")
		and Renderer.MODERN_SHADER.contains("stencil * relief_scale / 44.0"),
		"Fair comparison must retain the classic signed-light formula and source geometry", failures)
	renderer.free()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
