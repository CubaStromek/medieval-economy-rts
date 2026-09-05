extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 15


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_specialists_gate_production,
		_test_empty_inputs_wait,
		_test_bread_batch_timing,
		_test_field_sowing_growth_and_harvest,
		_test_farmers_reserve_distinct_fields,
		_test_trained_farmers_keep_distinct_workplaces,
		_test_full_chain_reaches_warehouse,
		_test_warehouse_supplies_later_consumer,
		_test_save_resumes_consumed_batch,
		_test_save_preserves_carried_wares,
		_test_output_backpressure,
		_test_input_capacity_with_competing_deliveries,
		_test_terrain_and_field_placement,
		_test_new_professions_train_fifo,
		_test_field_save_and_legacy_migration,
	]:
		test.call(failures)
	return failures


static func _advance(world: World, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: World, condition: Callable, ticks: int = 1000) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _stock(building: Dictionary, field: String, resource: String) -> int:
	return int((building[field] as Dictionary).get(resource, 0))


static func _staff(world: World, building_id: int, profession: String) -> int:
	return world.spawn_worker(world.buildings[building_id]["entrance"], profession,
		building_id if profession in ["farmer", "lumberjack"] else 0)


static func _test_specialists_gate_production(failures: Array[String]) -> void:
	var world := World.new(Vector2i(16, 10))
	world.grid.set_base_terrain(Vector2i(12, 2), "rock")
	world.add_deposit(Vector2i(12, 2), "stone", 8)
	var quarry: int = world.place_building("quarry", Vector2i(10, 2))
	var farm: int = world.place_building("farm", Vector2i(2, 2))
	var field: int = world.place_field(Vector2i(4, 2))
	world.spawn_worker(Vector2i(1, 7), "carrier")
	_advance(world, 400)
	_check(_stock(world.buildings[quarry], "outputs", "stone") == 0, "Quarry must wait for a stonemason", failures)
	_check(_stock(world.buildings[farm], "outputs", "grain") == 0 and int(world.fields[field]["age_ticks"]) == -1,
		"Farm and its field must wait for a farmer", failures)
	var mason: int = world.spawn_worker(Vector2i(0, 9), "stonemason")
	world.step_tick()
	_check(int(world.deposits[world.deposit_id_at(Vector2i(12, 2))]["amount"]) == 8,
		"Distant specialist must reach the deposit before extracting stone", failures)
	_check(_until(world, func() -> bool: return _stock(world.buildings[quarry], "outputs", "stone") > 0),
		"Stonemason must walk to the quarry and produce stone", failures)
	_check(int(world.deposits[world.deposit_id_at(Vector2i(12, 2))]["amount"]) < 8,
		"Stone delivered to the quarry must come from its finite deposit", failures)


static func _test_empty_inputs_wait(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 8))
	for entry: Array in [["mill", "flour", Vector2i(2, 2)], ["bakery", "bread", Vector2i(7, 2)]]:
		var id: int = world.place_building(String(entry[0]), entry[2])
		_staff(world, id, "baker")
	_advance(world, 400)
	for building: Dictionary in world.buildings.values():
		_check(int(building["process_remaining"]) == 0, "Processing buildings must wait for their required input", failures)
		_check(_stock(building, "outputs", "flour") + _stock(building, "outputs", "bread") == 0,
			"Bakers must not create flour or bread without ingredients", failures)
		_check(not world.production_status(building).is_empty(), "Waiting production must expose a status to the UI", failures)
	# Sandbox sawmills remain automatic and use the reference one-log, two-plank recipe.
	var sawmill: int = world.place_building("sawmill", Vector2i(5, 5))
	world.buildings[sawmill]["inputs"]["log"] = 1
	world.step_tick()
	_check(int(world.buildings[sawmill]["process_remaining"]) == 60, "Sawmill batch must retain its 60-tick duration", failures)
	_advance(world, 60)
	_check(_stock(world.buildings[sawmill], "outputs", "plank") == 2, "Sawmill must turn one log into two planks", failures)


