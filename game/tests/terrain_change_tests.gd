extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const TEST_COUNT: int = 6


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_initial_and_definition_invalidation(failures)
	_test_surface_mutators(failures)
	_test_terrain_and_shared_heights(failures)
	_test_independent_readers_and_bounded_storage(failures)
	_test_untracked_revision_fallback(failures)
	_test_rejected_and_noop_mutations(failures)
	return failures


static func _test_initial_and_definition_invalidation(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 2))
	_expect(grid.revision == 1 and grid.definition_revision == 1,
		"Change tracking preserves initial grid and definition revisions", failures)
	_expect(bool(grid.rendering_changes_since(-1)["full"]), "A new rendering client requests a complete map", failures)
	_expect_cells(grid, grid.revision, [], [], "An up-to-date client has no changed cells", failures)
	var revision: int = grid.revision
	grid.configure_movement({"terrain": {"grass": {"color": "809060"}}})
	_expect(grid.revision == revision + 1 and grid.definition_revision == 2
		and bool(grid.rendering_changes_since(revision)["full"]),
		"Definition changes retain one revision advance and invalidate the complete rendering", failures)
	_expect_cells(grid, grid.revision, [], [], "Acknowledged definition updates have no pending cells", failures)
	var empty_grid := Grid.new(Vector2i.ZERO)
	_expect_cells(empty_grid, empty_grid.revision, [], [], "Empty grids have safe empty change queries", failures)


static func _test_surface_mutators(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 3))
	grid.configure_movement({"trail": {"carrier_passes_to_form": 4}})
	var cell := Vector2i(1, 1)
	var revision: int = grid.revision
	grid.set_traffic_wear(cell, 1)
	_expect(grid.overlay_at(cell).is_empty(), "Partial wear fixture has not yet formed a trail", failures)
	_expect_cells(grid, revision, [], [cell], "Partial traffic wear refreshes only its surface", failures)
	revision = grid.revision
	grid.set_traffic_wear(cell, 0)
	_expect_cells(grid, revision, [], [cell], "Erasing partial wear refreshes its surface", failures)
	revision = grid.revision
	grid.record_carrier_traffic(cell)
	_expect_cells(grid, revision, [], [cell], "Carrier traffic below the trail threshold refreshes its surface", failures)
	revision = grid.revision
	grid.add_dirt_trail(cell)
	_expect_cells(grid, revision, [], [cell], "Explicit trails leave the static terrain unchanged", failures)
	revision = grid.revision
	grid.add_road(cell)
	_expect(grid.overlay_at(cell) == Grid.OVERLAY_STONE_ROAD and not grid.dirt_trails.has(cell),
		"Road upgrade still replaces the dirt trail", failures)
	_expect_cells(grid, revision, [], [cell], "Road upgrades refresh only surface geometry", failures)
	revision = grid.revision
	grid.block(cell, 17)
	_expect(not grid.is_walkable(cell) and grid.overlay_at(cell).is_empty(),
		"Building occupation still removes roads and changes passability", failures)
	_expect_cells(grid, revision, [], [cell], "Occupation refreshes surface and passability, not base geometry", failures)
	revision = grid.revision
	grid.unblock(cell)
	_expect_cells(grid, revision, [], [cell], "Unblocking refreshes passability without rebuilding base terrain", failures)
	revision = grid.revision
	grid.set_traffic_wear(cell, 3)
	grid.record_carrier_traffic(cell)
	_expect(grid.overlay_at(cell) == Grid.OVERLAY_TRAIL, "Carrier traffic still forms the trail at its configured threshold", failures)
	_expect_cells(grid, revision, [], [cell], "Multiple surface updates report their cell only once", failures)


static func _test_terrain_and_shared_heights(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 3))
	var cell := Vector2i(1, 1)
	grid.add_road(cell)
	var revision: int = grid.revision
	grid.set_base_terrain(cell, "water")
	_expect(grid.overlay_at(cell).is_empty(), "Impassable base terrain still removes its road", failures)
	_expect_cells(grid, revision, [cell], [cell], "Base changes refresh terrain and potentially removed surfaces", failures)
	grid.set_base_terrain(cell, "grass")
	grid.add_road(cell)
	revision = grid.revision
	grid.set_vertex_height(Vector2i(2, 2), 8)
	var shared: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
	_expect(grid.overlay_at(cell).is_empty(), "Steep shared height still invalidates an existing road", failures)
	_expect_cells(grid, revision, shared, shared, "Height changes report all four sharing cells in canonical order", failures)
	revision = grid.revision
	grid.set_vertex_height(Vector2i.ZERO, 2)
	_expect_cells(grid, revision, [Vector2i.ZERO], [Vector2i.ZERO], "A boundary vertex reports only cells inside the map", failures)


