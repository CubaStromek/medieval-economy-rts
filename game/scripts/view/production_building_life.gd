class_name ProductionBuildingLife
extends RefCounted

## Read-only household layers for individually authored production buildings.
## Geometry comes from house.life; the existing lumber-hut renderer is unchanged.
const HUMAN_HEIGHT := 33.0
const TICK_SECONDS := 0.1
const LOOK_TURN_SECONDS := 0.45
const LOOK_TURN_STEPS := 8
const ALPHA_THRESHOLD := 0.10
const WorkerAppearance = preload("res://scripts/view/building_worker_appearance.gd")
const WorkerIdle = preload("res://scripts/view/building_worker_idle.gd")

var _rest_assets: Dictionary = {}
static var _soft_texture: GradientTexture2D


func presentation_for(world: Variant, building: Dictionary, house: Dictionary, tick_fraction: float = 0.0) -> Dictionary:
	var config: Dictionary = house.get("life", {})
	if house.is_empty() or config.is_empty() or not world.is_building_complete(building):
		return {}
	var result: Dictionary = {"rect": house["rect"], "source_to_world": house["source_to_world"], "config": config,
		"known": false, "at_home": false, "active_work": false, "door_open": false, "window_open": false,
		"rest_visible": false, "rest_worker_id": 0,
		"time_seconds": (float(world.tick % 60000) + clampf(tick_fraction, 0.0, 1.0)) * TICK_SECONDS}
	# Return before even the reverse workplace lookup: an explored/spotted
	# foreign silhouette does not reveal a hidden resident or production state.
	if world.fog.enabled and not world.is_local_entity(building):
		return result
	result["known"] = true
	var worker: Dictionary = world.workplace_worker(int(building["id"]))
	var role: String = String(world.catalog.building(String(building["type"])).get("worker", ""))
	var at_home: bool = not worker.is_empty() and not role.is_empty() and String(worker.get("type", "")) == role \
		and int(worker.get("inside_building_id", 0)) == int(building["id"])
	result["at_home"] = at_home
	result["door_open"] = at_home
	if not at_home:
		return result
	var action: String = String(worker.get("action", ""))
	var state: String = String(worker.get("state", ""))
	var paused: bool = world.is_worker_work_paused(worker)
	var active_work: bool = state == "working" and action == "operate" \
		and int(worker.get("source_id", 0)) == int(building["id"]) \
		and world.can_worker_work(worker) and world.is_building_enabled(building) \
		and int(building.get("process_remaining", 0)) > 0
	result["active_work"] = active_work
	var resting: bool = not active_work and String(worker.get("carrying", "")).is_empty() \
		and int(worker.get("meal_ticks_left", 0)) == 0 \
		and not action.begins_with("deliver_") \
		and action not in ["eat", "pause_return", "leave_building", "yield"] \
		and (state == "idle" or (paused and state != "moving"))
	result["rest_visible"] = resting
	result["window_open"] = resting
	result["rest_worker_id"] = int(worker["id"]) if resting else 0
	return result


func draw(canvas: CanvasItem, life: Dictionary, house: Dictionary) -> void:
	if life.is_empty() or not bool(life.get("known", false)):
		return
	var config: Dictionary = life["config"]
	var origin: Vector2 = (life["rect"] as Rect2).position
	var scale: float = float(life["source_to_world"])
	var texture: Texture2D = house["texture"]
	var door: PackedVector2Array = _points(config.get("door", []), origin, scale)
	if bool(life["door_open"]) and door.size() >= 3:
		canvas.draw_colored_polygon(door, Color(0.105, 0.081, 0.053))
	elif bool(config.get("door_base_open", false)) and door.size() >= 3:
		_draw_wood(canvas, config.get("door", []), life, texture)
	var window: PackedVector2Array = _points(config.get("window", []), origin, scale)
	if bool(life["window_open"]) and window.size() >= 3:
		_draw_window(canvas, life, texture)
	elif bool(config.get("window_base_open", false)) and window.size() >= 3:
		_draw_wood(canvas, config.get("window", []), life, texture)
	if bool(life["rest_visible"]):
		var asset: Dictionary = _rest_asset(life)
		if not asset.is_empty():
			var foot: Vector2 = origin + _point(config["rest_foot"]) * scale
			var pose: String = _rest_look_key(life)
			var rest_texture: Texture2D = (asset["textures"] as Dictionary).get(pose, asset["texture"])
			var rect: Rect2 = rest_rect(life)
			var appearance: Dictionary = asset["appearance"]
			if bool(asset["has_appearance"]):
				WorkerAppearance.draw_contact(canvas, rect, rest_texture.get_size(), appearance)
			else:
				canvas.draw_texture_rect(_soft(), Rect2(foot - Vector2(3, 0.8), Vector2(6, 1.8)), false, Color(0.12, 0.10, 0.06, 0.4))
			WorkerAppearance.draw_body(canvas, rest_texture, rect, appearance,
				WorkerIdle.quads(rect, rest_texture.get_size(), rest_motion_for(life)))


