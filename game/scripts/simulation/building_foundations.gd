extends RefCounted

# Earthwork is an explicit part of construction, not a placement side effect.
# Work uses the same shared-corner terrain as drawing and pathfinding.
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Footprints = preload("res://scripts/simulation/building_footprints.gd")
const Deposits = preload("res://scripts/simulation/resource_deposits.gd")
const MAX_HEIGHT_SPAN: int = 2
const TICKS_PER_HEIGHT_UNIT: int = 8


static func pending(building: Dictionary) -> bool:
	return int(building.get("foundation_work_remaining", 0)) > 0


static func vertices_for_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for cell: Vector2i in cells:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			unique[cell + offset] = true
	var result: Array[Vector2i] = []
	result.assign(unique.keys())
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result


static func plan(world: Variant, type: String, anchor: Vector2i) -> Dictionary:
	var cells: Array[Vector2i] = world.placement_cells(type, anchor)
	var result: Dictionary = {"valid": false, "reason": "", "target_height": -1, "work_ticks": 0, "cells": cells, "vertices": vertices_for_cells(cells)}
	if world.default_footprint_version == 0 or not world.economy_enabled:
		result["valid"] = world.can_place_building(type, anchor)
		result["reason"] = "" if result["valid"] else "This building needs clear, level ground and an accessible entrance."
		return result
	var definition: Dictionary = world.catalog.building(type)
	if definition.is_empty() or cells.is_empty() or not world._building_terrain_valid(type, anchor):
		return _invalid(result, "The building does not have the required terrain here.")
	var occupied: Dictionary = {}
	var allowed: Array = definition.get("allowed_terrain", [])
	for cell: Vector2i in cells:
		if not world.grid.contains(cell):
			return _invalid(result, "The whole building must fit inside the map.")
		if not world.grid.is_walkable(cell) or not bool(world.grid.terrain_definition(world.grid.base_terrain_at(cell)).get("buildable", false)):
			return _invalid(result, "Buildings cannot be founded on water, rock, blocked or very steep ground.")
		if not allowed.is_empty() and not allowed.has(world.grid.base_terrain_at(cell)):
			return _invalid(result, "The whole building needs suitable ground.")
		if not world._building_site_cell_clear(cell):
			return _invalid(result, "The building area contains an object, worker or reserved space.")
		occupied[cell] = true
	var vertices: Array[Vector2i] = result["vertices"]
	var lowest: int = Grid.MAX_HEIGHT
	var highest: int = 0
	var sum: int = 0
	for vertex: Vector2i in vertices:
		var height: int = world.grid.vertex_height(vertex)
		lowest = mini(lowest, height)
		highest = maxi(highest, height)
		sum += height
	if highest - lowest > MAX_HEIGHT_SPAN:
		return _invalid(result, "The terrain is too uneven: a Builder can level at most 2 height units across a building.")
	var target: int = roundi(float(sum) / float(vertices.size()))
	result["target_height"] = target
	for vertex: Vector2i in vertices:
		result["work_ticks"] = int(result["work_ticks"]) + absi(world.grid.vertex_height(vertex) - target) * TICKS_PER_HEIGHT_UNIT
	var entrance: Vector2i = world.placement_entrance(type, anchor)
	if occupied.has(entrance) or not world.grid.is_walkable(entrance) or not world._building_site_cell_clear(entrance):
		return _invalid(result, "The building entrance must stay clear and walkable.")
	var reason: String = _sequence_reason(world, vertices, target, 0, occupied, entrance)
	if not reason.is_empty():
		return _invalid(result, reason)
	var final_heights: Dictionary = {}
	for vertex: Vector2i in vertices:
		final_heights[vertex] = target
	if not _approach_exists(world, entrance, occupied, final_heights):
		return _invalid(result, "The building needs an accessible approach after its ground is leveled.")
	# All exterior walkable connections and resource cells remain unchanged or
	# traversable, so the existing resource route remains valid after earthwork.
	if not Deposits.placement_valid(world, type, anchor, entrance, occupied):
		return _invalid(result, "No suitable resource can be reached from this building.")
	result["valid"] = true
	return result


static func _invalid(result: Dictionary, reason: String) -> Dictionary:
	result["valid"] = false
	result["reason"] = reason
	return result


