extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_mixed_flags_are_observational, _test_invalid_flags_are_transactional,
		_test_legacy_defaults_preserve_nutrition, _test_loaded_gardener_waits,
		_test_paid_recipe_resumes, _test_paid_training_resumes,
		_test_construction_and_foundation_resume, _test_partial_meal_continues,
		_test_carried_ration_keeps_its_recipient]:
		test.call(failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 600) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _test_mixed_flags_are_observational(failures: Array[String]) -> void:
	var source = World.new(Vector2i(32, 22))
	var store: int = source.place_building("warehouse", Vector2i(3, 3))
	var hut: int = source.place_building("forester_hut", Vector2i(16, 6))
	var gardener: int = source.spawn_worker(source.buildings[hut]["entrance"], "gardener", hut)
	var builder: int = source.spawn_worker(Vector2i(13, 16), "builder")
	source.buildings[store]["storage"]["bread"] = 7
	source.set_building_enabled(hut, false)
	source.set_worker_enabled(builder, false)
	source.enable_fog()
	var before: Dictionary = source.to_data()
	var raw_workers: Dictionary = source.workers.duplicate(true)
	var raw_buildings: Dictionary = source.buildings.duplicate(true)
	var reservations: Dictionary = source.tile_reservations.duplicate(true)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("V20 must load independently paused citizens and completed staffed buildings")
		return
	_check(int(before["version"]) == World.SAVE_VERSION and restored.to_data() == before
		and source.workers == raw_workers and source.buildings == raw_buildings
		and source.tile_reservations == reservations,
		"Saving flags must not execute toggle side effects, advance work, mutate goods or release reservations", failures)
	_check(not bool(restored.buildings[hut]["enabled"]) and bool(restored.workers[gardener]["enabled"])
		and not bool(restored.workers[builder]["enabled"]) and bool(restored.buildings[store]["enabled"])
		and int(restored.workers[gardener]["home_id"]) == hut
		and int(restored.workplace_worker(hut).get("id", 0)) == gardener,
		"Loading a paused hut must retain its original enabled specialist and exclusive ownership", failures)


static func _test_invalid_flags_are_transactional(failures: Array[String]) -> void:
	var source = World.new(Vector2i(20, 16))
	source.place_building("warehouse", Vector2i(3, 3))
	source.spawn_worker(Vector2i(14, 10), "builder")
	var valid: Dictionary = _json(source)
	var live = World.new(Vector2i(24, 18))
	var store: int = live.place_building("warehouse", Vector2i(3, 3))
	live.buildings[store]["storage"]["gold"] = 5
	live.spawn_worker(Vector2i(16, 10), "builder")
	live.set_building_enabled(store, false)
	live.enable_fog()
	var before: Dictionary = live.to_data()
	var original_grid: Variant = live.grid
	var original_fog: Variant = live.fog
	var original_workers: Dictionary = live.workers.duplicate(true)
	var original_events: Array = live.event_log.duplicate(true)
	var original_reservations: Dictionary = live.tile_reservations.duplicate(true)
	for entities: String in ["workers", "buildings"]:
		for invalid: Variant in [null, 0, 1, -1, 0.0, 1.0, 0.5, "true", "false", INF, NAN, [], {}]:
			var broken: Dictionary = valid.duplicate(true)
			broken[entities][0]["enabled"] = invalid
			_check(not live.from_data(broken), "V20 must reject non-boolean %s.enabled=%s" % [entities, str(invalid)], failures)
		var missing: Dictionary = valid.duplicate(true)
		missing[entities][0].erase("enabled")
		_check(not live.from_data(missing), "V20 requires explicit %s.enabled" % entities, failures)
		_check(live.to_data() == before and live.grid == original_grid and live.fog == original_fog
			and live.workers == original_workers and live.event_log == original_events
			and live.tile_reservations == original_reservations,
			"A missing or malformed enabled flag must reject transactionally without touching live state", failures)


