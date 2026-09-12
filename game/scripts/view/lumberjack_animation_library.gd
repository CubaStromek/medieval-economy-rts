class_name LumberjackAnimationLibrary
extends RefCounted

## Reads the packer's schema 1 without changing source frames or registration.
## The caller supplies presentation time; keeping that time fixed pauses a clip.
## This library does not choose simulation actions, move workers or draw cargo.
const MANIFEST_PATH := "res://art/units/lumberjack-pixellab-v2/manifest.json"
const DIRECTIONS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const CLIPS: Array[String] = ["walk_axe", "chop", "walk_log"]
const BODY_HEIGHT_WORLD_PX := 33.0
const HIT_ALPHA_THRESHOLD := 0.10

static var _shared_default: LumberjackAnimationLibrary

var errors: Array[String] = []
var warnings: Array[String] = []
var manifest: Dictionary = {}
var manifest_path: String = ""
var source_canvas_px := Vector2i.ZERO
var anchor_source_px := Vector2.ZERO
var body_height_source_px: float = 0.0
var world_px_per_source_px: float = 0.0
var _textures: Dictionary = {}
var _hit_masks: Dictionary = {}
var _shared_read_only: bool = false


## Default game views share one load and immutable frame/mask data. Callers
## needing a custom manifest create their own instance with new().
static func shared() -> LumberjackAnimationLibrary:
	if _shared_default == null:
		_shared_default = LumberjackAnimationLibrary.new()
		_shared_default.load_manifest()
		_shared_default._shared_read_only = true
	return _shared_default


func load_manifest(path: String = MANIFEST_PATH) -> bool:
	if _shared_read_only:
		push_warning("Sdílená knihovna dřevorubce je pouze pro čtení; vlastní manifest načtěte do nové instance.")
		return false
	errors.clear()
	warnings.clear()
	manifest.clear()
	_textures.clear()
	_hit_masks.clear()
	manifest_path = path
	source_canvas_px = Vector2i.ZERO
	anchor_source_px = Vector2.ZERO
	body_height_source_px = 0.0
	world_px_per_source_px = 0.0
	if not FileAccess.file_exists(path):
		return _fail("Chybí manifest animací: " + path)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return _fail("Neplatný JSON manifest: " + path)
	manifest = parser.data as Dictionary
	if manifest.get("schema_version") != 1:
		return _fail("Reader podporuje pouze schema_version 1.")
	var canvas: Variant = manifest.get("source_canvas_px")
	var anchor: Variant = manifest.get("anchor_source_px")
	if not _number_array(canvas, 2) or not _number_array(anchor, 2):
		return _fail("Manifest musí obsahovat source_canvas_px a anchor_source_px.")
	source_canvas_px = Vector2i(int(canvas[0]), int(canvas[1]))
	anchor_source_px = Vector2(float(anchor[0]), float(anchor[1]))
	if source_canvas_px.x <= 0 or source_canvas_px.y <= 0 or Vector2(source_canvas_px) != Vector2(float(canvas[0]), float(canvas[1])):
		return _fail("Rozměry zdrojového plátna musí být kladná celá čísla.")
	if anchor_source_px.x < 0 or anchor_source_px.y < 0 or anchor_source_px.x > source_canvas_px.x or anchor_source_px.y > source_canvas_px.y:
		return _fail("Společná kotva leží mimo zdrojové plátno.")
	if not _positive_number(manifest.get("body_height_source_px")):
		return _fail("Chybí kladná výška těla body_height_source_px.")
	body_height_source_px = float(manifest["body_height_source_px"])
	if not _positive_number(manifest.get("body_height_world_px")) or not is_equal_approx(float(manifest["body_height_world_px"]), BODY_HEIGHT_WORLD_PX):
		return _fail("Tato knihovna vyžaduje projektovou výšku těla 33 world px.")
	world_px_per_source_px = BODY_HEIGHT_WORLD_PX / body_height_source_px
	if not _positive_number(manifest.get("world_px_per_source_px")) or not is_equal_approx(float(manifest["world_px_per_source_px"]), world_px_per_source_px):
		return _fail("Měřítko manifestu neodpovídá uvedené výšce těla.")
	var registration: Variant = manifest.get("registration")
	if not registration is Dictionary or registration.get("trim") != "none" or registration.get("frame_offsets") != "none":
		return _fail("Reader vyžaduje celé plátno bez trimu a bez posunů jednotlivých snímků.")
	var declared_clips: Variant = manifest.get("clips")
	if not declared_clips is Dictionary or declared_clips.is_empty():
		return _fail("Manifest neobsahuje žádný klip.")
	for clip_id: String in CLIPS:
		if declared_clips.has(clip_id):
			_load_clip(clip_id, declared_clips[clip_id])
		else:
			warnings.append("Není dodán klip " + clip_id + ".")
	if not errors.is_empty():
		_textures.clear()
		_hit_masks.clear()
		return false
	if _textures.is_empty():
		return _fail("Manifest neobsahuje žádnou podporovanou animaci.")
	if not is_complete():
		warnings.append("Dílčí sada: nejsou dostupné všechny tři klipy ve všech osmi směrech.")
	return true


