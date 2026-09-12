class_name PaintedTerrainData
extends RefCounted

# CPU presentation data only. The compositor owns the GPU textures; this class
# never changes terrain, collision, source metadata, roads, or saved state.
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Materials = preload("res://scripts/view/modern_terrain_materials.gd")
const HEIGHT_SCALE: float = 0.15
const SOURCE_META: StringName = &"painted_visual_source"
const TERRAIN_CODES: Dictionary = {"grass": "g", "dirt": "d", "water": "w", "rock": "r"}
const CORNERS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]

var low: Image
var high: Image
var light: Image
var weight_scale: float = 2.0
var weight_dimensions: Vector2 = Vector2.ZERO
var source_active: bool = false
var last_error: String = ""
var update_count: int = 0
var weight_write_count: int = 0
var light_write_count: int = 0

var _grid: Grid
var _source: Dictionary = {}
var _kind_weights: Dictionary = {}
var _generic_weights: Dictionary = {}


func configure(grid: Grid) -> bool:
	_grid = grid
	_source = {}
	source_active = false
	last_error = ""
	low = null
	high = null
	light = null
	update_count = 0
	weight_write_count = 0
	light_write_count = 0
	if grid == null or grid.size.x < 1 or grid.size.y < 1 or grid.size.x > 255 or grid.size.y > 255:
		last_error = "Painted terrain requires a grid of 1–255 cells per side."
		return false
	var candidate: Variant = grid.get_meta(SOURCE_META, {})
	if candidate is Dictionary and not candidate.is_empty():
		if _valid_source(candidate):
			_source = candidate
			source_active = true
		else:
			last_error = "Invalid visual terrain metadata; using the map's own terrain materials."
	elif not candidate is Dictionary:
		last_error = "Invalid visual terrain metadata; using the map's own terrain materials."
	for kind: String in "GPRDMWCO":
		_kind_weights[kind] = Materials.kind_weights(kind)
	for terrain_id: String in Grid.BASE_TERRAIN_IDS:
		var channels := PackedFloat32Array()
		channels.resize(8)
		var slot: int = {"grass": 0, "dirt": 3, "water": 5, "rock": 2}[terrain_id]
		channels[slot] = 1.0
		_generic_weights[terrain_id] = channels
	weight_scale = 1.0 if source_active else 2.0
	var dimensions: Vector2i = grid.size * int(weight_scale) + Vector2i.ONE
	weight_dimensions = Vector2(dimensions)
	low = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBAF)
	high = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBAF)
	light = Image.create(grid.size.x + 1, grid.size.y + 1, false, Image.FORMAT_RF)
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			_write_weights(Vector2i(x, y))
	for y: int in range(grid.size.y + 1):
		for x: int in range(grid.size.x + 1):
			_write_light(Vector2i(x, y))
	return true


# Call only for terrain/height invalidations, never surface wear or camera/time.
# A changed height influences its own, eastern, and northern light stencil.
# Work is bounded by the changed cells, not the dimensions of the full map.
func update_terrain(cells: Array[Vector2i]) -> void:
	if _grid == null or low == null or cells.is_empty():
		return
	var weight_points: Dictionary = {}
	var light_points: Dictionary = {}
	var scale: int = int(weight_scale)
	for cell: Vector2i in cells:
		if not _grid.contains(cell):
			continue
		for y: int in range(cell.y * scale, (cell.y + 1) * scale + 1):
			for x: int in range(cell.x * scale, (cell.x + 1) * scale + 1):
				weight_points[Vector2i(x, y)] = true
		for offset: Vector2i in CORNERS:
			var vertex: Vector2i = cell + offset
			for dependency: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.UP]:
				var affected: Vector2i = vertex + dependency
				if _grid.contains_vertex(affected):
					light_points[affected] = true
	if weight_points.is_empty():
		return
	for point: Vector2i in weight_points:
		_write_weights(point)
	for point: Vector2i in light_points:
		_write_light(point)
	update_count += 1


