extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const TEST_COUNT: int = 13
const SITE := Vector2i(10, 8)

static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_plan_and_placement_are_height_read_only,
		_test_no_builder_means_no_earthwork_or_deliveries,
		_test_real_builder_levels_then_carriers_then_builds,
		_test_earthwork_does_not_require_materials,
		_test_cancel_before_work,
		_test_cancel_during_work,
		_test_protected_neighbors,
		_test_steep_and_blocked_ground,
		_test_flat_and_legacy_sites,
		_test_night_pauses_and_morning_resumes,
		_test_two_builders_keep_one_reservation,
		_test_dynamic_obstruction_waits_and_resumes,
		_test_future_surface_reservation,
	]:
		test.call(failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _fixture(stock: bool = true) -> Dictionary:
	var world := World.new(Vector2i(24, 18))
	# Keep the measured historical foundation below: changing the hut's
	# geometry would also change its independent cut/fill expectation.
	world.default_footprint_version = 1
	var store: int = world.place_building("warehouse", Vector2i(2, 5))
	if stock:
		world.buildings[store]["storage"]["plank"] = 20
		world.buildings[store]["storage"]["stone"] = 20
	# The revision-1 hut has 6 cells / 12 shared vertices. The independent
	# repeating 0,1,2 terrain has average1 and eight units of cut/fill.
	for y: int in range(7, 10):
		for x: int in range(10, 14):
			world.grid.set_vertex_height(Vector2i(x, y), (x + y) % 3)
	world.economy_enabled = true
	return {"world": world, "store": store}


static func _site(world: Variant, failures: Array[String]) -> int:
	var id: int = world.place_building("lumber_hut", SITE)
	_check(id != 0, "Gentle full-mask fixture must create a real construction site", failures)
	return id


static func _advance(world: Variant, ticks: int) -> void:
	for _tick: int in range(ticks):
		world.step_tick()


static func _until(world: Variant, condition: Callable, ticks: int = 1800) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _heights(world: Variant) -> PackedInt32Array:
	return world.grid._vertex_heights.duplicate()


static func _state(world: Variant) -> Dictionary:
	return {
		"save": world.to_data().duplicate(true),
		"events": world.event_log.duplicate(),
		"workers": world.workers.duplicate(true),
		"tasks": world.task_board.to_data().duplicate(true),
		"tiles": world.tile_reservations.duplicate(true),
		"plants": world.planting_reservations.duplicate(true),
		"revision": world.grid.revision,
	}


static func _remaining(world: Variant, site: int) -> int:
	return int(world.buildings[site].get("foundation_work_remaining", -1))


static func _geometry_error(world: Variant, building: Dictionary, target: int) -> int:
	var vertices: Dictionary = {}
	for cell: Vector2i in world.building_cells(building):
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			vertices[cell + offset] = true
	var error: int = 0
	for vertex: Vector2i in vertices:
		error += absi(world.grid.vertex_height(vertex) - target)
	return error


static func _spawn_builder(world: Variant, at: Vector2i = Vector2i(12, 11)) -> int:
	return world.spawn_worker(at, "builder")


static func _test_plan_and_placement_are_height_read_only(failures: Array[String]) -> void:
	var world: Variant = _fixture()["world"]
	var before: Dictionary = _state(world)
	var plan: Dictionary = world.foundation_plan("lumber_hut", SITE)
	_check(bool(plan.get("valid", false)) and int(plan.get("target_height", -1)) == 1
		and int(plan.get("work_ticks", 0)) == 64,
		"A real six-cell hut must require independent expected eight cut/fill units at eight work ticks each", failures)
	for _repeat: int in range(4):
		world.foundation_plan("lumber_hut", SITE)
		world.can_place_building("lumber_hut", SITE)
	_check(_state(world) == before, "Repeated foundation planning must not edit height, resources, events, reservations or tasks", failures)
	var heights: PackedInt32Array = _heights(world)
	var site: int = _site(world, failures)
	if site == 0:
		return
	_check(_heights(world) == heights and _remaining(world, site) == 64,
		"Clicking placement must reserve the site without instantly levelling even one vertex", failures)
	_check(world.building_cells(world.buildings[site]).size() == 6, "Earthwork must preserve the revision-1 site's full six-cell foundation", failures)
	for cell: Vector2i in world.building_cells(world.buildings[site]):
		_check(world.building_id_at(cell) == site and not world.grid.is_walkable(cell),
			"Every occupied mask tile remains reserved throughout earthwork", failures)


static func _test_no_builder_means_no_earthwork_or_deliveries(failures: Array[String]) -> void:
	var world: Variant = _fixture()["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	world.spawn_worker(Vector2i(5, 10), "carrier")
	var heights: PackedInt32Array = _heights(world)
	var construction: int = int(world.buildings[site]["construction_remaining"])
	_advance(world, 120)
	_check(_heights(world) == heights and _remaining(world, site) == 64
		and int(world.buildings[site]["construction_remaining"]) == construction,
		"A supplied settlement without a Builder must not prepare or construct the site automatically", failures)
	_check((world.buildings[site]["construction_delivered"] as Dictionary).is_empty()
		and world.stored_amount("plank") == 20 and world.stored_amount("stone") == 20,
		"Carriers must not remove construction stock before the ground has been prepared", failures)


static func _test_real_builder_levels_then_carriers_then_builds(failures: Array[String]) -> void:
	var world: Variant = _fixture()["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	var builder: int = _spawn_builder(world)
	world.spawn_worker(Vector2i(5, 10), "carrier")
	world.spawn_worker(Vector2i(7, 11), "carrier")
	var building: Dictionary = world.buildings[site]
	var construction: int = int(building["construction_remaining"])
	var previous: int = _remaining(world, site)
	var observed_work: bool = false
	var observed_geometry: bool = false
	var previous_heights: PackedInt32Array = _heights(world)
	for _tick: int in range(800):
		if _remaining(world, site) == 0:
			break
		var before_worker: Dictionary = world.workers[builder].duplicate(true)
		world.step_tick()
		var remaining: int = _remaining(world, site)
		if remaining < previous:
			observed_work = true
			_check(previous - remaining == 1 and world.workers.has(builder)
				and before_worker["action"] == "build_site" and before_worker["state"] == "working"
				and world.can_worker_work(world.workers[builder]),
				"Earthwork advances only from a physically working Builder, at most one work tick per world tick", failures)
		var heights: PackedInt32Array = _heights(world)
		var displacement: int = 0
		for index: int in range(heights.size()):
			displacement += absi(heights[index] - previous_heights[index])
		if displacement > 0:
			observed_geometry = true
			_check(displacement == 1, "Real earthwork must deform at most one height unit per step, never teleport the whole foundation", failures)
		_check(int(building["construction_remaining"]) == construction
			and (building["construction_delivered"] as Dictionary).is_empty(),
			"Foundation work must finish before any construction ticks or delivered building materials", failures)
		_check(_geometry_error(world, building, 1) == ceili(float(remaining) / 8.0),
			"Persisted remaining work must exactly match the unfinished real height changes", failures)
		previous = remaining
		previous_heights = heights
	_check(observed_work and observed_geometry and _remaining(world, site) == 0,
		"The actual Builder must finish observable, progressive preparation", failures)
	if _remaining(world, site) != 0:
		return
	_check(_geometry_error(world, building, 1) == 0, "Every unique vertex under the full mask must finish at the agreed level", failures)
	_check(_until(world, func() -> bool: return world.is_building_complete(building), 2200),
		"After levelling, physical carriers and the Builder must finish the normal construction pipeline", failures)
	var cost: Dictionary = world.construction_cost(building)
	_check(world.stored_amount("plank") == 20 - int(cost.get("plank", 0))
		and world.stored_amount("stone") == 20 - int(cost.get("stone", 0)),
		"Earthwork must neither add an unrequested resource charge nor double-pay the existing construction bill", failures)


static func _test_earthwork_does_not_require_materials(failures: Array[String]) -> void:
	var world: Variant = _fixture(false)["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	_spawn_builder(world)
	var construction: int = int(world.buildings[site]["construction_remaining"])
	_check(_until(world, func() -> bool: return _remaining(world, site) == 0, 800),
		"A Builder must prepare the soil even when the Warehouse has no planks or stone", failures)
	_advance(world, 60)
	_check(int(world.buildings[site]["construction_remaining"]) == construction
		and not world.is_building_complete(world.buildings[site]),
		"Prepared but unsupplied foundations must wait; earthwork must not build for free", failures)


static func _test_cancel_before_work(failures: Array[String]) -> void:
	var world: Variant = _fixture()["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	var heights: PackedInt32Array = _heights(world)
	_check(world.cancel_construction(site), "An unprepared site with no delivered materials must cancel", failures)
	_spawn_builder(world)
	_advance(world, 60)
	_check(_heights(world) == heights and not world.buildings.has(site),
		"Cancellation before the Builder arrives must not perform delayed or automatic earthwork", failures)


static func _test_cancel_during_work(failures: Array[String]) -> void:
	var world: Variant = _fixture()["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	var builder: int = _spawn_builder(world)
	var reached: bool = _until(world, func() -> bool: return _remaining(world, site) <= 48, 800)
	_check(reached and _remaining(world, site) > 0, "Cancellation fixture must really change soil before finishing", failures)
	if not reached:
		return
	var heights: PackedInt32Array = _heights(world)
	_check(world.cancel_construction(site), "Active earthwork must remain cancellable", failures)
	_check(int(world.workers[builder]["task_id"]) == 0 and int(world.workers[builder]["source_id"]) != site,
		"Cancelling earthwork must immediately release the Builder and obsolete site task", failures)
	_advance(world, 80)
	_check(_heights(world) == heights, "Cancellation must keep performed terrain work and never undo or finish cancelled work", failures)
	for cell: Vector2i in world.placement_cells("lumber_hut", SITE):
		_check(world.building_id_at(cell) == 0 and world.grid.is_walkable(cell), "Cancellation must release every partially prepared tile", failures)
	_check(world.stored_amount("plank") == 20 and world.stored_amount("stone") == 20, "Cancelling earthwork must not create or consume construction stock", failures)


static func _test_protected_neighbors(failures: Array[String]) -> void:
	for kind: String in ["building", "field", "tree"]:
		var world := World.new(Vector2i(24, 18))
		world.default_footprint_version = 1
		# Six height2 vertices and six height0 vertices imply target1; the
		# eastern edge currently stays0, so existing content there is level.
		for y: int in range(7, 10):
			for x: int in range(10, 12):
				world.grid.set_vertex_height(Vector2i(x, y), 2)
		var neighbor := Vector2i(13, 8)
		var created: int = 0
		match kind:
			"building": created = world.place_building("warehouse", neighbor)
			"field": created = world.place_field(neighbor)
			"tree": created = world.add_tree(neighbor, 5)
		_check(created != 0, "Protected " + kind + " fixture must really create the neighboring content", failures)
		world.economy_enabled = true
		var before: Dictionary = _state(world)
		_check(not world.can_place_building("lumber_hut", SITE)
			and world.place_building("lumber_hut", SITE) == 0,
			"Earthwork must reject a footprint whose changed shared vertices undermine neighboring " + kind, failures)
		_check(_state(world) == before, "Unsafe neighboring-content rejection must be atomic and read-only", failures)


static func _test_steep_and_blocked_ground(failures: Array[String]) -> void:
	for kind: String in ["steep", "rock", "water"]:
		var world: Variant = _fixture()["world"]
		match kind:
			"steep": world.grid.set_vertex_height(Vector2i(11, 8), 6)
			"rock": world.grid.set_base_terrain(Vector2i(11, 8), "rock")
			"water": world.grid.set_base_terrain(Vector2i(11, 8), "water")
		var before: Dictionary = _state(world)
		_check(not world.can_place_building("lumber_hut", SITE) and world.place_building("lumber_hut", SITE) == 0,
			"Foundation preparation must not authorize " + kind + " terrain", failures)
		_check(_state(world) == before, "Rejected terrain must not erase hills or allocate a construction site", failures)


static func _test_flat_and_legacy_sites(failures: Array[String]) -> void:
	var world := World.new(Vector2i(24, 18))
	world.economy_enabled = true
	var site: int = world.place_building("lumber_hut", SITE)
	_check(site != 0 and _remaining(world, site) == 0, "Already-flat modern foundations must skip earthwork", failures)
	var legacy := World.new(Vector2i(24, 18))
	legacy.default_footprint_version = 0
	legacy.economy_enabled = true
	legacy.grid.set_vertex_height(SITE, 1)
	_check(not legacy.can_place_building("lumber_hut", SITE), "Historical one-cell authoring must preserve its established flat-only rule", failures)
	var authored: Variant = _fixture()["world"]
	authored.economy_enabled = false
	_check(not authored.can_place_building("lumber_hut", SITE), "Instant editor/demo placement cannot level ground without a Builder", failures)


static func _test_night_pauses_and_morning_resumes(failures: Array[String]) -> void:
	var world: Variant = _fixture(false)["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	_spawn_builder(world)
	var begun: bool = _until(world, func() -> bool: return _remaining(world, site) < 64, 800)
	_check(begun, "Night fixture must first observe actual earthwork", failures)
	if not begun:
		return
	var remaining: int = _remaining(world, site)
	var heights: PackedInt32Array = _heights(world)
	world.tick = 3749
	_advance(world, 80)
	_check(_remaining(world, site) == remaining and _heights(world) == heights,
		"20:00 night rest must stop the Builder's soil changes without resetting progress", failures)
	world.tick = 5999
	_check(_until(world, func() -> bool: return _remaining(world, site) == 0, 900),
		"At 05:00 the Builder must travel back and resume the unfinished earthwork", failures)


static func _test_two_builders_keep_one_reservation(failures: Array[String]) -> void:
	var world: Variant = _fixture(false)["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	_spawn_builder(world)
	_spawn_builder(world, Vector2i(10, 11))
	var previous: int = 64
	var saw_owner: bool = false
	for _tick: int in range(900):
		if _remaining(world, site) == 0:
			break
		world.step_tick()
		var remaining: int = _remaining(world, site)
		var owners: int = world.task_board.reservation_count_for_source("construction:%d" % site)
		saw_owner = saw_owner or owners == 1
		_check(owners <= 1 and previous - remaining <= 1,
			"Two Builders must not reserve the same earthwork task or accelerate it twice in one tick", failures)
		previous = remaining
	_check(saw_owner and _remaining(world, site) == 0, "Exclusive Builder work must actually finish the shared site", failures)


static func _test_dynamic_obstruction_waits_and_resumes(failures: Array[String]) -> void:
	var world: Variant = _fixture(false)["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	_spawn_builder(world)
	var observer: int = world.spawn_worker(Vector2i(13, 8), "carrier")
	_check(observer != 0, "The dynamic safety fixture must put a real citizen beside shared boundary vertices", failures)
	if observer == 0:
		return
	_advance(world, 300)
	var remaining: int = _remaining(world, site)
	var heights: PackedInt32Array = _heights(world)
	_advance(world, 40)
	_check(remaining > 0 and _remaining(world, site) == remaining and _heights(world) == heights,
		"Earthwork must wait without consuming work while another citizen occupies ground that would move", failures)
	var worker: Dictionary = world.workers[observer]
	var destination := Vector2i(17, 12)
	var path: Array[Vector2i] = Pathfinder.find_path(world.grid, worker["position"], destination)
	_check(not path.is_empty(), "Safety fixture must provide a real walkable escape route for its citizen", failures)
	if path.is_empty():
		return
	world._begin_worker_move(worker, path, destination)
	_check(_until(world, func() -> bool: return _remaining(world, site) == 0, 900),
		"After the citizen walks clear, the Builder must resume and finish the exact remaining soil work", failures)


static func _test_future_surface_reservation(failures: Array[String]) -> void:
	var world: Variant = _fixture()["world"]
	var site: int = _site(world, failures)
	if site == 0:
		return
	var halo := Vector2i(13, 8)
	var before: Dictionary = _state(world)
	_check(world.foundation_affects_cell(halo) and world.grid.is_walkable(halo),
		"Future shared-edge earthwork reserves static placement, never neighboring pedestrian movement", failures)
	_check(world.add_tree(halo) == 0 and world.add_deposit(halo, "coal", 5) == 0
		and not world.can_place_field(halo) and not world.set_base_terrain(halo, "water")
		and not world.set_vertex_height(Vector2i(14, 8), 2)
		and not world.can_place_building("lumber_hut", halo),
		"New static objects and authoring edits cannot invalidate already agreed future earthwork", failures)
	_check(_state(world) == before, "Rejected future-surface changes must remain entirely atomic", failures)
	_check(world.cancel_construction(site) and not world.foundation_affects_cell(halo)
		and world.add_tree(halo) != 0,
		"Cancelling preparation releases its future surface reservation as well as its actual footprint", failures)
