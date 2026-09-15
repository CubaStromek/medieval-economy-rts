class_name LumberHutLife
extends RefCounted

## Read-only household presentation. All coordinates belong to finished.png;
## the house keeps its physical threshold, painter row, fog and terrain height.
const TICK_SECONDS := 0.1
const REST_MANIFEST := "res://art/buildings/lumber_hut/v1/life/resting_lumberjack.json"
const LOOK_MANIFEST := "res://art/buildings/lumber_hut/v1/life/look/look.json"
const LOOK_TURN_SECONDS := 0.45
const LOOK_TURN_STEPS := 8
const DOOR: Array[Vector2] = [Vector2(543, 322), Vector2(583, 310), Vector2(584, 394), Vector2(543, 406)]
const WINDOW: Array[Vector2] = [Vector2(471, 350), Vector2(502, 341), Vector2(502, 378), Vector2(471, 388)]
const REST_FOOT := Vector2(448, 478)

static var _soft_texture: GradientTexture2D
static var _rest_texture: Texture2D
static var _rest_mask: BitMap
static var _rest_anchor := Vector2.ZERO
static var _rest_scale: float = 0.0
static var _look_textures: Dictionary = {}
static var _look_masks: Dictionary = {}


func _init() -> void:
	_load_rest()


func presentation_for(world: Variant, building: Dictionary, house: Dictionary, tick_fraction: float = 0.0) -> Dictionary:
	if house.is_empty() or String(building.get("type", "")) != "lumber_hut" \
			or int(building.get("footprint_version", 0)) not in [1, 2] or not world.is_building_complete(building):
		return {}
	var result: Dictionary = {"rect": house["rect"], "source_to_world": house["source_to_world"],
		"known": false, "at_home": false, "door_open": false, "window_open": false,
		"rest_visible": false, "rest_worker_id": 0,
		"time_seconds": (float(world.tick % 60000) + clampf(tick_fraction, 0.0, 1.0)) * TICK_SECONDS}
	# A spotted foreign house is not permission to query its hidden resident.
	if world.fog.enabled and not world.is_local_entity(building):
		return result
	result["known"] = true
	var worker: Dictionary = world.workplace_worker(int(building["id"]))
	var at_home: bool = not worker.is_empty() and String(worker.get("type", "")) == "lumberjack" \
		and int(worker.get("inside_building_id", 0)) == int(building["id"])
	result["at_home"] = at_home
	result["door_open"] = at_home
	if not at_home:
		return result
	var resting: bool = String(worker.get("carrying", "")).is_empty() \
		and not String(worker.get("action", "")).begins_with("deliver_") \
		and (String(worker.get("state", "")) == "idle" or world.is_worker_work_paused(worker))
	result["rest_visible"] = resting
	result["window_open"] = resting
	result["rest_worker_id"] = int(worker["id"]) if resting else 0
	return result


func draw(canvas: CanvasItem, life: Dictionary, house: Dictionary) -> void:
	if life.is_empty() or not bool(life["known"]):
		return
	var origin: Vector2 = (life["rect"] as Rect2).position
	var scale: float = float(life["source_to_world"])
	var house_texture: Texture2D = house["texture"]
	# Reuse the house's own painted plank material for a registered door leaf.
	# This is a textured mesh, not a replacement image or regenerated building.
	if not bool(life["door_open"]):
		_draw_wood_quad(canvas, DOOR, origin, scale, house_texture, Color(0.88, 0.83, 0.74))
		for pair: Array in [[Vector2(545, 343), Vector2(582, 332)], [Vector2(545, 389), Vector2(582, 378)]]:
			canvas.draw_line(origin + pair[0] * scale, origin + pair[1] * scale, Color(0.20, 0.16, 0.11), 1.0, true)
		canvas.draw_circle(origin + Vector2(550, 367) * scale, 0.65, Color(0.16, 0.15, 0.12))
	# A small dark opening on the existing stone chimney cap.
	canvas.draw_colored_polygon(_points([Vector2(438, 61), Vector2(450, 57), Vector2(459, 63), Vector2(447, 67)], origin, scale), Color(0.19, 0.17, 0.15))
	if bool(life["window_open"]):
		_draw_window(canvas, origin, scale, house_texture)
	if bool(life["rest_visible"]) and _rest_texture != null:
		var foot: Vector2 = origin + REST_FOOT * scale
		canvas.draw_texture_rect(_soft(), Rect2(foot - Vector2(3, 0.8), Vector2(6, 1.8)), false, Color(0.12, 0.10, 0.06, 0.40))
		var rest_texture: Texture2D = _look_textures.get(_rest_look_key(life), _rest_texture)
		canvas.draw_texture_rect(rest_texture, rest_rect(life), false)


