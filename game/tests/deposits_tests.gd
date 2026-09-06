extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Deposits = preload("res://scripts/simulation/resource_deposits.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_authored_deposits,
		_test_accessible_work_cells,
		_test_deposit_placement_radius,
		_test_finite_extraction_and_transport,
		_test_competing_extraction_respects_capacity,
		_test_extraction_save_conserves_remaining_stock,
		_test_snapshot_validation_is_transactional,
		_test_legacy_schema_migration,
		_test_expanded_save_preserves_paid_work_and_orders,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 1200) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _site(world: Variant, resource: String, cell: Vector2i, amount: int = 2) -> int:
	world.grid.set_base_terrain(cell, "water" if resource == "fish" else ("dirt" if resource == "coal" else "rock"))
	return Deposits.add(world, cell, resource, amount)


static func _test_authored_deposits(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(14, 10))
	for index: int in range(Deposits.RESOURCES.size()):
		var resource: String = Deposits.RESOURCES[index]
		var cell := Vector2i(index * 2 + 1, 2)
		var id: int = _site(world, resource, cell, 7)
		_check(id != 0 and Deposits.id_at(world, cell) == id, "Authoring must create an addressable %s deposit" % resource, failures)
		_check(Deposits.add(world, cell, resource, 2) == 0, "Deposit cells must not receive duplicate sources", failures)
	_check(Deposits.add(world, Vector2i(0, 0), "stone", 2) == 0, "Rock minerals must reject ordinary grass during authoring", failures)
	_check(Deposits.add(world, Vector2i(0, 0), "coal", 0) == 0, "New deposits require a positive finite amount", failures)
	_check(Deposits.add(world, Vector2i(-1, 0), "coal", 3) == 0, "Deposit authoring must reject off-map positions", failures)
	_check(Deposits.add(world, Vector2i(0, 0), "bread", 3) == 0, "Finished wares must not become natural deposits", failures)
	world.place_field(Vector2i(4, 6))
	_check(Deposits.add(world, Vector2i(4, 6), "coal", 3) == 0, "Deposits must preserve prepared fields", failures)
	world.add_tree(Vector2i(6, 6))
	_check(Deposits.add(world, Vector2i(6, 6), "coal", 3) == 0, "Deposits must preserve trees", failures)


static func _test_accessible_work_cells(failures: Array[String]) -> void:
	for resource: String in ["stone", "fish"]:
		var world = LegacyFixture.create(Vector2i(9, 9))
		var id: int = _site(world, resource, Vector2i(4, 4))
		var start := Vector2i(0, 4)
		var work: Vector2i = Deposits.candidate_work_cell(world, world.deposits[id], start)
		_check(work == Vector2i(3, 4), "Worker must choose the nearest reachable edge of an impassable %s deposit" % resource, failures)
		var blockers: Dictionary = {Vector2i(3, 4): true, Vector2i(4, 3): true, Vector2i(4, 5): true}
		work = Deposits.candidate_work_cell(world, world.deposits[id], start, blockers)
		_check(work == Vector2i(5, 4), "Worker must route around blocked deposit edges to a reachable work cell", failures)
		blockers[Vector2i(5, 4)] = true
		_check(Deposits.candidate_work_cell(world, world.deposits[id], start, blockers) == Deposits.NO_CELL,
			"Completely inaccessible deposits must not offer a work target", failures)


static func _test_deposit_placement_radius(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(14, 10))
	var id: int = _site(world, "iron_ore", Vector2i(8, 3))
	_check(Deposits.placement_valid(world, "iron_mine", Vector2i(5, 3)), "A mine must accept its matching ore at radius three", failures)
	_check(not Deposits.placement_valid(world, "iron_mine", Vector2i(4, 3)), "A mine must reject deposits beyond its extraction radius", failures)
	_check(not Deposits.placement_valid(world, "gold_mine", Vector2i(5, 3)), "An iron vein cannot enable a gold mine", failures)
	world.deposits[id]["amount"] = 0
	_check(not Deposits.placement_valid(world, "iron_mine", Vector2i(5, 3)), "Exhausted veins must not enable new mines", failures)


