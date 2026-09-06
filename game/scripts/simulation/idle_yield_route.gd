extends RefCounted

# Yielding is local traffic management, not another whole-map route search.
const MAX_STEPS: int = 16
const MAX_VISITED: int = 256


static func find(world: Variant, other: Dictionary, requester_start: Vector2i, path: Array, path_index: int, requester_id: int) -> Array[Vector2i]:
	var avoided: Dictionary = {requester_start: true}
	for index: int in range(path_index, path.size()):
		avoided[path[index]] = true
	for building: Dictionary in world.buildings.values():
		avoided[building["entrance"]] = true
	# Two simultaneous retreats must not select the same distant resting cell.
	for worker: Dictionary in world.workers.values():
		if worker["action"] == "yield" and int(worker["id"]) != int(other["id"]):
			avoided[worker["target_cell"]] = true
	var blockers: Dictionary = world._temporary_blockers_for(int(other["id"]))
	var from: Vector2i = other["position"]
	# Preserve the cheap one-step behavior, including a preference for resting
	# off a road. Only blocked lanes need the bounded multi-step search.
	var best := Vector2i(-1, -1)
	var best_cost: int = 2147483647
	for cell: Vector2i in world.grid.neighbors8(from, blockers):
		if not _can_rest(world, cell, avoided):
			continue
		var cost: int = world.grid.step_duration_ticks(from, cell) + (100 if not world.grid.overlay_at(cell).is_empty() else 0)
		if cost < best_cost:
			best = cell
			best_cost = cost
	if best != Vector2i(-1, -1):
		return [best]
	var route: Array[Vector2i] = _search(world, from, blockers, avoided)
	if not route.is_empty():
		return route
	# A dead-end doorway may have its only clearing behind the requester.
	# Permit a planned retreat past that one person, using the existing timed
	# reciprocal walking step at their encounter. Never relax unrelated units,
	# a diagonal flank blocker, or an occupied virtual door of someone indoors.
	var requester: Dictionary = world.workers.get(requester_id, {})
	if requester.is_empty() or world.is_worker_inside(requester) \
			or int(world.tile_reservations.get(requester_start, 0)) != requester_id \
			or world._yielding_origins.has(requester_start) \
			or not path.slice(path_index).has(from):
		return []
	blockers.erase(requester_start)
	return _search(world, from, blockers, avoided)


static func _can_rest(world: Variant, cell: Vector2i, avoided: Dictionary) -> bool:
	return not avoided.has(cell) and not world.planting_reservations.has(cell) \
		and world._tree_at(cell) == 0 and world.field_id_at(cell) == 0 and world.deposit_id_at(cell) == 0


static func _search(world: Variant, from: Vector2i, blockers: Dictionary, avoided: Dictionary) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [from]
	var parents: Dictionary = {from: from}
	var depths: Dictionary = {from: 0}
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		if int(depths[current]) >= MAX_STEPS:
			continue
		for cell: Vector2i in world.grid.neighbors8(current, blockers):
			if parents.has(cell):
				continue
			parents[cell] = current
			depths[cell] = int(depths[current]) + 1
			if _can_rest(world, cell, avoided):
				var result: Array[Vector2i] = [cell]
				var previous: Vector2i = current
				while previous != from:
					result.append(previous)
					previous = parents[previous]
				result.reverse()
				return result
			if parents.size() >= MAX_VISITED:
				return []
			queue.append(cell)
	return []
