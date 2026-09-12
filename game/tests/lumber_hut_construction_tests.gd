extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const Sprites = preload("res://scripts/view/lumber_hut_sprite_library.gd")
const Foundations = preload("res://tests/foundation_tests.gd")
const Legacy = preload("res://tests/legacy_world_fixture.gd")
const TEST_COUNT: int = 12
const SITE := Vector2i(10, 8)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library := Sprites.new()
	_test_independent_phase_boundaries(library, failures)
	var saves: Dictionary = _test_real_builder_visits_every_step(library, failures)
	_test_stopped_work_and_ground_preparation(library, failures)
	_test_saved_stages(library, saves, failures)
	_test_real_raster_stages(library, failures)
	_test_legacy_and_other_buildings(library, failures)
	_test_actual_alpha_selection(failures)
	_test_fog_and_private_state(failures)
	await _test_paused_scene_and_lighting(host, failures) # Cases 9 and 10.
	await _test_lower_sprite_depth_and_native_pixels(host, failures) # Cases 11 and 12.
	return failures


static func _site_world(supplied: bool = false, footprint_version: int = 2) -> Dictionary:
	var world := World.new(Vector2i(24, 18))
	world.default_footprint_version = footprint_version
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 5))
	if supplied:
		world.buildings[warehouse]["storage"]["plank"] = 20
		world.buildings[warehouse]["storage"]["stone"] = 20
	world.economy_enabled = true
	var id: int = world.place_building("lumber_hut", SITE)
	return {"world": world, "id": id, "warehouse": warehouse}


static func _test_independent_phase_boundaries(library: Sprites, failures: Array[String]) -> void:
	var fixture: Dictionary = _site_world()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	var definition: Dictionary = world.catalog.building("lumber_hut")
	var cost: Dictionary = world.construction_cost(building)
	_check(int(definition["construction_ticks"]) == 120 and cost.size() == 2 and int(cost.get("plank", 0)) == 3 and int(cost.get("stone", 0)) == 2
		and world.building_cells(building).size() == 9 and int(building["footprint_version"]) == 2,
		"The expanded hut must retain the real 120-work-tick price with its new nine-cell footprint", failures)
	# Independent expected boundary samples: 72 work ticks of timber, then 48
	# of finishing. These are authored expected values, not the production formula.
	var expected: Array[Array] = [
		[0, 0, 0, 0], [1, 1, 1, 0], [6, 1, 1, 0], [7, 2, 2, 0],
		[66, 11, 11, 0], [67, 12, 12, 0], [72, 12, 12, 0],
		[73, 13, 12, 1], [74, 13, 12, 1], [75, 14, 12, 2],
		[88, 19, 12, 7], [89, 20, 12, 8], [104, 26, 12, 14],
		[118, 33, 12, 21], [119, 33, 12, 21], [120, 33, 12, 21],
	]
	for sample: Array in expected:
		building["construction_remaining"] = 120 - int(sample[0])
		var state: Dictionary = library.state_for(building, definition)
		_check(int(state.get("step", -1)) == int(sample[1]) and int(state.get("wood_step", -1)) == int(sample[2])
			and int(state.get("finishing_step", -1)) == int(sample[3]),
			"Authored timber/finishing boundaries must hold after %d actual work ticks" % int(sample[0]), failures)
		if int(sample[0]) < 120:
			_check(not world.is_building_complete(building), "A visually final stage must not complete the actual building early", failures)
	_check(String(library.state_for(building, definition).get("phase", "")) == "complete",
		"Only zero remaining construction work may describe the complete building", failures)


