extends RefCounted

## QA identity follows the same manifest as normal MainView. Older screenshots
## remain in their own version directories when a new artwork revision ships.
const Sprites = preload("res://scripts/view/sawmill_sprite_library.gd")


static func manifest_path() -> String:
	# An explicit preview override validates a candidate without changing normal
	# MainView defaults. No argument means the same active production manifest.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--manifest="):
			return args[index].trim_prefix("--manifest=")
		if args[index] == "--manifest" and index + 1 < args.size():
			return args[index + 1]
	return Sprites.MANIFEST_PATH


static func manifest() -> Dictionary:
	if not FileAccess.file_exists(manifest_path()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path()))
	return parsed if parsed is Dictionary else {}


static func output_path(operation: bool, leaf: String) -> String:
	var version: String = String(manifest().get("asset_version", manifest_path().get_base_dir().get_file()))
	var folder: String = ("sawmill-operation-" if operation else "sawmill-") + version
	return ProjectSettings.globalize_path("res://../docs/art/qa/" + folder + "/" + leaf).simplify_path()


static func focus(sprite: Dictionary) -> Vector2:
	var bounds: Array = manifest().get("alpha_bbox", [])
	if sprite.is_empty():
		return Vector2.ZERO
	if bounds.size() != 4:
		return (sprite["rect"] as Rect2).get_center()
	var center := Vector2(float(bounds[0]) + float(bounds[2]) * 0.5, float(bounds[1]) + float(bounds[3]) * 0.5)
	return (sprite["rect"] as Rect2).position + center * float(sprite["source_to_world"])


static func asset_hashes() -> Dictionary:
	var result: Dictionary = {}
	_add_hash(result, manifest_path())
	var data: Dictionary = manifest()
	var image: String = String(data.get("finished_image", ""))
	if not image.is_empty():
		_add_hash(result, manifest_path().get_base_dir().path_join(image))
	var rest: Dictionary = (data.get("life", {}) as Dictionary).get("rest_sprite", {})
	_add_hash(result, String(rest.get("texture", "")))
	for path: String in (rest.get("look_textures", {}) as Dictionary).values():
		_add_hash(result, path)
	var operation_path: String = String((data.get("operation", {}) as Dictionary).get("manifest", ""))
	_add_hash(result, operation_path)
	if not operation_path.is_empty() and FileAccess.file_exists(operation_path):
		var operation: Variant = JSON.parse_string(FileAccess.get_file_as_string(operation_path))
		if operation is Dictionary:
			for path: String in operation.get("asset_hashes", {}):
				_add_hash(result, path)
	return result


static func _add_hash(result: Dictionary, path: String) -> void:
	if not path.is_empty():
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
