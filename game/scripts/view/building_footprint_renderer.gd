extends RefCounted

# The same terrain-projected geometry is used for painting and pointer picking.
# A cut-out in a house mask remains a cut-out in its foundation and roof.
const WALL_HEIGHT: float = 28.0
const ROOF_RISE: float = 20.0


static func geometry(world: Variant, terrain: Variant, building: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = world.building_cells(building)
	var earthwork: bool = int(building.get("foundation_work_remaining", 0)) > 0
	var work_total: int = maxi(1, int(building.get("foundation_work_total", 0)))
	var earthwork_progress: float = clampf(1.0 - float(building.get("foundation_work_remaining", 0)) / float(work_total), 0.0, 1.0)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for cell: Vector2i in cells:
		low = low.min(Vector2(cell) - Vector2(0.5, 0.5))
		high = high.max(Vector2(cell) + Vector2(0.5, 0.5))
	var ridge: float = (low.y + high.y) * 0.5
	var foundations: Array[PackedVector2Array] = []
	var roofs: Array[Dictionary] = []
	var walls: Array[PackedVector2Array] = []
	var boundary: Array[PackedVector2Array] = []
	var roof_edges: Array[PackedVector2Array] = []
	var south_edges: Array[PackedVector2Array] = []
	for cell: Vector2i in cells:
		foundations.append(terrain.cell_polygon(cell))
		var north: float = float(cell.y) - 0.5
		var south: float = float(cell.y) + 0.5
		var splits: Array[float] = [north]
		if ridge > north and ridge < south:
			splits.append(ridge)
		splits.append(south)
		for index: int in range(splits.size() - 1):
			var corners := PackedVector2Array([
				Vector2(cell.x - 0.5, splits[index]), Vector2(cell.x + 0.5, splits[index]),
				Vector2(cell.x + 0.5, splits[index + 1]), Vector2(cell.x - 0.5, splits[index + 1]),
			])
			var polygon := PackedVector2Array()
			for corner: Vector2 in corners:
				polygon.append(_roof_point(terrain, corner, low, high))
			roofs.append({"points": polygon, "north": splits[index] < ridge, "cell": cell})
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if cells.has(cell + direction):
				continue
			var start: Vector2
			var finish: Vector2
			match direction:
				Vector2i.UP:
					start = Vector2(cell) + Vector2(-0.5, -0.5)
					finish = start + Vector2.RIGHT
				Vector2i.RIGHT:
					start = Vector2(cell) + Vector2(0.5, -0.5)
					finish = start + Vector2.DOWN
				Vector2i.DOWN:
					start = Vector2(cell) + Vector2(0.5, 0.5)
					finish = start + Vector2.LEFT
				_:
					start = Vector2(cell) + Vector2(-0.5, 0.5)
					finish = start + Vector2.UP
			var a: Vector2 = terrain.project_grid_position(start)
			var b: Vector2 = terrain.project_grid_position(finish)
			boundary.append(PackedVector2Array([a, b]))
			var roof_line := PackedVector2Array([_roof_point(terrain, start, low, high)])
			if minf(start.y, finish.y) < ridge and maxf(start.y, finish.y) > ridge:
				roof_line.append(_roof_point(terrain, Vector2(start.x, ridge), low, high))
			roof_line.append(_roof_point(terrain, finish, low, high))
			roof_edges.append(roof_line)
			if direction == Vector2i.DOWN:
				walls.append(PackedVector2Array([a, b, b - Vector2(0, WALL_HEIGHT), a - Vector2(0, WALL_HEIGHT)]))
				south_edges.append(PackedVector2Array([a, b]))
	# Uneven sites only have surveying stakes and ground work. Do not expose
	# a pitched roof or tall scaffold to drawing, selection or other consumers.
	if earthwork:
		roofs.clear()
		walls.clear()
		roof_edges.clear()
	var door_cell: Vector2i = world.building_door_cell(building)
	var door: Vector2 = terrain.project_grid_position(Vector2(door_cell) + Vector2(0, 0.5))
	var front: Vector2 = terrain.project_grid_position(Vector2((low.x + high.x) * 0.5, high.y))
	return {"cells": cells, "foundations": foundations, "roofs": roofs, "walls": walls,
		"boundary": boundary, "roof_edges": roof_edges, "south_edges": south_edges,
		"door": door, "door_cell": door_cell, "entrance": building["entrance"],
		"detail_center": front - Vector2(0, 5), "label_position": front + Vector2(0, 17),
		"ground_center": (low + high) * 0.5, "ground_size": high - low,
		"earthwork": earthwork, "earthwork_progress": earthwork_progress}


static func _roof_point(terrain: Variant, point: Vector2, low: Vector2, high: Vector2) -> Vector2:
	var fraction: float = inverse_lerp(low.y, high.y, point.y)
	var rise: float = minf(ROOF_RISE, (high.y - low.y) * 10.0)
	var height: float = WALL_HEIGHT + rise * (1.0 - absf(fraction * 2.0 - 1.0))
	return terrain.project_grid_position(point) - Vector2(0, height)


static func contains_point(shape: Dictionary, point: Vector2, construction: bool = false) -> bool:
	for layer: String in (["foundations"] if construction else ["foundations", "walls"]):
		for polygon: PackedVector2Array in shape[layer]:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return true
	if construction:
		for segment: PackedVector2Array in scaffold_segments(shape):
			if Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1]).distance_to(point) <= 2.0:
				return true
	else:
		for roof: Dictionary in shape["roofs"]:
			if Geometry2D.is_point_in_polygon(point, roof["points"]):
				return true
	return false


