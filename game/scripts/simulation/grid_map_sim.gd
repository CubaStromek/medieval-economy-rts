class_name GridMapSim
extends RefCounted

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]
# Movement is eight-way, while doors, resource work faces and tile borders
# deliberately keep using CARDINAL_DIRECTIONS.
const MOVEMENT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const BASE_TERRAIN_IDS: Array[String] = ["grass", "dirt", "water", "rock"]
const DEFAULT_BASE_TERRAIN: String = "grass"
# Heights are exact integer simulation state; absolute altitude is not a blocker.
const MAX_HEIGHT: int = 64
const MAX_WALK_SLOPE: int = 3
const MAX_BUILD_SLOPE: int = 0
const OVERLAY_NONE: String = ""
const OVERLAY_TRAIL: String = "trail"
const OVERLAY_STONE_ROAD: String = "stone_road"
const NO_CELL: Vector2i = Vector2i(-2147483648, -2147483648)
const TRAIL_DECAY_SCAN_TICKS: int = 20
const _BASE_TERRAIN_CODES: Dictionary = {
	"grass": 0,
	"dirt": 1,
	"water": 2,
	"rock": 3,
}

var size: Vector2i
# Dense row-major base terrain. Overlay and occupancy remain independent layers.
var _base_terrain: PackedByteArray = PackedByteArray()
# Adjacent cells share their (W + 1) × (H + 1) corner lattice.
var _vertex_heights: PackedInt32Array = PackedInt32Array()
# Player-built stone roads. The existing name is kept for save/API compatibility.
var roads: Dictionary = {}
var dirt_trails: Dictionary = {}
var traffic_wear: Dictionary = {}
# Sparse timestamps and traversed edges are simulation state, not rendering
# guesses from nearby muddy tiles. An undirected edge is stored only once.
var trail_last_decay: Dictionary = {}
var trail_links: Dictionary = {}
var blocked_by: Dictionary = {}
var revision: int = 0
var definition_revision: int = 0
# Failed workplace searches depend on reachability, not painted road wear.
# Keep this transient revision separate from the render/surface revision.
var connectivity_revision: int = 0
## Cells whose walkability inputs changed since GridPathfinder last updated its
## packed index. A revision bumped without tracking forces a full rebuild.
var _path_dirty_cells: Dictionary = {}
var _path_dirty_full: bool = true
var _path_tracked_revision: int = 0
## Owned by GridPathfinder; untyped so the grid does not depend on it.
var path_index: Variant = null
# Presentation invalidation is bounded by map size, not by elapsed play time.
# Each reader keeps its own revision; reading never consumes another's changes.
var _terrain_change_revisions: PackedInt64Array = PackedInt64Array()
var _surface_change_revisions: PackedInt64Array = PackedInt64Array()
var _tracked_render_revision: int = 0
var _full_render_revision: int = 0

var _terrain_definitions: Dictionary = {}
var _overlay_definitions: Dictionary = {}
var _carrier_passes_to_form: int = 36
var _trail_weak_decay_ticks: int = 200
var _trail_established_decay_ticks: int = 400
var _trail_retention_passes: int = 16
var _last_trail_decay_scan: int = -TRAIL_DECAY_SCAN_TICKS
var _trail_now: int = 0


func _init(map_size: Vector2i = Vector2i(20, 16)) -> void:
	size = map_size
	_base_terrain.resize(maxi(0, size.x * size.y))
	_base_terrain.fill(int(_BASE_TERRAIN_CODES[DEFAULT_BASE_TERRAIN]))
	_vertex_heights.resize(maxi(0, (size.x + 1) * (size.y + 1)))
	_vertex_heights.fill(0)
	_terrain_change_revisions.resize(_base_terrain.size())
	_surface_change_revisions.resize(_base_terrain.size())
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
	_trail_weak_decay_ticks = maxi(1, int(trail.get("weak_decay_ticks", _trail_weak_decay_ticks)))
	_trail_established_decay_ticks = maxi(1, int(trail.get("established_decay_ticks", _trail_established_decay_ticks)))
	_trail_retention_passes = maxi(1, int(trail.get("established_min_wear", _trail_retention_passes)))
	_normalize_trail_profile()
	definition_revision += 1
	invalidate_connectivity()
	_record_full_render_change()


