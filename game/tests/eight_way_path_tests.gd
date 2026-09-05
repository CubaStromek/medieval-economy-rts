extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const Workplaces = preload("res://scripts/simulation/workplaces.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_eight_neighbors_and_cardinal_interactions,
		_test_open_diagonal_routes,
		_test_distance_and_surface_duration,
		_test_static_corner_guards,
		_test_dynamic_corner_guards,
		_test_diagonal_ramps_and_cliffs,
		_test_weighted_road_route,
		_test_nearest_goal_by_eight_way_cost,
		_test_octile_astar_matches_dijkstra,
		_test_workplaces_use_eight_way_cost,
	]:
		test.call(failures)
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_eight_neighbors_and_cardinal_interactions(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 3))
	var center := Vector2i(1, 1)
	_expect(Grid.CARDINAL_DIRECTIONS.size() == 4 and Grid.MOVEMENT_DIRECTIONS.size() == 8,
		"Walking gains eight directions without changing four-sided building/resource rules", failures)
	_expect(grid.neighbors(center).size() == 4 and grid.neighbors8(center).size() == 8
		and grid.neighbors8(Vector2i.ZERO).size() == 3, "Neighbors remain inside the map", failures)
	_expect(not grid.can_traverse(center, center) and not grid.can_traverse(Vector2i.ZERO, Vector2i(2, 1)),
		"A step cannot stay in place or skip cells", failures)
	_expect(not grid.can_reach_resource(Vector2i.ZERO, Vector2i.ONE)
		and not grid.can_use_building_exit(Vector2i.ZERO, Vector2i.ONE),
		"Diagonal walking does not permit reaching through a building or resource corner", failures)


static func _test_open_diagonal_routes(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(6, 6))
	var start := Vector2i.ZERO
	var goal := Vector2i(4, 4)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, start, goal)
	_expect(path == [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), goal],
		"An open diagonal route takes four diagonal steps instead of eight cardinal steps", failures)
	_expect(Pathfinder.path_cost(grid, path, start) == 36,
		"The first diagonal step contributes its full nine-tick travel duration", failures)
	var reverse: Array[Vector2i] = Pathfinder.find_path(grid, goal, start)
	_expect(reverse.size() == 4 and Pathfinder.path_cost(grid, reverse, goal) == 36,
		"Diagonal travel works in both directions with symmetric grass cost", failures)


static func _test_distance_and_surface_duration(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(5, 5))
	grid.add_dirt_trail(Vector2i(2, 2))
	grid.add_road(Vector2i(3, 3))
	for from: Vector2i in [Vector2i(1, 2), Vector2i(1, 1)]:
		grid.set_trail_link(from, Vector2i(2, 2), grid.carrier_passes_to_form_trail(), 0, true)
	for entry: Array in [[Vector2i(1, 1), 6, 9], [Vector2i(2, 2), 4, 6], [Vector2i(3, 3), 2, 3]]:
		var to: Vector2i = entry[0]
		_expect(grid.step_duration_ticks(to - Vector2i.RIGHT, to) == int(entry[1])
			and grid.step_duration_ticks(to - Vector2i.ONE, to) == int(entry[2]),
			"Grass, mud and stone all account for the longer diagonal distance", failures)
		_expect(grid.step_cost(to - Vector2i.ONE, to) == grid.step_duration_ticks(to - Vector2i.ONE, to),
			"Routing and physical movement share the exact same integer step duration", failures)
	grid.configure_movement({"terrain": {"grass": {"move_ticks": 13}}})
	_expect(grid.step_cost(Vector2i.ZERO, Vector2i.ONE) == 19,
		"Custom movement profiles also round diagonal durations up consistently", failures)


static func _test_static_corner_guards(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 2))
	grid.block(Vector2i.RIGHT, 101)
	_expect(not grid.can_traverse(Vector2i.ZERO, Vector2i.ONE),
		"A diagonal may not clip a single occupied building corner", failures)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, Vector2i.ZERO, Vector2i.ONE)
	_expect(path == [Vector2i.DOWN, Vector2i.ONE], "A clear cardinal detour remains available beside a corner", failures)
	grid.set_base_terrain(Vector2i.DOWN, "water")
	_expect(Pathfinder.find_path(grid, Vector2i.ZERO, Vector2i.ONE).is_empty(),
		"Two touching blockers cannot be crossed diagonally", failures)
	grid.unblock(Vector2i.RIGHT)
	grid.set_base_terrain(Vector2i.DOWN, "grass")
	_expect(grid.can_traverse(Vector2i.ZERO, Vector2i.ONE), "Removing corner blockers reopens the diagonal", failures)


static func _test_dynamic_corner_guards(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 3))
	var start := Vector2i.ZERO
	var goal := Vector2i.ONE
	var blockers: Dictionary = {Vector2i.RIGHT: 8}
	_expect(grid.can_traverse(start, goal) and not grid.can_step(start, goal, blockers),
		"A worker beside a diagonal blocks the narrow corner without changing terrain", failures)
	_expect(Pathfinder.find_path(grid, start, goal, blockers) == [Vector2i.DOWN, goal],
		"A* uses the safe cardinal detour around an occupied diagonal flank", failures)
	blockers[Vector2i.DOWN] = 9
	_expect(Pathfinder.find_path(grid, start, goal, blockers).is_empty()
		and Pathfinder.find_path_to_nearest(grid, start, func(cell: Vector2i) -> bool: return cell == goal, blockers).is_empty(),
		"A* and nearest search both reject squeezing between two workers", failures)
	_expect(not grid.can_step(start, Vector2i.DOWN, {Vector2i.DOWN: 1}),
		"Temporary blockers still protect cardinal destinations", failures)
	_expect(grid.can_step(start, goal, {start: 1}), "The moving worker's own source occupancy is harmless", failures)