static func rest_rect(life: Dictionary) -> Rect2:
	if life.is_empty() or _rest_texture == null:
		return Rect2()
	var foot: Vector2 = (life["rect"] as Rect2).position + REST_FOOT * float(life["source_to_world"])
	return Rect2(foot - _rest_anchor * _rest_scale, _rest_texture.get_size() * _rest_scale)


static func contains_point(life: Dictionary, point: Vector2) -> bool:
	if life.is_empty() or not bool(life.get("rest_visible", false)) or _rest_mask == null:
		return false
	var rect: Rect2 = rest_rect(life)
	if not rect.has_point(point):
		return false
	var mask: BitMap = _look_masks.get(_rest_look_key(life), _rest_mask)
	return mask.get_bitv(Vector2i((point - rect.position) / _rest_scale))


static func rest_pose_for(life: Dictionary) -> String:
	var turn: Dictionary = _rest_turn_for(life)
	return String(turn["side"]) if float(turn["amount"]) >= 0.5 else "center"


static func _rest_turn_for(life: Dictionary) -> Dictionary:
	if not bool(life.get("rest_visible", false)):
		return {"side": "center", "amount": 0.0}
	# Long quiet holds and short, small head turns. A resident-specific phase
	# avoids synchronized glances across huts. Only saved simulation time moves
	# this presentation; neither a frame timer nor an extra worker action exists.
	var phase: float = fposmod(float(life.get("time_seconds", 0.0)) + float(life.get("rest_worker_id", 0)) * 0.73, 12.0)
	var side: String = "center"
	var amount: float = 0.0
	if phase >= 2.0 and phase < 4.0 + LOOK_TURN_SECONDS:
		side = "left"
		amount = minf((phase - 2.0) / LOOK_TURN_SECONDS, (4.0 + LOOK_TURN_SECONDS - phase) / LOOK_TURN_SECONDS)
	elif phase >= 7.0 and phase < 9.0 + LOOK_TURN_SECONDS:
		side = "right"
		amount = minf((phase - 7.0) / LOOK_TURN_SECONDS, (9.0 + LOOK_TURN_SECONDS - phase) / LOOK_TURN_SECONDS)
	amount = smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))
	return {"side": side, "amount": amount}


static func _rest_look_key(life: Dictionary) -> String:
	var turn: Dictionary = _rest_turn_for(life)
	return "%s:%d" % [turn["side"], roundi(float(turn["amount"]) * LOOK_TURN_STEPS)]


static func _load_rest() -> void:
	if _rest_texture != null or not FileAccess.file_exists(REST_MANIFEST):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(REST_MANIFEST))
	if not data is Dictionary:
		return
	var anchor: Array = data.get("production_ground_contact", [])
	var body_height: float = float(data.get("production_body_height_px", 0))
	if anchor.size() != 2 or not is_finite(body_height) or body_height <= 0.0:
		return
	var path: String = REST_MANIFEST.get_base_dir().path_join("resting_lumberjack.png")
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	var pixels: Image = texture.get_image()
	if pixels == null or pixels.get_size() != Vector2i(256, 256):
		return
	if pixels.is_compressed():
		pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	var mask := BitMap.new()
	mask.create_from_image_alpha(pixels, 0.10)
	if mask.get_true_bit_count() == 0 or mask.get_bitv(Vector2i.ZERO):
		return
	_rest_anchor = Vector2(float(anchor[0]), float(anchor[1]))
	_rest_scale = 33.0 / body_height
	_rest_mask = mask
	_load_looks(pixels)
	pixels.generate_mipmaps()
	_rest_texture = ImageTexture.create_from_image(pixels)


