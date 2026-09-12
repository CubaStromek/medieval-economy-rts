class_name PaintedTerrainSource
extends RefCounted

# Optional local semantic metadata, not simulation/save state. Only the explicit
# Mountainous Region startup/load path attaches it; dimensions are not a map ID.
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const DEFAULT_PATH: String = "res://external_assets/maps/mountainous-region.visual.json"
const META_KEY: String = "painted_visual_source"
const FORMAT: String = "painted-visual-terrain-v1"
const SOURCE_SHA256: String = "cf70c8b222632e7281a10935125b325a0367b36a68f29aae3c4792777b397bb4"
const MAX_BYTES: int = 8 * 1024 * 1024


static func attach(grid: Grid, path: String = DEFAULT_PATH) -> bool:
	if grid == null or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return false
	return attach_data(grid, parser.data)


# Atomic validation: failures leave previous metadata and every gameplay field
# intact. Copies prevent callers from mutating an attached source after checks.
static func attach_data(grid: Grid, value: Variant) -> bool:
	if grid == null or not valid_data(value, grid.size):
		return false
	grid.set_meta(META_KEY, (value as Dictionary).duplicate(true))
	return true


static func valid_data(value: Variant, size: Vector2i) -> bool:
	if not value is Dictionary or size.x < 1 or size.y < 1 or size.x > 255 or size.y > 255:
		return false
	var data: Dictionary = value
	if data.get("format") != FORMAT or data.get("source_sha256") != SOURCE_SHA256:
		return false
	var dimensions: Variant = data.get("size")
	if not dimensions is Array or dimensions.size() != 2:
		return false
	if not _whole(dimensions[0], size.x, size.x) or not _whole(dimensions[1], size.y, size.y):
		return false
	var origin: Variant = data.get("origin", [0, 0])
	if not origin is Array or origin.size() != 2 or not _whole(origin[0], 0, 0) or not _whole(origin[1], 0, 0):
		return false
	var scale: Variant = data.get("height_scale", 0.15)
	if not scale is int and not scale is float:
		return false
	if not is_finite(float(scale)) or not is_equal_approx(float(scale), 0.15):
		return false
	var corners: Variant = data.get("corner_kinds")
	if not corners is Array or corners.size() != size.y:
		return false
	for row: Variant in corners:
		if not row is Array or row.size() != size.x:
			return false
		for kinds: Variant in row:
			if not kinds is String or kinds.length() != 4:
				return false
			for kind: String in kinds:
				if not "GPRDMWCO".contains(kind):
					return false
	if not _height_rows(data.get("raw_heights"), size.x + 1, size.y + 1, 255):
		return false
	if not _height_rows(data.get("base_heights"), size.x + 1, size.y + 1, Grid.MAX_HEIGHT):
		return false
	var terrain: Variant = data.get("base_terrain")
	if not terrain is Array or terrain.size() != size.y:
		return false
	for row: Variant in terrain:
		if not row is String or row.length() != size.x:
			return false
		for kind: String in row:
			if not "gdwr".contains(kind):
				return false
	var water: Variant = data.get("water_vertices")
	if not water is Array or water.size() != size.y + 1:
		return false
	for row: Variant in water:
		if not row is Array or row.size() != size.x + 1:
			return false
		for flag: Variant in row:
			if not flag is bool and not _whole(flag, 0, 1):
				return false
	if data.has("raw_height_halo"):
		if not _height_rows(data["raw_height_halo"], size.x + 3, size.y + 3, 255):
			return false
		# The optional halo must agree with the whole raw lattice, including
		# clamped border samples. Otherwise edge lighting could use foreign data.
		var halo: Array = data["raw_height_halo"]
		var heights: Array = data["raw_heights"]
		for y: int in range(size.y + 3):
			for x: int in range(size.x + 3):
				if int(halo[y][x]) != int(heights[clampi(y - 1, 0, size.y)][clampi(x - 1, 0, size.x)]):
					return false
	return true


static func _height_rows(value: Variant, width: int, height: int, maximum: int) -> bool:
	if not value is Array or value.size() != height:
		return false
	for row: Variant in value:
		if not row is Array or row.size() != width:
			return false
		for number: Variant in row:
			if not _whole(number, 0, maximum):
				return false
	return true


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
