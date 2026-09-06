extends RefCounted

const Objects = preload("res://scripts/view/terrain_sandbox_objects.gd")
const TEST_COUNT: int = 7


class ProjectionStub:
	extends Node2D
	var sample_size := Vector2i(4, 3)
	var relief: float = 1.0

	func projected_point(point: Vector2) -> Vector2:
		return point * 40.0 - Vector2(0.0, point.x * 12.0 * relief)


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_defaults, _test_immutable_source, _test_validation,
		_test_options, _test_projection_and_depth, _test_relief_refresh, _test_missing_renderer]:
		test.call(failures)
	return failures


static func fixture() -> Array:
	return [
		{"x": 0, "y": 1, "id": 71, "kind": "tree", "stage": 2},
		{"x": 3, "y": 1, "id": 82, "kind": "tree", "stage": 1},
		{"x": 1, "y": 0, "id": 43, "kind": "object", "stage": 0},
	]


static func _test_defaults(failures: Array[String]) -> void:
	var renderer := ProjectionStub.new()
	var layer := Objects.new()
	layer.configure(renderer, fixture())
	_check(layer.tree_count() == 2 and layer.marker_count() == 3,
		"Object counts describe source trees and all source records even when layers are hidden", failures)
	var options: Dictionary = layer.options_snapshot()
	_check(not options["trees"] and not options["shadows"] and not options["markers"] and not options["grid"]
		and options["tree_scale"] == 1.0, "All experimental overlays must default off", failures)
	layer.free()
	renderer.free()


static func _test_immutable_source(failures: Array[String]) -> void:
	var renderer := ProjectionStub.new()
	var layer := Objects.new()
	var source: Array = fixture()
	var before: Array = source.duplicate(true)
	layer.configure(renderer, source)
	layer.set_options({"markers": true, "tree_scale": 1.3})
	_check(source == before, "Configuring and adjusting overlays must not mutate source records", failures)
	source[0]["x"] = 99
	source.clear()
	var snapshot: Array[Dictionary] = layer.source_objects_snapshot()
	_check(snapshot.size() == 3 and int(snapshot[0]["x"]) == 0,
		"Configured source must be a private copy independent of caller mutations", failures)
	snapshot[0]["id"] = 1
	_check(int(layer.source_objects_snapshot()[0]["id"]) == 71,
		"An object snapshot must not expose the retained source to mutation", failures)
	layer.free()
	renderer.free()


static func _test_validation(failures: Array[String]) -> void:
	var renderer := ProjectionStub.new()
	var layer := Objects.new()
	var records: Array = fixture()
	records.append_array([null, 17, {}, {"x": -1, "y": 0, "id": 1, "kind": "tree"},
		{"x": 4, "y": 0, "id": 1, "kind": "tree"}, {"x": 0, "y": 3, "id": 1, "kind": "tree"},
		{"x": 0.5, "y": 0, "id": 1, "kind": "tree"}, {"x": true, "y": 0, "id": 1, "kind": "tree"},
		{"x": 0, "y": 0, "id": NAN, "kind": "tree"}, {"x": 0, "y": 0, "id": -1, "kind": "tree"},
		{"x": 0, "y": 0, "id": 1, "kind": "unit"}, {"x": 0, "y": 0, "id": 1, "kind": "tree", "stage": 5}])
	layer.configure(renderer, records)
	_check(layer.tree_count() == 2 and layer.marker_count() == 3,
		"Out-of-patch coordinates, invalid stages/kinds and noninteger source values must be ignored", failures)
	layer.configure(renderer, [{"x": 3.0, "y": 2.0, "id": 0.0, "kind": "tree"}])
	_check(layer.tree_count() == 1 and int(layer.source_objects_snapshot()[0]["stage"]) == 2,
		"Whole JSON numbers are valid source coordinates and an omitted stage defaults to mature", failures)
	layer.free()
	renderer.free()


static func _test_options(failures: Array[String]) -> void:
	var layer := Objects.new()
	layer.set_options({"markers": true, "grid": true, "shadows": true, "tree_scale": 20.0, "unknown": true})
	var options: Dictionary = layer.options_snapshot()
	_check(options["markers"] and options["grid"] and options["shadows"] and not options.has("unknown")
		and options["tree_scale"] == 1.5, "Settings must accept known flags and clamp oversized trees", failures)
	options["markers"] = false
	_check(layer.options_snapshot()["markers"], "Settings snapshots must not mutate retained settings", failures)
	layer.set_options({"markers": "yes", "grid": 1, "tree_scale": NAN})
	_check(layer.options_snapshot()["markers"] and layer.options_snapshot()["grid"]
		and layer.options_snapshot()["tree_scale"] == 1.5, "Invalid option types and NaN must preserve prior options", failures)
	layer.set_options({"tree_scale": -1.0})
	_check(layer.options_snapshot()["tree_scale"] == 0.5, "Tree scale must have a positive lower bound", failures)
	layer.free()


static func _test_projection_and_depth(failures: Array[String]) -> void:
	var renderer := ProjectionStub.new()
	var layer := Objects.new()
	layer.configure(renderer, fixture())
	var entries: Array[Dictionary] = layer.projected_entries()
	_check(entries.size() == 3 and int(entries[0]["id"]) == 43 and int(entries[1]["id"]) == 82
		and int(entries[2]["id"]) == 71, "Sprite order must follow projected ground depth, not source row or ID", failures)
	for entry: Dictionary in entries:
		var cell_center := Vector2(float(entry["x"]) + 0.5, float(entry["y"]) + 0.5)
		_check((entry["foot"] as Vector2).is_equal_approx(renderer.projected_point(cell_center)),
			"Tree and marker roots must use the renderer's exact center-of-cell projection", failures)
	layer.free()
	renderer.free()


static func _test_relief_refresh(failures: Array[String]) -> void:
	var renderer := ProjectionStub.new()
	var layer := Objects.new()
	layer.configure(renderer, fixture())
	var before: Array[Dictionary] = layer.source_objects_snapshot()
	renderer.relief = 0.0
	layer.queue_redraw()
	var entries: Array[Dictionary] = layer.projected_entries()
	for entry: Dictionary in entries:
		_check(is_equal_approx((entry["foot"] as Vector2).y, (float(entry["y"]) + 0.5) * 40.0),
			"Visual relief changes must reproject every object without changing source coordinates", failures)
	_check(layer.source_objects_snapshot() == before, "Relief experiments must not edit source object data", failures)
	layer.free()
	renderer.free()


static func _test_missing_renderer(failures: Array[String]) -> void:
	var layer := Objects.new()
	layer.configure(null, fixture())
	_check(layer.marker_count() == 0 and layer.projected_entries().is_empty(),
		"A missing renderer must yield an empty overlay rather than an error", failures)
	var renderer := ProjectionStub.new()
	layer.configure(renderer, fixture())
	renderer.free()
	_check(layer.projected_entries().is_empty(), "Freed terrain must not be accessed by a retained object overlay", failures)
	layer.free()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
