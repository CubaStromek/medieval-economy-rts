extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 3

# Independent reference values, ordered [finished planks, stone]. See the
# manual/source links in docs/construction-costs.md, not runtime definitions.
const EXPECTED: Dictionary = {
	"warehouse": [6, 5], "lumber_hut": [3, 2], "sawmill": [4, 3],
	"school": [6, 5], "quarry": [3, 2], "farm": [4, 3],
	"mill": [4, 3], "bakery": [4, 3], "coal_mine": [3, 2],
	"iron_mine": [3, 2], "gold_mine": [3, 2], "iron_smithy": [4, 3],
	"metallurgist": [4, 3], "vineyard": [4, 3], "fisher_hut": [4, 3],
	"swine_farm": [4, 3], "butcher": [4, 3], "tannery": [4, 3],
	"stables": [6, 5], "weapon_workshop": [4, 3], "armour_workshop": [4, 3],
	"weapon_smithy": [4, 3], "armour_smithy": [4, 3], "inn": [6, 5],
	"barracks": [6, 6], "marketplace": [5, 6], "town_hall": [6, 5], "watchtower": [3, 2],
}


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_all_reference_costs(failures)
	_test_project_extension_prices(failures)
	_test_logs_do_not_replace_construction_planks(failures)
	return failures


static func _test_all_reference_costs(failures: Array[String]) -> void:
	var world := LegacyFixture.create()
	_check(world.catalog.buildings.size() == EXPECTED.size() + 1, "Catalog must retain all reference buildings plus the project's Forester Hut", failures)
	for type: String in EXPECTED:
		var definition: Dictionary = world.catalog.building(type)
		var amount: Array = EXPECTED[type]
		var actual: Dictionary = definition.get("construction_cost", {})
		_check(actual.size() == 2 and actual.get("plank") == amount[0] and actual.get("stone") == amount[1],
			"KaM construction price mismatch: " + type, failures)
		_check(not String(definition.get("construction_cost_reference", "")).is_empty()
			and String(definition.get("construction_cost_source", "")) != "project_balance",
			"Reference price must identify its real source: " + type, failures)
	_check(world.catalog.economy["road_cost"].size() == 1 and world.catalog.economy["road_cost"].get("stone") == 1
		and world.catalog.economy["vine_field_cost"].size() == 1 and world.catalog.economy["vine_field_cost"].get("plank") == 1,
		"Road/vine costs must retain their separate source-backed material rules", failures)


static func _test_project_extension_prices(failures: Array[String]) -> void:
	var world := LegacyFixture.create()
	for type: String in ["forester_hut"]:
		var definition: Dictionary = world.catalog.building(type)
		var cost: Dictionary = definition.get("construction_cost", {})
		_check(cost.size() == 2 and cost.get("plank") == 3 and cost.get("stone") == 2,
			"%s must cost 3 finished planks and 2 stone" % definition.get("display_name", type), failures)
		_check(definition.get("construction_cost_source", "") == "project_balance"
			and not String(definition.get("construction_cost_reference", "")).is_empty(),
			"The additional %s price must not be misrepresented as an original KaM price" % definition.get("display_name", type), failures)


static func _test_logs_do_not_replace_construction_planks(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(12, 8))
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 2))
	world.buildings[warehouse]["storage"]["log"] = 20
	world.buildings[warehouse]["storage"]["stone"] = 2
	world.economy_enabled = true
	var hut: int = world.place_building("lumber_hut", Vector2i(7, 2))
	world.spawn_worker(Vector2i(3, 5), "carrier")
	world.spawn_worker(Vector2i(4, 5), "builder")
	for _tick: int in range(600):
		world.step_tick()
	_check(not world.is_building_complete(world.buildings[hut])
		and int(world.buildings[hut]["construction_delivered"].get("plank", 0)) == 0,
		"Raw logs must not silently pay a site's required finished planks", failures)
	_check(world.stored_amount("log") == 20, "A site must never consume raw logs as construction timber", failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
