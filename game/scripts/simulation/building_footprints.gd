extends RefCounted

# The anchor is the bottom-left cell of the tightly trimmed bounding box.
# Rows run north to south. '#' and 'E' occupy ground; '.' remains available.
# 'E' marks the occupied door tile. Citizens use its southern exterior cell.
# Version 0 is immutable geometry for the original one-cell saved buildings.
const CURRENT_VERSION: int = 1
const NO_CELL := Vector2i(-1, -1)


static func valid_definition(definition: Dictionary) -> bool:
	var rows: Array = definition.get("footprint_mask", [])
	var size: Array = definition.get("footprint", [])
	if rows.is_empty() or size.size() != 2 or int(size[0]) <= 0 or int(size[1]) != rows.size():
		return false
	var width: int = int(size[0])
	var doors: int = 0
	var occupied_left: bool = false
	var occupied_right: bool = false
	for y: int in range(rows.size()):
		if not rows[y] is String or String(rows[y]).length() != width:
			return false
		var row: String = rows[y]
		if (y == 0 or y == rows.size() - 1) and row.count(".") == width:
			return false
		occupied_left = occupied_left or row[0] != "."
		occupied_right = occupied_right or row[width - 1] != "."
		for x: int in range(width):
			if row[x] not in ["#", "E", "."]:
				return false
			if row[x] == "E":
				doors += 1
				if y != rows.size() - 1:
					return false
	return doors == 1 and occupied_left and occupied_right


static func cells(definition: Dictionary, anchor: Vector2i, version: int = CURRENT_VERSION) -> Array[Vector2i]:
	if version == 0:
		return [anchor]
	var result: Array[Vector2i] = []
	if version != CURRENT_VERSION or not valid_definition(definition):
		return result
	var rows: Array = definition["footprint_mask"]
	for y: int in range(rows.size()):
		var row: String = rows[y]
		for x: int in range(row.length()):
			if row[x] != ".":
				result.append(anchor + Vector2i(x, y - rows.size() + 1))
	return result


static func door_cell(definition: Dictionary, anchor: Vector2i, version: int = CURRENT_VERSION) -> Vector2i:
	if version == 0:
		return anchor
	if version != CURRENT_VERSION or not valid_definition(definition):
		return NO_CELL
	var rows: Array = definition["footprint_mask"]
	var southern_row: String = rows[rows.size() - 1]
	return anchor + Vector2i(southern_row.find("E"), 0)
