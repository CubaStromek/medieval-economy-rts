class_name TerrainRenderer
extends Node2D

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const PaintedTerrainLibraryClass = preload("res://scripts/view/painted_terrain_library.gd")
const PaintedTerrainCompositorClass = preload("res://scripts/view/painted_terrain_compositor.gd")

const VARIANT_TINTS: Array[float] = [0.975, 1.0, 1.025]
const TRANSITION_WIDTH: float = 0.14
const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1),
]
const UV_CORNERS := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
const INVALID_CELL := Vector2i(-1, -1)
const STONE_ROAD_TEXTURE_PATH: String = "res://art/environment/stone-road-basic-v1.png"
const ROAD_TEXTURE_SPAN: float = 2.0
const ROAD_SEGMENTS: int = 3
const INVISIBLE_TRAFFIC_PASSES: int = 3
const TRACE_MAX_OPACITY: float = 0.78
# Readability controls: real-height contour accents, not steps in geometry.
const CONTOUR_INTERVAL: float = 1.0
const CONTOUR_STEEP_INTERVAL: float = 2.0
const CONTOUR_OFFSET: float = 0.5
const CONTOUR_HALF_WIDTH_UV: float = 0.022
const CONTOUR_DARK_ALPHA: float = 0.30
const CONTOUR_LIGHT_ALPHA: float = 0.17
const SLOPE_NORMAL_STRENGTH: float = 0.70

var grid: GridMapSimClass
# Scenes opt in; bare renderers and the sandbox's historical four-material
# baseline deliberately retain their previous appearance.
@export var use_painted_terrain: bool = false:
	set(value):
		if use_painted_terrain == value:
			return
		use_painted_terrain = value
		if grid != null:
			rebuild()
# Retained terrain rows interleave with MainView's dynamic object rows. An
# opaque foreground ridge still hides the lower half of a worker behind it.
var external_painter: bool = false:
	set(value):
		if external_painter == value:
			return
		external_painter = value
		if grid != null:
			_sync_row_canvases()
			_redraw_rows()
var show_passability: bool = false:
	set(value):
		if show_passability == value:
			return
		show_passability = value
		_redraw_rows()
var show_buildability: bool = false:
	set(value):
		if show_buildability == value:
			return
		show_buildability = value
		_redraw_rows()
# Gold hatching means earthwork may be possible for a building, never a
# blanket approval of its full footprint. Fields retain flat-ground rules.
var allow_ground_preparation: bool = false:
	set(value):
		if allow_ground_preparation == value:
			return
		allow_ground_preparation = value
		if show_buildability:
			_redraw_rows()
var _textures: Dictionary = {}
var _painted_tints: Dictionary = {}
var _painted_compositor: PaintedTerrainCompositorClass
var _cells: Dictionary = {}
var _row_batches: Dictionary = {}
var _row_canvases: Dictionary = {}
var _invalidated_cells: Dictionary = {}
var _bounds := Rect2()
var _last_revision: int = -1
var _last_definition_revision: int = -1
var geometry_build_count: int = 0
var base_cell_build_count: int = 0
var surface_cell_build_count: int = 0
var row_mesh_build_count: int = 0
var row_draw_count: int = 0


func bind_grid(value: GridMapSimClass) -> void:
	grid = value
	_last_revision = -1
	_last_definition_revision = -1
	_cells.clear()
	_row_batches.clear()
	_invalidated_cells.clear()
	if grid == null:
		_painted_compositor = null
		_sync_row_canvases()
	_ensure_cache()
	queue_redraw()


func rebuild() -> void:
	_last_revision = -1
	_last_definition_revision = -1
	_ensure_cache()
	queue_redraw()


func painted_available() -> bool:
	return PaintedTerrainLibraryClass.available()


func painted_mode_active() -> bool:
	return use_painted_terrain and grid != null and _painted_compositor != null


func invalidate_cell(cell: Vector2i) -> void:
	if grid != null and grid.contains(cell):
		_invalidated_cells[cell] = true
	queue_redraw()


func cell_center(cell: Vector2i) -> Vector2:
	return project_grid_position(Vector2(cell))


func project_grid_position(position: Vector2) -> Vector2:
	var height: float = 0.0 if grid == null else grid.height_at(position + Vector2(0.5, 0.5))
	return MapProjectionClass.project_grid_position(position, height)


func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	_ensure_cache()
	if not _cells.has(cell):
		return PackedVector2Array()
	return (_cells[cell] as Dictionary)["polygon"] as PackedVector2Array


# Compatibility for callers needing a label/hit-test extent, not ground shape.
# Ground drawing must use cell_polygon or the triangle-based painter instead.
func cell_rect(cell: Vector2i) -> Rect2:
	_ensure_cache()
	if not _cells.has(cell):
		return Rect2()
	return (_cells[cell] as Dictionary)["bounds"] as Rect2


func pick_cell(local_position: Vector2) -> Vector2i:
	_ensure_cache()
	if grid == null:
		return INVALID_CELL
	# Reverse the exact painter order. Heights can fold a steep rock face over
	# several earlier rows, so the flat inverse alone cannot identify a click.
	var column: int = floori(local_position.x / MapProjectionClass.CELL_SIZE.x)
	if column < 0 or column >= grid.size.x:
		return INVALID_CELL
	for y: int in range(grid.size.y - 1, -1, -1):
		var cell := Vector2i(column, y)
		if _cell_contains_point(cell, local_position):
			return cell
	return INVALID_CELL


func point_occluded(screen_position: Vector2, ground_position: Vector2) -> bool:
	_ensure_cache()
	if grid == null:
		return false
	var column: int = floori(screen_position.x / MapProjectionClass.CELL_SIZE.x)
	if column < 0 or column >= grid.size.x:
		return false
	# Objects are painted after the terrain in their own ground row. Their
	# screen Y is deliberately not a depth key: high mountains rise behind them.
	var ground_row: int = floori(ground_position.y + 0.5)
	for y: int in range(grid.size.y - 1, ground_row, -1):
		if _cell_contains_point(Vector2i(column, y), screen_position):
			return true
	return false


func map_bounds() -> Rect2:
	_ensure_cache()
	return _bounds