static func validate_saved(world: Variant, building: Dictionary) -> bool:
	var target: int = int(building.get("foundation_target_height", -1))
	if target < 0 or target > Grid.MAX_HEIGHT:
		return false
	var cells: Array[Vector2i] = world.building_cells(building)
	var occupied: Dictionary = {}
	for cell: Vector2i in cells:
		occupied[cell] = true
	return _sequence_reason(world, vertices_for_cells(cells), target, int(building["id"]), occupied, building["entrance"]).is_empty()


static func _sequence_reason(world: Variant, vertices: Array[Vector2i], target: int, owner: int, occupied: Dictionary, entrance: Vector2i) -> String:
	var heights: Dictionary = {}
	for vertex: Vector2i in vertices:
		var current: int = world.grid.vertex_height(vertex)
		while current != target:
			current += 1 if current < target else -1
			var reason: String = _change_reason(world, vertex, current, owner, occupied, heights, false, 0)
			if not reason.is_empty():
				return reason
			heights[vertex] = current
	if not _approach_exists(world, entrance, occupied, heights):
		return "Leveling would obstruct the building entrance."
	return ""


static func next_vertex(world: Variant, building: Dictionary) -> Vector2i:
	var target: int = int(building.get("foundation_target_height", -1))
	for vertex: Vector2i in vertices_for_cells(world.building_cells(building)):
		if world.grid.vertex_height(vertex) != target:
			return vertex
	return Vector2i(-1, -1)


static func waiting_reason(world: Variant, building: Dictionary, builder_id: int = 0) -> String:
	var vertex: Vector2i = next_vertex(world, building)
	if vertex == Vector2i(-1, -1):
		return ""
	var target: int = int(building["foundation_target_height"])
	var current: int = world.grid.vertex_height(vertex)
	var height: int = current + (1 if current < target else -1)
	var occupied: Dictionary = {}
	for cell: Vector2i in world.building_cells(building):
		occupied[cell] = true
	return _change_reason(world, vertex, height, int(building["id"]), occupied, {}, true, builder_id)


static func tick(world: Variant, building: Dictionary, worker: Dictionary) -> bool:
	if not world.is_building_enabled(building) or not pending(building) or not world.can_worker_work(worker) or not _owns_work(world, building, worker):
		return false
	if not waiting_reason(world, building, int(worker["id"])).is_empty():
		return false
	if not world.allow_worker_work_tick(worker):
		return false
	var remaining: int = int(building["foundation_work_remaining"]) - 1
	if remaining % TICKS_PER_HEIGHT_UNIT == 0:
		var vertex: Vector2i = next_vertex(world, building)
		if vertex == Vector2i(-1, -1):
			return false
		var height: int = world.grid.vertex_height(vertex)
		height += 1 if height < int(building["foundation_target_height"]) else -1
		if not world.grid.set_foundation_vertex_height(vertex, height, int(building["id"])):
			return false
	building["foundation_work_remaining"] = remaining
	if remaining == 0:
		world.task_board.complete(int(worker["task_id"]), int(worker["id"]))
		world._reset_worker(worker)
		world._push_event("Ground leveled: %s. Carriers can now bring construction materials." % world.catalog.building(building["type"])["display_name"])
	return true


static func _owns_work(world: Variant, building: Dictionary, worker: Dictionary) -> bool:
	if worker["type"] != "builder" or worker["action"] != "build_site" or worker["state"] != "working" or int(worker["source_id"]) != int(building["id"]):
		return false
	if world.is_worker_inside(worker) or not String(worker["carrying"]).is_empty() or int(worker["visual_progress_ticks"]) < int(worker["visual_duration_ticks"]):
		return false
	var task: Dictionary = world.task_board._tasks.get(int(worker["task_id"]), {})
	if task.get("kind", "") != "build_site" or int(task.get("source_id", 0)) != int(building["id"]) or int(task.get("reserved_by", 0)) != int(worker["id"]):
		return false
	var position: Vector2i = worker["position"]
	var entrance: Vector2i = building["entrance"]
	return position == entrance or world.grid.can_traverse(position, entrance)


