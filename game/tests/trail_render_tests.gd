extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const CacheTests = preload("res://tests/terrain_cache_tests.gd")
const DiagonalTests = preload("res://tests/diagonal_trail_tests.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_first_trips_are_invisible(failures)
	_test_repeated_traces_remain_subtle(failures)
	_test_mature_surface_readability(failures)
	_test_only_walked_links_connect(failures)
	_test_stone_and_mixed_links(failures)
	_test_new_link_invalidation(failures)
	_test_declining_trail_joins(failures)
	_test_disused_link_between_busy_junctions(failures)
	_test_decay_updates_only_surface(failures)
	return failures


static func _test_first_trips_are_invisible(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 6))
	var cell := Vector2i(3, 3)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var base_meshes: Dictionary = CacheTests._mesh_ids(renderer, "base")
	_expect(grid.carrier_passes_to_form_trail() == 36,
		"The trail appearance fixture must use the actual 36-pass game configuration", failures)
	for _pass: int in range(3):
		grid.record_carrier_traffic(cell)
		renderer.map_bounds()
		_expect((renderer._cells[cell]["surface_draws"] as Array).is_empty(),
			"The first three isolated trips must produce no brown wear geometry", failures)
		_expect(grid.overlay_at(cell).is_empty(), "Invisible first trips must not already form a trail", failures)
	_expect(CacheTests._mesh_ids(renderer, "base") == base_meshes,
		"Invisible traffic must retain the static terrain meshes", failures)
	renderer.free()


static func _test_repeated_traces_remain_subtle(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 6))
	var cell := Vector2i(3, 3)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var previous_opacity: float = 0.0
	var previous_radius: float = 0.0
	for wear: int in [4, 8, 12, 20, 28, 35]:
		grid.set_traffic_wear(cell, wear)
		renderer.map_bounds()
		var opacity: float = _layer_opacity(renderer, cell, "wear")
		var radius: float = _layer_radius(renderer, cell, "wear")
		_expect(opacity > previous_opacity and radius > previous_radius,
			"Repeated traffic must increase the submitted faint trace smoothly in opacity and size", failures)
		if wear <= 12:
			_expect(opacity <= 0.07, "Four to twelve trips must remain almost invisible, not paint 30-percent brown spots", failures)
		_expect(opacity < 0.78 and radius < 0.145 and grid.overlay_at(cell).is_empty(),
			"An immature trace must stay narrower and less opaque than a fully worn trail", failures)
		_expect(renderer.surface_connection_mask_for(cell) == 0 and renderer.diagonal_surface_connection_mask_for(cell) == 0,
			"Partial wear must never invent connected trail arms", failures)
		_expect(grid.step_duration_ticks(cell + Vector2i.LEFT, cell) == grid.movement_duration_ticks(Vector2i.ZERO),
			"A visible immature trace must not grant the mature trail speed", failures)
		previous_opacity = opacity
		previous_radius = radius
	renderer.free()


static func _test_mature_surface_readability(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 6))
	var trail := Vector2i(2, 2)
	var stone := Vector2i(5, 2)
	grid.add_dirt_trail(trail)
	grid.add_road(stone)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	_expect(is_equal_approx(_layer_opacity(renderer, trail, "trail_core"), 1.0),
		"Frequently reused mature trails must remain clearly readable rather than permanently translucent", failures)
	_expect(is_equal_approx(renderer._surface_half_width_for(trail), 0.145)
		and is_equal_approx(renderer._surface_expansion_for(trail, 0), 0.055),
		"Mature dirt paths should have a readable narrow core with restrained shoulders", failures)
	_expect(is_equal_approx(_layer_opacity(renderer, stone, "road_core"), 1.0)
		and is_equal_approx(renderer._surface_half_width_for(stone), 0.23)
		and is_equal_approx(renderer._surface_expansion_for(stone, 0), 0.09),
		"Player-built stone-road width, opacity and shoulders must retain their existing appearance", failures)
	for command: Dictionary in renderer._cells[stone]["surface_draws"]:
		if command["layer"] == "road_core":
			_expect(command["texture"] == renderer._textures[Grid.OVERLAY_STONE_ROAD],
				"Stone roads must keep using the authored cobble texture", failures)
	renderer.free()