static func _test_finite_extraction_and_transport(failures: Array[String]) -> void:
	for entry: Array in [["quarry", "stonemason", "stone"], ["coal_mine", "miner", "coal"], ["iron_mine", "miner", "iron_ore"], ["gold_mine", "miner", "gold_ore"], ["fisher_hut", "fisherman", "fish"]]:
		var world = LegacyFixture.create(Vector2i(14, 9))
		var resource: String = String(entry[2])
		var deposit: int = _site(world, resource, Vector2i(9, 3), 2)
		world.place_building("warehouse", Vector2i(2, 2))
		var building: int = world.place_building(String(entry[0]), Vector2i(7, 3))
		if building == 0:
			failures.append("Finite extraction fixture must place %s near its source" % entry[0])
			continue
		world.spawn_worker(Vector2i(6, 5), String(entry[1]), building)
		world.spawn_worker(Vector2i(3, 5), "carrier")
		_check(_until(world, func() -> bool: return world.stored_amount(resource) == 2, 1600),
			"Specialist and carrier must move both finite %s units into the warehouse" % resource, failures)
		_advance(world, 250)
		_check(int(world.deposits[deposit]["amount"]) == 0 and world.stored_amount(resource) + world.pipeline_amount(resource) == 2,
			"Exhausted %s source must stop production without minting another ware" % resource, failures)


static func _test_competing_extraction_respects_capacity(failures: Array[String]) -> void:
	var world = LegacyFixture.create(Vector2i(14, 10))
	var first: int = _site(world, "stone", Vector2i(8, 3), 1)
	var second: int = _site(world, "stone", Vector2i(8, 5), 1)
	var quarry: int = world.place_building("quarry", Vector2i(6, 4))
	if quarry == 0:
		failures.append("Competing miners fixture must place a quarry")
		return
	world.buildings[quarry]["outputs"]["stone"] = 5
	world.spawn_worker(Vector2i(5, 3), "stonemason", quarry)
	var surplus: int = world.spawn_worker(Vector2i(5, 5), "stonemason")
	_advance(world, 700)
	var remaining: int = int(world.deposits[first]["amount"]) + int(world.deposits[second]["amount"])
	_check(int(world.buildings[quarry]["outputs"]["stone"]) == 6 and world.pipeline_amount("stone") == 6 and remaining == 1,
		"The quarry's sole worker must fill its final output slot and leave the second finite stone unmined", failures)
	_check(surplus != 0 and int(world.workers[surplus]["home_id"]) == 0 and world.workers[surplus]["carrying"] == "",
		"A surplus stonemason must wait for a vacant quarry instead of extracting through another worker's home", failures)


static func _test_extraction_save_conserves_remaining_stock(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(14, 9))
	var deposit: int = _site(source, "gold_ore", Vector2i(10, 3), 2)
	source.place_building("warehouse", Vector2i(1, 2))
	var mine: int = source.place_building("gold_mine", Vector2i(8, 3))
	if mine == 0:
		failures.append("Extraction save fixture must place a gold mine")
		return
	var miner: int = source.spawn_worker(Vector2i(9, 3), "miner", mine)
	source.spawn_worker(Vector2i(2, 5), "carrier")
	if not _until(source, func() -> bool: return source.workers[miner]["carrying"] == "gold_ore", 300):
		failures.append("Extraction save must catch a miner after consuming one deposit unit")
		return
	var restored = LegacyFixture.create()
	if not restored.from_data(JSON.parse_string(JSON.stringify(source.to_data()))):
		failures.append("A miner carrying ore and its finite deposit must survive save/load")
		return
	_check(int(restored.deposits[deposit]["amount"]) == 1, "Save/load must preserve the atomic deposit debit", failures)
	_advance(restored, 1400)
	_check(restored.stored_amount("gold_ore") == 2 and int(restored.deposits[deposit]["amount"]) == 0,
		"Restored mining must conserve both already carried ore and the final unmined unit", failures)
	var exhausted = LegacyFixture.create()
	_check(exhausted.from_data(restored.to_data()), "Existing mines must remain loadable beside exhausted deposits", failures)