# Terrain-only placement guidance; MainView still checks the selected building,
# entrances and live economy rules before displaying its precise hover result.
func buildability_state(cell: Vector2i) -> String:
	if grid == null or not grid.contains(cell) or not grid.is_walkable(cell):
		return "blocked"
	if grid.cell_slope(cell) > GridMapSimClass.MAX_BUILD_SLOPE:
		return "slope"
	return "level" if grid.is_buildable(cell) else "blocked"


func buildability_guidance(cell: Vector2i) -> String:
	var state: String = buildability_state(cell)
	if state == "slope" and allow_ground_preparation and grid.cell_slope(cell) <= 2 \
			and bool(grid.terrain_definition(grid.base_terrain_at(cell)).get("buildable", false)):
		return "preparable"
	return state


func transition_mask_for(cell: Vector2i) -> int:
	if grid == null or not grid.contains(cell):
		return 0
	var current_id: String = grid.base_terrain_at(cell)
	var current_priority: int = _transition_priority(current_id)
	var mask: int = 0
	for index: int in range(GridMapSimClass.CARDINAL_DIRECTIONS.size()):
		var neighbor: Vector2i = cell + GridMapSimClass.CARDINAL_DIRECTIONS[index]
		if not grid.contains(neighbor):
			continue
		var neighbor_id: String = grid.base_terrain_at(neighbor)
		if neighbor_id != current_id and _transition_priority(neighbor_id) > current_priority:
			mask |= 1 << index
	return mask


# Follow the simulation's recorded traffic edges. Player-built stone pairs
# connect automatically; neighboring dirt alone is not evidence of a route.
func surface_connection_mask_for(cell: Vector2i) -> int:
	if grid == null or not grid.contains(cell) or grid.overlay_at(cell).is_empty():
		return 0
	var mask: int = 0
	for index: int in range(GridMapSimClass.CARDINAL_DIRECTIONS.size()):
		var neighbor: Vector2i = cell + GridMapSimClass.CARDINAL_DIRECTIONS[index]
		if grid.contains(neighbor) and not grid.overlay_at(neighbor).is_empty() and grid.can_traverse(cell, neighbor) and grid.trail_connection_active(cell, neighbor):
			mask |= 1 << index
	return mask


func diagonal_surface_connection_mask_for(cell: Vector2i) -> int:
	if grid == null or not grid.contains(cell) or grid.overlay_at(cell).is_empty():
		return 0
	var mask: int = 0
	for index: int in range(DIAGONAL_DIRECTIONS.size()):
		var neighbor: Vector2i = cell + DIAGONAL_DIRECTIONS[index]
		if not grid.overlay_at(neighbor).is_empty() and grid.can_traverse(cell, neighbor) and grid.trail_connection_active(cell, neighbor):
			mask |= 1 << index
	return mask


func surface_edge_half_width(cell: Vector2i, direction: Vector2i) -> float:
	if grid == null or not grid.contains(cell) or (
		direction not in GridMapSimClass.CARDINAL_DIRECTIONS and direction not in DIAGONAL_DIRECTIONS):
		return 0.0
	var neighbor: Vector2i = cell + direction
	if not grid.can_traverse(cell, neighbor) or grid.overlay_at(cell).is_empty() or grid.overlay_at(neighbor).is_empty() or not grid.trail_connection_active(cell, neighbor):
		return 0.0
	var width: float = _connection_half_width_for(cell, neighbor)
	var edge: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) + Vector2(direction) * 0.5
	return width + _road_width_jitter(edge)


func corner_transition_id_for(cell: Vector2i, diagonal: Vector2i) -> String:
	if grid == null or not grid.contains(cell) or absi(diagonal.x) != 1 or absi(diagonal.y) != 1:
		return ""
	var neighbor: Vector2i = cell + diagonal
	if not grid.contains(neighbor):
		return ""
	var current_id: String = grid.base_terrain_at(cell)
	var neighbor_id: String = grid.base_terrain_at(neighbor)
	var neighbor_priority: int = _transition_priority(neighbor_id)
	if neighbor_id == current_id or neighbor_priority <= _transition_priority(current_id):
		return ""
	var horizontal_id: String = grid.base_terrain_at(cell + Vector2i(diagonal.x, 0))
	var vertical_id: String = grid.base_terrain_at(cell + Vector2i(0, diagonal.y))
	if horizontal_id == neighbor_id or vertical_id == neighbor_id:
		return ""
	if maxi(_transition_priority(horizontal_id), _transition_priority(vertical_id)) >= neighbor_priority:
		return ""
	return neighbor_id


func _process(_delta: float) -> void:
	_ensure_cache()


func _draw() -> void:
	if grid == null or external_painter:
		return
	for y: int in range(grid.size.y):
		paint_row(self, y)


func paint_row(canvas: CanvasItem, row: int) -> void:
	_ensure_cache()
	if not _row_batches.has(row):
		return
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	canvas.material = _painted_compositor.shader_material if painted_mode_active() else null
	# Different columns have disjoint projected X intervals. Base/surface can
	# be separate layers within a row, but never reorder triangles by texture:
	# transparent shoulders/transitions rely on their original painter order.
	for layer: String in ["base", "surface"]:
		for batch: Dictionary in _row_batches[row][layer]:
			canvas.draw_mesh(batch["mesh"] as ArrayMesh, batch["texture"] as Texture2D,
				Transform2D.IDENTITY, batch["modulate"] as Color)
	if show_passability:
		for x: int in range(grid.size.x):
			_paint_passability(canvas, Vector2i(x, row))
	if show_buildability:
		for x: int in range(grid.size.x):
			_paint_buildability(canvas, Vector2i(x, row))
	row_draw_count += 1


