class_name SawmillSpriteLibrary
extends RefCounted

## A completed sawmill has its own measured registration. Construction keeps
## the existing scaffold; no lumber-hut stages or collision changes are reused.
const MANIFEST_PATH := "res://art/buildings/sawmill/v2/manifest.json"
const ALPHA_THRESHOLD: float = 0.10
static var _cache: Dictionary = {}

var _asset: Dictionary = {}


func _init(manifest_path: String = MANIFEST_PATH) -> void:
	if _cache.has(manifest_path):
		_asset = _cache[manifest_path]
		return
	_asset = _load_asset(manifest_path)
	# A missing/incomplete delivery is not cached: a later scene may load the
	# now-imported asset, while valid houses share one texture and alpha mask.
	if not _asset.is_empty():
		_cache[manifest_path] = _asset


func supports(building: Dictionary) -> bool:
	return not _asset.is_empty() and String(building.get("type", "")) == "sawmill" \
		and int(building.get("footprint_version", 0)) == 1 \
		and int(building.get("foundation_work_remaining", 0)) == 0 \
		and int(building.get("construction_remaining", 0)) == 0


func presentation_for(building: Dictionary, _definition: Dictionary, door: Vector2) -> Dictionary:
	if not supports(building):
		return {}
	var data: Dictionary = _asset["manifest"]
	var scale: float = float(data["source_to_world"])
	var threshold: Vector2 = _vector(data["door_threshold"])
	return {"texture": _asset["texture"], "hit_mask": _asset["hit_mask"],
		"rect": Rect2(door - threshold * scale, _vector(data["canvas"]) * scale),
		"source_to_world": scale, "door_threshold": threshold,
		"sort_foot": _vector(data["sort_foot"]), "label_anchor": _vector(data["label_anchor"]),
		"phase": "complete", "progress": 1.0, "building_id": "sawmill",
		"life": data.get("life", {}), "operation": data.get("operation", {})}


func visual_ground_position(building: Dictionary, door_cell: Vector2i, cell_height: float) -> Vector2:
	var anchor := Vector2(building["position"] as Vector2i)
	if not supports(building) or not is_finite(cell_height) or cell_height <= 0.0:
		return anchor
	var data: Dictionary = _asset["manifest"]
	var source_delta: Vector2 = _vector(data["sort_foot"]) - _vector(data["door_threshold"])
	# This painter orders by ground Y. Keep the map X, and never use this
	# sorting allowance for projection, occupied cells or shadow receivers.
	return Vector2(anchor.x, float(door_cell.y) + 0.5 + source_delta.y * float(data["source_to_world"]) / cell_height)


static func contains_point(presentation: Dictionary, point: Vector2) -> bool:
	if presentation.is_empty():
		return false
	var rect: Rect2 = presentation["rect"]
	var mask: BitMap = presentation.get("hit_mask") as BitMap
	if mask == null or not rect.has_point(point):
		return false
	return mask.get_bitv(Vector2i((point - rect.position) / float(presentation["source_to_world"])))


static func validate_manifest(data: Dictionary) -> bool:
	if data.get("schema_version") != 1 or data.get("building_id") != "sawmill" or data.get("asset_version") not in ["v1", "v2"]:
		return false
	if not _finite_numbers(data.get("canvas"), 2) or not _finite_numbers(data.get("alpha_bbox"), 4):
		return false
	var size: Vector2 = _vector(data["canvas"])
	if size.x < 2 or size.y < 2 or size.x > 4096 or size.y > 4096 or size != size.floor():
		return false
	for key: String in ["door_threshold", "sort_foot", "label_anchor"]:
		if not _finite_numbers(data.get(key), 2):
			return false
		var point: Vector2 = _vector(data[key])
		if point.x < 0 or point.y < 0 or point.x > size.x or point.y > size.y:
			return false
	if not _finite_number(data.get("source_to_world")) or float(data["source_to_world"]) <= 0.0 or float(data["source_to_world"]) > 1.0:
		return false
	var bounds: Array = data["alpha_bbox"]
	for component: Variant in bounds:
		if float(component) != floorf(float(component)):
			return false
	if float(bounds[0]) < 0 or float(bounds[1]) < 0 or float(bounds[2]) <= 0 or float(bounds[3]) <= 0 \
			or float(bounds[0]) + float(bounds[2]) > size.x or float(bounds[1]) + float(bounds[3]) > size.y:
		return false
	var filename: Variant = data.get("finished_image")
	if not filename is String or String(filename).is_empty() or String(filename).get_file() != filename or not String(filename).ends_with(".png"):
		return false
	if not _valid_sha256(data.get("finished_rgba_sha256")):
		return false
	if data.has("finished_sha256") and not _valid_sha256(data["finished_sha256"]):
		return false
	return (not data.has("life") or data["life"] is Dictionary) \
		and (not data.has("operation") or data["operation"] is Dictionary)