func rendering_changes_since(previous_revision: int) -> Dictionary:
	var terrain: Array[Vector2i] = []
	var surface: Array[Vector2i] = []
	if previous_revision == revision:
		return {"full": false, "terrain": terrain, "surface": surface}
	# Legacy callers can mutate public dictionaries and increment revision. A
	# revision outside the tracked sequence must not produce stale cached tiles.
	if previous_revision < 0 or previous_revision > revision \
			or revision != _tracked_render_revision or previous_revision < _full_render_revision:
		return {"full": true, "terrain": terrain, "surface": surface}
	for index: int in range(_terrain_change_revisions.size()):
		if _terrain_change_revisions[index] > previous_revision:
			terrain.append(Vector2i(index % size.x, index / size.x))
		if _surface_change_revisions[index] > previous_revision:
			surface.append(Vector2i(index % size.x, index / size.x))
	return {"full": false, "terrain": terrain, "surface": surface}


func _record_full_render_change() -> void:
	_terrain_change_revisions.fill(0)
	_surface_change_revisions.fill(0)
	revision += 1
	_tracked_render_revision = revision
	_full_render_revision = revision


func _record_render_change(cells: Array[Vector2i], terrain_changed: bool = false) -> void:
	if revision != _tracked_render_revision:
		# Preserve the fallback even when a normal mutator follows an unobserved
		# direct revision edit. Rewound revisions must not keep future timestamps.
		_terrain_change_revisions.fill(0)
		_surface_change_revisions.fill(0)
		_full_render_revision = revision + 1
	revision += 1
	_tracked_render_revision = revision
	for cell: Vector2i in cells:
		var index: int = _cell_index(cell)
		if terrain_changed:
			_terrain_change_revisions[index] = revision
		_surface_change_revisions[index] = revision


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func contains_vertex(vertex: Vector2i) -> bool:
	return vertex.x >= 0 and vertex.y >= 0 and vertex.x <= size.x and vertex.y <= size.y


func vertex_height(vertex: Vector2i) -> int:
	if not contains_vertex(vertex):
		return 0
	return _vertex_heights[vertex.y * (size.x + 1) + vertex.x]


func set_vertex_height(vertex: Vector2i, height: int) -> bool:
	return _set_vertex_height(vertex, height, 0)


func set_foundation_vertex_height(vertex: Vector2i, height: int, building_id: int) -> bool:
	# Only the owning construction site may reshape its own blocked footprint.
	# SimulationWorld checks shared entities, workers and path safety first.
	if building_id <= 0 or not contains_vertex(vertex):
		return false
	var owned: bool = false
	for cell: Vector2i in cells_touching_vertex(vertex):
		owned = owned or int(blocked_by.get(cell, 0)) == building_id
	if not owned or absi(vertex_height(vertex) - height) != 1:
		return false
	return _set_vertex_height(vertex, height, building_id)


func _set_vertex_height(vertex: Vector2i, height: int, allowed_owner: int) -> bool:
	if not contains_vertex(vertex) or height < 0 or height > MAX_HEIGHT:
		return false
	if vertex_height(vertex) == height:
		return true
	var affected: Array[Vector2i] = cells_touching_vertex(vertex)
	for cell: Vector2i in affected:
		if blocked_by.has(cell) and (allowed_owner == 0 or int(blocked_by[cell]) != allowed_owner):
			return false
	_vertex_heights[vertex.y * (size.x + 1) + vertex.x] = height
	connectivity_revision += 1
	_mark_path_cells(affected)
	var trail_changes: Dictionary = {}
	for cell: Vector2i in affected:
		if not is_walkable(cell) or not is_roadable(cell):
			roads.erase(cell)
			_erase_trail_cell(cell, trail_changes)
		_remove_invalid_trail_links_near(cell, trail_changes)
	_mark_trail_changes(trail_changes)
	_record_render_change(affected, true)
	return true

