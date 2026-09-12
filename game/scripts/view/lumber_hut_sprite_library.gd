class_name LumberHutSpriteLibrary
extends RefCounted

# The house and both ordered construction masks share one measured canvas and
# door threshold. Original KaM artwork is never loaded by this library.
const MANIFEST_PATH: String = "res://art/buildings/lumber_hut/v1/manifest.json"
const WOOD_STEPS: int = 12
const FINISHING_STEPS: int = 21
const TOTAL_STEPS: int = WOOD_STEPS + FINISHING_STEPS
const WOOD_PHASE_FRACTION: float = 0.6
const ALPHA_THRESHOLD: float = 0.10

static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}
static var _hit_masks: Dictionary = {}
static var _source_size := Vector2i.ZERO
static var _loaded: bool = false


func _init() -> void:
	_ensure_loaded()


func supports(building: Dictionary) -> bool:
	return _loaded and String(building.get("type", "")) == "lumber_hut" \
		and int(building.get("footprint_version", 0)) in [1, 2]


# Sorting feet are distinct from the physical threshold and from projected
# screen height. One authored foot serves all stages; a growing alpha bound
# must never reorder the same house between its neighbours.
func visual_ground_position(building: Dictionary, door_cell: Vector2i, cell_height: float) -> Vector2:
	var anchor := Vector2(building["position"] as Vector2i)
	if not supports(building) or int(building.get("foundation_work_remaining", 0)) > 0:
		return anchor
	var threshold: Array = _manifest["door_threshold"]
	var sort_foot: Array = _manifest["sort_foot"]
	var offset_y: float = (float(sort_foot[1]) - float(threshold[1])) * float(_manifest["source_to_world"])
	return Vector2(anchor.x, float(door_cell.y) + 0.5 + offset_y / cell_height)


# Work is supplied by the existing simulation; wall time, sub-tick motion,
# stock reservations and workers' animation never advance the house artwork.
# Integer ceil divisions keep the 60% phase boundary exact on saved ticks.
static func state_for(building: Dictionary, definition: Dictionary) -> Dictionary:
	if int(building.get("foundation_work_remaining", 0)) > 0:
		return {"phase": "foundation", "step": 0, "wood_step": 0, "finishing_step": 0, "progress": 0.0}
	var total: int = maxi(1, int(definition.get("construction_ticks", 120)))
	var remaining: int = clampi(int(building.get("construction_remaining", 0)), 0, total)
	var worked: int = total - remaining
	var progress: float = float(worked) / float(total)
	if remaining == 0:
		return {"phase": "complete", "step": TOTAL_STEPS, "wood_step": WOOD_STEPS,
			"finishing_step": FINISHING_STEPS, "progress": 1.0}
	var wood_step: int = 0
	var finishing_step: int = 0
	if worked * 5 <= total * 3:
		wood_step = _ceil_div(worked * 5 * WOOD_STEPS, total * 3)
	else:
		wood_step = WOOD_STEPS
		finishing_step = _ceil_div((worked * 5 - total * 3) * FINISHING_STEPS, total * 2)
	return {"phase": "wood" if finishing_step == 0 else "finishing",
		"step": wood_step + finishing_step, "wood_step": wood_step,
		"finishing_step": finishing_step, "progress": progress}