static func _test_legacy_defaults_preserve_nutrition(failures: Array[String]) -> void:
	for version: int in [1, 18, 19]:
		var source = LegacyFixture.create(Vector2i(14, 10))
		var store: int = source.place_building("warehouse", Vector2i(3, 3))
		var id: int = source.spawn_worker(Vector2i(10, 7), "builder")
		if version < 9:
			# This historical fixture must use the historical material-cost
			# revision as well; pause migration does not rewrite old costs.
			source.buildings[store]["construction_cost_revision"] = 1
		source.buildings[store]["storage"]["bread"] = 8
		source.workers[id]["hunger"] = 733
		source.workers[id]["nutrition_deficit_ticks"] = 27001
		source.workers[id]["condition_decay_remainder"] = 731
		source.workers[id]["nutrition_recovery_remainder"] = 1199
		source.workers[id]["work_effort_remainder"] = 499
		source.set_building_enabled(store, false)
		source.set_worker_enabled(id, false)
		var old: Dictionary = _json(source)
		old["version"] = version
		for entities: String in ["workers", "buildings"]:
			for entity: Dictionary in old[entities]:
				entity.erase("enabled")
		var expected: Dictionary = LegacyFixture.expected_pre_pause_migration(source.to_data())
		if version < 18:
			expected = LegacyFixture.expected_pre_fog_migration(source.to_data())
		elif version < 19:
			expected = LegacyFixture.expected_pre_nutrition_migration(source.to_data())
		var restored = World.new()
		if not restored.from_data(old):
			failures.append("Historical v%d must migrate without enabled fields" % version)
			continue
		_check(restored.to_data() == expected and bool(restored.workers[id]["enabled"])
			and bool(restored.buildings[store]["enabled"]),
			"V%d flags default to active without altering food, satiety, ownership, geometry or existing nutrition fractions" % version, failures)
		if version == 19:
			_check(restored.workers[id]["nutrition_deficit_ticks"] == 27001
				and restored.workers[id]["nutrition_recovery_remainder"] == 1199,
				"V19 migration must never erase already recorded seven-day deprivation history", failures)


static func _test_loaded_gardener_waits(failures: Array[String]) -> void:
	for pause_home: bool in [false, true]:
		var source = World.new(Vector2i(24, 18))
		var hut: int = source.place_building("forester_hut", Vector2i(6, 4))
		var id: int = source.spawn_worker(Vector2i(13, 10), "gardener", hut)
		source.economy_enabled = true
		if pause_home:
			source.set_building_enabled(hut, false)
		else:
			source.set_worker_enabled(id, false)
		var restored = World.new()
		if not restored.from_data(_json(source)):
			failures.append("A paused gardener and its owned hut must load")
			continue
		_advance(restored, 180)
		_check(restored.trees.is_empty() and restored.planting_reservations.is_empty()
			and int(restored.workers[id]["home_id"]) == hut
			and int(restored.workplace_worker(hut).get("id", 0)) == id
			and int(restored.workers[id]["nutrition_deficit_ticks"]) == 180,
			"A loaded paused gardener must retain its home and keep living, without planting or reserving new work", failures)
		restored.set_building_enabled(hut, true)
		restored.set_worker_enabled(id, true)
		_check(_until(restored, func() -> bool: return not restored.trees.is_empty()),
			"Re-enabling a saved gardener and hut must resume actual planting", failures)


