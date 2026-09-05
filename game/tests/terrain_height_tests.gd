extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const Deposits = preload("res://scripts/simulation/resource_deposits.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_shared_corners_and_sampling(failures)
	_test_altitude_slope_and_material(failures)
	_test_paths_use_pass_and_ramp(failures)
	_test_foundations_exits_and_height_edit_guards(failures)
	_test_real_worker_replans_after_height_change(failures)
	_test_swaps_and_interactions_reject_cliffs(failures)
	_test_extraction_height_reach(failures)
	_test_save_round_trip_and_flat_migrations(failures)
	_test_invalid_heights_are_transactional(failures)
	return failures


static func _test_shared_corners_and_sampling(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(2, 2))
	var revision: int = grid.revision
	_expect(grid.set_vertex_height(Vector2i(1, 1), 8), "Height command accepts a shared interior vertex", failures)
	_expect(grid.revision == revision + 1, "Height changes invalidate the terrain cache", failures)
	for cell: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		_expect(grid.cell_corner_heights(cell).has(8), "All four touching cells share the authored corner", failures)
	_expect(is_equal_approx(grid.height_at(Vector2(0.75, 0.25)), 2.0)
		and is_equal_approx(grid.height_at(Vector2(0.25, 0.75)), 2.0)
		and is_equal_approx(grid.cell_height(Vector2i.ZERO), 4.0),
		"Height sampling follows both TL-BR triangles rather than a bilinear saddle", failures)
	grid.set_vertex_height(Vector2i(2, 2), 16)
	_expect(is_equal_approx(grid.height_at(Vector2(2, 2)), 16.0), "Last boundary vertex is sampled without indexing past the map", failures)
	_expect(not grid.set_vertex_height(Vector2i(-1, 0), 1)
		and not grid.set_vertex_height(Vector2i(3, 0), 1)
		and not grid.set_vertex_height(Vector2i.ZERO, -1)
		and not grid.set_vertex_height(Vector2i.ZERO, Grid.MAX_HEIGHT + 1),
		"Invalid vertices and out-of-range heights are rejected", failures)


static func _test_altitude_slope_and_material(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 3))
	_fill_height(grid, 20)
	_expect(grid.is_walkable(Vector2i(1, 1)) and grid.is_buildable(Vector2i(1, 1)), "High flat meadow remains walkable and buildable", failures)
	grid.set_vertex_height(Vector2i(1, 1), 22)
	_expect(grid.is_walkable(Vector2i(1, 1)) and not grid.is_buildable(Vector2i(1, 1)), "Gentle slope supports walking but not foundations", failures)
	grid.add_road(Vector2i(1, 1))
	_expect(grid.movement_duration_ticks(Vector2i(1, 1)) == 2, "Road movement retains its two-tick balance on slopes", failures)
	grid.set_vertex_height(Vector2i(1, 1), 24)
	_expect(not grid.is_walkable(Vector2i(1, 1)) and not grid.is_roadable(Vector2i(1, 1))
		and not grid.roads.has(Vector2i(1, 1)), "Steep slope blocks walking and removes an invalid road", failures)
	grid.set_base_terrain(Vector2i(3, 2), "water")
	grid.set_base_terrain(Vector2i(2, 2), "rock")
	_expect(not grid.is_walkable(Vector2i(3, 2)) and not grid.is_walkable(Vector2i(2, 2)),
		"Water and rock remain impassable at a level altitude", failures)


static func _test_paths_use_pass_and_ramp(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 6))
	for y: int in range(4):
		grid.set_vertex_height(Vector2i(3, y), 12)
	var start := Vector2i(1, 1)
	var goal := Vector2i(6, 1)
	var path: Array[Vector2i] = Pathfinder.find_path(grid, start, goal)
	_expect(path.size() > 5 and path.has(Vector2i(3, 4)), "A* goes around the mountain through the low pass", failures)
	var previous: Vector2i = start
	for cell: Vector2i in path:
		_expect(grid.can_traverse(previous, cell), "Every A* edge obeys terrain traversal", failures)
		previous = cell
	var nearest: Array[Vector2i] = Pathfinder.find_path_to_nearest(grid, start, func(cell: Vector2i) -> bool: return cell == goal)
	_expect(Pathfinder.path_cost(grid, path, start) == Pathfinder.path_cost(grid, nearest, start), "A* and nearest search agree around relief", failures)

	var ramp := Grid.new(Vector2i(8, 3))
	for y: int in range(4):
		for x: int in range(9):
			ramp.set_vertex_height(Vector2i(x, y), mini(x * 2, 10))
	var ramp_path: Array[Vector2i] = Pathfinder.find_path(ramp, Vector2i(0, 1), Vector2i(7, 1))
	_expect(ramp_path.size() == 7 and ramp.cell_height(Vector2i(7, 1)) == 10.0,
		"Workers can reach a high plateau via a gentle ramp", failures)
	_expect(not ramp.can_traverse(Vector2i(0, 1), Vector2i(2, 1))
		and ramp.can_traverse(Vector2i(0, 1), Vector2i(1, 2)), "Traversal rejects skipped steps but allows safe diagonals on a gentle ramp", failures)