static func _test_real_builder_visits_every_step(library: Sprites, failures: Array[String]) -> Dictionary:
	var fixture: Dictionary = _site_world(true)
	var world: World = fixture["world"]
	var id: int = fixture["id"]
	var building: Dictionary = world.buildings[id]
	world.spawn_worker(Vector2i(5, 10), "carrier")
	world.spawn_worker(Vector2i(7, 11), "carrier")
	var builder_id: int = world.spawn_worker(Vector2i(12, 11), "builder")
	var definition: Dictionary = world.catalog.building("lumber_hut")
	var previous_work: int = 120
	var previous_step: int = 0
	var effective_work: int = 0
	var saves: Dictionary = {0: world.to_data().duplicate(true)}
	for _tick: int in range(2400):
		if world.is_building_complete(building):
			break
		var worker_before: Dictionary = world.workers[builder_id].duplicate(true)
		world.step_tick()
		var remaining: int = building["construction_remaining"]
		var state: Dictionary = library.state_for(building, definition)
		var stage: int = int(state.get("step", -1))
		_check(stage >= previous_step and stage <= previous_step + 1,
			"The real builder must visit each graphical stage in order without skipping one", failures)
		if remaining != previous_work:
			effective_work += 1
			_check(remaining == previous_work - 1 and worker_before["action"] == "build_site" and worker_before["state"] == "working"
				and int(building["construction_delivered"].get("plank", 0)) == 3 and int(building["construction_delivered"].get("stone", 0)) == 2,
				"Painted construction must be driven by real assigned Builder work after physical plank and stone delivery", failures)
		else:
			_check(stage == previous_step, "Travelling and delivering goods must never advance the painted structure", failures)
		if not saves.has(stage):
			saves[stage] = world.to_data().duplicate(true)
		previous_work = remaining
		previous_step = stage
	_check(world.is_building_complete(building) and effective_work == 120 and saves.size() == 34,
		"A production construction must finish in the same 120 effective work ticks and visit ground plus all 33 stages", failures)
	_check(world.stored_amount("plank") == 17 and world.stored_amount("stone") == 18
		and world.building_cells(building).size() == 9 and building["entrance"] == SITE + Vector2i(3, 0),
		"Finishing graphics must preserve paid materials, all occupied cells and the right-hand entrance", failures)
	if world.is_building_complete(building):
		saves[33] = world.to_data().duplicate(true)
	return saves


static func _test_stopped_work_and_ground_preparation(library: Sprites, failures: Array[String]) -> void:
	var fixture: Dictionary = _site_world(true)
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	world.spawn_worker(Vector2i(5, 10), "carrier")
	Foundations._advance(world, 250)
	_check(int(building["construction_remaining"]) == 120
		and int(library.state_for(building, world.catalog.building("lumber_hut"))["step"]) == 0,
		"Delivered materials without a Builder must leave the actual graphic at bare ground", failures)
	var foundation_fixture: Dictionary = Foundations._fixture(false)
	var slope: World = foundation_fixture["world"]
	var id: int = slope.place_building("lumber_hut", SITE)
	var site: Dictionary = slope.buildings[id]
	var definition: Dictionary = slope.catalog.building("lumber_hut")
	slope.spawn_worker(Vector2i(12, 11), "builder")
	var observed_work: bool = false
	for _tick: int in range(1000):
		if int(site["foundation_work_remaining"]) == 0:
			break
		_check(library.presentation_for(site, definition, Vector2.ZERO).is_empty()
			and int(library.state_for(site, definition)["step"]) == 0,
			"Every real earthwork state must retain stakes and terrain without painted walls or roof", failures)
		slope.step_tick()
		observed_work = observed_work or int(site["foundation_work_remaining"]) < 64
	_check(observed_work and int(site["foundation_work_remaining"]) == 0 and int(site["construction_remaining"]) == 120
		and int(library.state_for(site, definition)["step"]) == 0,
		"Finishing real ground preparation must still wait for construction materials before revealing structure", failures)


static func _test_saved_stages(library: Sprites, saves: Dictionary, failures: Array[String]) -> void:
	for stage: int in saves:
		var restored := World.new()
		var json_data: Dictionary = JSON.parse_string(JSON.stringify(saves[stage])) as Dictionary
		if not restored.from_data(json_data):
			failures.append("The existing save format must load actual construction stage %d" % stage)
			continue
		var id: int = restored.building_id_at(SITE)
		_check(id != 0 and restored.to_data() == saves[stage],
			"Stage %d JSON reload must preserve every economy, terrain, worker and footprint value" % stage, failures)
		if id != 0:
			_check(int(library.state_for(restored.buildings[id], restored.catalog.building("lumber_hut"))["step"]) == stage,
				"Stage %d must reconstruct from existing saved work without a new frame/save field" % stage, failures)
		if stage in [1, 12, 13, 32]:
			var building: Dictionary = restored.buildings[id]
			var work: int = int(building["construction_remaining"])
			_check(Foundations._until(restored, func() -> bool: return int(building["construction_remaining"]) < work, 100)
				and int(building["construction_remaining"]) == work - 1,
				"Loading stage %d must resume real Builder work without replaying payment or jumping progress" % stage, failures)


