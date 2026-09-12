extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 7


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_every_catalog_resource,
		_test_real_carrier_transfer_conserves_stock,
		_test_warehouse_payment_does_not_spend_total_stock,
		_test_recipe_consumption_and_completion,
		_test_construction_and_unfinished_storage_are_excluded,
		_test_bulk_owner_filter_and_fresh_values,
		_test_bulk_empty_catalog_stock,
	]:
		test.call(failures)
	return failures


# Deliberately seed different counts in each inventory bucket: this tests all
# catalog IDs independently of their current production recipes or HUD category.
static func all_resource_fixture() -> Dictionary:
	var world := LegacyFixture.create(Vector2i(40, 12))
	var first_warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	var second_warehouse: int = world.place_building("warehouse", Vector2i(6, 2))
	var hut: int = world.place_building("lumber_hut", Vector2i(10, 2))
	var sawmill: int = world.place_building("sawmill", Vector2i(14, 2))
	var expected: Dictionary = {}
	var index: int = 0
	for resource: String in world.catalog.resources:
		index += 1
		world.buildings[first_warehouse]["storage"][resource] = index
		world.buildings[second_warehouse]["storage"][resource] = 10 + index
		world.buildings[sawmill]["inputs"][resource] = 100 + index
		world.buildings[hut]["outputs"][resource] = 1000 + index
		var carrier: int = world.spawn_worker(Vector2i(index, 8), "carrier")
		world.workers[carrier]["carrying"] = resource
		expected[resource] = {
			"warehouse": 10 + 2 * index,
			"buildings": 1100 + 2 * index,
			"carried": 1,
			"total": 1111 + 4 * index,
		}
	return {"world": world, "expected": expected}


static func _test_every_catalog_resource(failures: Array[String]) -> void:
	var fixture: Dictionary = all_resource_fixture()
	var world: World = fixture["world"]
	var expected: Dictionary = fixture["expected"]
	_check(world.resource_stocks() == expected, "Bulk accounting must match independently seeded amounts for every ware", failures)
	_check(expected.size() >= 28, "Accounting fixture must cover all 28 current catalog resources", failures)
	for resource: String in expected:
		var stock: Dictionary = world.resource_stock(resource)
		_check(stock == expected[resource], "Every inventory location must count exactly once for " + resource, failures)
		_check(world.stored_amount(resource) == int(expected[resource]["warehouse"]),
			"Warehouse-only accounting must retain its existing meaning for " + resource, failures)
		_check(world.pipeline_amount(resource) == int(expected[resource]["buildings"]) + 1,
			"Existing pipeline accounting must remain compatible for " + resource, failures)
	_check(world.resource_stock("unknown_resource") == {"warehouse": 0, "buildings": 0, "carried": 0, "total": 0},
		"An absent resource must report a zero breakdown", failures)


