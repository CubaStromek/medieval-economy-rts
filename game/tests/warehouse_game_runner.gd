extends "res://tests/lumberjack_game_integration_runner.gd"

## Native evidence: first the actual menu -> Relief -> real schedule/save path;
## then clearly separated disposable visual fixtures using the same Main scene.
## No player save slot, source artwork, runtime logic or game catalog is changed.
const WarehouseWorld = preload("res://scripts/simulation/simulation_world.gd")
const WarehouseMain = preload("res://scenes/main.tscn")
const WarehouseSprites = preload("res://scripts/view/warehouse_sprite_library.gd")
const WAREHOUSE_MANIFEST: String = WarehouseSprites.MANIFEST_PATH
var _stage: String = "natural"
var _checks: int = 0
var _fixture_viewport: SubViewport
var _fixture_preview: TextureRect
var _fixture_ids: Dictionary = {}
var _natural_storage_changes: Array[Dictionary] = []
var _probes: Dictionary = {}
var _initial_hashes: Dictionary = {}


func _ready() -> void:
	output_path = ProjectSettings.globalize_path("res://../docs/art/qa/warehouse-v2/runtime")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")
	DirAccess.make_dir_recursive_absolute(output_path)
	for folder: String in ["natural", "fixture", "motion"]:
		DirAccess.make_dir_recursive_absolute(output_path.path_join(folder))
	_mute_music_bus_only()
	get_tree().root.title = "Skladiště · nativní ověření · bez hudby"
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1280, 800)
	if DisplayServer.get_name() == "headless" or not FileAccess.file_exists(WAREHOUSE_MANIFEST):
		_expect(false, "Native renderer and completed production manifest are required")
		_finish()
		return
	_initial_hashes = _asset_hashes()
	await _normal_game()
	if failures.is_empty():
		await _visual_fixtures()
	_finish()


func _normal_game() -> void:
	session = SessionScene.instantiate()
	session.honor_launch_arguments = false
	var temporary_slot: String = OS.get_temp_dir().path_join("warehouse_native_%d" % OS.get_process_id())
	session.save_path = temporary_slot + ".json"
	session.region_save_path = temporary_slot + "_region.json"
	add_child(session)
	await _settle()
	_expect(session.game == null, "Real startup is the main menu")
	await _capture("natural/00-menu", {})
	if not await _press_menu_button("NewGameButton"):
		return
	var picker: OptionButton = session.menu.find_child("MapPicker", true, false) as OptionButton
	_expect(picker != null and picker.item_count > 1, "Real map picker exposes Relief")
	if picker == null:
		return
	picker.select(1)
	picker.item_selected.emit(1)
	await _capture("natural/01-relief-picker", {})
	if not await _press_menu_button("StartMapButton") or session.game == null:
		_expect(false, "Real Start button creates Main")
		return
	game = session.game
	game._set_simulation_speed(0.0)
	game.set_process(false)
	_expect(game.demo_kind == "relief", "Normal game uses authored Relief")
	for building: Dictionary in game.world.buildings.values():
		if building["type"] == "warehouse":
			home_id = int(building["id"])
			break
	for worker: Dictionary in game.world.workers.values():
		if worker["type"] == "carrier":
			worker_id = int(worker["id"])
			break
	_expect(home_id != 0 and worker_id != 0, "Authored warehouse and carrier exist")
	if home_id == 0:
		return
	var building: Dictionary = game.world.buildings[home_id]
	_expect(not game.building_sprite_presentation(building).is_empty(), "Normal Main loads warehouse production artwork")
	_expect(not game.building_life_presentation(building).is_empty(), "Normal Main connects warehouse household effects")
	if game.building_sprite_presentation(building).is_empty():
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WAREHOUSE_MANIFEST))
	_expect(String(game.building_sprite_presentation(building).get("asset_version", "")) == String(manifest["asset_version"]), "Normal Main reports the actual active warehouse asset version")
	var previous_storage: Dictionary = building["storage"].duplicate()
	var deadline: int = Time.get_ticks_msec() + 180000
	while game.world.tick < 1000 and Time.get_ticks_msec() < deadline:
		for _tick_index: int in range(32):
			_step()
		game.queue_redraw()
		await get_tree().process_frame
		if building["storage"] != previous_storage:
			_natural_storage_changes.append({"tick": game.world.tick, "before": previous_storage, "after": building["storage"].duplicate()})
			previous_storage = building["storage"].duplicate()
	_expect(bool(game.building_life_presentation(building).get("door_open", false)), "Doors open regardless of indoor presence")
	_expect(not _natural_storage_changes.is_empty(), "Actual logistics change warehouse inventory")
	for zoom_value: float in [0.75, 1.0, 2.4]:
		await _record("natural/day-open-" + str(zoom_value).replace(".", "_"), zoom_value)
	var before: Dictionary = _snapshot()
	_expect(game._save_game(), "Isolated temporary save succeeds")
	game._load_game()
	await _settle()
	game._set_simulation_speed(0.0)
	game.set_process(false)
	var after: Dictionary = _snapshot()
	_expect(before["tick"] == after["tick"] and before["storage"] == after["storage"], "Save/load retains real inventory and clock")
	_expect(before["life"] == after["life"], "Save/load reconstructs identical warehouse life presentation")
	await _record("natural/loaded", 2.4)


