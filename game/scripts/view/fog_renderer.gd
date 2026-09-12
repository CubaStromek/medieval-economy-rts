extends RefCounted

# Separate retained masks, painted in the same back-to-front ground order as
# terrain. A global overlay would incorrectly blacken a known foreground ridge
# where its projected polygon overlaps an unexplored valley behind it.
const MEMORY_ALPHA: float = 0.32
var mesh_build_count: int = 0
var _meshes: Dictionary = {}
var _row_geometry: Dictionary = {}
var geometry_build_count: int = 0
var _world_id: int = 0
var _grid_id: int = 0
var _fog_id: int = 0
var _fog_revision: int = -1
var _terrain_revision: int = -1
var _enabled: bool = false


func sync(world: Variant, terrain: Variant) -> void:
	if not world.fog.enabled:
		_meshes.clear()
		_enabled = false
		_fog_revision = -1
		return
	var full: bool = not _enabled or _world_id != world.get_instance_id() \
		or _grid_id != world.grid.get_instance_id() or _fog_id != world.fog.get_instance_id()
	if _grid_id != world.grid.get_instance_id():
		_row_geometry.clear()
	_enabled = true
	_world_id = world.get_instance_id()
	_grid_id = world.grid.get_instance_id()
	_fog_id = world.fog.get_instance_id()
	var dirty_rows: Dictionary = {}
	var changed: Dictionary = world.fog.changes_since(-1 if full else _fog_revision)
	full = full or bool(changed["full"])
	if world.grid.revision != _terrain_revision:
		var ground: Dictionary = world.grid.rendering_changes_since(_terrain_revision)
		if bool(ground["full"]):
			full = true
			_row_geometry.clear()
		for cell: Vector2i in ground["terrain"]:
			dirty_rows[cell.y] = true
			_row_geometry.erase(cell.y)
	if full:
		_meshes.clear()
		for row: int in range(world.grid.size.y):
			dirty_rows[row] = true
	else:
		for cell: Vector2i in changed["cells"]:
			dirty_rows[cell.y] = true
	for row: int in dirty_rows:
		_rebuild_row(world, terrain, row)
	_fog_revision = world.fog.revision
	_terrain_revision = world.grid.revision


func draw_row(canvas: CanvasItem, row: int) -> void:
	if _enabled and _meshes.has(row):
		canvas.draw_mesh(_meshes[row], null)


func _rebuild_row(world: Variant, terrain: Variant, row: int) -> void:
	# Sight changes only opacity. Keep projected vertices (including invisible
	# cells) so a simultaneous group movement never re-triangulates entire rows.
	if not _row_geometry.has(row):
		_cache_geometry(world, terrain, row)
	var geometry: Dictionary = _row_geometry[row]
	var points: PackedVector2Array = geometry["points"]
	var counts: PackedInt32Array = geometry["counts"]
	var colors := PackedColorArray()
	colors.resize(points.size())
	var offset: int = 0
	for x: int in range(world.grid.size.x):
		var state: int = world.fog_state(Vector2i(x, row))
		var color := Color(0.0, 0.0, 0.0, 1.0 if state == 0 else (MEMORY_ALPHA if state == 1 else 0.0))
		for index: int in range(counts[x]):
			colors[offset + index] = color
		offset += counts[x]
	_meshes.erase(row)
	if not points.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		_meshes[row] = mesh
	mesh_build_count += 1


func _cache_geometry(world: Variant, terrain: Variant, row: int) -> void:
	var points := PackedVector2Array()
	var counts := PackedInt32Array()
	counts.resize(world.grid.size.x)
	for x: int in range(world.grid.size.x):
		var polygon: PackedVector2Array = terrain.cell_polygon(Vector2i(x, row))
		if polygon.size() != 4:
			continue
		for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector2 = polygon[int(triangle[0])]
			var b: Vector2 = polygon[int(triangle[1])]
			var c: Vector2 = polygon[int(triangle[2])]
			if absf((b - a).cross(c - a)) >= 0.01:
				points.append_array(PackedVector2Array([a, b, c]))
				counts[x] += 3
	_row_geometry[row] = {"points": points, "counts": counts}
	geometry_build_count += 1