static func _test_real_raster_stages(library: Sprites, failures: Array[String]) -> void:
	var fixture: Dictionary = _site_world()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	var definition: Dictionary = world.catalog.building("lumber_hut")
	var seen: Dictionary = {}
	var signatures: Dictionary = {}
	var registration := Rect2()
	var door := Vector2(412.5, 325.75)
	_check(library.supports(building), "The real current-footprint lumber hut must load its own production artwork", failures)
	for done: int in range(1, 121):
		building["construction_remaining"] = 120 - done
		var state: Dictionary = library.state_for(building, definition)
		var step: int = state["step"]
		if seen.has(step):
			continue
		seen[step] = true
		var before: Dictionary = world.to_data()
		var presentation: Dictionary = library.presentation_for(building, definition, door)
		_check(not presentation.is_empty() and presentation.get("texture") is Texture2D,
			"Construction step %d must have a real texture, not metadata alone" % step, failures)
		if presentation.is_empty() or not presentation.get("texture") is Texture2D:
			continue
		var texture: Texture2D = presentation["texture"]
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			failures.append("Construction step %d must contain readable raster pixels" % step)
			continue
		if image.is_compressed():
			image.decompress()
		var visible: int = 0
		var clear: int = 0
		for y: int in range(0, image.get_height(), 3):
			for x: int in range(0, image.get_width(), 3):
				var alpha: float = image.get_pixel(x, y).a
				visible += 1 if alpha >= 0.5 else 0
				clear += 1 if alpha <= 0.01 else 0
		_check(visible > 10 and clear > 100, "Step %d needs visible building pieces and genuine transparent surroundings" % step, failures)
		var signature: String = str(hash(image.get_data()))
		_check(not signatures.has(signature), "Each of the 33 reveal steps must actually change the rendered raster (step %d)" % step, failures)
		signatures[signature] = step
		var rect: Rect2 = presentation["rect"]
		if registration == Rect2():
			registration = rect
		_check(rect == registration and world.to_data() == before,
			"All construction layers must keep exactly one immutable door registration and canvas size", failures)
		var source_scale: float = float(presentation["source_to_world"])
		_check((rect.position + Vector2(presentation["door_threshold"]) * source_scale).is_equal_approx(door),
			"Step %d must anchor its measured source threshold to the actual terrain door" % step, failures)
	_check(seen.size() == 33 and signatures.size() == 33, "The production images must provide all twelve timber and twenty-one finishing changes", failures)


static func _test_legacy_and_other_buildings(library: Sprites, failures: Array[String]) -> void:
	var legacy: World = Legacy.create(Vector2i(24, 18))
	var id: int = legacy.place_building("lumber_hut", SITE)
	var view: MainView = _bare_view(legacy)
	var building: Dictionary = legacy.buildings[id]
	_check(not library.supports(building) and view.building_sprite_presentation(building).is_empty()
		and legacy.building_cells(building).size() == 1,
		"Compact historical huts must retain their original footprint and vector fallback", failures)
	var center: Vector2 = view.terrain_renderer.cell_center(SITE)
	_check(view._building_id_at_visual_position(center + Vector2(0, -29)) == id,
		"A compact historical hut must retain its actual original roof selection", failures)
	legacy.default_footprint_version = 1
	var other: int = legacy.place_building("forester_hut", Vector2i(16, 8))
	_check(other != 0 and not library.supports(legacy.buildings[other])
		and view.building_sprite_presentation(legacy.buildings[other]).is_empty(),
		"The lumber pilot must not replace the unproduced forester sibling or other catalog artwork", failures)
	view.free()


static func _test_actual_alpha_selection(failures: Array[String]) -> void:
	var fixture: Dictionary = _site_world()
	var world: World = fixture["world"]
	var id: int = fixture["id"]
	var building: Dictionary = world.buildings[id]
	building["construction_remaining"] = 0
	var view: MainView = _bare_view(world)
	var presentation: Dictionary = view.building_sprite_presentation(building)
	if presentation.is_empty():
		failures.append("Actual completed-hut selection requires its loaded bitmap")
		view.free()
		return
	var roof: Vector2 = _source_probe(presentation, view.building_geometry(building), true)
	var clear: Vector2 = _source_probe(presentation, view.building_geometry(building), false)
	_check(roof.is_finite() and clear.is_finite(), "Selection tests must find real opaque roof and transparent padding outside the ground footprint", failures)
	if roof.is_finite() and clear.is_finite():
		_check(view._building_id_at_visual_position(roof) == id and view._building_id_at_visual_position(clear) == 0,
			"The actual scene must select the painted roof and pass through fully transparent bitmap padding", failures)
		for cell: Vector2i in world.building_cells(building):
			_check(view._building_id_at_visual_position(view.terrain_renderer.cell_center(cell)) == id,
				"Every occupied ground tile must retain complete-building selection, including the empty work bay", failures)
		building["construction_remaining"] = 120
		_check(view._building_id_at_visual_position(roof) == 0,
			"The future completed roof must not intercept clicks while the site is still bare ground", failures)
		for cell: Vector2i in world.building_cells(building):
			_check(view._building_id_at_visual_position(view.terrain_renderer.cell_center(cell)) == id,
				"Every reserved construction tile must remain selectable before any walls exist", failures)
	view.free()


