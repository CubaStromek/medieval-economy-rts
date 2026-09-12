extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Footprints = preload("res://scripts/simulation/building_footprints.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const Relief = preload("res://scripts/simulation/relief_demo.gd")
const TEST_COUNT: int = 12


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_revision_and_preserved_door,
		_test_recessed_door_validation,
		_test_added_ground_blocks_placement,
		_test_notch_access_and_protection,
		_test_map_edge_approach,
		_test_foundation_and_cancellation,
		_test_real_construction_at_notch,
		_test_real_wood_handoffs_at_notch,
		_test_mixed_geometry_round_trip,
		_test_v20_crowded_hut_preserved,
		_test_malformed_saves_are_atomic,
		_test_authored_demo_connections,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_revision_and_preserved_door(failures: Array[String]) -> void:
	var world := World.new()
	var hut: Dictionary = world.catalog.building("lumber_hut")
	var old_anchor := Vector2i(6, 6)
	var new_anchor := Vector2i(5, 7)
	_check(hut["footprint_mask"] == [".###", ".##E", "###."]
		and world.placement_cells("lumber_hut", new_anchor).size() == 9,
		"The painted hut must own nine ground cells in its 4 by 3 notched foundation", failures)
	_check(Footprints.door_cell(hut, old_anchor, 1) == Vector2i(8, 6)
		and Footprints.door_cell(hut, new_anchor, 2) == Vector2i(8, 6)
		and world.placement_entrance("lumber_hut", new_anchor) == Vector2i(8, 7),
		"Moving the authoring anchor left one and down one must preserve the physical threshold and outdoor approach", failures)
	world.default_footprint_version = 1
	_check(world.placement_cells("lumber_hut", old_anchor).size() == 6
		and world.placement_entrance("lumber_hut", old_anchor) == Vector2i(8, 7),
		"Explicit revision 1 authoring must retain the historical six-cell hut and its entrance", failures)
	world.default_footprint_version = 2
	for type: String in world.catalog.buildings:
		_check(world.placement_footprint_version(type) == (2 if type == "lumber_hut" else 1),
			"Only the lumber hut may adopt the new geometry revision: " + type, failures)
	_check(world.catalog.building("forester_hut")["footprint_mask"] == ["###", "##E"],
		"Expanding this own painted hut must leave the later forester sibling's ground contract unchanged", failures)


static func _test_recessed_door_validation(failures: Array[String]) -> void:
	for entry: Array in [
		[[".###", ".##E", "###."], true],
		[["####", "###E", "####"], false],
		[["###E", "###.", "###."], true],
		[["###E", "###.", "####"], false],
		[["####", "##EE", "##.."], false],
		[["####", "###E", "...."], false],
	]:
		var definition: Dictionary = {"footprint": [4, 3], "footprint_mask": entry[0]}
		_check(Footprints.valid_definition(definition) == bool(entry[1]),
			"A recessed threshold needs a clear straight southern opening and a tightly trimmed occupied mask: %s" % str(entry[0]), failures)


static func _test_added_ground_blocks_placement(failures: Array[String]) -> void:
	# Independent contacts added around the former six cells with the same door.
	for extra: Vector2i in [Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7)]:
		var world := World.new()
		world.add_tree(extra, 3)
		world.default_footprint_version = 1
		_check(world.can_place_building("lumber_hut", Vector2i(6, 6)),
			"A tree on newly claimed contact ground must be outside the historical hut: %s" % extra, failures)
		world.default_footprint_version = 2
		var before: Dictionary = world.to_data()
		_check(not world.can_place_building("lumber_hut", Vector2i(5, 7))
			and world.place_building("lumber_hut", Vector2i(5, 7)) == 0
			and world.to_data() == before,
			"The expanded hut must atomically reject each occupied new ground contact: %s" % extra, failures)


static func _test_notch_access_and_protection(failures: Array[String]) -> void:
	var world := World.new()
	var entrance := Vector2i(8, 7)
	world.place_road(entrance)
	var id: int = world.place_building("lumber_hut", Vector2i(5, 7))
	_check(id != 0, "A current hut must place around its existing entrance road", failures)
	if id == 0:
		return
	var building: Dictionary = world.buildings[id]
	for cell: Vector2i in world.building_cells(building):
		_check(world.building_id_at(cell) == id and not world.grid.is_walkable(cell)
			and not world.can_place_field(cell) and world.spawn_worker(cell, "carrier", 0, false) == 0,
			"Every new hut ground cell must select the hut and block walking, farming and spawning", failures)
	_check(world.grid.is_walkable(entrance) and world.grid.roads.has(entrance)
		and world.building_id_at(entrance) == 0 and world.add_tree(entrance) == 0
		and not world.can_place_field(entrance),
		"The footprint notch must stay a road-capable, protected, unoccupied entrance", failures)
	for recess: Vector2i in [Vector2i(5, 5), Vector2i(5, 6)]:
		_check(world.grid.is_walkable(recess) and world.building_id_at(recess) == 0 and world.can_place_field(recess),
			"Empty western mask corners must remain usable ground rather than a filled bounding rectangle", failures)
	var route: Array[Vector2i] = Pathfinder.find_path(world.grid, Vector2i(3, 7), entrance)
	_check(not route.is_empty() and route.back() == entrance,
		"A worker approaching from the shed side must find the real recessed doorway", failures)
	for cell: Vector2i in route:
		_check(world.building_id_at(cell) == 0, "The approach route must never cross the shed or stock rack", failures)
	_check(not world.grid.can_traverse(entrance, Vector2i(7, 8)),
		"The front rack corner must prevent a diagonal squeeze from the doorway through occupied ground", failures)