func is_ready() -> bool:
	return errors.is_empty() and not _textures.is_empty()


func is_complete() -> bool:
	for clip_id: String in CLIPS:
		for direction: String in DIRECTIONS:
			if frame_count(clip_id, direction) == 0:
				return false
	return true


func clip_ids() -> Array[String]:
	var result: Array[String] = []
	for clip_id: String in CLIPS:
		if _textures.has(clip_id):
			result.append(clip_id)
	return result


func clip_metadata(clip_id: String) -> Dictionary:
	return (manifest.get("clips", {}) as Dictionary).get(clip_id, {}) as Dictionary


func frame_count(clip_id: String, direction: String) -> int:
	return ((_textures.get(clip_id, {}) as Dictionary).get(direction, []) as Array).size()


func fps(clip_id: String, direction: String = "") -> float:
	var clip: Dictionary = clip_metadata(clip_id)
	var record: Dictionary = (clip.get("directions", {}) as Dictionary).get(direction, {}) as Dictionary
	return float(record.get("fps", clip.get("fps", 0.0)))


func rest_frame(clip_id: String) -> int:
	return int(clip_metadata(clip_id).get("rest_frame", 0))


func frame_index(clip_id: String, direction: String, elapsed_seconds: float, at_rest: bool = false) -> int:
	var count: int = frame_count(clip_id, direction)
	if count == 0 or not is_finite(elapsed_seconds):
		return -1
	if at_rest:
		return rest_frame(clip_id)
	return posmod(floori(elapsed_seconds * fps(clip_id, direction)), count)


func texture_for(clip_id: String, direction: String, index: int) -> Texture2D:
	if index < 0 or index >= frame_count(clip_id, direction):
		return null
	return (_textures[clip_id][direction] as Array)[index] as Texture2D


func sprite_rect(feet: Vector2) -> Rect2:
	return Rect2(feet - anchor_source_px * world_px_per_source_px, Vector2(source_canvas_px) * world_px_per_source_px)


func presentation_for(clip_id: String, direction: String, feet: Vector2, elapsed_seconds: float, at_rest: bool = false) -> Dictionary:
	return presentation_frame(clip_id, direction, feet, frame_index(clip_id, direction, elapsed_seconds, at_rest))


func presentation_frame(clip_id: String, direction: String, feet: Vector2, index: int) -> Dictionary:
	var texture: Texture2D = texture_for(clip_id, direction, index)
	if texture == null:
		return {"error": "Chybí snímek %s/%s/%d." % [clip_id, direction, index]}
	var metadata: Dictionary = clip_metadata(clip_id)
	return {
		"texture": texture, "rect": sprite_rect(feet), "flip_h": false,
		"clip": clip_id, "direction": direction,
		"frame_index": index, "frame_count": frame_count(clip_id, direction),
		"fps": fps(clip_id, direction),
		"renders_cargo": metadata.get("renders_cargo"), "tool_grip": metadata.get("tool_grip"),
	}


## Tests the current source frame, not its transparent full-canvas padding.
## Masks are prepared at load time; this path performs no image readback.
func contains_point(presentation: Dictionary, point: Vector2) -> bool:
	var rect_value: Variant = presentation.get("rect")
	var index_value: Variant = presentation.get("frame_index")
	if not rect_value is Rect2 or not _number(index_value) or float(index_value) != int(index_value):
		return false
	var rect: Rect2 = rect_value as Rect2
	if not is_finite(point.x) or not is_finite(point.y) or rect.size.x <= 0 or rect.size.y <= 0 or not rect.has_point(point):
		return false
	var clip_id: String = String(presentation.get("clip", ""))
	var direction: String = String(presentation.get("direction", ""))
	var masks: Array = (_hit_masks.get(clip_id, {}) as Dictionary).get(direction, []) as Array
	var index: int = int(index_value)
	if index < 0 or index >= masks.size():
		return false
	var uv: Vector2 = (point - rect.position) / rect.size
	var pixel := Vector2i(clampi(floori(uv.x * source_canvas_px.x), 0, source_canvas_px.x - 1),
		clampi(floori(uv.y * source_canvas_px.y), 0, source_canvas_px.y - 1))
	return (masks[index] as BitMap).get_bitv(pixel)


