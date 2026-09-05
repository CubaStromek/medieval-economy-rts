extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 2


static func run() -> Array[String]:
	var failures: Array[String] = []
	for expanded: bool in [false, true]:
		var world := World.new()
		world.setup_demo()
		if expanded:
			var school: int = world.place_building("school", Vector2i(3, 3))
			for profession: String in ["carrier", "lumberjack", "gardener", "carrier", "lumberjack"]:
				if not world.queue_unit_training(school, profession):
					failures.append("Invariant fixture must train all five workers")
		var halfway_planks: int = 0
		for tick_index: int in range(3000):
			world.step_tick()
			_check_world(world, failures)
			if world.tick == 1500:
				halfway_planks = world.stored_amount("plank")
			if world.tick % 777 == 0:
				var restored := World.new()
				var snapshot: Dictionary = JSON.parse_string(JSON.stringify(world.to_data()))
				if not restored.from_data(snapshot):
					failures.append("Live snapshot must remain loadable at tick %d" % world.tick)
				else:
					_check_world(restored, failures)
					for resumed_tick: int in range(10):
						restored.step_tick()
						_check_world(restored, failures)
			if not failures.is_empty():
				return failures
		if halfway_planks <= 0 or world.stored_amount("plank") <= halfway_planks:
			failures.append("Economy must keep producing throughout the long run (expanded=%s)" % expanded)
		if expanded and world.workers.size() != 8:
			failures.append("Long run must include all five completed school trainees")
	return failures


static func _check_world(world: World, failures: Array[String]) -> void:
	var outdoor_count: int = 0
	for id: int in world.workers:
		var worker: Dictionary = world.workers[id]
		if world.is_worker_inside(worker):
			var building: Dictionary = world.buildings.get(int(worker["inside_building_id"]), {})
			_check(not building.is_empty() and world.is_building_complete(building)
				and building.get("entrance") == worker["position"], "Indoor worker retains a valid completed building", world, failures)
			_check(not world.tile_reservations.values().has(id), "Indoor workers never reserve outdoor tiles", world, failures)
		else:
			outdoor_count += 1
			_check(int(world.tile_reservations.get(worker["position"], 0)) == id, "Outdoor worker owns its current tile", world, failures)
		_check(world.grid.is_walkable(worker["position"]), "Worker remains on walkable terrain", world, failures)
		var task_id: int = int(worker["task_id"])
		if task_id != 0:
			var task: Dictionary = world.task_board._tasks.get(task_id, {})
			_check(int(task.get("reserved_by", 0)) == id, "Worker's task exists and has the same owner", world, failures)
		var plant_target: Vector2i = worker["plant_target"]
		if plant_target != Vector2i(-1, -1):
			_check(int(world.planting_reservations.get(plant_target, 0)) == id, "Worker owns its planting target", world, failures)
	_check(world.tile_reservations.size() == outdoor_count, "Exactly one tile reservation per outdoor worker", world, failures)
	for cell: Vector2i in world.planting_reservations:
		var owner: int = int(world.planting_reservations[cell])
		var worker: Dictionary = world.workers.get(owner, {})
		_check(worker.get("plant_target") == cell and worker.get("action") == "plant_sapling",
			"Planting reservation points back to an active gardener", world, failures)
	for task: Dictionary in world.task_board._tasks.values():
		var owner: int = int(task["reserved_by"])
		if owner != 0:
			var worker: Dictionary = world.workers.get(owner, {})
			_check(int(worker.get("task_id", 0)) == int(task["id"]), "Task owner points back to its task", world, failures)
		var source_exists: bool = (
			world.trees.has(int(task["source_id"])) if task["kind"] == "harvest_tree"
			else world.buildings.has(int(task["source_id"]))
		)
		_check(source_exists, "Tasks retain a live source", world, failures)
	for building: Dictionary in world.buildings.values():
		for field: String in ["inputs", "outputs", "storage"]:
			for amount: Variant in (building[field] as Dictionary).values():
				_check(int(amount) >= 0, "Inventory stays nonnegative", world, failures)
	for tree: Dictionary in world.trees.values():
		_check(int(tree["amount"]) > 0, "Trees retain positive harvestable amounts", world, failures)


static func _check(condition: bool, message: String, world: World, failures: Array[String]) -> void:
	if not condition:
		failures.append("tick %d: %s" % [world.tick, message])
