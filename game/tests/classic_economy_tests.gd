extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 11

# Source-backed quantities, intentionally independent of the runtime catalog.
const EXPECTED_RECIPES: Dictionary = {
	"saw_planks": ["sawmill", "carpenter", {"log": 1}, {"plank": 2}],
	"mill_flour": ["mill", "baker", {"grain": 1}, {"flour": 1}],
	"bake_bread": ["bakery", "baker", {"flour": 1}, {"bread": 2}],
	"smelt_iron": ["iron_smithy", "metallurgist", {"iron_ore": 1, "coal": 1}, {"iron": 1}],
	"smelt_gold": ["metallurgist", "metallurgist", {"gold_ore": 1, "coal": 1}, {"gold": 2}],
	"breed_pig": ["swine_farm", "animal_breeder", {"grain": 4}, {"pig": 1, "skin": 1}],
	"make_sausages": ["butcher", "butcher", {"pig": 1}, {"sausage": 3}],
	"tan_leather": ["tannery", "butcher", {"skin": 1}, {"leather": 2}],
	"breed_horse": ["stables", "animal_breeder", {"grain": 4}, {"horse": 1}],
	"make_axe": ["weapon_workshop", "carpenter", {"plank": 2}, {"axe": 1}],
	"make_lance": ["weapon_workshop", "carpenter", {"plank": 2}, {"lance": 1}],
	"make_bow": ["weapon_workshop", "carpenter", {"plank": 2}, {"bow": 1}],
	"make_wooden_shield": ["armour_workshop", "carpenter", {"plank": 1}, {"wooden_shield": 1}],
	"make_leather_armour": ["armour_workshop", "carpenter", {"leather": 1}, {"leather_armour": 1}],
	"make_sword": ["weapon_smithy", "smith", {"iron": 1, "coal": 1}, {"sword": 1}],
	"make_pike": ["weapon_smithy", "smith", {"iron": 1, "coal": 1}, {"pike": 1}],
	"make_crossbow": ["weapon_smithy", "smith", {"iron": 1, "coal": 1}, {"crossbow": 1}],
	"make_iron_shield": ["armour_smithy", "smith", {"iron": 1, "coal": 1}, {"iron_shield": 1}],
	"make_iron_armour": ["armour_smithy", "smith", {"iron": 1, "coal": 1}, {"iron_armour": 1}],
}
const EXPECTED_SOLDIERS: Dictionary = {
	"militia": {"axe": 1},
	"axe_fighter": {"wooden_shield": 1, "leather_armour": 1, "axe": 1},
	"sword_fighter": {"iron_shield": 1, "iron_armour": 1, "sword": 1},
	"bowman": {"leather_armour": 1, "bow": 1},
	"crossbowman": {"iron_armour": 1, "crossbow": 1},
	"lance_carrier": {"leather_armour": 1, "lance": 1},
	"pikeman": {"iron_armour": 1, "pike": 1},
	"scout": {"wooden_shield": 1, "leather_armour": 1, "axe": 1, "horse": 1},
	"knight": {"iron_shield": 1, "iron_armour": 1, "sword": 1, "horse": 1},
	"rebel": {"gold": 2}, "rogue": {"gold": 3}, "vagabond": {"gold": 5},
	"barbarian": {"gold": 8}, "warrior": {"gold": 8},
}


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_all_reference_recipes,
		_test_recipe_capacity_and_explicit_orders,
		_test_production_fifo_and_boundaries,
		_test_all_recruitment_equipment,
		_test_paid_training_survives_save,
		_test_carriers_and_builder_construct,
		_test_wheat_and_vine_cycles,
		_test_food_consumption_and_starvation,
		_test_market_quotes_and_physical_trade,
		_test_inflight_processing_conserves_material,
		_test_watchtower_guard_ammunition_and_recruitment,
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