static func _test_bread_batch_timing(failures: Array[String]) -> void:
	var world := World.new(Vector2i(8, 8))
	var id: int = world.place_building("bakery", Vector2i(3, 3))
	var bakery: Dictionary = world.buildings[id]
	bakery["inputs"]["flour"] = 1
	_staff(world, id, "baker")
	world.spawn_worker(Vector2i(6, 6), "baker")
	_check(_until(world, func() -> bool: return int(bakery["process_remaining"]) > 0), "Baker must start a supplied bakery", failures)
	_check(_stock(bakery, "inputs", "flour") == 0, "A batch consumes its flour exactly once at the start", failures)
	_check(int(bakery["process_remaining"]) == 100, "Bread batch must use 100 production ticks", failures)
	_advance(world, 99)
	_check(_stock(bakery, "outputs", "bread") == 0, "Two bakers must not accelerate or duplicate one reserved batch", failures)
	world.step_tick()
	_check(_stock(bakery, "outputs", "bread") == 2, "One flour must yield exactly two loaves at the completion tick", failures)
	_advance(world, 250)
	_check(_stock(bakery, "outputs", "bread") == 2, "Completed batch must not repeat without new flour", failures)


static func _test_field_sowing_growth_and_harvest(failures: Array[String]) -> void:
	var world := World.new(Vector2i(10, 8))
	var farm_id: int = world.place_building("farm", Vector2i(2, 2))
	var field_id: int = world.place_field(Vector2i(5, 2))
	var field: Dictionary = world.fields[field_id]
	world.spawn_worker(Vector2i(5, 2), "farmer", farm_id)
	_check(_until(world, func() -> bool: return int(field["age_ticks"]) == 0, 100), "Farmer must sow a prepared field", failures)
	_check(world.tick >= 20, "Sowing must take the configured work duration", failures)
	_check(world.field_growth_stage(field) == 1, "Sown field must visibly enter its growing stage", failures)
	_advance(world, World.FIELD_MATURE_AGE_TICKS - 1)
	_check(world.field_growth_stage(field) == 1 and world.pipeline_amount("grain") == 0,
		"Immature wheat must remain unharvestable for the full growth interval", failures)
	world.step_tick()
	_check(world.field_growth_stage(field) == 2, "Wheat becomes ripe on the exact maturity tick", failures)
	_check(world.pipeline_amount("grain") == 0, "Reaching maturity alone must not create grain", failures)
	_check(_until(world, func() -> bool: return _stock(world.buildings[farm_id], "outputs", "grain") == 1, 200),
		"Farmer must harvest ripe wheat and carry grain back to the farm", failures)
	_check(world.field_growth_stage(field) != 2, "Harvest must clear the ripe crop so it cannot be harvested twice", failures)


static func _test_farmers_reserve_distinct_fields(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 10))
	var farm_a: int = world.place_building("farm", Vector2i(2, 2))
	var farm_b: int = world.place_building("farm", Vector2i(8, 2))
	var first: int = world.place_field(Vector2i(5, 2))
	var second: int = world.place_field(Vector2i(5, 5))
	var a: int = world.spawn_worker(Vector2i(5, 2), "farmer", farm_a)
	var b: int = world.spawn_worker(Vector2i(5, 5), "farmer", farm_b)
	if a == 0 or b == 0:
		failures.append("Field reservation fixture must give each farmer its own farm")
		return
	world.step_tick()
	var source_a: int = int(world.workers[a]["source_id"])
	var source_b: int = int(world.workers[b]["source_id"])
	_check([first, second].has(source_a) and [first, second].has(source_b) and source_a != source_b,
		"Two farmers with overlapping workplace ranges must reserve different fields", failures)
	_check(_until(world, func() -> bool:
		return _stock(world.buildings[farm_a], "outputs", "grain") >= 1 and _stock(world.buildings[farm_b], "outputs", "grain") >= 1
	, 650), "Both farmers must complete their own sow-grow-harvest-deliver cycle at their assigned farm", failures)
	_check(int(world.workers[a]["home_id"]) == farm_a and int(world.workers[b]["home_id"]) == farm_b,
		"Overlapping fields must not cause farmers to exchange workplaces", failures)
	_check(world.pipeline_amount("grain") == 2, "Two initial crops must yield two grains without duplicate harvests", failures)


