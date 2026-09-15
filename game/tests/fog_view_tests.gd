extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const Preview = preload("res://scripts/view/placement_preview_rules.gd")
const SpriteLibrary = preload("res://scripts/view/unit_sprite_library.gd")
const TEST_COUNT: int = 8


class PresentationSpy:
	extends SpriteLibrary
	var ids: Array[int] = []
	func presentation_for(worker: Dictionary, feet: Vector2, tick: int, frame_alpha: float) -> Dictionary:
		ids.append(int(worker["id"]))
		return super.presentation_for(worker, feet, tick, frame_alpha)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_dynamic_visibility_and_picking(failures)
	_test_static_memory_and_indoor_workers(failures)
	_test_hud_ownership_and_unknown_details(failures)
	_test_placement_requires_complete_exploration(failures)
	_test_retained_fog_cache(failures)
	await _test_actual_input_and_draw(host, failures) # Cases 6 and 7.
	await _test_native_black_memory_and_relief(host, failures) # Case 8.
	return failures


static func _fixture() -> Dictionary:
	var world := World.new(Vector2i(30, 20))
	world.tick = 1750 # Noon: real cast shadows must be exercised, not disabled dawn shadows.
	var local_id: int = world.spawn_worker(Vector2i(8, 8), "carrier")
	var enemy_id: int = world.spawn_worker(Vector2i(12, 8), "carrier")
	world.workers[enemy_id]["owner_id"] = 2
	world.workers[enemy_id]["carrying"] = "gold"
	world.workers[enemy_id]["hunger"] = 120
	world.enable_fog(1)
	return {"world": world, "local": local_id, "enemy": enemy_id}


static func _move_observer(fixture: Dictionary, cell: Vector2i) -> void:
	var world: World = fixture["world"]
	var worker: Dictionary = world.workers[fixture["local"]]
	world._release_worker_tile(worker)
	worker["position"] = cell
	worker["previous_position"] = cell
	world.tile_reservations[cell] = int(worker["id"])
	world.update_visibility()


static func _view_for(world: World) -> MainView:
	var view := MainView.new()
	view.world = world
	view.terrain_renderer = Terrain.new()
	view.add_child(view.terrain_renderer)
	view.terrain_renderer.bind_grid(world.grid)
	return view


static func _has_entry(view: MainView, kind: String, id: int) -> bool:
	for entry: Dictionary in view._world_draw_entries():
		if entry["kind"] == kind and int(entry["id"]) == id:
			return true
	return false