func _load_clip(clip_id: String, value: Variant) -> void:
	if not value is Dictionary:
		_fail("Neplatný záznam klipu " + clip_id)
		return
	var clip: Dictionary = value as Dictionary
	if not _positive_number(clip.get("fps")) or clip.get("playback") != "loop":
		_fail(clip_id + ": vyžaduje kladné fps a playback=loop.")
		return
	var rest: Variant = clip.get("rest_frame", 0)
	if not _number(rest) or float(rest) != int(rest) or int(rest) < 0:
		_fail(clip_id + ": neplatný rest_frame.")
		return
	var relative: String = String(clip.get("atlas", ""))
	if relative.is_empty() or relative.is_absolute_path() or ":" in relative or ".." in relative.split("/"):
		_fail(clip_id + ": atlas musí být relativní cesta uvnitř balíku.")
		return
	var atlas_path: String = manifest_path.get_base_dir().path_join(relative)
	if not ResourceLoader.exists(atlas_path, "Texture2D"):
		_fail("Chybí importovaná textura " + atlas_path + "; otevřete projekt v Godotu nebo spusťte --editor --import.")
		return
	# Exported PCKs may contain only the imported texture, not its source PNG.
	# Local import/QA verifies the PNG hash; exported builds still validate pixels.
	if FileAccess.file_exists(atlas_path):
		if String(clip.get("atlas_sha256", "")) != FileAccess.get_sha256(atlas_path):
			_fail(clip_id + ": hash atlasu nesouhlasí s manifestem.")
			return
	else:
		warnings.append(clip_id + ": v exportu není zdrojové PNG; jeho hash nelze znovu ověřit.")
	var atlas: Texture2D = load(atlas_path) as Texture2D
	var size_value: Variant = clip.get("atlas_size_px")
	if atlas == null or not _number_array(size_value, 2) or atlas.get_size() != Vector2(float(size_value[0]), float(size_value[1])):
		_fail(clip_id + ": rozměry atlasu nesouhlasí s manifestem.")
		return
	var source: Image = atlas.get_image()
	if source == null or source.is_empty():
		_fail(clip_id + ": nelze přečíst pixely atlasu.")
		return
	if source.is_compressed() and source.decompress() != OK:
		_fail(clip_id + ": nelze rozbalit pixely atlasu.")
		return
	var directions: Variant = clip.get("directions")
	if not directions is Dictionary or directions.is_empty():
		_fail(clip_id + ": chybí směry.")
		return
	_textures[clip_id] = {}
	_hit_masks[clip_id] = {}
	for direction: String in DIRECTIONS:
		if not directions.has(direction):
			continue
		var record: Variant = directions[direction]
		if not record is Dictionary or not record.get("frames") is Array:
			_fail(clip_id + "/" + direction + ": chybí pole snímků.")
			continue
		if record.has("fps") and not _positive_number(record["fps"]):
			_fail(clip_id + "/" + direction + ": fps směru musí být kladné konečné číslo.")
			continue
		var frames: Array = record["frames"] as Array
		if frames.is_empty() or record.get("frame_count") != frames.size() or int(rest) >= frames.size():
			_fail(clip_id + "/" + direction + ": nesouhlasí počet snímků nebo klidový snímek.")
			continue
		var textures: Array[Texture2D] = []
		var masks: Array[BitMap] = []
		for index: int in range(frames.size()):
			var frame: Variant = frames[index]
			if not frame is Dictionary or frame.get("index") != index or not _number_array(frame.get("atlas_rect_px"), 4):
				_fail(clip_id + "/" + direction + ": neplatná definice snímku " + str(index))
				break
			var coordinates: Array = frame["atlas_rect_px"] as Array
			var rect := Rect2i(int(coordinates[0]), int(coordinates[1]), int(coordinates[2]), int(coordinates[3]))
			if Rect2(rect) != Rect2(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]), float(coordinates[3])) or rect.size != source_canvas_px or not Rect2i(Vector2i.ZERO, source.get_size()).encloses(rect):
				_fail(clip_id + "/" + direction + ": snímek není celé plátno uvnitř atlasu.")
				break
			var cell: Image = source.get_region(rect)
			if cell.get_used_rect().size == Vector2i.ZERO or cell.detect_alpha() == Image.ALPHA_NONE:
				_fail(clip_id + "/" + direction + ": snímek %d nemá současně obsah a skutečnou průhlednost." % index)
				break
			var mask := BitMap.new()
			mask.create_from_image_alpha(cell, HIT_ALPHA_THRESHOLD)
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(rect)
			texture.filter_clip = true
			textures.append(texture)
			masks.append(mask)
		_textures[clip_id][direction] = textures
		_hit_masks[clip_id][direction] = masks


func _fail(message: String) -> bool:
	errors.append(message)
	return false


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _positive_number(value: Variant) -> bool:
	return _number(value) and float(value) > 0.0


static func _number_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for item: Variant in value:
		if not _number(item):
			return false
	return true