static func _load_asset(manifest_path: String) -> Dictionary:
	if not FileAccess.file_exists(manifest_path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not value is Dictionary or not validate_manifest(value as Dictionary):
		push_warning("Sawmill registration is invalid; using the existing building renderer.")
		return {}
	var data: Dictionary = value as Dictionary
	var path: String = manifest_path.get_base_dir().path_join(String(data["finished_image"]))
	if not ResourceLoader.exists(path):
		return {}
	if data.has("finished_sha256") and FileAccess.file_exists(path) and FileAccess.get_sha256(path) != data["finished_sha256"]:
		push_warning("Sawmill source hash does not match its manifest; using the existing building renderer.")
		return {}
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return {}
	var pixels: Image = texture.get_image()
	if pixels == null or pixels.is_empty() or Vector2(pixels.get_size()) != _vector(data["canvas"]):
		return {}
	if pixels.is_compressed() and pixels.decompress() != OK:
		return {}
	pixels.convert(Image.FORMAT_RGBA8)
	pixels.clear_mipmaps()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(pixels.get_data())
	if hashing.finish().hex_encode() != data["finished_rgba_sha256"]:
		push_warning("Sawmill imported pixels do not match its manifest; using the existing building renderer.")
		return {}
	var hit_mask := BitMap.new()
	hit_mask.create_from_image_alpha(pixels, ALPHA_THRESHOLD)
	var actual_bounds := Rect2i()
	var visible: int = 0
	for y: int in range(pixels.get_height()):
		for x: int in range(pixels.get_width()):
			if not hit_mask.get_bit(x, y):
				continue
			visible += 1
			var pixel_rect := Rect2i(x, y, 1, 1)
			actual_bounds = pixel_rect if not actual_bounds.has_area() else actual_bounds.merge(pixel_rect)
	var bounds: Array = data["alpha_bbox"]
	var expected := Rect2i(int(bounds[0]), int(bounds[1]), int(bounds[2]), int(bounds[3]))
	if visible == 0 or visible == pixels.get_width() * pixels.get_height() or actual_bounds != expected \
			or hit_mask.get_bit(0, 0) or hit_mask.get_bit(pixels.get_width() - 1, 0) \
			or hit_mask.get_bit(0, pixels.get_height() - 1) or hit_mask.get_bit(pixels.get_width() - 1, pixels.get_height() - 1):
		push_warning("Sawmill transparency does not match its measured bounds; using the existing building renderer.")
		return {}
	pixels.generate_mipmaps()
	return {"manifest": data, "texture": ImageTexture.create_from_image(pixels), "hit_mask": hit_mask}


static func _vector(data: Array) -> Vector2:
	return Vector2(float(data[0]), float(data[1]))


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _finite_numbers(value: Variant, count: int) -> bool:
	if not value is Array or (value as Array).size() != count:
		return false
	for component: Variant in value:
		if not _finite_number(component):
			return false
	return true


static func _valid_sha256(value: Variant) -> bool:
	if not value is String or String(value).length() != 64:
		return false
	for index: int in range(64):
		if not String(value)[index] in "0123456789abcdef":
			return false
	return true
