extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Preview = preload("res://scripts/view/placement_preview_rules.gd")
const Renderer = preload("res://scripts/view/building_footprint_renderer.gd")
const TEST_COUNT: int = 6


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.world = World.new(Vector2i(32, 24))
	main.terrain_renderer.bind_grid(main.world.grid)
	main.simulation_speed = 0.0
	var ids: Array[int] = []
	for item: Array in [["warehouse", Vector2i(4, 7)], ["lumber_hut", Vector2i(10, 7)], ["sawmill", Vector2i(15, 7)]]:
		ids.append(main.world.place_building(item[0], item[1]))
	if ids.has(0):
		failures.append("Footprint view fixture must place real warehouse, lumber hut and sawmill")
		viewport.free()
		return failures
	main._update_ui()
	main.queue_redraw()
	await _settle(host)
	_test_full_size_geometry(main, ids, failures)
	_test_catalog_geometry(main, failures)
	await _test_actual_selection(host, viewport, main, ids, failures)
	await _test_hover_preview(host, viewport, main, failures)
	_test_obstacle_reasons(main, failures)
	_test_construction_and_legacy(main, failures)
	viewport.free()
	return failures


static func _test_full_size_geometry(main: MainView, ids: Array[int], failures: Array[String]) -> void:
	var expected_sizes: Array[Vector2] = [Vector2(3, 3), Vector2(4, 3), Vector2(4, 2)]
	var expected_cells: Array[int] = [9, 9, 8]
	for index: int in range(ids.size()):
		var building: Dictionary = main.world.buildings[ids[index]]
		var shape: Dictionary = main.building_geometry(building)
		_expect(shape["ground_size"] == expected_sizes[index]
			and (shape["foundations"] as Array).size() == expected_cells[index],
			"Actual building foundations must occupy the authored full %s footprint" % building["type"], failures)
		var approach: Vector2i = building["entrance"]
		var expected_door: Vector2 = main.terrain_renderer.project_grid_position(Vector2(approach) - Vector2(0, 0.5))
		_expect((shape["door"] as Vector2).is_equal_approx(expected_door),
			"Visible door must touch the exact north edge of the usable entrance tile", failures)


static func _test_catalog_geometry(main: MainView, failures: Array[String]) -> void:
	for type: String in main.world.catalog.buildings:
		var anchor := Vector2i(24, 16)
		var building: Dictionary = {"type": type, "position": anchor, "footprint_version": main.world.placement_footprint_version(type),
			"entrance": main.world.placement_entrance(type, anchor)}
		var shape: Dictionary = main.building_geometry(building)
		var definition: Dictionary = main.world.catalog.building(type)
		var mask: Array = definition["footprint_mask"]
		var occupied: int = 0
		for row: int in range(mask.size()):
			for column: int in range(String(mask[row]).length()):
				var cell := anchor + Vector2i(column, row - mask.size() + 1)
				var point: Vector2 = main.terrain_renderer.cell_center(cell)
				var foundation_hit: bool = false
				for polygon: PackedVector2Array in shape["foundations"]:
					foundation_hit = foundation_hit or Geometry2D.is_point_in_polygon(point, polygon)
				var should_occupy: bool = String(mask[row])[column] != "."
				_expect(foundation_hit == should_occupy,
					"Rendered foundation must retain occupied cells and cut-outs for %s at %s" % [type, cell], failures)
				occupied += 1 if should_occupy else 0
		_expect((shape["foundations"] as Array).size() == occupied,
			"Every catalog mask cell must contribute exactly one foundation tile", failures)
		for roof: Dictionary in shape["roofs"]:
			_expect(Geometry2D.triangulate_polygon(roof["points"]).size() >= 3,
				"Even shallow one-row mine roofs must produce a nondegenerate drawable surface", failures)