static func _json_snapshot(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _positive(inventory: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in inventory:
		if int(inventory[key]) != 0:
			result[key] = int(inventory[key])
	return result


static func _has_type(world: Variant, type: String) -> bool:
	for worker: Dictionary in world.workers.values():
		if worker["type"] == type:
			return true
	return false


static func _recipe_fixture(recipe_id: String) -> Dictionary:
	var world = World.new(Vector2i(9, 9))
	var expected: Array = EXPECTED_RECIPES[recipe_id]
	var building_id: int = world.place_building(expected[0], Vector2i(4, 3))
	var building: Dictionary = world.buildings[building_id]
	for resource: String in expected[2]:
		building["inputs"][resource] = expected[2][resource]
	world.economy_enabled = true
	return {"world": world, "building": building, "id": building_id, "expected": expected}


static func _test_all_reference_recipes(failures: Array[String]) -> void:
	var catalog_world = World.new()
	_check(catalog_world.catalog.recipes.size() == 19, "KaM catalog must cover all 19 processing recipes", failures)
	_check(catalog_world.catalog.buildings.size() == 29 and catalog_world.catalog.resources.size() == 28, "Remake catalog must contain 28 reference buildings plus the Forester Hut and 28 wares", failures)
	_check(catalog_world.catalog.units.has("gardener"), "The expanded economy must retain the gardener/forester profession", failures)
	for recipe_id: String in EXPECTED_RECIPES:
		var fixture: Dictionary = _recipe_fixture(recipe_id)
		var world: Variant = fixture["world"]
		var building: Dictionary = fixture["building"]
		var expected: Array = fixture["expected"]
		var actual: Dictionary = world.catalog.recipe(recipe_id)
		_check(_positive(actual.get("inputs", {})) == expected[2] and _positive(actual.get("outputs", {})) == expected[3], "%s must retain the independent KaM material ratio" % recipe_id, failures)
		_check(world.queue_production(fixture["id"], recipe_id), "%s must accept a valid production order" % recipe_id, failures)
		_advance(world, 100)
		_check(_positive(building["outputs"]).is_empty() and _positive(building["inputs"]) == expected[2], "%s must wait for its specialist without consuming materials" % recipe_id, failures)
		world.spawn_worker(Vector2i(2, 4), expected[1])
		var produced: bool = _until(world, func() -> bool: return _positive(building["outputs"]) == expected[3])
		_check(produced, "%s must complete its exact output batch through real ticks" % recipe_id, failures)
		_check(_positive(building["inputs"]).is_empty(), "%s must consume its exact input batch once" % recipe_id, failures)
		_advance(world, 40)
		_check(_positive(building["outputs"]) == expected[3], "%s must not duplicate a completed batch" % recipe_id, failures)


static func _test_recipe_capacity_and_explicit_orders(failures: Array[String]) -> void:
	for recipe_id: String in EXPECTED_RECIPES:
		var fixture: Dictionary = _recipe_fixture(recipe_id)
		var world: Variant = fixture["world"]
		var building: Dictionary = fixture["building"]
		var expected: Array = fixture["expected"]
		world.queue_production(fixture["id"], recipe_id)
		world.spawn_worker(Vector2i(2, 4), expected[1])
		var cap: int = int(world.catalog.building(expected[0])["output_capacity"])
		var first_output: String = String(expected[3].keys()[0])
		building["outputs"][first_output] = cap
		_advance(world, 60)
		_check(_positive(building["inputs"]) == expected[2] and int(building["process_remaining"]) == 0, "%s must reserve output capacity before taking inputs" % recipe_id, failures)
	var world = World.new(Vector2i(9, 9))
	var workshop: int = world.place_building("weapon_workshop", Vector2i(4, 3))
	world.buildings[workshop]["inputs"]["plank"] = 4
	world.spawn_worker(Vector2i(2, 4), "carpenter")
	world.economy_enabled = true
	_advance(world, 180)
	_check(int(world.buildings[workshop]["inputs"]["plank"]) == 4 and _positive(world.buildings[workshop]["outputs"]).is_empty(), "Equipment workshops must wait for an explicit player order", failures)


static func _test_production_fifo_and_boundaries(failures: Array[String]) -> void:
	var world = World.new(Vector2i(10, 9))
	var id: int = world.place_building("weapon_workshop", Vector2i(4, 3))
	world.buildings[id]["inputs"]["plank"] = 6
	world.spawn_worker(Vector2i(2, 4), "carpenter")
	world.economy_enabled = true
	for recipe: String in ["make_bow", "make_axe", "make_lance"]:
		_check(world.queue_production(id, recipe), "FIFO queue must accept %s" % recipe, failures)
	_check(_until(world, func() -> bool: return int(world.buildings[id]["process_remaining"]) > 0, 120), "The first ordered weapon must start before its save checkpoint", failures)
	_advance(world, 17)
	_check(world.from_data(_json_snapshot(world)), "An active multi-recipe order and its remaining FIFO queue must survive JSON save/load", failures)
	var observed: Array[String] = []
	for _tick: int in range(900):
		world.step_tick()
		for ware: String in ["bow", "axe", "lance"]:
			if int(world.buildings[id]["outputs"].get(ware, 0)) > 0 and not observed.has(ware):
				observed.append(ware)
		if observed.size() == 3:
			break
	_check(observed == ["bow", "axe", "lance"], "Production orders must finish in requested FIFO order", failures)
	_check(_positive(world.buildings[id]["inputs"]).is_empty(), "Three wooden weapons must consume exactly six planks", failures)
	_check(not world.queue_production(id, "smelt_gold") and not world.queue_production(9999, "make_axe"), "Wrong-building and missing-building recipes must be rejected", failures)
	for _index: int in range(10):
		_check(world.queue_production(id, "make_axe"), "Production queue must hold ten pending orders", failures)
	_check(not world.queue_production(id, "make_axe"), "Production queue must reject the eleventh pending order", failures)


static func _test_all_recruitment_equipment(failures: Array[String]) -> void:
	for type: String in EXPECTED_SOLDIERS:
		var world = World.new(Vector2i(9, 9))
		var cost: Dictionary = EXPECTED_SOLDIERS[type]
		var uses_recruit: bool = not cost.has("gold")
		var building_type: String = "barracks" if uses_recruit else "town_hall"
		var id: int = world.place_building(building_type, Vector2i(4, 3))
		var building: Dictionary = world.buildings[id]
		world.economy_enabled = true
		_check(_positive(world.catalog.soldiers[type]["equipment"]) == cost, "%s must require the reference equipment/gold" % type, failures)
		_check(world.queue_recruitment(id, type), "%s must be queueable in its recruitment building" % type, failures)
		_check(world.from_data(_json_snapshot(world)), "%s recruitment order must survive a save while waiting for materials" % type, failures)
		building = world.buildings[id]
		for resource: String in cost:
			building["inputs"][resource] = cost[resource]
		var recruit_id: int = 0
		if uses_recruit:
			_advance(world, 30)
			_check(world.workers.is_empty() and _positive(building["inputs"]) == cost, "%s must not consume equipment without a physical recruit" % type, failures)
			recruit_id = world.spawn_worker(Vector2i(1, 4), "recruit")
		else:
			building["inputs"]["gold"] = int(cost["gold"]) - 1
			_advance(world, 20)
			_check(world.workers.is_empty(), "%s must wait for its full gold price" % type, failures)
			building["inputs"]["gold"] = cost["gold"]
		_check(_until(world, func() -> bool: return _has_type(world, type), 300), "%s must be recruited by real service ticks" % type, failures)
		_check(world.workers.size() == 1 and _positive(building["inputs"]).is_empty(), "%s recruitment must consume one exact equipment batch and create one soldier" % type, failures)
		if uses_recruit:
			_check(world.workers.has(recruit_id) and world.workers[recruit_id]["type"] == type, "%s must convert the arriving recruit, preserving its identity" % type, failures)
		_check(not world.queue_recruitment(id, "rebel" if uses_recruit else "militia"), "Recruitment must reject a unit belonging to the other building", failures)
		var restored = World.new()
		_check(restored.from_data(_json_snapshot(world)) and _has_type(restored, type), "%s must survive JSON save/load as a soldier" % type, failures)
		var malformed: Dictionary = _json_snapshot(world)
		malformed["buildings"][0]["service_queue"] = [{"kind": "recruit", "unit": "rebel" if uses_recruit else "militia"}]
		_check(not World.new().from_data(malformed), "Saved recruitment orders must match the soldier's required building", failures)


static func _test_paid_training_survives_save(failures: Array[String]) -> void:
	var world = World.new(Vector2i(9, 9))
	var school: int = world.place_building("school", Vector2i(4, 3))
	world.economy_enabled = true
	_check(world.queue_unit_training(school, "builder"), "School must queue a builder", failures)
	_check(world.queue_unit_training(school, "recruit"), "School must queue a recruit after the builder", failures)
	_advance(world, 120)
	_check(world.workers.is_empty(), "Training must wait while the school has no gold", failures)
	world.buildings[school]["inputs"]["gold"] = 1
	world.step_tick()
	_check(int(world.buildings[school]["inputs"]["gold"]) == 0 and bool(world.buildings[school]["training_paid"]), "Starting training must consume gold once and persist the paid state", failures)
	for _index: int in range(4):
		_advance(world, 7)
		_check(world.from_data(_json_snapshot(world)), "Partially paid training must round-trip through JSON", failures)
	_check(_until(world, func() -> bool: return _has_type(world, "builder"), 200), "Paid training must finish after reload without another gold", failures)
	_advance(world, 120)
	_check(world.workers.size() == 1 and not _has_type(world, "recruit"), "The next training order must not reuse the previous gold payment", failures)
	world.buildings[school]["inputs"]["gold"] = 1
	_check(_until(world, func() -> bool: return _has_type(world, "recruit"), 200), "A second gold must train the queued recruit", failures)
	_check(int(world.buildings[school]["inputs"]["gold"]) == 0 and world.workers.size() == 2, "Two school graduates must consume exactly two gold", failures)


static func _test_carriers_and_builder_construct(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 10))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[store]["storage"]["plank"] = 12
	world.buildings[store]["storage"]["stone"] = 12
	world.spawn_worker(Vector2i(1, 6), "carrier")
	world.spawn_worker(Vector2i(3, 6), "carrier")
	world.economy_enabled = true
	var site: int = world.place_building("bakery", Vector2i(9, 3))
	_check(site != 0 and not world.is_building_complete(world.buildings[site]), "Economy-mode placement must create an unfinished building site", failures)
	_check(not world.queue_production(site, "bake_bread"), "An unfinished bakery must reject production orders", failures)
	var cost: Dictionary = _positive(world.catalog.building("bakery")["construction_cost"])
	var delivered: bool = _until(world, func() -> bool: return _positive(world.buildings[site]["construction_delivered"]) == cost, 1800)
	_check(delivered, "Carriers must deliver the actual plank and stone construction costs", failures)
	_check(not world.is_building_complete(world.buildings[site]), "Delivered materials must still require a builder", failures)
	_check(world.stored_amount("plank") == 12 - int(cost["plank"]) and world.stored_amount("stone") == 12 - int(cost["stone"]), "Construction must withdraw exactly its material cost from storage", failures)
	_check(world.from_data(_json_snapshot(world)), "A supplied unfinished site must survive save/load", failures)
	world.spawn_worker(Vector2i(7, 6), "builder")
	_check(_until(world, func() -> bool: return world.is_building_complete(world.buildings[site]), 600), "A builder must finish a supplied site through real work ticks", failures)
	_check(world.stored_amount("plank") == 12 - int(cost["plank"]) and world.stored_amount("stone") == 12 - int(cost["stone"]), "Finishing construction must not charge materials twice", failures)


static func _test_wheat_and_vine_cycles(failures: Array[String]) -> void:
	var world = World.new(Vector2i(16, 12))
	var farm: int = world.place_building("farm", Vector2i(3, 2))
	var vineyard: int = world.place_building("vineyard", Vector2i(10, 2))
	var wheat: int = world.place_field(Vector2i(3, 6), "wheat")
	var vine: int = world.place_field(Vector2i(10, 6), "vine")
	world.economy_enabled = true
	_advance(world, 220)
	_check(int(world.fields[wheat]["age_ticks"]) == -1, "Unseeded wheat must wait for a farmer instead of growing automatically", failures)
	_check(world.field_growth_stage(world.fields[vine]) == 2, "Vines must mature through their real growth ticks", failures)
	_check(world.pipeline_amount("grain") == 0 and world.pipeline_amount("wine") == 0, "Fields must not create inventory without a farmer's harvest", failures)
	world.spawn_worker(Vector2i(2, 5), "farmer", farm)
	world.spawn_worker(Vector2i(9, 5), "farmer", vineyard)
	_check(_until(world, func() -> bool: return int(world.buildings[farm]["outputs"]["grain"]) >= 1 and int(world.buildings[vineyard]["outputs"]["wine"]) >= 1, 1000), "Farmers must sow/grow/harvest wheat and deliver wine to the vineyard", failures)
	_check(int(world.fields[vine]["age_ticks"]) >= 0, "Harvested perennial vines must regrow without becoming an unseeded wheat plot", failures)
	_check(world.from_data(_json_snapshot(world)), "Active mixed wheat/vine agriculture must survive JSON save/load", failures)
	var authored = World.new(Vector2i(9, 9))
	var store: int = authored.place_building("warehouse", Vector2i(1, 1))
	authored.buildings[store]["storage"]["plank"] = 2
	authored.buildings[store]["storage"]["stone"] = 2
	authored.economy_enabled = true
	_check(authored.place_field(Vector2i(5, 5), "vine") != 0 and authored.stored_amount("plank") == 1, "A vine-field tile must cost one plank", failures)
	_check(authored.place_field(Vector2i(5, 5), "vine") == 0 and authored.stored_amount("plank") == 1, "Rejected vine placement must not charge a plank", failures)
	_check(authored.place_field(Vector2i(6, 5), "wheat") != 0 and authored.stored_amount("plank") == 1, "Wheat-field placement must not charge vine timber", failures)
	_check(authored.place_road(Vector2i(5, 6)) and authored.stored_amount("stone") == 1, "A road tile must consume one stone", failures)
	_check(not authored.place_road(Vector2i(5, 6)) and authored.stored_amount("stone") == 1, "Repeated road placement must not spend more stone", failures)


static func _test_food_consumption_and_starvation(failures: Array[String]) -> void:
	var restore: Dictionary = {"bread": 1080, "sausage": 1620, "wine": 810, "fish": 1350}
	for food: String in restore:
		var world = World.new(Vector2i(9, 9))
		var inn: int = world.place_building("inn", Vector2i(4, 3))
		var worker: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
		world.buildings[inn]["inputs"][food] = 1
		world.workers[worker]["hunger"] = 100
		world.economy_enabled = true
		world.step_tick()
		_check(int(world.workers[worker]["meal_ticks_left"]) > 0 and int(world.workers[worker]["hunger"]) == 100,
			"Hungry citizens must start eating available %s inside the inn without an instant refill" % food, failures)
		_check(int(world.buildings[inn]["inputs"][food]) == 0, "Eating %s must consume one physical food ware" % food, failures)
		_advance(world, int(world.catalog.building("inn")["meal_duration_ticks"]))
		_check(int(world.workers[worker]["hunger"]) == 100 + int(restore[food]), "%s must apply the KaM Remake restoration amount" % food, failures)
	var world = World.new(Vector2i(9, 9))
	var inn: int = world.place_building("inn", Vector2i(4, 3))
	var worker: int = world.spawn_worker(world.buildings[inn]["entrance"], "carrier")
	for food: String in restore:
		world.buildings[inn]["inputs"][food] = 1
	world.workers[worker]["hunger"] = 100
	world.economy_enabled = true
	world.step_tick()
	_advance(world, int(world.catalog.building("inn")["meal_duration_ticks"]) * int(world.catalog.economy["max_meals_per_visit"]))
	_check(int(world.workers[worker]["hunger"]) == 2700 and int(world.buildings[inn]["inputs"]["wine"]) == 0 \
		and int(world.buildings[inn]["inputs"]["fish"]) == 1 and int(world.workers[worker]["meal_ticks_left"]) == 0,
		"Inn meals must restore condition through three distinct courses and leave the fourth food untouched", failures)
	var starving = World.new(Vector2i(7, 7))
	var doomed: int = starving.spawn_worker(Vector2i(2, 2), "carrier")
	starving.workers[doomed]["hunger"] = 1
	starving.economy_enabled = true
	_advance(starving, 9)
	_check(starving.workers.has(doomed), "Condition must not decay ahead of the ten-tick interval", failures)
	starving.step_tick()
	_check(not starving.workers.has(doomed) and not starving.tile_reservations.has(Vector2i(2, 2)), "Starvation must remove the citizen and release its occupied tile", failures)


static func _test_market_quotes_and_physical_trade(failures: Array[String]) -> void:
	var world = World.new(Vector2i(14, 10))
	var expected: Array = [
		["log", "gold_ore", 3, 1], ["stone", "gold", 9, 1],
		["gold", "stone", 1, 2], ["plank", "bread", 2, 1],
		["bread", "plank", 2, 1], ["horse", "coal", 1, 2], ["coal", "horse", 12, 1],
	]
	for quote: Array in expected:
		_check(world.trade_amounts(quote[0], quote[1]) == {"give": quote[2], "receive": quote[3]}, "Market quote %s→%s must use the Remake integer rate" % [quote[0], quote[1]], failures)
	_check(world.trade_amounts("gold", "gold").is_empty() and world.trade_amounts("unknown", "gold").is_empty(), "Invalid or identical market wares must not produce a quote", failures)
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	var market: int = world.place_building("marketplace", Vector2i(9, 3))
	world.buildings[store]["storage"]["log"] = 3
	world.spawn_worker(Vector2i(2, 6), "carrier")
	world.spawn_worker(Vector2i(4, 6), "carrier")
	world.economy_enabled = true
	_advance(world, 80)
	_check(world.stored_amount("log") == 3 and world.pipeline_amount("gold_ore") == 0, "Marketplace must not pull goods or trade without a player order", failures)
	_check(world.queue_trade(market, "log", "gold_ore"), "Valid marketplace order must be accepted", failures)
	_check(world.from_data(_json_snapshot(world)), "A queued market exchange must survive JSON save/load before delivery", failures)
	_check(_until(world, func() -> bool: return world.stored_amount("gold_ore") == 1, 1600), "Carriers must supply three logs, trade them, and deliver the received gold ore", failures)
	_check(world.stored_amount("log") + world.pipeline_amount("log") == 0 and world.stored_amount("gold_ore") + world.pipeline_amount("gold_ore") == 1, "One market transaction must consume three logs and produce exactly one gold ore", failures)
	_check(not world.queue_trade(store, "log", "gold") and not world.queue_trade(market, "gold", "gold"), "Trade commands must reject non-markets and identical wares", failures)


static func _grain_equivalent(world: Variant) -> int:
	var result: int = 0
	for building: Dictionary in world.buildings.values():
		for key: String in ["inputs", "outputs", "storage"]:
			var inv: Dictionary = building[key]
			result += 2 * int(inv.get("grain", 0)) + 2 * int(inv.get("flour", 0)) + int(inv.get("bread", 0))
		if building["type"] in ["mill", "bakery"] and int(building["process_remaining"]) > 0:
			result += 2
	for worker: Dictionary in world.workers.values():
		if worker["carrying"] in ["grain", "flour"]:
			result += 2
		elif worker["carrying"] == "bread":
			result += 1
	return result


static func _test_inflight_processing_conserves_material(failures: Array[String]) -> void:
	var world = World.new(Vector2i(15, 10))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	var mill: int = world.place_building("mill", Vector2i(6, 3))
	var bakery: int = world.place_building("bakery", Vector2i(10, 3))
	world.buildings[store]["storage"]["grain"] = 12
	world.spawn_worker(Vector2i(6, 4), "baker")
	world.spawn_worker(Vector2i(10, 4), "baker")
	for x: int in [1, 3, 5, 7, 9]:
		world.spawn_worker(Vector2i(x, 7), "carrier")
	world.economy_enabled = true
	for tick: int in range(2200):
		world.step_tick()
		if _grain_equivalent(world) != 24:
			failures.append("Processing/cargo/save must conserve twelve grains at tick %d" % tick)
			return
		for id: int in [mill, bakery]:
			for amount: Variant in world.buildings[id]["inputs"].values():
				if int(amount) > 4:
					failures.append("Concurrent carriers must not overfill processing inputs")
					return
			for amount: Variant in world.buildings[id]["outputs"].values():
				if int(amount) > 6:
					failures.append("Processing must not overfill its output capacity")
					return
		if tick % 97 == 0 and not world.from_data(_json_snapshot(world)):
			failures.append("A live food-chain snapshot must restore during processing and delivery")
			return
	_check(world.stored_amount("bread") > 0, "Repeated saves must allow the complete food chain to keep making progress", failures)


static func _near_entrance(world: Variant, worker_id: int, building_id: int) -> bool:
	if not world.workers.has(worker_id):
		return false
	var position: Vector2i = world.workers[worker_id]["position"]
	var entrance: Vector2i = world.buildings[building_id]["entrance"]
	return absi(position.x - entrance.x) + absi(position.y - entrance.y) <= 1


static func _test_watchtower_guard_ammunition_and_recruitment(failures: Array[String]) -> void:
	var world = World.new(Vector2i(15, 12))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	var tower: int = world.place_building("watchtower", Vector2i(8, 3))
	# Adjacent entrances deliberately put the tower guard within the barracks'
	# normal recruitment distance, so the test proves guards are not converted.
	var barracks: int = world.place_building("barracks", Vector2i(9, 3))
	var inn: int = world.place_building("inn", Vector2i(6, 8))
	world.buildings[store]["storage"]["stone"] = 3
	world.spawn_worker(Vector2i(2, 6), "carrier")
	world.spawn_worker(Vector2i(4, 6), "carrier")
	var guard: int = world.spawn_worker(Vector2i(6, 5), "recruit")
	world.economy_enabled = true
	_check(_until(world, func() -> bool:
		return int(world.workers[guard]["home_id"]) == tower and _near_entrance(world, guard, tower)
	), "A free recruit must occupy a reachable unstaffed watchtower", failures)
	_check(_until(world, func() -> bool: return int(world.buildings[tower]["inputs"]["stone"]) == 3), "Carriers must physically supply stone ammunition to the guarded tower", failures)
	_check(world.stored_amount("stone") == 0, "Tower ammunition must come from storage without duplicating stone", failures)
	_check(world.from_data(_json_snapshot(world)), "A stationed watchtower guard and ammunition must survive JSON save/load", failures)
	_advance(world, 80)
	_check(world.workers[guard]["type"] == "recruit" and int(world.workers[guard]["home_id"]) == tower and _near_entrance(world, guard, tower), "The loaded guard must keep its post instead of reporting to the nearby barracks", failures)
	world.buildings[inn]["inputs"]["bread"] = 1
	world.buildings[inn]["inputs"]["sausage"] = 1
	world.workers[guard]["hunger"] = 100
	_check(_until(world, func() -> bool:
		return int(world.workers[guard]["hunger"]) > 360 and _near_entrance(world, guard, tower)
	), "A hungry guard must visit the supplied inn and return to its tower", failures)
	_check(int(world.workers[guard]["home_id"]) == tower and int(world.buildings[inn]["inputs"]["bread"]) == 0, "Eating must preserve the guard's tower assignment and consume food", failures)
	world.buildings[barracks]["inputs"]["axe"] = 1
	_check(world.queue_recruitment(barracks, "militia"), "The nearby barracks must accept an equipped militia order", failures)
	_advance(world, 80)
	_check(not _has_type(world, "militia") and int(world.buildings[barracks]["inputs"]["axe"]) == 1, "Barracks must not consume its neighbouring tower guard to fill recruitment", failures)
	var volunteer: int = world.spawn_worker(Vector2i(3, 5), "recruit")
	_check(_until(world, func() -> bool: return world.workers[volunteer]["type"] == "militia", 500), "A second free recruit must report to barracks and fill the pending equipment order", failures)
	_check(world.workers[guard]["type"] == "recruit" and int(world.workers[guard]["home_id"]) == tower and _near_entrance(world, guard, tower), "Military recruitment must leave the original watchtower guard stationed", failures)
	_check(int(world.buildings[barracks]["inputs"]["axe"]) == 0 and int(world.buildings[tower]["inputs"]["stone"]) == 3, "Recruitment must consume its axe once while preserving tower ammunition", failures)