static func _test_diagonal_ramps_and_cliffs(failures: Array[String]) -> void:
	var ramp := Grid.new(Vector2i(4, 4))
	for y: int in range(5):
		for x: int in range(5):
			ramp.set_vertex_height(Vector2i(x, y), x * 2)
	_expect(ramp.can_traverse(Vector2i.ZERO, Vector2i.ONE),
		"A gentle ramp can be walked diagonally", failures)
	var grid := Grid.new(Vector2i(3, 3))
	grid.set_vertex_height(Vector2i(2, 0), Grid.MAX_WALK_SLOPE + 1)
	_expect(grid.is_walkable(Vector2i.ZERO) and grid.is_walkable(Vector2i.ONE)
		and not grid.can_traverse(Vector2i.ZERO, Vector2i.ONE),
		"Walkable diagonal endpoints cannot bypass a steep flank", failures)
	_expect(Pathfinder.find_path(grid, Vector2i.ZERO, Vector2i.ONE) == [Vector2i.DOWN, Vector2i.ONE],
		"Pathfinding goes around the steep flank through the level side", failures)


static func _test_weighted_road_route(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 6))
	for x: int in range(8):
		grid.add_road(Vector2i(x, 2))
	var start := Vector2i(0, 4)
	var goal := Vector2i(7, 4)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, start, goal)
	_expect(path.has(Vector2i(3, 2)) and Pathfinder.path_cost(grid, path, start) < 7 * 6,
		"Eight-way routing still prefers a cheaper stone-road detour over direct grass", failures)
	var previous: Vector2i = start
	var duration: int = 0
	for cell: Vector2i in path:
		_expect(grid.can_step(previous, cell), "Every selected weighted edge is traversable", failures)
		duration += grid.step_duration_ticks(previous, cell)
		previous = cell
	_expect(duration == Pathfinder.path_cost(grid, path, start),
		"Summed real step durations exactly match the selected route cost", failures)


static func _test_nearest_goal_by_eight_way_cost(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var diagonal := Vector2i.ONE
	var cardinal := Vector2i(2, 0)
	var goal_test: Callable = func(cell: Vector2i) -> bool: return cell == diagonal or cell == cardinal
	var path: Array[Vector2i] = Pathfinder.find_path_to_nearest(grid, Vector2i.ZERO, goal_test)
	_expect(path == [diagonal] and Pathfinder.path_cost(grid, path, Vector2i.ZERO) == 9,
		"Nearest-goal search recognizes the nine-tick diagonal before twelve-tick grass", failures)
	grid.add_road(Vector2i.RIGHT)
	grid.add_road(cardinal)
	path = Pathfinder.find_path_to_nearest(grid, Vector2i.ZERO, goal_test)
	_expect(path == [Vector2i.RIGHT, cardinal] and Pathfinder.path_cost(grid, path, Vector2i.ZERO) == 4,
		"A cheaper cardinal road goal beats a geometrically closer diagonal grass goal", failures)


static func _test_octile_astar_matches_dijkstra(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(7, 6))
	grid.set_base_terrain(Vector2i(3, 1), "water")
	grid.set_base_terrain(Vector2i(3, 2), "rock")
	grid.block(Vector2i(2, 4), 88)
	for x: int in range(7):
		grid.add_road(Vector2i(x, 0))
		grid.add_dirt_trail(Vector2i(x, 5))
	var points: Array[Vector2i] = [Vector2i.ZERO, Vector2i(6, 0), Vector2i(1, 2), Vector2i(5, 3), Vector2i(0, 5), Vector2i(6, 5)]
	for grass_ticks: int in [1, 6, 13]:
		grid.configure_movement({"terrain": {"grass": {"move_ticks": grass_ticks}}})
		for start: Vector2i in points:
			for goal: Vector2i in points:
				var blockers: Dictionary = {Vector2i(4, 3): 11}
				var astar: Array[Vector2i] = Pathfinder.find_path(grid, start, goal, blockers)
				var dijkstra: Array[Vector2i] = Pathfinder.find_path_to_nearest(
					grid, start, func(cell: Vector2i) -> bool: return cell == goal, blockers
				)
				_expect(Pathfinder.path_cost(grid, astar, start) == Pathfinder.path_cost(grid, dijkstra, start),
					"Octile A* stays optimal against exhaustive Dijkstra with custom speeds and blockers", failures)


static func _test_workplaces_use_eight_way_cost(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var targets: Dictionary = {10: Vector2i.ONE, 20: Vector2i(2, 0)}
	_expect(Workplaces._nearest_vacancy(grid, Vector2i.ZERO, targets) == 10,
		"Home selection accounts for a shorter diagonal journey", failures)
	grid.add_road(Vector2i.RIGHT)
	grid.add_road(Vector2i(2, 0))
	_expect(Workplaces._nearest_vacancy(grid, Vector2i.ZERO, targets) == 20,
		"Home selection honors faster roads under eight-way movement", failures)
	_expect(Workplaces._nearest_vacancy(grid, Vector2i.ZERO, {9: Vector2i.ONE, 3: Vector2i.ONE}) == 3,
		"Equal-cost vacancies retain the deterministic building-ID tie break", failures)