static func _test_actual_selection(host: Node, viewport: SubViewport, main: MainView, ids: Array[int], failures: Array[String]) -> void:
	main._set_build_mode("")
	var pointer := Vector2(810, 400)
	for id: int in ids:
		var building: Dictionary = main.world.buildings[id]
		for cell: Vector2i in main.world.building_cells(building):
			_center_point(main, viewport, main.terrain_renderer.cell_center(cell), pointer)
			await _settle(host)
			_click(viewport, pointer)
			_expect(main.selected_cell == building["position"] and main.world.building_id_at(main.selected_cell) == id,
				"Clicking every occupied ground tile must inspect its full building", failures)
		var shape: Dictionary = main.building_geometry(building)
		var roof: PackedVector2Array = shape["roofs"][0]["points"]
		var roof_point: Vector2 = (roof[0] + roof[1] + roof[2] + roof[3]) * 0.25
		var sprite: Dictionary = main.building_sprite_presentation(building)
		if not sprite.is_empty():
			# The retained vector shell still describes ground/shadow geometry;
			# bitmap buildings must be clicked on their actual painted roof.
			roof_point = _bitmap_roof_point(sprite)
			_expect(roof_point.is_finite(), "The current bitmap must expose a genuine opaque roof target", failures)
			if not roof_point.is_finite():
				continue
		_center_point(main, viewport, roof_point, pointer)
		await _settle(host)
		_click(viewport, pointer)
		_expect(main.world.building_id_at(main.selected_cell) == id,
			"Clicking the actual drawn roof must select the building", failures)


static func _bitmap_roof_point(sprite: Dictionary) -> Vector2:
	var texture: Texture2D = sprite["texture"]
	var image: Image = texture.get_image()
	if image.is_compressed():
		image.decompress()
	var rect: Rect2 = sprite["rect"]
	var scale: Vector2 = rect.size / Vector2(image.get_size())
	for y: int in range(4, image.get_height() - 4, 4):
		for x: int in range(4, image.get_width() - 4, 4):
			var point: Vector2 = rect.position + (Vector2(x, y) + Vector2.ONE * 0.5) * scale
			if image.get_pixel(x, y).a >= 0.98:
				return point
	return Vector2.INF