static func draw_shell(canvas: CanvasItem, shape: Dictionary, color: Color, construction: bool = false) -> void:
	if bool(shape.get("earthwork", false)):
		_draw_earthworks(canvas, shape)
		return
	var stone := Color(0.45, 0.42, 0.34)
	for polygon: PackedVector2Array in shape["foundations"]:
		canvas.draw_colored_polygon(polygon, Color(0.28, 0.25, 0.18, 0.76) if construction else stone)
	for edge: PackedVector2Array in shape["boundary"]:
		canvas.draw_polyline(edge, Color(0.20, 0.18, 0.12, 0.8), 3.0, true)
	if construction:
		_draw_scaffolding(canvas, shape)
		return
	for wall: PackedVector2Array in shape["walls"]:
		canvas.draw_colored_polygon(wall, Color(0.70, 0.65, 0.50).lerp(color, 0.18))
		canvas.draw_line(wall[0] - Vector2(0, 4), wall[1] - Vector2(0, 4), stone, 5.0)
		canvas.draw_line(wall[0], wall[3], Color(0.36, 0.25, 0.14), 3.0)
		var middle: Vector2 = (wall[0] + wall[1]) * 0.5
		if absf(middle.x - (shape["door"] as Vector2).x) > 10.0 or absf(middle.y - (shape["door"] as Vector2).y) > 3.0:
			canvas.draw_rect(Rect2(middle + Vector2(-6, -21), Vector2(12, 10)), Color(0.25, 0.24, 0.17))
			canvas.draw_line(middle + Vector2(0, -21), middle + Vector2(0, -11), Color(0.68, 0.48, 0.24), 2.0)
	for roof: Dictionary in shape["roofs"]:
		var polygon: PackedVector2Array = roof["points"]
		var shade: Color = color.darkened(0.23) if roof["north"] else color.lightened(0.08)
		canvas.draw_colored_polygon(polygon, shade)
		# Tile courses follow the actual pitched surface; seams remain subtle.
		for course: int in range(1, 4):
			var fraction: float = float(course) * 0.25
			canvas.draw_line(polygon[0].lerp(polygon[3], fraction), polygon[1].lerp(polygon[2], fraction), shade.darkened(0.12), 1.0, true)
	for edge: PackedVector2Array in shape["roof_edges"]:
		canvas.draw_polyline(edge, color.darkened(0.40), 2.0, true)


