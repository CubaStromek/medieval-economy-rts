extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Footprints = preload("res://scripts/simulation/building_footprints.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const TEST_COUNT: int = 14


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_source_shapes,
		_test_irregular_occupancy_and_selection,
		_test_full_boundary_checks,
		_test_obstacles_across_the_foundation,
		_test_fixed_southern_entrance,
		_test_common_level_foundation,
		_test_existing_entrance_protection,
		_test_full_surface_cleanup_and_cancellation,
		_test_legacy_geometry_is_per_building,
		_test_extraction_routes_after_placement,
		_test_training_and_indoor_doorway,
		_test_real_transport_and_production,
		_test_quarry_range_from_occupied_edge,
		_test_placement_during_visible_steps,
	]:
		test.call(failures)
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_source_shapes(failures: Array[String]) -> void:
	var world := World.new()
	_expect(world.catalog.buildings.size() == 30, "The footprint catalog covers all 28 classic menu buildings plus the Forester Hut and Workers' Cottage", failures)
	for type: String in world.catalog.buildings:
		var definition: Dictionary = world.catalog.building(type)
		_expect(Footprints.valid_definition(definition), "%s must have a tightly trimmed mask and one southern door" % type, failures)
		_expect(not String(definition.get("footprint_reference", "")).is_empty(), "%s must retain its footprint provenance" % type, failures)
	# These independent examples include every important shape class, including
	# the one-row mines and the two separate recesses of the armour smithy.
	for entry: Array in [
		["warehouse", ["###", "###", "#E#"], 9],
		["lumber_hut", [".###", ".##E", "###."], 9],
		["sawmill", ["####", "#E##"], 8],
		["farm", ["####", "####", "#E##"], 12],
		["barracks", ["####", "####", "####", "#E##"], 16],
		["fisher_hut", ["##.", "E##"], 5],
		["armour_smithy", [".##.", "####", "#E##"], 10],
		["gold_mine", ["#E"], 2],
		["iron_mine", ["#E#"], 3],
	]:
		var type: String = entry[0]
		_expect(world.catalog.building(type)["footprint_mask"] == entry[1]
			and world.placement_cells(type, Vector2i(5, 8)).size() == int(entry[2]),
			"%s must retain its current authored shape and occupied count" % type, failures)
	_expect(world.catalog.building("forester_hut")["footprint_mask"] == Footprints.for_version(world.catalog.building("lumber_hut"), 1)["footprint_mask"]
		and world.catalog.building("forester_hut")["footprint_source"] == "project_forester_woodcutter_shape",
		"The project Forester retains the historic woodcutter shape with explicit project attribution", failures)
	_expect(world.catalog.building("workers_house")["footprint_mask"] == ["##", "#E"]
		and world.placement_cells("workers_house", Vector2i(5, 8)).size() == 4
		and world.catalog.building("workers_house")["footprint_source"] == "project_workers_house"
		and int(world.catalog.building("workers_house")["residence_capacity"]) == 2,
		"The project Workers' Cottage must retain its authored four-cell footprint and two-bed capacity", failures)


static func _test_irregular_occupancy_and_selection(failures: Array[String]) -> void:
	var world := World.new()
	var anchor := Vector2i(4, 6)
	var id: int = world.place_building("armour_smithy", anchor)
	_expect(id != 0, "An irregular smithy must place on clear terrain", failures)
	if id == 0:
		return
	for cell: Vector2i in world.building_cells(world.buildings[id]):
		_expect(world.building_id_at(cell) == id and not world.grid.is_walkable(cell),
			"Every occupied mask tile must select the same building and block walking", failures)
	for recess: Vector2i in [Vector2i(4, 4), Vector2i(7, 4)]:
		_expect(world.building_id_at(recess) == 0 and world.grid.is_walkable(recess)
			and world.can_place_field(recess), "An empty mask recess must remain usable ground", failures)
	var path: Array[Vector2i] = Pathfinder.find_path(world.grid, Vector2i(3, 5), Vector2i(8, 5))
	_expect(not path.is_empty(), "Walking must find a route around a multi-cell building", failures)
	for cell: Vector2i in path:
		_expect(world.building_id_at(cell) == 0, "A route must never cut through an occupied footprint", failures)
	_expect(not world.grid.can_traverse(Vector2i(4, 4), Vector2i(3, 5)),
		"The occupied lower corner must prevent a diagonal squeeze out of the recess", failures)


