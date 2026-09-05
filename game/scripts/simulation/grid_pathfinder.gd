class_name GridPathfinder
extends RefCounted

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const UNSPECIFIED_START: Vector2i = Vector2i(-2147483648, -2147483648)


static func find_path(
	grid: GridMapSimClass,
	start: Vector2i,
	goal: Vector2i,
	temporary_blockers: Dictionary = {}
) -> Array[Vector2i]:
	if start == goal:
		return []
	if not grid.is_walkable(start) or not grid.is_walkable(goal) or temporary_blockers.has(goal):
		return []

	var minimum_cost: int = grid.minimum_movement_cost()
	var frontier: Array[Dictionary] = []
	_heap_push(frontier, {
		"cell": start, "cost": 0,
		"priority": _heuristic_cost(start, goal, minimum_cost),
	})
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}

	while not frontier.is_empty():
		var entry: Dictionary = _heap_pop(frontier)
		var current: Vector2i = entry["cell"] as Vector2i
		var current_cost: int = int(entry["cost"])
		# Improved routes insert a new entry; obsolete entries are discarded.
		if current_cost != int(cost_so_far.get(current, -1)):
			continue
		if current == goal:
			return _reconstruct(came_from, start, goal)

		for next_cell: Vector2i in grid.neighbors8(current, temporary_blockers):
			var new_cost: int = current_cost + grid.step_cost(current, next_cell)
			if not cost_so_far.has(next_cell) or new_cost < int(cost_so_far[next_cell]):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				_heap_push(frontier, {
					"cell": next_cell, "cost": new_cost,
					"priority": new_cost + _heuristic_cost(next_cell, goal, minimum_cost),
				})

	return []


static func find_path_to_nearest(
	grid: GridMapSimClass,
	start: Vector2i,
	goal_test: Callable,
	temporary_blockers: Dictionary = {}
) -> Array[Vector2i]:
	if not grid.is_walkable(start):
		return []

	# Dijkstra search finds the nearest valid cell by the same weighted travel
	# time used by ordinary workers. The binary heap keeps a full-map search
	# practical while cost/cell tie-breaking makes the result deterministic.
	var frontier: Array[Dictionary] = []
	_heap_push(frontier, {"cell": start, "cost": 0, "priority": 0})
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}

	while not frontier.is_empty():
		var entry: Dictionary = _heap_pop(frontier)
		var current: Vector2i = entry["cell"] as Vector2i
		var current_cost: int = int(entry["cost"])
		if current_cost != int(cost_so_far.get(current, -1)):
			continue
		if current != start and bool(goal_test.call(current)):
			return _reconstruct(came_from, start, current)

		for next_cell: Vector2i in grid.neighbors8(current, temporary_blockers):
			var new_cost: int = current_cost + grid.step_cost(current, next_cell)
			if not cost_so_far.has(next_cell) or new_cost < int(cost_so_far[next_cell]):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				_heap_push(frontier, {"cell": next_cell, "cost": new_cost, "priority": new_cost})

	return []


static func path_cost(
	grid: GridMapSimClass,
	path: Array[Vector2i],
	start: Vector2i = UNSPECIFIED_START
) -> int:
	var result: int = 0
	var previous: Vector2i = start
	for cell: Vector2i in path:
		# Legacy callers without a start retain a cardinal first step. New route
		# comparisons must supply start because that first step can be diagonal.
		result += grid.movement_cost(cell) if previous == UNSPECIFIED_START else grid.step_cost(previous, cell)
		previous = cell
	return result


static func _heuristic_cost(
	cell: Vector2i,
	goal: Vector2i,
	minimum_cost: int
) -> int:
	var dx: int = absi(cell.x - goal.x)
	var dy: int = absi(cell.y - goal.y)
	var diagonal_steps: int = mini(dx, dy)
	var straight_steps: int = maxi(dx, dy) - diagonal_steps
	return diagonal_steps * GridMapSimClass.diagonal_duration_ticks(minimum_cost) + straight_steps * minimum_cost


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _heap_push(heap: Array[Dictionary], entry: Dictionary) -> void:
	heap.append(entry)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _heap_entry_before(heap[index], heap[parent]):
			break
		var swap: Dictionary = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent


static func _heap_pop(heap: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = heap[0]
	var tail: Dictionary = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = tail
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		if left >= heap.size():
			break
		var right: int = left + 1
		var best_child: int = left
		if right < heap.size() and _heap_entry_before(heap[right], heap[left]):
			best_child = right
		if not _heap_entry_before(heap[best_child], heap[index]):
			break
		var swap: Dictionary = heap[index]
		heap[index] = heap[best_child]
		heap[best_child] = swap
		index = best_child
	return result


static func _heap_entry_before(a: Dictionary, b: Dictionary) -> bool:
	var a_priority: int = int(a["priority"])
	var b_priority: int = int(b["priority"])
	if a_priority != b_priority:
		return a_priority < b_priority
	return _cell_before(a["cell"] as Vector2i, b["cell"] as Vector2i)


static func _reconstruct(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = []
	var current: Vector2i = goal
	while current != start:
		reversed_path.append(current)
		current = came_from[current] as Vector2i
	reversed_path.reverse()
	return reversed_path