static func _test_independent_readers_and_bounded_storage(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 3))
	var older_reader: int = grid.revision
	grid.add_road(Vector2i(2, 2))
	var newer_reader: int = grid.revision
	grid.set_base_terrain(Vector2i(1, 0), "dirt")
	_expect_cells(grid, newer_reader, [Vector2i(1, 0)], [Vector2i(1, 0)], "A recent reader sees only later changes", failures)
	_expect_cells(grid, older_reader, [Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(2, 2)],
		"An earlier reader still sees changes after another reader queried them", failures)
	var unchanged_revision: int = grid.revision
	var first: Dictionary = grid.rendering_changes_since(older_reader)
	(first["surface"] as Array).clear()
	_expect_cells(grid, older_reader, [Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(2, 2)],
		"Returned collections cannot mutate future reader results", failures)
	_expect(grid.revision == unchanged_revision, "Reading change information must never mutate simulation revisions", failures)
	for _index: int in range(10000):
		grid.add_road(Vector2i(2, 2))
	_expect(grid._terrain_change_revisions.size() == 9 and grid._surface_change_revisions.size() == 9,
		"Tracking storage stays bounded by map cells after ten thousand revisions", failures)
	_expect_cells(grid, older_reader, [Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(2, 2)],
		"Long-idle clients retain every changed cell without an accumulating history log", failures)


static func _test_untracked_revision_fallback(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 3))
	var reader: int = grid.revision
	grid.roads[Vector2i.ONE] = true
	grid.revision += 1
	_expect(bool(grid.rendering_changes_since(reader)["full"]), "A legacy direct revision edit forces a full rebuild", failures)
	_expect(bool(grid.rendering_changes_since(reader)["full"]), "Full fallback remains available to independent readers", failures)
	reader = grid.revision
	_expect_cells(grid, reader, [], [], "A reader that rebuilt the direct change can acknowledge that revision", failures)
	grid.add_road(Vector2i(2, 2))
	_expect(bool(grid.rendering_changes_since(reader)["full"]),
		"The first tracked mutation after a legacy edit retains conservative fallback", failures)
	reader = grid.revision
	grid.add_road(Vector2i.ZERO)
	_expect_cells(grid, reader, [], [Vector2i.ZERO], "Tracked mutations resume incremental refresh after fallback is acknowledged", failures)
	reader = grid.revision
	grid.revision += 4
	grid.add_dirt_trail(Vector2i(1, 0))
	_expect(bool(grid.rendering_changes_since(reader)["full"]),
		"Unobserved revision gaps cannot be hidden by a subsequent normal mutation", failures)
	grid.revision = 0
	_expect(bool(grid.rendering_changes_since(reader)["full"]), "A rewound revision conservatively invalidates future readers", failures)
	grid.configure_movement({})
	reader = grid.revision
	grid.add_road(Vector2i(2, 0))
	_expect_cells(grid, reader, [], [Vector2i(2, 0)], "Definition reconfiguration after a rewind clears obsolete future timestamps", failures)


static func _test_rejected_and_noop_mutations(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 3))
	var revision: int = grid.revision
	grid.set_base_terrain(Vector2i.ZERO, "grass")
	grid.set_base_terrain(Vector2i(-1, 0), "water")
	grid.set_vertex_height(Vector2i.ONE, 0)
	grid.set_vertex_height(Vector2i(-1, 0), 3)
	grid.unblock(Vector2i.ZERO)
	grid.set_traffic_wear(Vector2i.ZERO, 0)
	grid.block(Vector2i(-1, 0), 17)
	_expect(grid.revision == revision, "No-op and rejected grid edits preserve their original revision behavior", failures)
	_expect_cells(grid, revision, [], [], "No-op edits do not dirty either rendering layer", failures)
	grid.add_road(Vector2i.ONE)
	revision = grid.revision
	grid.record_carrier_traffic(Vector2i.ONE)
	grid.set_traffic_wear(Vector2i.ONE, 3)
	grid.add_dirt_trail(Vector2i.ONE)
	_expect(grid.revision == revision, "Rejected wear and trail mutations on a road do not advance revision", failures)
	_expect_cells(grid, revision, [], [], "Rejected surface changes leave the cache clean", failures)


static func _expect_cells(grid: Grid, previous_revision: int, terrain: Array[Vector2i], surface: Array[Vector2i],
		message: String, failures: Array[String]) -> void:
	var changes: Dictionary = grid.rendering_changes_since(previous_revision)
	_expect(not bool(changes["full"]) and changes["terrain"] == terrain and changes["surface"] == surface,
		message, failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