static func _test_snapshot_validation_is_transactional(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(10, 8))
	_site(source, "coal", Vector2i(7, 2), 3)
	source.place_building("warehouse", Vector2i(2, 2))
	source.spawn_worker(Vector2i(3, 4), "carrier")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(source.to_data()))
	var cases: Array[Dictionary] = [
		{"name": "missing deposits", "mutate": func(data: Dictionary): data.erase("deposits")},
		{"name": "negative deposit", "mutate": func(data: Dictionary): data["deposits"][0]["amount"] = -1},
		{"name": "fractional deposit", "mutate": func(data: Dictionary): data["deposits"][0]["amount"] = 0.5},
		{"name": "unknown natural source", "mutate": func(data: Dictionary): data["deposits"][0]["resource"] = "bread"},
		{"name": "cross-type duplicate ID", "mutate": func(data: Dictionary): data["deposits"][0]["id"] = data["buildings"][0]["id"]},
		{"name": "deposit on building", "mutate": func(data: Dictionary): data["deposits"][0]["position"] = data["buildings"][0]["position"]},
		{"name": "non-boolean economy", "mutate": func(data: Dictionary): data["economy_enabled"] = "true"},
		{"name": "negative hunger", "mutate": func(data: Dictionary): data["workers"][0]["hunger"] = -1},
		{"name": "hunger above maximum", "mutate": func(data: Dictionary): data["workers"][0]["hunger"] = 2701},
		{"name": "missing paid training flag", "mutate": func(data: Dictionary): data["buildings"][0].erase("training_paid")},
		{"name": "construction overpayment", "mutate": func(data: Dictionary): data["buildings"][0]["construction_delivered"] = {"plank": 99999}},
		{"name": "non-boolean active order", "mutate": func(data: Dictionary): data["buildings"][0]["order_active"] = 1},
		{"name": "active order without a queued batch", "mutate": func(data: Dictionary): data["buildings"][0]["order_active"] = true},
		{"name": "foreign building recipe", "mutate": func(data: Dictionary): data["buildings"][0]["recipe_id"] = "bake_bread"},
		{"name": "invalid recipe order", "mutate": func(data: Dictionary): data["buildings"][0]["production_queue"] = ["unknown"]},
		{"name": "invalid service kind", "mutate": func(data: Dictionary): data["buildings"][0]["service_queue"] = [{"kind": "cheat"}]},
	]
	for test: Dictionary in cases:
		var invalid: Dictionary = snapshot.duplicate(true)
		(test["mutate"] as Callable).call(invalid)
		var before: Dictionary = source.to_data()
		var grid: Variant = source.grid
		_check(not source.from_data(invalid), "Snapshot must reject %s" % test["name"], failures)
		_check(source.to_data() == before and source.grid == grid, "Rejected %s must preserve the entire live world" % test["name"], failures)


