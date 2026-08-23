class_name GridPathfinder
extends RefCounted

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")


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

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}

	while not frontier.is_empty():
		var current_index: int = _lowest_score_index(
			frontier,
			cost_so_far,
			goal,
			grid.minimum_movement_cost()
		)
		var current: Vector2i = frontier[current_index]
		frontier.remove_at(current_index)
		if current == goal:
			return _reconstruct(came_from, start, goal)

		for next_cell: Vector2i in grid.neighbors(current):
			if temporary_blockers.has(next_cell):
				continue
			var new_cost: int = int(cost_so_far[current]) + grid.movement_cost(next_cell)
			if not cost_so_far.has(next_cell) or new_cost < int(cost_so_far[next_cell]):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				if not frontier.has(next_cell):
					frontier.append(next_cell)

	return []


static func path_cost(grid: GridMapSimClass, path: Array[Vector2i]) -> int:
	var result: int = 0
	for cell: Vector2i in path:
		result += grid.movement_cost(cell)
	return result


static func _lowest_score_index(
	frontier: Array[Vector2i],
	costs: Dictionary,
	goal: Vector2i,
	minimum_cost: int
) -> int:
	var best_index: int = 0
	var best_score: int = 2147483647
	for index: int in range(frontier.size()):
		var cell: Vector2i = frontier[index]
		var heuristic: int = abs(cell.x - goal.x) + abs(cell.y - goal.y)
		var score: int = int(costs[cell]) + heuristic * minimum_cost
		if score < best_score:
			best_score = score
			best_index = index
		elif score == best_score and _cell_before(cell, frontier[best_index]):
			best_index = index
	return best_index


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _reconstruct(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = []
	var current: Vector2i = goal
	while current != start:
		reversed_path.append(current)
		current = came_from[current] as Vector2i
	reversed_path.reverse()
	return reversed_path
