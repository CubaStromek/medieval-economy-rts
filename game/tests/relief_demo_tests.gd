extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Demo = preload("res://scripts/simulation/relief_demo.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const TEST_COUNT: int = 3


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_landmarks_and_connections(failures)
	_test_logistics_climb_and_produce(failures)
	_test_save_and_continue(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_landmarks_and_connections(failures: Array[String]) -> void:
	var world = World.new(Demo.MAP_SIZE)
	Demo.setup(world)
	_check(world.grid.size == Demo.MAP_SIZE and world.buildings.size() == 6 and world.workers.size() == 8,
		"Relief demo must create every authored building and worker", failures)
	_check(world.grid.cell_height(Demo.LOWLAND) == 0.0 and world.grid.cell_height(Demo.PLATEAU) == Demo.PLATEAU_HEIGHT,
		"Relief demo must contain distinct lowland and elevated meadow", failures)
	_check(world.grid.cell_slope(Demo.RAMP) > 0 and world.grid.is_walkable(Demo.RAMP),
		"The meadow ramp must have a real but walkable gradient", failures)
	_check(not world.grid.is_walkable(Demo.RIDGE) and world.grid.cell_height(Demo.RIDGE) > Demo.PLATEAU_HEIGHT,
		"The rocky ridge must rise above the meadow and block movement", failures)
	_check(world.grid.is_walkable(Demo.PASS_CELL), "The mountain pass must be physically traversable", failures)
	_check(world.can_place_building("lumber_hut", Demo.LOWLAND_BUILD_SITE)
		and world.can_place_building("sawmill", Demo.PLATEAU_BUILD_SITE),
		"Both elevation levels must retain a flat legal expansion site", failures)
	var warehouse: Dictionary = world.buildings[world.building_id_at(Demo.BUILDING_CELLS["warehouse"])]
	var sawmill: Dictionary = world.buildings[world.building_id_at(Demo.BUILDING_CELLS["sawmill"])]
	var route: Array[Vector2i] = Pathfinder.find_path(world.grid, warehouse["entrance"], sawmill["entrance"])
	_check(not route.is_empty() and route.has(Demo.RAMP),
		"The production route must use the authored uphill road", failures)
	var crossing: Array[Vector2i] = Pathfinder.find_path(world.grid, Vector2i(18, 5), Vector2i(27, 5))
	var crossed_pass: bool = false
	for cell: Vector2i in crossing:
		if cell.x == Demo.PASS_CELL.x and cell.y >= 11 and cell.y <= 12:
			crossed_pass = true
	_check(not crossing.is_empty() and crossed_pass,
		"A route across the ridge must detour through its two-cell pass", failures)


static func _test_logistics_climb_and_produce(failures: Array[String]) -> void:
	var world = World.new(Demo.MAP_SIZE)
	Demo.setup(world)
	var carrier_on_ramp: bool = false
	var loaded_carrier_on_plateau: bool = false
	for step: int in range(2000):
		world.step_tick()
		for worker: Dictionary in world.workers.values():
			if worker["type"] != "carrier":
				continue
			var cell: Vector2i = worker["position"]
			if world.grid.cell_slope(cell) > 0:
				carrier_on_ramp = true
			if world.grid.cell_height(cell) >= Demo.PLATEAU_HEIGHT and worker["carrying"] == "log":
				loaded_carrier_on_plateau = true
	_check(carrier_on_ramp and loaded_carrier_on_plateau,
		"Real carriers must climb a slope and deliver harvested logs onto the plateau", failures)
	_check(world.stored_amount("plank") > int(Demo.STARTING_STOCK["plank"]),
		"The height-aware production loop must return newly made planks to the warehouse", failures)


static func _test_save_and_continue(failures: Array[String]) -> void:
	var world = World.new(Demo.MAP_SIZE)
	Demo.setup(world)
	for step: int in range(110):
		world.step_tick()
	var restored = World.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary
	if not restored.from_data(data):
		failures.append("The authored relief demo must load with its in-flight economy")
		return
	_check(restored.grid.cell_height(Demo.PLATEAU) == Demo.PLATEAU_HEIGHT
		and restored.grid.cell_height(Demo.RIDGE) == world.grid.cell_height(Demo.RIDGE)
		and restored.grid.is_walkable(Demo.PASS_CELL),
		"Saving must preserve the plateau, rocky height and usable mountain pass", failures)
	_check(restored.stored_amount("plank") == world.stored_amount("plank")
		and restored.pipeline_amount("log") == world.pipeline_amount("log"),
		"Loading the relief map must preserve stored and in-flight wood stock", failures)
	# Save files intentionally rebuild movement/tasks, so continuation timing
	# need not match the unsaved worker paths. Verify the actual resumed output.
	var planks_before: int = restored.stored_amount("plank")
	for step: int in range(1500):
		restored.step_tick()
		if restored.stored_amount("plank") > planks_before:
			break
	_check(restored.stored_amount("plank") > planks_before,
		"The loaded relief economy must resume work and deliver new planks", failures)