func rest_rect(life: Dictionary) -> Rect2:
	if life.is_empty() or not bool(life.get("known", false)) or not bool(life.get("rest_visible", false)):
		return Rect2()
	var asset: Dictionary = _rest_asset(life)
	if asset.is_empty():
		return Rect2()
	var foot: Vector2 = (life["rect"] as Rect2).position \
		+ _point((life["config"] as Dictionary)["rest_foot"]) * float(life["source_to_world"])
	return Rect2(foot - (asset["anchor"] as Vector2) * float(asset["scale"]),
		(asset["texture"] as Texture2D).get_size() * float(asset["scale"]))


func contains_point(life: Dictionary, point: Vector2) -> bool:
	var rect: Rect2 = rest_rect(life)
	if not rect.has_area() or not rect.has_point(point):
		return false
	var asset: Dictionary = _rest_asset(life)
	var mask: BitMap = (asset["masks"] as Dictionary).get(_rest_look_key(life), asset["mask"])
	var source: Vector2 = WorkerIdle.source_at((point - rect.position) / float(asset["scale"]),
		Vector2(mask.get_size()), rest_motion_for(life))
	return Rect2(Vector2.ZERO, Vector2(mask.get_size())).has_point(source) and mask.get_bitv(Vector2i(source))


func rest_motion_for(life: Dictionary) -> Dictionary:
	if life.is_empty() or not bool(life.get("known", false)) or not bool(life.get("rest_visible", false)):
		return {}
	var asset: Dictionary = _rest_asset(life)
	if asset.is_empty():
		return {}
	var motion: Dictionary = WorkerIdle.sample(asset["idle_motion"], float(life.get("time_seconds", 0)),
		int(life.get("rest_worker_id", 0)))
	if not motion.is_empty():
		motion["offset_world"] = (motion["source_offset"] as Vector2) * float(asset["scale"])
	return motion


func rest_pose_for(life: Dictionary) -> String:
	var turn: Dictionary = _rest_turn_for(life)
	return String(turn["side"]) if float(turn["amount"]) >= 0.5 else "center"


func _rest_asset(life: Dictionary) -> Dictionary:
	var config: Dictionary = life.get("config", {})
	var rest: Dictionary = config.get("rest_sprite", {})
	if rest.is_empty() or not _valid_point(config.get("rest_foot")):
		return {}
	var key: String = JSON.stringify(rest, "", true)
	if _rest_assets.has(key):
		return _rest_assets[key]
	# Invalid and unavailable assets are also cached. Production resources are
	# immutable within one library lifetime; a new import starts a fresh session.
	_rest_assets[key] = {}
	var appearance: Variant = rest.get("appearance", {})
	if not WorkerAppearance.valid(appearance):
		return {}
	var body_height: float = float(rest.get("body_height_px", 0))
	if not is_finite(body_height) or body_height <= 0.0 or not _valid_point(rest.get("ground_contact")):
		return {}
	var pixels: Image = _load_image(String(rest.get("texture", "")))
	if pixels == null:
		return {}
	var idle_motion: Variant = rest.get("idle_motion", {})
	if not WorkerIdle.valid(idle_motion, Vector2(pixels.get_size())):
		return {}
	var anchor: Vector2 = _point(rest["ground_contact"])
	if anchor.x < 0.0 or anchor.y < 0.0 or anchor.x > pixels.get_width() or anchor.y > pixels.get_height():
		return {}
	if not idle_motion.is_empty() and float(idle_motion["fixed_from_y"]) > anchor.y:
		return {}
	var mask := BitMap.new()
	mask.create_from_image_alpha(pixels, ALPHA_THRESHOLD)
	if mask.get_true_bit_count() == 0 or mask.get_bitv(Vector2i.ZERO):
		return {}
	var asset: Dictionary = {"anchor": anchor, "scale": HUMAN_HEIGHT / body_height,
		"mask": mask, "textures": {}, "masks": {}, "appearance": appearance,
		"has_appearance": rest.has("appearance"), "idle_motion": idle_motion}
	_load_looks(pixels, rest.get("look_textures", {}), asset)
	pixels.generate_mipmaps()
	asset["texture"] = ImageTexture.create_from_image(pixels)
	_rest_assets[key] = asset
	return asset