func _step() -> void:
	game.world.step_tick()
	game.sawmill_operation.observe_tick(game.world)
	game.accumulator = 0.0


func _visual_fixtures() -> void:
	_stage = "disposable exact-state fixture"
	game = null
	session.free()
	session = null
	_fixture_viewport = SubViewport.new()
	_fixture_viewport.size = Vector2i(1600, 900)
	_fixture_viewport.disable_3d = true
	_fixture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_fixture_viewport)
	_fixture_preview = TextureRect.new()
	_fixture_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fixture_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fixture_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fixture_preview.texture = _fixture_viewport.get_texture()
	add_child(_fixture_preview)
	await _fixture(false)
	for zoom_value: float in [0.75, 1.0, 2.4]:
		await _record("fixture/day-pair-" + str(zoom_value).replace(".", "_"), zoom_value, true)
	await _record("fixture/day-open-detail", 2.4)
	var empty_pixels: Image = await _render_image()
	for ware: String in game.world.catalog.building("warehouse")["accepts"]:
		game.world.buildings[home_id]["storage"][ware] = 99999
	await _record("fixture/day-full-storage-same-art", 2.4)
	var full_pixels: Image = await _render_image()
	_expect(_image_hash(empty_pixels) == _image_hash(full_pixels), "Changing every ware from zero to capacity does not change warehouse pixels")
	_expect(game.building_operation_presentation(game.world.buildings[home_id]).is_empty(), "Warehouse has no production inventory or visible-worker layers")
	var guest: Dictionary = game.world.workers[worker_id]
	guest["inside_building_id"] = home_id
	guest["action"] = ""
	await _record("fixture/indoor-guest-detail", 2.4)
	_expect(_worker_entry().is_empty(), "Indoor warehouse guest has no outdoor duplicate or indoor visible figure")
	await _fixture(true)
	game.selected_cell = game.world.buildings[home_id]["position"]
	await _record("fixture/raised-edge-door-approach", 2.4)
	var b: Dictionary = game.world.buildings[home_id]
	_expect(game.world.grid.can_use_building_exit(game.world.building_door_cell(b), b["entrance"]), "Actual raised warehouse exit remains traversable")
	_expect(not game.world.building_cells(b).has(b["entrance"]), "Entrance cell remains outside unchanged occupied mask")


func _fixture(raised: bool) -> void:
	if game != null:
		game.free()
	var world: WarehouseWorld = WarehouseWorld.new(Vector2i(24, 22))
	world.tick = 1750
	if raised:
		for y: int in range(world.grid.size.y + 1):
			for x: int in range(world.grid.size.x + 1):
				var distance: int = maxi(maxi(4 - x, x - 7), maxi(10 - y, y - 13))
				world.grid.set_vertex_height(Vector2i(x, y), maxi(0, 6 - maxi(0, distance) * 2))
		# Only the warehouse is raised. Keep complete flat pads under the
		# reference buildings rather than placing the hut on the ramp fringe.
		for y: int in range(8, 16):
			for x: int in range(9, 21):
				world.grid.set_vertex_height(Vector2i(x, y), 0)
	_fixture_ids.clear()
	for specification: Array in [["warehouse", Vector2i(4, 12)], ["lumber_hut", Vector2i(9, 12)], ["sawmill", Vector2i(15, 12)]]:
		var id: int = world.place_building(String(specification[0]), specification[1])
		_expect(id != 0, "Fixture places existing " + String(specification[0]))
		_fixture_ids[specification[0]] = id
	home_id = int(_fixture_ids["warehouse"])
	worker_id = world.spawn_worker(Vector2i(7, 14), "carrier")
	_expect(worker_id != 0, "Fixture has real native carrier at the entrance approach")
	for x: int in range(3, 20):
		world.grid.add_road(Vector2i(x, 14))
	world.grid.add_road(world.buildings[home_id]["entrance"])
	game = WarehouseMain.instantiate()
	game.world = world
	game.honor_launch_arguments = false
	game.simulation_speed = 0.0
	_fixture_viewport.add_child(game)
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.hud.visible = false
	game._camera_auto_fit = false
	game.camera.position_smoothing_enabled = false
	game.selected_cell = Vector2i(-1, -1)
	await _settle()


func _record(label: String, zoom_value: float, pair: bool = false) -> void:
	game._set_simulation_speed(0.0)
	game.accumulator = 0.0
	game._update_ui()
	game._set_zoom(zoom_value)
	var sprite: Dictionary = game.building_sprite_presentation(game.world.buildings[home_id])
	var rect: Rect2 = sprite["rect"]
	if pair:
		for id: int in _fixture_ids.values():
			var other: Dictionary = game.building_sprite_presentation(game.world.buildings[id])
			if not other.is_empty():
				rect = rect.merge(other["rect"])
	var focus: Vector2 = rect.get_center()
	if _fixture_viewport == null:
		focus -= (game._camera_map_rect().get_center() - game.get_viewport_rect().size * 0.5) / zoom_value
	game.camera.position = focus
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	phases[label] = _snapshot()
	await _capture(label, phases[label])
	print("WAREHOUSE NATIVE: %s tick %d" % [label, game.world.tick])