static func _test_fog_and_private_state(failures: Array[String]) -> void:
	var world := World.new(Vector2i(30, 20))
	var id: int = world.place_building("lumber_hut", Vector2i(22, 14), 2)
	var building: Dictionary = world.buildings[id]
	world.spawn_worker(Vector2i(2, 2), "carrier")
	world.enable_fog(1)
	var view: MainView = _bare_view(world)
	_check(not _has_building_entry(view, id), "Unexplored foreign huts must never add a sprite to the real painter list", failures)
	var shape: Dictionary = view.building_geometry(building)
	_check(view._building_id_at_visual_position(shape["door"] - Vector2(0, 20)) == 0,
		"New art must not turn unknown foreign structures into selectable targets", failures)
	world.fog.restore_explored(world.building_cells(building))
	_check(_has_building_entry(view, id), "Remembered foreign buildings retain their static landmark under the existing fog policy", failures)
	var empty: Dictionary = view.building_sprite_presentation(building)
	building["outputs"]["log"] = 6
	building["enabled"] = false
	var occupied: Dictionary = view.building_sprite_presentation(building)
	_check(not empty.is_empty() and empty.get("texture") == occupied.get("texture") and empty.get("rect") == occupied.get("rect"),
		"Static construction artwork must not leak foreign output amounts or pretend occupancy/work are baked state layers", failures)
	view.free()