static func _load_image(path: String) -> Image:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var pixels: Image = texture.get_image()
	if pixels == null or pixels.is_empty():
		return null
	if pixels.is_compressed():
		pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	return pixels


static func _load_looks(center: Image, look_paths: Dictionary, asset: Dictionary) -> void:
	for side: String in ["left", "right"]:
		var target: Image = _load_image(String(look_paths.get(side, "")))
		if target == null or target.get_size() != center.get_size():
			continue
		var changed := Rect2i()
		for y: int in range(center.get_height()):
			for x: int in range(center.get_width()):
				if center.get_pixel(x, y) != target.get_pixel(x, y):
					var pixel := Rect2i(x, y, 1, 1)
					changed = pixel if not changed.has_area() else changed.merge(pixel)
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
			mask.create_from_image_alpha(blended, ALPHA_THRESHOLD)
			(asset["masks"] as Dictionary)[key] = mask
			blended.generate_mipmaps()
			(asset["textures"] as Dictionary)[key] = ImageTexture.create_from_image(blended)


static func _rest_turn_for(life: Dictionary) -> Dictionary:
	if not bool(life.get("rest_visible", false)):
		return {"side": "center", "amount": 0.0}
	# Same restrained rhythm as the lumber hut. Only authored head pixels vary;
	# the sprite rectangle and foot never move, and saved simulation time rules.
	var phase: float = fposmod(float(life.get("time_seconds", 0.0)) + float(life.get("rest_worker_id", 0)) * 0.73, 12.0)
	var side: String = "center"
	var amount: float = 0.0
	if phase >= 2.0 and phase < 4.0 + LOOK_TURN_SECONDS:
		side = "left"
		amount = minf((phase - 2.0) / LOOK_TURN_SECONDS, (4.0 + LOOK_TURN_SECONDS - phase) / LOOK_TURN_SECONDS)
	elif phase >= 7.0 and phase < 9.0 + LOOK_TURN_SECONDS:
		side = "right"
		amount = minf((phase - 7.0) / LOOK_TURN_SECONDS, (9.0 + LOOK_TURN_SECONDS - phase) / LOOK_TURN_SECONDS)
	return {"side": side, "amount": smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))}


static func _rest_look_key(life: Dictionary) -> String:
	var turn: Dictionary = _rest_turn_for(life)
	return "%s:%d" % [turn["side"], roundi(float(turn["amount"]) * LOOK_TURN_STEPS)]


static func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and is_finite(float(value[0])) and is_finite(float(value[1]))


static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _points(source: Array, origin: Vector2, scale: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for value: Variant in source:
		if not _valid_point(value):
			return PackedVector2Array()
		points.append(origin + _point(value) * scale)
	return points


static func _draw_wood(canvas: CanvasItem, quad: Array, life: Dictionary, texture: Texture2D) -> void:
	var config: Dictionary = life["config"]
	var points: PackedVector2Array = _points(quad, (life["rect"] as Rect2).position, float(life["source_to_world"]))
	if points.size() < 3:
		return
	var uv_source: Array = config.get("wood_uv", [])
	if uv_source.size() != points.size() or texture == null:
		canvas.draw_colored_polygon(points, Color(0.37, 0.25, 0.14))
		return
	var uv: PackedVector2Array = _points(uv_source, Vector2.ZERO, 1.0)
	for index: int in range(uv.size()):
		uv[index] /= texture.get_size()
	canvas.draw_polygon(points, PackedColorArray([Color(0.88, 0.83, 0.74)]), uv, texture)


static func _draw_window(canvas: CanvasItem, life: Dictionary, texture: Texture2D) -> void:
	var config: Dictionary = life["config"]
	var window: PackedVector2Array = _points(config.get("window", []), (life["rect"] as Rect2).position, float(life["source_to_world"]))
	canvas.draw_colored_polygon(window, Color(0.10, 0.085, 0.065))
	if window.size() == 4:
		canvas.draw_line(window[0].lerp(window[1], 0.5), window[3].lerp(window[2], 0.5), Color(0.23, 0.15, 0.08), 0.85, true)
		canvas.draw_line(window[0].lerp(window[3], 0.52), window[1].lerp(window[2], 0.52), Color(0.25, 0.16, 0.08), 0.8, true)
	for shutter: Array in config.get("window_shutters", []):
		_draw_wood(canvas, shutter, life, texture)


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
