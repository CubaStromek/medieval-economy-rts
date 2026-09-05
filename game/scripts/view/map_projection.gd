class_name MapProjection
extends RefCounted

# Flat orthogonal foundation. Height will later offset shared corner vertices,
# while callers continue to use this projection boundary.
const CELL_SIZE := Vector2(48.0, 48.0)
const HEIGHT_STEP_PIXELS: float = 8.0


static func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * CELL_SIZE.x, float(cell.y) * CELL_SIZE.y)


static func cell_center(cell: Vector2i) -> Vector2:
	return cell_origin(cell) + CELL_SIZE * 0.5


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_origin(cell), CELL_SIZE)


static func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / CELL_SIZE.x),
		floori(position.y / CELL_SIZE.y)
	)


static func map_bounds(map_size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map_size) * CELL_SIZE)


static func corner_position(vertex: Vector2i, height: int = 0) -> Vector2:
	return Vector2(
		float(vertex.x) * CELL_SIZE.x,
		float(vertex.y) * CELL_SIZE.y - float(height) * HEIGHT_STEP_PIXELS
	)
