extends RefCounted

## The packed path index must reproduce the historical Dictionary A*/Dijkstra
## byte for byte, including tie-breaking, live trail costs, temporary blockers
## and every tracked or untracked connectivity change.
const World = preload("res://scripts/simulation/simulation_world.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_demo_routes_match_reference, _test_nearest_matches_reference,
		_test_incremental_updates_match_rebuild, _test_reentrant_nearest_goal]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _walkable_cells(grid: Grid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(grid.size.y):
		for x: int in range(grid.size.x):
			if grid.is_walkable(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


static func _pairs(cells: Array[Vector2i], count: int, seed_value: int) -> Array:
	var state: int = seed_value
	var pairs: Array = []
	for _index: int in range(count):
		state = (state * 1103515245 + 12345) % 2147483648
		var a: Vector2i = cells[state % cells.size()]
		state = (state * 1103515245 + 12345) % 2147483648
		pairs.append([a, cells[state % cells.size()]])
	return pairs


static func _test_demo_routes_match_reference(failures: Array[String]) -> void:
	var world := World.new()
	world.setup_economy_demo()
	for _tick: int in range(250):
		world.step_tick()
	var trail_start: Vector2i = _add_established_trail(world)
	var established: bool = false
	for link: Dictionary in world.grid.trail_links.values():
		established = established or bool(link.get("established", false))
	_check(trail_start.x >= 0 and established, "Equivalence fixture must include an established dynamic trail", failures)
	var cells: Array[Vector2i] = _walkable_cells(world.grid)
	var pairs: Array = _pairs(cells, 50, 7)
	if trail_start.x >= 0:
		pairs.append([trail_start, trail_start + Vector2i(5, 0)])
		pairs.append([trail_start + Vector2i(5, 0), trail_start])
		pairs.append([trail_start + Vector2i(0, -1), trail_start + Vector2i(5, 1)])
	for worker: Dictionary in world.workers.values():
		pairs.append([worker["position"], (world.buildings.values()[int(worker["id"]) % world.buildings.size()] as Dictionary)["entrance"]])
	var mismatches: int = 0
	var reach_mismatches: int = 0
	var found: int = 0
	for blockers: Dictionary in [{}, world._temporary_blockers_for(0)]:
		for pair: Array in pairs:
			var expected: Array[Vector2i] = _reference_find_path(world.grid, pair[0], pair[1], blockers)
			if Pathfinder.find_path(world.grid, pair[0], pair[1], blockers) != expected:
				mismatches += 1
			if not expected.is_empty():
				found += 1
			if blockers.is_empty() and Pathfinder.is_reachable(world.grid, pair[0], pair[1]) != (not expected.is_empty()):
				reach_mismatches += 1
	_check(found > pairs.size() and mismatches == 0 and reach_mismatches == 0,
		"Packed A* and reachability must equal the historical search for real demo routes (%d path, %d reach mismatches)" % [mismatches, reach_mismatches], failures)


## Drives real carrier traffic along a free straight lane until its links are
## established; returns the lane's first cell, or (-1, -1) when none exists.
static func _add_established_trail(world: World) -> Vector2i:
	var grid: Grid = world.grid
	for y: int in range(1, grid.size.y - 1):
		for x: int in range(grid.size.x - 6):
			var free: bool = true
			for offset: int in range(6):
				var cell := Vector2i(x + offset, y)
				free = free and grid.is_walkable(cell) and grid.is_roadable(cell) and not grid.roads.has(cell)
			if not free:
				continue
			for pass_index: int in range(40):
				for offset: int in range(1, 6):
					grid.record_carrier_traffic(Vector2i(x + offset, y), Vector2i(x + offset - 1, y), world.tick + pass_index)
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _test_nearest_matches_reference(failures: Array[String]) -> void:
	var world := World.new()
	world.setup_economy_demo()
	for _tick: int in range(120):
		world.step_tick()
	var goals: Array[Callable] = [
		func(cell: Vector2i) -> bool: return (cell.x * 7 + cell.y * 3) % 11 == 0,
		func(cell: Vector2i) -> bool: return world.grid.overlay_at(cell) != "",
		func(cell: Vector2i) -> bool: return cell == Vector2i(0, 0),
	]
	var mismatches: int = 0
	for pair: Array in _pairs(_walkable_cells(world.grid), 25, 11):
		for blockers: Dictionary in [{}, world._temporary_blockers_for(0)]:
			for goal: Callable in goals:
				if Pathfinder.find_path_to_nearest(world.grid, pair[0], goal, blockers) != _reference_nearest(world.grid, pair[0], goal, blockers):
					mismatches += 1
	_check(mismatches == 0, "Packed nearest-goal Dijkstra must equal the historical search (%d mismatches)" % mismatches, failures)


static func _test_incremental_updates_match_rebuild(failures: Array[String]) -> void:
	var world := World.new(Vector2i(22, 16))
	var grid: Grid = world.grid
	Pathfinder.find_path(grid, Vector2i(1, 1), Vector2i(20, 14))
	var index: Pathfinder.PathIndex = Pathfinder.path_index(grid)
	var rebuilds: int = index.rebuild_count
	var changes: Array[Callable] = [
		func(): grid.block(Vector2i(8, 7), 41),
		func(): grid.set_base_terrain(Vector2i(9, 7), "water"),
		func(): grid.set_vertex_height(Vector2i(12, 9), 5),
		func(): grid.set_vertex_height(Vector2i(12, 9), 1),
		func(): grid.unblock(Vector2i(8, 7)),
		func(): grid.set_base_terrain(Vector2i(9, 7), "grass"),
		func():
			for y: int in range(16):
				grid.set_base_terrain(Vector2i(14, y), "rock"),
	]
	var cells: Array[Vector2i] = []
	for y: int in range(0, 16, 3):
		for x: int in range(0, 22, 3):
			cells.append(Vector2i(x, y))
	var pairs: Array = _pairs(cells, 30, 3)
	var incremental_ok: bool = true
	for change: Callable in changes:
		change.call()
		index = Pathfinder.path_index(grid)
		var fresh := Pathfinder.PathIndex.new()
		fresh.rebuild(grid)
		incremental_ok = incremental_ok and index.walk == fresh.walk and index.edges == fresh.edges
		for pair: Array in pairs:
			incremental_ok = incremental_ok and Pathfinder.find_path(grid, pair[0], pair[1]) == _reference_find_path(grid, pair[0], pair[1], {})
	_check(incremental_ok and index.rebuild_count == rebuilds,
		"Tracked block, terrain and height changes must update locally to the same edges and routes as a full rebuild", failures)
	# A direct legacy edit without its tracked cells must still be detected.
	grid._base_terrain[grid.size.x * 3 + 3] = 2
	grid.connectivity_revision += 1
	var reference: Array[Vector2i] = _reference_find_path(grid, Vector2i(3, 2), Vector2i(3, 4), {})
	_check(Pathfinder.find_path(grid, Vector2i(3, 2), Vector2i(3, 4)) == reference and not grid.is_walkable(Vector2i(3, 3))
		and Pathfinder.path_index(grid).rebuild_count == rebuilds + 1,
		"An untracked connectivity revision must fall back to a full index rebuild", failures)
	var heights: PackedInt32Array = grid._vertex_heights.duplicate()
	heights[(grid.size.x + 1) * 6 + 6] = 9
	grid._vertex_heights = heights
	grid.invalidate_connectivity()
	_check(Pathfinder.find_path(grid, Vector2i(2, 6), Vector2i(9, 6)) == _reference_find_path(grid, Vector2i(2, 6), Vector2i(9, 6), {}),
		"Bulk terrain replacement followed by invalidate_connectivity must rebuild the index", failures)


static func _test_reentrant_nearest_goal(failures: Array[String]) -> void:
	var world := World.new()
	world.setup_economy_demo()
	var grid: Grid = world.grid
	var anchor: Vector2i = world.buildings.values()[0]["entrance"]
	# A goal test may itself search routes while the outer search is running.
	var goal := func(cell: Vector2i) -> bool:
		var route: Array[Vector2i] = Pathfinder.find_path(grid, cell, anchor)
		return route.size() == 6
	var reference_goal := func(cell: Vector2i) -> bool:
		return _reference_find_path(grid, cell, anchor, {}).size() == 6
	var start: Vector2i = _walkable_cells(grid)[40]
	_check(Pathfinder.find_path_to_nearest(grid, start, goal) == _reference_nearest(grid, start, reference_goal, {}),
		"Nested searches from a goal test must not disturb the outer search", failures)


# --- Historical reference implementation (pre-2026-09-14) -------------------

static func _reference_find_path(grid: Grid, start: Vector2i, goal: Vector2i, blockers: Dictionary) -> Array[Vector2i]:
	if start == goal:
		return []
	if not grid.is_walkable(start) or not grid.is_walkable(goal) or blockers.has(goal):
		return []
	var minimum_cost: int = grid.minimum_movement_cost()
	var frontier: Array[Dictionary] = []
	Pathfinder._heap_push(frontier, {"cell": start, "cost": 0, "priority": _reference_heuristic(start, goal, minimum_cost)})
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}
	while not frontier.is_empty():
		var entry: Dictionary = Pathfinder._heap_pop(frontier)
		var current: Vector2i = entry["cell"]
		var current_cost: int = int(entry["cost"])
		if current_cost != int(cost_so_far.get(current, -1)):
			continue
		if current == goal:
			return _reference_reconstruct(came_from, start, goal)
		for next_cell: Vector2i in grid.neighbors8(current, blockers):
			var new_cost: int = current_cost + grid.step_cost(current, next_cell)
			if not cost_so_far.has(next_cell) or new_cost < int(cost_so_far[next_cell]):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				Pathfinder._heap_push(frontier, {"cell": next_cell, "cost": new_cost,
					"priority": new_cost + _reference_heuristic(next_cell, goal, minimum_cost)})
	return []


static func _reference_nearest(grid: Grid, start: Vector2i, goal_test: Callable, blockers: Dictionary) -> Array[Vector2i]:
	if not grid.is_walkable(start):
		return []
	var frontier: Array[Dictionary] = []
	Pathfinder._heap_push(frontier, {"cell": start, "cost": 0, "priority": 0})
	var came_from: Dictionary = {start: start}
	var cost_so_far: Dictionary = {start: 0}
	while not frontier.is_empty():
		var entry: Dictionary = Pathfinder._heap_pop(frontier)
		var current: Vector2i = entry["cell"]
		var current_cost: int = int(entry["cost"])
		if current_cost != int(cost_so_far.get(current, -1)):
			continue
		if current != start and bool(goal_test.call(current)):
			return _reference_reconstruct(came_from, start, current)
		for next_cell: Vector2i in grid.neighbors8(current, blockers):
			var new_cost: int = current_cost + grid.step_cost(current, next_cell)
			if not cost_so_far.has(next_cell) or new_cost < int(cost_so_far[next_cell]):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				Pathfinder._heap_push(frontier, {"cell": next_cell, "cost": new_cost, "priority": new_cost})
	return []


static func _reference_heuristic(cell: Vector2i, goal: Vector2i, minimum_cost: int) -> int:
	var dx: int = absi(cell.x - goal.x)
	var dy: int = absi(cell.y - goal.y)
	var diagonal_steps: int = mini(dx, dy)
	return diagonal_steps * Grid.diagonal_duration_ticks(minimum_cost) + (maxi(dx, dy) - diagonal_steps) * minimum_cost


static func _reference_reconstruct(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = []
	var current: Vector2i = goal
	while current != start:
		reversed_path.append(current)
		current = came_from[current]
	reversed_path.reverse()
	return reversed_path