static func _test_paid_recipe_resumes(failures: Array[String]) -> void:
	for pause_home: bool in [false, true]:
		var source = World.new(Vector2i(24, 18))
		var mill: int = source.place_building("sawmill", Vector2i(6, 4))
		var id: int = source.spawn_worker(source.buildings[mill]["entrance"], "carpenter", mill)
		source.buildings[mill]["inputs"]["log"] = 1
		source.economy_enabled = true
		source.queue_production(mill, "saw_planks")
		source.queue_production(mill, "saw_planks")
		if not _until(source, func() -> bool: return int(source.buildings[mill]["process_remaining"]) == 41):
			failures.append("The pause save fixture must really consume a log and partially saw its paid batch")
			continue
		if pause_home:
			source.set_building_enabled(mill, false)
		else:
			source.set_worker_enabled(id, false)
		var before: Dictionary = source.buildings[mill].duplicate(true)
		var restored = World.new()
		if not restored.from_data(_json(source)):
			failures.append("A disabled producer with its paid unfinished batch must load")
			continue
		_check(restored.to_data() == source.to_data(), "Loading must not spend or finish an already paid batch", failures)
		_advance(restored, 100)
		_check(restored.buildings[mill] == before and int(restored.workers[id]["home_id"]) == mill,
			"A loaded paused workshop or operator must freeze its exact process counter without losing staff or paid inputs", failures)
		restored.set_building_enabled(mill, true)
		restored.set_worker_enabled(id, true)
		_check(_until(restored, func() -> bool: return int(restored.buildings[mill]["outputs"].get("plank", 0)) == 2)
			and int(restored.buildings[mill]["inputs"].get("log", 0)) == 0
			and restored.buildings[mill]["production_queue"] == ["saw_planks"],
			"Resuming the saved paid batch must produce exactly two planks, retaining the next unpaid order without another charge", failures)


static func _test_paid_training_resumes(failures: Array[String]) -> void:
	var source = World.new(Vector2i(24, 18))
	var school: int = source.place_building("school", Vector2i(6, 4))
	source.economy_enabled = true
	source.buildings[school]["inputs"]["gold"] = 1
	source.queue_unit_training(school, "builder")
	source.queue_unit_training(school, "recruit")
	_advance(source, 17)
	_check(bool(source.buildings[school]["training_paid"]) and source.buildings[school]["inputs"]["gold"] == 0,
		"The school fixture must have physically spent one gold on its current pupil", failures)
	source.set_building_enabled(school, false)
	var before: Dictionary = source.buildings[school].duplicate(true)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A paused school must load its paid pupil and unpaid next order")
		return
	_advance(restored, 180)
	_check(restored.buildings[school] == before and restored.workers.is_empty(),
		"A loaded disabled school must preserve paid training time and queue without graduating or charging again", failures)
	restored.set_building_enabled(school, true)
	_check(_until(restored, func() -> bool: return restored.workers.size() == 1),
		"Re-enabling the loaded school must finish its already paid pupil", failures)
	_advance(restored, 180)
	_check(restored.workers.size() == 1 and restored.buildings[school]["inputs"]["gold"] == 0
		and restored.buildings[school]["training_queue"] == ["recruit"],
		"Paused training must not duplicate its pupil or reuse the first wage for the second order", failures)


static func _test_construction_and_foundation_resume(failures: Array[String]) -> void:
	for uneven: bool in [false, true]:
		var source = World.new(Vector2i(20, 16))
		for y: int in range(17):
			for x: int in range(21):
				source.grid.set_vertex_height(Vector2i(x, y), 2)
		source.place_building("warehouse", Vector2i(1, 3))
		if uneven:
			source.grid.set_vertex_height(Vector2i(9, 6), 3)
			source.grid.set_vertex_height(Vector2i(11, 7), 1)
		source.economy_enabled = true
		var site: int = source.place_building("sawmill", Vector2i(8, 7))
		if site == 0:
			failures.append("The paused construction fixture needs a valid modern sawmill site")
			continue
		if not uneven:
			# A paid material record contains whole delivered items, unlike the
			# float-valued JSON definition from which their required count comes.
			var cost: Dictionary = source.catalog.construction_cost("sawmill", int(source.buildings[site]["construction_cost_revision"]))
			for resource: String in cost:
				source.buildings[site]["construction_delivered"][resource] = int(cost[resource])
		source.spawn_worker(source.buildings[site]["entrance"], "builder")
		var field: String = "foundation_work_remaining" if uneven else "construction_remaining"
		var checkpoint: int = 7 if uneven else int(source.buildings[site][field]) - 9
		if not _until(source, func() -> bool: return int(source.buildings[site][field]) == checkpoint):
			failures.append("A real Builder must reach partial %s before its pause save" % field)
			continue
		source.set_building_enabled(site, false)
		var before: Dictionary = source.to_data()
		var building_before: Dictionary = source.buildings[site].duplicate(true)
		var restored = World.new()
		if not restored.from_data(_json(source)):
			failures.append("An actually worked disabled construction or foundation site must load")
			continue
		_check(restored.to_data() == before, "Loading paused %s cannot flatten terrain or spend delivered materials" % field, failures)
		_advance(restored, 90)
		_check(restored.buildings[site] == building_before and restored.to_data()["terrain"] == before["terrain"],
			"Loaded disabled %s must freeze exact partial work, terrain and delivered resources" % field, failures)
		restored.set_building_enabled(site, true)
		_check(_until(restored, func() -> bool: return int(restored.buildings[site][field]) == 0),
			"A resumed loaded site must finish its saved partial work instead of restarting or remaining stuck", failures)