static func _test_trained_farmers_keep_distinct_workplaces(failures: Array[String]) -> void:
	for near_farm_full: bool in [false, true]:
		var world := World.new(Vector2i(26, 12))
		var near_farm: int = world.place_building("farm", Vector2i(2, 2))
		var school: int = world.place_building("school", Vector2i(5, 2))
		var far_farm: int = world.place_building("farm", Vector2i(18, 2))
		var far_field: int = world.place_field(Vector2i(20, 2))
		if near_farm_full:
			world.buildings[near_farm]["outputs"]["grain"] = 6
			var near_field: int = world.place_field(Vector2i(3, 5))
			world.fields[near_field]["age_ticks"] = World.FIELD_MATURE_AGE_TICKS
		_check(world.queue_unit_training(school, "farmer"), "School must accept the workplace assignment fixture's first farmer", failures)
		if not _until(world, func() -> bool: return world.workers.size() == 1, 100):
			failures.append("School must finish training the workplace assignment fixture's first farmer")
			continue
		var farmer: Dictionary = world.workers.values()[0]
		var school_exit: Vector2i = farmer["position"]
		_check(absi(school_exit.x - 2) + absi(school_exit.y - 2) < absi(school_exit.x - 18) + absi(school_exit.y - 2),
			"Trained farmer must begin nearer the farm with no available work", failures)
		_advance(world, 120)
		_check(int(farmer["home_id"]) == near_farm and int(world.fields[far_field]["age_ticks"]) == -1,
			"The first trained farmer must keep the nearer farm despite its missing fields or full output", failures)
		_check(world.queue_unit_training(school, "farmer"), "School must accept a second farmer for the other farm", failures)
		if not _until(world, func() -> bool: return world.workers.size() == 2, 100):
			failures.append("School must train the second farmer while the first keeps its workplace")
			continue
		var second_farmer: Dictionary = {}
		for candidate: Dictionary in world.workers.values():
			if int(candidate["id"]) != int(farmer["id"]):
				second_farmer = candidate
		_check(not second_farmer.is_empty() and int(second_farmer.get("home_id", 0)) == far_farm,
			"The second trained farmer must claim the remaining distant farm", failures)
		if not _until(world, func() -> bool: return int(world.fields[far_field]["age_ticks"]) >= 0, 500):
			failures.append("Second trained farmer must reach and sow its distant farm's field (near farm full=%s)" % near_farm_full)
			continue
		_check(_until(world, func() -> bool: return _stock(world.buildings[far_farm], "outputs", "grain") == 1, 600),
			"Farmer must harvest and deliver to the farm serving the distant field (near farm full=%s)" % near_farm_full, failures)
		_check(_stock(world.buildings[near_farm], "outputs", "grain") == (6 if near_farm_full else 0),
			"The first farmer's nearby farm must not receive the second farmer's distant harvest", failures)
		_check(int(farmer["home_id"]) == near_farm and int(second_farmer.get("home_id", 0)) == far_farm,
			"Both school-trained farmers must retain their distinct farms after the harvest", failures)


static func _test_full_chain_reaches_warehouse(failures: Array[String]) -> void:
	var world := World.new()
	# Isolate the bread/stone/wood chains from consumers in the full settlement
	# demo; inns and construction intentionally spend its warehouse stock.
	world.setup_demo()
	world.add_deposit(Vector2i(17, 2), "stone", 30)
	world.place_building("farm", Vector2i(5, 13))
	world.place_building("mill", Vector2i(9, 13))
	world.place_building("bakery", Vector2i(13, 13))
	world.place_building("quarry", Vector2i(16, 2))
	for cell: Vector2i in [Vector2i(6, 13), Vector2i(6, 14), Vector2i(7, 13), Vector2i(7, 14)]:
		world.place_field(cell)
	world.spawn_worker(Vector2i(4, 13), "farmer")
	world.spawn_worker(Vector2i(8, 12), "baker")
	world.spawn_worker(Vector2i(12, 12), "baker")
	world.spawn_worker(Vector2i(16, 3), "stonemason")
	for cell: Vector2i in [Vector2i(4, 10), Vector2i(8, 10), Vector2i(12, 10)]:
		world.spawn_worker(cell, "carrier")
	var first_bread: int = 0
	for tick_index: int in range(3000):
		world.step_tick()
		if tick_index == 1500:
			first_bread = world.stored_amount("bread")
		for building: Dictionary in world.buildings.values():
			var definition: Dictionary = world.catalog.building(String(building["type"]))
			for inventory: String in ["inputs", "outputs"]:
				var capacity: int = int(definition.get("input_capacity" if inventory == "inputs" else "output_capacity", 2147483647))
				for amount: Variant in (building[inventory] as Dictionary).values():
					if int(amount) < 0 or int(amount) > capacity:
						failures.append("Full economy exceeded %s capacity at tick %d" % [inventory, world.tick])
						return
	_check(first_bread > 0 and world.stored_amount("bread") > first_bread,
		"Real farmers, bakers and carriers must keep delivering field-grown bread to the warehouse", failures)
	_check(world.stored_amount("stone") > 0, "Real quarry workers and carriers must deliver stone to the warehouse", failures)
	_check(world.stored_amount("plank") > 0, "Extended economy must preserve the original lumber production chain", failures)