static func _test_foundations_exits_and_height_edit_guards(failures: Array[String]) -> void:
	var world := World.new(Vector2i(7, 6))
	_fill_height(world.grid, 8)
	var school: int = world.place_building("school", Vector2i(3, 3))
	_expect(school != 0, "A school can be founded on a high plateau", failures)
	if school == 0:
		return
	var entrance: Vector2i = world.buildings[school]["entrance"]
	_expect(world.grid.can_use_building_exit(Vector2i(3, 3), entrance), "An occupied foundation still permits its valid exit", failures)
	_expect(not world.set_vertex_height(Vector2i(3, 3), 9)
		and not world.grid.set_vertex_height(Vector2i(3, 3), 9)
		and not world.set_vertex_height(entrance, 9), "Height authoring protects foundations and their entrance", failures)
	var worker: int = world.spawn_worker(Vector2i(1, 4))
	_expect(worker != 0 and not world.set_vertex_height(Vector2i(1, 4), 9), "Height authoring protects an occupied worker cell", failures)
	world.grid.set_vertex_height(Vector2i(6, 0), 20)
	_expect(world.spawn_worker(Vector2i(5, 0)) == 0
		and not world.can_place_building("warehouse", Vector2i(5, 0)), "Spawn and building commands reject steep terrain", failures)
	# Only the west side remains flat; the producer must never spawn into the
	# newly steep north/east/south cells, even when its preferred entrance is full.
	var exits_world := World.new(Vector2i(5, 5))
	var producer: int = exits_world.place_building("school", Vector2i(2, 2))
	exits_world.grid.set_vertex_height(Vector2i(2, 1), 12)
	exits_world.grid.set_vertex_height(Vector2i(4, 2), 12)
	exits_world.grid.set_vertex_height(Vector2i(2, 4), 12)
	_expect(exits_world._find_unit_spawn_cell(exits_world.buildings[producer]) == Vector2i(1, 2),
		"Training chooses a reachable level side rather than a steep exit", failures)


static func _test_real_worker_replans_after_height_change(failures: Array[String]) -> void:
	var world := World.new(Vector2i(7, 5))
	var start := Vector2i(0, 2)
	var goal := Vector2i(6, 2)
	var id: int = world.spawn_worker(start)
	var worker: Dictionary = world.workers[id]
	_expect(world._move_worker_to(worker, goal), "Cached route is created on the initially flat ground", failures)
	_expect(world.set_vertex_height(Vector2i(3, 2), 12), "Empty future route can change height while a worker is en route", failures)
	var previous: Vector2i = start
	var arrived: bool = false
	for step: int in range(160):
		world.step_tick()
		var current: Vector2i = worker["position"]
		if current != previous:
			_expect(world.grid.can_traverse(previous, current), "Real worker movement rechecks each cached edge after a terrain edit", failures)
			previous = current
		if current == goal:
			arrived = true
			break
	_expect(arrived, "The real worker replans and reaches its target around the new hill", failures)


static func _test_swaps_and_interactions_reject_cliffs(failures: Array[String]) -> void:
	var world := World.new(Vector2i(5, 3))
	var a: int = world.spawn_worker(Vector2i(1, 1))
	var b: int = world.spawn_worker(Vector2i(2, 1))
	world._move_worker_to(world.workers[a], Vector2i(3, 1))
	world._move_worker_to(world.workers[b], Vector2i(0, 1))
	# Bypass safe authoring to exercise movement's defensive validation.
	world.grid.set_vertex_height(Vector2i(3, 1), 12)
	_expect(not world._try_swap_workers(world.workers[a], b, Vector2i(2, 1)),
		"Swap cannot bypass a cliff even with stale paths", failures)
	var worker: Dictionary = world.workers[a]
	worker["target_cell"] = Vector2i(2, 1)
	worker["action"] = "deliver_plank"
	_expect(not world._can_interact_from_adjacent(worker, Vector2i(2, 1)),
		"Occupied-target delivery cannot reach through a cliff", failures)


