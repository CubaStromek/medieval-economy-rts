extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const Sprites = preload("res://scripts/view/sawmill_sprite_library.gd")
const TEST_COUNT: int = 8
const SITE := Vector2i(10, 8)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library := Sprites.new()
	_test_actual_import_and_cache(library, failures)
	_test_invalid_metadata(failures)
	_test_unfinished_legacy_and_missing(library, failures)
	_test_footprint_and_registration(library, failures)
	_test_real_alpha_selection(failures)
	_test_real_paid_construction(library, failures)
	_test_fog_and_immutable_save(failures)
	await _test_native_depth_lighting_and_pause(host, failures)
	return failures


static func _fixture(height: int = 0) -> Dictionary:
	var world := World.new(Vector2i(24, 18))
	world.tick = 1750
	if height > 0:
		for y: int in range(world.grid.size.y + 1):
			for x: int in range(world.grid.size.x + 1):
				world.grid.set_vertex_height(Vector2i(x, y), height)
	var id: int = world.place_building("sawmill", SITE)
	return {"world": world, "id": id, "building": world.buildings[id]}


static func _view(world: World) -> MainView:
	var view := MainView.new()
	view.world = world
	view.terrain_renderer = Terrain.new()
	view.add_child(view.terrain_renderer)
	view.terrain_renderer.bind_grid(world.grid)
	return view


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_actual_import_and_cache(library: Sprites, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(library.supports(f["building"]), "The actual completed current sawmill must load its own measured RGBA asset", failures)
	if not library.supports(f["building"]):
		return
	var world: World = f["world"]
	var door := Vector2(400, 300)
	var shown: Dictionary = library.presentation_for(f["building"], world.catalog.building("sawmill"), door)
	var another := Sprites.new()
	var shared: Dictionary = another.presentation_for(f["building"], world.catalog.building("sawmill"), door)
	_check(shown.get("texture") is Texture2D and shown.get("hit_mask") is BitMap
		and shown.get("texture") == shared.get("texture") and shown.get("hit_mask") == shared.get("hit_mask"),
		"Completed sawmills must share the genuinely imported texture and matching alpha mask", failures)
	var image: Image = (shown["texture"] as Texture2D).get_image()
	_check(image.has_mipmaps() and (shown["hit_mask"] as BitMap).get_true_bit_count() > 100,
		"The actual sawmill must retain mipmaps and substantial opaque artwork after import", failures)


static func _test_invalid_metadata(failures: Array[String]) -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(Sprites.MANIFEST_PATH))
	if not value is Dictionary:
		failures.append("Metadata regression requires the delivered sawmill manifest")
		return
	var data: Dictionary = value
	_check(Sprites.validate_manifest(data), "The delivered manifest must satisfy the production schema", failures)
	var next_revision: Dictionary = data.duplicate(true)
	next_revision["asset_version"] = "v2"
	_check(Sprites.validate_manifest(next_revision), "The known v2 artwork revision must retain the same registration schema without changing footprint versions", failures)
	for sample: Array in [["schema_version", 2], ["building_id", "lumber_hut"], ["asset_version", "v999"],
		["canvas", [1024, 0]], ["canvas", [1024.5, 1024]], ["door_threshold", [1, INF]],
		["sort_foot", [NAN, 1]], ["label_anchor", ["4", 12]], ["source_to_world", 0],
		["source_to_world", INF], ["source_to_world", true], ["alpha_bbox", [0, 0, 999999, 4]],
		["finished_image", "../foreign.png"], ["finished_rgba_sha256", "not-a-sha"], ["life", []]]:
		var malformed: Dictionary = data.duplicate(true)
		malformed[sample[0]] = sample[1]
		_check(not Sprites.validate_manifest(malformed), "Malformed %s must be rejected before reading resources" % sample[0], failures)


