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
		"stone", "coal", "iron_ore", "gold_ore":
			_draw_stone(center, unit, outline)
		"grain":
			_draw_grain(center, unit, outline)
		"flour":
			_draw_flour(center, unit, outline)
		"bread":
			_draw_bread(center, unit, outline)
		"iron", "gold":
			_draw_ingot(center, unit, outline)
		"wine":
			_draw_wine(center, unit, outline)
		"fish":
			_draw_fish(center, unit, outline)
		"sausage":
			_draw_sausages(center, unit, outline)
		"pig", "horse":
			_draw_animal(center, unit, outline)
		"skin", "leather":
			_draw_hide(center, unit, outline)
		"wooden_shield", "iron_shield", "leather_armour", "iron_armour":
			_draw_armour(center, unit, outline)
		"axe", "sword", "lance", "pike", "bow", "crossbow":
			_draw_weapon(center, unit, outline)
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


func _draw_grain(center: Vector2, unit: float, outline: Color) -> void:
	for stalk: int in range(3):
		var offset: Vector2 = Vector2(float(stalk - 1) * 6.0, absf(float(stalk - 1)) * 3.0) * unit
		var tip: Vector2 = center + offset + Vector2(0, -11) * unit
		draw_line(center + Vector2(0, 12) * unit, tip, icon_color.darkened(0.15), 1.7 * unit, true)
		for seed: int in range(3):
			var point: Vector2 = tip + Vector2(0, float(seed) * 4.0) * unit
			draw_line(point + Vector2(-3, 0) * unit, point + Vector2(0, 3) * unit, icon_color.lightened(0.18), 2.4 * unit, true)
			draw_line(point + Vector2(3, -1) * unit, point + Vector2(0, 2) * unit, outline, 2.4 * unit, true)
	draw_line(center + Vector2(-4, 8) * unit, center + Vector2(4, 8) * unit, icon_color.darkened(0.35), 2.0 * unit, true)


func _draw_flour(center: Vector2, unit: float, outline: Color) -> void:
	var bag := PackedVector2Array([
		center + Vector2(-7, -10) * unit,
		center + Vector2(6, -10) * unit,
		center + Vector2(5, -5) * unit,
		center + Vector2(11, 5) * unit,
		center + Vector2(9, 11) * unit,
		center + Vector2(-9, 11) * unit,
		center + Vector2(-11, 5) * unit,
		center + Vector2(-5, -5) * unit,
	])
	_draw_outlined_polygon(bag, icon_color, outline, unit)
	draw_line(center + Vector2(-6, -5) * unit, center + Vector2(6, -5) * unit, icon_color.darkened(0.44), 2.0 * unit, true)
	draw_circle(center + Vector2(0, 4) * unit, 4.0 * unit, icon_color.darkened(0.20))
	draw_line(center + Vector2(0, 7) * unit, center + Vector2(0, 1) * unit, outline, 1.2 * unit, true)
	draw_line(center + Vector2(-2, 2) * unit, center + Vector2(2, 5) * unit, outline, 1.2 * unit, true)


func _draw_bread(center: Vector2, unit: float, outline: Color) -> void:
	var loaf := PackedVector2Array([
		center + Vector2(-13, 3) * unit,
		center + Vector2(-10, -4) * unit,
		center + Vector2(-5, -8) * unit,
		center + Vector2(5, -8) * unit,
		center + Vector2(11, -3) * unit,
		center + Vector2(13, 4) * unit,
		center + Vector2(9, 8) * unit,
		center + Vector2(-9, 8) * unit,
	])
	_draw_outlined_polygon(loaf, icon_color, outline, unit)
	draw_line(center + Vector2(-10, 5) * unit, center + Vector2(10, 5) * unit, icon_color.darkened(0.25), 2.0 * unit, true)
	for score: int in range(3):
		var x: float = float(score - 1) * 6.0
		draw_line(center + Vector2(x - 1, -5) * unit, center + Vector2(x + 2, 0) * unit, outline.lightened(0.1), 2.0 * unit, true)


func _draw_ingot(center: Vector2, unit: float, outline: Color) -> void:
	var front := PackedVector2Array([center + Vector2(-12, 6) * unit, center + Vector2(-9, -3) * unit, center + Vector2(8, -3) * unit, center + Vector2(12, 6) * unit])
	_draw_outlined_polygon(front, icon_color, outline, unit)
	var top := PackedVector2Array([front[1], center + Vector2(-4, -8) * unit, center + Vector2(11, -8) * unit, front[2]])
	_draw_outlined_polygon(top, icon_color.lightened(0.25), outline, unit)
	draw_line(center + Vector2(-8, 3) * unit, center + Vector2(8, 3) * unit, icon_color.lightened(0.3), 1.0 * unit, true)


func _draw_wine(center: Vector2, unit: float, outline: Color) -> void:
	var bottle := PackedVector2Array([center + Vector2(-3, -12) * unit, center + Vector2(3, -12) * unit, center + Vector2(3, -5) * unit, center + Vector2(7, -1) * unit, center + Vector2(7, 11) * unit, center + Vector2(-7, 11) * unit, center + Vector2(-7, -1) * unit, center + Vector2(-3, -5) * unit])
	_draw_outlined_polygon(bottle, icon_color.darkened(0.2), outline, unit)
	draw_rect(Rect2(center + Vector2(-5, 1) * unit, Vector2(10, 6) * unit), Color(0.89, 0.79, 0.56))
	draw_circle(center + Vector2(0, 4) * unit, 2.0 * unit, icon_color)