static func _test_legacy_schema_migration(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(12, 9))
	_site(source, "stone", Vector2i(9, 3), 5)
	var quarry: int = source.place_building("quarry", Vector2i(7, 3))
	source.place_field(Vector2i(3, 3))
	source.spawn_worker(Vector2i(2, 5), "farmer")
	if quarry == 0:
		failures.append("Legacy migration fixture must place a quarry")
		return
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(source.to_data()))
	legacy["version"] = 6
	legacy.erase("economy_enabled")
	legacy.erase("deposits")
	for building: Dictionary in legacy["buildings"]:
		for field: String in ["recipe_id", "construction_remaining", "construction_delivered", "production_queue", "order_active", "service_queue", "training_paid"]:
			building.erase(field)
		if building["type"] == "quarry":
			building["process_remaining"] = 40
	for field: Dictionary in legacy["fields"]:
		field.erase("kind")
	for worker: Dictionary in legacy["workers"]:
		worker.erase("hunger")
	var restored = LegacyFixture.create()
	if not restored.from_data(legacy):
		failures.append("Version 6 must migrate an unfinished old quarry batch without a finite deposit requirement")
		return
	_check(restored.deposits.is_empty() and not restored.economy_enabled, "Legacy worlds must not invent deposits or enable new survival rules", failures)
	_check(int(restored.buildings[quarry]["outputs"]["stone"]) == 1 and int(restored.buildings[quarry]["process_remaining"]) == 0,
		"Migration must finish the one old quarry batch exactly once", failures)
	_check(restored.fields.values()[0]["kind"] == "wheat", "Legacy fields must migrate as wheat", failures)
	var second = LegacyFixture.create()
	_check(second.from_data(restored.to_data()) and int(second.buildings[quarry]["outputs"]["stone"]) == 1,
		"Saving the migrated quarry again must not duplicate its completed legacy batch", failures)


static func _test_expanded_save_preserves_paid_work_and_orders(failures: Array[String]) -> void:
	var source = LegacyFixture.create(Vector2i(26, 16))
	var school: int = source.place_building("school", Vector2i(3, 2))
	var workshop: int = source.place_building("weapon_workshop", Vector2i(7, 2))
	var market: int = source.place_building("marketplace", Vector2i(11, 2))
	var barracks: int = source.place_building("barracks", Vector2i(15, 2))
	var inn: int = source.place_building("inn", Vector2i(19, 2))
	var vine: int = source.place_field(Vector2i(22, 2), "vine")
	source.fields[vine]["age_ticks"] = 73
	source.buildings[school]["training_queue"] = ["miner"]
	source.buildings[school]["training_remaining"] = 20
	source.buildings[school]["training_paid"] = true
	source.buildings[workshop]["recipe_id"] = "make_lance"
	source.buildings[workshop]["production_queue"] = ["make_lance", "make_bow"]
	source.buildings[workshop]["process_remaining"] = 25
	source.buildings[workshop]["order_active"] = true
	source.buildings[market]["service_queue"] = [{"kind": "trade", "give": "log", "receive": "gold_ore"}]
	source.buildings[barracks]["service_queue"] = [{"kind": "recruit", "unit": "militia"}]
	source.buildings[inn]["construction_remaining"] = 55
	source.buildings[inn]["construction_delivered"] = {"plank": 1}
	var carpenter: int = source.spawn_worker(source.buildings[workshop]["entrance"], "carpenter", workshop)
	source.workers[carpenter]["hunger"] = 437
	var soldier: int = source.spawn_worker(Vector2i(15, 5), "militia")
	source.workers[soldier]["hunger"] = 100
	source.economy_enabled = true
	var snapshot: Dictionary = source.to_data()
	var restored = LegacyFixture.create()
	if not restored.from_data(JSON.parse_string(JSON.stringify(snapshot))):
		failures.append("Expanded snapshot must accept paid training, active production, services, construction, vines and soldiers together")
		return
	_check(restored.to_data() == snapshot, "Expanded save must preserve all persistent economic state exactly", failures)
	_advance(restored, 120)
	var miners: int = 0
	for worker: Dictionary in restored.workers.values():
		if worker["type"] == "miner":
			miners += 1
	_check(miners == 1 and int(restored.buildings[school]["inputs"]["gold"]) == 0,
		"Already paid school training must finish after load without charging a second gold", failures)
	_check(int(restored.buildings[workshop]["outputs"]["lance"]) == 1 and restored.buildings[workshop]["production_queue"] == ["make_bow"],
		"Already consumed active recipe must finish once and preserve the next queued order after load", failures)
