extends RefCounted

const MainScene = preload("res://scenes/main.tscn")
const MainView = preload("res://scripts/view/main_view.gd")
const Fixture = preload("res://tests/foundation_tests.gd")
const FootprintView = preload("res://tests/footprint_view_tests.gd")
const Shape = preload("res://scripts/view/building_footprint_renderer.gd")
const TEST_COUNT: int = 6
const POINTER := Vector2(810, 410)

static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	# Share the measured revision-1, eight-height-unit foundation so real
	# pointer dispatch, stakes and shovel cues retain their 64-tick contract.
	main.world = Fixture._fixture(false)["world"]
	main.terrain_renderer.bind_grid(main.world.grid)
	main.simulation_speed = 0.0
	main.camera.position_smoothing_enabled = false
	main._set_build_mode("lumber_hut")
	FootprintView._center_point(main, viewport, main.terrain_renderer.cell_center(Fixture.SITE), POINTER)
	await FootprintView._settle(host)
	# 1. Real pointer dispatch and frame-driven preview must never do earthwork.
	var before: Dictionary = Fixture._state(main.world)
	var motion := InputEventMouseMotion.new()
	motion.position = POINTER
	motion.global_position = POINTER
	viewport.push_input(motion, true)
	await FootprintView._settle(host)
	var label: Label = main.find_child("PlacementPreviewLabel", true, false) as Label
	_check(main.is_processing() and main.placement_preview.get("valid", false)
		and main.placement_preview.get("needs_levelling", false)
		and int(main.placement_preview.get("foundation_work_ticks", 0)) == 64
		and main._placement_canvas.visible and main.terrain_renderer.allow_ground_preparation,
		"Real gentle-slope hover must visibly offer the complete 64-tick foundation", failures)
	_check(label != null and label.text.contains("Stavitel místo srovná")
		and main.world.to_data() == before["save"] and Fixture._state(main.world) == before,
		"Preview must explain Builder preparation without changing terrain, tasks, stock or events", failures)
	# 2. Actual placement creates short stakes following each uneven ground tile.
	FootprintView._click(viewport, POINTER)
	await FootprintView._settle(host)
	var id: int = main.world.building_id_at(Fixture.SITE)
	if id == 0:
		failures.append("An actual click on a preparable slope must create a construction site")
		viewport.free()
		return failures
	var building: Dictionary = main.world.buildings[id]
	var shape: Dictionary = main.building_geometry(building)
	_check(shape["earthwork"] and shape["roofs"].is_empty() and shape["walls"].is_empty()
		and shape["foundations"].size() == 6 and not Shape.earthwork_segments(shape).is_empty(),
		"Uneven sites must draw actual low surveying geometry, without walls or phantom roofs", failures)
	for index: int in range(shape["cells"].size()):
		_check(shape["foundations"][index] == main.terrain_renderer.cell_polygon(shape["cells"][index]),
			"Every preparation tile must follow the authoritative current terrain mesh", failures)
	# 3. Ground selection uses the same full-mask geometry that is rendered.
	main._set_build_mode("")
	for cell: Vector2i in main.world.building_cells(building):
		FootprintView._center_point(main, viewport, main.terrain_renderer.cell_center(cell), POINTER)
		await FootprintView._settle(host)
		FootprintView._click(viewport, POINTER)
		_check(main.selected_cell == Fixture.SITE, "Each visible foundation tile must inspect its single construction site", failures)
	_check(main.hud._selected_production_text(main.world, Fixture.SITE).contains("Příprava terénu"),
		"Inspector must distinguish waiting for ground preparation from waiting for materials", failures)
	# 4. Real work changes ground and the shovel cue; paused frames remain read-only.
	var builder_id: int = main.world.spawn_worker(Vector2i(12, 11), "builder")
	var reached: bool = Fixture._until(main.world, func() -> bool: return int(building["foundation_work_remaining"]) == 40, 800)
	_check(reached, "View fixture must reach actual partially completed Builder work", failures)
	var builder: Dictionary = main.world.workers[builder_id]
	var feet: Vector2 = main.terrain_renderer.cell_center(builder["position"])
	shape = main.building_geometry(building)
	_check(float(shape["earthwork_progress"]) > 0.3 and float(shape["earthwork_progress"]) < 0.5
		and main.worker_earthwork_presentation(builder, feet).get("visible", false),
		"Worked terrain must expose correct ground-preparation progress and an active shovel", failures)
	var cue: Dictionary = main.worker_earthwork_presentation(builder, feet)
	before = Fixture._state(main.world)
	await FootprintView._settle(host)
	_check(main.worker_earthwork_presentation(builder, feet) == cue and Fixture._state(main.world) == before,
		"Paused real frames must freeze shovel, progress and terrain without synthetic work", failures)
	# 6. Only real completion reveals the normal construction scaffold and materials stage.
	_check(Fixture._until(main.world, func() -> bool: return int(building["foundation_work_remaining"]) == 0, 800),
		"Builder must continue and complete the visible foundations", failures)
	await FootprintView._settle(host)
	shape = main.building_geometry(building)
	_check(not shape["earthwork"] and not shape["roofs"].is_empty()
		and not main.worker_earthwork_presentation(builder, feet).get("visible", false)
		and main.hud._selected_production_text(main.world, Fixture.SITE).contains("Dovezeno:")
		and int(building["construction_remaining"]) > 0,
		"Prepared ground must transition to material delivery and ordinary scaffold, never a free finished building", failures)
	viewport.free()
	return failures

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
