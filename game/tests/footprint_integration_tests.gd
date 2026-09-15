extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const ClassicTests = preload("res://tests/classic_economy_tests.gd")
const TEST_COUNT: int = 3


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_full_catalog_village(failures)
	_test_all_recipes_with_real_footprints(failures)
	_test_real_door_home_and_work(failures)
	return failures


static func _test_full_catalog_village(failures: Array[String]) -> void:
	var world := World.new()
	world.setup_economy_demo()
	_check(world.buildings.size() == 29 and world.grid.blocked_by.size() == 238,
		"The production economy demo must represent all 29 types across 29 full masks (238 occupied tiles)", failures)
	var warehouse: Dictionary = world.buildings[world._first_building("warehouse")]
	for building: Dictionary in world.buildings.values():
		_check(int(building["footprint_version"]) == (2 if building["type"] == "lumber_hut" else 1),
			"Every new demo building uses its current authored geometry revision", failures)
		var route: Array[Vector2i] = Pathfinder.find_path(world.grid, warehouse["entrance"], building["entrance"])
		_check(building["id"] == warehouse["id"] or not route.is_empty(),
			"Every full-size demo doorway connects to the warehouse: " + building["type"], failures)
	for _tick: int in range(160):
		world.step_tick()
		for worker: Dictionary in world.workers.values():
			_check(not world.grid.blocked_by.has(worker["position"]),
				"Live demo citizens must stay outside every occupied footprint tile", failures)
	var restored := World.new()
	_check(restored.from_data(JSON.parse_string(JSON.stringify(world.to_data()))),
		"The active full-catalog economy must survive JSON save/load", failures)
	_check(restored.grid.blocked_by == world.grid.blocked_by,
		"Restoring the full village must rebuild exactly all occupied cells", failures)


static func _test_all_recipes_with_real_footprints(failures: Array[String]) -> void:
	for recipe_id: String in ClassicTests.EXPECTED_RECIPES:
		var expected: Array = ClassicTests.EXPECTED_RECIPES[recipe_id]
		var world := World.new(Vector2i(14, 12))
		var id: int = world.place_building(expected[0], Vector2i(5, 5))
		if id == 0:
			failures.append("Cannot author real production footprint: " + expected[0])
			continue
		var building: Dictionary = world.buildings[id]
		for resource: String in expected[2]:
			building["inputs"][resource] = expected[2][resource]
		world.economy_enabled = true
		world.queue_production(id, recipe_id)
		var worker_id: int = world.spawn_worker(Vector2i(2, 8), expected[1])
		_check(worker_id > 0, "Real recipe fixture must spawn its operator", failures)
		var produced: bool = false
		for _tick: int in range(1100):
			world.step_tick()
			var actual: Dictionary = {}
			for resource: String in building["outputs"]:
				if int(building["outputs"][resource]) > 0:
					actual[resource] = building["outputs"][resource]
			if actual == expected[3]:
				produced = true
				break
		_check(produced, "A specialist must reach the authored door and complete " + recipe_id, failures)
		for resource: String in expected[2]:
			_check(int(building["inputs"].get(resource, 0)) == 0, "A real-footprint recipe consumes its input exactly once", failures)


static func _test_real_door_home_and_work(failures: Array[String]) -> void:
	var world := World.new(Vector2i(18, 14))
	var id: int = world.place_building("lumber_hut", Vector2i(6, 6))
	var worker_id: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", id)
	var worker: Dictionary = world.workers[worker_id]
	# A personal pause sends the resident home through normal routing.
	world.set_worker_enabled(worker_id, false)
	for _tick: int in range(200):
		world.step_tick()
		if world.is_worker_inside(worker):
			break
	_check(int(worker.get("inside_building_id", 0)) == id and worker["position"] == world.buildings[id]["entrance"],
		"A real hut resident must reach the offset front door before going inside", failures)
	world.set_worker_enabled(worker_id, true)
	world.add_tree(Vector2i(10, 9), 3)
	for _tick: int in range(160):
		world.step_tick()
		if int(worker.get("inside_building_id", 0)) == 0 and worker["position"] != world.buildings[id]["entrance"]:
			break
	_check(int(worker.get("inside_building_id", 0)) == 0,
		"New work must release the resident through the real front door into outdoor work", failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
