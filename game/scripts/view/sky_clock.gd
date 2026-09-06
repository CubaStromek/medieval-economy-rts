class_name SkyClock
extends Control

const SolarCycleClass = preload("res://scripts/view/solar_cycle.gd")
const BODY_RADIUS: float = 5.0

var solar_state: Dictionary = {}
var body_position: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "SkyClock"
	custom_minimum_size = Vector2(184, 86)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	set_time(0)


func set_time(tick: int, fraction: float = 0.0) -> void:
	# The world clock is the only time source: pause, speed and loading all agree.
	solar_state = SolarCycleClass.sample(tick, fraction)
	_update_body_position()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_body_position()
		queue_redraw()


func _update_body_position() -> void:
	if solar_state.is_empty():
		return
	var progress: float = float(solar_state["sun_progress"] if bool(solar_state["sun_visible"]) else solar_state["moon_progress"])
	body_position = _arc_point(progress)


func _arc_point(progress: float) -> Vector2:
	var available: Vector2 = size.max(custom_minimum_size)
	return Vector2(lerpf(20.0, available.x - 20.0, progress), available.y - 23.0 - sin(progress * PI) * 35.0)


func _draw() -> void:
	if solar_state.is_empty():
		return
	var sun_visible: bool = bool(solar_state["sun_visible"])
	var top: Color = solar_state["sky_top"] as Color
	var horizon: Color = solar_state["sky_horizon"] as Color
	_draw_sky(top, horizon)
	var font: Font = get_theme_default_font()
	var pale := Color("#f2ead5")
	var path_color := Color(0.97, 0.91, 0.74, 0.26)
	var caption: String = "SUN PATH" if sun_visible else "MOON PATH"
	draw_string(font, Vector2(0, 15), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, pale)
	var arc := PackedVector2Array()
	for index: int in range(41):
		arc.append(_arc_point(float(index) / 40.0))
	draw_polyline(arc, path_color, 1.0, true)
	if not sun_visible:
		for star: Vector2 in [Vector2(35, 26), Vector2(57, 18), Vector2(122, 22), Vector2(153, 32)]:
			draw_circle(star, 0.7, Color(0.85, 0.91, 1.0, 0.7), true, -1.0, true)
	var body_color := Color("#ffe8a5") if sun_visible else Color("#e5edf4")
	draw_circle(body_position, BODY_RADIUS + 6.0, Color(body_color, 0.06), true, -1.0, true)
	draw_circle(body_position, BODY_RADIUS + 3.0, Color(body_color, 0.13), true, -1.0, true)
	draw_circle(body_position, BODY_RADIUS, body_color, true, -1.0, true)
	if sun_visible:
		for ray: int in range(8):
			var direction := Vector2.from_angle(float(ray) * TAU / 8.0)
			draw_line(body_position + direction * 7.5, body_position + direction * 9.0, Color(body_color, 0.8), 1.0, true)
	else:
		# A soft crescent remains recognizable even at this small scale.
		var moon_backdrop: Color = top.lerp(horizon, clampf((body_position.y - 2.0) / size.y, 0.0, 1.0))
		draw_circle(body_position + Vector2(2.5, -1.8), BODY_RADIUS - 0.4, moon_backdrop, true, -1.0, true)
	var horizon_y: float = size.y - 18.0
	draw_line(Vector2(12, horizon_y), Vector2(size.x - 12, horizon_y), Color(pale, 0.32), 1.0, true)
	draw_string(font, Vector2(15, size.y - 5), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	draw_string(font, Vector2(size.x - 23, size.y - 5), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	draw_string(font, Vector2(0, size.y - 5), "05:00 — 20:00" if sun_visible else "20:00 — 05:00", HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color(pale, 0.8))


func _draw_sky(top: Color, horizon: Color) -> void:
	# Vertex colors provide a smooth gradient without a texture or a shader.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var radius: float = 7.0
	var centers: Array[Vector2] = [Vector2(size.x - radius - 1, radius + 1), Vector2(size.x - radius - 1, size.y - radius - 1), Vector2(radius + 1, size.y - radius - 1), Vector2(radius + 1, radius + 1)]
	for corner: int in range(4):
		for segment: int in range(7):
			var angle: float = -PI * 0.5 + float(corner) * PI * 0.5 + float(segment) * PI / 12.0
			var point: Vector2 = centers[corner] + Vector2.from_angle(angle) * radius
			points.append(point)
			colors.append(top.lerp(horizon, point.y / maxf(size.y, 1.0)))
	draw_polygon(points, colors)
	points.append(points[0])
	draw_polyline(points, Color(0.74, 0.75, 0.62, 0.6), 1.0, true)
