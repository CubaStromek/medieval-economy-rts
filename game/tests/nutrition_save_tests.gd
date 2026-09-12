extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Nutrition = preload("res://scripts/simulation/nutrition.gd")
const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const TEST_COUNT: int = 8
const FIELDS: Array[String] = ["nutrition_deficit_ticks", "condition_decay_remainder",
	"nutrition_recovery_remainder", "work_effort_remainder"]


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_exact_fractional_round_trip, _test_sleeping_continuity,
		_test_progressive_meal_continuity, _test_v18_preserves_existing_game,
		_test_ancient_migration, _test_invalid_nutrition_is_transactional,
		_test_saved_death_boundary, _test_repeated_loading_cannot_extend_survival]:
		test.call(failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _seed(worker: Dictionary, deficit: int = 18000) -> void:
	worker["nutrition_deficit_ticks"] = deficit
	worker["condition_decay_remainder"] = 731
	worker["nutrition_recovery_remainder"] = 1199
	worker["work_effort_remainder"] = 499


static func _until(world: Variant, condition: Callable, ticks: int = 600) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _test_exact_fractional_round_trip(failures: Array[String]) -> void:
	var source = World.new(Vector2i(18, 14))
	var id: int = source.spawn_worker(Vector2i(8, 8), "builder")
	_seed(source.workers[id], 27001)
	source.economy_enabled = true
	source.enable_fog()
	var before: Dictionary = source.to_data()
	var before_worker: Dictionary = source.workers[id].duplicate(true)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("V19 must accept and preserve all four nonzero nutrition history fields")
		return
	_check(int(before["version"]) == World.SAVE_VERSION and restored.to_data() == before
		and source.to_data() == before and source.workers[id] == before_worker,
		"Snapshotting must not tick nutrition, spend fractional work, change fog, or feed a citizen", failures)
	for _attempt: int in range(19):
		var source_allowed: bool = Nutrition.allow_work_tick(source, source.workers[id])
		var restored_allowed: bool = Nutrition.allow_work_tick(restored, restored.workers[id])
		_check(source_allowed == restored_allowed and restored.to_data() == source.to_data(),
			"A saved fractional work remainder must resume the exact productive-tick sequence", failures)
	var maximums: Array[int] = [Nutrition.max_deficit_ticks(source), 999, Nutrition.max_recovery_remainder(source), 999]
	for index: int in range(FIELDS.size()):
		source.workers[id][FIELDS[index]] = maximums[index]
	_check(restored.from_data(_json(source)) and restored.to_data() == source.to_data()
		and restored.workers.has(id),
		"Inclusive maximum nutrition values must load without prematurely executing a death tick", failures)


static func _test_sleeping_continuity(failures: Array[String]) -> void:
	var source = World.new(Vector2i(24, 18))
	var hut: int = source.place_building("lumber_hut", Vector2i(6, 4))
	var id: int = source.spawn_worker(Vector2i(14, 12), "lumberjack", hut)
	source.economy_enabled = true
	source.tick = 4000
	if not _until(source, func() -> bool: return source.is_worker_sleeping(source.workers[id])):
		failures.append("The nutrition save fixture must physically enter its own hut and fall asleep")
		return
	_seed(source.workers[id])
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A sleeping citizen's nonzero metabolic and recovery remainders must load")
		return
	_check(restored.to_data() == source.to_data() and restored.is_worker_sleeping(restored.workers[id]),
		"Loading nutrition must preserve the worker's real bedroom, sleep state and calendar", failures)
	for _tick: int in range(83):
		source.step_tick()
		restored.step_tick()
	_check(restored.to_data() == source.to_data()
		and int(restored.workers[id]["nutrition_deficit_ticks"]) == 18083,
		"Saved sleepers must retain slower satiety loss but count every unfed calendar tick", failures)


static func _test_progressive_meal_continuity(failures: Array[String]) -> void:
	var source = World.new(Vector2i(24, 18))
	var inn: int = source.place_building("inn", Vector2i(6, 4))
	var id: int = source.spawn_worker(source.buildings[inn]["entrance"], "builder")
	for food: String in ["bread", "wine", "fish"]:
		source.buildings[inn]["inputs"][food] = 2
	_seed(source.workers[id], 27000)
	source.workers[id]["hunger"] = 100
	source.economy_enabled = true
	source.step_tick()
	for _tick: int in range(37):
		source.step_tick()
	_check(int(source.workers[id]["meal_ticks_left"]) > 0
		and int(source.workers[id]["nutrition_deficit_ticks"]) < 27000
		and int(source.workers[id]["nutrition_recovery_remainder"]) > 0,
		"The meal fixture must have genuinely eaten a partial paid course and partially repaid deprivation", failures)
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("Mid-course nutritional debt and fractional recovery must survive JSON loading")
		return
	_check(restored.to_data() == source.to_data(),
		"Loading a partial meal must not repay extra debt or withdraw a duplicate serving", failures)
	for segment: int in [39, 40, 117, 92]:
		for _tick: int in range(segment):
			source.step_tick()
			restored.step_tick()
		_check(restored.to_data() == source.to_data(),
			"Progressive food, inventory and nutrition must match uninterrupted play across saved course boundaries", failures)
		var next = World.new()
		if not next.from_data(_json(restored)):
			failures.append("An intermediate meal save with nutrition history must remain reloadable")
			return
		restored = next


static func _test_v18_preserves_existing_game(failures: Array[String]) -> void:
	var source = World.new(Vector2i(24, 18))
	var store: int = source.place_building("warehouse", Vector2i(3, 3))
	var id: int = source.spawn_worker(Vector2i(15, 10), "builder")
	source.buildings[store]["storage"]["bread"] = 8
	source.buildings[store]["storage"]["stone"] = 5
	source.workers[id]["hunger"] = 123
	_seed(source.workers[id], 41999)
	source.tick = 24001
	source.economy_enabled = true
	source.enable_fog()
	var old: Dictionary = _json(source)
	old["version"] = 18
	for field: String in FIELDS:
		old["workers"][0].erase(field)
	var restored = World.new()
	if not restored.from_data(old):
		failures.append("A v18 game without historical nutrition fields must migrate")
		return
	_check(restored.to_data() == LegacyFixture.expected_pre_nutrition_migration(source.to_data())
		and restored.workers[id]["hunger"] == 123 and restored.stored_amount("bread") == 8,
		"V18 migration must zero unknown deprivation only, preserving satiety, wares, owners, terrain, fog and clock", failures)
	restored.step_tick()
	_check(restored.workers.has(id) and int(restored.workers[id]["nutrition_deficit_ticks"]) == 1,
		"An old low-satiety citizen must start a fresh seven-day history, never inherit starvation from game age", failures)


static func _test_ancient_migration(failures: Array[String]) -> void:
	for version: int in [1, 6, 7, 12, 17]:
		var source = LegacyFixture.create(Vector2i(8, 8))
		var id: int = source.spawn_worker(Vector2i(3, 3), "builder")
		source.workers[id]["hunger"] = 733
		_seed(source.workers[id])
		var old: Dictionary = _json(source)
		old["version"] = version
		for field: String in FIELDS:
			old["workers"][0].erase(field)
		var restored = World.new()
		if not restored.from_data(old):
			failures.append("Historical v%d workers must migrate without nutrition history" % version)
			continue
		_check(restored.to_data() == LegacyFixture.expected_pre_fog_migration(source.to_data())
			and restored.workers[id]["hunger"] == 733,
			"Historical migration must retain supplied satiety and seed zero deprivation", failures)
		if version < 7:
			old["workers"][0].erase("hunger")
			_check(restored.from_data(old) and restored.workers[id]["hunger"] == 1620,
				"Very old missing satiety must retain its historical 1620 fallback, not today's new-game balance", failures)


static func _test_invalid_nutrition_is_transactional(failures: Array[String]) -> void:
	var source = World.new(Vector2i(12, 10))
	source.spawn_worker(Vector2i(5, 5), "builder")
	var valid: Dictionary = _json(source)
	var destination = World.new(Vector2i(20, 16))
	var store: int = destination.place_building("warehouse", Vector2i(3, 3))
	destination.buildings[store]["storage"]["bread"] = 5
	destination.spawn_worker(Vector2i(14, 10), "builder")
	destination.enable_fog()
	var before: Dictionary = destination.to_data()
	var original_grid: Variant = destination.grid
	var original_fog: Variant = destination.fog
	var original_workers: Dictionary = destination.workers.duplicate(true)
	var original_events: Array = destination.event_log.duplicate(true)
	var original_reservations: Dictionary = destination.tile_reservations.duplicate(true)
	var maximums: Array[int] = [42000, 999, 2339, 999]
	for index: int in range(FIELDS.size()):
		var field: String = FIELDS[index]
		var cases: Array = [null, true, false, "0", -1, 0.5, INF, NAN, [], {}, maximums[index] + 1]
		for invalid: Variant in cases:
			var broken: Dictionary = valid.duplicate(true)
			broken["workers"][0][field] = invalid
			_check(not destination.from_data(broken), "V19 must reject invalid %s=%s" % [field, str(invalid)], failures)
		var missing: Dictionary = valid.duplicate(true)
		missing["workers"][0].erase(field)
		_check(not destination.from_data(missing), "V19 must reject missing mandatory %s" % field, failures)
		_check(destination.to_data() == before and destination.grid == original_grid
			and destination.fog == original_fog and destination.workers == original_workers
			and destination.event_log == original_events and destination.tile_reservations == original_reservations,
			"Rejecting malformed nutrition must leave every live object, reservation, good and visibility mask unchanged", failures)


static func _test_saved_death_boundary(failures: Array[String]) -> void:
	var source = World.new(Vector2i(20, 16))
	var store: int = source.place_building("warehouse", Vector2i(3, 3))
	var door: Vector2i = source.buildings[store]["entrance"]
	var id: int = source.spawn_worker(door, "builder", 0, false, store)
	var passer: int = source.spawn_worker(door, "builder")
	source.workers[id]["hunger"] = 0
	_seed(source.workers[id], Nutrition.max_deficit_ticks(source) - 3)
	source.economy_enabled = true
	var restored = World.new()
	if not restored.from_data(_json(source)):
		failures.append("A living zero-satiety citizen three ticks short of starvation must load")
		return
	for _tick: int in range(2):
		source.step_tick()
		restored.step_tick()
	_check(source.workers.has(id) and restored.workers.has(id),
		"Neither loading nor low satiety may kill a citizen before seven actual unfed days", failures)
	source.step_tick()
	restored.step_tick()
	_check(not source.workers.has(id) and not restored.workers.has(id)
		and restored.to_data() == source.to_data() and restored.workers.has(passer)
		and int(restored.tile_reservations.get(door, 0)) == passer,
		"The saved 42000th unfed tick must kill exactly its owner without releasing another citizen's doorway reservation", failures)


static func _test_repeated_loading_cannot_extend_survival(failures: Array[String]) -> void:
	var world = World.new(Vector2i(8, 8))
	var id: int = world.spawn_worker(Vector2i(3, 3), "militia")
	world.workers[id]["hunger"] = 0
	_seed(world.workers[id], Nutrition.max_deficit_ticks(world) - 11)
	world.economy_enabled = true
	for elapsed: int in range(11):
		var next = World.new()
		if not next.from_data(_json(world)):
			failures.append("Each living zero-satiety military save must remain valid up to the final unfed tick")
			return
		world = next
		world.step_tick()
		_check(world.workers.has(id) == (elapsed < 10),
			"Repeated saves must neither reset deprivation nor shorten the remaining seven-day grace period", failures)