static func _test_full_boundary_checks(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 12))
	for anchor: Vector2i in [Vector2i(2, 1), Vector2i(10, 5), Vector2i(2, 11)]:
		_expect(not world.can_place_building("warehouse", anchor),
			"A foundation or fixed exterior doorway outside the map must reject placement", failures)
	_expect(world.can_place_building("warehouse", Vector2i(0, 2)),
		"A complete foundation touching the map's north-west edge must be legal", failures)
	_expect(world.place_building("unknown_building", Vector2i(4, 6)) == 0,
		"Unknown definitions cannot allocate a building", failures)


static func _test_obstacles_across_the_foundation(failures: Array[String]) -> void:
	var anchor := Vector2i(4, 6)
	var remote_tile := Vector2i(6, 4)
	for kind: String in ["tree", "field", "deposit", "worker", "planting", "yielding"]:
		var world := World.new()
		match kind:
			"tree": world.add_tree(remote_tile, 3)
			"field": world.place_field(remote_tile)
			"deposit": world.add_deposit(remote_tile, "coal", 5)
			"worker": world.spawn_worker(remote_tile)
			"planting": world.planting_reservations[remote_tile] = 99
			"yielding": world._yielding_origins[remote_tile] = 99
		var before: Dictionary = world.to_data()
		var revision: int = world.grid.revision
		_expect(not world.can_place_building("warehouse", anchor)
			and world.place_building("warehouse", anchor) == 0,
			"A %s on any foundation tile must prevent the whole building" % kind, failures)
		_expect(world.to_data() == before and world.grid.revision == revision,
			"Rejected %s placement must leave simulation state untouched" % kind, failures)


static func _test_fixed_southern_entrance(failures: Array[String]) -> void:
	var world := World.new()
	var anchor := Vector2i(4, 6)
	var entrance := Vector2i(5, 7)
	_expect(world.placement_entrance("warehouse", anchor) == entrance,
		"The warehouse door has an authored southern exterior offset", failures)
	world.add_tree(entrance)
	_expect(not world.can_place_building("warehouse", anchor),
		"A blocked southern entry must reject placement even when other sides are clear", failures)
	var clear := World.new()
	clear.grid.add_road(entrance)
	var id: int = clear.place_building("warehouse", anchor)
	_expect(id != 0 and clear.grid.is_walkable(entrance) and clear.grid.roads.has(entrance),
		"A fixed exterior entry remains a walkable road after building placement", failures)
	_expect(clear.add_tree(entrance) == 0 and not clear.can_place_field(entrance),
		"Later authoring and field placement must keep the new door approach clear", failures)


static func _test_common_level_foundation(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 12))
	for y: int in range(13):
		for x: int in range(13):
			world.grid.set_vertex_height(Vector2i(x, y), 4)
	_expect(world.can_place_building("warehouse", Vector2i(4, 6)),
		"A multi-cell foundation may stand on a uniformly elevated plateau", failures)
	world.grid.set_vertex_height(Vector2i(6, 4), 5)
	_expect(not world.can_place_building("warehouse", Vector2i(4, 6)),
		"An uneven remote corner must invalidate the entire foundation", failures)
	world.grid.set_vertex_height(Vector2i(6, 4), 4)
	var id: int = world.place_building("warehouse", Vector2i(4, 6))
	_expect(id != 0 and not world.set_vertex_height(Vector2i(6, 4), 5)
		and not world.set_base_terrain(Vector2i(6, 4), "water"),
		"Live terrain edits cannot undermine any tile of an existing foundation", failures)


static func _test_existing_entrance_protection(failures: Array[String]) -> void:
	var world := World.new()
	var first: int = world.place_building("warehouse", Vector2i(3, 4))
	_expect(first != 0 and not world.can_place_building("warehouse", Vector2i(4, 7)),
		"A remote tile in a proposed mask cannot swallow an existing building entrance", failures)
	_expect(not world.can_place_building("warehouse", Vector2i(4, 5)),
		"A proposed foundation cannot overlap any existing occupied tile", failures)