static func _test_real_carrier_transfer_conserves_stock(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	var hut: int = world.place_building("lumber_hut", Vector2i(8, 2))
	world.buildings[hut]["outputs"]["log"] = 6
	world.spawn_worker(Vector2i(7, 3), "carrier")
	_check(world.resource_stock("log") == {"warehouse": 0, "buildings": 6, "carried": 0, "total": 6},
		"Six logs in a hut must already count as six total logs", failures)
	var observed_carrying: bool = false
	for _tick: int in range(1200):
		world.step_tick()
		var stock: Dictionary = world.resource_stock("log")
		_check(world.resource_stocks()["log"] == stock, "Bulk accounting must follow each real pickup, move and delivery", failures)
		_check(int(stock["total"]) == 6, "Pickup, travel and delivery must neither lose nor duplicate logs", failures)
		if int(stock["carried"]) == 1:
			observed_carrying = true
			_check(int(stock["warehouse"]) + int(stock["buildings"]) == 5,
				"A carried log must leave its source inventory", failures)
		if int(world.buildings[warehouse]["storage"]["log"]) == 6:
			break
	_check(observed_carrying, "Transfer fixture must observe a physical carried log", failures)
	_check(world.resource_stock("log") == {"warehouse": 6, "buildings": 0, "carried": 0, "total": 6},
		"After delivery all six logs must move into the warehouse bucket", failures)
	var restored := LegacyFixture.create()
	_check(restored.from_data(world.to_data()) and restored.resource_stock("log") == world.resource_stock("log"),
		"Save/load must preserve resource totals and locations", failures)


static func _test_warehouse_payment_does_not_spend_total_stock(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(10, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	var tower: int = world.place_building("watchtower", Vector2i(6, 2))
	if tower == 0:
		failures.append("Payment fixture requires a watchtower")
		return
	world.buildings[tower]["inputs"]["stone"] = 3
	var carrier: int = world.spawn_worker(Vector2i(5, 6), "carrier")
	world.workers[carrier]["carrying"] = "stone"
	world.economy_enabled = true
	_check(int(world.resource_stock("stone")["total"]) == 4 and world.stored_amount("stone") == 0,
		"Visible total may include stone that is unavailable for warehouse payment", failures)
	_check(not world.place_road(Vector2i(7, 6)),
		"Road construction must not spend ammunition or carried stone when the warehouse is empty", failures)
	world.buildings[warehouse]["storage"]["stone"] = 1
	_check(world.place_road(Vector2i(7, 6)), "A warehouse stone must pay for a road", failures)
	_check(world.resource_stock("stone") == {"warehouse": 0, "buildings": 3, "carried": 1, "total": 4},
		"Road payment must remove only its warehouse stone from the total", failures)


static func _test_recipe_consumption_and_completion(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(8, 8))
	var sawmill: int = world.place_building("sawmill", Vector2i(3, 3))
	world.buildings[sawmill]["inputs"]["log"] = 1
	_check(int(world.resource_stock("log")["total"]) == 1, "Unused recipe inputs must count as stock", failures)
	world.step_tick()
	var remaining: int = int(world.buildings[sawmill]["process_remaining"])
	_check(remaining > 0, "Recipe fixture must start a real sawmill batch", failures)
	_check(int(world.resource_stock("log")["total"]) == 0 and int(world.resource_stock("plank")["total"]) == 0,
		"Consumed logs and unfinished planks must not remain available in totals", failures)
	for _tick: int in range(remaining):
		world.step_tick()
	_check(world.resource_stock("plank") == {"warehouse": 0, "buildings": 2, "carried": 0, "total": 2},
		"Finished production must add its actual two-plank output to building stock", failures)


static func _test_construction_and_unfinished_storage_are_excluded(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	var unfinished: int = world.place_building("warehouse", Vector2i(6, 2))
	var hut: int = world.place_building("lumber_hut", Vector2i(9, 2))
	world.buildings[warehouse]["storage"]["log"] = 2
	world.buildings[unfinished]["construction_remaining"] = 10
	world.buildings[unfinished]["storage"]["log"] = 31
	world.buildings[unfinished]["construction_delivered"]["log"] = 41
	world.buildings[hut]["storage"]["log"] = 51
	_check(world.resource_stock("log") == {"warehouse": 2, "buildings": 0, "carried": 0, "total": 2},
		"Totals must exclude spent construction materials, unfinished storage and non-warehouse storage", failures)
	_check(world.resource_stocks()["log"] == {"warehouse": 2, "buildings": 0, "carried": 0, "total": 2},
		"Bulk totals must exclude committed construction and unavailable storage", failures)


static func _test_bulk_owner_filter_and_fresh_values(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(14, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	var foreign: int = world.place_building("warehouse", Vector2i(7, 2))
	var carrier: int = world.spawn_worker(Vector2i(5, 6), "carrier")
	world.buildings[warehouse]["storage"]["log"] = 3
	world.buildings[foreign]["owner_id"] = 2
	world.buildings[foreign]["storage"]["log"] = 40
	world.buildings[foreign]["inputs"]["log"] = 5
	world.buildings[foreign]["outputs"]["log"] = 6
	world.workers[carrier]["owner_id"] = 2
	world.workers[carrier]["carrying"] = "log"
	var initial_tick: int = world.tick
	var first: Dictionary = world.resource_stocks()
	_check(first["log"] == {"warehouse": 3, "buildings": 0, "carried": 0, "total": 3},
		"Default bulk stock must exclude foreign stock even before fog is enabled", failures)
	world.fog.local_player_id = 2
	_check(world.resource_stocks()["log"] == {"warehouse": 40, "buildings": 11, "carried": 1, "total": 52},
		"Bulk stock must follow the current local player", failures)
	_check(world.resource_stocks(1)["log"] == first["log"], "Explicit owner must override local player", failures)
	world.buildings[warehouse]["storage"]["log"] = 9
	_check(world.resource_stocks(1)["log"]["total"] == 9 and world.tick == initial_tick,
		"Same-tick stock edits must be visible without a stale cache", failures)
	_check(first["log"]["total"] == 3, "Previously returned summaries must remain independent values", failures)
	first["log"]["total"] = 999
	_check(world.resource_stocks(1)["log"]["total"] == 9 and world.stored_amount("log", 1) == 9,
		"Editing a returned summary must not mutate inventories or future queries", failures)


static func _test_bulk_empty_catalog_stock(failures: Array[String]) -> void:
	var world := World.new()
	var stocks: Dictionary = world.resource_stocks()
	_check(stocks.size() == world.catalog.resources.size(), "Empty settlement must still include every HUD ware", failures)
	for resource: String in world.catalog.resources:
		_check(stocks[resource] == {"warehouse": 0, "buildings": 0, "carried": 0, "total": 0},
			"Empty bulk stock must report zero for " + resource, failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
