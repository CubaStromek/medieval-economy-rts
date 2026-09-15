extends RefCounted

## Procedural buildings keep retained drawing and cached geometry until their
## visual inputs change, without altering the painter order within a row.
const World = preload("res://scripts/simulation/simulation_world.gd")
const MainScene = preload("res://scenes/main.tscn")
const MainView = preload("res://scripts/view/main_view.gd")
const FootprintRenderer = preload("res://scripts/view/building_footprint_renderer.gd")
const TEST_COUNT: int = 4


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_geometry_cache, _test_static_redraws_follow_inputs,
		_test_painter_order_around_buildings, _test_removed_building_leaves_no_layer]:
		await test.call(host, failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _scene(host: Node) -> Dictionary:
	var world := World.new(Vector2i(22, 16))
	var school: int = world.place_building("school", Vector2i(5, 5))
	var mill: int = world.place_building("mill", Vector2i(14, 5))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	main.world = world
	main.simulation_speed = 0.0
	main.terrain_renderer.bind_grid(world.grid)
	main.hud.visible = false
	await _frames(host, main, 2)
	return {"world": world, "main": main, "viewport": viewport, "school": school, "mill": mill}


static func _frames(host: Node, main: MainView, count: int) -> void:
	for _frame: int in range(count):
		main.queue_redraw()
		await host.get_tree().process_frame


static func _test_geometry_cache(host: Node, failures: Array[String]) -> void:
	var scene: Dictionary = await _scene(host)
	var world: World = scene["world"]
	var main: MainView = scene["main"]
	var building: Dictionary = world.buildings[scene["school"]]
	var first: Dictionary = main.building_geometry(building)
	_check(is_same(main.building_geometry(building), first)
		and first == FootprintRenderer.geometry(world, main.terrain_renderer, building),
		"Unchanged building geometry must be reused and equal a fresh computation", failures)
	var corner: Vector2i = world.building_cells(building)[0]
	var raised: bool = world.grid.set_foundation_vertex_height(corner, world.grid.vertex_height(corner) + 1, int(building["id"]))
	var second: Dictionary = main.building_geometry(building)
	_check(raised and not is_same(second, first) and second["foundations"] != first["foundations"]
		and second == FootprintRenderer.geometry(world, main.terrain_renderer, building),
		"A terrain height change under the house must rebuild its cached geometry", failures)
	building["foundation_work_total"] = 10
	building["foundation_work_remaining"] = 4
	var third: Dictionary = main.building_geometry(building)
	_check(bool(third["earthwork"]) and is_equal_approx(float(third["earthwork_progress"]), 0.6)
		and third == FootprintRenderer.geometry(world, main.terrain_renderer, building),
		"Ground-preparation progress must invalidate cached geometry", failures)
	(scene["viewport"] as SubViewport).free()


static func _test_static_redraws_follow_inputs(host: Node, failures: Array[String]) -> void:
	var scene: Dictionary = await _scene(host)
	var world: World = scene["world"]
	var main: MainView = scene["main"]
	var school: int = scene["school"]
	var mill: int = scene["mill"]
	_check(main._building_layers.has(school) and main._building_layers.has(mill),
		"Procedural buildings must receive retained layers", failures)
	if not main._building_layers.has(school) or not main._building_layers.has(mill):
		(scene["viewport"] as SubViewport).free()
		return
	var school_canvas: Node2D = main._building_layers[school]["canvas"]
	var mill_canvas: Node2D = main._building_layers[mill]["canvas"]
	var draws: Array[int] = [0, 0]
	school_canvas.draw.connect(func() -> void: draws[0] += 1)
	mill_canvas.draw.connect(func() -> void: draws[1] += 1)
	await _frames(host, main, 6)
	_check(draws == [0, 0] and main._building_layers[school]["canvas"] == school_canvas,
		"Unchanged procedural buildings must keep their retained drawing across frames", failures)
	main.selected_cell = world.buildings[school]["position"]
	await _frames(host, main, 4)
	_check(draws[0] == 1 and draws[1] == 0, "Selecting a building must redraw only that building, once", failures)
	world.buildings[school]["enabled"] = false
	await _frames(host, main, 3)
	_check(draws[0] == 2, "A change in saved building state must redraw the building once", failures)
	world.buildings[mill]["process_remaining"] = 30
	await _frames(host, main, 3)
	var grinding: int = draws[1]
	world.tick += 1
	await _frames(host, main, 3)
	_check(grinding == 1 and draws[1] == 2, "Grinding mill sails must redraw once per simulation tick", failures)
	(scene["viewport"] as SubViewport).free()


static func _test_painter_order_around_buildings(host: Node, failures: Array[String]) -> void:
	var scene: Dictionary = await _scene(host)
	var world: World = scene["world"]
	var main: MainView = scene["main"]
	var school: int = scene["school"]
	var row: int = int((world.buildings[school]["position"] as Vector2i).y)
	var cells: Array[Vector2i] = world.building_cells(world.buildings[school])
	var min_x: int = 99
	var max_x: int = -99
	for cell: Vector2i in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
	var behind: int = world.spawn_worker(Vector2i(min_x - 2, row), "carrier")
	var front: int = world.spawn_worker(Vector2i(max_x + 2, row), "carrier")
	await _frames(host, main, 2)
	var row_canvas: Node2D = main._dynamic_rows[row]
	var building_index: int = (main._building_layers[school]["canvas"] as Node2D).get_index()
	var indices: Dictionary = {}
	for child: Node in row_canvas.get_children():
		for entry: Dictionary in main._segment_entries.get(child.get_instance_id(), []):
			if entry["kind"] == "worker" and (child as Node2D).visible:
				indices[int(entry["id"])] = child.get_index()
	_check(behind != 0 and front != 0 and indices.has(behind) and indices.has(front)
		and int(indices[behind]) < building_index and int(indices[front]) > building_index,
		"Units sorted before and after a procedural building must stay in separate layers on each side of it", failures)
	var drawn: Array = []
	for child: Node in row_canvas.get_children():
		if (child as Node2D).visible:
			if main._segment_entries.has(child.get_instance_id()):
				drawn.append_array(main._segment_entries[child.get_instance_id()])
			else:
				for id: int in main._building_layers:
					if main._building_layers[id]["canvas"] == child:
						drawn.append(main._building_layers[id]["entry"])
	var expected_ids: Array = []
	for entry: Dictionary in main._row_entries.get(row, []):
		expected_ids.append([entry["kind"], int(entry["id"])])
	var drawn_ids: Array = []
	for entry: Dictionary in drawn:
		drawn_ids.append([entry["kind"], int(entry["id"])])
	_check(drawn_ids == expected_ids, "Layer order must reproduce the complete depth-sorted row exactly", failures)
	(scene["viewport"] as SubViewport).free()


static func _test_removed_building_leaves_no_layer(host: Node, failures: Array[String]) -> void:
	var scene: Dictionary = await _scene(host)
	var world: World = scene["world"]
	var main: MainView = scene["main"]
	var school: int = scene["school"]
	var canvas: Node2D = main._building_layers[school]["canvas"]
	world.buildings.erase(school)
	await _frames(host, main, 1)
	_check(not main._building_layers.has(school) and (not is_instance_valid(canvas) or not canvas.visible),
		"A building that is no longer drawn must hide its retained layer immediately", failures)
	(scene["viewport"] as SubViewport).free()