func _snapshot() -> Dictionary:
	if game == null or home_id == 0 or not game.world.buildings.has(home_id):
		return {"stage": _stage}
	var building: Dictionary = game.world.buildings[home_id]
	var life: Dictionary = game.building_life_presentation(building)
	var retained: Dictionary = {}
	for key: String in ["known", "door_open"]:
		retained[key] = life.get(key)
	var indoor: Array[int] = []
	var duplicate: Array[int] = []
	for worker: Dictionary in game.world.workers.values():
		if int(worker.get("inside_building_id", 0)) == home_id:
			indoor.append(int(worker["id"]))
	for entry: Dictionary in game._world_draw_entries():
		if entry.get("kind") == "worker" and int(entry.get("id", 0)) in indoor:
			duplicate.append(int(entry["id"]))
	var sprite: Dictionary = game.building_sprite_presentation(building)
	return {"stage": _stage, "tick": game.world.tick, "warehouse_id": home_id, "storage": building["storage"].duplicate(),
		"life": retained, "inside_workers": indoor, "duplicate_outdoor_workers": duplicate,
		"asset_version": sprite.get("asset_version", ""), "active_manifest": WAREHOUSE_MANIFEST,
		"loaded_rgba_sha256": _loaded_rgba_hash(sprite), "source_to_world": sprite.get("source_to_world"),
		"footprint_version": building["footprint_version"], "occupied_cell_count": game.world.building_cells(building).size(),
		"camera_zoom": game.camera.zoom.x, "accumulator": game.accumulator}


func _capture(label: String, _metadata: Dictionary) -> void:
	var pixels: Image = await _render_image()
	var filename: String = output_path.path_join(label + ".png")
	_expect(pixels != null and not pixels.is_empty(), "Native frame exists: " + label)
	if pixels == null or pixels.is_empty():
		return
	_expect(pixels.save_png(filename) == OK, "Native PNG saved: " + label)
	captures.append({"file": label + ".png", "sha256": FileAccess.get_sha256(filename), "width": pixels.get_width(), "height": pixels.get_height(), "state": _snapshot()})


func _render_image() -> Image:
	if game != null:
		game.queue_redraw()
	for _frame_index: int in range(2):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var viewport: Viewport = _fixture_viewport if _fixture_viewport != null else get_viewport()
	return viewport.get_texture().get_image()


func _image_hash(pixels: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(pixels.get_data())
	return hashing.finish().hex_encode()


func _loaded_rgba_hash(sprite: Dictionary) -> String:
	if not sprite.get("texture") is Texture2D:
		return ""
	var pixels: Image = (sprite["texture"] as Texture2D).get_image()
	if pixels.is_compressed() and pixels.decompress() != OK:
		return ""
	pixels.convert(Image.FORMAT_RGBA8)
	pixels.clear_mipmaps()
	return _image_hash(pixels)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		failures.append(message)
		printerr("WAREHOUSE QA: " + message)


func _asset_hashes() -> Dictionary:
	var result: Dictionary = {}
	for resource: String in [WAREHOUSE_MANIFEST, "res://scripts/view/main_view.gd", "res://scripts/view/warehouse_life.gd", "res://scripts/view/warehouse_sprite_library.gd", get_script().resource_path]:
		if FileAccess.file_exists(resource):
			result[resource] = FileAccess.get_sha256(resource)
	if FileAccess.file_exists(WAREHOUSE_MANIFEST):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WAREHOUSE_MANIFEST))
		for key: String in ["finished_image", "day_open_image"]:
			var resource: String = WAREHOUSE_MANIFEST.get_base_dir().path_join(String(manifest.get(key, "")))
			if FileAccess.file_exists(resource):
				result[resource] = FileAccess.get_sha256(resource)
	return result


func _finish() -> void:
	var report: Dictionary = {"date": Time.get_datetime_string_from_system(), "engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_video_adapter_name(), "checks": _checks, "failures": failures,
		"natural_scenario": "Actual menu -> Relief -> real warehouse logistics -> isolated save/load",
		"natural_synthetic_worker_stock_or_clock_states": false, "natural_acceleration": "Every simulation tick executed in batches up to32; no skipped clock values",
		"fixture_scenario": "Separate disposable Main world: own building comparison, 0.75/1/2.4 zoom, indoor guest, zero/full inventory, raised ground edge",
		"fixture_synthetic_states": true, "player_saves_accessed": false, "music": music_status,
		"hashes_at_start": _initial_hashes, "hashes_at_end": _asset_hashes(), "phases": phases, "captures": captures,
		"natural_storage_changes": _natural_storage_changes, "pixel_probes": _probes}
	var file: FileAccess = FileAccess.open(output_path.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("WAREHOUSE NATIVE QA: %d checks, %d captures, %d failures -> %s" % [_checks, captures.size(), failures.size(), output_path])
	get_tree().quit(0 if failures.is_empty() else 1)
