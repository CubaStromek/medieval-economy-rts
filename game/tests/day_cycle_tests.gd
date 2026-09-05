extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const DayCycle = preload("res://scripts/simulation/day_cycle.gd")
const TEST_COUNT: int = 7


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_new_world_and_read_only_clock,
		_test_minute_phase_and_calendar_boundaries,
		_test_full_cycle_uses_six_thousand_simulation_ticks,
		_test_current_json_preserves_clock_and_inventory,
		_test_saved_boundary_continues_on_next_tick,
		_test_historical_saves_project_existing_tick_without_migration,
		_test_large_json_ticks_keep_integer_precision,
	]:
		test.call(failures)
	return failures


static func _test_new_world_and_read_only_clock(failures: Array[String]) -> void:
	var world = World.new(Vector2i(2, 2))
	var before: Dictionary = world.to_data()
	for _read: int in range(20):
		_expect_clock(world.calendar_time(), 1, 5, 0, "dawn", "Fresh world", failures)
	_check(world.tick == 0 and world.to_data() == before,
		"Reading a paused clock repeatedly must not advance time or mutate the simulation", failures)
	var detached: Dictionary = world.calendar_time()
	detached["day"] = 99
	detached["hour"] = 23
	_expect_clock(world.calendar_time(), 1, 5, 0, "dawn", "After editing returned clock data", failures)


static func _test_minute_phase_and_calendar_boundaries(failures: Array[String]) -> void:
	var world = World.new(Vector2i(2, 2))
	# Explicit expectations describe the promised ten-minute day independently
	# of production constants or a second copy of its conversion formula.
	for row: Array in [
		[0, 1, 5, 0, "dawn"],
		[4, 1, 5, 0, "dawn"],
		[5, 1, 5, 1, "dawn"],
		[24, 1, 5, 5, "dawn"],
		[25, 1, 5, 6, "dawn"],
		[249, 1, 5, 59, "dawn"],
		[250, 1, 6, 0, "day"],
		[3249, 1, 17, 59, "day"],
		[3250, 1, 18, 0, "dusk"],
		[3749, 1, 19, 59, "dusk"],
		[3750, 1, 20, 0, "night"],
		[4749, 1, 23, 59, "night"],
		[4750, 2, 0, 0, "night"],
		[5999, 2, 4, 59, "night"],
		[6000, 2, 5, 0, "dawn"],
		[6250, 2, 6, 0, "day"],
		[10750, 3, 0, 0, "night"],
		[12000, 3, 5, 0, "dawn"],
	]:
		world.tick = int(row[0])
		var context: String = "Tick %d" % world.tick
		_expect_clock(DayCycle.at_tick(world.tick), row[1], row[2], row[3], row[4], context + " conversion", failures)
		_expect_clock(world.calendar_time(), row[1], row[2], row[3], row[4], context + " world clock", failures)


static func _test_full_cycle_uses_six_thousand_simulation_ticks(failures: Array[String]) -> void:
	var world = World.new(Vector2i(2, 2))
	for _tick: int in range(5999):
		world.step_tick()
	_check(world.tick == 5999, "The real simulation must execute all 5,999 requested ticks", failures)
	_expect_clock(world.calendar_time(), 2, 4, 59, "night", "One tick before a full day", failures)
	world.step_tick()
	_check(world.tick == 6000, "A complete ten-minute day must consume exactly 6,000 simulation ticks", failures)
	_expect_clock(world.calendar_time(), 2, 5, 0, "dawn", "One complete simulation day", failures)


static func _test_current_json_preserves_clock_and_inventory(failures: Array[String]) -> void:
	var source: Variant = _inventory_fixture()
	source.tick = 3817
	var before: Dictionary = source.to_data()
	_check(int(before["version"]) == World.SAVE_VERSION and int(before["version"]) >= 12,
		"A calendar save must use the current schema and retain indoor-save compatibility", failures)
	var restored = World.new()
	if not restored.from_data(_json(before)):
		failures.append("A populated current evening save must load through actual JSON serialization")
		return
	_check(restored.tick == 3817 and restored.to_data() == before,
		"Saving the calendar must retain the exact tick, workers, cargo, inventories and every persistent field", failures)
	_expect_clock(restored.calendar_time(), 1, 20, 16, "night", "Restored evening save", failures)
	_check(restored.stored_amount("plank") == 7
		and int(restored.resource_stock("log")["total"]) == 2
		and int(restored.resource_stock("stone")["total"]) == 1,
		"Clock loading must preserve stored planks, building inputs and the carrier's stone", failures)