static func _test_only_walked_links_connect(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 7))
	var route: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3)]
	# Repeatedly walk a U-shaped route out and back. All four cells mature,
	# but the missing fourth side and the diagonal X were never traversed.
	for _pass: int in range(36):
		for index: int in range(1, route.size()):
			grid.record_carrier_traffic(route[index], route[index - 1])
		for index: int in range(route.size() - 2, -1, -1):
			grid.record_carrier_traffic(route[index], route[index + 1])
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var degrees: Array[int] = [1, 2, 2, 1]
	for index: int in range(route.size()):
		var cell: Vector2i = route[index]
		_expect(grid.overlay_at(cell) == Grid.OVERLAY_TRAIL,
			"The no-spurious-joins fixture must mature all four actual traffic cells", failures)
		_expect(_bit_count(renderer.surface_connection_mask_for(cell)) == degrees[index],
			"A dense 2-by-2 group must retain only its actually traversed cardinal edges", failures)
		_expect(renderer.diagonal_surface_connection_mask_for(cell) == 0,
			"Neighboring mature trails must not generate an untraversed diagonal X", failures)
	_expect(not DiagonalTests._core_covers(renderer, Vector2(4, 3)),
		"The shared center of the 2-by-2 block must remain grass instead of a filled diagonal junction", failures)
	_expect(renderer.surface_edge_half_width(route[0], Vector2i.DOWN) == 0.0
		and renderer.surface_edge_half_width(route[0], Vector2i.ONE) == 0.0,
		"Unwalked neighboring directions must report no rendered edge width", failures)
	grid.record_carrier_traffic(route[2], route[0])
	renderer.map_bounds()
	_expect(renderer.diagonal_surface_connection_mask_for(route[0]) == 0,
		"One shortcut across established cells must not immediately add a full diagonal connector", failures)
	for _pass: int in range(35):
		grid.record_carrier_traffic(route[2], route[0])
	CacheTests._assert_matches_fresh(renderer, "Frequently used diagonal shortcut", failures)
	_expect(_bit_count(renderer.diagonal_surface_connection_mask_for(route[0])) == 1
		and renderer.diagonal_surface_connection_mask_for(route[1]) == 0,
		"Repeated shortcut traffic may add its one real diagonal but not the unrelated crossing diagonal", failures)
	DiagonalTests._assert_continuous(renderer, route[0], Vector2i.ONE, failures)
	renderer.free()


static func _test_stone_and_mixed_links(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 7))
	var stone := Vector2i(3, 2)
	var other_stone := Vector2i(4, 3)
	var dirt := Vector2i(3, 3)
	grid.add_road(stone)
	grid.add_road(other_stone)
	for _pass: int in range(36):
		grid.record_carrier_traffic(dirt)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	_expect(renderer.diagonal_surface_connection_mask_for(stone) != 0,
		"Two player-built stone cells must keep automatic legal diagonal connections", failures)
	_expect(renderer.surface_connection_mask_for(dirt) == 0,
		"A naturally worn dirt cell must not automatically connect to adjacent stone roads", failures)
	for _pass: int in range(36):
		grid.record_carrier_traffic(dirt, stone)
	CacheTests._assert_matches_fresh(renderer, "Established mixed approach", failures)
	_expect(_bit_count(renderer.surface_connection_mask_for(dirt)) == 1
		and renderer.surface_edge_half_width(dirt, Vector2i.UP) > 0.0
		and renderer.surface_edge_half_width(dirt, Vector2i.RIGHT) == 0.0,
		"A used dirt-to-stone approach must connect only its actual direction", failures)
	renderer.free()


static func _test_new_link_invalidation(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(12, 10))
	var first := Vector2i(5, 4)
	var second := Vector2i(6, 5)
	grid.set_trail_state(first, 36, 0, true)
	grid.set_trail_state(second, 36, 0, true)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var before: Array = CacheTests._cell_commands(renderer, first)
	var base_meshes: Dictionary = CacheTests._mesh_ids(renderer, "base")
	var base_builds: int = renderer.base_cell_build_count
	var surface_builds: int = renderer.surface_cell_build_count
	for _pass: int in range(36):
		grid.record_carrier_traffic(second, first)
	CacheTests._assert_matches_fresh(renderer, "New recorded diagonal edge", failures)
	_expect(CacheTests._cell_commands(renderer, first) != before,
		"A new real link must refresh both cached mature endpoints even if neither cell wear changes", failures)
	_expect(renderer.surface_cell_build_count - surface_builds <= 14
		and renderer.base_cell_build_count == base_builds and CacheTests._mesh_ids(renderer, "base") == base_meshes,
		"An edge change must refresh only its two endpoint neighborhoods and retain all base meshes", failures)
	grid.set_trail_link(first, second, 0, 0, false)
	CacheTests._assert_matches_fresh(renderer, "Recorded diagonal link erased", failures)
	_expect(not DiagonalTests._has_core(renderer, first + Vector2i.RIGHT)
		and not DiagonalTests._has_core(renderer, first + Vector2i.DOWN),
		"Removing a recorded diagonal edge must remove both clipped side-cell fragments", failures)
	renderer.free()