func _sync_row_canvases() -> void:
	var terrain_material: ShaderMaterial = _painted_compositor.shader_material if painted_mode_active() else null
	material = terrain_material
	for row: int in _row_canvases.keys():
		if grid == null or not external_painter or row >= grid.size.y:
			var obsolete: Node2D = _row_canvases[row]
			remove_child(obsolete)
			obsolete.free()
			_row_canvases.erase(row)
	if grid == null or not external_painter:
		return
	# The scene's old -100 offset would put every terrain row behind workers.
	z_index = 0
	for row: int in range(grid.size.y):
		if _row_canvases.has(row):
			(_row_canvases[row] as Node2D).material = terrain_material
			continue
		var canvas := Node2D.new()
		canvas.name = "TerrainRow_%d" % row
		canvas.z_index = row * 2
		canvas.material = terrain_material
		canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		canvas.draw.connect(paint_row.bind(canvas, row))
		add_child(canvas)
		_row_canvases[row] = canvas


func _redraw_rows() -> void:
	queue_redraw()
	for canvas: Node2D in _row_canvases.values():
		canvas.queue_redraw()


func paint_cell(canvas: CanvasItem, cell: Vector2i) -> void:
	# The external row painter owns the actual CanvasItem, not this child node.
	# Repeat also preserves the original 0..1 terrain texture sampling.
	if canvas.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ensure_cache()
	if not _cells.has(cell):
		return
	canvas.material = _painted_compositor.shader_material if painted_mode_active() else null
	for command: Dictionary in (_cells[cell] as Dictionary)["draws"] as Array:
		canvas.draw_polygon(
			command["points"] as PackedVector2Array,
			command["colors"] as PackedColorArray,
			command["texture_uvs"] as PackedVector2Array,
			command["texture"] as Texture2D
		)
	if show_passability:
		_paint_passability(canvas, cell)
	if show_buildability:
		_paint_buildability(canvas, cell)


func _paint_buildability(canvas: CanvasItem, cell: Vector2i) -> void:
	var state: String = buildability_guidance(cell)
	if state == "level":
		return
	var slope: bool = state == "preparable" or (state == "slope" and not allow_ground_preparation)
	var tint := Color(0.92, 0.61, 0.18, 0.10) if slope else Color(0.34, 0.18, 0.14, 0.13)
	var hatch := Color(1.0, 0.70, 0.27, 0.45) if slope else Color(0.79, 0.33, 0.24, 0.42)
	var outline := Color(0.95, 0.65, 0.22, 0.50) if slope else Color(0.20, 0.14, 0.11, 0.64)
	var polygon: PackedVector2Array = _cells[cell]["polygon"]
	_paint_cell_tint(canvas, polygon, tint)
	# Each hatch bends at the same diagonal as the terrain, including twisted
	# cells. Drawing these only on retained-row invalidation keeps idle frames cheap.
	for index: int in range(5):
		var diagonal: float = 0.25 + float(index) * 0.35
		var low: float = maxf(0.0, diagonal - 1.0)
		var high: float = minf(1.0, diagonal)
		var points := PackedVector2Array([
			_project_cell_uv(cell, Vector2(low, high)),
			_project_cell_uv(cell, Vector2(diagonal * 0.5, diagonal * 0.5)),
			_project_cell_uv(cell, Vector2(high, low)),
		])
		canvas.draw_polyline(points, hatch, 1.2, true)
	var border := PackedVector2Array(polygon)
	border.append(border[0])
	canvas.draw_polyline(border, outline, 1.0, true)


func _paint_passability(canvas: CanvasItem, cell: Vector2i) -> void:
	var tint := Color(0.42, 0.9, 0.49, 0.12)
	if not grid.is_walkable(cell):
		tint = Color(0.95, 0.22, 0.18, 0.33)
	elif grid.cell_slope(cell) > 0:
		tint = Color(1.0, 0.72, 0.2, 0.24)
	var polygon: PackedVector2Array = _cells[cell]["polygon"]
	_paint_cell_tint(canvas, polygon, tint)


static func _paint_cell_tint(canvas: CanvasItem, polygon: PackedVector2Array, tint: Color) -> void:
	# A five-height rise is exactly edge-on at 40px cells / 8px height units.
	# Its invisible triangle must not reach Godot's polygon triangulator.
	for index: int in [1, 2]:
		var triangle := PackedVector2Array([polygon[0], polygon[index], polygon[index + 1]])
		if absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.0001:
			canvas.draw_colored_polygon(triangle, tint)


func _ensure_cache() -> void:
	if grid == null:
		_bounds = Rect2()
		return
	var compositor_configured: bool = false
	if grid.definition_revision != _last_definition_revision:
		_rebuild_texture_cache()
		compositor_configured = painted_mode_active()
		_last_definition_revision = grid.definition_revision
		_last_revision = -1
	if grid.revision == _last_revision and _invalidated_cells.is_empty():
		return
	var changes: Dictionary = grid.rendering_changes_since(_last_revision)
	var full: bool = bool(changes["full"]) or _cells.is_empty()
	var base_dirty: Dictionary = {}
	var surface_dirty: Dictionary = {}
	if full:
		_cells.clear()
		_row_batches.clear()
		for y: int in range(grid.size.y):
			for x: int in range(grid.size.x):
				base_dirty[Vector2i(x, y)] = true
		_sync_row_canvases()
	else:
		for cell: Vector2i in changes["terrain"]:
			_expand_dirty(base_dirty, cell, true)
		for cell: Vector2i in changes["surface"]:
			# A diagonal joins at a shared corner and has clipped shoulders in
			# both side cells. Occupying either side also removes the connection.
			_expand_dirty(surface_dirty, cell, true)
		for cell: Vector2i in _invalidated_cells:
			_expand_dirty(base_dirty, cell, true)
	# Terrain weights and smooth vertex lighting follow only base changes.
	# Traffic and paved-road edits must not re-upload ground data.
	if painted_mode_active() and not compositor_configured and not base_dirty.is_empty():
		var changed_ground: Array[Vector2i] = []
		changed_ground.assign(base_dirty.keys())
		_painted_compositor.update_terrain(changed_ground)
	var base_rows: Dictionary = {}
	var surface_rows: Dictionary = {}
	for cell: Vector2i in base_dirty:
		_build_base_cell(cell)
		surface_dirty[cell] = true
		base_rows[cell.y] = true
	for cell: Vector2i in surface_dirty:
		var commands: Array[Dictionary] = []
		_append_surface(commands, cell)
		_cells[cell]["surface_draws"] = commands
		_cells[cell]["draws"] = _cells[cell]["base_draws"] + commands
		surface_cell_build_count += 1
		surface_rows[cell.y] = true
	for row: int in base_rows:
		_build_row_layer(row, "base")
	for row: int in surface_rows:
		_build_row_layer(row, "surface")
		if _row_canvases.has(row):
			(_row_canvases[row] as Node2D).queue_redraw()
	if full or not base_dirty.is_empty():
		_rebuild_bounds()
	_invalidated_cells.clear()
	_last_revision = grid.revision
	geometry_build_count += 1
	if not external_painter:
		queue_redraw()