static func _test_map_edge_approach(failures: Array[String]) -> void:
	var world := World.new(Vector2i(12, 12))
	_check(world.can_place_building("lumber_hut", Vector2i(0, 2)),
		"The complete 4 by 3 hut may touch the north-west map edge", failures)
	_check(not world.can_place_building("lumber_hut", Vector2i(0, 1))
		and not world.can_place_building("lumber_hut", Vector2i(9, 5)),
		"The wider/deeper foundation must reject any occupied cell beyond map bounds", failures)
	_check(world.can_place_building("lumber_hut", Vector2i(7, 11))
		and not world.can_place_building("lumber_hut", Vector2i(8, 11)),
		"A southern-edge recessed doorway is legal only when its external approach remains reachable", failures)


static func _test_foundation_and_cancellation(failures: Array[String]) -> void:
	var world := World.new(Vector2i(20, 16))
	world.economy_enabled = true
	# This front-left vertex was outside the historic foundation at the same door.
	world.grid.set_vertex_height(Vector2i(5, 8), 1)
	var plan: Dictionary = world.foundation_plan("lumber_hut", Vector2i(5, 7))
	_check(bool(plan["valid"]) and int(plan["work_ticks"]) == 8
		and (plan["vertices"] as Array).has(Vector2i(5, 8)),
		"Earthwork must include the added front shed contact instead of leaving that footing on its former slope", failures)
	var id: int = world.place_building("lumber_hut", Vector2i(5, 7))
	_check(id != 0 and int(world.buildings[id]["foundation_work_remaining"]) == 8,
		"Expanded hut placement must reserve all added contact ground for real builder leveling", failures)
	if id == 0:
		return
	var cells: Array[Vector2i] = world.building_cells(world.buildings[id])
	_check(world.cancel_construction(id), "An unpaid expanded site must remain cancellable", failures)
	for cell: Vector2i in cells:
		_check(world.grid.is_walkable(cell) and world.building_id_at(cell) == 0,
			"Cancellation must release all nine occupied cells", failures)
	_check(world.grid.vertex_height(Vector2i(5, 8)) == 1,
		"Cancelling before any work must preserve the untouched terrain", failures)


static func _test_real_construction_at_notch(failures: Array[String]) -> void:
	var world := World.new(Vector2i(22, 16))
	var warehouse: int = world.place_building("warehouse", Vector2i(1, 4))
	world.buildings[warehouse]["storage"]["plank"] = 3
	world.buildings[warehouse]["storage"]["stone"] = 2
	world.economy_enabled = true
	var id: int = world.place_building("lumber_hut", Vector2i(9, 7))
	_check(id != 0, "The real construction fixture must place its expanded hut", failures)
	if id == 0:
		return
	var building: Dictionary = world.buildings[id]
	world.spawn_worker(Vector2i(4, 5), "carrier")
	world.spawn_worker(Vector2i(5, 5), "carrier")
	var builder: int = world.spawn_worker(Vector2i(6, 5), "builder")
	var saw_builder: bool = false
	var crossed_foundation: bool = false
	for _tick: int in range(2400):
		world.step_tick()
		var worker: Dictionary = world.workers[builder]
		saw_builder = saw_builder or (worker["action"] == "build_site" and worker["state"] == "working"
			and worker["target_cell"] == Vector2i(12, 7)
			and (worker["position"] == Vector2i(12, 7) or world.grid.can_traverse(worker["position"], Vector2i(12, 7))))
		for citizen: Dictionary in world.workers.values():
			crossed_foundation = crossed_foundation or world.building_id_at(citizen["position"]) != 0
		if world.is_building_complete(building):
			break
	_check(saw_builder and world.is_building_complete(building)
		and building["construction_delivered"] == {"plank": 3, "stone": 2}
		and world.stored_amount("plank") == 0 and world.stored_amount("stone") == 0,
		"Real carriers must deliver the unchanged price and a real builder must finish from the recessed entrance or its reachable neighbor (builder=%s, remaining=%s, delivered=%s)"
		% [saw_builder, building["construction_remaining"], building["construction_delivered"]], failures)
	_check(not crossed_foundation, "Construction traffic must stay outside every occupied hut cell", failures)