static func _test_declining_trail_joins(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(8, 7))
	var first := Vector2i(3, 2)
	var second := Vector2i(4, 3)
	grid.add_dirt_trail(first)
	grid.add_dirt_trail(second)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var full_width: float = renderer.surface_edge_half_width(first, Vector2i.ONE)
	var previous_opacity: float = 1.1
	for wear: int in [36, 28, 20, 16]:
		grid.set_traffic_wear(second, wear)
		CacheTests._assert_matches_fresh(renderer, "Fading mature endpoint %d" % wear, failures)
		var opacity: float = _layer_opacity(renderer, second, "trail_core")
		_expect(opacity < previous_opacity and grid.overlay_at(second) == Grid.OVERLAY_TRAIL,
			"Established dirt paths must visibly fade before falling below the retained-trail threshold", failures)
		var width: float = renderer.surface_edge_half_width(first, Vector2i.ONE)
		_expect(width <= full_width and is_equal_approx(width, renderer.surface_edge_half_width(second, -Vector2i.ONE)),
			"Different wear strengths must taper to an identical shared diagonal width", failures)
		DiagonalTests._assert_continuous(renderer, first, Vector2i.ONE, failures)
		previous_opacity = opacity
	_expect(previous_opacity < 0.15,
		"A path about to lose its established state must already be visibly faint", failures)
	grid.set_traffic_wear(second, 15)
	CacheTests._assert_matches_fresh(renderer, "Trail falls back to weak wear", failures)
	_expect(grid.overlay_at(second).is_empty() and _layer_opacity(renderer, second, "wear") < 0.15,
		"Demotion must leave only a subtle trace, not a full-opacity path that suddenly vanishes", failures)
	renderer.free()


static func _test_decay_updates_only_surface(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(12, 10))
	var first := Vector2i(5, 4)
	var second := Vector2i(6, 5)
	grid.add_dirt_trail(first)
	grid.add_dirt_trail(second)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var base_meshes: Dictionary = CacheTests._mesh_ids(renderer, "base")
	var base_builds: int = renderer.base_cell_build_count
	var surface_builds: int = renderer.surface_cell_build_count
	grid.tick_trails(grid.trail_established_decay_ticks())
	CacheTests._assert_matches_fresh(renderer, "Actual mature decay tick", failures)
	_expect(grid.traffic_wear_at(first) == 35 and _layer_opacity(renderer, first, "trail_core") < 1.0,
		"The real decay scheduler must update the submitted trail appearance", failures)
	_expect(renderer.surface_cell_build_count - surface_builds <= 14,
		"Decay may rebuild only affected endpoint neighborhoods, not the whole map", failures)
	var last_mature_tick: int = (grid.carrier_passes_to_form_trail() - grid.trail_retention_passes()) * grid.trail_established_decay_ticks()
	grid.tick_trails(last_mature_tick)
	CacheTests._assert_matches_fresh(renderer, "Late mature decay", failures)
	grid.tick_trails(last_mature_tick + grid.trail_established_decay_ticks())
	CacheTests._assert_matches_fresh(renderer, "Actual trail demotion", failures)
	_expect(renderer.diagonal_surface_connection_mask_for(first) == 0
		and not DiagonalTests._has_core(renderer, first + Vector2i.RIGHT),
		"A decayed connection must remove its cached diagonal arms and side-cell geometry", failures)
	grid.tick_trails(last_mature_tick + grid.trail_established_decay_ticks() + 16 * grid.trail_weak_decay_ticks())
	CacheTests._assert_matches_fresh(renderer, "Forgotten trail", failures)
	_expect((renderer._cells[first]["surface_draws"] as Array).is_empty()
		and (renderer._cells[second]["surface_draws"] as Array).is_empty(),
		"Fully regrown trails must leave no stale wear or road geometry", failures)
	_expect(renderer.base_cell_build_count == base_builds and CacheTests._mesh_ids(renderer, "base") == base_meshes,
		"All stages of real trail decay must leave static base terrain retained", failures)
	renderer.free()


