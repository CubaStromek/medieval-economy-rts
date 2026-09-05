class_name ResourceIcon
extends Control

var resource_id: String = ""
var icon_color := Color(0.64, 0.58, 0.46)


func configure(new_resource_id: String, new_icon_color: Color) -> void:
	resource_id = new_resource_id
	icon_color = new_icon_color
	custom_minimum_size = Vector2(38, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var unit: float = minf(size.x, size.y) / 38.0
	var outline := Color(0.91, 0.84, 0.66, 0.88)
	draw_circle(center, 17.0 * unit, Color(0.04, 0.055, 0.05, 0.78))
	draw_arc(center, 16.5 * unit, 0.0, TAU, 32, Color(0.39, 0.37, 0.28, 0.95), 1.4 * unit, true)

	match resource_id:
		"log":
			_draw_log(center, unit, outline)
		"plank":
			_draw_planks(center, unit, outline)
		"stone":
			_draw_stone(center, unit, outline)
		_:
			_draw_fallback(center, unit, outline)


func _draw_log(center: Vector2, unit: float, outline: Color) -> void:
	var body_color: Color = icon_color.lightened(0.08)
	var end_color: Color = icon_color.lightened(0.34)
	var body_rect := Rect2(center + Vector2(-10, -5) * unit, Vector2(18, 10) * unit)
	draw_rect(body_rect, body_color)
	draw_circle(center + Vector2(-10, 0) * unit, 5.0 * unit, icon_color.darkened(0.12))
	draw_circle(center + Vector2(8, 0) * unit, 5.0 * unit, end_color)
	draw_arc(center + Vector2(8, 0) * unit, 3.2 * unit, 0.0, TAU, 20, icon_color.darkened(0.2), 1.0 * unit, true)
	draw_line(center + Vector2(-8, -5) * unit, center + Vector2(7, -5) * unit, outline, 1.1 * unit, true)
	draw_line(center + Vector2(-8, 5) * unit, center + Vector2(7, 5) * unit, outline.darkened(0.4), 1.1 * unit, true)


func _draw_planks(center: Vector2, unit: float, outline: Color) -> void:
	for index: int in range(3):
		var y_offset: float = float(index - 1) * 6.0
		var points := PackedVector2Array([
			center + Vector2(-11, y_offset - 3) * unit,
			center + Vector2(8, y_offset - 3) * unit,
			center + Vector2(11, y_offset) * unit,
			center + Vector2(-8, y_offset) * unit,
		])
		var plank_color: Color = icon_color.lightened(0.12 - float(index) * 0.05)
		draw_colored_polygon(points, plank_color)
		draw_polyline(
			PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
			outline.darkened(0.12 + float(index) * 0.08),
			1.0 * unit,
			true
		)


func _draw_stone(center: Vector2, unit: float, outline: Color) -> void:
	var back_stone := PackedVector2Array([
		center + Vector2(-10, 3) * unit,
		center + Vector2(-8, -5) * unit,
		center + Vector2(-3, -9) * unit,
		center + Vector2(3, -5) * unit,
		center + Vector2(2, 4) * unit,
	])
	var right_stone := PackedVector2Array([
		center + Vector2(0, 5) * unit,
		center + Vector2(3, -4) * unit,
		center + Vector2(9, -6) * unit,
		center + Vector2(13, 0) * unit,
		center + Vector2(10, 7) * unit,
	])
	var front_stone := PackedVector2Array([
		center + Vector2(-11, 8) * unit,
		center + Vector2(-8, 1) * unit,
		center + Vector2(-1, -2) * unit,
		center + Vector2(6, 2) * unit,
		center + Vector2(5, 9) * unit,
	])
	_draw_outlined_polygon(back_stone, icon_color.darkened(0.12), outline.darkened(0.34), unit)
	_draw_outlined_polygon(right_stone, icon_color.lightened(0.06), outline.darkened(0.28), unit)
	_draw_outlined_polygon(front_stone, icon_color.lightened(0.18), outline, unit)


func _draw_fallback(center: Vector2, unit: float, outline: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -11) * unit,
		center + Vector2(11, 0) * unit,
		center + Vector2(0, 11) * unit,
		center + Vector2(-11, 0) * unit,
	])
	_draw_outlined_polygon(points, icon_color, outline, unit)


func _draw_outlined_polygon(
	points: PackedVector2Array,
	fill_color: Color,
	line_color: Color,
	unit: float
) -> void:
	draw_colored_polygon(points, fill_color)
	var closed_points := PackedVector2Array(points)
	closed_points.append(points[0])
	draw_polyline(closed_points, line_color, 1.0 * unit, true)