static func _test_real_wood_handoffs_at_notch(failures: Array[String]) -> void:
	var world := World.new(Vector2i(22, 16))
	var warehouse: int = world.place_building("warehouse", Vector2i(1, 4))
	var id: int = world.place_building("lumber_hut", Vector2i(9, 7))
	_check(id != 0, "The stock journey must start at a real completed expanded hut", failures)
	if id == 0:
		return
	world.add_tree(Vector2i(15, 10), 1)
	var lumberjack: int = world.spawn_worker(Vector2i(14, 10), "lumberjack", id)
	var carrier: int = world.spawn_worker(Vector2i(4, 5), "carrier")
	var delivered_at_notch: bool = false
	var picked_up_at_notch: bool = false
	var crossed_foundation: bool = false
	var previous_output: int = 0
	for _tick: int in range(1800):
		world.step_tick()
		var output: int = int(world.buildings[id]["outputs"]["log"])
		if output > previous_output:
			delivered_at_notch = world.workers[lumberjack]["position"] == Vector2i(12, 7)
		if output < previous_output:
			picked_up_at_notch = world.workers[carrier]["position"] == Vector2i(12, 7)
		previous_output = output
		for citizen: Dictionary in world.workers.values():
			crossed_foundation = crossed_foundation or world.building_id_at(citizen["position"]) != 0
		if int(world.buildings[warehouse]["storage"]["log"]) == 1:
			break
	_check(delivered_at_notch and picked_up_at_notch and int(world.buildings[warehouse]["storage"]["log"]) == 1,
		"One real harvested log must enter the hut, leave with a carrier and reach storage through the same recessed doorway", failures)
	_check(not crossed_foundation, "Harvesting and stock pickup must never cross the enlarged shed or rack", failures)


static func _crowded_old_hut() -> Dictionary:
	var world := World.new(Vector2i(26, 18))
	world.default_footprint_version = 0
	var legacy: int = world.place_building("warehouse", Vector2i(5, 7))
	world.default_footprint_version = 1
	var hut: int = world.place_building("lumber_hut", Vector2i(6, 6))
	world.place_road(Vector2i(5, 5))
	world.add_tree(Vector2i(5, 6), 3)
	world.place_field(Vector2i(6, 7))
	world.spawn_worker(Vector2i(7, 7), "carrier", 0, false)
	world.buildings[hut]["outputs"]["log"] = 4
	world.default_footprint_version = 2
	return {"world": world, "hut": hut, "legacy": legacy}


static func _test_mixed_geometry_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _crowded_old_hut()
	var source: World = fixture["world"]
	var modern: int = source.place_building("lumber_hut", Vector2i(15, 11))
	_check(modern != 0 and source.grid.blocked_by.size() == 16,
		"The save fixture must contain real one-, six- and nine-cell buildings", failures)
	if modern == 0:
		return
	var data: Dictionary = _json(source)
	for reverse: bool in [false, true]:
		var reordered: Dictionary = data.duplicate(true)
		if reverse:
			reordered["buildings"].reverse()
		var restored := World.new()
		restored.default_footprint_version = 0
		var loaded: bool = restored.from_data(reordered)
		_check(loaded, "A mixed 0/1/2 footprint save must load independently of object order and authoring defaults", failures)
		if loaded:
			_check(restored.to_data() == source.to_data() and restored.grid.blocked_by == source.grid.blocked_by,
				"Mixed geometry must retain exact blockers, stock, objects, workers and independent historical entrances", failures)
			_check(restored.building_cells(restored.buildings[fixture["hut"]]).size() == 6
				and restored.building_cells(restored.buildings[modern]).size() == 9,
				"Loading must never reinterpret an old six-cell hut as the expanded nine-cell hut", failures)


static func _test_v20_crowded_hut_preserved(failures: Array[String]) -> void:
	var fixture: Dictionary = _crowded_old_hut()
	var source: World = fixture["world"]
	var data: Dictionary = _json(source)
	data["version"] = 20
	var restored := World.new()
	var loaded: bool = restored.from_data(data)
	_check(loaded, "A v20 hut with occupied neighbors must load without stealing a road, tree, field, citizen or building", failures)
	if not loaded:
		return
	_check(restored.to_data() == source.to_data() and restored.grid.blocked_by.size() == 7
		and restored.buildings[fixture["hut"]]["position"] == Vector2i(6, 6)
		and restored.buildings[fixture["hut"]]["entrance"] == Vector2i(8, 7),
		"Old save migration must preserve every adjacent entity and the original hut's position, entrance and stock", failures)
	var modern: int = restored.place_building("lumber_hut", Vector2i(15, 11))
	_check(modern != 0 and int(restored.buildings[modern]["footprint_version"]) == 2
		and restored.building_cells(restored.buildings[modern]).size() == 9,
		"Fresh player construction after an old save loads must use the revised hut geometry", failures)


