extends RefCounted

const Sample = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const Baseline = preload("res://tests/kam_terrain_sample_tests.gd")
const TEST_COUNT: int = 8


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_default_settings, _test_partial_settings,
		_test_bounds_and_clamps, _test_retained_meshes, _test_triangle_projection,
		_test_source_isolation, _test_raw_height_encoding, _test_reconfiguration]:
		test.call(failures)
	return failures


static func _configured() -> Node2D:
	var renderer := Sample.new()
	renderer.configure(Baseline.fixture(), Baseline._atlas())
	return renderer


static func _test_default_settings(failures: Array[String]) -> void:
	var renderer := _configured()
	_check(renderer.visual_options() == Sample.DEFAULT_VISUAL_OPTIONS,
		"Sandbox defaults must preserve the original reference configuration", failures)
	var shader_material: ShaderMaterial = renderer.material as ShaderMaterial
	_check(shader_material.get_shader_parameter("use_textures") == true
		and shader_material.get_shader_parameter("use_lighting") == true
		and shader_material.get_shader_parameter("light_strength") == 1.0
		and shader_material.get_shader_parameter("relief_scale") == 1.0
		and renderer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"All default visual options must actually reach the native material", failures)
	_check(renderer.projected_point(Vector2(1, 2)).is_equal_approx(Sample.project_vertex(Vector2i(1, 2), 30.0)),
		"Default projected anchors must match the original reference projection", failures)
	renderer.free()


static func _test_partial_settings(failures: Array[String]) -> void:
	var renderer := _configured()
	renderer.set_visual_options({"textures": false, "lighting": false, "linear_filter": true})
	var expected: Dictionary = Sample.DEFAULT_VISUAL_OPTIONS.duplicate()
	expected.merge({"textures": false, "lighting": false, "linear_filter": true}, true)
	_check(renderer.visual_options() == expected
		and renderer.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"Partial option updates must leave untouched values alone and switch filtering", failures)
	var shader_material: ShaderMaterial = renderer.material as ShaderMaterial
	_check(shader_material.get_shader_parameter("use_textures") == false
		and shader_material.get_shader_parameter("use_lighting") == false,
		"Texture and lighting toggles must update real shader uniforms", failures)
	renderer.set_visual_options({"textures": 1, "lighting": "true", "linear_filter": null,
		"light_strength": INF, "relief_scale": NAN, "unknown": 200})
	_check(renderer.visual_options() == expected,
		"Wrong types, nonfinite numbers, and unknown keys must not corrupt visual settings", failures)
	var copy: Dictionary = renderer.visual_options()
	copy["textures"] = true
	_check(renderer.visual_options()["textures"] == false,
		"Callers must receive a copy, not a mutable renderer settings reference", failures)
	renderer.free()


static func _test_bounds_and_clamps(failures: Array[String]) -> void:
	var renderer := _configured()
	renderer.set_visual_options({"relief_scale": -2, "light_strength": 6})
	_check(renderer.visual_options()["relief_scale"] == 0.0
		and renderer.visual_options()["light_strength"] == 1.5
		and renderer.bounds().is_equal_approx(Rect2(0, 0, 80, 80)),
		"Options must clamp to 0..1.5 and zero relief must give exact flat bounds", failures)
	renderer.set_visual_options({"relief_scale": 8, "light_strength": -1})
	var expected_top: float = -30.0 * 40.0 / 33.333 * 1.5
	_check(renderer.visual_options()["relief_scale"] == 1.5
		and renderer.visual_options()["light_strength"] == 0.0
		and renderer.bounds().is_equal_approx(Rect2(0, expected_top, 80, 80)),
		"Maximum relief bounds must follow actual shader displacement, not the original mesh", failures)
	renderer.free()


static func _test_retained_meshes(failures: Array[String]) -> void:
	var renderer := _configured()
	var mesh: ArrayMesh = renderer._batches[0]["mesh"]
	var texture: ImageTexture = renderer._batches[0]["texture"]
	var first_material: Material = renderer.material
	for i: int in range(20):
		renderer.set_visual_options({"relief_scale": float(i) / 13.0,
			"light_strength": float(i) / 17.0, "textures": i % 2 == 0,
			"lighting": i % 3 == 0, "linear_filter": i % 2 == 1})
	_check(renderer.geometry_build_count == 1 and renderer._batches[0]["mesh"] == mesh
		and renderer._batches[0]["texture"] == texture and renderer.material == first_material,
		"Moving sliders or toggling options must reuse the same meshes, textures, and material", failures)
	renderer.free()