func _expand_dirty(dirty: Dictionary, cell: Vector2i, diagonals: bool) -> void:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not diagonals and absi(dx) + absi(dy) > 1:
				continue
			var neighbor: Vector2i = cell + Vector2i(dx, dy)
			if grid.contains(neighbor):
				dirty[neighbor] = true


func _build_base_cell(cell: Vector2i) -> void:
	var polygon := PackedVector2Array()
	for offset: Vector2 in UV_CORNERS:
		var vertex: Vector2i = cell + Vector2i(offset)
		polygon.append(MapProjectionClass.corner_position(vertex, grid.vertex_height(vertex)))
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	var commands: Array[Dictionary] = []
	var terrain_id: String = grid.base_terrain_at(cell)
	var tint: float = 1.0 if painted_mode_active() else VARIANT_TINTS[grid.visual_variant_at(cell, VARIANT_TINTS.size())]
	_append_base_polygon(commands, cell, PackedVector2Array(UV_CORNERS),
		Color(tint, tint, tint), terrain_id)
	if not painted_mode_active():
		# V1 blends the shared material field and interpolates corner lighting
		# in its shader. Legacy strips/contours would paint over that result.
		_append_transitions(commands, cell)
		_append_slope_contours(commands, cell)
	_cells[cell] = {"polygon": polygon, "bounds": bounds, "base_draws": commands}
	base_cell_build_count += 1


# Clip narrow bands at true height levels against each existing terrain
# triangle. Shared edge heights yield continuous contours across cell borders;
# a flat plateau receives none. Keeping them in base_draws leaves roads on top.
func _append_slope_contours(commands: Array[Dictionary], cell: Vector2i) -> void:
	if grid.base_terrain_at(cell) not in ["grass", "dirt"] or grid.cell_slope(cell) == 0:
		return
	var heights: PackedInt32Array = grid.cell_corner_heights(cell)
	for half: int in range(2):
		var upper: bool = half == 0
		var triangle := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE]) if upper else PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2.DOWN])
		var dx: float = float(heights[1] - heights[0]) if upper else float(heights[2] - heights[3])
		var dy: float = float(heights[2] - heights[1]) if upper else float(heights[3] - heights[0])
		var gradient: float = Vector2(dx, dy).length()
		if is_zero_approx(gradient):
			continue
		var minimum: float = minf(float(heights[0]), minf(float(heights[2]), float(heights[1] if upper else heights[3])))
		var maximum: float = maxf(float(heights[0]), maxf(float(heights[2]), float(heights[1] if upper else heights[3])))
		var half_width: float = clampf(gradient * CONTOUR_HALF_WIDTH_UV, 0.025, 0.20)
		var interval: float = CONTOUR_INTERVAL if gradient <= 3.0 else CONTOUR_STEEP_INTERVAL
		var first: int = ceili((minimum - half_width * 2.0 - CONTOUR_OFFSET) / interval)
		var last: int = floori((maximum + half_width - CONTOUR_OFFSET) / interval)
		for step: int in range(first, last + 1):
			var height: float = float(step) * interval + CONTOUR_OFFSET
			_append_height_band(commands, cell, triangle, float(heights[0]), dx, dy,
				height - half_width, height + half_width,
				Color(0.17, 0.22, 0.12, CONTOUR_DARK_ALPHA), "slope_contour")
			_append_height_band(commands, cell, triangle, float(heights[0]), dx, dy,
				height + half_width, height + half_width * 2.0,
				Color(0.72, 0.76, 0.49, CONTOUR_LIGHT_ALPHA), "slope_contour_highlight")


func _append_height_band(commands: Array[Dictionary], cell: Vector2i,
		triangle: PackedVector2Array, origin_height: float, dx: float, dy: float,
		low: float, high: float, color: Color, layer: String) -> void:
	var clipped: PackedVector2Array = _clip_height(triangle, origin_height, dx, dy, low, true)
	clipped = _clip_height(clipped, origin_height, dx, dy, high, false)
	if clipped.size() >= 3:
		_append_uv_polygon(commands, cell, clipped, color, null, 0.0, layer)


