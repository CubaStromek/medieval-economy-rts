class_name MapProjection
extends RefCounted

# Square, axis-aligned ground cells. Relief projects upward without rotating
# the map or changing simulation coordinates; world objects share this origin.
const CELL_SIZE := Vector2(40.0, 40.0)
const HEIGHT_STEP_PIXELS: float = 8.0


static func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * CELL_SIZE.x, float(cell.y) * CELL_SIZE.y)


static func cell_center(cell: Vector2i) -> Vector2:
	return cell_origin(cell) + CELL_SIZE * 0.5


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_origin(cell), CELL_SIZE)


static func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE.x), floori(position.y / CELL_SIZE.y))


static func map_bounds(map_size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map_size) * CELL_SIZE)


static func corner_position(vertex: Vector2i, height: float = 0.0) -> Vector2:
	return Vector2(float(vertex.x) * CELL_SIZE.x, float(vertex.y) * CELL_SIZE.y - height * HEIGHT_STEP_PIXELS)


# Fractional cell-center coordinates: (0, 0) is the center of the first cell.
# The renderer supplies a height sampled on the same two terrain triangles.
static func project_grid_position(position: Vector2, height: float = 0.0) -> Vector2:
	return (position + Vector2(0.5, 0.5)) * CELL_SIZE - Vector2(0.0, height * HEIGHT_STEP_PIXELS)