static func _test_extraction_height_reach(failures: Array[String]) -> void:
	var world := World.new(Vector2i(5, 4))
	var target := Vector2i(2, 1)
	world.grid.set_base_terrain(target, "rock")
	var deposit: Dictionary = {"position": target, "resource": "stone", "amount": 8}
	_expect(world.grid.can_reach_resource(Vector2i(1, 1), target), "A worker can mine level rock from an adjacent edge", failures)
	world.grid.set_vertex_height(Vector2i(3, 2), 20)
	_expect(not world.grid.can_reach_resource(Vector2i(1, 1), target), "A high mineral surface is out of reach from the valley", failures)
	_expect(Deposits.candidate_work_cell(world, deposit, Vector2i(0, 1)) == Vector2i(-1, -1),
		"Miner task selection does not assign an unreachable high deposit", failures)
	var fake_worker: Dictionary = {"position": Vector2i(1, 1)}
	_expect(not Deposits._at_deposit(world, fake_worker, deposit), "Finishing extraction rechecks vertical reach", failures)


static func _test_save_round_trip_and_flat_migrations(failures: Array[String]) -> void:
	var world := World.new(Vector2i(6, 5))
	_fill_height(world.grid, 10)
	world.place_building("school", Vector2i(2, 2))
	world.spawn_worker(Vector2i(1, 3))
	world.place_road(Vector2i(4, 3))
	world.grid.set_vertex_height(Vector2i(6, 0), 24)
	var data: Dictionary = world.to_data()
	var restored := World.new()
	_expect(data["version"] == World.SAVE_VERSION and restored.from_data(JSON.parse_string(JSON.stringify(data))),
		"Current snapshot with a plateau, peak and entities loads through actual JSON", failures)
	_expect(restored.to_data() == data, "Current round trip preserves all shared corner heights and authored state", failures)
	var flat := World.new(Vector2i(4, 3))
	for version: int in range(1, 8):
		var legacy: Dictionary = flat.to_data()
		legacy["version"] = version
		legacy["terrain"].erase("corner_heights")
		var migrated := World.new()
		_expect(migrated.from_data(legacy), "Historical v%d snapshots remain loadable" % version, failures)
		for y: int in range(4):
			for x: int in range(5):
				_expect(migrated.grid.vertex_height(Vector2i(x, y)) == 0, "Historical v%d snapshot migrates to flat terrain" % version, failures)


static func _test_invalid_heights_are_transactional(failures: Array[String]) -> void:
	var world := World.new(Vector2i(5, 4))
	world.place_building("school", Vector2i(1, 1))
	world.spawn_worker(Vector2i(3, 2))
	var baseline: Dictionary = world.to_data()
	var bad_rows: Array = [null, {}, [], [[0]]]
	for rows: Variant in bad_rows:
		var malformed: Dictionary = JSON.parse_string(JSON.stringify(baseline))
		malformed["terrain"]["corner_heights"] = rows
		_expect(not world.from_data(malformed) and world.to_data() == baseline, "Malformed height array fails transactionally", failures)
	var invalid_values: Array = [-1, Grid.MAX_HEIGHT + 1, 1.5, "2", true, null, INF, NAN]
	for value: Variant in invalid_values:
		var malformed: Dictionary = JSON.parse_string(JSON.stringify(baseline))
		malformed["terrain"]["corner_heights"][0][0] = value
		_expect(not world.from_data(malformed) and world.to_data() == baseline, "Noninteger or out-of-range height fails transactionally", failures)
	var missing: Dictionary = baseline.duplicate(true)
	missing["terrain"].erase("corner_heights")
	_expect(not world.from_data(missing) and world.to_data() == baseline, "V8 requires explicit height data", failures)
	for vertex: Vector2i in [Vector2i(1, 1), Vector2i(3, 2)]:
		var invalid_entity: Dictionary = baseline.duplicate(true)
		invalid_entity["terrain"]["corner_heights"][vertex.y][vertex.x] = 20
		_expect(not world.from_data(invalid_entity) and world.to_data() == baseline,
			"Slope invalidating a saved building or worker rejects the entire snapshot", failures)


static func _fill_height(grid: Grid, height: int) -> void:
	for y: int in range(grid.size.y + 1):
		for x: int in range(grid.size.x + 1):
			grid.set_vertex_height(Vector2i(x, y), height)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
