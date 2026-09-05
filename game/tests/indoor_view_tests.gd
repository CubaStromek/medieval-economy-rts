extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TerrainRenderer = preload("res://scripts/view/terrain_renderer.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const SpriteLibrary = preload("res://scripts/view/unit_sprite_library.gd")
const TEST_COUNT: int = 6


class PresentationSpy:
	extends SpriteLibrary

	var presented_ids: Array[int] = []

	func presentation_for(worker: Dictionary, feet: Vector2, tick: int, frame_alpha: float) -> Dictionary:
		presented_ids.append(int(worker["id"]))
		return super.presentation_for(worker, feet, tick, frame_alpha)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_only_actual_occupants_hidden(failures)
	_test_enter_exit_draw_entries(failures)
	_test_indoor_details_keep_citizens(failures)
	_test_selection_and_read_only_queries(failures)
	await _test_actual_draw_and_return(host, failures)
	return failures


static func _fixture() -> Dictionary:
	var world := World.new(Vector2i(12, 8))
	var building_id: int = world.place_building("sawmill", Vector2i(4, 3))
	var entrance: Vector2i = world.buildings[building_id]["entrance"]
	var worker_id: int = world.spawn_worker(entrance, "carpenter", building_id)
	return {"world": world, "building_id": building_id, "entrance": entrance,
		"worker_id": worker_id, "worker": world.workers[worker_id]}


static func _view_for(world: World) -> MainView:
	var main := MainView.new()
	main.world = world
	main.terrain_renderer = TerrainRenderer.new()
	main.add_child(main.terrain_renderer)
	main.terrain_renderer.bind_grid(world.grid)
	return main


static func _drawn_worker_ids(main: MainView) -> Array[int]:
	var ids: Array[int] = []
	for entry: Dictionary in main._world_draw_entries():
		if String(entry["kind"]) == "worker":
			ids.append(int(entry["state"]["id"]))
	return ids


static func _test_only_actual_occupants_hidden(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var main: MainView = _view_for(world)
	_expect(_drawn_worker_ids(main) == [int(worker["id"])],
		"Owning a workplace or standing at its door must not hide an outdoor worker", failures)
	_expect(world._enter_worker_building(worker, int(fixture["building_id"])),
		"The indoor view fixture must enter a real completed building", failures)
	var passerby_id: int = world.spawn_worker(fixture["entrance"], "carrier")
	_expect(passerby_id != 0 and world.workers[passerby_id]["position"] == worker["position"],
		"The outdoor passerby must share the indoor worker's virtual doorway position", failures)
	_expect(_drawn_worker_ids(main) == [passerby_id],
		"Only actual indoor occupancy may hide a unit; the outdoor passerby remains visible", failures)
	_expect(not world._try_exit_worker_building(worker) and world.is_worker_inside(worker)
		and _drawn_worker_ids(main) == [passerby_id],
		"A temporarily occupied exit must keep its waiting indoor worker hidden", failures)
	main.free()


static func _test_enter_exit_draw_entries(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var main: MainView = _view_for(world)
	var outdoor_entries: Array[Dictionary] = main._world_draw_entries()
	_expect(world._enter_worker_building(worker, int(fixture["building_id"]))
		and _drawn_worker_ids(main).is_empty(),
		"Entering a completed house must immediately remove the outdoor worker draw entry", failures)
	_expect(world._try_exit_worker_building(worker) and not world.is_worker_inside(worker)
		and _drawn_worker_ids(main) == [int(worker["id"])],
		"Exiting through a free door must restore the same citizen's draw entry", failures)
	var returned_entries: Array[Dictionary] = main._world_draw_entries()
	_expect(returned_entries.size() == outdoor_entries.size(),
		"An enter/exit cycle must not duplicate a worker or remove its building", failures)
	for entry: Dictionary in returned_entries:
		if String(entry["kind"]) == "worker":
			_expect((entry["position"] as Vector2).is_equal_approx(main.terrain_renderer.cell_center(fixture["entrance"])),
				"A returning worker must reappear at the real entrance, without interpolating from the roof", failures)
	main.free()


static func _test_indoor_details_keep_citizens(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var building_id: int = fixture["building_id"]
	var hud := Hud.new()
	hud.configure(world.catalog)
	worker["carrying"] = "log"
	var stock_before: Dictionary = world.resource_stock("log")
	world._enter_worker_building(worker, building_id)
	var visitor_id: int = world.spawn_worker(fixture["entrance"], "carrier")
	world._enter_worker_building(world.workers[visitor_id], building_id)
	var details: String = hud._selected_production_text(world, world.buildings[building_id]["position"])
	_expect(details.contains("Worker: Carpenter #%d • 1/1 • inside" % int(worker["id"]))
		and details.contains("Inside: 2 citizens"),
		"Selected buildings must show their real indoor employee and visiting carrier separately from workplace capacity", failures)
	hud.refresh(world, world.buildings[building_id]["position"], "", 0.0, MainView.FIXED_TICK_SECONDS)
	_expect(hud._citizens_label.text == "2 citizens · 0 soldiers" and hud._worker_summary_text(world).contains("Citizens 2")
		and hud._worker_summary_text(world).contains("Soldiers 0")
		and world.resource_stock("log") == stock_before,
		"Indoor citizens and their carried resources must remain in the settlement totals", failures)
	hud.free()
	# An employee eating in another building is not indoors at their workplace.
	var visiting_world := World.new(Vector2i(14, 8))
	var home_id: int = visiting_world.place_building("sawmill", Vector2i(3, 3))
	var inn_id: int = visiting_world.place_building("inn", Vector2i(9, 3))
	var employee_id: int = visiting_world.spawn_worker(visiting_world.buildings[inn_id]["entrance"], "carpenter", home_id)
	visiting_world._enter_worker_building(visiting_world.workers[employee_id], inn_id)
	hud = Hud.new()
	hud.configure(visiting_world.catalog)
	var home_details: String = hud._selected_production_text(visiting_world, Vector2i(3, 3))
	var inn_details: String = hud._selected_production_text(visiting_world, Vector2i(9, 3))
	_expect(home_details.contains("1/1") and not home_details.contains(" • inside")
		and not home_details.contains("Inside:") and inn_details.contains("Inside: 1 citizen"),
		"Indoor labels must identify the actual visited building, not merely the worker's assigned home", failures)
	hud.free()


static func _test_selection_and_read_only_queries(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var main: MainView = _view_for(world)
	world._enter_worker_building(fixture["worker"], fixture["building_id"])
	var saved_before: Dictionary = world.to_data()
	var workers_before: Dictionary = world.workers.duplicate(true)
	var terrain_builds: int = main.terrain_renderer.base_cell_build_count
	var center: Vector2 = main.terrain_renderer.cell_center(Vector2i(4, 3))
	for sample: int in range(4):
		_expect(main._building_id_at_visual_position(center + Vector2(0, -28)) == int(fixture["building_id"]),
			"Hiding indoor residents must leave the actual roof/building selection target intact", failures)
		_drawn_worker_ids(main)
	_expect(world.to_data() == saved_before and world.workers == workers_before
		and main.terrain_renderer.base_cell_build_count == terrain_builds,
		"Indoor visibility and selection queries must not advance simulation or rebuild static terrain", failures)
	main.free()


# Cases 5 and 6 use real retained-row callbacks, including a deliberately stale
# worker entry, then repaint after exit. No sprite lookup means no shadow, cargo
# or hunger drawing can execute because all are downstream of that lookup.
static func _test_actual_draw_and_return(host: Node, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	worker["carrying"] = "log"
	worker["hunger"] = 300
	world._enter_worker_building(worker, fixture["building_id"])
	var outdoor_id: int = world.spawn_worker(Vector2i(7, 5), "carrier")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	main.world = world
	main.simulation_speed = 0.0
	main.terrain_renderer.bind_grid(world.grid)
	main._center_camera()
	var spy := PresentationSpy.new()
	main.unit_sprites = spy
	var stale_canvas := Node2D.new()
	main.add_child(stale_canvas)
	var stale_draws: Array[int] = [0]
	var stale_entry: Dictionary = {"kind": "worker", "state": worker,
		"position": main.terrain_renderer.cell_center(fixture["entrance"])}
	stale_canvas.draw.connect(func() -> void:
		stale_draws[0] += 1
		main._draw_canvas = stale_canvas
		main._draw_world_entry(stale_entry)
		main._draw_canvas = null
	)
	var saved_before: Dictionary = world.to_data()
	var workers_before: Dictionary = world.workers.duplicate(true)
	for frame: int in range(5):
		main.queue_redraw()
		stale_canvas.queue_redraw()
		await host.get_tree().process_frame
	_expect(stale_draws[0] > 0 and spy.presented_ids.has(outdoor_id),
		"The indoor visibility test must execute actual stale and normal outdoor draw callbacks", failures)
	_expect(not spy.presented_ids.has(int(worker["id"])),
		"Neither retained rows nor stale entries may draw an indoor sprite, shadow, carried log or hunger mark", failures)
	_expect(world.to_data() == saved_before and world.workers == workers_before,
		"Repeated paused indoor drawing must preserve saved and transient simulation state", failures)
	stale_canvas.free()
	spy.presented_ids.clear()
	_expect(world._try_exit_worker_building(worker), "The real drawing fixture must return through its free door", failures)
	var terrain_builds: int = main.terrain_renderer.base_cell_build_count
	for frame: int in range(4):
		main.queue_redraw()
		await host.get_tree().process_frame
	_expect(spy.presented_ids.has(int(worker["id"])) and spy.presented_ids.has(outdoor_id),
		"The exited citizen must reappear through the actual renderer alongside existing outdoor units", failures)
	_expect(main.terrain_renderer.base_cell_build_count == terrain_builds,
		"Showing an exiting worker must only repaint the dynamic view, not rebuild the base map", failures)
	viewport.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