static func _clip_height(points: PackedVector2Array, origin_height: float,
		dx: float, dy: float, level: float, keep_above: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty():
		return result
	var sign_value: float = 1.0 if keep_above else -1.0
	var previous: Vector2 = points[points.size() - 1]
	var previous_distance: float = (origin_height + dx * previous.x + dy * previous.y - level) * sign_value
	for current: Vector2 in points:
		var distance: float = (origin_height + dx * current.x + dy * current.y - level) * sign_value
		var inside: bool = distance >= 0.0
		var previous_inside: bool = previous_distance >= 0.0
		if inside != previous_inside:
			result.append(previous.lerp(current, previous_distance / (previous_distance - distance)))
		if inside and (result.is_empty() or not result[result.size() - 1].is_equal_approx(current)):
			result.append(current)
		previous = current
		previous_distance = distance
	if result.size() > 1 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


func _build_row_layer(row: int, layer: String) -> void:
	var commands: Array[Dictionary] = []
	for x: int in range(grid.size.x):
		commands.append_array(_cells[Vector2i(x, row)][layer + "_draws"])
	if not _row_batches.has(row):
		_row_batches[row] = {"base": [], "surface": []}
	_row_batches[row][layer] = _batch_commands(commands)
	row_mesh_build_count += 1


func _batch_commands(commands: Array[Dictionary]) -> Array[Dictionary]:
	var batches: Array[Dictionary] = []
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var texture: Texture2D
	for command: Dictionary in commands:
		var next_texture: Texture2D = command["texture"] as Texture2D
		if not points.is_empty() and texture != next_texture:
			batches.append(_make_batch(points, colors, uvs, texture))
			points = PackedVector2Array()
			colors = PackedColorArray()
			uvs = PackedVector2Array()
		texture = next_texture
		points.append_array(command["points"])
		uvs.append_array(command["texture_uvs"])
		var command_colors: PackedColorArray = command["colors"] as PackedColorArray
		for vertex: int in range((command["points"] as PackedVector2Array).size()):
			colors.append(command_colors[0] if command_colors.size() == 1 else command_colors[vertex])
	if not points.is_empty():
		batches.append(_make_batch(points, colors, uvs, texture))
	return batches


func _make_batch(points: PackedVector2Array, colors: PackedColorArray,
		uvs: PackedVector2Array, texture: Texture2D) -> Dictionary:
	# ArrayMesh packs colors into UNORM8. Move HDR slope/road brightness into
	# the float modulation instead of clipping every component above 1.0.
	var brightness: float = 1.0
	for color: Color in colors:
		brightness = maxf(brightness, maxf(color.r, maxf(color.g, color.b)))
	var normalized_colors := PackedColorArray()
	for color: Color in colors:
		normalized_colors.append(Color(color.r / brightness, color.g / brightness, color.b / brightness, color.a))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = normalized_colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return {"mesh": mesh, "texture": texture, "modulate": Color(brightness, brightness, brightness, 1.0)}


func _rebuild_bounds() -> void:
	var first_vertex: Vector2 = MapProjectionClass.corner_position(Vector2i.ZERO, grid.vertex_height(Vector2i.ZERO))
	_bounds = Rect2(first_vertex, Vector2.ZERO)
	for y: int in range(grid.size.y + 1):
		for x: int in range(grid.size.x + 1):
			var vertex := Vector2i(x, y)
			_bounds = _bounds.expand(MapProjectionClass.corner_position(vertex, grid.vertex_height(vertex)))


func _append_transitions(commands: Array[Dictionary], cell: Vector2i) -> void:
	var mask: int = transition_mask_for(cell)
	var transitions: Array[Dictionary] = []
	for index: int in range(GridMapSimClass.CARDINAL_DIRECTIONS.size()):
		if (mask & (1 << index)) != 0:
			var direction: Vector2i = GridMapSimClass.CARDINAL_DIRECTIONS[index]
			var terrain_id: String = grid.base_terrain_at(cell + direction)
			transitions.append({"index": index, "id": terrain_id, "priority": _transition_priority(terrain_id)})
	transitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) < int(b["priority"]) or (
			int(a["priority"]) == int(b["priority"]) and int(a["index"]) < int(b["index"]))
	)
	for transition: Dictionary in transitions:
		var terrain_id: String = String(transition["id"])
		var index: int = int(transition["index"])
		for band: int in range(3):
			var outer: float = float(band) * TRANSITION_WIDTH * 0.55
			var inner: float = outer + TRANSITION_WIDTH * 0.65
			var strip: PackedVector2Array
			match index:
				0: strip = _uv_rect(0.0, outer, 1.0, inner)
				1: strip = _uv_rect(1.0 - inner, 0.0, 1.0 - outer, 1.0)
				2: strip = _uv_rect(0.0, 1.0 - inner, 1.0, 1.0 - outer)
				_: strip = _uv_rect(outer, 0.0, inner, 1.0)
			var alpha: float = [0.58, 0.28, 0.10][band]
			_append_base_polygon(commands, cell, strip, Color(1, 1, 1, alpha), terrain_id)
	for diagonal: Vector2i in DIAGONAL_DIRECTIONS:
		var terrain_id: String = corner_transition_id_for(cell, diagonal)
		if terrain_id.is_empty():
			continue
		var corner := Vector2(0.0 if diagonal.x < 0 else 1.0, 0.0 if diagonal.y < 0 else 1.0)
		var corner_points := PackedVector2Array([
			corner, corner - Vector2(diagonal.x * 0.24, 0.0), corner - Vector2(0.0, diagonal.y * 0.24)])
		_append_base_polygon(commands, cell, corner_points, Color(1, 1, 1, 0.45), terrain_id)


# V1 ground uses the complete atlas and shared compositor. Surface roads,
# trails, wear and guidance retain their original textures and untagged UVs.
func _append_base_polygon(commands: Array[Dictionary], cell: Vector2i,
		uv_points: PackedVector2Array, color: Color, terrain_id: String) -> void:
	var painted: bool = painted_mode_active()
	var texture: Texture2D = _painted_compositor.atlas if painted else _textures.get(terrain_id) as Texture2D
	var tint: Color = _painted_tints.get(terrain_id, Color.WHITE) as Color if painted else color
	_append_uv_polygon(commands, cell, uv_points, tint, texture, 0.0, "terrain", painted)


func _append_surface(commands: Array[Dictionary], cell: Vector2i) -> void:
	var overlay_id: String = grid.overlay_at(cell)
	var dirt_texture: Texture2D = _textures.get("dirt") as Texture2D
	if overlay_id.is_empty():
		var wear: int = grid.traffic_wear_at(cell)
		if wear > INVISIBLE_TRAFFIC_PASSES:
			_append_uv_polygon(commands, cell, _organic_disc(cell, _trace_radius_for(wear)),
				Color(0.91, 0.86, 0.74, _trace_opacity_for(wear)), dirt_texture, ROAD_TEXTURE_SPAN, "wear")
	var diagonal_halves: Array[Dictionary] = _diagonal_surface_halves_for(cell)
	if overlay_id.is_empty() and diagonal_halves.is_empty():
		return
	# Full connected footprints are drawn once per layer. The opaque core hides
	# their internal overlaps, so every tile does not acquire a circular stamp.
	for pass_index: int in range(3):
		if not overlay_id.is_empty():
			var style: Dictionary = _surface_layer_style(cell, pass_index)
			_append_surface_layer(commands, cell, pass_index, style["color"], style["texture"], style["layer"])
		for half: Dictionary in diagonal_halves:
			var source: Vector2i = half["source"]
			var style: Dictionary = _surface_layer_style(source, pass_index)
			_append_diagonal_surface_half(commands, cell, source, half["direction"], pass_index, style)