static func _test_saved_boundary_continues_on_next_tick(failures: Array[String]) -> void:
	for row: Array in [
		[249, 1, 6, 0, "day"],
		[3249, 1, 18, 0, "dusk"],
		[3749, 1, 20, 0, "night"],
		[4749, 2, 0, 0, "night"],
		[5999, 2, 5, 0, "dawn"],
	]:
		# Keep inventory inert here: active NPC paths are intentionally replanned
		# after loading, independently of the persistent calendar and materials.
		var source: Variant = _inventory_fixture(false)
		source.tick = int(row[0])
		var restored = World.new()
		if not restored.from_data(_json(source.to_data())):
			failures.append("A save immediately before tick %d must load" % (source.tick + 1))
			continue
		_expect_clock(restored.calendar_time(), source.calendar_time()["day"], source.calendar_time()["hour"],
			source.calendar_time()["minute"], source.calendar_time()["phase"], "Before the restored boundary", failures)
		source.step_tick()
		restored.step_tick()
		_check(restored.tick == int(row[0]) + 1 and restored.to_data() == source.to_data(),
			"Resuming a saved phase or midnight boundary must match uninterrupted simulation state", failures)
		_expect_clock(restored.calendar_time(), row[1], row[2], row[3], row[4],
			"Resumed boundary at tick %d" % restored.tick, failures)


static func _test_historical_saves_project_existing_tick_without_migration(failures: Array[String]) -> void:
	var source: Variant = _inventory_fixture()
	source.tick = 10749
	var expected: Dictionary = source.to_data()
	for version: int in [11, 12]:
		var legacy: Dictionary = _json(expected)
		legacy["version"] = version
		for worker: Dictionary in legacy["workers"]:
			# The historical schemas predate soldier meal-delivery fields.
			worker.erase("meal_ticks_left")
			worker.erase("food_requested")
			worker.erase("ration_delivery")
			if version == 11:
				worker.erase("inside_building_id")
				worker.erase("indoor_wait_ticks")
		var restored = World.new()
		if not restored.from_data(legacy):
			failures.append("A historical v%d save must acquire its calendar from the preserved tick" % version)
			continue
		_check(restored.tick == 10749 and restored.to_data() == expected,
			"Introducing time must preserve legacy tick, outdoor workers, cargo and inventories exactly", failures)
		_expect_clock(restored.calendar_time(), 2, 23, 59, "night", "Legacy save before midnight", failures)
		restored.step_tick()
		_expect_clock(restored.calendar_time(), 3, 0, 0, "night", "Legacy save after midnight", failures)


static func _test_large_json_ticks_keep_integer_precision(failures: Array[String]) -> void:
	for row: Array in [
		[9007199254739999, 1501199875791, 4, 59, "night"],
		[9007199254740000, 1501199875791, 5, 0, "dawn"],
		[9007199254740499, 1501199875791, 6, 59, "day"],
		[9007199254740500, 1501199875791, 7, 0, "day"],
		[9007199254740991, 1501199875791, 8, 57, "day"],
	]:
		var source = World.new(Vector2i(2, 2))
		source.tick = int(row[0])
		_expect_clock(DayCycle.at_tick(source.tick), row[1], row[2], row[3], row[4],
			"Large tick %d conversion" % source.tick, failures)
		var restored = World.new()
		if not restored.from_data(_json(source.to_data())):
			failures.append("The calendar must support the existing JSON-safe tick %d" % source.tick)
			continue
		_check(restored.tick == source.tick, "Large saved simulation ticks must remain exact", failures)
		_expect_clock(restored.calendar_time(), row[1], row[2], row[3], row[4],
			"Large tick %d after JSON loading" % source.tick, failures)
		if source.tick == 9007199254739999:
			restored.step_tick()
			_expect_clock(restored.calendar_time(), 1501199875791, 5, 0, "dawn",
				"Restored large tick crossing dawn", failures)


static func _inventory_fixture(include_carrier: bool = true) -> Variant:
	var world = World.new(Vector2i(12, 9))
	var store: int = world.place_building("warehouse", Vector2i(2, 2))
	var sawmill: int = world.place_building("sawmill", Vector2i(6, 2))
	world.buildings[store]["storage"]["plank"] = 7
	world.buildings[sawmill]["inputs"]["log"] = 2
	if include_carrier:
		var carrier: int = world.spawn_worker(Vector2i(1, 7), "carrier")
		world.workers[carrier]["carrying"] = "stone"
	return world


static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data)) as Dictionary


static func _expect_clock(clock: Dictionary, day: int, hour: int, minute: int, phase: String,
	context: String, failures: Array[String]) -> void:
	_check(typeof(clock.get("day")) == TYPE_INT and typeof(clock.get("hour")) == TYPE_INT
		and typeof(clock.get("minute")) == TYPE_INT,
		context + ": calendar values must be integers", failures)
	_check(clock.get("day") == day and clock.get("hour") == hour
		and clock.get("minute") == minute and clock.get("phase") == phase,
		"%s: expected day %d %02d:%02d (%s), got %s" % [context, day, hour, minute, phase, clock], failures)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