static func _test_paused_scene_and_lighting(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	var fixture: Dictionary = _site_world()
	main.world = fixture["world"]
	var building: Dictionary = main.world.buildings[fixture["id"]]
	building["construction_remaining"] = 35
	main.simulation_speed = 0.0
	main.accumulator = 0.0
	main.terrain_renderer.bind_grid(main.world.grid)
	main._center_camera()
	main.hud.visible = false
	main.world.tick = 1750
	main._update_ui()
	await _settle(host, main)
	var state: Dictionary = Foundations._state(main.world)
	var presentation: Dictionary = main.building_sprite_presentation(building)
	var mesh_count: int = main.terrain_renderer.base_cell_build_count
	var draws: Array[int] = [0]
	main.draw.connect(func() -> void: draws[0] += 1)
	for zoom: float in [0.75, 1.0, 2.4]:
		main.camera.zoom = Vector2.ONE * zoom
		for _frame: int in range(3):
			main._process(1.0 / 30.0)
			await _settle(host, main)
		_check(main.building_sprite_presentation(building) == presentation,
			"Paused frames and camera zoom must never animate, resize in world units or shift construction anchors", failures)
	_check(draws[0] > 0 and Foundations._state(main.world) == state and main.terrain_renderer.base_cell_build_count == mesh_count,
		"Actual paused scene drawing must run while preserving saved/transient state and retained terrain", failures)
	main.camera.zoom = Vector2.ONE
	main.camera.position = main.building_geometry(building)["door"] - Vector2(0, 50)
	main.camera.force_update_scroll()
	var colors: Array[Color] = []
	var native_luminance: Array[float] = []
	for tick: int in [1750, 3375, 4750]:
		main.world.tick = tick
		var before: Dictionary = main.world.to_data()
		main._update_ui()
		await _settle(host, main)
		colors.append(main.modulate)
		_check(main.modulate == main.solar_state["ambient"] and main.building_sprite_presentation(building) == presentation
			and main.world.to_data() == before,
			"Day, dusk and night must tint the same actual construction state without changing simulation work", failures)
		if DisplayServer.get_name() != "headless" and not presentation.is_empty():
			await RenderingServer.frame_post_draw
			var probe: Vector2 = _source_probe(presentation, main.building_geometry(building), true)
			var screen: Vector2 = main.get_global_transform_with_canvas() * probe
			var pixels: Image = viewport.get_texture().get_image()
			if probe.is_finite() and Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(screen):
				native_luminance.append(pixels.get_pixelv(Vector2i(screen)).get_luminance())
	_check(colors[0].get_luminance() > colors[2].get_luminance() + 0.2 and colors[1] != colors[0],
		"The integrated painted structure must share distinguishable existing day/dusk/night map lighting", failures)
	if DisplayServer.get_name() != "headless":
		_check(native_luminance.size() == 3 and native_luminance[0] > native_luminance[2] + 0.02,
			"Native rendered construction pixels must actually darken at night, not merely expose lighting metadata", failures)
	viewport.free()


static func _test_lower_sprite_depth_and_native_pixels(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	# Retain this historical regression: v1 art extends below its occupied row.
	# New v2 contact, row and native-frame checks live in the footprint suite/QA.
	var fixture: Dictionary = _site_world(false, 1)
	main.world = fixture["world"]
	var id: int = fixture["id"]
	var building: Dictionary = main.world.buildings[id]
	building["construction_remaining"] = 0
	main.simulation_speed = 0.0
	main.accumulator = 0.0
	main.terrain_renderer.bind_grid(main.world.grid)
	main.hud.visible = false
	main.world.tick = 1750
	main.camera.zoom = Vector2.ONE * 2.0
	main.camera.position = main.building_geometry(building)["door"] - Vector2(35, 10)
	main.camera.force_update_scroll()
	main._update_ui()
	await _settle(host, main)
	var complete: Dictionary = main.building_sprite_presentation(building)
	var shape: Dictionary = main.building_geometry(building)
	var lower: Vector2 = _lower_source_probe(complete, shape)
	_check(lower.is_finite(), "Depth regression needs an actual opaque front pixel extending below the footprint's southern terrain row", failures)
	if not lower.is_finite():
		viewport.free()
		return
	_check(main._building_id_at_visual_position(lower) == id
		and main._building_id_at_visual_position(shape["door"] - Vector2(0, 2)) == id,
		"Actual visible lower-front pixels and the unchanged door must both remain pickable on flat terrain", failures)
	var original_rect: Rect2 = complete["rect"]
	var original_door: Vector2 = shape["door"]
	var stable_row: int = _row_containing(main, id)
	_check(stable_row >= 0, "The actual scene must put the painted hut into a real retained object row", failures)
	var seen_steps: Dictionary = {}
	for remaining: int in range(120, -1, -1):
		building["construction_remaining"] = remaining
		var step: int = int(Sprites.state_for(building, main.world.catalog.building("lumber_hut"))["step"])
		if seen_steps.has(step) and remaining != 0:
			continue
		seen_steps[step] = true
		await _settle(host, main)
		var frame: Dictionary = main.building_sprite_presentation(building)
		_check(frame.get("rect") == original_rect and main.building_geometry(building)["door"] == original_door
			and _row_containing(main, id) == stable_row,
			"Growing timber, roof and final details must not move the bitmap, doorway or its terrain painter row", failures)
	_check(seen_steps.size() == 34, "Stable depth must be sampled at bare ground and all33 actual construction stages", failures)
	var before: Dictionary = main.world.to_data()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(before)) as Dictionary
	var raised := World.new()
	raised.default_footprint_version = 1
	# A separate authoring world permits a genuinely flat raised platform. This
	# never edits or migrates the active world's terrain to fix sprite clipping.
	for y: int in range(raised.grid.size.y + 1):
		for x: int in range(raised.grid.size.x + 1):
			raised.grid.set_vertex_height(Vector2i(x, y), 3)
	var raised_id: int = raised.place_building("lumber_hut", SITE)
	var raised_view: MainView = _bare_view(raised)
	if raised_id != 0:
		var raised_sprite: Dictionary = raised_view.building_sprite_presentation(raised.buildings[raised_id])
		_check((raised_sprite.get("rect", Rect2()) as Rect2).position.is_equal_approx(original_rect.position - Vector2(0, 24))
			and raised_view.building_geometry(raised.buildings[raised_id])["door"] == original_door - Vector2(0, 24),
			"Three real terrain levels must move the complete house and doorway together by exactly24 world pixels", failures)
		_check(raised_view._building_id_at_visual_position(lower - Vector2(0, 24)) == raised_id,
			"The same lower visible pixel must stay selectable on a real raised flat foundation", failures)
	else:
		failures.append("Depth regression must create a valid hut on its actual raised platform")
	raised_view.free()
	_check(main.world.to_data() == before and int(snapshot["version"]) == World.SAVE_VERSION,
		"Presentation depth checks must not change saved terrain, coordinates, footprint or format", failures)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screen: Vector2 = main.get_global_transform_with_canvas() * lower
		var original: Image = viewport.get_texture().get_image()
		# Independent visual oracle: overdraw the identical texture in the same
		# canvas, lighting and registration, above terrain. A source-opaque pixel
		# must already match this unobstructed reference in the real renderer.
		var reference := Node2D.new()
		reference.z_index = 2000
		main.add_child(reference)
		var texture: Texture2D = complete["texture"]
		reference.draw.connect(func() -> void: reference.draw_texture_rect(texture, original_rect, false))
		reference.queue_redraw()
		await _settle(host, main)
		await RenderingServer.frame_post_draw
		var unobstructed: Image = viewport.get_texture().get_image()
		var pixel := Vector2i(screen)
		var a: Color = original.get_pixelv(pixel)
		var b: Color = unobstructed.get_pixelv(pixel)
		_check(absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02,
			"Native lower-front building pixels must equal an unobstructed sprite reference instead of being repainted by a later grass row", failures)
		reference.free()
	viewport.free()


static func _row_containing(main: MainView, id: int) -> int:
	for row: int in main._row_entries:
		for entry: Dictionary in main._row_entries[row]:
			if entry["kind"] == "building" and int(entry["id"]) == id:
				return row
	return -1


static func _lower_source_probe(presentation: Dictionary, shape: Dictionary) -> Vector2:
	if presentation.is_empty():
		return Vector2.INF
	var texture: Texture2D = presentation["texture"]
	var source: Image = texture.get_image()
	if source.is_compressed():
		source.decompress()
	var rect: Rect2 = presentation["rect"]
	var scale: Vector2 = rect.size / Vector2(source.get_size())
	var door: Vector2 = shape["door"]
	for y: int in range(source.get_height() - 8, 8, -4):
		for x: int in range(8, source.get_width() - 8, 4):
			var point: Vector2 = rect.position + (Vector2(x, y) + Vector2.ONE * 0.5) * scale
			if point.y < door.y + 20.0:
				continue
			var opaque: bool = true
			for offset: Vector2i in [Vector2i.ZERO, Vector2i(-4, -4), Vector2i(4, -4), Vector2i(4, 4), Vector2i(-4, 4)]:
				opaque = opaque and source.get_pixelv(Vector2i(x, y) + offset).a >= 0.99
			if opaque:
				return point
	return Vector2.INF


static func _bare_view(world: World) -> MainView:
	var view := MainView.new()
	view.world = world
	view.terrain_renderer = Terrain.new()
	view.add_child(view.terrain_renderer)
	view.terrain_renderer.bind_grid(world.grid)
	return view


static func _source_probe(presentation: Dictionary, shape: Dictionary, opaque: bool) -> Vector2:
	if presentation.is_empty():
		return Vector2.INF
	var texture: Texture2D = presentation["texture"]
	var source: Image = texture.get_image()
	if source.is_compressed():
		source.decompress()
	var rect: Rect2 = presentation["rect"]
	var scale: Vector2 = rect.size / Vector2(source.get_size())
	for y: int in range(4, source.get_height() - 4, 4):
		for x: int in range(4, source.get_width() - 4, 4):
			var alpha: float = source.get_pixel(x, y).a
			if (opaque and alpha < 0.95) or (not opaque and alpha > 0.01):
				continue
			var point: Vector2 = rect.position + (Vector2(x, y) + Vector2.ONE * 0.5) * scale
			var on_ground: bool = false
			for polygon: PackedVector2Array in shape["foundations"]:
				on_ground = on_ground or Geometry2D.is_point_in_polygon(point, polygon)
			if not on_ground:
				return point
	return Vector2.INF


static func _has_building_entry(view: MainView, id: int) -> bool:
	for entry: Dictionary in view._world_draw_entries():
		if entry["kind"] == "building" and int(entry["id"]) == id:
			return true
	return false


static func _settle(host: Node, main: MainView) -> void:
	for _frame: int in range(3):
		main.queue_redraw()
		await host.get_tree().process_frame


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
