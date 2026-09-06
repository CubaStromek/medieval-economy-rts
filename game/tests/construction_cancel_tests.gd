extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 7


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_empty_site_releases_ground,
		_test_partial_deliveries_refund_once,
		_test_loaded_carrier_returns_its_cargo,
		_test_working_builder_is_released_and_reused,
		_test_completed_and_missing_buildings_are_unchanged,
		_test_cancelled_site_survives_save_load,
		_test_refund_failure_is_atomic,
	]:
		test.call(failures)
	return failures


static func _fixture(carrier_count: int = 2) -> Dictionary:
	# Same real delivery route as classic_economy_tests: author the warehouse,
	# enable construction costs, then let carriers supply the new bakery.
	var world := LegacyFixture.create(Vector2i(14, 10))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[store]["storage"]["plank"] = 12
	world.buildings[store]["storage"]["stone"] = 12
	for index: int in range(carrier_count):
		world.spawn_worker(Vector2i(1 + index * 2, 6), "carrier")
	world.economy_enabled = true
	var site: int = world.place_building("bakery", Vector2i(9, 3))
	return {"world": world, "store": store, "site": site}


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 1800) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _json_snapshot(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _amount(inventory: Dictionary) -> int:
	var total: int = 0
	for value: Variant in inventory.values():
		total += int(value)
	return total


static func _material_totals(world: Variant) -> Dictionary:
	# HUD stock intentionally excludes committed construction supplies. Count
	# those explicitly so a cancellation cannot conceal a loss or double refund.
	var result: Dictionary = {}
	for resource: String in world.catalog.resources:
		var total: int = 0
		for building: Dictionary in world.buildings.values():
			for bucket: String in ["storage", "inputs", "outputs", "construction_delivered"]:
				total += int(building[bucket].get(resource, 0))
		for worker: Dictionary in world.workers.values():
			if worker["carrying"] == resource:
				total += 1
		if total > 0:
			result[resource] = total
	return result


static func _supplied(world: Variant, site: int) -> bool:
	var cost: Dictionary = world.catalog.building(world.buildings[site]["type"])["construction_cost"]
	return _amount(world.buildings[site]["construction_delivered"]) == _amount(cost)


static func _no_site_references(world: Variant, site: int) -> bool:
	for worker: Dictionary in world.workers.values():
		for field: String in ["source_id", "destination_id", "home_id"]:
			if int(worker[field]) == site:
				return false
	for task: Dictionary in world.task_board.to_data()["tasks"]:
		if int(task["source_id"]) == site:
			return false
	return not world.task_board.has_source("construction:%d" % site)


static func _loaded_carrier(world: Variant, site: int) -> int:
	for worker: Dictionary in world.workers.values():
		if int(worker["destination_id"]) == site and not String(worker["carrying"]).is_empty():
			return int(worker["id"])
	return 0


static func _test_empty_site_releases_ground(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(8, 8))
	world.economy_enabled = true
	var cell := Vector2i(4, 3)
	var site: int = world.place_building("bakery", cell)
	var before: Dictionary = _material_totals(world)
	var revision: int = world.grid.revision
	_check(site != 0 and not world.grid.is_walkable(cell), "Placement must occupy the construction tile", failures)
	_check(world.cancel_construction(site), "A newly placed empty site must cancel even without a warehouse", failures)
	_check(not world.buildings.has(site) and world.building_id_at(cell) == 0 and world.grid.is_walkable(cell),
		"Cancelling must remove the site and release its occupied ground", failures)
	_check(world.grid.revision > revision and _material_totals(world) == before,
		"Cancelling must invalidate map rendering without spending or creating resources", failures)
	_check(world.place_building("bakery", cell) > site, "The released tile must immediately accept a fresh building with a new ID", failures)


static func _test_partial_deliveries_refund_once(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var site: int = fixture["site"]
	var expected: Dictionary = _material_totals(world)
	var reached: bool = _until(world, func() -> bool: return _amount(world.buildings[site]["construction_delivered"]) > 0)
	_check(reached and not _supplied(world, site), "Refund fixture must reach a real partly delivered construction site", failures)
	if not reached:
		return
	_check(world.cancel_construction(site), "A partly supplied site must accept cancellation", failures)
	_check(_material_totals(world) == expected and _no_site_references(world, site),
		"Delivered and carried materials must be conserved and obsolete site references removed", failures)
	var after: Dictionary = _json_snapshot(world)
	_check(not world.cancel_construction(site) and _json_snapshot(world) == after,
		"Repeating cancellation on the same ID must not refund twice or mutate the world", failures)
	_check(_until(world, func() -> bool: return world.stored_amount("plank") == 12 and world.stored_amount("stone") == 12, 600),
		"Refunded materials and any remaining cargo must return to warehouse stock", failures)
	_check(_material_totals(world) == expected, "Refund totals must remain conserved after subsequent simulation ticks", failures)


static func _test_loaded_carrier_returns_its_cargo(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(1)
	var world: Variant = fixture["world"]
	var site: int = fixture["site"]
	var expected: Dictionary = _material_totals(world)
	var reached: bool = _until(world, func() -> bool: return _loaded_carrier(world, site) != 0, 300)
	_check(reached, "Carrier fixture must observe real pickup with cargo addressed to the construction site", failures)
	if not reached:
		return
	var carrier: int = _loaded_carrier(world, site)
	_check(world.cancel_construction(site), "Cancellation must succeed while a carrier is delivering to the site", failures)
	_check(world.workers.has(carrier) and _material_totals(world) == expected and _no_site_references(world, site),
		"Cancellation must preserve the loaded carrier and every physical ware while clearing its old destination", failures)
	_check(_until(world, func() -> bool: return (String(world.workers[carrier]["carrying"]).is_empty()
		and world.stored_amount("plank") == 12 and world.stored_amount("stone") == 12), 600),
		"The former construction carrier must complete a return delivery through normal ticks", failures)
	_check(not world.buildings.has(site) and _material_totals(world) == expected,
		"Delivery completion must neither resurrect the cancelled building nor lose its cargo", failures)


static func _test_working_builder_is_released_and_reused(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var site: int = fixture["site"]
	var supplied: bool = _until(world, func() -> bool: return _supplied(world, site))
	_check(supplied, "Builder cancellation fixture must deliver all construction supplies through carriers", failures)
	if not supplied:
		return
	var builder: int = world.spawn_worker(Vector2i(7, 6), "builder")
	var initial_work: int = int(world.buildings[site]["construction_remaining"])
	var working: bool = _until(world, func() -> bool: return int(world.buildings[site]["construction_remaining"]) < initial_work, 300)
	_check(working and int(world.workers[builder]["task_id"]) != 0
		and world.task_board.reservation_count_for_source("construction:%d" % site) == 1,
		"Builder cancellation fixture must have a reserved task that has performed actual building work", failures)
	if not working:
		return
	_check(world.cancel_construction(site), "A construction site under active builder work must be cancellable", failures)
	_check(world.workers[builder]["state"] == "idle" and int(world.workers[builder]["task_id"]) == 0
		and (world.workers[builder]["path"] as Array).is_empty() and _no_site_references(world, site),
		"Cancellation must release the builder, its route, and the reserved construction task", failures)
	_check(world.stored_amount("plank") == 12 and world.stored_amount("stone") == 12,
		"Cancelling active construction must refund its full delivered material cost", failures)
	var replacement: int = world.place_building("bakery", Vector2i(9, 3))
	_check(replacement != 0, "The active builder's cancelled tile must accept replacement construction", failures)
	if replacement == 0:
		return
	_check(_until(world, func() -> bool: return world.is_building_complete(world.buildings[replacement]), 2400),
		"The released builder and carriers must supply and finish replacement construction autonomously", failures)
	_check(not world.buildings.has(site) and _no_site_references(world, site),
		"Later construction must never restore the old site or its cancelled task", failures)


static func _test_completed_and_missing_buildings_are_unchanged(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var site: int = fixture["site"]
	world.spawn_worker(Vector2i(7, 6), "builder")
	var finished: bool = _until(world, func() -> bool: return world.is_building_complete(world.buildings[site]), 2400)
	_check(finished, "Completed-building rejection fixture must finish a real construction job", failures)
	if not finished:
		return
	var before: Dictionary = _json_snapshot(world)
	var tasks: Dictionary = world.task_board.to_data()
	var workers: Dictionary = world.workers.duplicate(true)
	var revision: int = world.grid.revision
	_check(not world.cancel_construction(site) and not world.cancel_construction(0) and not world.cancel_construction(999999),
		"Cancellation must reject completed, zero, and missing building IDs", failures)
	_check(_json_snapshot(world) == before and world.task_board.to_data() == tasks
		and world.workers == workers and world.grid.revision == revision,
		"Rejected cancellation must preserve completed buildings, inventories, paths, tasks, and map revision", failures)


static func _test_cancelled_site_survives_save_load(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(1)
	var world: Variant = fixture["world"]
	var site: int = fixture["site"]
	var loaded: bool = _until(world, func() -> bool: return _loaded_carrier(world, site) != 0, 300)
	_check(loaded, "Cancellation save fixture must start with an active physical delivery", failures)
	if not loaded:
		return
	_check(world.cancel_construction(site), "Save fixture must cancel its construction site", failures)
	var checkpoint: Dictionary = _json_snapshot(world)
	var expected: Dictionary = _material_totals(world)
	var restored := LegacyFixture.create()
	var accepted: bool = restored.from_data(checkpoint)
	_check(accepted, "A save after construction cancellation must pass the production snapshot validator", failures)
	if not accepted:
		return
	_check(_json_snapshot(restored) == checkpoint and _material_totals(restored) == expected,
		"Cancellation save/load must preserve exact serialized state and all material totals", failures)
	_check(not restored.buildings.has(site) and restored.grid.is_walkable(Vector2i(9, 3))
		and _no_site_references(restored, site), "Reload must retain freed ground without dangling building, worker, or task references", failures)
	_check(_until(restored, func() -> bool: return restored.stored_amount("plank") == 12 and restored.stored_amount("stone") == 12, 600),
		"A carrier saved after cancellation must finish returning its cargo after reload", failures)


static func _test_refund_failure_is_atomic(failures: Array[String]) -> void:
	for obstacle: String in ["missing warehouse", "unreachable warehouse", "full warehouse"]:
		var fixture: Dictionary = _fixture()
		var world: Variant = fixture["world"]
		var site: int = fixture["site"]
		var store: int = fixture["store"]
		var supplied: bool = _until(world, func() -> bool: return _supplied(world, site))
		_check(supplied, "Atomic-refund fixture must receive actual deliveries before testing " + obstacle, failures)
		if not supplied:
			continue
		_advance(world, 40)
		if obstacle == "missing warehouse":
			# Load an otherwise valid settlement containing only the supplied site.
			var data: Dictionary = _json_snapshot(world)
			data["buildings"].remove_at(0)
			_check(world.from_data(data), "A supplied construction site without a warehouse must be a valid saved state", failures)
		elif obstacle == "unreachable warehouse":
			for y: int in range(world.grid.size.y):
				world.grid.set_base_terrain(Vector2i(6, y), "water")
		else:
			var capacity: int = int(world.catalog.economy["stock_capacity_per_ware"])
			world.buildings[store]["storage"]["plank"] = capacity
			world.buildings[store]["storage"]["stone"] = capacity
		var before: Dictionary = _json_snapshot(world)
		var tasks: Dictionary = world.task_board.to_data()
		var workers: Dictionary = world.workers.duplicate(true)
		var revision: int = world.grid.revision
		_check(not world.cancel_construction(site), "Refund must refuse cancellation with " + obstacle, failures)
		_check(_json_snapshot(world) == before and world.task_board.to_data() == tasks
			and world.workers == workers and world.grid.revision == revision,
			"Failed refund must be atomic with " + obstacle, failures)
		if obstacle == "unreachable warehouse":
			for y: int in range(world.grid.size.y):
				world.grid.set_base_terrain(Vector2i(6, y), "grass")
			_check(world.cancel_construction(site), "Restoring warehouse access must allow the previously refused cancellation", failures)
		elif obstacle == "full warehouse":
			world.buildings[store]["storage"]["plank"] -= 12
			world.buildings[store]["storage"]["stone"] -= 12
			var expected: Dictionary = _material_totals(world)
			_check(world.cancel_construction(site) and _material_totals(world) == expected,
				"Freeing capacity must permit one exact refund after a refused cancellation", failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