func cells_touching_vertex(vertex: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(vertex.y - 1, vertex.y + 1):
		for x: int in range(vertex.x - 1, vertex.x + 1):
			var cell := Vector2i(x, y)
			if contains(cell):
				cells.append(cell)
	return cells


func cell_corner_heights(cell: Vector2i) -> PackedInt32Array:
	if not contains(cell):
		return PackedInt32Array([0, 0, 0, 0])
	return PackedInt32Array([
		vertex_height(cell), vertex_height(cell + Vector2i.RIGHT),
		vertex_height(cell + Vector2i.ONE), vertex_height(cell + Vector2i.DOWN),
	])


func cell_slope(cell: Vector2i) -> int:
	if not contains(cell):
		return MAX_HEIGHT + 1
	var heights: PackedInt32Array = cell_corner_heights(cell)
	var low: int = heights[0]
	var high: int = heights[0]
	for height: int in heights:
		low = mini(low, height)
		high = maxi(high, height)
	return high - low


func height_at(position: Vector2) -> float:
	# Read-only presentation sampling, with the renderer's TL–BR diagonal.
	if size.x <= 0 or size.y <= 0:
		return 0.0
	var x: float = clampf(position.x, 0.0, float(size.x))
	var y: float = clampf(position.y, 0.0, float(size.y))
	var cell := Vector2i(mini(floori(x), size.x - 1), mini(floori(y), size.y - 1))
	var u: float = x - float(cell.x)
	var v: float = y - float(cell.y)
	var heights: PackedInt32Array = cell_corner_heights(cell)
	if u >= v:
		return float(heights[0]) + float(heights[1] - heights[0]) * u + float(heights[2] - heights[1]) * v
	return float(heights[0]) + float(heights[2] - heights[3]) * u + float(heights[3] - heights[0]) * v


func cell_height(cell: Vector2i) -> float:
	return float(_twice_cell_height(cell)) * 0.5


func _twice_cell_height(cell: Vector2i) -> int:
	return vertex_height(cell) + vertex_height(cell + Vector2i.ONE)


func _adjacent_height_access(from: Vector2i, to: Vector2i) -> bool:
	if not contains(from) or not contains(to):
		return false
	if absi(from.x - to.x) + absi(from.y - to.y) != 1:
		return false
	return absi(_twice_cell_height(from) - _twice_cell_height(to)) <= MAX_WALK_SLOPE * 2


func can_traverse(from: Vector2i, to: Vector2i) -> bool:
	if not is_walkable(from) or not is_walkable(to):
		return false
	var delta: Vector2i = to - from
	if absi(delta.x) + absi(delta.y) == 1:
		return _adjacent_height_access(from, to)
	if absi(delta.x) != 1 or absi(delta.y) != 1:
		return false
	var flank_x := Vector2i(to.x, from.y)
	var flank_y := Vector2i(from.x, to.y)
	# Both routes around the corner must be open. A diagonal must not clip a
	# building, cut a bank or bridge a height edge that a cardinal step rejects.
	return (
		is_walkable(flank_x) and is_walkable(flank_y)
		and absi(_twice_cell_height(from) - _twice_cell_height(to)) <= MAX_WALK_SLOPE * 2
		and _adjacent_height_access(from, flank_x) and _adjacent_height_access(flank_x, to)
		and _adjacent_height_access(from, flank_y) and _adjacent_height_access(flank_y, to)
	)


func can_step(from: Vector2i, to: Vector2i, temporary_blockers: Dictionary = {}) -> bool:
	if temporary_blockers.has(to) or not can_traverse(from, to):
		return false
	var delta: Vector2i = to - from
	if delta.x != 0 and delta.y != 0:
		return not temporary_blockers.has(Vector2i(to.x, from.y)) \
			and not temporary_blockers.has(Vector2i(from.x, to.y))
	return true


func can_use_building_exit(building_cell: Vector2i, exit_cell: Vector2i) -> bool:
	# Buildings occupy their source cell; test the underlying foundation instead.
	return (
		contains(building_cell) and cell_slope(building_cell) <= MAX_BUILD_SLOPE
		and bool(terrain_definition(base_terrain_at(building_cell)).get("buildable", false))
		and is_walkable(exit_cell) and _adjacent_height_access(building_cell, exit_cell)
	)


func can_reach_resource(from: Vector2i, target: Vector2i) -> bool:
	# Banks and mineral faces can be worked from the side without entering the
	# water/rock cell. A resource high above the worker is still out of reach.
	if not is_walkable(from):
		return false
	if from == target:
		return true
	return _adjacent_height_access(from, target)


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
	connectivity_revision += 1
	_mark_path_cells([cell])
	var trail_changes: Dictionary = {}
	if not bool(terrain_definition(terrain_id).get("roadable", false)):
		roads.erase(cell)
		_erase_trail_cell(cell, trail_changes)
	_remove_invalid_trail_links_near(cell, trail_changes)
	_mark_trail_changes(trail_changes)
	_record_render_change([cell], true)
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
	return cell_slope(cell) <= MAX_WALK_SLOPE and bool(terrain_definition(base_terrain_at(cell)).get("walkable", false))


func is_buildable(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return cell_slope(cell) <= MAX_BUILD_SLOPE and bool(terrain_definition(base_terrain_at(cell)).get("buildable", false))


func allows_trees(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return cell_slope(cell) <= MAX_WALK_SLOPE and bool(terrain_definition(base_terrain_at(cell)).get("allows_trees", false))


func is_roadable(cell: Vector2i) -> bool:
	if not contains(cell) or blocked_by.has(cell):
		return false
	return cell_slope(cell) <= MAX_WALK_SLOPE and bool(terrain_definition(base_terrain_at(cell)).get("roadable", false))


func add_road(cell: Vector2i) -> bool:
	if not is_walkable(cell) or not is_roadable(cell):
		return false
	roads[cell] = true
	var changes: Dictionary = {}
	_erase_trail_cell(cell, changes)
	# Existing worn approaches survive paving, but new neighboring dirt paths
	# are never connected simply because a road was placed alongside them.
	_remove_invalid_trail_links_near(cell, changes)
	_mark_trail_changes(changes)
	_record_render_change([cell])
	return true


func add_dirt_trail(cell: Vector2i) -> bool:
	if not is_walkable(cell) or not is_roadable(cell) or roads.has(cell):
		return false
	set_trail_state(cell, _carrier_passes_to_form, _trail_now, true)
	# This is an explicit map-authoring helper. Real walking uses only the
	# traversed from/to edge and must never invent these neighboring links.
	for direction: Vector2i in MOVEMENT_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if not overlay_at(neighbor).is_empty() and can_traverse(cell, neighbor):
			set_trail_link(cell, neighbor, _carrier_passes_to_form, _trail_now, true)
	return true


func set_traffic_wear(cell: Vector2i, passes: int) -> void:
	var wear: int = clampi(passes, 0, _carrier_passes_to_form)
	var established: bool = wear >= _carrier_passes_to_form \
		or (dirt_trails.has(cell) and wear >= trail_retention_passes())
	set_trail_state(cell, wear, _trail_now, established)


func record_carrier_traffic(cell: Vector2i, from: Vector2i = NO_CELL, now: int = 0) -> bool:
	if now < 0 or not is_walkable(cell) or not is_roadable(cell):
		return false
	if from != NO_CELL and (not can_traverse(from, cell) or not is_roadable(from)):
		return false
	now = maxi(now, _trail_now)
	_trail_now = now
	var was_dirt: bool = dirt_trails.has(cell)
	var changes: Dictionary = {}
	if not roads.has(cell):
		_decay_trail_cell(cell, now, changes)
		var old_wear: int = traffic_wear_at(cell)
		var wear: int = mini(_carrier_passes_to_form, old_wear + 1)
		traffic_wear[cell] = wear
		if not trail_last_decay.has(cell):
			trail_last_decay[cell] = now
		if wear >= _carrier_passes_to_form:
			dirt_trails[cell] = true
		if old_wear != wear:
			changes[cell] = true
	if from != NO_CELL and not (roads.has(from) and roads.has(cell)):
		var key: Vector4i = trail_link_key(from, cell)
		_decay_trail_link(key, now, changes)
		var link: Dictionary = trail_links.get(key, {})
		var old_wear: int = int(link.get("wear", 0))
		var wear: int = mini(_carrier_passes_to_form, old_wear + 1)
		trail_links[key] = {
			"wear": wear, "decay_tick": int(link.get("decay_tick", now)),
			"established": bool(link.get("established", false)) or wear >= _carrier_passes_to_form,
		}
		if old_wear != wear:
			changes[from] = true
			changes[cell] = true
	_mark_trail_changes(changes)
	return not was_dirt and dirt_trails.has(cell)


func set_trail_state(cell: Vector2i, wear: int, last_decay: int, established: bool) -> bool:
	if not is_walkable(cell) or not is_roadable(cell) or roads.has(cell) \
			or not _valid_trail_state(wear, last_decay, established):
		return false
	if wear == 0:
		clear_trail(cell)
		return true
	var visual_changed: bool = traffic_wear_at(cell) != wear or dirt_trails.has(cell) != established
	traffic_wear[cell] = wear
	trail_last_decay[cell] = last_decay
	if established:
		dirt_trails[cell] = true
	else:
		dirt_trails.erase(cell)
	if visual_changed:
		_record_render_change([cell])
	return true


func set_trail_link(from: Vector2i, to: Vector2i, wear: int, decay_tick: int, established: bool) -> bool:
	if not _valid_trail_state(wear, decay_tick, established) or not can_traverse(from, to) \
			or not is_roadable(from) or not is_roadable(to) or (roads.has(from) and roads.has(to)):
		return false
	var key: Vector4i = trail_link_key(from, to)
	var changes: Dictionary = {}
	if wear == 0:
		_erase_trail_link(key, changes)
	else:
		var previous: Dictionary = trail_links.get(key, {})
		trail_links[key] = {"wear": wear, "decay_tick": decay_tick, "established": established}
		if int(previous.get("wear", 0)) != wear or bool(previous.get("established", false)) != established:
			changes[from] = true
			changes[to] = true
	_mark_trail_changes(changes)
	return true


static func trail_link_key(from: Vector2i, to: Vector2i) -> Vector4i:
	if from.y < to.y or (from.y == to.y and from.x < to.x):
		return Vector4i(from.x, from.y, to.x, to.y)
	return Vector4i(to.x, to.y, from.x, from.y)


func trail_connection_active(from: Vector2i, to: Vector2i) -> bool:
	if not can_traverse(from, to):
		return false
	if roads.has(from) and roads.has(to):
		return true
	if not dirt_trails.has(from) and not dirt_trails.has(to):
		return false
	var link: Dictionary = trail_links.get(trail_link_key(from, to), {})
	return bool(link.get("established", false))


func clear_trail(cell: Vector2i) -> void:
	var changes: Dictionary = {}
	_erase_trail_cell(cell, changes)
	for direction: Vector2i in MOVEMENT_DIRECTIONS:
		_erase_trail_link(trail_link_key(cell, cell + direction), changes)
	_mark_trail_changes(changes)


func tick_trails(now: int) -> void:
	if now < 0:
		return
	_trail_now = maxi(_trail_now, now)
	var scan_tick: int = (now / TRAIL_DECAY_SCAN_TICKS) * TRAIL_DECAY_SCAN_TICKS
	if scan_tick <= _last_trail_decay_scan:
		return
	_last_trail_decay_scan = scan_tick
	var changes: Dictionary = {}
	# These dictionaries contain only touched ground and traversed edges. No
	# whole-map scan or per-tile idle timer is needed, even on a large map.
	for cell: Vector2i in traffic_wear.keys():
		_decay_trail_cell(cell, now, changes)
	for key: Vector4i in trail_links.keys():
		_decay_trail_link(key, now, changes)
	_mark_trail_changes(changes)


func restore_trail_clock(now: int) -> void:
	# Loading restores scheduling only; it must not age a paused save or apply
	# an extra off-boundary sweep that an uninterrupted simulation would skip.
	_trail_now = maxi(0, now)
	_last_trail_decay_scan = (_trail_now / TRAIL_DECAY_SCAN_TICKS) * TRAIL_DECAY_SCAN_TICKS


func _valid_trail_state(wear: int, decay_tick: int, established: bool) -> bool:
	return wear >= 0 and wear <= _carrier_passes_to_form and decay_tick >= 0 \
		and (wear >= trail_retention_passes() if established else wear < _carrier_passes_to_form)


func _normalize_trail_profile() -> void:
	# Runtime profile overrides must not leave formerly valid saved/fixture
	# state above its new cap or below its new established-retention boundary.
	for cell: Vector2i in traffic_wear.keys():
		var wear: int = clampi(traffic_wear_at(cell), 0, _carrier_passes_to_form)
		if wear == 0:
			traffic_wear.erase(cell)
			trail_last_decay.erase(cell)
			dirt_trails.erase(cell)
			continue
		traffic_wear[cell] = wear
		if wear >= _carrier_passes_to_form or (dirt_trails.has(cell) and wear >= trail_retention_passes()):
			dirt_trails[cell] = true
		else:
			dirt_trails.erase(cell)
	for key: Vector4i in trail_links.keys():
		var link: Dictionary = trail_links[key]
		var wear: int = clampi(int(link["wear"]), 0, _carrier_passes_to_form)
		if wear == 0:
			trail_links.erase(key)
			continue
		link["wear"] = wear
		link["established"] = wear >= _carrier_passes_to_form \
			or (bool(link["established"]) and wear >= trail_retention_passes())


func _decayed_trail_state(wear: int, decay_tick: int, established: bool, now: int) -> Dictionary:
	if now > decay_tick:
		if established:
			var mature_drops: int = mini((now - decay_tick) / _trail_established_decay_ticks,
				maxi(0, wear - trail_retention_passes() + 1))
			wear -= mature_drops
			decay_tick += mature_drops * _trail_established_decay_ticks
			established = wear >= trail_retention_passes()
		if not established:
			var weak_drops: int = mini((now - decay_tick) / _trail_weak_decay_ticks, wear)
			wear -= weak_drops
			decay_tick += weak_drops * _trail_weak_decay_ticks
	return {"wear": wear, "decay_tick": decay_tick, "established": established}


func _decay_trail_cell(cell: Vector2i, now: int, changes: Dictionary) -> void:
	if not traffic_wear.has(cell):
		return
	var old_wear: int = traffic_wear_at(cell)
	var was_established: bool = dirt_trails.has(cell)
	var state: Dictionary = _decayed_trail_state(old_wear, int(trail_last_decay.get(cell, 0)), was_established, now)
	var wear: int = int(state["wear"])
	if wear == 0:
		_erase_trail_cell(cell, changes)
		return
	traffic_wear[cell] = wear
	trail_last_decay[cell] = int(state["decay_tick"])
	if bool(state["established"]):
		dirt_trails[cell] = true
	else:
		dirt_trails.erase(cell)
	if wear != old_wear or was_established != bool(state["established"]):
		changes[cell] = true


func _decay_trail_link(key: Vector4i, now: int, changes: Dictionary) -> void:
	if not trail_links.has(key):
		return
	var link: Dictionary = trail_links[key]
	var state: Dictionary = _decayed_trail_state(int(link["wear"]), int(link["decay_tick"]), bool(link["established"]), now)
	if int(state["wear"]) == 0:
		_erase_trail_link(key, changes)
	else:
		trail_links[key] = state
		if int(link["wear"]) != int(state["wear"]) or bool(link["established"]) != bool(state["established"]):
			changes[Vector2i(key.x, key.y)] = true
			changes[Vector2i(key.z, key.w)] = true


func _erase_trail_cell(cell: Vector2i, changes: Dictionary) -> void:
	var changed: bool = traffic_wear.erase(cell)
	changed = dirt_trails.erase(cell) or changed
	trail_last_decay.erase(cell)
	if changed:
		changes[cell] = true


func _erase_trail_link(key: Vector4i, changes: Dictionary) -> void:
	if trail_links.erase(key):
		changes[Vector2i(key.x, key.y)] = true
		changes[Vector2i(key.z, key.w)] = true


func _remove_invalid_trail_links_near(cell: Vector2i, changes: Dictionary) -> void:
	var candidates: Dictionary = {}
	for direction: Vector2i in MOVEMENT_DIRECTIONS:
		candidates[trail_link_key(cell, cell + direction)] = true
	# A changed tile may also be a flank of a diagonal whose endpoints stay
	# otherwise walkable. Only these four extra local edges need checking.
	for index: int in range(CARDINAL_DIRECTIONS.size()):
		candidates[trail_link_key(cell + CARDINAL_DIRECTIONS[index],
			cell + CARDINAL_DIRECTIONS[(index + 1) % CARDINAL_DIRECTIONS.size()])] = true
	for key: Vector4i in candidates:
		if not trail_links.has(key):
			continue
		var from := Vector2i(key.x, key.y)
		var to := Vector2i(key.z, key.w)
		if not can_traverse(from, to) or not is_roadable(from) or not is_roadable(to) \
				or (roads.has(from) and roads.has(to)):
			_erase_trail_link(key, changes)


func _mark_trail_changes(changes: Dictionary) -> void:
	if changes.is_empty():
		return
	var cells: Array[Vector2i] = []
	for cell: Vector2i in changes:
		if contains(cell):
			cells.append(cell)
	if not cells.is_empty():
		_record_render_change(cells)


## Call after replacing dense terrain/height arrays directly.
func invalidate_connectivity() -> void:
	connectivity_revision += 1
	_path_dirty_cells.clear()
	_path_dirty_full = true
	_path_tracked_revision = connectivity_revision


func _mark_path_cells(cells: Array) -> void:
	# A pending full rebuild already covers every cell; keep bulk loads cheap.
	if not _path_dirty_full:
		for cell: Vector2i in cells:
			_path_dirty_cells[cell] = true
		if _path_dirty_cells.size() > maxi(64, size.x * size.y / 8):
			_path_dirty_cells.clear()
			_path_dirty_full = true
	_path_tracked_revision = connectivity_revision


func block(cell: Vector2i, entity_id: int) -> void:
	if not contains(cell):
		return
	if not blocked_by.has(cell):
		connectivity_revision += 1
		_mark_path_cells([cell])
	blocked_by[cell] = entity_id
	roads.erase(cell)
	var trail_changes: Dictionary = {}
	_erase_trail_cell(cell, trail_changes)
	_remove_invalid_trail_links_near(cell, trail_changes)
	_mark_trail_changes(trail_changes)
	_record_render_change([cell])


func unblock(cell: Vector2i) -> void:
	if blocked_by.erase(cell):
		connectivity_revision += 1
		_mark_path_cells([cell])
		_record_render_change([cell])


func movement_cost(cell: Vector2i) -> int:
	return movement_duration_ticks(cell)


func movement_duration_ticks(cell: Vector2i) -> int:
	var overlay_id: String = overlay_at(cell)
	if not overlay_id.is_empty():
		return maxi(1, int(overlay_definition(overlay_id).get("move_ticks", 6)))
	return maxi(1, int(terrain_definition(base_terrain_at(cell)).get("move_ticks", 6)))


static func diagonal_duration_ticks(cardinal_duration: int) -> int:
	# Integer ticks keep routing and physical movement on the same time scale.
	return ceili(float(cardinal_duration) * sqrt(2.0))


func step_duration_ticks(from: Vector2i, to: Vector2i) -> int:
	var duration: int = movement_duration_ticks(to)
	if dirt_trails.has(to) and not roads.has(to) and not trail_connection_active(from, to):
		duration = maxi(1, int(terrain_definition(base_terrain_at(to)).get("move_ticks", 6)))
	var delta: Vector2i = to - from
	if absi(delta.x) == 1 and absi(delta.y) == 1:
		return diagonal_duration_ticks(duration)
	return duration


func step_cost(from: Vector2i, to: Vector2i) -> int:
	return step_duration_ticks(from, to)


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


func trail_retention_passes() -> int:
	return mini(_trail_retention_passes, maxi(1, _carrier_passes_to_form - 1))


func trail_weak_decay_ticks() -> int:
	return _trail_weak_decay_ticks


func trail_established_decay_ticks() -> int:
	return _trail_established_decay_ticks


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
		if can_traverse(cell, candidate):
			result.append(candidate)
	return result


func neighbors8(cell: Vector2i, temporary_blockers: Dictionary = {}) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in MOVEMENT_DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if can_step(cell, candidate, temporary_blockers):
			result.append(candidate)
	return result


func _cell_index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x