func _draw_fish(center: Vector2, unit: float, outline: Color) -> void:
	var fish := PackedVector2Array([center + Vector2(-7, 0) * unit, center + Vector2(-13, -6) * unit, center + Vector2(-13, 6) * unit, center + Vector2(-7, 1) * unit, center + Vector2(0, 7) * unit, center + Vector2(12, 0) * unit, center + Vector2(0, -7) * unit])
	_draw_outlined_polygon(fish, icon_color, outline, unit)
	draw_circle(center + Vector2(7, -1) * unit, 1.2 * unit, Color(0.10, 0.14, 0.13))
	draw_line(center + Vector2(1, -4) * unit, center + Vector2(1, 4) * unit, icon_color.darkened(0.25), 1.0 * unit, true)


func _draw_sausages(center: Vector2, unit: float, outline: Color) -> void:
	for link: int in range(3):
		var x: float = float(link - 1) * 7.0
		draw_line(center + Vector2(x, -8) * unit, center + Vector2(x + 2, 8) * unit, outline, 5.5 * unit, true)
		draw_line(center + Vector2(x, -7) * unit, center + Vector2(x + 2, 7) * unit, icon_color, 4.0 * unit, true)
		draw_line(center + Vector2(x - 2, -10) * unit, center + Vector2(x + 2, -8) * unit, outline, 1.0 * unit, true)


func _draw_animal(center: Vector2, unit: float, outline: Color) -> void:
	draw_circle(center + Vector2(-3, 1) * unit, 8.0 * unit, icon_color)
	var head: Vector2 = center + Vector2(7, -3) * unit
	if resource_id == "horse":
		head = center + Vector2(7, -8) * unit
		draw_line(center + Vector2(4, 3) * unit, head, icon_color, 6.0 * unit, true)
	draw_circle(head, 4.5 * unit, icon_color.lightened(0.1))
	draw_line(head + Vector2(-2, -3) * unit, head + Vector2(-2, -7) * unit, outline, 2.0 * unit, true)
	draw_circle(head + Vector2(2, -1) * unit, 0.9 * unit, Color(0.10, 0.10, 0.08))
	for leg: int in [-1, 1]:
		draw_line(center + Vector2(leg * 5, 4) * unit, center + Vector2(leg * 5, 12) * unit, icon_color.darkened(0.1), 2.3 * unit, true)


func _draw_hide(center: Vector2, unit: float, outline: Color) -> void:
	var hide := PackedVector2Array([center + Vector2(-10, -10) * unit, center + Vector2(-3, -7) * unit, center + Vector2(3, -7) * unit, center + Vector2(10, -10) * unit, center + Vector2(6, -1) * unit, center + Vector2(11, 9) * unit, center + Vector2(3, 7) * unit, center + Vector2(-3, 7) * unit, center + Vector2(-11, 9) * unit, center + Vector2(-6, -1) * unit])
	_draw_outlined_polygon(hide, icon_color, outline, unit)
	draw_line(center + Vector2(0, -5) * unit, center + Vector2(0, 5) * unit, icon_color.darkened(0.25), 1.0 * unit, true)


func _draw_armour(center: Vector2, unit: float, outline: Color) -> void:
	var points: PackedVector2Array
	if "shield" in resource_id:
		points = PackedVector2Array([center + Vector2(-10, -10) * unit, center + Vector2(10, -10) * unit, center + Vector2(8, 3) * unit, center + Vector2(0, 12) * unit, center + Vector2(-8, 3) * unit])
	else:
		points = PackedVector2Array([center + Vector2(-5, -10) * unit, center + Vector2(-11, -6) * unit, center + Vector2(-8, 0) * unit, center + Vector2(-6, -2) * unit, center + Vector2(-7, 11) * unit, center + Vector2(7, 11) * unit, center + Vector2(6, -2) * unit, center + Vector2(8, 0) * unit, center + Vector2(11, -6) * unit, center + Vector2(5, -10) * unit, center + Vector2(0, -6) * unit])
	_draw_outlined_polygon(points, icon_color, outline, unit)
	draw_line(center + Vector2(0, -5) * unit, center + Vector2(0, 8) * unit, icon_color.lightened(0.3), 1.5 * unit, true)


func _draw_weapon(center: Vector2, unit: float, outline: Color) -> void:
	if resource_id in ["bow", "crossbow"]:
		draw_arc(center + Vector2(-3, 0) * unit, 12.0 * unit, -PI * 0.5, PI * 0.5, 20, icon_color, 2.7 * unit, true)
		draw_line(center + Vector2(-3, -12) * unit, center + Vector2(-3, 12) * unit, outline, 1.0 * unit, true)
		if resource_id == "crossbow":
			draw_line(center + Vector2(-11, 0) * unit, center + Vector2(11, 0) * unit, icon_color.lightened(0.2), 3.0 * unit, true)
		return
	draw_line(center + Vector2(-8, 11) * unit, center + Vector2(7, -10) * unit, icon_color if resource_id == "sword" else Color(0.68, 0.47, 0.25), 3.0 * unit, true)
	if resource_id == "axe":
		var head := PackedVector2Array([center + Vector2(1, -9) * unit, center + Vector2(10, -12) * unit, center + Vector2(13, -3) * unit, center + Vector2(5, -3) * unit])
		_draw_outlined_polygon(head, icon_color, outline, unit)
	elif resource_id == "sword":
		draw_line(center + Vector2(-7, -1) * unit, center + Vector2(1, 5) * unit, outline, 2.3 * unit, true)
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(3, -8) * unit, center + Vector2(10, -14) * unit, center + Vector2(8, -5) * unit]), outline)


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