static func draw_door(canvas: CanvasItem, shape: Dictionary) -> void:
	var door: Vector2 = shape["door"]
	canvas.draw_rect(Rect2(door + Vector2(-9, -23), Vector2(18, 23)), Color(0.25, 0.18, 0.10))
	canvas.draw_rect(Rect2(door + Vector2(-11, -2), Vector2(22, 4)), Color(0.60, 0.56, 0.43))
	canvas.draw_line(door + Vector2(-10, -23), door + Vector2(10, -23), Color(0.48, 0.31, 0.15), 3.0)
	canvas.draw_line(door + Vector2(0, -21), door + Vector2(0, -2), Color(0.40, 0.27, 0.13), 1.5)
	canvas.draw_circle(door + Vector2(5, -10), 1.5, Color(0.78, 0.66, 0.37))


static func scaffold_segments(shape: Dictionary) -> Array[PackedVector2Array]:
	if bool(shape.get("earthwork", false)):
		return earthwork_segments(shape)
	var segments: Array[PackedVector2Array] = []
	for edge: PackedVector2Array in shape["boundary"]:
		for point: Vector2 in edge:
			segments.append(PackedVector2Array([point, point - Vector2(0, WALL_HEIGHT + 8.0)]))
		segments.append(PackedVector2Array([edge[0] - Vector2(0, 12), edge[1] - Vector2(0, 12)]))
		segments.append(PackedVector2Array([edge[0] - Vector2(0, WALL_HEIGHT), edge[1] - Vector2(0, WALL_HEIGHT)]))
		segments.append(PackedVector2Array([edge[0] - Vector2(0, 12), edge[1] - Vector2(0, WALL_HEIGHT)]))
	return segments


static func _draw_scaffolding(canvas: CanvasItem, shape: Dictionary) -> void:
	var timber := Color(0.71, 0.49, 0.26)
	for segment: PackedVector2Array in scaffold_segments(shape):
		canvas.draw_polyline(segment, timber, 2.5, true)
	var door: Vector2 = shape["door"]
	canvas.draw_line(door + Vector2(-11, 1), door + Vector2(11, 1), Color(0.91, 0.74, 0.35), 4.0)


# Survey stakes stay short and follow each real shared-corner height, including
# holes in an irregular mask. Their hit targets match exactly what is drawn.
static func earthwork_segments(shape: Dictionary) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	for edge: PackedVector2Array in shape["boundary"]:
		for point: Vector2 in edge:
			segments.append(PackedVector2Array([point, point - Vector2(0, 10)]))
		segments.append(PackedVector2Array([edge[0] - Vector2(0, 6), edge[1] - Vector2(0, 6)]))
	return segments


static func _draw_earthworks(canvas: CanvasItem, shape: Dictionary) -> void:
	var progress: float = float(shape["earthwork_progress"])
	for polygon: PackedVector2Array in shape["foundations"]:
		for triangle: PackedVector2Array in [PackedVector2Array([polygon[0], polygon[1], polygon[2]]),
				PackedVector2Array([polygon[0], polygon[2], polygon[3]])]:
			canvas.draw_colored_polygon(triangle, Color(0.37, 0.25, 0.12, 0.20 + progress * 0.38))
		if progress > 0.0:
			var center: Vector2 = (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 3),
				center + Vector2(-2, -2), center + Vector2(5, 0), center + Vector2(9, 4)]),
				Color(0.39, 0.27, 0.13, 0.80))
			canvas.draw_line(center + Vector2(-6, 3), center + Vector2(6, 3), Color(0.61, 0.43, 0.23), 1.5)
	for segment: PackedVector2Array in earthwork_segments(shape):
		var vertical: bool = is_equal_approx(segment[0].x, segment[1].x) and is_equal_approx(absf(segment[0].y - segment[1].y), 10.0)
		canvas.draw_polyline(segment, Color(0.78, 0.56, 0.29) if vertical else Color(0.97, 0.81, 0.46), 2.5 if vertical else 1.3, true)