static func _test_disused_link_between_busy_junctions(failures: Array[String]) -> void:
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.ONE]:
		var grid := Grid.new(Vector2i(8, 7))
		var first := Vector2i(3, 2)
		var second: Vector2i = first + direction
		grid.add_dirt_trail(first)
		grid.add_dirt_trail(second)
		var renderer := Renderer.new()
		renderer.bind_grid(grid)
		var base_meshes: Dictionary = CacheTests._mesh_ids(renderer, "base")
		var previous_width: float = INF
		var previous_opacity: float = 1.1
		var midpoint: Vector2 = Vector2(first) + Vector2(0.5, 0.5) + Vector2(direction) * 0.5
		for wear: int in [36, 28, 20, 16]:
			grid.set_trail_link(first, second, wear, 0, true)
			CacheTests._assert_matches_fresh(renderer, "Disused branch wear %d" % wear, failures)
			var width: float = renderer.surface_edge_half_width(first, direction)
			var opacity: float = _core_opacity_at(renderer, midpoint)
			_expect(width < previous_width and opacity < previous_opacity,
				"A disused recorded branch must narrow and fade even when both junction cells remain busy", failures)
			_expect(is_equal_approx(width, renderer.surface_edge_half_width(second, -direction)),
				"Both ends of a fading branch must retain an identical shared width", failures)
			_expect(_layer_opacity(renderer, first, "trail_core") == 1.0
				and _layer_opacity(renderer, second, "trail_core") == 1.0
				and grid.traffic_wear_at(first) == 36 and grid.traffic_wear_at(second) == 36,
				"Fading a branch must not dim or consume its independently busy junction cells", failures)
			if direction == Vector2i.ONE:
				DiagonalTests._assert_continuous(renderer, first, direction, failures)
			previous_width = width
			previous_opacity = opacity
		_expect(previous_opacity < 0.15,
			"A soon-to-disappear branch must already be faint at the retained-link threshold", failures)
		grid.set_trail_link(first, second, 15, 0, false)
		CacheTests._assert_matches_fresh(renderer, "Disused branch regrown", failures)
		_expect(renderer.surface_edge_half_width(first, direction) == 0.0
			and _core_opacity_at(renderer, midpoint) == 0.0,
			"An expired branch must disappear while its mature endpoint discs remain", failures)
		_expect(CacheTests._mesh_ids(renderer, "base") == base_meshes,
			"Independent branch aging must not rebuild static terrain", failures)
		renderer.free()


static func _core_opacity_at(renderer: Renderer, world_point: Vector2) -> float:
	var cell := Vector2i(floori(world_point.x), floori(world_point.y))
	var uv: Vector2 = world_point - Vector2(cell)
	var result: float = 0.0
	for command: Dictionary in renderer._cells[cell]["surface_draws"]:
		if not String(command["layer"]).ends_with("_core"):
			continue
		var vertices: PackedVector2Array = command["uvs"]
		if Renderer._point_in_triangle(uv, vertices[0], vertices[1], vertices[2]):
			result = maxf(result, (command["colors"] as PackedColorArray)[0].a)
	return result


static func _layer_opacity(renderer: Renderer, cell: Vector2i, layer: String) -> float:
	var result: float = 0.0
	for command: Dictionary in renderer._cells[cell]["surface_draws"]:
		if command["layer"] == layer:
			result = maxf(result, (command["colors"] as PackedColorArray)[0].a)
	return result


static func _layer_radius(renderer: Renderer, cell: Vector2i, layer: String) -> float:
	var result: float = 0.0
	for command: Dictionary in renderer._cells[cell]["surface_draws"]:
		if command["layer"] == layer:
			for uv: Vector2 in command["uvs"]:
				result = maxf(result, uv.distance_to(Vector2(0.5, 0.5)))
	return result


static func _bit_count(mask: int) -> int:
	var result: int = 0
	while mask > 0:
		result += mask & 1
		mask >>= 1
	return result


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