static func _test_full_surface_cleanup_and_cancellation(failures: Array[String]) -> void:
	var world := World.new()
	var store: int = world.place_building("warehouse", Vector2i(1, 11))
	var anchor := Vector2i(7, 6)
	var cells: Array[Vector2i] = world.placement_cells("armour_smithy", anchor)
	for cell: Vector2i in cells:
		world.grid.add_road(cell)
	world.economy_enabled = true
	var site: int = world.place_building("armour_smithy", anchor)
	_expect(site != 0, "A multi-cell construction site may replace roads beneath its foundation", failures)
	if site == 0:
		return
	world.buildings[site]["construction_delivered"]["plank"] = 1
	for cell: Vector2i in cells:
		_expect(world.grid.overlay_at(cell).is_empty() and world.building_id_at(cell) == site,
			"Construction must clear surface state and reserve every occupied tile immediately", failures)
	_expect(world.cancel_construction(site) and int(world.buildings[store]["storage"]["plank"]) == 1,
		"Cancellation must refund delivered goods through the real exterior entrance", failures)
	for cell: Vector2i in cells:
		_expect(world.grid.is_walkable(cell) and world.building_id_at(cell) == 0,
			"Cancellation must release the entire footprint", failures)


static func _test_legacy_geometry_is_per_building(failures: Array[String]) -> void:
	var world := World.new()
	world.default_footprint_version = 0
	var legacy: int = world.place_building("warehouse", Vector2i(3, 4))
	var original_entrance: Vector2i = world.buildings[legacy]["entrance"]
	world.default_footprint_version = 1
	var current: int = world.place_building("warehouse", Vector2i(9, 6))
	_expect(world.building_cells(world.buildings[legacy]) == [Vector2i(3, 4)]
		and world.building_door_cell(world.buildings[legacy]) == Vector2i(3, 4)
		and world.buildings[legacy]["entrance"] == original_entrance,
		"Changing new-building geometry must not expand or move a historical building", failures)
	_expect(current != 0 and world.building_cells(world.buildings[current]).size() == 9,
		"Current and historical footprints must coexist in one world", failures)


static func _test_extraction_routes_after_placement(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 12))
	for y: int in range(12):
		for x: int in range(12):
			world.grid.set_base_terrain(Vector2i(x, y), "water")
	var anchor := Vector2i(4, 4)
	for cell: Vector2i in world.placement_cells("fisher_hut", anchor):
		world.grid.set_base_terrain(cell, "grass")
	for cell: Vector2i in [Vector2i(4, 5), Vector2i(4, 6)]:
		world.grid.set_base_terrain(cell, "grass")
	world.add_deposit(Vector2i(7, 4), "fish", 20)
	_expect(not world.can_place_building("fisher_hut", anchor),
		"A fish bank accessible only through the future footprint must not authorize a hut", failures)
	for cell: Vector2i in [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]:
		world.grid.set_base_terrain(cell, "grass")
	_expect(world.can_place_building("fisher_hut", anchor),
		"Opening a real route from the southern doorway to the fish bank must enable the hut", failures)


static func _test_training_and_indoor_doorway(failures: Array[String]) -> void:
	var world := World.new()
	var school: int = world.place_building("school", Vector2i(4, 6))
	var building: Dictionary = world.buildings[school]
	var entrance: Vector2i = building["entrance"]
	_expect(world._find_unit_spawn_cell(building) == entrance,
		"Training must prefer the authored exterior doorway", failures)
	world.spawn_worker(entrance)
	var fallback: Vector2i = world._find_unit_spawn_cell(building)
	_expect(fallback != Vector2i(-1, -1) and not world.building_cells(building).has(fallback)
		and world.grid.can_traverse(entrance, fallback),
		"A busy training doorway may use an adjacent reachable exterior tile", failures)
	var indoor: int = world.spawn_worker(entrance, "builder", 0, false, school)
	_expect(indoor != 0 and world.is_worker_inside(world.workers[indoor]),
		"An indoor unit is anchored at the fixed exterior doorway without blocking it", failures)
	if indoor == 0:
		return
	var worker: Dictionary = world.workers[indoor]
	_expect(not world._try_exit_worker_building(worker), "A busy doorway must defer the indoor unit's exit", failures)
	for _tick: int in range(30):
		world.step_tick()
		if world._try_exit_worker_building(worker):
			break
	_expect(world._try_exit_worker_building(worker) and worker["position"] == entrance
		and not world.is_worker_inside(worker) and world.tile_reservations.get(entrance, 0) == indoor,
		"Leaving must claim the real exterior entry and retain a coherent visible position", failures)