func _write_weights(point: Vector2i) -> void:
	var channels := PackedFloat32Array()
	channels.resize(8)
	var count: int = 0
	# Scale one reconciles source corners exactly like the approved sandbox.
	# Scale two also stores pure cell centers, so a one-cell pool/rock survives
	# the fragment shader's nonlinear sharpening instead of disappearing.
	var scale: int = int(weight_scale)
	var minimum := Vector2i(floori(float(point.x - 1) / scale), floori(float(point.y - 1) / scale))
	var maximum := Vector2i(floori(float(point.x) / scale), floori(float(point.y) / scale))
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, y)
			if not _grid.contains(cell):
				continue
			var incoming: PackedFloat32Array
			if source_active and _matches_source_terrain(cell):
				var corner: Vector2i = point - cell
				var corner_index: int = (0 if corner.x == 0 else 1) if corner.y == 0 else (3 if corner.x == 0 else 2)
				var kinds: String = _source["corner_kinds"][y][x]
				incoming = _kind_weights[kinds[corner_index]]
			else:
				incoming = _generic_weights[_grid.base_terrain_at(cell)]
			for channel: int in range(8):
				channels[channel] += incoming[channel]
			count += 1
	if count > 0:
		for channel: int in range(8):
			channels[channel] /= float(count)
	low.set_pixelv(point, Color(channels[0], channels[1], channels[2], channels[3]))
	high.set_pixelv(point, Color(channels[4], channels[5], channels[6], channels[7]))
	weight_write_count += 1


func _write_light(vertex: Vector2i) -> void:
	var value: float = clampf((2.0 * _height(vertex) - _height(vertex + Vector2i.LEFT) - _height(vertex + Vector2i.DOWN)) / 44.0, -1.0, 1.0)
	if _water_vertex(vertex):
		value = clampf(value * 1.3 + 0.1, -1.0, 1.0)
	light.set_pixelv(vertex, Color(value, 0.0, 0.0, 1.0))
	light_write_count += 1


func _height(vertex: Vector2i) -> float:
	var bounded := Vector2i(clampi(vertex.x, 0, _grid.size.x), clampi(vertex.y, 0, _grid.size.y))
	var current: float = float(_grid.vertex_height(bounded))
	if not source_active:
		return current / HEIGHT_SCALE
	var raw: float = float(_source["raw_heights"][bounded.y][bounded.x])
	if _source.has("raw_height_halo"):
		raw = float(_source["raw_height_halo"][vertex.y + 1][vertex.x + 1])
	var baseline: float = float(_source["base_heights"][bounded.y][bounded.x])
	return raw + (current - baseline) / HEIGHT_SCALE


func _water_vertex(vertex: Vector2i) -> bool:
	var source_unchanged: bool = source_active
	var water: bool = false
	for cell: Vector2i in _grid.cells_touching_vertex(vertex):
		water = water or _grid.base_terrain_at(cell) == "water"
		if source_active and not _matches_source_terrain(cell):
			source_unchanged = false
	if source_unchanged:
		return bool(_source["water_vertices"][vertex.y][vertex.x])
	return water


func _matches_source_terrain(cell: Vector2i) -> bool:
	return TERRAIN_CODES[_grid.base_terrain_at(cell)] == String(_source["base_terrain"][cell.y])[cell.x]


func _valid_source(value: Dictionary) -> bool:
	var dimensions: Variant = value.get("size")
	if not dimensions is Array or dimensions.size() != 2 or not _whole(dimensions[0], 1, 255) or not _whole(dimensions[1], 1, 255):
		return false
	if Vector2i(int(dimensions[0]), int(dimensions[1])) != _grid.size:
		return false
	if not _valid_rows(value.get("corner_kinds"), _grid.size):
		return false
	for row: Array in value["corner_kinds"]:
		for kinds: Variant in row:
			if not kinds is String or kinds.length() != 4:
				return false
			for kind: String in kinds:
				if not "GPRDMWCO".contains(kind):
					return false
	var base: Variant = value.get("base_terrain")
	if not base is Array or base.size() != _grid.size.y:
		return false
	for row: Variant in base:
		if not row is String or row.length() != _grid.size.x:
			return false
		for code: String in row:
			if not "gdwr".contains(code):
				return false
	var vertex_size: Vector2i = _grid.size + Vector2i.ONE
	for field: String in ["raw_heights", "base_heights", "water_vertices"]:
		if not _valid_rows(value.get(field), vertex_size):
			return false
		for row: Array in value[field]:
			for entry: Variant in row:
				if field == "water_vertices":
					if not entry is bool and not _whole(entry, 0, 1):
						return false
				elif not _whole(entry, 0, 255 if field == "raw_heights" else Grid.MAX_HEIGHT):
					return false
	if value.has("raw_height_halo"):
		if not _valid_rows(value["raw_height_halo"], _grid.size + Vector2i(3, 3)):
			return false
		for row: Array in value["raw_height_halo"]:
			for entry: Variant in row:
				if not _whole(entry, 0, 255):
					return false
	return true


static func _valid_rows(value: Variant, dimensions: Vector2i) -> bool:
	if not value is Array or value.size() != dimensions.y:
		return false
	for row: Variant in value:
		if not row is Array or row.size() != dimensions.x:
			return false
	return true


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
