extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const Start = preload("res://scripts/simulation/mountainous_region_start.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_canonical_identity_is_required(failures)
	_test_buildings_paths_and_exact_stock(failures)
	_test_first_carrier_bootstraps_training(failures)
	_test_save_roundtrip(failures)
	return failures


static func _fresh_world() -> Variant:
	var world := World.new(Start.MAP_SIZE)
	world.tick = 1000
	world.grid.restore_trail_clock(world.tick)
	world.economy_enabled = true
	return world


static func _canonical_import() -> Dictionary:
	return {
		"name": Start.MAP_NAME,
		"source": {"sha256": Start.SOURCE_SHA256},
	}


static func _started_world(failures: Array[String]) -> Variant:
	var world: Variant = _fresh_world()
	_check(Start.apply_if_supported(world, _canonical_import()),
		"The canonical Mountainous Region identity must receive its authored start", failures)
	return world


static func _test_canonical_identity_is_required(failures: Array[String]) -> void:
	var world: Variant = _fresh_world()
	var before: Dictionary = world.to_data()
	var wrong_name: Dictionary = _canonical_import()
	wrong_name["name"] = "Another landscape"
	var wrong_hash: Dictionary = _canonical_import()
	wrong_hash["source"]["sha256"] = "0".repeat(64)
	_check(not Start.apply_if_supported(world, wrong_name)
		and not Start.apply_if_supported(world, wrong_hash) and world.to_data() == before,
		"Other imported landscapes must remain unchanged and terrain-only", failures)
	var wrong_size := World.new(Vector2i(142, 127))
	wrong_size.economy_enabled = true
	_check(not Start.matches_import(wrong_size, _canonical_import()),
		"The known source digest cannot apply its fixed coordinates to another map size", failures)


static func _test_buildings_paths_and_exact_stock(failures: Array[String]) -> void:
	var world: Variant = _started_world(failures)
	var warehouse_id: int = int(world.building_id_at(Start.WAREHOUSE_CELL))
	var school_id: int = int(world.building_id_at(Start.SCHOOL_CELL))
	_check(world.buildings.size() == 2 and world.workers.is_empty()
		and world.deposits.is_empty() and world.fields.is_empty() and world.grid.roads.is_empty(),
		"The starter must contain only its two requested buildings and imported trees", failures)
	if warehouse_id == 0 or school_id == 0:
		failures.append("The starter Warehouse and School must occupy their authored plateau anchors")
		return
	var warehouse: Dictionary = world.buildings[warehouse_id]
	var school: Dictionary = world.buildings[school_id]
	_check(warehouse["type"] == "warehouse" and school["type"] == "school"
		and warehouse["position"] == Start.WAREHOUSE_CELL and school["position"] == Start.SCHOOL_CELL
		and world.is_building_complete(warehouse) and world.is_building_complete(school),
		"The Mountainous Region Warehouse and School must start fully completed", failures)
	var route: Array[Vector2i] = Pathfinder.find_path(world.grid, warehouse["entrance"], school["entrance"])
	_check(not route.is_empty() and route.back() == school["entrance"],
		"The two clear southern entrances must remain connected after both footprints are blocked", failures)
	_check(world.resource_stock("gold") == {"warehouse": 49, "buildings": 1, "carried": 0, "total": 50},
		"Starter Gold must total 50, with one piece already inside the School", failures)
	for resource: String in ["log", "plank", "stone"]:
		_check(world.resource_stock(resource) == {"warehouse": 20, "buildings": 0, "carried": 0, "total": 20},
			"Starter material must be exactly 20 units in the Warehouse: " + resource, failures)
	for resource: String in world.catalog.resources:
		if resource not in ["gold", "log", "plank", "stone"]:
			_check(int(world.resource_stock(resource)["total"]) == 0,
				"Unrequested starter ware must remain zero: " + resource, failures)
	_check(world.economy_enabled and Start.is_ready(world),
		"Normal economy rules must be enabled after authoring the completed start", failures)


static func _test_first_carrier_bootstraps_training(failures: Array[String]) -> void:
	var world: Variant = _started_world(failures)
	var school_id: int = int(world.building_id_at(Start.SCHOOL_CELL))
	if school_id == 0:
		return
	_check(world.queue_unit_training(school_id, "carrier"),
		"The Gold seeded in the School must allow the first Carrier to be queued", failures)
	for _tick: int in range(400):
		world.step_tick()
		if world.workers.size() == 1:
			break
	_check(world.workers.size() == 1 and _has_role(world, "carrier")
		and int(world.resource_stock("gold")["total"]) == 49,
		"The first Carrier must finish without any pre-existing citizen or free training", failures)
	_check(world.queue_unit_training(school_id, "builder"),
		"The live start must accept a second paid profession", failures)
	var saw_gold_in_transit: bool = false
	for _tick: int in range(1200):
		world.step_tick()
		saw_gold_in_transit = saw_gold_in_transit or int(world.resource_stock("gold")["carried"]) > 0
		if world.workers.size() == 2:
			break
	_check(saw_gold_in_transit and world.workers.size() == 2 and _has_role(world, "builder")
		and int(world.resource_stock("gold")["total"]) == 48,
		"The first Carrier must physically deliver Warehouse Gold for the next citizen", failures)


static func _test_save_roundtrip(failures: Array[String]) -> void:
	var source: Variant = _started_world(failures)
	var before: Dictionary = source.to_data()
	var restored := World.new()
	_check(restored.from_data(JSON.parse_string(JSON.stringify(before)))
		and restored.to_data() == before and Start.is_ready(restored),
		"A JSON roundtrip must preserve the starter buildings, inventories and economy state", failures)


static func _has_role(world: Variant, role: String) -> bool:
	for worker: Dictionary in world.workers.values():
		if String(worker["type"]) == role:
			return true
	return false


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
