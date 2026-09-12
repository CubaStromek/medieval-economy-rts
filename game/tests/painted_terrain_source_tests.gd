extends RefCounted

const Source = preload("res://scripts/view/painted_terrain_source.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const TEST_COUNT: int = 7


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_attach, _test_atomic_rejection, _test_copy,
		_test_invalid_dimensions, _test_invalid_values, _test_halo, _test_missing_file]:
		test.call(failures)
	return failures


static func fixture() -> Dictionary:
	return {"format": Source.FORMAT, "source_sha256": Source.SOURCE_SHA256,
		"size": [2, 1], "origin": [0, 0], "height_scale": 0.15,
		"corner_kinds": [["GPRD", "MWCO"]], "raw_heights": [[0, 7, 13], [20, 27, 33]],
		"base_heights": [[0, 1, 2], [3, 4, 5]], "base_terrain": ["gw"],
		"water_vertices": [[false, false, true], [false, true, true]]}


static func _test_attach(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 1))
	grid.set_base_terrain(Vector2i.ZERO, "rock")
	grid.set_vertex_height(Vector2i.ONE, 6)
	var before_terrain := grid._base_terrain.duplicate()
	var before_heights := grid._vertex_heights.duplicate()
	var before_revision: int = grid.revision
	_check(Source.attach_data(grid, fixture()), "Valid V1 semantic source must attach", failures)
	_check(grid.get_meta(Source.META_KEY) == fixture(), "V1 source metadata must retain all validated data", failures)
	_check(grid._base_terrain == before_terrain and grid._vertex_heights == before_heights
		and grid.revision == before_revision, "Attaching source art must never modify restored/current gameplay terrain", failures)


static func _test_atomic_rejection(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 1))
	Source.attach_data(grid, fixture())
	var invalid := fixture()
	invalid["source_sha256"] = "a".repeat(64)
	_check(not Source.attach_data(grid, invalid) and grid.get_meta(Source.META_KEY) == fixture(),
		"Wrong provenance must fail without replacing an attached source", failures)


static func _test_copy(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 1))
	var source := fixture()
	Source.attach_data(grid, source)
	source["corner_kinds"][0][0] = "WWWW"
	source["raw_heights"][0][0] = 255
	_check(grid.get_meta(Source.META_KEY) == fixture(), "External callers must not mutate attached metadata after validation", failures)


static func _test_invalid_dimensions(failures: Array[String]) -> void:
	for size: Variant in [[], [2], [2, 1, 0], [3, 1], [2.5, 1], [true, 1]]:
		var data := fixture()
		data["size"] = size
		_check(not Source.valid_data(data, Vector2i(2, 1)), "Mismatched/fractional visual source dimensions must fail", failures)
	for key: String in ["corner_kinds", "raw_heights", "base_heights", "base_terrain", "water_vertices"]:
		var data := fixture()
		data[key] = []
		_check(not Source.valid_data(data, Vector2i(2, 1)), "Incomplete visual source lattice must fail: " + key, failures)


static func _test_invalid_values(failures: Array[String]) -> void:
	for entry: Array in [["raw_heights", 256], ["raw_heights", -1], ["raw_heights", NAN],
		["base_heights", 65], ["base_heights", 1.5], ["water_vertices", 2], ["water_vertices", "true"]]:
		var data := fixture()
		data[entry[0]][0][0] = entry[1]
		_check(not Source.valid_data(data, Vector2i(2, 1)), "Invalid visual source values must fail before attachment", failures)
	var data := fixture()
	data["corner_kinds"][0][0] = "GXGG"
	_check(not Source.valid_data(data, Vector2i(2, 1)), "Unknown modern corner kind must fail", failures)
	data = fixture()
	data["base_terrain"][0] = "gx"
	_check(not Source.valid_data(data, Vector2i(2, 1)), "Unknown baseline terrain must fail", failures)


static func _test_halo(failures: Array[String]) -> void:
	var data := fixture()
	data["raw_height_halo"] = [[0, 0, 7, 13, 13], [0, 0, 7, 13, 13],
		[20, 20, 27, 33, 33], [20, 20, 27, 33, 33]]
	_check(Source.valid_data(data, Vector2i(2, 1)), "Consistent clamped raw-height halo must validate", failures)
	data["raw_height_halo"][0][0] = 2
	_check(not Source.valid_data(data, Vector2i(2, 1)), "Inconsistent edge halo must fail", failures)


static func _test_missing_file(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 1))
	_check(not Source.attach(grid, "res://external_assets/maps/nonexistent-v1-test.json")
		and not grid.has_meta(Source.META_KEY), "Missing optional metadata must leave normal V1 rendering available", failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