static func _change_reason(world: Variant, vertex: Vector2i, height: int, owner: int, occupied: Dictionary, previous: Dictionary, dynamic: bool, builder_id: int) -> String:
	var affected: Array[Vector2i] = world.grid.cells_touching_vertex(vertex)
	var after: Dictionary = previous.duplicate()
	after[vertex] = height
	for cell: Vector2i in affected:
		var blocking: int = int(world.grid.blocked_by.get(cell, 0))
		if blocking != 0 and (blocking != owner or not occupied.has(cell)):
			return "Leveling would move the foundation of a neighboring building."
		if world._tree_at(cell) != 0 or world.field_id_at(cell) != 0 or world.deposit_id_at(cell) != 0:
			return "Leveling would disturb a neighboring tree, field or resource."
		if world.grid.base_terrain_at(cell) in ["water", "rock"]:
			return "Leveling must not reshape neighboring water or rock."
		for other: Dictionary in world.buildings.values():
			if int(other["id"]) != owner and other["entrance"] == cell:
				return "Leveling would move a neighboring building entrance."
		if dynamic and _occupied_by_other(world, cell, builder_id):
			return "Waiting for workers to clear the ground."
		if occupied.has(cell):
			continue
		if _walkable(world, cell, previous, occupied) and not _walkable(world, cell, after, occupied):
			return "Leveling would make neighboring ground or a road impassable."
		for direction: Vector2i in Grid.MOVEMENT_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if _traverse(world, cell, neighbor, previous, occupied) and not _traverse(world, cell, neighbor, after, occupied):
				return "Leveling would break an existing path or road connection."
	return ""


static func _occupied_by_other(world: Variant, cell: Vector2i, builder_id: int) -> bool:
	for reservations: Dictionary in [world.tile_reservations, world.planting_reservations, world._yielding_origins]:
		var holder: int = int(reservations.get(cell, 0))
		if holder != 0 and holder != builder_id:
			return true
	for worker: Dictionary in world.workers.values():
		if int(worker["id"]) == builder_id or world.is_worker_inside(worker):
			continue
		if worker["position"] == cell:
			return true
		if int(worker["visual_progress_ticks"]) < int(worker["visual_duration_ticks"]):
			var origin: Vector2i = worker["previous_position"]
			var destination: Vector2i = worker["position"]
			if origin == cell or (origin.x != destination.x and origin.y != destination.y and cell in [Vector2i(origin.x, destination.y), Vector2i(destination.x, origin.y)]):
				return true
	return false


static func _height(world: Variant, vertex: Vector2i, heights: Dictionary) -> int:
	return int(heights.get(vertex, world.grid.vertex_height(vertex)))


static func _slope(world: Variant, cell: Vector2i, heights: Dictionary) -> int:
	var low: int = Grid.MAX_HEIGHT
	var high: int = 0
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
		var height: int = _height(world, cell + offset, heights)
		low = mini(low, height)
		high = maxi(high, height)
	return high - low


static func _walkable(world: Variant, cell: Vector2i, heights: Dictionary, occupied: Dictionary) -> bool:
	return world.grid.contains(cell) and not occupied.has(cell) and not world.grid.blocked_by.has(cell) and _slope(world, cell, heights) <= Grid.MAX_WALK_SLOPE and bool(world.grid.terrain_definition(world.grid.base_terrain_at(cell)).get("walkable", false))


static func _adjacent(world: Variant, from: Vector2i, to: Vector2i, heights: Dictionary) -> bool:
	var source: int = _height(world, from, heights) + _height(world, from + Vector2i.ONE, heights)
	var destination: int = _height(world, to, heights) + _height(world, to + Vector2i.ONE, heights)
	return absi(source - destination) <= Grid.MAX_WALK_SLOPE * 2


static func _traverse(world: Variant, from: Vector2i, to: Vector2i, heights: Dictionary, occupied: Dictionary) -> bool:
	if not _walkable(world, from, heights, occupied) or not _walkable(world, to, heights, occupied):
		return false
	var delta: Vector2i = to - from
	if absi(delta.x) + absi(delta.y) == 1:
		return _adjacent(world, from, to, heights)
	if absi(delta.x) != 1 or absi(delta.y) != 1:
		return false
	var flank_x := Vector2i(to.x, from.y)
	var flank_y := Vector2i(from.x, to.y)
	return _walkable(world, flank_x, heights, occupied) and _walkable(world, flank_y, heights, occupied) and _adjacent(world, from, to, heights) and _adjacent(world, from, flank_x, heights) and _adjacent(world, flank_x, to, heights) and _adjacent(world, from, flank_y, heights) and _adjacent(world, flank_y, to, heights)


static func _approach_exists(world: Variant, entrance: Vector2i, occupied: Dictionary, heights: Dictionary) -> bool:
	if not _walkable(world, entrance, heights, occupied):
		return false
	for direction: Vector2i in Grid.CARDINAL_DIRECTIONS:
		var cell: Vector2i = entrance + direction
		if _traverse(world, entrance, cell, heights, occupied) and world._tree_at(cell) == 0:
			return true
	return false
