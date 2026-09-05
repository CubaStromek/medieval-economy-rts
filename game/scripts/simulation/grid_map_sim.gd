class_name GridMapSim
extends RefCounted

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]
const BASE_TERRAIN_IDS: Array[String] = ["grass", "dirt", "water", "rock"]
const DEFAULT_BASE_TERRAIN: String = "grass"
const OVERLAY_NONE: String = ""
const OVERLAY_TRAIL: String = "trail"
const OVERLAY_STONE_ROAD: String = "stone_road"
const _BASE_TERRAIN_CODES: Dictionary = {
	"grass": 0,
	"dirt": 1,
	"water": 2,
	"rock": 3,
}

var size: Vector2i
# Dense row-major base terrain. Overlay and occupancy remain independent layers.
var _base_terrain: PackedByteArray = PackedByteArray()
# Player-built stone roads. The existing name is kept for save/API compatibility.
var roads: Dictionary = {}
var dirt_trails: Dictionary = {}
var traffic_wear: Dictionary = {}
var blocked_by: Dictionary = {}
var revision: int = 0
var definition_revision: int = 0

var _terrain_definitions: Dictionary = {}
var _overlay_definitions: Dictionary = {}
var _carrier_passes_to_form: int = 1


func _init(map_size: Vector2i = Vector2i(20, 16)) -> void:
	size = map_size
	_base_terrain.resize(maxi(0, size.x * size.y))
	_base_terrain.fill(int(_BASE_TERRAIN_CODES[DEFAULT_BASE_TERRAIN]))
	configure_movement(DefinitionCatalogClass.movement_defaults())


func configure_movement(definitions: Dictionary) -> void:
	var terrain_definitions: Dictionary = definitions.get("terrain", {}) as Dictionary
	for terrain_id: String in BASE_TERRAIN_IDS:
		var terrain_definition: Dictionary = terrain_definitions.get(terrain_id, {}) as Dictionary
		if not terrain_definition.is_empty():
			var merged: Dictionary = _terrain_definitions.get(terrain_id, {}) as Dictionary
			merged.merge(terrain_definition.duplicate(true), true)
			_terrain_definitions[terrain_id] = merged
	var overlay_definitions: Dictionary = definitions.get("overlays", {}) as Dictionary
	for overlay_id: String in [OVERLAY_TRAIL, OVERLAY_STONE_ROAD]:
		var overlay_definition: Dictionary = overlay_definitions.get(overlay_id, {}) as Dictionary
		if not overlay_definition.is_empty():
			var merged: Dictionary = _overlay_definitions.get(overlay_id, {}) as Dictionary
			merged.merge(overlay_definition.duplicate(true), true)
			_overlay_definitions[overlay_id] = merged

	# Accept the prototype's pre-terrain movement schema for API compatibility.
	var legacy_surfaces: Dictionary = definitions.get("surfaces", {}) as Dictionary
	if not legacy_surfaces.is_empty():
		var grass_definition: Dictionary = legacy_surfaces.get("grass", {}) as Dictionary
		var trail_definition: Dictionary = legacy_surfaces.get("dirt", {}) as Dictionary
		var road_definition: Dictionary = legacy_surfaces.get("stone", {}) as Dictionary
		if not grass_definition.is_empty():
			(_terrain_definitions["grass"] as Dictionary)["move_ticks"] = maxi(
				1, int(grass_definition.get("move_ticks", _terrain_definitions["grass"]["move_ticks"]))
			)
		if not trail_definition.is_empty():
			(_overlay_definitions[OVERLAY_TRAIL] as Dictionary)["move_ticks"] = maxi(
				1, int(trail_definition.get("move_ticks", _overlay_definitions[OVERLAY_TRAIL]["move_ticks"]))
			)
		if not road_definition.is_empty():
			(_overlay_definitions[OVERLAY_STONE_ROAD] as Dictionary)["move_ticks"] = maxi(
				1, int(road_definition.get("move_ticks", _overlay_definitions[OVERLAY_STONE_ROAD]["move_ticks"]))
			)
	var trail: Dictionary = definitions.get("trail", {}) as Dictionary
	_carrier_passes_to_form = maxi(1, int(trail.get("carrier_passes_to_form", _carrier_passes_to_form)))
	definition_revision += 1
	revision += 1


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func base_terrain_at(cell: Vector2i) -> String:
	if not contains(cell):
		return ""
	return BASE_TERRAIN_IDS[int(_base_terrain[_cell_index(cell)])]


func set_base_terrain(cell: Vector2i, terrain_id: String) -> bool:
	if not contains(cell) or not _BASE_TERRAIN_CODES.has(terrain_id) or blocked_by.has(cell):
		return false
	var terrain_code: int = int(_BASE_TERRAIN_CODES[terrain_id])
	var index: int = _cell_index(cell)
	if int(_base_terrain[index]) == terrain_code:
		return true
	_base_terrain[index] = terrain_code
	if not bool(terrain_definition(terrain_id).get("roadable", false)):
		roads.erase(cell)
		dirt_trails.erase(cell)
		traffic_wear.erase(cell)
	revision += 1
	return true