static func _test_hover_preview(host: Node, viewport: SubViewport, main: MainView, failures: Array[String]) -> void:
	var anchor := Vector2i(7, 16)
	main._set_build_mode("lumber_hut")
	_center_point(main, viewport, main.terrain_renderer.cell_center(anchor), Vector2(810, 410))
	await _settle(host)
	var before: Dictionary = main.world.to_data().duplicate(true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(810, 410)
	motion.global_position = motion.position
	viewport.push_input(motion, true)
	await _settle(host)
	_expect(main.placement_preview.get("valid", false) and (main.placement_preview.get("cells", []) as Array).size() == 9,
		"A real pointer hover must preview all nine occupied lumber-hut tiles", failures)
	_expect(main.placement_preview.get("entrance") == anchor + Vector2i(3, 0)
		and main._placement_canvas.visible,
		"Actual placement overlay must expose the fixed right-hand door approach separately", failures)
	_expect(main.world.to_data() == before,
		"Area preview and its scene redraw must not mutate the paused simulation", failures)


static func _test_obstacle_reasons(main: MainView, failures: Array[String]) -> void:
	var anchor := Vector2i(7, 16)
	var blocker := anchor + Vector2i(2, -1)
	main.world.add_tree(blocker)
	var result: Dictionary = Preview.evaluate(main.world, "lumber_hut", anchor)
	_expect(not result["valid"] and String(result["reason"]).to_lower().contains("strom"),
		"A tree away from the anchor but inside the full footprint must explain rejection", failures)
	var blocked_approach := Vector2i(18, 16)
	main.world.add_tree(blocked_approach)
	result = Preview.evaluate(main.world, "lumber_hut", Vector2i(15, 16))
	_expect(not result["valid"] and String(result["reason"]).to_lower().contains("vstup"),
		"A blocked fixed entrance must be distinguished from clear building ground", failures)
	result = Preview.evaluate(main.world, "warehouse", Vector2i(31, 1))
	_expect(not result["valid"] and String(result["reason"]).contains("mimo mapu"),
		"An in-map anchor must still explain an out-of-map building footprint", failures)


static func _test_construction_and_legacy(main: MainView, failures: Array[String]) -> void:
	main.world.economy_enabled = true
	var site: int = main.world.place_building("sawmill", Vector2i(22, 17))
	if site == 0:
		failures.append("Construction view test requires a real large construction site")
		return
	var building: Dictionary = main.world.buildings[site]
	_expect(int(building["construction_remaining"]) > 0
		and (main.building_geometry(building)["cells"] as Array).size() == 8,
		"Unfinished scaffolding must occupy the same eight-cell footprint as a complete sawmill", failures)
	var shape: Dictionary = main.building_geometry(building)
	var roof_only := Vector2.INF
	for roof: Dictionary in shape["roofs"]:
		var polygon: PackedVector2Array = roof["points"]
		for fraction: float in [0.15, 0.30, 0.50, 0.70, 0.85]:
			var sample: Vector2 = polygon[0].lerp(polygon[1], fraction).lerp(polygon[3].lerp(polygon[2], fraction), 0.5)
			if Renderer.contains_point(shape, sample) and not Renderer.contains_point(shape, sample, true):
				roof_only = sample
				break
		if roof_only != Vector2.INF:
			break
	_expect(roof_only != Vector2.INF and not main._building_contains_visual_point(building, roof_only),
		"Unfinished sites must not capture pointer clicks on the invisible completed roof", failures)
	# Put a real citizen behind the site, where the eventual roof will obscure
	# the sprite. Empty scaffold gaps must keep that citizen selectable today.
	var worker_id: int = main.world.spawn_worker(Vector2i(23, 15), "carrier")
	_expect(worker_id != 0, "Construction occlusion fixture needs a citizen behind the scaffold", failures)
	if worker_id != 0:
		var worker: Dictionary = main.world.workers[worker_id]
		var feet: Vector2 = main.terrain_renderer.cell_center(worker["position"])
		var sprite: Rect2 = main.worker_presentation(worker, feet)["rect"]
		var gap_point := Vector2.INF
		for y: int in range(1, int(sprite.size.y)):
			for x: int in range(1, int(sprite.size.x)):
				var sample: Vector2 = sprite.position + Vector2(x, y)
				if Renderer.contains_point(shape, sample) and not Renderer.contains_point(shape, sample, true):
					gap_point = sample
					break
			if gap_point != Vector2.INF:
				break
		_expect(gap_point != Vector2.INF and main._worker_id_at_visual_position(gap_point) == worker_id,
			"Invisible roofs must not occlude a real citizen viewed through construction scaffold gaps", failures)
	main.world.default_footprint_version = 0
	main.world.economy_enabled = false
	var legacy: int = main.world.place_building("warehouse", Vector2i(1, 1))
	_expect(legacy != 0 and int(main.world.buildings[legacy]["footprint_version"]) == 0
		and main.world.building_cells(main.world.buildings[legacy]).size() == 1,
		"Legacy saves must keep compact geometry beside newly built full-size houses", failures)
	var center: Vector2 = main.terrain_renderer.cell_center(Vector2i(1, 1))
	_expect(main._building_id_at_visual_position(center + Vector2(0, -29)) == legacy,
		"Legacy roof selection must remain aligned with its original one-cell art", failures)
	main.world.default_footprint_version = 2
	main.queue_redraw()


static func _center_point(main: MainView, viewport: SubViewport, point: Vector2, screen: Vector2) -> void:
	main.camera.zoom = Vector2.ONE
	main.camera.position = main.terrain_renderer.to_global(point) - (screen - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _click(viewport: SubViewport, point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		viewport.push_input(event, true)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
