extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Level = preload("res://scripts/simulation/test_level.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 4


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_default_start_and_reset(host, failures)
	_test_first_carrier_supplies_training(failures)
	_test_save_preserves_start_and_paid_training(failures)
	_test_start_bootstraps_wood_and_stone(failures)
	return failures


static func _test_default_start_and_reset(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	_check(main.demo_kind == "test", "The default game scene must open the minimal test level", failures)
	_check_initial_world(main.world, failures)
	var school_id: int = main.world.building_id_at(Vector2i(3, 16))
	if school_id != 0:
		main.world.queue_unit_training(school_id, "carrier")
		main.world.step_tick()
	main.selected_cell = Vector2i(3, 16)
	main.accumulator = 0.05
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_R
		event.physical_keycode = KEY_R
		event.pressed = pressed
		viewport.push_input(event, true)
	_check(main.world.tick == 0 and main.accumulator == 0.0 and main.selected_cell == Vector2i(-1, -1),
		"The reset shortcut must discard test-level progress and clear selection", failures)
	_check_initial_world(main.world, failures)
	viewport.free()


static func _test_first_carrier_supplies_training(failures: Array[String]) -> void:
	var world := World.new(Level.MAP_SIZE)
	Level.setup(world)
	for _tick: int in range(100):
		world.step_tick()
	_check(world.workers.is_empty() and int(world.resource_stock("gold")["total"]) == 50,
		"An untouched test level must neither spawn citizens nor consume starter gold", failures)
	var school_id: int = world.building_id_at(Vector2i(3, 16))
	if school_id == 0:
		failures.append("The test level requires its starter school for training")
		return
	_check(world.queue_unit_training(school_id, "carrier"), "The starter school must accept the first carrier", failures)
	for _tick: int in range(300):
		world.step_tick()
		if world.workers.size() == 1:
			break
	_check(world.workers.size() == 1 and _has_role(world, "carrier"),
		"The seeded school gold must train a first carrier without an existing delivery worker", failures)
	_check(int(world.resource_stock("gold")["total"]) == 49,
		"The first carrier must consume exactly one of the fifty starter gold", failures)
	_check(world.queue_unit_training(school_id, "builder"), "The starter school must accept another profession", failures)
	var saw_gold_in_transit: bool = false
	for _tick: int in range(1000):
		world.step_tick()
		if int(world.resource_stock("gold")["carried"]) > 0:
			saw_gold_in_transit = true
		if world.workers.size() == 2:
			break
	_check(saw_gold_in_transit and world.stored_amount("gold") < 49,
		"The first carrier must physically bring further gold from the warehouse", failures)
	_check(world.workers.size() == 2 and _has_role(world, "builder")
		and int(world.resource_stock("gold")["total"]) == 48,
		"Delivered gold must finish a second citizen with exactly two gold consumed overall", failures)


static func _test_save_preserves_start_and_paid_training(failures: Array[String]) -> void:
	var source := World.new(Level.MAP_SIZE)
	Level.setup(source)
	var restored := World.new()
	if not restored.from_data(_json_snapshot(source)):
		failures.append("The minimal test level must survive a JSON snapshot")
		return
	_check_initial_world(restored, failures)
	var school_id: int = restored.building_id_at(Vector2i(3, 16))
	if school_id == 0:
		return
	restored.queue_unit_training(school_id, "carrier")
	restored.step_tick()
	var remaining: int = int(restored.buildings[school_id]["training_remaining"])
	if not source.from_data(_json_snapshot(restored)):
		failures.append("A paid first citizen must survive a JSON snapshot")
		return
	_check(bool(source.buildings[school_id]["training_paid"])
		and int(source.buildings[school_id]["training_remaining"]) == remaining,
		"Loading must preserve the first citizen's payment and exact training progress", failures)
	for _tick: int in range(300):
		source.step_tick()
		if source.workers.size() == 1:
			break
	_check(source.workers.size() == 1 and _has_role(source, "carrier")
		and int(source.resource_stock("gold")["total"]) == 49,
		"Loading paid training must produce the first carrier without spending another gold", failures)


static func _check_initial_world(world: World, failures: Array[String]) -> void:
	_check(world.grid.size == Vector2i(28, 22) and world.economy_enabled,
		"The test level must retain its authored map size and normal economy rules", failures)
	_check(world.buildings.size() == 2 and world.workers.is_empty() and world.grid.roads.is_empty(),
		"The test level must start with exactly two buildings, no citizens and no built roads", failures)
	for type: String in {"warehouse": Vector2i(7, 16), "school": Vector2i(3, 16)}:
		var cell: Vector2i = Vector2i(7, 16) if type == "warehouse" else Vector2i(3, 16)
		var id: int = world.building_id_at(cell)
		if id == 0:
			failures.append("The test level is missing its starter " + type)
			continue
		var building: Dictionary = world.buildings[id]
		_check(building["type"] == type and world.is_building_complete(building)
			and (building["training_queue"] as Array).is_empty(),
			"The starter " + type + " must be complete and have no queued training", failures)
	for resource: String in world.catalog.resources:
		var expected: int = 50 if resource == "gold" else 0
		if resource in ["log", "plank", "stone"]:
			expected = 20
		_check(int(world.resource_stock(resource)["total"]) == expected,
			"Initial stock must be fifty gold, twenty each of logs/planks/stone and zero other wares: " + resource, failures)
	_check(world.resource_stock("log") == {"warehouse": 20, "buildings": 0, "carried": 0, "total": 20},
		"All twenty starter logs must be stored in the warehouse", failures)
	_check(world.resource_stock("gold") == {"warehouse": 49, "buildings": 1, "carried": 0, "total": 50},
		"One of the fifty starter gold must be in the school to enable the first carrier", failures)
	for resource: String in ["plank", "stone"]:
		_check(world.resource_stock(resource) == {"warehouse": 20, "buildings": 0, "carried": 0, "total": 20},
			"Starter construction supplies must be physical warehouse stock: " + resource, failures)
	_check(world.deposits.size() == 4, "The starter map must contain two finite stone deposits and two fish shoals", failures)
	for cell: Vector2i in [Vector2i(20, 16), Vector2i(20, 17)]:
		var id: int = world.deposit_id_at(cell)
		_check(id != 0 and world.deposits[id]["resource"] == "stone" and int(world.deposits[id]["amount"]) == 90,
			"Starter deposits must persist at the accessible western foot of the ridge", failures)
	_check(world.can_place_building("quarry", Vector2i(17, 16)),
		"A quarry must be placeable within working reach of the starter stone deposits", failures)
	for cell: Vector2i in Level.FISH_DEPOSIT_CELLS:
		var id: int = world.deposit_id_at(cell)
		_check(id != 0 and world.deposits[id]["resource"] == "fish" and int(world.deposits[id]["amount"]) == Level.FISH_PER_DEPOSIT,
			"The existing starter pond must preserve its finite fish shoals", failures)
	_check(world.can_place_building("fisher_hut", Level.FISHER_HUT_SITE),
		"The eastern pond bank must allow a player-built fishing hut within range of both shoals", failures)


static func _test_start_bootstraps_wood_and_stone(failures: Array[String]) -> void:
	var world := World.new(Level.MAP_SIZE)
	Level.setup(world)
	var school_id: int = world.building_id_at(Vector2i(3, 16))
	# Exercise only player commands: no spawned workers, free materials, manually
	# completed buildings, custom recipes or speed-up of the simulation rules.
	for role: String in ["carrier", "builder", "carrier", "lumberjack", "carpenter"]:
		_check(world.queue_unit_training(school_id, role), "School must accept starter role " + role, failures)
	var sites: Dictionary = {}
	var cells: Dictionary = {"lumber_hut": Vector2i(11, 13), "sawmill": Vector2i(11, 17), "quarry": Vector2i(17, 16)}
	for type: String in cells:
		var cell: Vector2i = cells[type]
		var id: int = world.place_building(type, cell)
		if id == 0:
			failures.append("Cannot place starter construction: " + type)
			return
		sites[type] = id
		_check(not world.is_building_complete(world.buildings[id]), "Starter expansion must require construction: " + type, failures)
	_check(world.stored_amount("plank") == 20 and world.stored_amount("stone") == 20,
		"Blueprint placement must not remotely consume starter materials", failures)
	var success: bool = false
	var mason_queued: bool = false
	for _tick: int in range(6500):
		world.step_tick()
		# School has five queue slots. Add the sixth citizen when the first
		# leaves school, exactly as the player can through the training UI.
		if not mason_queued and not world.workers.is_empty():
			mason_queued = world.queue_unit_training(school_id, "stonemason")
		var all_complete: bool = true
		for id: int in sites.values():
			all_complete = all_complete and world.is_building_complete(world.buildings[id])
		var trees_remaining: int = 0
		for tree: Dictionary in world.trees.values():
			trees_remaining += int(tree["amount"])
		if all_complete and trees_remaining < 60 and world.stored_amount("plank") > 10 and world.stored_amount("stone") > 13:
			success = true
			break
	_check(success, "The actual starter level must build and operate all three material producers and return newly produced planks/stone to the warehouse within 6500 ticks", failures)
	_check(mason_queued, "Training a first carrier must free a queue slot for the sixth starter citizen", failures)
	_check(world.workers.size() == 6 and int(world.resource_stock("gold")["total"]) == 44,
		"Bootstrap must use exactly six paid citizens without starvation or free training", failures)
	for type: String in sites:
		var expected: Dictionary = {"plank": 4, "stone": 3} if type == "sawmill" else {"plank": 3, "stone": 2}
		_check(world.buildings[int(sites[type])]["construction_delivered"] == expected,
			"Carriers must deliver exactly the authentic construction cost: " + type, failures)
	var restored := World.new()
	_check(restored.from_data(_json_snapshot(world)), "The bootstrapped live settlement must remain saveable", failures)


static func _has_role(world: World, role: String) -> bool:
	for worker: Dictionary in world.workers.values():
		if worker["type"] == role:
			return true
	return false


static func _json_snapshot(world: World) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
