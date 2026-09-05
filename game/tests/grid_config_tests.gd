extends RefCounted

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const GridPathfinderClass = preload("res://scripts/simulation/grid_pathfinder.gd")
const TEST_COUNT: int = 2


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_catalog_defaults_and_override_isolation(failures)
	_test_weighted_paths_and_ties(failures)
	return failures


static func _test_catalog_defaults_and_override_isolation(failures: Array[String]) -> void:
	var catalog := DefinitionCatalogClass.new()
	var grid := GridMapSimClass.new(Vector2i(4, 4))
	var terrain: Dictionary = catalog.movement["terrain"] as Dictionary
	var overlays: Dictionary = catalog.movement["overlays"] as Dictionary
	for terrain_id: String in GridMapSimClass.BASE_TERRAIN_IDS:
		_expect(grid.terrain_definition(terrain_id) == terrain[terrain_id],
			"Standalone grid must use the complete catalog definition for " + terrain_id, failures)
	for overlay_id: String in [GridMapSimClass.OVERLAY_TRAIL, GridMapSimClass.OVERLAY_STONE_ROAD]:
		_expect(grid.overlay_definition(overlay_id) == overlays[overlay_id],
			"Standalone grid must use the complete catalog definition for " + overlay_id, failures)
	_expect(grid.carrier_passes_to_form_trail() == int(catalog.movement["trail"]["carrier_passes_to_form"]),
		"Standalone grid must use the authored trail threshold", failures)

	var original_grass: Dictionary = grid.terrain_definition("grass").duplicate(true)
	var original_trail: Dictionary = grid.overlay_definition("trail").duplicate(true)
	(terrain["grass"] as Dictionary)["move_ticks"] = 17
	(overlays["trail"] as Dictionary)["move_ticks"] = 7
	(catalog.movement["trail"] as Dictionary)["carrier_passes_to_form"] = 9
	grid.configure_movement(catalog.movement)
	_expect(grid.movement_duration_ticks(Vector2i.ZERO) == 17,
		"A grid must apply custom catalog movement values", failures)
	grid.add_dirt_trail(Vector2i(1, 0))
	_expect(grid.movement_duration_ticks(Vector2i(1, 0)) == 7
		and grid.carrier_passes_to_form_trail() == 9,
		"A grid must apply custom catalog overlay values and wear thresholds", failures)
	(terrain["grass"] as Dictionary)["move_ticks"] = 99
	_expect(grid.movement_duration_ticks(Vector2i.ZERO) == 17,
		"Changing a catalog after configuration must not mutate an existing grid", failures)

	var fresh_grid := GridMapSimClass.new(Vector2i(4, 4))
	var fresh_catalog := DefinitionCatalogClass.new()
	_expect(fresh_grid.terrain_definition("grass") == original_grass
		and fresh_grid.overlay_definition("trail") == original_trail,
		"Runtime overrides must not leak into the defaults of later grids", failures)
	_expect(fresh_catalog.movement["terrain"]["grass"] == original_grass,
		"Runtime overrides must not leak into the defaults of later catalogs", failures)

	var revision_before: int = grid.definition_revision
	grid.configure_movement({
		"terrain": {"grass": {"move_ticks": 13}},
		"overlays": {"trail": {"move_ticks": 5}},
	})
	_expect(grid.is_walkable(Vector2i.ZERO) and grid.is_buildable(Vector2i.ZERO)
		and grid.allows_trees(Vector2i.ZERO) and grid.is_roadable(Vector2i.ZERO),
		"Partial movement overrides must preserve the other terrain rules", failures)
	_expect(grid.terrain_definition("grass")["color"] == original_grass["color"]
		and grid.overlay_definition("trail")["color"] == original_trail["color"],
		"Partial movement overrides must preserve authored display properties", failures)
	_expect(grid.movement_cost(Vector2i.ZERO) == 13
		and grid.movement_cost(Vector2i(1, 0)) == 5
		and grid.definition_revision == revision_before + 1,
		"Reconfiguration must update path costs and invalidate definition clients", failures)

	grid.configure_movement({"surfaces": {
		"grass": {"move_ticks": 12}, "dirt": {"move_ticks": 4}, "stone": {"move_ticks": 2},
	}})
	grid.add_road(Vector2i(2, 0))
	_expect(grid.movement_cost(Vector2i.ZERO) == 12
		and grid.movement_cost(Vector2i(1, 0)) == 4
		and grid.movement_cost(Vector2i(2, 0)) == 2,
		"Legacy surface overrides must continue to configure all three movement tiers", failures)
	_expect(grid.is_walkable(Vector2i.ZERO)
		and fresh_grid.terrain_definition("grass") == original_grass,
		"Legacy overrides must preserve terrain rules and remain isolated", failures)


