class_name GridMapSim
extends RefCounted

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var size: Vector2i
# Player-built stone roads. The existing name is kept for save/API compatibility.
var roads: Dictionary = {}
var dirt_trails: Dictionary = {}
var traffic_wear: Dictionary = {}
var blocked_by: Dictionary = {}

var _surface_costs: Dictionary = {
	"grass": 6,
	"dirt": 4,
	"stone": 2,
}
var _surface_move_ticks: Dictionary = {
	"grass": 6,
	"dirt": 4,
	"stone": 2,
}
var _carrier_passes_to_form: int = 4


func _init(map_size: Vector2i = Vector2i(20, 16)) -> void:
	size = map_size


func configure_movement(definitions: Dictionary) -> void:
	var surfaces: Dictionary = definitions.get("surfaces", {}) as Dictionary
	for surface_id: String in ["grass", "dirt", "stone"]:
		var definition: Dictionary = surfaces.get(surface_id, {}) as Dictionary
		if not definition.is_empty():
			var move_ticks: int = maxi(1, int(definition.get("move_ticks", _surface_move_ticks[surface_id])))
			_surface_move_ticks[surface_id] = move_ticks
			_surface_costs[surface_id] = move_ticks
	var trail: Dictionary = definitions.get("trail", {}) as Dictionary
	_carrier_passes_to_form = maxi(1, int(trail.get("carrier_passes_to_form", _carrier_passes_to_form)))


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_walkable(cell: Vector2i) -> bool:
	return contains(cell) and not blocked_by.has(cell)


func add_road(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	roads[cell] = true
	dirt_trails.erase(cell)
	traffic_wear.erase(cell)
	return true


func add_dirt_trail(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell) or roads.has(cell):
		return false
	dirt_trails[cell] = true
	traffic_wear[cell] = _carrier_passes_to_form
	return true


func set_traffic_wear(cell: Vector2i, passes: int) -> void:
	if not contains(cell) or blocked_by.has(cell) or roads.has(cell):
		return
	var clamped_passes: int = maxi(0, passes)
	if clamped_passes == 0:
		traffic_wear.erase(cell)
		return
	traffic_wear[cell] = clamped_passes
	if clamped_passes >= _carrier_passes_to_form:
		dirt_trails[cell] = true


func record_carrier_traffic(cell: Vector2i) -> bool:
	if not is_walkable(cell) or roads.has(cell):
		return false
	var was_dirt: bool = dirt_trails.has(cell)
	var passes: int = int(traffic_wear.get(cell, 0)) + 1
	traffic_wear[cell] = passes
	if passes >= _carrier_passes_to_form:
		dirt_trails[cell] = true
	return not was_dirt and dirt_trails.has(cell)


func block(cell: Vector2i, entity_id: int) -> void:
	blocked_by[cell] = entity_id
	roads.erase(cell)
	dirt_trails.erase(cell)
	traffic_wear.erase(cell)


func unblock(cell: Vector2i) -> void:
	blocked_by.erase(cell)


func movement_cost(cell: Vector2i) -> int:
	return int(_surface_costs[surface_at(cell)])


func movement_duration_ticks(cell: Vector2i) -> int:
	return int(_surface_move_ticks[surface_at(cell)])


func surface_at(cell: Vector2i) -> String:
	if roads.has(cell):
		return "stone"
	if dirt_trails.has(cell):
		return "dirt"
	return "grass"


func minimum_movement_cost() -> int:
	var result: int = 2147483647
	for value_variant: Variant in _surface_costs.values():
		result = mini(result, int(value_variant))
	return maxi(1, result)


func carrier_passes_to_form_trail() -> int:
	return _carrier_passes_to_form


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if is_walkable(candidate):
			result.append(candidate)
	return result
