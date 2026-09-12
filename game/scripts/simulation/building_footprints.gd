extends RefCounted

# The anchor is the bottom-left cell of the tightly trimmed bounding box.
# Rows run north to south. '#' and 'E' occupy ground; '.' remains available.
# 'E' marks the occupied door tile. Citizens use its southern exterior cell,
# including a southern-facing recess inside the bounding box.
# Version 0 is immutable geometry for the original one-cell saved buildings.
# This is the maximum supported authoring revision, not every type's revision.
const CURRENT_VERSION: int = 2
const NO_CELL := Vector2i(-1, -1)


static func latest_version(definition: Dictionary) -> int:
	return int(definition.get("footprint_version", 1))


# Historical masks stay in the catalog alongside the current artwork's mask.
# A saved instance selects its exact revision; loading never enlarges it.
static func for_version(definition: Dictionary, version: int = -1) -> Dictionary:
	var latest: int = latest_version(definition)
	var resolved: int = latest if version == -1 else version
	if resolved < 1 or resolved > latest or latest < 1 or latest > CURRENT_VERSION:
		return {}
	if resolved == latest:
		return definition
	var revisions: Dictionary = definition.get("footprint_revisions", {})
	return revisions.get(str(resolved), {}) as Dictionary


static func supports_version(definition: Dictionary, version: int) -> bool:
	if definition.is_empty() or version < 0:
		return false
	if version == 0:
		return true
	return valid_definition(for_version(definition, version))


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
				# The door may face a notch, but its approach must lead out of
				# the mask without crossing another occupied foundation tile.
				for southern_y: int in range(y + 1, rows.size()):
					if not rows[southern_y] is String or String(rows[southern_y]).length() != width or String(rows[southern_y])[x] != ".":
						return false
	return doors == 1 and occupied_left and occupied_right


static func cells(definition: Dictionary, anchor: Vector2i, version: int = -1) -> Array[Vector2i]:
	if version == 0:
		return [anchor]
	var result: Array[Vector2i] = []
	var geometry: Dictionary = for_version(definition, version)
	if not valid_definition(geometry):
		return result
	var rows: Array = geometry["footprint_mask"]
	for y: int in range(rows.size()):
		var row: String = rows[y]
		for x: int in range(row.length()):
			if row[x] != ".":
				result.append(anchor + Vector2i(x, y - rows.size() + 1))
	return result


static func door_cell(definition: Dictionary, anchor: Vector2i, version: int = -1) -> Vector2i:
	if version == 0:
		return anchor
	var geometry: Dictionary = for_version(definition, version)
	if not valid_definition(geometry):
		return NO_CELL
	var rows: Array = geometry["footprint_mask"]
	for y: int in range(rows.size()):
		var door_x: int = String(rows[y]).find("E")
		if door_x >= 0:
			return anchor + Vector2i(door_x, y - rows.size() + 1)
	return NO_CELL