static func _test_weighted_paths_and_ties(failures: Array[String]) -> void:
	var grid := GridMapSimClass.new(Vector2i(7, 4))
	grid.configure_movement({
		"terrain": {"grass": {"move_ticks": 6}},
		"overlays": {"stone_road": {"move_ticks": 2}},
	})
	for x: int in range(7):
		grid.add_road(Vector2i(x, 0))
	var start := Vector2i(0, 2)
	var goal := Vector2i(6, 2)
	var expected: Array[Vector2i] = [Vector2i(0, 1)]
	for x: int in range(1, 7):
		expected.append(Vector2i(x, 0))
	expected.append_array([Vector2i(6, 1), goal])
	var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, start, goal)
	_expect(path == expected and GridPathfinderClass.path_cost(grid, path, start) == 31,
		"A* must select the cheaper 31-tick diagonal-entry road detour over the 36-tick direct route", failures)
	var nearest_path: Array[Vector2i] = GridPathfinderClass.find_path_to_nearest(
		grid, start, func(cell: Vector2i) -> bool: return cell == goal)
	_expect(GridPathfinderClass.path_cost(grid, nearest_path, start) == 31,
		"A* and nearest-goal search must agree on weighted optimal cost", failures)
	var blocked_path: Array[Vector2i] = GridPathfinderClass.find_path(
		grid, start, goal, {Vector2i(3, 0): true})
	_expect(GridPathfinderClass.path_cost(grid, blocked_path, start) == 36
		and not blocked_path.has(Vector2i(3, 0)),
		"Blocking the road corridor must select the direct optimal route", failures)

	var tie_grid := GridMapSimClass.new(Vector2i(3, 3))
	tie_grid.set_base_terrain(Vector2i(1, 1), "water")
	var north_route: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1),
	]
	var south_route: Array[Vector2i] = [
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1),
	]
	_expect(GridPathfinderClass.find_path(tie_grid, Vector2i(0, 1), Vector2i(2, 1)) == north_route,
		"Equal-cost A* routes must retain canonical row/column tie ordering", failures)
	_expect(GridPathfinderClass.find_path(tie_grid, Vector2i(0, 1), Vector2i(2, 1),
		{Vector2i(0, 0): true}) == south_route,
		"A temporary blocker must exclude the canonical equal-cost route", failures)
	_expect(GridPathfinderClass.find_path(tie_grid, Vector2i(0, 1), Vector2i(2, 1),
		{Vector2i(0, 0): true, Vector2i(0, 2): true}).is_empty(),
		"An unreachable target must return no route", failures)

	var nearest_ties := GridMapSimClass.new(Vector2i(3, 3))
	var expected_nearest: Array[Vector2i] = [Vector2i(0, 0)]
	var tied_goals: Dictionary = {Vector2i(0, 0): true, Vector2i(2, 0): true}
	_expect(GridPathfinderClass.find_path_to_nearest(nearest_ties, Vector2i(1, 1),
		func(cell: Vector2i) -> bool: return tied_goals.has(cell)) == expected_nearest,
		"Equal-cost nearest goals must retain canonical row/column tie ordering", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