static func _test_dynamic_visibility_and_picking(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var view: MainView = _view_for(world)
	var enemy: Dictionary = world.workers[fixture["enemy"]]
	var feet: Vector2 = view.terrain_renderer.cell_center(enemy["position"])
	var hit: Vector2 = (view.worker_presentation(enemy, feet)["rect"] as Rect2).get_center()
	_check(_has_entry(view, "worker", fixture["enemy"]) and view._worker_id_at_visual_position(hit) == int(fixture["enemy"]),
		"A foreign worker inside local sight must be drawn and have a genuine visible hit target", failures)
	_move_observer(fixture, Vector2i(2, 2))
	var before: Dictionary = world.to_data()
	_check(world.fog_state(enemy["position"]) == 1 and not _has_entry(view, "worker", fixture["enemy"])
		and view._worker_id_at_visual_position(hit) == 0 and _has_entry(view, "worker", fixture["local"]),
		"Leaving local sight must retain explored ground but remove the foreign sprite and its hit target", failures)
	_check(not bool(view.worker_satiety_presentation(enemy, feet).get("visible", false))
		and not bool(view.worker_earthwork_presentation(enemy, feet).get("visible", false)),
		"Hidden workers must not expose satiety labels, food markers or earthwork presentation", failures)
	_check(world.to_data() == before, "Fog drawing and picking must remain read-only", failures)
	view.free()


static func _test_static_memory_and_indoor_workers(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var known_id: int = world.place_building("school", Vector2i(11, 11), 2)
	var unknown_id: int = world.place_building("school", Vector2i(24, 15), 2)
	var known_tree: int = world.add_tree(Vector2i(10, 7), 3)
	var hidden_tree: int = world.add_tree(Vector2i(25, 6), 3)
	world.update_visibility()
	_move_observer(fixture, Vector2i(2, 2))
	var view: MainView = _view_for(world)
	_check(_has_entry(view, "building", known_id) and _has_entry(view, "tree", known_tree)
		and not _has_entry(view, "building", unknown_id) and not _has_entry(view, "tree", hidden_tree),
		"Explored static landmarks must remain while wholly unknown buildings and trees stay hidden", failures)
	var unknown_center: Vector2 = view.building_geometry(world.buildings[unknown_id])["detail_center"]
	_check(view._building_id_at_visual_position(unknown_center + Vector2(0, -20)) == 0,
		"An unknown roof must not become a selectable building through the black mask", failures)
	var own_hut: int = world.place_building("sawmill", Vector2i(4, 14))
	var indoor_id: int = world.spawn_worker(world.buildings[own_hut]["entrance"], "carpenter", own_hut)
	world._enter_worker_building(world.workers[indoor_id], own_hut)
	world.update_visibility()
	_check(not _has_entry(view, "worker", indoor_id) and _has_entry(view, "building", own_hut),
		"Local sight must not undo the existing hiding of workers inside buildings", failures)
	var hud := Hud.new()
	hud.configure(world.catalog)
	hud.refresh(world, world.workers[indoor_id]["position"], "", 0.0, World.TICK_SECONDS, indoor_id)
	_check(hud._selected_unit_id == indoor_id and hud._satiety_panel.visible,
		"A previously selected local worker may retain its inspector while working indoors", failures)
	hud.free()
	view.free()


static func _test_hud_ownership_and_unknown_details(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var own_id: int = world.place_building("warehouse", Vector2i(4, 4))
	var foreign_id: int = world.place_building("school", Vector2i(24, 15), 2)
	world.buildings[own_id]["storage"]["plank"] = 7
	var foreign: Dictionary = world.buildings[foreign_id]
	foreign["owner_id"] = 2
	foreign["outputs"]["plank"] = 400
	foreign["training_queue"] = ["gardener"]
	var soldier_id: int = world.spawn_worker(Vector2i(25, 8), "bowman", 0, false, 0, 2)
	world.workers[soldier_id]["hunger"] = 10
	world.workers[soldier_id]["food_requested"] = true
	world.update_visibility()
	var hud := Hud.new()
	hud.configure(world.catalog)
	hud.refresh(world, foreign["position"], "", 0.0, World.TICK_SECONDS, fixture["enemy"])
	_check(hud._selected_unit_id == 0 and not hud._satiety_panel.visible
		and not hud._actions.visible and not hud._soldier_food_panel.visible,
		"Foreign units and unknown buildings must not retain local command or private-detail controls", failures)
	_check(hud.building_inventory_label.text.is_empty() and hud.production_detail_label.text.is_empty()
		and hud._selected_training_text(world, foreign["position"]).is_empty(),
		"Unknown cells must reveal no inventory, production, foundation or training details", failures)
	var counts: Dictionary = hud._food_summary(world)
	_check(counts["citizens"] == 1 and counts["soldiers"] == 0 and counts["hungry"] == 0
		and counts["requested"] == 0 and counts["eligible"] == 0
		and hud.resource_amount_labels["plank"].text == "7" and hud.resource_amount_labels["gold"].text == "0",
		"Hidden foreign citizens, soldiers, requests and carried/stored wares must never enter the local HUD totals", failures)
	var explored: Array[Vector2i] = []
	for cell: Vector2i in world.fog.explored:
		explored.append(cell)
	explored.append(foreign["position"])
	world.fog.restore_explored(explored)
	hud.refresh(world, foreign["position"], "", 0.0, World.TICK_SECONDS)
	_check(hud.building_inventory_label.text.contains("Cizí budova")
		and not hud.building_inventory_label.text.contains("400") and hud.production_detail_label.text.is_empty()
		and not hud._actions.visible and hud._selected_training_text(world, foreign["position"]).is_empty(),
		"A remembered foreign building may keep its name but not disclose its private economy or controls", failures)
	hud.free()


static func _test_placement_requires_complete_exploration(failures: Array[String]) -> void:
	var world := World.new(Vector2i(20, 16))
	world.economy_enabled = true
	world.enable_fog(1)
	var anchor := Vector2i(10, 8)
	var cells: Array[Vector2i] = world.placement_cells("school", anchor)
	var entrance: Vector2i = world.placement_entrance("school", anchor)
	world.fog.restore_explored([anchor])
	var unknown: Dictionary = Preview.evaluate(world, "school", anchor)
	_check(not unknown["valid"] and bool(unknown.get("obscured", false))
		and (unknown["cells"] as Array).is_empty() and unknown["entrance"] == Vector2i(-1, -1)
		and not unknown.has("foundation_target_height"),
		"A known anchor must not disclose or build its still-unknown foundation footprint", failures)
	world.fog.restore_explored(cells)
	_check(bool(Preview.evaluate(world, "school", anchor).get("obscured", false)),
		"A building also needs its separate approach/door tile explored", failures)
	cells.append(entrance)
	world.fog.restore_explored(cells)
	_check(bool(Preview.evaluate(world, "school", anchor)["valid"]),
		"Fully explored empty terrain must still allow normal building placement", failures)
	var hud := Hud.new()
	hud.configure(world.catalog)
	hud.set_placement_preview("school", unknown)
	_check(not hud.placement_preview_label.text.contains("Height") and not hud.placement_preview_label.text.contains("slope"),
		"The unexplored placement hint must not invent zero height/slope readings for hidden land", failures)
	hud.free()


static func _test_retained_fog_cache(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var view: MainView = _view_for(world)
	view.fog_renderer.sync(world, view.terrain_renderer)
	var meshes: int = view.fog_renderer.mesh_build_count
	var geometry_builds: int = view.fog_renderer.geometry_build_count
	var base_builds: int = view.terrain_renderer.base_cell_build_count
	var row_builds: int = view.terrain_renderer.row_mesh_build_count
	var grid_revision: int = world.grid.revision
	var fog_revision: int = world.fog.revision
	for frame: int in range(4):
		world.update_visibility()
		view.fog_renderer.sync(world, view.terrain_renderer)
	_check(view.fog_renderer.mesh_build_count == meshes and world.fog.revision == fog_revision,
		"Stationary vision must reuse its retained fog masks without rebuilding on every frame", failures)
	_move_observer(fixture, Vector2i(9, 8))
	var changed_rows: Dictionary = {}
	for cell: Vector2i in world.fog.changes_since(fog_revision)["cells"]:
		changed_rows[cell.y] = true
	view.fog_renderer.sync(world, view.terrain_renderer)
	_check(view.fog_renderer.mesh_build_count - meshes == changed_rows.size()
		and not changed_rows.is_empty() and changed_rows.size() < world.grid.size.y,
		"A short scout step must rebuild only ground rows whose fog state changed", failures)
	_check(world.grid.revision == grid_revision and view.terrain_renderer.base_cell_build_count == base_builds
		and view.terrain_renderer.row_mesh_build_count == row_builds,
		"Vision must never invalidate simulation terrain, painted ground or retained base meshes", failures)
	_check(geometry_builds > 0 and view.fog_renderer.geometry_build_count == geometry_builds,
		"Observer motion must reuse projected fog vertices and update opacity only", failures)
	var before_height: PackedVector2Array = view.fog_renderer._row_geometry[15]["points"].duplicate()
	world.grid.set_vertex_height(Vector2i(22, 16), 2)
	var terrain_rows: Dictionary = {}
	for cell: Vector2i in world.grid.rendering_changes_since(grid_revision)["terrain"]:
		terrain_rows[cell.y] = true
	view.fog_renderer.sync(world, view.terrain_renderer)
	_check(not terrain_rows.is_empty()
		and view.fog_renderer.geometry_build_count - geometry_builds == terrain_rows.size()
		and view.fog_renderer._row_geometry[15]["points"] != before_height,
		"A real terrain-height edit must rebuild the affected fog row geometry so the mask remains grounded", failures)
	view.free()


static func _attach_view(host: Node, world: World) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 900)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var view: MainView = MainScene.instantiate() as MainView
	view.world = world
	view.honor_launch_arguments = false
	viewport.add_child(view)
	view.set_process(false)
	view.simulation_speed = 0.0
	view.camera.position_smoothing_enabled = false
	view.camera.position = Vector2(world.grid.size) * 20.0
	view.camera.zoom = Vector2.ONE
	view.camera.reset_smoothing()
	view.camera.force_update_scroll()
	view._camera_auto_fit = false
	return {"view": view, "viewport": viewport}


static func _test_actual_input_and_draw(host: Node, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var scene: Dictionary = _attach_view(host, world)
	var view: MainView = scene["view"]
	var viewport: SubViewport = scene["viewport"]
	view.selected_unit_id = fixture["enemy"]
	view._update_ui()
	_move_observer(fixture, Vector2i(2, 2))
	view._update_ui()
	_check(view.selected_unit_id == 0 and view.selected_cell == Vector2i(-1, -1)
		and not view.hud._satiety_panel.visible,
		"An enemy leaving view must clear its persistent selected ID and inspector before the next frame", failures)
	var before: Dictionary = world.to_data()
	view.build_mode = "school"
	view._apply_build_mode(Vector2i(25, 15))
	view.build_mode = "road"
	view._apply_build_mode(Vector2i(26, 15))
	_check(world.to_data() == before, "Direct placement commands must not construct roads or buildings in unexplored land", failures)
	view.build_mode = ""
	view.selected_cell = Vector2i(26, 15)
	view._update_ui()
	_check(view.selected_cell == Vector2i(-1, -1), "Unknown ground must not remain selected behind the fog", failures)
	view.hud.visible = false
	var spy := PresentationSpy.new()
	view.unit_sprites = spy
	var stale_canvas := Node2D.new()
	view.add_child(stale_canvas)
	var callbacks: Array[int] = [0]
	var enemy: Dictionary = world.workers[fixture["enemy"]]
	stale_canvas.draw.connect(func() -> void:
		callbacks[0] += 1
		view._draw_canvas = stale_canvas
		view._draw_worker(enemy, view.terrain_renderer.cell_center(enemy["position"]))
		view._draw_canvas = null
	)
	for frame: int in range(5):
		view.queue_redraw()
		stale_canvas.queue_redraw()
		await host.get_tree().process_frame
	_check(callbacks[0] > 0 and spy.ids.has(int(fixture["local"])) and not spy.ids.has(int(fixture["enemy"])),
		"Real normal and deliberately stale callbacks must draw the local worker but no hidden sprite/cargo/satiety", failures)
	_check(world.to_data() == before, "Paused fog/input/drawing checks must not advance or mutate the simulation", failures)
	viewport.free()


static func _capture(host: Node, view: MainView, viewport: SubViewport) -> Image:
	for frame: int in range(4):
		view.queue_redraw()
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


static func _sample(image: Image, view: MainView, cell: Vector2i) -> Color:
	var screen: Vector2 = view.get_global_transform_with_canvas() * view.terrain_renderer.cell_center(cell)
	return image.get_pixelv(Vector2i(screen))


static func _test_native_black_memory_and_relief(host: Node, failures: Array[String]) -> void:
	if DisplayServer.get_name() == "headless":
		return # Pixel assertions execute in the native-renderer test run.
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	_move_observer(fixture, Vector2i(2, 2))
	var scene: Dictionary = _attach_view(host, world)
	var view: MainView = scene["view"]
	var viewport: SubViewport = scene["viewport"]
	view.hud.visible = false
	view._set_terrain_rules(true)
	var hidden: Image = await _capture(host, view, viewport)
	var enemy: Dictionary = world.workers[fixture["enemy"]]
	world.workers.erase(fixture["enemy"])
	world.tile_reservations.erase(enemy["position"])
	var absent: Image = await _capture(host, view, viewport)
	_check(hidden.get_data() == absent.get_data(),
		"Native hidden-enemy pixels must equal an absent-enemy baseline: no body, shadow, gold, hunger or selection leak", failures)
	world.fog.enabled = false
	view._update_ui()
	var clear: Image = await _capture(host, view, viewport)
	var black: Color = _sample(hidden, view, Vector2i(27, 17))
	var memory: Color = _sample(hidden, view, Vector2i(8, 8))
	var original: Color = _sample(clear, view, Vector2i(8, 8))
	var visible: Color = _sample(hidden, view, Vector2i(4, 4))
	var visible_clear: Color = _sample(clear, view, Vector2i(4, 4))
	_check(black.r < 0.01 and black.g < 0.01 and black.b < 0.01,
		"Unexplored ground must be genuinely black even with terrain-rule overlays enabled", failures)
	_check(memory.g > 0.01 and memory.g < original.g * 0.95 and visible.is_equal_approx(visible_clear),
		"Explored terrain remains recognizable and darker, while current sight retains its normal brightness", failures)
	viewport.free()
	# A known raised foreground row overlaps an unknown valley in screen
	# space. Fog must follow the terrain painter order, not cover the ridge.
	var relief := World.new(Vector2i(8, 8))
	for y: int in range(4, 9):
		for x: int in range(9):
			relief.grid.set_vertex_height(Vector2i(x, y), 16)
	relief.enable_fog(1)
	var known: Array[Vector2i] = []
	for y: int in range(4, 8):
		for x: int in range(8):
			known.append(Vector2i(x, y))
	relief.fog.restore_explored(known)
	scene = _attach_view(host, relief)
	view = scene["view"]
	viewport = scene["viewport"]
	view.hud.visible = false
	var ridge: Image = await _capture(host, view, viewport)
	var ridge_color: Color = _sample(ridge, view, Vector2i(3, 4))
	_check(ridge_color.g > 0.03,
		"An explored raised foreground ridge must not be blackened by overlapping unexplored valley masks", failures)
	viewport.free()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
