extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Economy = preload("res://scripts/simulation/classic_economy.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 7


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_current_sites_and_catalog,
		_test_legacy_price_decrease_and_builder,
		_test_legacy_price_increase_and_physical_delivery,
		_test_completed_building_and_round_trip,
		_test_cancel_conserves_legacy_materials,
		_test_invalid_revisions_and_deliveries_are_atomic,
		_test_hud_uses_site_contract,
	]:
		test.call(failures)
	return failures


static func _fixture(type: String, delivered: Dictionary = {}, remaining: int = 120) -> Dictionary:
	var world := LegacyFixture.create(Vector2i(16, 12))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[store]["storage"]["plank"] = 20
	world.buildings[store]["storage"]["stone"] = 20
	world.economy_enabled = true
	var site: int = world.place_building(type, Vector2i(9, 3))
	world.buildings[site]["construction_remaining"] = remaining
	world.buildings[site]["construction_delivered"] = delivered.duplicate(true)
	return {"world": world, "store": store, "site": site}


static func _legacy_snapshot(fixture: Dictionary) -> Dictionary:
	var data: Dictionary = _json_snapshot(fixture["world"])
	data["version"] = 8
	for building: Dictionary in data["buildings"]:
		building.erase("construction_cost_revision")
	return data


static func _json_snapshot(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _material_totals(world: Variant) -> Dictionary:
	var totals: Dictionary = {}
	for resource: String in world.catalog.resources:
		var amount: int = int(world.resource_stock(resource)["total"])
		for building: Dictionary in world.buildings.values():
			amount += int(building["construction_delivered"].get(resource, 0))
		totals[resource] = amount
	return totals


static func _until(world: Variant, condition: Callable, limit: int = 1800) -> bool:
	for _tick: int in range(limit):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_current_sites_and_catalog(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture("lumber_hut")
	var world: Variant = fixture["world"]
	var site: Dictionary = world.buildings[fixture["site"]]
	_check(int(site["construction_cost_revision"]) == 2,
		"New construction must use the source-backed cost revision", failures)
	_check(world.catalog.buildings.size() == world.catalog.LEGACY_CONSTRUCTION_COSTS.size() + 1
		and not world.catalog.LEGACY_CONSTRUCTION_COSTS.has("forester_hut"),
		"Every pre-revision type needs a frozen cost; the later Forester Hut must not invent legacy history", failures)
	for type: String in world.catalog.buildings:
		_check(world.catalog.construction_cost(type, 2) == world.catalog.building(type)["construction_cost"],
			"New site costs must match the build-menu catalog for " + type, failures)
		if type != "forester_hut":
			_check(not world.catalog.construction_cost(type, 1).is_empty(),
				"Legacy migration needs a nonempty material contract for " + type, failures)
	_check(world.construction_cost(site) == world.catalog.construction_cost("lumber_hut", 2),
		"The new site's material requests must use its current cost contract", failures)
	var restored := LegacyFixture.create()
	_check(restored.from_data(_json_snapshot(world)) and restored.to_data() == world.to_data(),
		"Current site revisions must round-trip through JSON without state changes", failures)


static func _test_legacy_price_decrease_and_builder(failures: Array[String]) -> void:
	# The old farm paid more of both materials than a newly placed farm does.
	var fixture: Dictionary = _fixture("farm", {"plank": 5, "stone": 4})
	var restored := LegacyFixture.create()
	if not restored.from_data(_legacy_snapshot(fixture)):
		failures.append("A V8 farm must still load when its delivered materials exceed the new farm price")
		return
	var site: int = fixture["site"]
	var current_cost: Dictionary = restored.catalog.construction_cost("farm", 2)
	_check(int(current_cost.get("plank", 0)) == 4 and int(current_cost.get("stone", 0)) == 3,
		"Legacy decrease fixture must exercise the actual lowered farm price", failures)
	_check(restored.construction_cost(restored.buildings[site]) == {"plank": 5, "stone": 4}
		and Economy.materials_ready(restored, restored.buildings[site]),
		"An already supplied old farm must keep its paid contract and stay buildable", failures)
	_check(_material_totals(restored) == _material_totals(fixture["world"]),
		"Migration must neither discard delivered stone nor refund or create inventory", failures)
	restored.spawn_worker(Vector2i(7, 6), "builder")
	_check(_until(restored, func() -> bool: return restored.is_building_complete(restored.buildings[site])),
		"A real builder must finish the fully supplied legacy farm under its original price", failures)
	_check(restored.buildings[site]["construction_delivered"] == {"plank": 5, "stone": 4},
		"Completion must preserve original delivered material records", failures)
	var replacement: int = restored.place_building("lumber_hut", Vector2i(12, 7))
	_check(replacement != 0 and int(restored.buildings[replacement]["construction_cost_revision"]) == 2,
		"New sites placed after loading a legacy world must use current prices", failures)


static func _test_legacy_price_increase_and_physical_delivery(failures: Array[String]) -> void:
	# Schools cost 5 planks + 4 stone in the old balance, less than the new price.
	var fixture: Dictionary = _fixture("school", {"plank": 4, "stone": 4})
	var restored := LegacyFixture.create()
	if not restored.from_data(_legacy_snapshot(fixture)):
		failures.append("A partly supplied V8 school must load after its new-build price increases")
		return
	var site: int = fixture["site"]
	var current_cost: Dictionary = restored.catalog.construction_cost("school", 2)
	_check(int(current_cost.get("plank", 0)) == 6 and int(current_cost.get("stone", 0)) == 5,
		"Legacy increase fixture must exercise the actual raised school price", failures)
	_check(restored.construction_cost(restored.buildings[site]) == {"plank": 5, "stone": 4},
		"Existing schools must retain their original price after a price increase", failures)
	_check(Economy.needs_material(restored, restored.buildings[site], "plank") == 1
		and Economy.needs_material(restored, restored.buildings[site], "stone") == 0,
		"Legacy material demand must count only the one originally missing plank", failures)
	var before: Dictionary = _material_totals(restored)
	restored.spawn_worker(Vector2i(4, 6), "carrier")
	_check(_until(restored, func() -> bool: return Economy.materials_ready(restored, restored.buildings[site])),
		"A carrier must physically deliver the last old-price plank", failures)
	_check(restored.buildings[site]["construction_delivered"] == {"plank": 5, "stone": 4}
		and restored.stored_amount("plank") == 19 and restored.stored_amount("stone") == 20,
		"A migrated site must not receive extra new-price materials", failures)
	_check(_material_totals(restored) == before, "Legacy deliveries must conserve every physical material", failures)


static func _test_completed_building_and_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture("farm", {"plank": 5, "stone": 4}, 0)
	var restored := LegacyFixture.create()
	if not restored.from_data(_legacy_snapshot(fixture)):
		failures.append("Completed V8 buildings must load with their retained old-price delivered material records")
		return
	var site: int = fixture["site"]
	_check(restored.is_building_complete(restored.buildings[site])
		and int(restored.buildings[site]["construction_cost_revision"]) == 1,
		"Loading must never reopen or reprice a completed legacy building", failures)
	var next: Dictionary = _json_snapshot(restored)
	_check(int(next["version"]) == World.SAVE_VERSION, "Migrated buildings must be written in the current explicit revision schema", failures)
	var round_trip := LegacyFixture.create()
	_check(round_trip.from_data(next) and round_trip.to_data() == restored.to_data(),
		"Resaving and reloading a migrated completed site must preserve all state", failures)
	_check(not round_trip.cancel_construction(site), "Completed old sites must not become refundable after migration", failures)


static func _test_cancel_conserves_legacy_materials(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture("farm", {"plank": 3, "stone": 4})
	var restored := LegacyFixture.create()
	if not restored.from_data(_legacy_snapshot(fixture)):
		failures.append("Partly supplied old sites must migrate before cancellation")
		return
	var site: int = fixture["site"]
	var before: Dictionary = _material_totals(restored)
	_check(restored.cancel_construction(site), "A migrated site must still support cancellation", failures)
	_check(restored.stored_amount("plank") == 23 and restored.stored_amount("stone") == 24
		and _material_totals(restored) == before,
		"Cancellation must refund exactly actual old deliveries, including stone above the new price, once", failures)
	_check(not restored.cancel_construction(site) and _material_totals(restored) == before,
		"Cancelling a migrated site twice must not duplicate its refund", failures)
	var round_trip := LegacyFixture.create()
	_check(round_trip.from_data(_json_snapshot(restored)) and _material_totals(round_trip) == before,
		"Cancelled legacy material totals must survive another save/load", failures)


static func _test_invalid_revisions_and_deliveries_are_atomic(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture("lumber_hut")
	var baseline: Dictionary = _json_snapshot(fixture["world"])
	var target := LegacyFixture.create()
	target.place_building("warehouse", Vector2i(1, 1))
	var unchanged: Dictionary = target.to_data()
	for revision: Variant in [null, -1, 0, 3, 1.5, "1", true, {}]:
		var data: Dictionary = baseline.duplicate(true)
		data["buildings"][1]["construction_cost_revision"] = revision
		_check(not target.from_data(data) and target.to_data() == unchanged,
			"Unknown, missing or noninteger construction revisions must fail transactionally: " + str(revision), failures)
	var missing: Dictionary = baseline.duplicate(true)
	missing["buildings"][1].erase("construction_cost_revision")
	_check(not target.from_data(missing) and target.to_data() == unchanged,
		"V9 requires an explicit cost revision for each building", failures)
	for version: int in [8, 9]:
		for delivered: Dictionary in [{"plank": 99999}, {"stone": 99999}, {"gold": 1}, {"log": 1}, {"plank": -1}, {"plank": 0.5}]:
			var data: Dictionary = baseline.duplicate(true)
			data["version"] = version
			data["buildings"][1]["construction_delivered"] = delivered
			_check(not target.from_data(data) and target.to_data() == unchanged,
				"Both legacy and current contracts must reject malformed/overpaid deliveries without mutation: " + str(delivered), failures)


static func _test_hud_uses_site_contract(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture("farm", {"plank": 1, "stone": 4})
	var restored := LegacyFixture.create()
	if not restored.from_data(_legacy_snapshot(fixture)):
		failures.append("HUD legacy fixture must load")
		return
	var hud := Hud.new()
	hud._catalog = restored.catalog
	var old_text: String = hud._selected_production_text(restored, Vector2i(9, 3))
	_check(old_text.contains("Planks 1/5") and old_text.contains("Stone 4/4") and old_text.contains("Legacy site"),
		"Inspector counters must show the actual legacy contract and explain why it differs from the menu", failures)
	var new_site: int = restored.place_building("lumber_hut", Vector2i(12, 7))
	var new_text: String = hud._selected_production_text(restored, Vector2i(12, 7))
	_check(new_site != 0 and not new_text.contains("Legacy site")
		and hud._build_cost("lumber_hut") == restored.construction_cost(restored.buildings[new_site]),
		"Build menu and new-site inspector must use the same current price", failures)
	hud.free()