func _surface_layer_style(cell: Vector2i, pass_index: int) -> Dictionary:
	var stone: bool = grid.overlay_at(cell) == GridMapSimClass.OVERLAY_STONE_ROAD
	var opacity: float = _surface_opacity_for(cell)
	if pass_index == 0:
		return {"color": Color(0.80, 0.76, 0.65, 0.22 * opacity), "texture": _textures["dirt"], "layer": "shoulder_outer"}
	if pass_index == 1:
		return {"color": Color(0.83, 0.78, 0.67, 0.48 * opacity), "texture": _textures["dirt"], "layer": "shoulder_inner"}
	if stone:
		return {"color": Color.WHITE, "texture": _textures[GridMapSimClass.OVERLAY_STONE_ROAD], "layer": "road_core"}
	return {"color": Color(1.03, 0.94, 0.80, opacity), "texture": _textures["dirt"], "layer": "trail_core"}


func _trace_ratio_for(wear: int) -> float:
	# The first few one-off trips leave grass visually untouched. There is no
	# fixed opacity floor: increasing the formation threshold keeps rare use faint.
	return clampf(float(wear - INVISIBLE_TRAFFIC_PASSES)
		/ float(maxi(1, grid.carrier_passes_to_form_trail() - INVISIBLE_TRAFFIC_PASSES)), 0.0, 1.0)


func _trace_opacity_for(wear: int) -> float:
	var ratio: float = _trace_ratio_for(wear)
	return TRACE_MAX_OPACITY * ratio * ratio


func _trace_radius_for(wear: int) -> float:
	return lerpf(0.045, 0.135, _trace_ratio_for(wear))


func _trail_maturity_for(cell: Vector2i) -> float:
	return _maturity_for_wear(grid.traffic_wear_at(cell))


func _maturity_for_wear(wear: int) -> float:
	var retention: int = grid.trail_retention_passes()
	var formation: int = grid.carrier_passes_to_form_trail()
	if formation <= retention:
		return 1.0
	return smoothstep(float(retention), float(formation), float(wear))


func _surface_opacity_for(cell: Vector2i) -> float:
	if grid.overlay_at(cell) == GridMapSimClass.OVERLAY_STONE_ROAD:
		return 1.0
	return lerpf(_trace_opacity_for(grid.trail_retention_passes()), 1.0, _trail_maturity_for(cell))


func _surface_half_width_for(cell: Vector2i) -> float:
	if grid.overlay_at(cell) == GridMapSimClass.OVERLAY_STONE_ROAD:
		return 0.23
	return lerpf(_trace_radius_for(grid.trail_retention_passes()), 0.145, _trail_maturity_for(cell))


func _surface_expansion_for(cell: Vector2i, pass_index: int) -> float:
	if grid.overlay_at(cell) == GridMapSimClass.OVERLAY_STONE_ROAD:
		return [0.09, 0.045, 0.0][pass_index]
	return [0.055, 0.0275, 0.0][pass_index] * lerpf(0.35, 1.0, _trail_maturity_for(cell))


func _connection_maturity_for(from: Vector2i, to: Vector2i) -> float:
	if grid.roads.has(from) and grid.roads.has(to):
		return 1.0
	var link: Dictionary = grid.trail_links.get(GridMapSimClass.trail_link_key(from, to), {})
	return _maturity_for_wear(int(link.get("wear", 0)))


func _connection_half_width_for(from: Vector2i, to: Vector2i) -> float:
	var width: float = minf(_surface_half_width_for(from), _surface_half_width_for(to))
	if grid.roads.has(from) and grid.roads.has(to):
		return width
	var link_width: float = lerpf(_trace_radius_for(grid.trail_retention_passes()), 0.145, _connection_maturity_for(from, to))
	return minf(width, link_width)


func _connection_expansion_for(from: Vector2i, to: Vector2i, pass_index: int) -> float:
	var expansion: float = minf(_surface_expansion_for(from, pass_index), _surface_expansion_for(to, pass_index))
	if grid.roads.has(from) and grid.roads.has(to):
		return expansion
	var link_expansion: float = [0.055, 0.0275, 0.0][pass_index] * lerpf(0.35, 1.0, _connection_maturity_for(from, to))
	return minf(expansion, link_expansion)


func _connection_opacity_factor(from: Vector2i, to: Vector2i) -> float:
	if grid.roads.has(from) and grid.roads.has(to):
		return 1.0
	# A disused branch fades even when traffic on other routes keeps both
	# junction cells mature. Avoid multiplying cell and link fading twice.
	var link_opacity: float = lerpf(_trace_opacity_for(grid.trail_retention_passes()), 1.0, _connection_maturity_for(from, to))
	return minf(1.0, link_opacity / maxf(0.0001, _surface_opacity_for(from)))


func _diagonal_surface_halves_for(cell: Vector2i) -> Array[Dictionary]:
	var halves: Array[Dictionary] = []
	# A half-strip ends at a shared corner. Its width extends into the two
	# cardinal side cells, but never into the opposite diagonal endpoint cell.
	var sources: Array[Vector2i] = [cell]
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		sources.append(cell + direction)
	for source: Vector2i in sources:
		var mask: int = diagonal_surface_connection_mask_for(source)
		for index: int in range(DIAGONAL_DIRECTIONS.size()):
			if (mask & (1 << index)) == 0:
				continue
			var direction: Vector2i = DIAGONAL_DIRECTIONS[index]
			if source == cell or source + Vector2i(direction.x, 0) == cell or source + Vector2i(0, direction.y) == cell:
				halves.append({"source": source, "direction": direction})
	return halves


