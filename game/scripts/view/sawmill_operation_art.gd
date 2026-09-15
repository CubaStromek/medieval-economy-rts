class_name SawmillOperationArt
extends RefCounted

## Registered workshop layers. All gameplay facts arrive from SawmillOperation.
const HUMAN_HEIGHT := 33.0
const ALPHA_THRESHOLD := 0.10
const OperationClass = preload("res://scripts/view/sawmill_operation.gd")
const WorkerAppearance = preload("res://scripts/view/building_worker_appearance.gd")
static var _manifests: Dictionary = {}
static var _images: Dictionary = {}


func presentation_for(house: Dictionary, operation: Dictionary) -> Dictionary:
	if house.is_empty():
		return {}
	var setting: Dictionary = house.get("operation", {})
	var data: Dictionary = _manifest(String(setting.get("manifest", "")))
	if data.is_empty():
		return {}
	var result: Dictionary = {"rect": house["rect"], "scale": house["source_to_world"],
		"data": data, "operation": operation, "layers": [], "fallback_labels": [], "frame_index": -1}
	var work: Dictionary = data["work"]
	# A revision whose base already has an empty wall needs no backplate.
	# Any authored wall patch remains architectural, including a foreign silhouette.
	_add_layer(result, String(work.get("backplate", "")), Rect2(Vector2.ZERO, Vector2(800, 800)))
	if not bool(operation.get("known", false)):
		return result
	for kind: String in ["log", "plank"]:
		var stock: Dictionary = (data["stock"] as Dictionary)[kind]
		var amount: int = int(operation.get("input_amount" if kind == "log" else "output_amount", 0))
		var capacity: int = int(operation.get("input_capacity" if kind == "log" else "output_capacity", 0))
		var slots: Array = stock["slots"]
		if capacity != int(stock["capacity"]) or amount < 0 or amount > slots.size():
			# Keep an honest count if a later catalog no longer fits authored slots.
			(result["fallback_labels"] as Array).append({"text": "%s %d/%d" % ["Klády" if kind == "log" else "Prkna", amount, capacity],
				"position": _vector(stock["label"])})
			continue
		for index: int in range(amount):
			_add_layer(result, String(stock["texture"]), _rect(slots[index]))
		for front: Dictionary in stock.get("foreground", []):
			_add_layer(result, String(front["texture"]), _rect(front["rect"]))
	if bool(operation.get("in_process", false)):
		var log_data: Dictionary = work.get("log", {})
		if not log_data.is_empty():
			_add_layer(result, String(log_data["texture"]), _rect(log_data["rect"]))
	if bool(operation.get("active_work", false)):
		var frames: Array = work["frames"]
		var index: int = OperationClass.pose_index_for(operation, frames.size(), int(work["cycles_per_batch"]))
		if index < 0:
			return result
		var asset: Dictionary = _asset(String(frames[index]))
		if not asset.is_empty():
			# The bent work pose has its own measured projected height. Standing
			# citizens still use HUMAN_HEIGHT; neither value includes the tool.
			var body_scale: float = float(work.get("body_height_world", HUMAN_HEIGHT)) / float(work["body_height_px"]) / float(result["scale"])
			var origin: Vector2 = _vector(work["foot"]) - _vector(work["ground_contact"]) * body_scale
			var size: Vector2 = (asset["texture"] as Texture2D).get_size() * body_scale
			_add_layer(result, String(frames[index]), Rect2(origin, size), work.get("appearance", {}))
			result["frame_index"] = index
	for front: Dictionary in work.get("foreground", []):
		_add_layer(result, String(front["texture"]), _rect(front["rect"]))
	return result