static func _test_real_transport_and_production(failures: Array[String]) -> void:
	var world := World.new(Vector2i(20, 14))
	var store: int = world.place_building("warehouse", Vector2i(1, 4))
	var mill: int = world.place_building("sawmill", Vector2i(10, 4))
	world.buildings[store]["storage"]["log"] = 1
	var carpenter: int = world.spawn_worker(Vector2i(11, 6), "carpenter", mill)
	world.spawn_worker(Vector2i(4, 5), "carrier")
	world.spawn_worker(Vector2i(5, 5), "carrier")
	world.economy_enabled = true
	var saw_indoor: bool = false
	var invalid_position: bool = false
	for _tick: int in range(1200):
		world.step_tick()
		if world.workers.has(carpenter):
			saw_indoor = saw_indoor or world.is_worker_inside(world.workers[carpenter])
		for worker: Dictionary in world.workers.values():
			invalid_position = invalid_position or world.building_id_at(worker["position"]) != 0
		if world.stored_amount("plank") == 2:
			break
	_expect(world.stored_amount("plank") == 2 and saw_indoor,
		"Real carriers and a carpenter must deliver a log through the fixed door, work indoors and store both planks", failures)
	_expect(not invalid_position, "Transport and indoor work must never put a worker on an occupied foundation tile", failures)


static func _test_quarry_range_from_occupied_edge(failures: Array[String]) -> void:
	var world := World.new(Vector2i(26, 22))
	for y: int in range(13, 22):
		for x: int in range(20, 26):
			world.grid.set_base_terrain(Vector2i(x, y), "rock")
	var closed_deposit: int = world.add_deposit(Vector2i(20, 16), "stone", 4)
	var accessible_deposit: int = world.add_deposit(Vector2i(20, 17), "stone", 4)
	world.add_deposit(Vector2i(22, 17), "stone", 50)
	var anchor := Vector2i(17, 16)
	_expect(int(world.catalog.building("quarry")["extract_radius"]) == 3
		and world.can_place_building("quarry", anchor),
		"A full quarry must reach nearby stone from its occupied edge without increasing its three-tile radius", failures)
	var quarry: int = world.place_building("quarry", anchor)
	if quarry == 0:
		return
	_expect(world.production_status(world.buildings[quarry]).begins_with("Nearby reserves: 8 "),
		"Deposits more than three tiles from every occupied cell must remain outside the quarry's range", failures)
	var store: int = world.place_building("warehouse", Vector2i(10, 16))
	var mason: int = world.spawn_worker(Vector2i(18, 17), "stonemason", quarry)
	world.spawn_worker(Vector2i(12, 17), "carrier")
	world.economy_enabled = true
	var worked_exterior_face: bool = false
	for _tick: int in range(1000):
		world.step_tick()
		var worker: Dictionary = world.workers[mason]
		worked_exterior_face = worked_exterior_face or (worker["position"] == Vector2i(19, 17) and worker["state"] == "working")
		if int(world.buildings[store]["storage"]["stone"]) > 0:
			break
	_expect(worked_exterior_face and int(world.buildings[store]["storage"]["stone"]) > 0
		and int(world.deposits[accessible_deposit]["amount"]) < 4
		and int(world.deposits[closed_deposit]["amount"]) == 4,
		"The real mason must work the second deposit from (19,17), return through the southern door and supply the warehouse", failures)
	_expect(world.production_status(world.buildings[quarry]).begins_with("Nearby reserves:"),
		"The resource status must use the same occupied-edge range as placement and gathering", failures)
	var legacy := World.new(Vector2i(26, 22))
	legacy.default_footprint_version = 0
	legacy.grid.set_base_terrain(Vector2i(20, 17), "rock")
	legacy.add_deposit(Vector2i(20, 17), "stone", 4)
	_expect(not legacy.can_place_building("quarry", anchor),
		"A historical one-cell quarry must retain its original anchor-based three-tile radius", failures)


static func _test_placement_during_visible_steps(failures: Array[String]) -> void:
	for origin: Vector2i in [Vector2i(7, 4), Vector2i(7, 3)]:
		var world := World.new()
		var id: int = world.spawn_worker(origin, "carrier")
		var worker: Dictionary = world.workers[id]
		world._commit_worker_step(worker, Vector2i(8, 4))
		_expect(not world.tile_reservations.has(origin) and int(worker["visual_progress_ticks"]) == 0,
			"The regression must reach a real in-flight step after releasing its logical origin", failures)
		_expect(not world.can_place_building("lumber_hut", Vector2i(4, 6)),
			"A future wall must not cover a walking person's visible origin or diagonal crossing flank", failures)
		for _tick: int in range(int(worker["visual_duration_ticks"])):
			world.step_tick()
		_expect(world.can_place_building("lumber_hut", Vector2i(4, 6)),
			"The released foundation must become buildable as soon as the person visibly finishes the step", failures)