func _append_diagonal_surface_half(commands: Array[Dictionary], cell: Vector2i,
		source: Vector2i, direction: Vector2i, pass_index: int, style: Dictionary) -> void:
	var along := Vector2(direction)
	var across := Vector2(-direction.y, direction.x).normalized()
	var center: Vector2 = Vector2(source - cell) + Vector2(0.5, 0.5)
	var color: Color = style["color"]
	color.a *= _connection_opacity_factor(source, source + direction)
	for segment: int in range(ROAD_SEGMENTS):
		var start: float = float(segment) / float(ROAD_SEGMENTS)
		var end: float = float(segment + 1) / float(ROAD_SEGMENTS)
		var start_center: Vector2 = center + along * (start * 0.5)
		var end_center: Vector2 = center + along * (end * 0.5)
		var start_width: float = _surface_layer_width(source, direction, start, pass_index)
		var end_width: float = _surface_layer_width(source, direction, end, pass_index)
		var points := PackedVector2Array([
			start_center + across * start_width, end_center + across * end_width,
			end_center - across * end_width, start_center - across * start_width])
		# Draw each fragment on its actual ground cell, then split by that
		# cell's terrain diagonal. No floating geometry or later-row clipping.
		points = _clip_unit_square(points)
		if points.size() >= 3:
			_append_uv_polygon(commands, cell, points, color, style["texture"], ROAD_TEXTURE_SPAN, style["layer"])


static func _clip_unit_square(points: PackedVector2Array) -> PackedVector2Array:
	var clipped: PackedVector2Array = _clip_height(points, 0.0, 1.0, 0.0, 0.0, true)
	clipped = _clip_height(clipped, 0.0, 1.0, 0.0, 1.0, false)
	clipped = _clip_height(clipped, 0.0, 0.0, 1.0, 0.0, true)
	return _clip_height(clipped, 0.0, 0.0, 1.0, 1.0, false)


func _append_surface_layer(commands: Array[Dictionary], cell: Vector2i,
		pass_index: int, color: Color, texture: Texture2D, layer: String) -> void:
	var half_width: float = _surface_half_width_for(cell)
	var expansion: float = _surface_expansion_for(cell, pass_index)
	_append_uv_polygon(commands, cell, _organic_disc(cell, half_width * 0.93 + expansion),
		color, texture, ROAD_TEXTURE_SPAN, layer)
	var connections: int = surface_connection_mask_for(cell)
	for index: int in range(GridMapSimClass.CARDINAL_DIRECTIONS.size()):
		if (connections & (1 << index)) == 0:
			continue
		var direction: Vector2i = GridMapSimClass.CARDINAL_DIRECTIONS[index]
		var along := Vector2(direction)
		var across := Vector2(-direction.y, direction.x)
		var center := Vector2(0.5, 0.5)
		var arm_color: Color = color
		arm_color.a *= _connection_opacity_factor(cell, cell + direction)
		for segment: int in range(ROAD_SEGMENTS):
			var start: float = float(segment) / float(ROAD_SEGMENTS)
			var end: float = float(segment + 1) / float(ROAD_SEGMENTS)
			var start_center: Vector2 = center + along * (start * 0.5)
			var end_center: Vector2 = center + along * (end * 0.5)
			var start_width: float = _surface_layer_width(cell, direction, start, pass_index)
			var end_width: float = _surface_layer_width(cell, direction, end, pass_index)
			var points := PackedVector2Array([
				start_center + across * start_width, end_center + across * end_width,
				end_center - across * end_width, start_center - across * start_width])
			_append_uv_polygon(commands, cell, points, arm_color, texture, ROAD_TEXTURE_SPAN, layer)


func _surface_layer_width(cell: Vector2i, direction: Vector2i, along: float, pass_index: int) -> float:
	var width: float = _surface_half_width_for(cell)
	var neighbor: Vector2i = cell + direction
	var edge_width: float = _connection_half_width_for(cell, neighbor)
	var expansion: float = _surface_expansion_for(cell, pass_index)
	var edge_expansion: float = _connection_expansion_for(cell, neighbor, pass_index)
	var expanded: float = lerpf(expansion, edge_expansion, along)
	var point: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) + Vector2(direction) * (along * 0.5)
	return lerpf(width, edge_width, along) + expanded + _road_width_jitter(point) * (1.0 + expanded * 8.0)


static func _road_width_jitter(world_position: Vector2) -> float:
	# Shared world coordinates give both sides of every boundary the same edge.
	return (sin(world_position.x * 13.13 + world_position.y * 9.7) * 0.62
		+ cos(world_position.x * 3.1 - world_position.y * 7.4) * 0.38) * 0.013


static func _organic_disc(cell: Vector2i, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(12):
		var direction: Vector2 = Vector2.from_angle(float(index) / 12.0 * TAU)
		var point: Vector2 = Vector2(0.5, 0.5) + direction * radius
		var varied_radius: float = radius + _road_width_jitter(Vector2(cell) + point) * 0.6
		points.append(Vector2(0.5, 0.5) + direction * varied_radius)
	return points


# Every decoration is split on the mesh's TL–BR diagonal before projection.
# An unsplit road quad would float above/below a twisted terrain cell.
func _append_uv_polygon(commands: Array[Dictionary], cell: Vector2i,
		uv_points: PackedVector2Array, color: Color, texture: Texture2D = null,
		texture_span: float = 0.0, layer: String = "terrain", painted: bool = false) -> void:
	for half: int in range(2):
		var clipped: PackedVector2Array = _clip_diagonal(uv_points, half == 0)
		if clipped.size() < 3:
			continue
		var screen_points := PackedVector2Array()
		for uv: Vector2 in clipped:
			screen_points.append(_project_cell_uv(cell, uv))
		var shade: float = 1.0 if painted else _triangle_shade(cell, half == 0)
		var shaded := Color(color.r * shade, color.g * shade, color.b * shade, color.a)
		# Explicit fans handle projected back-facing rock triangles as well as
		# normal slopes, without asking the polygon triangulator to infer a fold.
		for index: int in range(1, clipped.size() - 1):
			var points := PackedVector2Array([screen_points[0], screen_points[index], screen_points[index + 1]])
			if absf((points[1] - points[0]).cross(points[2] - points[0])) < 0.0001:
				continue
			var local_uvs := PackedVector2Array([clipped[0], clipped[index], clipped[index + 1]])
			var texture_uvs := PackedVector2Array()
			for uv: Vector2 in local_uvs:
				if painted:
					texture_uvs.append(PaintedTerrainCompositorClass.ground_uv(Vector2(cell) + uv))
				else:
					texture_uvs.append((Vector2(cell) + uv) / texture_span if texture_span > 0.0 else uv)
			commands.append({
				"points": points,
				"colors": PackedColorArray([shaded]),
				"uvs": local_uvs,
				"texture_uvs": texture_uvs,
				"layer": layer,
				"texture": texture,
			})


func _project_cell_uv(cell: Vector2i, uv: Vector2) -> Vector2:
	var position: Vector2 = Vector2(cell) + uv
	return position * MapProjectionClass.CELL_SIZE - Vector2(0, grid.height_at(position) * MapProjectionClass.HEIGHT_STEP_PIXELS)


func _triangle_shade(cell: Vector2i, upper_right: bool) -> float:
	var heights = grid.cell_corner_heights(cell)
	var dx: float = float(heights[1] - heights[0]) if upper_right else float(heights[2] - heights[3])
	var dy: float = float(heights[2] - heights[1]) if upper_right else float(heights[3] - heights[0])
	var light := Vector3(-0.5, -0.7, 1.0).normalized()
	if is_zero_approx(dx) and is_zero_approx(dy):
		return 0.46 + light.z * 0.71
	var normal := Vector3(-dx * SLOPE_NORMAL_STRENGTH, -dy * SLOPE_NORMAL_STRENGTH, 1.0).normalized()
	return 0.40 + maxf(0.0, normal.dot(light)) * 0.79


func _cell_contains_point(cell: Vector2i, point: Vector2) -> bool:
	if not _cells.has(cell):
		return false
	var polygon: PackedVector2Array = (_cells[cell] as Dictionary)["polygon"] as PackedVector2Array
	return _point_in_triangle(point, polygon[0], polygon[1], polygon[2]) or _point_in_triangle(point, polygon[0], polygon[2], polygon[3])


static func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	if absf((b - a).cross(c - a)) < 0.0001:
		return false
	var ab: float = (b - a).cross(point - a)
	var bc: float = (c - b).cross(point - b)
	var ca: float = (a - c).cross(point - c)
	return (ab >= -0.0001 and bc >= -0.0001 and ca >= -0.0001) or (ab <= 0.0001 and bc <= 0.0001 and ca <= 0.0001)


static func _clip_diagonal(points: PackedVector2Array, upper_right: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	if points.is_empty():
		return result
	var sign_value: float = 1.0 if upper_right else -1.0
	var previous: Vector2 = points[points.size() - 1]
	var previous_distance: float = (previous.x - previous.y) * sign_value
	for current: Vector2 in points:
		var distance: float = (current.x - current.y) * sign_value
		var inside: bool = distance >= 0.0
		var previous_inside: bool = previous_distance >= 0.0
		if inside != previous_inside:
			var ratio: float = previous_distance / (previous_distance - distance)
			result.append(previous.lerp(current, ratio))
		if inside and (result.is_empty() or not result[result.size() - 1].is_equal_approx(current)):
			result.append(current)
		previous = current
		previous_distance = distance
	if result.size() > 1 and result[0].is_equal_approx(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	return result


static func _uv_rect(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)])


func _rebuild_texture_cache() -> void:
	_textures.clear()
	_painted_tints.clear()
	_painted_compositor = null
	if use_painted_terrain:
		var compositor := PaintedTerrainCompositorClass.new()
		if compositor.configure(grid):
			_painted_compositor = compositor
	_sync_row_canvases()
	if painted_mode_active():
		var defaults: Dictionary = GridMapSimClass.DefinitionCatalogClass.movement_defaults().get("terrain", {}) as Dictionary
		for terrain_id: String in GridMapSimClass.BASE_TERRAIN_IDS:
			var definition: Dictionary = defaults.get(terrain_id, {}) as Dictionary
			var baseline: Color = Color.from_string("#" + String(definition.get("color", "777777")), Color.GRAY)
			var configured: Color = _terrain_color(terrain_id)
			_painted_tints[terrain_id] = Color(
				configured.r / maxf(baseline.r, 0.001),
				configured.g / maxf(baseline.g, 0.001),
				configured.b / maxf(baseline.b, 0.001), 1.0)
	for terrain_id: String in GridMapSimClass.BASE_TERRAIN_IDS:
		_textures[terrain_id] = _terrain_texture(_terrain_color(terrain_id), terrain_id)
	var stone_texture: Texture2D = null
	if ResourceLoader.exists(STONE_ROAD_TEXTURE_PATH):
		stone_texture = load(STONE_ROAD_TEXTURE_PATH) as Texture2D
	_textures[GridMapSimClass.OVERLAY_STONE_ROAD] = stone_texture if stone_texture != null else _textures["rock"]


func _terrain_color(terrain_id: String) -> Color:
	var definition: Dictionary = grid.terrain_definition(terrain_id)
	return Color.from_string("#" + String(definition.get("color", "777777")), Color.GRAY)


func _transition_priority(terrain_id: String) -> int:
	return int(grid.terrain_definition(terrain_id).get("transition_priority", 0))


static func _terrain_texture(color: Color, terrain_id: String) -> ImageTexture:
	# Original deterministic procedural brush grain: no imported game artwork.
	# Periodic broad marks avoid harsh boundaries when neighbouring tiles repeat.
	const TEXTURE_SIZE: int = 64
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(TEXTURE_SIZE):
		for x: int in range(TEXTURE_SIZE):
			var u: float = float(x) / float(TEXTURE_SIZE) * TAU
			var v: float = float(y) / float(TEXTURE_SIZE) * TAU
			var coarse: float = sin(u * 2.0 + cos(v * 3.0)) * sin(v * 2.0 + cos(u))
			var grain: float = float((x * 127 + y * 311 + x * y * 17) % 101) / 100.0 - 0.5
			var strength: float = 0.08 if terrain_id == "grass" else 0.11
			var tint: float = 1.0 + coarse * strength + grain * 0.08
			if terrain_id == "rock":
				tint += pow(maxf(0.0, sin(v * 6.0 + sin(u * 2.0))), 14.0) * 0.12
			elif terrain_id == "water":
				tint += pow(maxf(0.0, sin(v * 8.0 + sin(u))), 12.0) * 0.08
			image.set_pixel(x, y, Color(color.r * tint, color.g * tint, color.b * tint, 1.0))
	return ImageTexture.create_from_image(image)