func draw(canvas: CanvasItem, art: Dictionary, _house: Dictionary) -> void:
	if art.is_empty():
		return
	var origin: Vector2 = (art["rect"] as Rect2).position
	var scale: float = float(art["scale"])
	for layer: Dictionary in art["layers"]:
		var source_rect: Rect2 = layer["rect"]
		var rect := Rect2(origin + source_rect.position * scale, source_rect.size * scale)
		var appearance: Dictionary = layer.get("appearance", {})
		# Local foot occlusion belongs on the workshop floor, above the house
		# bitmap and below the body/front posts. It is not a selectable layer.
		WorkerAppearance.draw_contact(canvas, rect, (layer["texture"] as Texture2D).get_size(), appearance)
		WorkerAppearance.draw_body(canvas, layer["texture"], rect, appearance)
	for label: Dictionary in art["fallback_labels"]:
		canvas.draw_string(ThemeDB.fallback_font, origin + (label["position"] as Vector2) * scale,
			String(label["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.86, 0.65))


func contains_point(art: Dictionary, point: Vector2) -> bool:
	if art.is_empty():
		return false
	var local: Vector2 = (point - (art["rect"] as Rect2).position) / float(art["scale"])
	for layer: Dictionary in art["layers"]:
		var rect: Rect2 = layer["rect"]
		if not rect.has_point(local):
			continue
		var mask: BitMap = layer["mask"]
		var pixel: Vector2i = Vector2i((local - rect.position) / rect.size * Vector2(mask.get_size()))
		if mask.get_bitv(pixel):
			return true
	return false


static func clear_cache() -> void:
	_manifests.clear()
	_images.clear()


static func _add_layer(art: Dictionary, file: String, rect: Rect2, appearance: Dictionary = {}) -> void:
	var image: Dictionary = _asset(file)
	if image.is_empty() or not rect.has_area():
		return
	(art["layers"] as Array).append({"texture": image["texture"], "mask": image["mask"], "rect": rect, "path": file,
		"appearance": appearance})


static func _manifest(file: String) -> Dictionary:
	if file.is_empty():
		return {}
	if _manifests.has(file):
		return _manifests[file]
	_manifests[file] = {}
	if not FileAccess.file_exists(file):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if int(data.get("schema_version", 0)) != 1 or String(data.get("building_id", "")) != "sawmill" \
		or not _numbers(data.get("canvas"), 2) or not data.get("stock") is Dictionary or not data.get("work") is Dictionary:
		return {}
	if _vector(data["canvas"]) != Vector2(800, 800):
		return {}
	for kind: String in ["log", "plank"]:
		if not (data["stock"] as Dictionary).get(kind) is Dictionary:
			return {}
		var stock: Dictionary = (data["stock"] as Dictionary).get(kind, {})
		if not stock.get("slots") is Array or not _numbers(stock.get("label"), 2) \
			or int(stock.get("capacity", 0)) <= 0 or stock["slots"].size() != int(stock["capacity"]):
			return {}
		if _asset(String(stock.get("texture", ""))).is_empty():
			return {}
		for slot: Variant in stock["slots"]:
			if not _valid_rect(slot):
				return {}
		if not _valid_fronts(stock.get("foreground", [])):
			return {}
	var work: Dictionary = data["work"]
	if not work.get("frames") is Array or work["frames"].is_empty() \
		or not _numbers(work.get("ground_contact"), 2) or not _numbers(work.get("foot"), 2) \
		or not _positive(work.get("body_height_px")) or not _positive(work.get("cycles_per_batch")):
		return {}
	if not _positive(work.get("body_height_world", HUMAN_HEIGHT)) or not WorkerAppearance.valid(work.get("appearance", {})):
		return {}
	var frame_size := Vector2.ZERO
	for frame: Variant in work["frames"]:
		var image: Dictionary = _asset(String(frame))
		if image.is_empty():
			return {}
		var size: Vector2 = (image["texture"] as Texture2D).get_size()
		if frame_size != Vector2.ZERO and frame_size != size:
			return {}
		frame_size = size
	var anchor: Vector2 = _vector(work["ground_contact"])
	if anchor.x < 0.0 or anchor.y < 0.0 or anchor.x > frame_size.x or anchor.y > frame_size.y \
		or float(work["body_height_px"]) > frame_size.y or not _valid_fronts(work.get("foreground", [])):
		return {}
	var backplate_path: Variant = work.get("backplate", "")
	if not backplate_path is String:
		return {}
	if not String(backplate_path).is_empty():
		var backplate: Dictionary = _asset(backplate_path)
		if backplate.is_empty() or (backplate["texture"] as Texture2D).get_size() != Vector2(800, 800):
			return {}
	if not work.get("log") is Dictionary:
		return {}
	var log_data: Dictionary = work.get("log", {})
	if not _valid_rect(log_data.get("rect")) or _asset(String(log_data.get("texture", ""))).is_empty():
		return {}
	_manifests[file] = data
	return data


static func _valid_fronts(fronts: Variant) -> bool:
	if not fronts is Array:
		return false
	for front: Variant in fronts:
		if not front is Dictionary or not _valid_rect(front.get("rect")) \
			or _asset(String(front.get("texture", ""))).is_empty():
			return false
	return true


static func _asset(file: String) -> Dictionary:
	if file.is_empty():
		return {}
	if _images.has(file):
		return _images[file]
	_images[file] = {}
	if not ResourceLoader.exists(file):
		return {}
	var source: Texture2D = load(file) as Texture2D
	if source == null:
		return {}
	var pixels: Image = source.get_image()
	if pixels == null or pixels.is_empty():
		return {}
	if pixels.is_compressed() and pixels.decompress() != OK:
		return {}
	pixels.convert(Image.FORMAT_RGBA8)
	var mask := BitMap.new()
	mask.create_from_image_alpha(pixels, ALPHA_THRESHOLD)
	if mask.get_true_bit_count() == 0 or mask.get_true_bit_count() == pixels.get_width() * pixels.get_height():
		return {}
	pixels.generate_mipmaps()
	var result: Dictionary = {"texture": ImageTexture.create_from_image(pixels), "mask": mask}
	_images[file] = result
	return result


static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for item: Variant in value:
		if not (item is float or item is int) or not is_finite(float(item)):
			return false
	return true


static func _positive(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0


static func _valid_rect(value: Variant) -> bool:
	return _numbers(value, 4) and float(value[2]) > 0.0 and float(value[3]) > 0.0


static func _vector(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