static func _test_unfinished_legacy_and_missing(library: Sprites, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var building: Dictionary = f["building"].duplicate(true)
	for sample: Array in [["foundation_work_remaining", 1], ["construction_remaining", 1],
		["footprint_version", 0], ["footprint_version", 2], ["type", "lumber_hut"]]:
		var state: Dictionary = building.duplicate(true)
		state[sample[0]] = sample[1]
		_check(not library.supports(state) and library.presentation_for(state, world.catalog.building("sawmill"), Vector2.ZERO).is_empty()
			and library.visual_ground_position(state, world.building_door_cell(building), 40) == Vector2(SITE),
			"%s=%s must retain existing placeholder, earthwork or construction geometry" % sample, failures)
	var missing := Sprites.new(Sprites.MANIFEST_PATH.get_base_dir().path_join("not-delivered.json"))
	_check(not missing.supports(building) and missing.presentation_for(building, {}, Vector2.ZERO).is_empty(),
		"A missing sawmill resource must gracefully retain the existing renderer", failures)


static func _test_footprint_and_registration(library: Sprites, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var building: Dictionary = f["building"]
	_check(world.building_cells(building).size() == 8 and world.building_door_cell(building) == SITE + Vector2i(1, 0)
		and building["entrance"] == SITE + Vector2i(1, 1) and world.building_id_at(SITE + Vector2i(1, 1)) == 0,
		"The real 4x2 sawmill mask must retain eight occupied cells and the free south doorway approach", failures)
	var view: MainView = _view(world)
	var flat: Dictionary = view.building_sprite_presentation(building)
	if flat.is_empty():
		failures.append("Registration checks need the loaded sawmill bitmap")
		view.free()
		return
	var shape: Dictionary = view.building_geometry(building)
	_check(((flat["rect"] as Rect2).position + (flat["door_threshold"] as Vector2) * float(flat["source_to_world"])).is_equal_approx(shape["door"]),
		"The measured image threshold must exactly register to the physical terrain threshold", failures)
	var raised: Dictionary = _fixture(3)
	var high: MainView = _view(raised["world"])
	var high_sprite: Dictionary = high.building_sprite_presentation(raised["building"])
	_check(not high_sprite.is_empty() and (high_sprite["rect"] as Rect2).position == (flat["rect"] as Rect2).position - Vector2(0, 24),
		"Three terrain levels must lift the actual bitmap exactly 24 world pixels without altering scale", failures)
	var depth: Vector2 = library.visual_ground_position(building, shape["door_cell"], 40)
	_check(depth == library.visual_ground_position(raised["building"], high.building_geometry(raised["building"])["door_cell"], 40),
		"Visual depth must use ground ordering independent from true terrain projection height", failures)
	view.free()
	high.free()


static func _test_real_alpha_selection(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var view: MainView = _view(f["world"])
	var sprite: Dictionary = view.building_sprite_presentation(f["building"])
	if sprite.is_empty():
		failures.append("Alpha selection must test the actual sawmill bitmap")
		view.free()
		return
	var shape: Dictionary = view.building_geometry(f["building"])
	var opaque: Vector2 = _probe(sprite, shape, true)
	var clear: Vector2 = _probe(sprite, shape, false)
	_check(opaque.is_finite() and view._building_id_at_visual_position(opaque) == int(f["id"]),
		"A genuinely opaque sawmill pixel outside occupied ground must be pickable through the real view", failures)
	_check(clear.is_finite() and view._building_id_at_visual_position(clear) == 0,
		"A transparent sawmill canvas pixel outside occupied ground must remain click-through", failures)
	for cell: Vector2i in (f["world"] as World).building_cells(f["building"]):
		_check(view._building_id_at_visual_position(view.terrain_renderer.cell_center(cell)) == int(f["id"]),
			"Every real occupied sawmill cell must remain selectable, including the open work bay", failures)
	view.free()


static func _test_real_paid_construction(library: Sprites, failures: Array[String]) -> void:
	var world := World.new(Vector2i(24, 18))
	world.tick = 1750
	var warehouse: int = world.place_building("warehouse", Vector2i(2, 5))
	world.buildings[warehouse]["storage"]["plank"] = 20
	world.buildings[warehouse]["storage"]["stone"] = 20
	world.economy_enabled = true
	var id: int = world.place_building("sawmill", SITE)
	var building: Dictionary = world.buildings[id]
	var cost: Dictionary = world.construction_cost(building).duplicate(true)
	var work: int = int(world.catalog.building("sawmill")["construction_ticks"])
	world.spawn_worker(Vector2i(6, 10), "carrier")
	world.spawn_worker(Vector2i(7, 11), "carrier")
	world.spawn_worker(Vector2i(12, 11), "builder")
	var worked: int = 0
	var previous: int = int(building["construction_remaining"])
	for _tick: int in range(2400):
		if world.is_building_complete(building):
			break
		_check(not library.supports(building), "Actual paid construction must never show the finished sawmill early", failures)
		world.step_tick()
		worked += previous - int(building["construction_remaining"])
		previous = int(building["construction_remaining"])
	_check(worked == work and world.is_building_complete(building) and library.supports(building),
		"Only completion by real carriers and Builder work may activate the finished sawmill bitmap", failures)
	_check(world.stored_amount("plank") == 20 - int(cost.get("plank", 0)) and world.stored_amount("stone") == 20 - int(cost.get("stone", 0)),
		"Artwork must preserve the real construction price and physical resource delivery", failures)
	var restored := World.new()
	var saved: Dictionary = world.to_data()
	_check(restored.from_data(JSON.parse_string(JSON.stringify(saved))) and restored.to_data() == saved
		and library.supports(restored.buildings.get(id, {})), "The actual completed sawmill must restore from unchanged game save data", failures)


static func _test_fog_and_immutable_save(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var view: MainView = _view(world)
	var saved: Dictionary = world.to_data()
	view.building_sprite_presentation(f["building"])
	view.building_life_presentation(f["building"])
	view._world_draw_entries()
	_check(world.to_data() == saved, "Sprite registration, life and draw ordering must be read-only over saved state", failures)
	world.fog.enabled = true
	f["building"]["owner_id"] = 2
	world.update_visibility()
	var found: bool = false
	for entry: Dictionary in view._world_draw_entries():
		found = found or (entry["kind"] == "building" and entry["id"] == f["id"])
	_check(not found and not bool(view.building_life_presentation(f["building"]).get("known", false)),
		"Unknown foreign sawmills must be absent from normal drawing and must disclose no resident state", failures)
	view.free()


static func _test_native_depth_lighting_and_pause(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var f: Dictionary = _fixture()
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	main.world = f["world"]
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.hud.visible = false
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2.ONE * 2.4
	main.camera.position = main.building_geometry(f["building"])["door"] - Vector2(0, 60)
	main.camera.force_update_scroll()
	var saved: Dictionary = main.world.to_data()
	main.accumulator = MainView.FIXED_TICK_SECONDS * 0.25
	var before: Dictionary = main.building_life_presentation(f["building"])
	for _frame: int in range(4):
		main._process(0.033)
	_check(main.world.to_data() == saved and main.building_life_presentation(f["building"]) == before,
		"Paused normal scene must preserve saved ticks, geometry and dynamic sawmill time", failures)
	if DisplayServer.get_name() == "headless":
		viewport.free()
		return
	var sprite: Dictionary = main.building_sprite_presentation(f["building"])
	if sprite.is_empty():
		failures.append("Native depth checks require a loaded positive-control sawmill texture")
		viewport.free()
		return
	var source: Image = (sprite["texture"] as Texture2D).get_image()
	var points: Array[Vector2] = _lower_opaque_samples(sprite, source)
	_check(points.size() >= 3, "Native pixel checks must find multiple opaque building contacts", failures)
	for tick: int in [1750, 4750]:
		main.world.tick = tick
		await _settle(host, main)
		var actual: Image = viewport.get_texture().get_image()
		var reference := Node2D.new()
		reference.z_index = 2000
		main.add_child(reference)
		reference.draw.connect(func() -> void: reference.draw_texture_rect(sprite["texture"], sprite["rect"], false))
		reference.queue_redraw()
		await _settle(host, main)
		var expected: Image = viewport.get_texture().get_image()
		for point: Vector2 in points:
			var screen := Vector2i(main.get_global_transform_with_canvas() * point)
			var a: Color = actual.get_pixelv(screen)
			var b: Color = expected.get_pixelv(screen)
			_check(absf(a.r - b.r) < 0.025 and absf(a.g - b.g) < 0.025 and absf(a.b - b.b) < 0.025,
				"Actual sawmill lower pixels must equal an independently unobstructed bitmap under day/night tint (tick %d)" % tick, failures)
			_check(main._building_id_at_visual_position(point) == int(f["id"]),
				"The exact native lower pixel must remain selectable under the same terrain ordering", failures)
		reference.free()
	viewport.free()


static func _settle(host: Node, main: MainView) -> void:
	for _frame: int in range(3):
		main.queue_redraw()
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw


static func _probe(sprite: Dictionary, shape: Dictionary, opaque: bool) -> Vector2:
	var image: Image = (sprite["texture"] as Texture2D).get_image()
	var scale: float = float(sprite["source_to_world"])
	var rect: Rect2 = sprite["rect"]
	for y: int in range(6, image.get_height() - 6, 6):
		for x: int in range(6, image.get_width() - 6, 6):
			var alpha: float = image.get_pixel(x, y).a
			if (opaque and alpha < 0.99) or (not opaque and alpha > 0.01):
				continue
			var point: Vector2 = rect.position + Vector2(x + 0.5, y + 0.5) * scale
			var occupied: bool = false
			for polygon: PackedVector2Array in shape["foundations"]:
				occupied = occupied or Geometry2D.is_point_in_polygon(point, polygon)
			if not occupied:
				return point
	return Vector2.INF


static func _lower_opaque_samples(sprite: Dictionary, image: Image) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var source_scale: float = float(sprite["source_to_world"])
	for band: int in range(4):
		var found: bool = false
		for y: int in range(image.get_height() - 8, image.get_height() / 2, -4):
			if found:
				break
			for x: int in range(maxi(8, band * image.get_width() / 4), mini(image.get_width() - 8, (band + 1) * image.get_width() / 4), 4):
				var solid: bool = true
				for offset: Vector2i in [Vector2i.ZERO, Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
					solid = solid and image.get_pixelv(Vector2i(x, y) + offset).a >= 0.99
				if solid:
					result.append((sprite["rect"] as Rect2).position + Vector2(x + 0.5, y + 0.5) * source_scale)
					found = true
					break
	return result