static func _test_partial_meal_continues(failures: Array[String]) -> void:
	var source = World.new(Vector2i(24, 18))
	var inn: int = source.place_building("inn", Vector2i(6, 4))
	var id: int = source.spawn_worker(source.buildings[inn]["entrance"], "builder")
	source.buildings[inn]["inputs"]["bread"] = 2
	source.workers[id]["hunger"] = 100
	source.workers[id]["nutrition_deficit_ticks"] = 17001
	source.economy_enabled = true
	_advance(source, 28)
	_check(source.workers[id]["meal_ticks_left"] > 0, "The paused meal fixture must actually begin eating paid bread", failures)
	source.set_worker_enabled(id, false)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A disabled worker's already paid partial meal must remain loadable")
		return
	_check(restored.to_data() == source.to_data(), "Loading a disabled diner cannot consume or restore food a second time", failures)
	var initial_hunger: int = int(restored.workers[id]["hunger"])
	for _tick: int in range(48):
		source.step_tick()
		restored.step_tick()
	_check(restored.to_data() == source.to_data() and not bool(restored.workers[id]["enabled"])
		and int(restored.workers[id]["hunger"]) > initial_hunger
		and restored.buildings[inn]["inputs"]["bread"] == 1,
		"A saved disabled worker must keep eating its existing serving at the same pace without extra withdrawal", failures)


static func _test_carried_ration_keeps_its_recipient(failures: Array[String]) -> void:
	var source = World.new(Vector2i(32, 22))
	var store: int = source.place_building("warehouse", Vector2i(3, 3))
	var carrier: int = source.spawn_worker(Vector2i(13, 10), "carrier")
	var soldier: int = source.spawn_worker(Vector2i(28, 18), "militia")
	source.buildings[store]["storage"]["bread"] = 1
	source.workers[soldier]["hunger"] = 100
	source.economy_enabled = true
	source.request_soldier_food(soldier)
	if not _until(source, func() -> bool: return source.workers[carrier]["carrying"] == "bread"):
		failures.append("The paused carrier fixture must physically collect its soldier's ration")
		return
	source.set_worker_enabled(carrier, false)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A disabled carrier must load the paid ration already in its hands")
		return
	_check(restored.to_data() == source.to_data() and restored.resource_stock("bread")["carried"] == 1
		and not (restored.workers[carrier]["ration_delivery"] as Dictionary).is_empty(),
		"Loading disabled cargo must preserve the exact goods and reserved recipient without handoff side effects", failures)
	_check(_until(restored, func() -> bool: return not bool(restored.workers[soldier]["food_requested"])),
		"A paused carrier may finish the physical delivery already underway after loading", failures)
	_check(restored.resource_stock("bread")["total"] == 0 and not bool(restored.workers[carrier]["enabled"])
		and restored.workers.size() == 2 and int(restored.workers[soldier]["hunger"]) > 2500,
		"Completing saved paused cargo must feed its intended soldier exactly once without reactivating the carrier", failures)