static func _ceil_div(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return (numerator + denominator - 1) / denominator


func presentation_for(building: Dictionary, definition: Dictionary, door: Vector2) -> Dictionary:
	if not supports(building) or int(building.get("foundation_work_remaining", 0)) > 0:
		return {}
	var state: Dictionary = state_for(building, definition)
	var source_to_world: float = float(_manifest["source_to_world"])
	var threshold_data: Array = _manifest["door_threshold"]
	var threshold := Vector2(float(threshold_data[0]), float(threshold_data[1]))
	var sort_data: Array = _manifest["sort_foot"]
	var sort_foot := Vector2(float(sort_data[0]), float(sort_data[1]))
	var label_data: Array = _manifest.get("label_anchor", [float(_source_size.x) * 0.5, 0.0]) as Array
	var label_anchor := Vector2(float(label_data[0]), float(label_data[1]))
	var step: int = int(state["step"])
	return {"texture": _textures.get(step) as Texture2D,
		"rect": Rect2(door - threshold * source_to_world, Vector2(_source_size) * source_to_world),
		"step": step, "phase": state["phase"], "wood_step": state["wood_step"],
		"finishing_step": state["finishing_step"], "progress": state["progress"],
		"source_to_world": source_to_world, "door_threshold": threshold, "sort_foot": sort_foot,
		"label_anchor": label_anchor,
		"hit_mask": _hit_masks.get(step) as BitMap}


static func contains_point(presentation: Dictionary, point: Vector2) -> bool:
	if presentation.is_empty():
		return false
	var rect: Rect2 = presentation["rect"]
	if not rect.has_point(point):
		return false
	var mask: BitMap = presentation.get("hit_mask") as BitMap
	if mask == null:
		return false
	var pixel := Vector2i((point - rect.position) / float(presentation["source_to_world"]))
	return mask.get_bitv(pixel)


static func _ensure_loaded() -> void:
	if _loaded or not FileAccess.file_exists(MANIFEST_PATH):
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not value is Dictionary:
		push_warning("Lumber hut manifest is invalid; using the existing building renderer.")
		return
	var manifest: Dictionary = value as Dictionary
	var threshold: Variant = manifest.get("door_threshold")
	var sort_foot: Variant = manifest.get("sort_foot")
	if not threshold is Array or (threshold as Array).size() != 2 \
			or not sort_foot is Array or (sort_foot as Array).size() != 2 \
			or float(manifest.get("source_to_world", 0.0)) <= 0.0 \
			or not is_equal_approx(float(manifest.get("wood_phase_fraction", 0.0)), WOOD_PHASE_FRACTION):
		push_warning("Lumber hut registration or phase timing is invalid; using the existing building renderer.")
		return
	var images: Dictionary = {}
	for key: String in ["wood_image", "finished_image", "wood_mask", "finished_mask"]:
		var path: String = MANIFEST_PATH.get_base_dir().path_join(String(manifest.get(key, "")))
		if not ResourceLoader.exists(path):
			push_warning("Missing lumber hut asset: " + path)
			return
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			return
		var source: Image = texture.get_image()
		if source == null or source.is_empty():
			return
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		images[key] = source
	var wood: Image = images["wood_image"]
	var finished: Image = images["finished_image"]
	var size: Vector2i = wood.get_size()
	for source: Image in images.values():
		if source.get_size() != size:
			push_warning("Lumber hut construction layers do not share a canvas; using the existing building renderer.")
			return
	var wood_mask: Image = images["wood_mask"]
	var finish_mask: Image = images["finished_mask"]
	var wood_groups: Array[PackedVector2Array] = []
	var finish_groups: Array[PackedVector2Array] = []
	for index: int in range(WOOD_STEPS + 1):
		wood_groups.append(PackedVector2Array())
	for index: int in range(FINISHING_STEPS + 1):
		finish_groups.append(PackedVector2Array())
	# Only one scan groups pixel coordinates. Each source pixel is copied once;
	# stages then use native image copies and mipmap generation, avoiding 33
	# full-canvas GDScript pixel loops or work inside the per-frame draw callback.
	for y: int in range(size.y):
		for x: int in range(size.x):
			var wood_index: int = wood_mask.get_pixel(x, y).r8
			var finish_index: int = finish_mask.get_pixel(x, y).r8
			if wood_index > WOOD_STEPS or finish_index > FINISHING_STEPS:
				push_warning("Lumber hut mask contains a stage outside the authored 12/21 sequence.")
				return
			if wood_index > 0:
				wood_groups[wood_index].append(Vector2(x, y))
			if finish_index > 0:
				finish_groups[finish_index].append(Vector2(x, y))
	for index: int in range(1, WOOD_STEPS + 1):
		if wood_groups[index].is_empty():
			push_warning("Lumber hut wood mask is missing stage %d." % index)
			return
	for index: int in range(1, FINISHING_STEPS + 1):
		if finish_groups[index].is_empty():
			push_warning("Lumber hut finishing mask is missing stage %d." % index)
			return
	var frame: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	frame.fill(Color.TRANSPARENT)
	_cache_frame(0, frame)
	for index: int in range(1, WOOD_STEPS + 1):
		for pixel: Vector2 in wood_groups[index]:
			frame.set_pixelv(Vector2i(pixel), wood.get_pixelv(Vector2i(pixel)))
		_cache_frame(index, frame)
	for index: int in range(1, FINISHING_STEPS + 1):
		for pixel: Vector2 in finish_groups[index]:
			# Deliberate overwrite includes transparent final pixels. Authored
			# mask zones can remove temporary construction supports and voids.
			frame.set_pixelv(Vector2i(pixel), finished.get_pixelv(Vector2i(pixel)))
		_cache_frame(WOOD_STEPS + index, finished if index == FINISHING_STEPS else frame)
	_manifest = manifest
	_source_size = size
	_loaded = true


static func _cache_frame(step: int, source: Image) -> void:
	var hit_mask := BitMap.new()
	hit_mask.create_from_image_alpha(source, ALPHA_THRESHOLD)
	_hit_masks[step] = hit_mask
	var mipmapped: Image = source.duplicate() as Image
	mipmapped.generate_mipmaps()
	_textures[step] = ImageTexture.create_from_image(mipmapped)