static func _load_looks(center: Image) -> void:
	if not FileAccess.file_exists(LOOK_MANIFEST):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOOK_MANIFEST))
	if not data is Dictionary or not data.get("frames") is Dictionary:
		return
	var poses: Dictionary = {}
	for side: String in ["left", "right"]:
		var path: String = LOOK_MANIFEST.get_base_dir().path_join(String(data["frames"].get(side, "")))
		if not ResourceLoader.exists(path):
			return
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			return
		var pixels: Image = texture.get_image()
		if pixels == null or pixels.get_size() != center.get_size():
			return
		if pixels.is_compressed():
			pixels.decompress()
		pixels.convert(Image.FORMAT_RGBA8)
		poses[side] = pixels
	for side: String in poses:
		var target: Image = poses[side]
		var changed := Rect2i()
		for y: int in range(center.get_height()):
			for x: int in range(center.get_width()):
				if center.get_pixel(x, y) != target.get_pixel(x, y):
					var pixel_rect := Rect2i(x, y, 1, 1)
					changed = pixel_rect if not changed.has_area() else changed.merge(pixel_rect)
		# Cache only eight brief transition steps. Premultiplied interpolation
		# avoids dark alpha rims; identical body pixels are copied, never redrawn
		# twice or moved. The authored yaw endpoints carry the actual head turn.
		for step: int in range(LOOK_TURN_STEPS + 1):
			var blended: Image = center.duplicate()
			var weight: float = float(step) / LOOK_TURN_STEPS
			for y: int in range(changed.position.y, changed.end.y):
				for x: int in range(changed.position.x, changed.end.x):
					var a: Color = center.get_pixel(x, y)
					var b: Color = target.get_pixel(x, y)
					var alpha: float = lerpf(a.a, b.a, weight)
					var premult: Color = (a * a.a).lerp(b * b.a, weight)
					blended.set_pixel(x, y, Color(premult.r / alpha, premult.g / alpha, premult.b / alpha, alpha) if alpha > 0.0 else Color.TRANSPARENT)
			var key: String = "%s:%d" % [side, step]
			var mask := BitMap.new()
			mask.create_from_image_alpha(blended, 0.10)
			_look_masks[key] = mask
			blended.generate_mipmaps()
			_look_textures[key] = ImageTexture.create_from_image(blended)


static func _points(source: Array[Vector2], origin: Vector2, scale: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in source:
		points.append(origin + point * scale)
	return points


static func _draw_wood_quad(canvas: CanvasItem, quad: Array[Vector2], origin: Vector2, scale: float,
		texture: Texture2D, tint: Color = Color.WHITE) -> void:
	var uv := PackedVector2Array()
	for point: Vector2 in WINDOW:
		uv.append(point / 640.0)
	canvas.draw_polygon(_points(quad, origin, scale), PackedColorArray([tint]), uv, texture)


static func _draw_window(canvas: CanvasItem, origin: Vector2, scale: float, texture: Texture2D) -> void:
	var colors := PackedColorArray([
		Color(0.09, 0.075, 0.055), Color(0.12, 0.10, 0.075),
		Color(0.19, 0.155, 0.105), Color(0.15, 0.12, 0.08)])
	canvas.draw_polygon(_points(WINDOW, origin, scale), colors)
	# Keep an inset timber cross and the original outer frame/plaster visible.
	canvas.draw_line(origin + Vector2(486, 346) * scale, origin + Vector2(486, 383) * scale, Color(0.23, 0.15, 0.08), 0.85, true)
	canvas.draw_line(origin + Vector2(471, 369) * scale, origin + Vector2(502, 360) * scale, Color(0.25, 0.16, 0.08), 0.8, true)
	# The open shutters frame the dark interior.
	_draw_wood_quad(canvas, [Vector2(462, 346), Vector2(470, 349), Vector2(470, 389), Vector2(462, 385)], origin, scale, texture)
	_draw_wood_quad(canvas, [Vector2(503, 341), Vector2(511, 333), Vector2(511, 371), Vector2(503, 379)], origin, scale, texture)


static func _soft() -> Texture2D:
	if _soft_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.52), Color(1, 1, 1, 0.13), Color(1, 1, 1, 0)])
		_soft_texture = GradientTexture2D.new()
		_soft_texture.width = 64
		_soft_texture.height = 64
		_soft_texture.gradient = gradient
		_soft_texture.fill = GradientTexture2D.FILL_RADIAL
		_soft_texture.fill_from = Vector2(0.5, 0.5)
		_soft_texture.fill_to = Vector2(1.0, 0.5)
	return _soft_texture
