extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const TEST_COUNT: int = 14


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_production_profile,
		_test_gradual_formation_and_cap,
		_test_only_traversed_connections,
		_test_weak_decay_preserves_partial_periods,
		_test_established_hysteresis_and_full_regrowth,
		_test_busy_trail_does_not_reset_decay_time,
		_test_bidirectional_link_is_canonical,
		_test_fast_forward_matches_incremental_decay,
		_test_speed_requires_real_worn_connection,
		_test_mutations_remove_invalid_links,
		_test_authored_trails_start_at_current_time,
		_test_strict_state_setters,
		_test_sparse_bounded_state_and_mature_invalidation,
		_test_link_decay_invalidates_both_endpoints,
	]:
		test.call(failures)
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_production_profile(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	_expect(grid.carrier_passes_to_form_trail() == 36 and grid.trail_retention_passes() == 16
		and grid.trail_weak_decay_ticks() == 200 and grid.trail_established_decay_ticks() == 400,
		"Production trails require 36 retained passes with 20/40-second weak/mature decay and 16-pass retention", failures)
	grid.configure_movement({"trail": {"carrier_passes_to_form": 2}})
	_expect(grid.trail_retention_passes() == 1 and grid.set_trail_state(Vector2i.ONE, 2, 0, true),
		"Small authored/test thresholds keep a valid proportionate hysteresis threshold", failures)
	grid.configure_movement({"trail": {"carrier_passes_to_form": 36}})
	_expect(grid.traffic_wear_at(Vector2i.ONE) == 2 and not grid.dirt_trails.has(Vector2i.ONE),
		"Changing the profile keeps existing wear within the new hysteresis rules", failures)


static func _test_gradual_formation_and_cap(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var cell := Vector2i.ONE
	for _pass: int in range(4):
		grid.record_carrier_traffic(cell)
	_expect(grid.traffic_wear_at(cell) == 4 and grid.overlay_at(cell).is_empty(),
		"A few visits leave weak wear without making a functional trail", failures)
	for _pass: int in range(31):
		grid.record_carrier_traffic(cell)
	_expect(grid.traffic_wear_at(cell) == 35 and not grid.dirt_trails.has(cell),
		"The functional trail cannot form one visit before the threshold", failures)
	_expect(grid.record_carrier_traffic(cell) and grid.dirt_trails.has(cell),
		"The 36th retained visit establishes the trail", failures)
	for _pass: int in range(100):
		grid.record_carrier_traffic(cell)
	_expect(grid.traffic_wear_at(cell) == 36, "Continued use cannot grow trail memory beyond its cap", failures)


static func _test_only_traversed_connections(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(5, 5))
	var a := Vector2i.ONE
	var b := Vector2i(2, 2)
	var c := Vector2i(2, 1)
	var d := Vector2i(1, 2)
	for cell: Vector2i in [a, b, c, d]:
		grid.set_trail_state(cell, 36, 0, true)
	_expect(grid.trail_links.is_empty() and not grid.trail_connection_active(a, b),
		"Four nearby muddy tiles never invent diagonal or crossing connections", failures)
	for _pass: int in range(36):
		grid.record_carrier_traffic(b, a, 0)
	_expect(grid.trail_connection_active(a, b) and not grid.trail_connection_active(c, d)
		and not grid.trail_connection_active(a, c) and grid.trail_links.size() == 1,
		"Only the repeatedly traversed diagonal becomes a visible/usable link", failures)


static func _test_weak_decay_preserves_partial_periods(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var cell := Vector2i.ONE
	grid.record_carrier_traffic(cell, Grid.NO_CELL, 0)
	grid.record_carrier_traffic(cell, Grid.NO_CELL, 199)
	_expect(grid.traffic_wear_at(cell) == 2 and int(grid.trail_last_decay[cell]) == 0,
		"A pass just before decay preserves the already elapsed partial period", failures)
	grid.record_carrier_traffic(cell, Grid.NO_CELL, 200)
	_expect(grid.traffic_wear_at(cell) == 2 and int(grid.trail_last_decay[cell]) == 200,
		"A pass on the decay boundary first pays the elapsed decay and then adds one visit", failures)
	grid.record_carrier_traffic(cell, Grid.NO_CELL, 399)
	grid.tick_trails(400)
	_expect(grid.traffic_wear_at(cell) == 2 and int(grid.trail_last_decay[cell]) == 400,
		"Repeated traffic does not postpone a weak trail's next full decay period", failures)
	grid.tick_trails(800)
	_expect(grid.traffic_wear.is_empty() and grid.trail_last_decay.is_empty(),
		"Abandoned weak footprints fully disappear and release their timestamps", failures)


static func _mature_pair() -> Dictionary:
	var grid := Grid.new(Vector2i(4, 4))
	var from := Vector2i.ONE
	var to := Vector2i(2, 1)
	grid.set_trail_state(from, 36, 0, true)
	grid.set_trail_state(to, 36, 0, true)
	grid.set_trail_link(from, to, 36, 0, true)
	return {"grid": grid, "from": from, "to": to}


static func _test_established_hysteresis_and_full_regrowth(failures: Array[String]) -> void:
	var fixture: Dictionary = _mature_pair()
	var grid = fixture["grid"]
	var from: Vector2i = fixture["from"]
	var to: Vector2i = fixture["to"]
	grid.tick_trails(8000)
	_expect(grid.traffic_wear_at(to) == 16 and grid.dirt_trails.has(to) and grid.trail_connection_active(from, to),
		"An established route remains functional at the 16-pass hysteresis boundary", failures)
	grid.tick_trails(8400)
	_expect(grid.traffic_wear_at(to) == 15 and not grid.dirt_trails.has(to) and not grid.trail_connection_active(from, to),
		"Only falling below 16 retained passes turns the mature route back into weak wear", failures)
	grid.tick_trails(8600)
	_expect(grid.traffic_wear_at(to) == 14, "Demoted trails switch to the faster weak decay period", failures)
	grid.tick_trails(11400)
	_expect(grid.traffic_wear.is_empty() and grid.dirt_trails.is_empty()
		and grid.trail_last_decay.is_empty() and grid.trail_links.is_empty(),
		"Unused mature trails eventually regrow completely, including all link state", failures)


static func _test_busy_trail_does_not_reset_decay_time(failures: Array[String]) -> void:
	var fixture: Dictionary = _mature_pair()
	var grid = fixture["grid"]
	var from: Vector2i = fixture["from"]
	var to: Vector2i = fixture["to"]
	grid.record_carrier_traffic(to, from, 399)
	_expect(int(grid.trail_last_decay[to]) == 0 and int(grid.trail_links[Grid.trail_link_key(from, to)]["decay_tick"]) == 0,
		"Refreshing a full trail does not erase its elapsed decay time", failures)
	grid.tick_trails(400)
	_expect(grid.traffic_wear_at(to) == 35, "Even a recently traversed capped trail pays each full elapsed decay period", failures)
	grid.record_carrier_traffic(to, from, 799)
	grid.tick_trails(800)
	_expect(grid.traffic_wear_at(to) == 35 and int(grid.trail_last_decay[to]) == 800,
		"Mature traffic replenishes wear while preserving deterministic absolute decay timing", failures)


static func _test_bidirectional_link_is_canonical(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var a := Vector2i.ONE
	var b := Vector2i(2, 2)
	for index: int in range(72):
		grid.record_carrier_traffic(b if index % 2 == 0 else a, a if index % 2 == 0 else b, 0)
	var key: Vector4i = Grid.trail_link_key(a, b)
	_expect(key == Grid.trail_link_key(b, a) and grid.trail_links.size() == 1
		and int(grid.trail_links[key]["wear"]) == 36 and grid.trail_connection_active(a, b),
		"Journeys in both directions reinforce one bounded canonical edge", failures)


static func _test_fast_forward_matches_incremental_decay(failures: Array[String]) -> void:
	var first: Dictionary = _mature_pair()
	var second: Dictionary = _mature_pair()
	for now: int in range(20, 9301, 20):
		first["grid"].tick_trails(now)
	second["grid"].tick_trails(9300)
	_expect(first["grid"].traffic_wear == second["grid"].traffic_wear
		and first["grid"].dirt_trails == second["grid"].dirt_trails
		and first["grid"].trail_last_decay == second["grid"].trail_last_decay
		and first["grid"].trail_links == second["grid"].trail_links,
		"One large elapsed-time update matches repeated updates across the mature-to-weak transition", failures)


static func _test_speed_requires_real_worn_connection(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(5, 5))
	var a := Vector2i.ONE
	var b := Vector2i(2, 1)
	var c := Vector2i(2, 2)
	for cell: Vector2i in [a, b, c]:
		grid.set_trail_state(cell, 36, 0, true)
	_expect(grid.movement_duration_ticks(b) == 4 and grid.step_duration_ticks(a, b) == 6
		and grid.step_duration_ticks(a, c) == 9,
		"Muddy tiles alone do not grant shortcuts across unworn cardinal or diagonal links", failures)
	grid.set_trail_link(a, b, 36, 0, true)
	grid.set_trail_link(a, c, 36, 0, true)
	_expect(grid.step_duration_ticks(a, b) == 4 and grid.step_duration_ticks(a, c) == 6,
		"Established traversed connections grant the correct cardinal/diagonal mud speed", failures)
	grid.add_road(b)
	_expect(grid.step_duration_ticks(a, b) == 2 and grid.step_duration_ticks(b, a) == 4,
		"Paving keeps a previously worn approach and stone remains the fastest destination", failures)
	grid.add_road(Vector2i(1, 0))
	_expect(grid.step_duration_ticks(Vector2i(1, 0), a) == 6,
		"A newly placed neighboring road does not invent a natural-trail connection", failures)


static func _test_mutations_remove_invalid_links(failures: Array[String]) -> void:
	for mutation: String in ["block", "water", "height", "clear"]:
		var grid := Grid.new(Vector2i(5, 5))
		var a := Vector2i.ONE
		var b := Vector2i(2, 2)
		grid.add_dirt_trail(a)
		grid.add_dirt_trail(b)
		_expect(grid.trail_connection_active(a, b), "Authored fixture begins with its explicit connected diagonal", failures)
		match mutation:
			"block": grid.block(Vector2i(2, 1), 99)
			"water": grid.set_base_terrain(Vector2i(2, 1), "water")
			"height": grid.set_vertex_height(Vector2i(3, 1), Grid.MAX_WALK_SLOPE + 1)
			"clear": grid.clear_trail(a)
		_expect(grid.trail_links.is_empty() and not grid.trail_connection_active(a, b),
			"Clearing ground or invalidating a diagonal flank removes its stored link: " + mutation, failures)


static func _test_authored_trails_start_at_current_time(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(5, 5))
	grid.tick_trails(9601)
	grid.add_dirt_trail(Vector2i.ONE)
	grid.add_dirt_trail(Vector2i(2, 1))
	grid.set_traffic_wear(Vector2i(3, 1), 4)
	_expect(int(grid.trail_last_decay[Vector2i.ONE]) == 9601
		and int(grid.trail_last_decay[Vector2i(3, 1)]) == 9601
		and int(grid.trail_links[Grid.trail_link_key(Vector2i.ONE, Vector2i(2, 1))]["decay_tick"]) == 9601,
		"Late authored wear and links begin at the current known simulation time, not tick zero", failures)
	grid.tick_trails(9800)
	_expect(grid.traffic_wear_at(Vector2i(3, 1)) == 4 and grid.traffic_wear_at(Vector2i.ONE) == 36,
		"Newly authored trails do not instantly regrow because of a stale default timestamp", failures)


static func _test_strict_state_setters(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var cell := Vector2i.ONE
	_expect(not grid.set_trail_state(cell, -1, 0, false)
		and not grid.set_trail_state(cell, 37, 0, true)
		and not grid.set_trail_state(cell, 15, 0, true)
		and not grid.set_trail_state(cell, 36, 0, false)
		and not grid.set_trail_state(cell, 1, -1, false),
		"Cell state setters reject invalid wear, hysteresis and timestamp combinations", failures)
	_expect(not grid.set_trail_link(cell, cell, 36, 0, true)
		and not grid.set_trail_link(cell, Vector2i(3, 3), 36, 0, true)
		and not grid.set_trail_link(cell, Vector2i(2, 1), 15, 0, true),
		"Link setters reject nonsteps and inconsistent established state", failures)
	grid.add_road(cell)
	grid.add_road(Vector2i(2, 1))
	_expect(not grid.set_trail_state(cell, 36, 0, true)
		and not grid.set_trail_link(cell, Vector2i(2, 1), 36, 0, true),
		"Stone ground never owns natural cell wear or redundant stone-to-stone link state", failures)


static func _test_sparse_bounded_state_and_mature_invalidation(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(300, 300))
	var a := Vector2i.ONE
	var b := Vector2i(2, 1)
	for _pass: int in range(36):
		grid.record_carrier_traffic(b, a, 0)
	var revision: int = grid.revision
	for _pass: int in range(100):
		grid.record_carrier_traffic(b, a, 0)
	grid.tick_trails(199)
	_expect(grid.traffic_wear.size() == 1 and grid.trail_last_decay.size() == 1 and grid.trail_links.size() == 1,
		"Large empty maps allocate trail state only for the one touched tile and edge", failures)
	_expect(grid.revision == revision and grid.rendering_changes_since(revision)["surface"].is_empty(),
		"Unchanged capped mature traffic and an incomplete decay period do not redraw terrain", failures)


static func _test_link_decay_invalidates_both_endpoints(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var a := Vector2i.ONE
	var b := Vector2i(2, 1)
	grid.set_trail_state(a, 36, 0, true)
	grid.set_trail_state(b, 36, 0, true)
	grid.set_trail_link(a, b, 1, 0, false)
	var revision: int = grid.revision
	grid.tick_trails(200)
	var changes: Dictionary = grid.rendering_changes_since(revision)
	_expect(grid.trail_links.is_empty() and not bool(changes["full"]) and changes["terrain"].is_empty()
		and changes["surface"].has(a) and changes["surface"].has(b),
		"Expiring an edge invalidates both endpoint surface caches without rebuilding base terrain", failures)
