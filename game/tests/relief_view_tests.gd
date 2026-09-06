extends RefCounted

const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Demo = preload("res://scripts/simulation/relief_demo.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const TEST_COUNT: int = 6
const MAP_CLICK: Vector2 = Vector2(810, 410)


# A dedicated scene leaves the existing flat economy input fixtures untouched.
# Keys and clicks reach the normal viewport/GUI dispatch, not view callbacks.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.demo_kind = "relief"
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.world.economy_enabled = false
	await _settle(host)
	_expect(main.demo_kind == "relief" and main.world.grid.size == Demo.MAP_SIZE,
		"Relief mode must open the authored relief map", failures)
	await _test_overlay_controls(host, main, viewport, failures)
	await _test_raised_ground_selection(host, main, viewport, failures)
	await _test_road_on_ramp(host, main, viewport, failures)
	await _test_building_slope_and_plateau(host, main, viewport, failures)
	_test_worker_ground_sampling(main, failures)
	await _test_raised_roof_selection(host, main, viewport, failures)
	viewport.free()
	return failures


static func _test_overlay_controls(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	var toggle: Button = main.find_child("TerrainOverlayToggle", true, false) as Button
	if toggle == null:
		failures.append("Relief HUD must expose TerrainOverlayToggle")
		return
	_expect(not main.show_terrain_rules and not main.terrain_renderer.show_passability and not toggle.button_pressed,
		"Relief map must begin with the normal terrain view", failures)
	_key(viewport, KEY_F2)
	_expect(main.show_terrain_rules and main.terrain_renderer.show_passability and toggle.button_pressed,
		"F2 through viewport input must enable both the terrain overlay and its HUD state", failures)
	_click_position(viewport, toggle.get_global_rect().get_center())
	await _settle(host)
	_expect(not main.show_terrain_rules and not main.terrain_renderer.show_passability and not toggle.button_pressed,
		"A real Terrain button click must disable the keyboard-enabled overlay", failures)
	_key(viewport, KEY_F2)
	_expect(main.show_terrain_rules and toggle.button_pressed,
		"F2 must still toggle terrain while its HUD button retains focus", failures)
	_key(viewport, KEY_F2)
	_expect(not main.show_terrain_rules and not toggle.button_pressed,
		"The next F2 press must return terrain and button to their default state", failures)


static func _test_raised_ground_selection(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	_key(viewport, KEY_ESCAPE)
	_center_cell_at(main, viewport, Demo.PLATEAU, MAP_CLICK)
	await _settle(host)
	_click_position(viewport, MAP_CLICK)
	await _settle(host)
	_expect(main.selected_cell == Demo.PLATEAU,
		"Clicking the raised meadow must select its actual cell, not the flat inverse row", failures)
	_expect(main.building_inventory_label.text.contains("Height: 4.0")
		and main.building_inventory_label.text.contains("Walkable"),
		"The selected plateau inspector must show its real height and walkability", failures)
	var foot: Vector2 = main.terrain_renderer.cell_center(Demo.PLATEAU)
	var flat: Vector2 = MapProjectionClass.cell_center(Demo.PLATEAU)
	_expect(is_equal_approx(flat.y - foot.y, 32.0),
		"The four-unit plateau must visibly rise 32 pixels above the flat projection", failures)


static func _test_road_on_ramp(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	# Remove exactly one starter road tile in this isolated fixture, providing a
	# positive placement check on the same visible slope used by the demo route.
	main.world.grid.roads.erase(Demo.RAMP)
	main.world.grid.revision += 1
	main.terrain_renderer.invalidate_cell(Demo.RAMP)
	_expect(main.world.grid.cell_slope(Demo.RAMP) > 0 and not main.world.grid.roads.has(Demo.RAMP),
		"Road input fixture must contain a genuinely sloping, unpaved tile", failures)
	_key(viewport, KEY_1)
	_center_cell_at(main, viewport, Demo.RAMP, MAP_CLICK)
	await _settle(host)
	_click_position(viewport, MAP_CLICK)
	_expect(main.world.grid.roads.has(Demo.RAMP) and main.selected_cell == Demo.RAMP,
		"The road shortcut and actual slope click must build on the selected ramp cell", failures)


static func _test_building_slope_and_plateau(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	_key(viewport, KEY_3)
	_center_cell_at(main, viewport, Demo.RAMP, MAP_CLICK)
	await _settle(host)
	var before: int = main.world.buildings.size()
	_click_position(viewport, MAP_CLICK)
	_expect(main.world.buildings.size() == before and main.world.building_id_at(Demo.RAMP) == 0,
		"The building tool must refuse a walkable but nonlevel slope", failures)
	_expect(main.event_label.text.contains("level ground"),
		"A rejected sloping building site must explain the level-ground requirement", failures)
	# Full footprints also reserve a fixed entrance: choose a clear raised plot
	# beside the authored sawmill, including the approach beyond its walls.
	var plateau_site := Vector2i(-1, -1)
	for y: int in range(main.world.grid.size.y):
		for x: int in range(main.world.grid.size.x):
			var candidate := Vector2i(x, y)
			if main.world.grid.cell_height(candidate) == float(Demo.PLATEAU_HEIGHT) and main.world.can_place_building("lumber_hut", candidate):
				plateau_site = candidate
				break
		if plateau_site != Vector2i(-1, -1):
			break
	_expect(main.world.can_place_building("lumber_hut", plateau_site),
		"The elevated positive-control building site must be legally buildable", failures)
	_center_cell_at(main, viewport, plateau_site, MAP_CLICK)
	await _settle(host)
	_click_position(viewport, MAP_CLICK)
	_expect(main.world.buildings.size() == before + 1
		and main.world.building_id_at(plateau_site) != 0
		and main.selected_cell == plateau_site,
		"The same building tool must accept a flat raised plateau through map input", failures)


static func _test_worker_ground_sampling(main: MainView, failures: Array[String]) -> void:
	var worker_id: int = int(main.world.workers.keys()[0])
	var original: Dictionary = (main.world.workers[worker_id] as Dictionary).duplicate(true)
	var worker: Dictionary = main.world.workers[worker_id] as Dictionary
	var previous_accumulator: float = main.accumulator
	worker["previous_position"] = Vector2i(9, 7)
	worker["position"] = Vector2i(9, 8)
	worker["visual_duration_ticks"] = 4
	worker["visual_progress_ticks"] = 1
	main.accumulator = MainView.FIXED_TICK_SECONDS * 0.5
	var found: bool = false
	for entry: Dictionary in main._world_draw_entries():
		if entry["kind"] != "worker" or int(entry["id"]) != worker_id:
			continue
		found = true
		# At alpha 3/8 the foot is still on the flat top (corner-space y=7.875).
		# Interpolating the two projected endpoints would instead sink it 1.5px.
		var expected_ground := Vector2(9.0, 7.375)
		var expected_foot := Vector2(9.5 * MapProjectionClass.CELL_SIZE.x,
			7.875 * MapProjectionClass.CELL_SIZE.y - 4.0 * MapProjectionClass.HEIGHT_STEP_PIXELS)
		_expect((entry["ground_position"] as Vector2).is_equal_approx(expected_ground),
			"Worker interpolation must preserve fractional logical ground coordinates", failures)
		_expect((entry["position"] as Vector2).distance_to(expected_foot) < 0.01,
			"Interpolated worker feet must sample the actual plateau edge, not lerp projected endpoints", failures)
	_expect(found, "World drawing must retain the sampled worker entry", failures)
	main.world.workers[worker_id] = original
	main.accumulator = previous_accumulator


static func _test_raised_roof_selection(host: Node, main: MainView, viewport: SubViewport, failures: Array[String]) -> void:
	_key(viewport, KEY_ESCAPE)
	var cell: Vector2i = Demo.BUILDING_CELLS["sawmill"]
	_center_cell_at(main, viewport, cell, MAP_CLICK)
	await _settle(host)
	# The roof projects above the footprint onto a different terrain row.
	var roof_point: Vector2 = MAP_CLICK + Vector2(0, -29)
	_click_position(viewport, roof_point)
	await _settle(host)
	_expect(main.selected_cell == cell and main.world.building_id_at(main.selected_cell) != 0,
		"Clicking an elevated sawmill roof must select its building instead of terrain behind it", failures)


static func _center_cell_at(main: MainView, viewport: SubViewport, cell: Vector2i, screen: Vector2) -> void:
	main.camera.zoom = Vector2.ONE
	var position: Vector2 = main.terrain_renderer.to_global(main.terrain_renderer.cell_center(cell))
	main.camera.position = position - (screen - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _key(viewport: Viewport, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)


static func _click_position(viewport: Viewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		viewport.push_input(event, true)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