static func _test_warehouse_supplies_later_consumer(failures: Array[String]) -> void:
	var world := World.new(Vector2i(14, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	world.buildings[warehouse]["storage"]["grain"] = 2
	world.spawn_worker(Vector2i(3, 5), "carrier")
	world.spawn_worker(Vector2i(4, 5), "carrier")
	_advance(world, 100)
	_check(world.stored_amount("grain") == 2, "Stored grain must wait safely while no consumer exists", failures)
	var mill: int = world.place_building("mill", Vector2i(6, 2))
	var bakery: int = world.place_building("bakery", Vector2i(10, 2))
	_staff(world, mill, "baker")
	_staff(world, bakery, "baker")
	_check(_until(world, func() -> bool: return world.stored_amount("bread") == 4, 1600),
		"Carriers must resupply a newly built mill from warehouse grain and complete the bread chain", failures)
	_check(world.stored_amount("grain") + world.pipeline_amount("grain") + world.pipeline_amount("flour") == 0,
		"Two stored grain must be consumed exactly once into four bread", failures)


static func _test_save_resumes_consumed_batch(failures: Array[String]) -> void:
	var source := World.new(Vector2i(8, 8))
	var id: int = source.place_building("bakery", Vector2i(3, 3))
	source.buildings[id]["inputs"]["flour"] = 1
	_staff(source, id, "baker")
	_check(_until(source, func() -> bool: return int(source.buildings[id]["process_remaining"]) == 60),
		"Save fixture must reach the middle of a bread batch", failures)
	var restored := World.new()
	if not restored.from_data(JSON.parse_string(JSON.stringify(source.to_data()))):
		failures.append("A partially consumed bread batch must load from JSON")
		return
	_check(int(restored.buildings[id]["process_remaining"]) == 60 and _stock(restored.buildings[id], "inputs", "flour") == 0,
		"Load must preserve remaining production and the already consumed ingredient", failures)
	_advance(restored, 400)
	_check(_stock(restored.buildings[id], "outputs", "bread") == 2,
		"Reloaded baker must resume and finish a batch once without requiring another flour", failures)


static func _test_save_preserves_carried_wares(failures: Array[String]) -> void:
	for entry: Array in [["farm", "grain"], ["mill", "flour"], ["bakery", "bread"], ["quarry", "stone"]]:
		var source := World.new(Vector2i(14, 8))
		source.grid.set_base_terrain(Vector2i(12, 1), "rock")
		source.add_deposit(Vector2i(12, 1), "stone", 8)
		source.place_building("warehouse", Vector2i(1, 2))
		var producer: int = source.place_building(String(entry[0]), Vector2i(10, 2))
		var ware: String = String(entry[1])
		source.buildings[producer]["outputs"][ware] = 1
		var carrier: int = _staff(source, producer, "carrier")
		if not _until(source, func() -> bool: return String(source.workers[carrier]["carrying"]) == ware, 200):
			failures.append("Carrier must pick up %s before save" % ware)
			continue
		var restored := World.new()
		if not restored.from_data(JSON.parse_string(JSON.stringify(source.to_data()))):
			failures.append("Snapshot must allow a carrier holding %s" % ware)
			continue
		_advance(restored, 400)
		_check(restored.stored_amount(ware) == 1 and restored.pipeline_amount(ware) == 0,
			"Reloaded transport must deliver exactly one %s without loss or duplication" % ware, failures)


static func _test_output_backpressure(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 8))
	var id: int = world.place_building("bakery", Vector2i(2, 2))
	var bakery: Dictionary = world.buildings[id]
	bakery["inputs"]["flour"] = 4
	bakery["outputs"]["bread"] = 5
	_staff(world, id, "baker")
	_advance(world, 250)
	_check(int(bakery["process_remaining"]) == 0 and _stock(bakery, "inputs", "flour") == 4,
		"Bakery must reserve room for both loaves before consuming flour", failures)
	bakery["outputs"]["bread"] = 4
	_advance(world, 250)
	_check(_stock(bakery, "outputs", "bread") == 6 and _stock(bakery, "inputs", "flour") == 3,
		"Freeing one full batch of output capacity must permit exactly one batch", failures)
	var farm: int = world.place_building("farm", Vector2i(7, 2))
	world.buildings[farm]["outputs"]["grain"] = 5
	for cell: Vector2i in [Vector2i(9, 2), Vector2i(9, 5)]:
		var field: int = world.place_field(cell)
		world.fields[field]["age_ticks"] = World.FIELD_MATURE_AGE_TICKS
	var farmer: int = world.spawn_worker(Vector2i(9, 2), "farmer", farm)
	var waiting_farmer: int = world.spawn_worker(Vector2i(9, 5), "farmer")
	if farmer == 0 or waiting_farmer == 0:
		failures.append("Farm capacity fixture must spawn its owner and an unassigned farmer")
		return
	_advance(world, 250)
	_check(_stock(world.buildings[farm], "outputs", "grain") == 6,
		"The assigned harvester must respect the farm's last available grain slot", failures)
	_check(int(world.workers[farmer]["home_id"]) == farm and int(world.workers[waiting_farmer]["home_id"]) == 0,
		"A second farmer must wait for its own farm instead of sharing a full workplace", failures)
	_check(world.pipeline_amount("grain") == 6 and String(world.workers[waiting_farmer]["carrying"]).is_empty(),
		"Unassigned farmers must not harvest surplus grain or bypass the owner's output capacity", failures)


static func _test_input_capacity_with_competing_deliveries(failures: Array[String]) -> void:
	var world := World.new(Vector2i(18, 10))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	world.buildings[warehouse]["storage"]["grain"] = 20
	var mill: int = world.place_building("mill", Vector2i(9, 2))
	for x: int in [4, 7, 10, 13]:
		var farm: int = world.place_building("farm", Vector2i(x, 6))
		world.buildings[farm]["outputs"]["grain"] = 2
		_staff(world, farm, "carrier")
	world.spawn_worker(Vector2i(1, 4), "carrier")
	world.spawn_worker(Vector2i(2, 4), "carrier")
	for _tick: int in range(1200):
		world.step_tick()
		if _stock(world.buildings[mill], "inputs", "grain") > 4:
			failures.append("Concurrent inbound grain reservations must never overflow mill input capacity")
			return
		if world.stored_amount("grain") + world.pipeline_amount("grain") != 28:
			failures.append("Capacity-limited deliveries must conserve all 28 grain while the mill has no baker")
			return
	_check(_stock(world.buildings[mill], "inputs", "grain") == 4,
		"Carriers must fill the consumer to its exact four-grain capacity", failures)


static func _test_terrain_and_field_placement(failures: Array[String]) -> void:
	var world := World.new(Vector2i(14, 10))
	world.grid.set_base_terrain(Vector2i(8, 2), "rock")
	world.add_deposit(Vector2i(8, 2), "stone", 8)
	world.grid.set_base_terrain(Vector2i(1, 1), "water")
	world.grid.set_base_terrain(Vector2i(2, 1), "dirt")
	_check(world.can_place_building("quarry", Vector2i(5, 2)), "Quarry must accept rock at the inclusive three-tile radius", failures)
	_check(not world.can_place_building("quarry", Vector2i(4, 2)), "Quarry must reject rock beyond its three-tile radius", failures)
	_check(not world.can_place_building("quarry", Vector2i(8, 2)), "Quarry cannot replace the rock deposit itself", failures)
	_check(world.can_place_building("farm", Vector2i(2, 1)) and world.can_place_building("farm", Vector2i(3, 1)),
		"Farm must accept dirt and grass", failures)
	_check(not world.can_place_building("farm", Vector2i(1, 1)), "Farm must reject water", failures)
	_check(not world.can_place_field(Vector2i(1, 1)) and not world.can_place_field(Vector2i(8, 2)),
		"Fields must reject water and rock", failures)
	_check(world.place_field(Vector2i(2, 1)) != 0, "Player must be able to prepare a dirt field", failures)
	var cell := Vector2i(4, 6)
	_check(world.place_field(cell) != 0 and world.grid.is_walkable(cell), "Prepared grass field must remain walkable", failures)
	_check(world.place_field(cell) == 0 and not world.place_road(cell) and not world.can_place_building("mill", cell),
		"Prepared field must reject duplicate fields, roads and buildings", failures)
	_check(world.add_tree(cell) == 0 and not world.can_plant_sapling(cell), "Fields must be protected from tree planting", failures)
	var farm: int = world.place_building("farm", Vector2i(9, 6))
	_check(not world.can_place_field(world.buildings[farm]["entrance"]), "Fields must preserve building entrances", failures)


static func _test_new_professions_train_fifo(failures: Array[String]) -> void:
	var world := World.new(Vector2i(9, 9))
	var school: int = world.place_building("school", Vector2i(4, 4))
	for profession: String in ["farmer", "baker", "stonemason"]:
		_check(world.queue_unit_training(school, profession), "School must accept the new %s profession" % profession, failures)
	var order: Array[String] = []
	var previous_count: int = 0
	for _tick: int in range(400):
		world.step_tick()
		if world.workers.size() > previous_count:
			var ids: Array = world.workers.keys()
			ids.sort()
			order.append(String(world.workers[ids[-1]]["type"]))
			previous_count = world.workers.size()
	_check(order == ["farmer", "baker", "stonemason"], "New school professions must finish in FIFO order", failures)


static func _test_field_save_and_legacy_migration(failures: Array[String]) -> void:
	var source := World.new(Vector2i(12, 8))
	for entry: Array in [[Vector2i(2, 2), -1], [Vector2i(4, 2), 73], [Vector2i(6, 2), World.FIELD_MATURE_AGE_TICKS]]:
		var field: int = source.place_field(entry[0])
		source.fields[field]["age_ticks"] = int(entry[1])
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(source.to_data()))
	_check(int(snapshot["version"]) == World.SAVE_VERSION and snapshot.has("fields"),
		"Current save must include explicit field entities", failures)
	var restored := World.new()
	if not restored.from_data(snapshot):
		failures.append("Empty, growing and ripe fields must load together")
		return
	_check(restored.fields == source.fields, "Save/load must preserve every field position, identity and exact growth age", failures)
	restored.step_tick()
	for field: Dictionary in restored.fields.values():
		var original: int = int(source.fields[int(field["id"])]["age_ticks"])
		_check(int(field["age_ticks"]) == (74 if original == 73 else original), "Only growing wheat must advance after load", failures)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy["version"] = 5
	legacy.erase("fields")
	var migrated := World.new()
	_check(migrated.from_data(legacy) and migrated.fields.is_empty(), "Version 5 saves must migrate with no invented fields", failures)
	var active := World.new(Vector2i(10, 8))
	var farm: int = active.place_building("farm", Vector2i(2, 2))
	var field: int = active.place_field(Vector2i(5, 2))
	active.fields[field]["age_ticks"] = World.FIELD_MATURE_AGE_TICKS
	var farmer: int = active.spawn_worker(Vector2i(5, 2), "farmer", farm)
	if not _until(active, func() -> bool: return String(active.workers[farmer]["carrying"]) == "grain", 100):
		failures.append("Farmer save fixture must harvest before carrying grain home")
		return
	var resumed := World.new()
	if not resumed.from_data(JSON.parse_string(JSON.stringify(active.to_data()))):
		failures.append("Farmer carrying harvested grain must load")
		return
	_check(_until(resumed, func() -> bool: return _stock(resumed.buildings[farm], "outputs", "grain") == 1, 100),
		"Reloaded farmer must deliver the already harvested grain to its home farm", failures)
	_check(resumed.pipeline_amount("grain") == 1, "Reloading a harvested field must not duplicate the crop", failures)