static func _test_triangle_projection(failures: Array[String]) -> void:
	var renderer := Sample.new()
	var patch: Dictionary = Baseline.fixture()
	# Saddle corners distinguish exact TL-BR triangles from bilinear sampling.
	patch["height_halo"][1][1] = 0
	patch["height_halo"][1][2] = 40
	patch["height_halo"][2][2] = 0
	patch["height_halo"][2][1] = 80
	renderer.configure(patch, Baseline._atlas())
	_check(renderer.projected_point(Vector2(0.5, 0.5)).is_equal_approx(Vector2(20, 20)),
		"Anchors on the TL-BR diagonal must not use bilinear saddle interpolation", failures)
	_check(renderer.projected_point(Vector2(0.75, 0.25)).is_equal_approx(Vector2(30, 10 - 20.0 * 40.0 / 33.333))
		and renderer.projected_point(Vector2(0.25, 0.75)).is_equal_approx(Vector2(10, 30 - 40.0 * 40.0 / 33.333)),
		"Anchors must use the correct upper-right and lower-left triangle heights", failures)
	_check(renderer.projected_point(Vector2(-1, -1)) == renderer.projected_point(Vector2.ZERO)
		and renderer.projected_point(Vector2(20, 20)) == renderer.projected_point(Vector2(2, 2))
		and renderer.projected_point(Vector2(NAN, 0)) == Vector2.ZERO,
		"Out-of-patch and nonfinite coordinates must be handled safely", failures)
	renderer.set_visual_options({"relief_scale": 0.5})
	_check(renderer.projected_point(Vector2(0.25, 0.75)).is_equal_approx(Vector2(10, 30 - 20.0 * 40.0 / 33.333)),
		"Fractional anchors must track the same relief scale as native terrain vertices", failures)
	renderer.free()


static func _test_source_isolation(failures: Array[String]) -> void:
	var renderer := Sample.new()
	var patch: Dictionary = Baseline.fixture()
	var before: Dictionary = patch.duplicate(true)
	var atlas: Image = Baseline._atlas()
	var pixels: PackedByteArray = atlas.get_data()
	renderer.configure(patch, atlas)
	renderer.set_visual_options({"relief_scale": 1.5, "light_strength": 0.5, "textures": false})
	_check(patch == before and atlas.get_data() == pixels,
		"Visual experimentation must not modify original patch data or bitmap pixels", failures)
	var anchor: Vector2 = renderer.projected_point(Vector2.ZERO)
	patch["height_halo"][1][1] = 255
	renderer.set_visual_options({"lighting": false})
	_check(renderer.projected_point(Vector2.ZERO) == anchor,
		"The renderer must retain its own height copy so caller changes cannot detach anchors from meshes", failures)
	renderer.free()


static func _test_raw_height_encoding(failures: Array[String]) -> void:
	var renderer := Sample.new()
	var patch: Dictionary = Baseline.fixture()
	patch["height_halo"][1][1] = 255
	patch["height_halo"][1][2] = 0
	patch["height_halo"][2][2] = 127
	renderer.configure(patch, Baseline._atlas())
	var mesh: ArrayMesh = renderer._batches[0]["mesh"]
	var arrays: Array = mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_check(roundi(colors[0].a * 255.0) == 255 and roundi(colors[1].a * 255.0) == 0
		and roundi(colors[2].a * 255.0) == 127,
		"Packed mesh alpha must preserve all raw height values for shader-only relief", failures)
	_check(Sample.LIGHT_SHADER.contains("stencil * relief_scale / 44.0")
		and Sample.LIGHT_SHADER.contains("terrain_light * 1.3 + 0.1"),
		"Visual relief must also scale slope lighting while retaining the original water bias", failures)
	renderer.free()


static func _test_reconfiguration(failures: Array[String]) -> void:
	var renderer := Sample.new()
	renderer.set_visual_options({"relief_scale": 0.5, "textures": false})
	_check(renderer.bounds() == Rect2() and renderer.projected_point(Vector2.ONE) == Vector2.ZERO,
		"Options and projection must be safe before an external patch is configured", failures)
	renderer.configure(Baseline.fixture(), Baseline._atlas())
	_check(renderer.visual_options()["relief_scale"] == 0.5
		and renderer.visual_options()["textures"] == false
		and renderer.geometry_build_count == 1,
		"Selecting another patch must preserve current visual controls", failures)
	var bounds_before: Rect2 = renderer.bounds()
	var invalid: Dictionary = Baseline.fixture()
	invalid["size"] = [0, 0]
	_check(not renderer.configure(invalid, Baseline._atlas()) and renderer.bounds() == bounds_before
		and renderer.visual_options()["relief_scale"] == 0.5,
		"Rejected patches must preserve the current display and settings", failures)
	renderer.set_visual_options(Sample.DEFAULT_VISUAL_OPTIONS)
	_check(renderer.visual_options() == Sample.DEFAULT_VISUAL_OPTIONS
		and renderer.projected_point(Vector2.ZERO).is_equal_approx(Sample.project_vertex(Vector2i.ZERO, 30.0)),
		"Reference reset must restore every option and the original projection", failures)
	renderer.free()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