static func _test_malformed_saves_are_atomic(failures: Array[String]) -> void:
	var source := World.new(Vector2i(22, 16))
	var hut: int = source.place_building("lumber_hut", Vector2i(9, 7))
	var warehouse: int = source.place_building("warehouse", Vector2i(1, 4))
	var baseline: Dictionary = _json(source)
	for value: Variant in [null, "2", true, -1, 3, 0.5, INF, NAN, [], {}]:
		var invalid: Dictionary = baseline.duplicate(true)
		_saved_building(invalid, hut)["footprint_version"] = value
		_reject_atomically(invalid, "invalid hut geometry version %s" % str(value), failures)
	var unsupported: Dictionary = baseline.duplicate(true)
	_saved_building(unsupported, warehouse)["footprint_version"] = 2
	_reject_atomically(unsupported, "revision 2 assigned to an unchanged building type", failures)
	var old_schema: Dictionary = baseline.duplicate(true)
	old_schema["version"] = 20
	_reject_atomically(old_schema, "new geometry smuggled into a pre-revision save schema", failures)
	var shifted_door: Dictionary = baseline.duplicate(true)
	_saved_building(shifted_door, hut)["entrance"] = [12, 8]
	_reject_atomically(shifted_door, "obsolete bottom-row doorway on a recessed-door hut", failures)
	var occupied: Dictionary = baseline.duplicate(true)
	occupied["roads"].append([9, 7])
	_reject_atomically(occupied, "road embedded in a newly occupied front shed cell", failures)
	var missing: Dictionary = baseline.duplicate(true)
	_saved_building(missing, hut).erase("footprint_version")
	_reject_atomically(missing, "missing geometry revision in a current save", failures)


static func _test_authored_demo_connections(failures: Array[String]) -> void:
	for relief: bool in [false, true]:
		var world := World.new(Relief.MAP_SIZE if relief else Vector2i(20, 16))
		if relief:
			Relief.setup(world)
		else:
			world.setup_economy_demo()
		var hut_id: int = world._first_building("lumber_hut")
		var warehouse_id: int = world._first_building("warehouse")
		_check(hut_id != 0 and warehouse_id != 0, "Both menu settlements must instantiate their actual lumber hut and warehouse", failures)
		if hut_id == 0 or warehouse_id == 0:
			continue
		var hut: Dictionary = world.buildings[hut_id]
		_check(int(hut["footprint_version"]) == 2 and world.building_cells(hut).size() == 9,
			"Both newly authored menu settlements must expose the revised nine-cell hut", failures)
		_check(hut["entrance"] == (Vector2i(13, 15) if relief else Vector2i(8, 9)),
			"Reauthoring the scenario anchor must preserve its original physical entrance and artwork location", failures)
		var off_road: Dictionary = {}
		for y: int in range(world.grid.size.y):
			for x: int in range(world.grid.size.x):
				var cell := Vector2i(x, y)
				if not world.grid.roads.has(cell):
					off_road[cell] = true
		for building: Dictionary in world.buildings.values():
			var start: Vector2i = world.buildings[warehouse_id]["entrance"]
			var end: Vector2i = building["entrance"]
			_check(start == end or not Pathfinder.find_path(world.grid, start, end).is_empty(),
				"The expanded hut must preserve every authored settlement doorway connection: " + String(building["type"]), failures)
			_check(world.grid.roads.has(start) and world.grid.roads.has(end)
				and (start == end or not Pathfinder.find_path(world.grid, start, end, off_road).is_empty()),
				"The adjusted authored road network must reach every entrance entirely over roads: " + String(building["type"]), failures)
		var restored := World.new()
		_check(restored.from_data(_json(world)), "New menu settlements must remain valid complete save snapshots", failures)


static func _reject_atomically(data: Dictionary, label: String, failures: Array[String]) -> void:
	var live: World = _crowded_old_hut()["world"]
	var before: Dictionary = live.to_data()
	var grid: Variant = live.grid
	var blockers: Dictionary = live.grid.blocked_by.duplicate(true)
	_check(not live.from_data(data), "The snapshot validator must reject " + label, failures)
	_check(live.to_data() == before and live.grid == grid and live.grid.blocked_by == blockers,
		"Rejecting " + label + " must leave the existing game and movement map untouched", failures)


static func _saved_building(data: Dictionary, id: int) -> Dictionary:
	for building: Dictionary in data["buildings"]:
		if int(building["id"]) == id:
			return building
	return {}


static func _json(world: World) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary
