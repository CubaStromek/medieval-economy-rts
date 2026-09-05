class_name TerrainRenderer
extends Node2D

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")

const TRANSITION_WIDTH: float = 7.0
const VARIANT_TINTS: Array[float] = [0.96, 1.0, 1.04]
const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
]

var grid: GridMapSimClass
var _textures: Dictionary = {}
var _last_revision: int = -1
var _last_definition_revision: int = -1


func bind_grid(value: GridMapSimClass) -> void:
	grid = value
	_last_revision = -1
	_rebuild_texture_cache()
	_last_definition_revision = grid.definition_revision
	queue_redraw()


func rebuild() -> void:
	_rebuild_texture_cache()
	_last_revision = -1
	_last_definition_revision = -1 if grid == null else grid.definition_revision
	queue_redraw()


func invalidate_cell(_cell: Vector2i) -> void:
	# The public invalidation boundary is ready for 16x16 chunk caching. The
	# first 20x16 milestone redraws the single lightweight canvas item.
	queue_redraw()


func cell_center(cell: Vector2i) -> Vector2:
	return MapProjectionClass.cell_center(cell)


func cell_rect(cell: Vector2i) -> Rect2:
	return MapProjectionClass.cell_rect(cell)


func pick_cell(local_position: Vector2) -> Vector2i:
	return MapProjectionClass.world_to_cell(local_position)


func map_bounds() -> Rect2:
	if grid == null:
		return Rect2()
	return MapProjectionClass.map_bounds(grid.size)


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


func corner_transition_id_for(cell: Vector2i, diagonal: Vector2i) -> String:
	if (
		grid == null
		or not grid.contains(cell)
		or absi(diagonal.x) != 1
		or absi(diagonal.y) != 1
	):
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
	if grid == null:
		return
	if grid.definition_revision != _last_definition_revision:
		_rebuild_texture_cache()
		_last_definition_revision = grid.definition_revision
	if grid.revision != _last_revision:
		_last_revision = grid.revision
		queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	for y: int in range(grid.size.y):
		for x: int in range(grid.size.x):
			_draw_base_cell(Vector2i(x, y))
	for y: int in range(grid.size.y):
		for x: int in range(grid.size.x):
			var cell := Vector2i(x, y)
			_draw_ground_transitions(cell)
			_draw_surface_overlay(cell)


func _draw_base_cell(cell: Vector2i) -> void:
	var terrain_id: String = grid.base_terrain_at(cell)
	var texture: Texture2D = _textures.get("terrain:%s" % terrain_id) as Texture2D
	var tint: float = VARIANT_TINTS[grid.visual_variant_at(cell, VARIANT_TINTS.size())]
	var rect: Rect2 = MapProjectionClass.cell_rect(cell)
	if texture != null:
		draw_texture_rect(texture, rect, false, Color(tint, tint, tint, 1.0))
	else:
		draw_rect(rect, _terrain_color(terrain_id) * tint)
	draw_rect(rect, Color(0.08, 0.10, 0.08, 0.12), false, 1.0)


func _draw_ground_transitions(cell: Vector2i) -> void:
	var rect: Rect2 = MapProjectionClass.cell_rect(cell)
	var transition_mask: int = transition_mask_for(cell)
	var transitions: Array[Dictionary] = []
	for index: int in range(GridMapSimClass.CARDINAL_DIRECTIONS.size()):
		if (transition_mask & (1 << index)) == 0:
			continue
		var direction: Vector2i = GridMapSimClass.CARDINAL_DIRECTIONS[index]
		var terrain_id: String = grid.base_terrain_at(cell + direction)
		transitions.append({
			"direction": direction,
			"index": index,
			"priority": _transition_priority(terrain_id),
			"terrain_id": terrain_id,
		})
	transitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority: int = int(a["priority"])
		var b_priority: int = int(b["priority"])
		return a_priority < b_priority or (a_priority == b_priority and int(a["index"]) < int(b["index"]))
	)
	for transition: Dictionary in transitions:
		_draw_edge_transition(
			rect,
			transition["direction"] as Vector2i,
			String(transition["terrain_id"])
		)
	_draw_corner_transitions(cell, rect)


func _draw_edge_transition(rect: Rect2, direction: Vector2i, terrain_id: String) -> void:
	var transition_color: Color = _terrain_color(terrain_id)
	transition_color.a = 0.62
	var soft_color: Color = transition_color
	soft_color.a = 0.22
	var edge_rect: Rect2
	var soft_rect: Rect2
	match direction:
		Vector2i(0, -1):
			edge_rect = Rect2(rect.position, Vector2(rect.size.x, TRANSITION_WIDTH))
			soft_rect = Rect2(
				rect.position + Vector2(0.0, TRANSITION_WIDTH),
				Vector2(rect.size.x, TRANSITION_WIDTH)
			)
		Vector2i(1, 0):
			edge_rect = Rect2(
				rect.position + Vector2(rect.size.x - TRANSITION_WIDTH, 0.0),
				Vector2(TRANSITION_WIDTH, rect.size.y)
			)
			soft_rect = Rect2(
				rect.position + Vector2(rect.size.x - TRANSITION_WIDTH * 2.0, 0.0),
				Vector2(TRANSITION_WIDTH, rect.size.y)
			)
		Vector2i(0, 1):
			edge_rect = Rect2(
				rect.position + Vector2(0.0, rect.size.y - TRANSITION_WIDTH),
				Vector2(rect.size.x, TRANSITION_WIDTH)
			)
			soft_rect = Rect2(
				rect.position + Vector2(0.0, rect.size.y - TRANSITION_WIDTH * 2.0),
				Vector2(rect.size.x, TRANSITION_WIDTH)
			)
		_:
			edge_rect = Rect2(rect.position, Vector2(TRANSITION_WIDTH, rect.size.y))
			soft_rect = Rect2(
				rect.position + Vector2(TRANSITION_WIDTH, 0.0),
				Vector2(TRANSITION_WIDTH, rect.size.y)
			)
	draw_rect(edge_rect, transition_color)
	draw_rect(soft_rect, soft_color)


func _draw_corner_transitions(cell: Vector2i, rect: Rect2) -> void:
	for diagonal: Vector2i in DIAGONAL_DIRECTIONS:
		var terrain_id: String = corner_transition_id_for(cell, diagonal)
		if terrain_id.is_empty():
			continue
		var corner := rect.position + Vector2(
			0.0 if diagonal.x < 0 else rect.size.x,
			0.0 if diagonal.y < 0 else rect.size.y
		)
		var horizontal_point := corner + Vector2(-diagonal.x * TRANSITION_WIDTH, 0.0)
		var vertical_point := corner + Vector2(0.0, -diagonal.y * TRANSITION_WIDTH)
		var corner_color: Color = _terrain_color(terrain_id)
		corner_color.a = 0.45
		draw_colored_polygon(
			PackedVector2Array([corner, horizontal_point, vertical_point]),
			corner_color
		)


func _draw_surface_overlay(cell: Vector2i) -> void:
	var overlay_id: String = grid.overlay_at(cell)
	if overlay_id.is_empty():
		_draw_partial_wear(cell)
		return
	var center: Vector2 = MapProjectionClass.cell_center(cell)
	var half_width: float = 7.0 if overlay_id == GridMapSimClass.OVERLAY_TRAIL else 11.0
	var color: Color = _overlay_color(overlay_id)
	draw_circle(center, half_width, color)
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if not grid.contains(neighbor) or grid.overlay_at(neighbor).is_empty():
			continue
		var branch_rect: Rect2
		match direction:
			Vector2i(0, -1):
				branch_rect = Rect2(
					center + Vector2(-half_width, -MapProjectionClass.CELL_SIZE.y * 0.5),
					Vector2(half_width * 2.0, MapProjectionClass.CELL_SIZE.y * 0.5)
				)
			Vector2i(1, 0):
				branch_rect = Rect2(
					center,
					Vector2(MapProjectionClass.CELL_SIZE.x * 0.5, half_width * 2.0)
				)
				branch_rect.position.y -= half_width
			Vector2i(0, 1):
				branch_rect = Rect2(
					center + Vector2(-half_width, 0.0),
					Vector2(half_width * 2.0, MapProjectionClass.CELL_SIZE.y * 0.5)
				)
			_:
				branch_rect = Rect2(
					center + Vector2(-MapProjectionClass.CELL_SIZE.x * 0.5, -half_width),
					Vector2(MapProjectionClass.CELL_SIZE.x * 0.5, half_width * 2.0)
				)
		draw_rect(branch_rect, color)
	if overlay_id == GridMapSimClass.OVERLAY_STONE_ROAD:
		draw_line(center + Vector2(-8.0, 0.0), center + Vector2(8.0, 0.0), color.lightened(0.18), 1.0)


func _draw_partial_wear(cell: Vector2i) -> void:
	var wear: int = grid.traffic_wear_at(cell)
	if wear <= 0:
		return
	var ratio: float = clampf(
		float(wear) / float(grid.carrier_passes_to_form_trail()),
		0.0,
		1.0
	)
	var wear_color: Color = _overlay_color(GridMapSimClass.OVERLAY_TRAIL)
	wear_color.a = 0.18 + ratio * 0.42
	draw_circle(MapProjectionClass.cell_center(cell), lerpf(3.0, 7.0, ratio), wear_color)


func _rebuild_texture_cache() -> void:
	_textures.clear()
	if grid == null:
		return
	for terrain_id: String in GridMapSimClass.BASE_TERRAIN_IDS:
		_textures["terrain:%s" % terrain_id] = _solid_texture(_terrain_color(terrain_id))
	for overlay_id: String in [
		GridMapSimClass.OVERLAY_TRAIL,
		GridMapSimClass.OVERLAY_STONE_ROAD,
	]:
		_textures["overlay:%s" % overlay_id] = _solid_texture(_overlay_color(overlay_id))


func _terrain_color(terrain_id: String) -> Color:
	var definition: Dictionary = grid.terrain_definition(terrain_id)
	return Color.from_string("#" + String(definition.get("color", "777777")), Color.GRAY)


func _overlay_color(overlay_id: String) -> Color:
	var definition: Dictionary = grid.overlay_definition(overlay_id)
	return Color.from_string("#" + String(definition.get("color", "777777")), Color.GRAY)


func _transition_priority(terrain_id: String) -> int:
	return int(grid.terrain_definition(terrain_id).get("transition_priority", 0))


static func _solid_texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
