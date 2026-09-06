class_name TerrainSandboxObjects
extends Node2D

# Optional study overlays, NOT faithful original KaM object graphics.
# TreeSpriteLibrary is our prototype painted art; ellipses are experimental
# contact shadows. Source map IDs/positions remain unchanged by every option.
const Trees = preload("res://scripts/view/tree_sprite_library.gd")
const DEFAULT_OPTIONS: Dictionary = {
	"trees": false,
	"shadows": false,
	"markers": false,
	"grid": false,
	"tree_scale": 1.0,
}
const MAX_OBJECTS: int = 4096
const GRID_COLOR := Color(0.80, 0.93, 0.83, 0.30)
const TREE_MARKER := Color(0.34, 0.94, 0.87, 0.95)
const OBJECT_MARKER := Color(1.0, 0.69, 0.23, 0.95)

var _renderer: Node2D
var _objects: Array[Dictionary] = []
var _options: Dictionary = DEFAULT_OPTIONS.duplicate(true)
var _trees: RefCounted
var _available_trees: int = 0


func configure(renderer: Node2D, source_objects: Array) -> void:
	_renderer = renderer
	_objects.clear()
	_available_trees = 0
	if _renderer == null or not _renderer.has_method("projected_point"):
		queue_redraw()
		return
	var dimensions: Vector2i = _renderer.get("sample_size")
	for value: Variant in source_objects.slice(0, MAX_OBJECTS):
		if not value is Dictionary:
			continue
		var entry: Dictionary = value as Dictionary
		if not _whole(entry.get("x"), 0, dimensions.x - 1) or not _whole(entry.get("y"), 0, dimensions.y - 1):
			continue
		if not _whole(entry.get("id"), 0, 65535) or not entry.get("kind") in ["tree", "object"]:
			continue
		if not _whole(entry.get("stage", 2), 0, 2):
			continue
		# Copy only the documented, scalar schema. Caller-owned data cannot
		# change this layer later and arbitrary extra metadata is not retained.
		var item: Dictionary = {
			"x": int(entry["x"]), "y": int(entry["y"]),
			"id": int(entry["id"]), "kind": String(entry["kind"]),
			"stage": int(entry.get("stage", 2)),
		}
		_objects.append(item)
		if item["kind"] == "tree":
			_available_trees += 1
	queue_redraw()


func set_options(values: Dictionary) -> void:
	for key: String in ["trees", "shadows", "markers", "grid"]:
		if values.get(key) is bool:
			_options[key] = values[key]
	var value: Variant = values.get("tree_scale")
	if (value is int or value is float) and is_finite(float(value)):
		_options["tree_scale"] = clampf(float(value), 0.5, 1.5)
	if bool(_options["trees"]) and _trees == null:
		_trees = Trees.new()
	queue_redraw()


func options_snapshot() -> Dictionary:
	return _options.duplicate(true)


# Counts describe available SOURCE records, even while their layers are off.
func tree_count() -> int:
	return _available_trees


func marker_count() -> int:
	return _objects.size()


func source_objects_snapshot() -> Array[Dictionary]:
	return _objects.duplicate(true)


# Project afresh, so changing visual relief cannot leave floating tree roots.
# Returning independent records also makes the projection/depth contract testable.
func projected_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not is_instance_valid(_renderer) or not _renderer.has_method("projected_point"):
		return entries
	for item: Dictionary in _objects:
		var entry: Dictionary = item.duplicate(true)
		entry["foot"] = _renderer.call("projected_point", Vector2(float(item["x"]) + 0.5, float(item["y"]) + 0.5))
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_foot: Vector2 = a["foot"]
		var b_foot: Vector2 = b["foot"]
		if not is_equal_approx(a_foot.y, b_foot.y):
			return a_foot.y < b_foot.y
		if a_foot.x != b_foot.x:
			return a_foot.x < b_foot.x
		return int(a["id"]) < int(b["id"]))
	return entries


func _draw() -> void:
	if not is_instance_valid(_renderer) or not _renderer.has_method("projected_point"):
		return
	if bool(_options["grid"]):
		_draw_grid()
	var entries: Array[Dictionary] = projected_entries()
	var sprite_scale: float = float(_options["tree_scale"])
	if bool(_options["shadows"]) and bool(_options["trees"]):
		for entry: Dictionary in entries:
			if entry["kind"] == "tree":
				_draw_contact_shadow(entry, sprite_scale)
	if bool(_options["trees"]) and _trees != null:
		for entry: Dictionary in entries:
			if entry["kind"] != "tree":
				continue
			var tree: Dictionary = _tree_identity(entry)
			var stage: int = int(entry["stage"])
			var texture: Texture2D = _trees.call("texture_for", tree, stage) as Texture2D
			if texture == null:
				continue
			var foot: Vector2 = entry["foot"]
			var root: Vector2 = _trees.call("root_offset_for", tree, stage)
			var dimensions: Vector2 = _trees.call("sprite_size", tree, stage)
			draw_texture_rect(texture, Rect2(foot - root * sprite_scale, dimensions * sprite_scale), false)
	if bool(_options["markers"]):
		for entry: Dictionary in entries:
			_draw_marker(entry, entries.size() <= 24)


func _draw_grid() -> void:
	var dimensions: Vector2i = _renderer.get("sample_size")
	for y: int in range(dimensions.y + 1):
		var points := PackedVector2Array()
		for x: int in range(dimensions.x + 1):
			points.append(_renderer.call("projected_point", Vector2(x, y)))
		draw_polyline(points, GRID_COLOR, 0.8, true)
	for x: int in range(dimensions.x + 1):
		var points := PackedVector2Array()
		for y: int in range(dimensions.y + 1):
			points.append(_renderer.call("projected_point", Vector2(x, y)))
		draw_polyline(points, GRID_COLOR, 0.8, true)


func _draw_contact_shadow(entry: Dictionary, sprite_scale: float) -> void:
	var foot: Vector2 = entry["foot"]
	var radius: float = (4.5 + float(entry["stage"]) * 4.2) * sprite_scale
	var points := PackedVector2Array()
	for index: int in range(20):
		var angle: float = TAU * float(index) / 20.0
		points.append(foot + Vector2(cos(angle) * radius, sin(angle) * radius * 0.34 + 1.0))
	draw_colored_polygon(points, Color(0.03, 0.06, 0.025, 0.25))


func _draw_marker(entry: Dictionary, show_id: bool) -> void:
	var foot: Vector2 = entry["foot"]
	var is_tree: bool = entry["kind"] == "tree"
	var color: Color = TREE_MARKER if is_tree else OBJECT_MARKER
	draw_circle(foot, 4.1, Color(0.025, 0.04, 0.03, 0.9))
	if is_tree:
		draw_circle(foot, 2.6, color)
	else:
		draw_line(foot + Vector2(-3, -3), foot + Vector2(3, 3), color, 1.6, true)
		draw_line(foot + Vector2(-3, 3), foot + Vector2(3, -3), color, 1.6, true)
	if show_id:
		var font: Font = ThemeDB.fallback_font
		draw_string_outline(font, foot + Vector2(6.0, 3.0), str(entry["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.025, 0.04, 0.03, 0.9))
		draw_string(font, foot + Vector2(6.0, 3.0), str(entry["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


static func _tree_identity(entry: Dictionary) -> Dictionary:
	return {"position": Vector2i(int(entry["x"]), int(entry["y"])), "id": int(entry["id"])}


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