func overlay_at(cell: Vector2i) -> String:
	if roads.has(cell):
		return OVERLAY_STONE_ROAD
	if dirt_trails.has(cell):
		return OVERLAY_TRAIL
	return OVERLAY_NONE


func terrain_definition(terrain_id: String) -> Dictionary:
	return _terrain_definitions.get(terrain_id, {}) as Dictionary


func overlay_definition(overlay_id: String) -> Dictionary:
	return _overlay_definitions.get(overlay_id, {}) as Dictionary


func is_walkable(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return bool(terrain_definition(base_terrain_at(cell)).get("walkable", false))


func is_buildable(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return bool(terrain_definition(base_terrain_at(cell)).get("buildable", false))


func allows_trees(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return bool(terrain_definition(base_terrain_at(cell)).get("allows_trees", false))


func is_roadable(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return bool(terrain_definition(base_terrain_at(cell)).get("roadable", false))


func add_road(cell: Vector2i) -> bool:
	if not is_walkable(cell) or not is_roadable(cell):
		return false
	roads[cell] = true
	dirt_trails.erase(cell)
	traffic_wear.erase(cell)
	revision += 1
	return true


func add_dirt_trail(cell: Vector2i) -> bool:
	if not is_walkable(cell) or not is_roadable(cell) or roads.has(cell):
		return false
	dirt_trails[cell] = true
	traffic_wear[cell] = _carrier_passes_to_form
	revision += 1
	return true


func set_traffic_wear(cell: Vector2i, passes: int) -> void:
	if not is_walkable(cell) or not is_roadable(cell) or roads.has(cell):
		return
	var clamped_passes: int = maxi(0, passes)
	if clamped_passes == 0:
		if traffic_wear.erase(cell):
			revision += 1
		return
	traffic_wear[cell] = clamped_passes
	if clamped_passes >= _carrier_passes_to_form:
		dirt_trails[cell] = true
	revision += 1


func record_carrier_traffic(cell: Vector2i) -> bool:
	if not is_walkable(cell) or not is_roadable(cell) or roads.has(cell):
		return false
	if dirt_trails.has(cell):
		return false
	var was_dirt: bool = dirt_trails.has(cell)
	var passes: int = int(traffic_wear.get(cell, 0)) + 1
	traffic_wear[cell] = passes
	if passes >= _carrier_passes_to_form:
		dirt_trails[cell] = true
	revision += 1
	return not was_dirt and dirt_trails.has(cell)


func block(cell: Vector2i, entity_id: int) -> void:
	if not contains(cell):
		return
	blocked_by[cell] = entity_id
	roads.erase(cell)
	dirt_trails.erase(cell)
	traffic_wear.erase(cell)
	revision += 1


func unblock(cell: Vector2i) -> void:
	if blocked_by.erase(cell):
		revision += 1


func movement_cost(cell: Vector2i) -> int:
	return movement_duration_ticks(cell)


func movement_duration_ticks(cell: Vector2i) -> int:
	var overlay_id: String = overlay_at(cell)
	if not overlay_id.is_empty():
		return maxi(1, int(overlay_definition(overlay_id).get("move_ticks", 6)))
	return maxi(1, int(terrain_definition(base_terrain_at(cell)).get("move_ticks", 6)))


func surface_at(cell: Vector2i) -> String:
	# Legacy movement-profile wrapper. New code must read the base and overlay
	# layers separately because base dirt and a dirt trail are distinct states.
	if overlay_at(cell) == OVERLAY_STONE_ROAD:
		return "stone"
	if overlay_at(cell) == OVERLAY_TRAIL:
		return "dirt"
	return base_terrain_at(cell)


func minimum_movement_cost() -> int:
	var result: int = 2147483647
	for terrain_id: String in BASE_TERRAIN_IDS:
		var terrain: Dictionary = terrain_definition(terrain_id)
		if bool(terrain.get("walkable", false)):
			result = mini(result, maxi(1, int(terrain.get("move_ticks", 6))))
	for overlay_variant: Variant in _overlay_definitions.values():
		var overlay: Dictionary = overlay_variant as Dictionary
		result = mini(result, maxi(1, int(overlay.get("move_ticks", 6))))
	return maxi(1, result)


func carrier_passes_to_form_trail() -> int:
	return _carrier_passes_to_form


func traffic_wear_at(cell: Vector2i) -> int:
	return int(traffic_wear.get(cell, 0))


func visual_variant_at(cell: Vector2i, variant_count: int = 3) -> int:
	if variant_count <= 1:
		return 0
	var stable_hash: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return absi(stable_hash) % variant_count


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if is_walkable(candidate):
			result.append(candidate)
	return result


func _cell_index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x
