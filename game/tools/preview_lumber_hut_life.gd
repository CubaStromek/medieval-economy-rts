extends "res://tools/preview_lumber_hut_construction.gd"

# Bounded native visual fixtures through production Main. Authoritative worker
# entry/exit establishes occupancy; explicit actions/ticks isolate each view.
# These snapshots supplement, but do not claim, an ordinary menu/play journey.
const Indoor = preload("res://scripts/simulation/indoor_workers.gd")
const Foundations = preload("res://scripts/simulation/building_foundations.gd")
const LIFE_PANEL := Vector2i(480, 420)
const CASES: Array[Dictionary] = [
	{"id": "day-away", "label": "Dřevorubec venku", "home": false, "rest": false},
	{"id": "day-home", "label": "Odpočinek doma", "home": true, "rest": true},
	{"id": "day-delivery", "label": "Odevzdávání klády", "home": true, "rest": false},
]
var _worker: Dictionary
var _checks: Array[Dictionary] = []
var _life_failed: bool = false


func _run() -> void:
	_output = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-life-v1").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.is_absolute_path() or DisplayServer.get_name() == "headless":
		_fail("Life visual QA needs native graphics and an absolute output directory.")
		return
	if DirAccess.make_dir_recursive_absolute(_output.path_join("frames")) != OK:
		_fail("Cannot create life QA directory.")
		return
	get_tree().root.title = "Dřevorubecká chata · život · bez hudby"
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1000, 650)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)
	_viewport = SubViewport.new()
	_viewport.size = LIFE_PANEL
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_preview.texture = _viewport.get_texture()
	await _new_fixture()
	for zoom_value: float in [0.75, 1.0, 2.4]:
		var captures: Array[Image] = []
		var labels: Array[String] = []
		for context: Dictionary in CASES:
			_set_case(context)
			_frame_camera(zoom_value)
			var captured: Image = await _capture("frames/" + _zoom_id(zoom_value) + "-" + String(context["id"]), context.merged({"zoom": zoom_value}))
			if captured == null:
				return
			captures.append(captured)
			labels.append(String(context["label"]))
		if not _probe_change("door-opens-" + _zoom_id(zoom_value), captures[0], captures[1], Vector2(560, 355), false):
			return
		await _save_life_sheet("life-" + _zoom_id(zoom_value), "Dřevorubecká chata · přítomnost a odpočinek · %.2f×" % zoom_value, captures, labels)
		if is_equal_approx(zoom_value, 2.4):
			var showcase: Array[Image] = [captures[0], captures[1], captures[2]]
			var showcase_labels: Array[String] = [labels[0], labels[1], labels[2]]
			await _save_life_sheet("showcase", "Dřevorubecká chata · dveře, odpočinek a odevzdání", showcase, showcase_labels)
	await _capture_contexts()
	if _life_failed:
		return
	var manifest: Dictionary = {
		"captured_at": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_video_adapter_name(),
		"scene": "res://scenes/main.tscn", "art_sha256": _art_hashes(), "production_sha256": _life_hashes(),
		"fixture": "Isolated 32x24 world, hut (14,12), production Main/SubViewport; worker spawned assigned, entered/exited using IndoorWorkers API; explicit actions and ticks",
		"simulation": "Process disabled for reproducible snapshots; no economic work claimed",
		"music": "No game_session/music controller or saved preferences loaded; saves untouched",
		"native_pixel_checks": _checks, "captures": _records,
	}
	var file: FileAccess = FileAccess.open(_output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save life QA manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("LUMBER HUT LIFE NATIVE QA: %d captures; %d pixel checks; %s" % [_records.size(), _checks.size(), _output])
	get_tree().quit(0)


func _new_fixture(raised: bool = false, fog_mode: String = "visible", occlusion: bool = false) -> void:
	if _main != null:
		_main.free()
	_world = WorldClass.new(Vector2i(32, 24))
	_world.tick = 1750
	_world.economy_enabled = true
	if raised:
		# The original preview's plateau used the older six-cell footprint.
		# Establish the current-mask plateau before placement; occupied vertices
		# correctly reject arbitrary subsequent terrain edits in the real game.
		var vertices: Array[Vector2i] = Foundations.vertices_for_cells(_world.placement_cells("lumber_hut", ANCHOR))
		var minimum: Vector2i = vertices[0]
		var maximum: Vector2i = vertices[0]
		for vertex: Vector2i in vertices:
			minimum = Vector2i(mini(minimum.x, vertex.x), mini(minimum.y, vertex.y))
			maximum = Vector2i(maxi(maximum.x, vertex.x), maxi(maximum.y, vertex.y))
		for y: int in range(_world.grid.size.y + 1):
			for x: int in range(_world.grid.size.x + 1):
				var distance: int = maxi(maxi(minimum.x - x, x - maximum.x), maxi(minimum.y - y, y - maximum.y))
				_world.grid.set_vertex_height(Vector2i(x, y), maxi(0, 6 - maxi(0, distance) * 2))
	var owner: int = 1 if fog_mode == "visible" else 2
	var building_id: int = _world.place_building("lumber_hut", ANCHOR, owner)
	if building_id == 0:
		_fail("Could not place current-footprint life fixture.")
		return
	_building = _world.buildings[building_id]
	_building["construction_remaining"] = 0
	for x: int in range(9, 22):
		_world.grid.add_road(Vector2i(x, 14))
	_world.grid.add_road(_building["entrance"])
	for cell: Vector2i in [Vector2i(11, 8), Vector2i(13, 8), Vector2i(18, 8), Vector2i(20, 11), Vector2i(21, 16), Vector2i(10, 16)]:
		_world.add_tree(cell, 3)
	if occlusion:
		_world.add_tree(Vector2i(16, 13), 3)
	var worker_id: int = _world.spawn_worker(_building["entrance"], "lumberjack", int(_building["id"]), false, 0, owner)
	if worker_id == 0:
		_fail("Could not spawn the assigned life fixture worker. raised=%s fog=%s entrance=%s walkable=%s complete=%s owner=%d reservations=%s" % [raised, fog_mode, _building["entrance"], _world.grid.is_walkable(_building["entrance"]), _world.is_building_complete(_building), owner, _world.tile_reservations])
		return
	_worker = _world.workers[worker_id]
	_building["outputs"]["log"] = 3
	if fog_mode != "visible":
		_world.enable_fog()
		if fog_mode == "explored":
			var explored: Array[Vector2i] = []
			for y: int in range(_world.grid.size.y):
				for x: int in range(_world.grid.size.x):
					explored.append(Vector2i(x, y))
			_world.fog.restore_explored(explored)
	_main = MainScene.instantiate()
	_main.world = _world
	_main.honor_launch_arguments = false
	_main.simulation_speed = 0.0
	_main.save_path_override = "user://lumber-hut-life-qa-never-written.json"
	_viewport.add_child(_main)
	_main.set_process(false)
	_main.set_process_input(false)
	_main.set_process_unhandled_input(false)
	_main.hud.visible = false
	_main._camera_auto_fit = false
	_main.camera.position_smoothing_enabled = false
	_main.selected_cell = Vector2i(-1, -1)
	_main.accumulator = 0.0
	_frame_camera(2.4)
	await get_tree().process_frame


func _set_case(context: Dictionary) -> void:
	_world.tick = 1750
	_main.accumulator = 0.0
	_worker["carrying"] = ""
	_worker["action"] = ""
	_worker["state"] = "idle"
	_worker["indoor_wait_ticks"] = 0
	if not Indoor.is_inside(_worker):
		_position_outdoor_worker(_building["entrance"])
	var expected_inside: bool = bool(context["home"])
	var succeeded: bool = Indoor.enter(_world, _worker, int(_building["id"])) if expected_inside else Indoor.leave(_world, _worker)
	if not succeeded:
		_fail("Fixture could not perform physical entry/exit: " + String(context["id"]))
	if not expected_inside:
		# Keep the outdoor scale witness clear of the door/window pixel probes.
		# This fixture repositioning is not represented as simulated walking.
		_position_outdoor_worker((_building["entrance"] as Vector2i) + Vector2i(2, 1))
	if String(context["id"]) == "day-delivery":
		_worker["carrying"] = "log"
		_worker["action"] = "deliver_output"
		_worker["state"] = "working"
		_worker["destination_id"] = int(_building["id"])


func _position_outdoor_worker(cell: Vector2i) -> void:
	_world._release_worker_tile(_worker)
	_worker["position"] = cell
	_worker["previous_position"] = cell
	_worker["move_cooldown"] = 0
	_worker["visual_progress_ticks"] = 1
	_worker["visual_duration_ticks"] = 1
	_world.tile_reservations[cell] = int(_worker["id"])


func _frame_camera(zoom_value: float) -> void:
	if _main == null:
		return
	super._frame_camera(zoom_value)
	var life: Dictionary = _main.building_life_presentation(_building)
	if life.get("rect") is Rect2:
		_main.camera.position = (life["rect"] as Rect2).position + Vector2(320.0 * float(life["source_to_world"]), 54.0)
	_main.camera.force_update_scroll()
	_main.queue_redraw()


func _capture(name: String, metadata: Dictionary) -> Image:
	var captured: Image = await super._capture(name, metadata)
	if captured == null:
		return null
	var life: Dictionary = _main.building_life_presentation(_building)
	var record: Dictionary = _records[-1]
	for key: String in ["known", "at_home", "door_open", "rest_visible", "rest_worker_id", "time_seconds", "source_to_world"]:
		record[key] = life.get(key)
	record["worker_inside_id"] = int(_worker.get("inside_building_id", 0))
	record["footprint_version"] = int(_building.get("footprint_version", 0))
	record["worker_action"] = _worker.get("action", "")
	record["worker_carrying"] = _worker.get("carrying", "")
	record["frame_sha256"] = FileAccess.get_sha256(_output.path_join(name + ".png"))
	if life.get("rect") is Rect2:
		var rect: Rect2 = life["rect"]
		record["world_rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if bool(metadata.get("private", false)):
		if bool(life.get("known", false)):
			_fail("Foreign life fixture disclosed private resident state: " + name)
			return null
	elif metadata.has("home"):
		if bool(life.get("at_home", false)) != bool(metadata["home"]) or bool(life.get("rest_visible", false)) != bool(metadata["rest"]):
			_fail("Life state disagrees with physical fixture: " + name)
			return null
	return captured


func _source_screen(point: Vector2) -> Vector2i:
	var life: Dictionary = _main.building_life_presentation(_building)
	var position: Vector2 = (life["rect"] as Rect2).position + point * float(life["source_to_world"])
	return Vector2i((_main.get_global_transform_with_canvas() * position).round())


func _probe_change(label: String, absent: Image, present: Image, source: Vector2, brighter: bool) -> bool:
	var probe: Vector2i = _source_screen(source)
	var changes: int = 0
	var positive_light: float = 0.0
	for y: int in range(probe.y - 2, probe.y + 3):
		for x: int in range(probe.x - 2, probe.x + 3):
			var a: Color = absent.get_pixel(x, y)
			var b: Color = present.get_pixel(x, y)
			if a != b:
				changes += 1
			positive_light = maxf(positive_light, b.get_luminance() - a.get_luminance())
	var passed: bool = changes > 0 and (not brighter or positive_light > 0.025)
	_checks.append({"check": label, "passed": passed, "source_probe": [source.x, source.y], "screen_probe": [probe.x, probe.y], "neighborhood": "5x5", "changed_pixels": changes, "maximum_luminance_increase": positive_light})
	if not passed:
		_fail("Native positive-control probe failed: " + label)
	return passed


func _capture_contexts() -> void:
	for context: Dictionary in [{"id": "raised-home", "raised": true}, {"id": "occlusion-home", "occlusion": true}]:
		await _new_fixture(bool(context.get("raised", false)), "visible", bool(context.get("occlusion", false)))
		_set_case(CASES[1])
		_frame_camera(2.4)
		await _capture("frames/" + String(context["id"]), context.merged({"zoom": 2.4}))
	for fog_mode: String in ["explored", "unknown"]:
		await _new_fixture(false, fog_mode)
		_set_case(CASES[0])
		_frame_camera(2.4)
		var absent: Image = await _capture("frames/fog-" + fog_mode + "-away", {"private": true, "zoom": 2.4})
		_set_case(CASES[1])
		_frame_camera(2.4)
		var present: Image = await _capture("frames/fog-" + fog_mode + "-home", {"private": true, "zoom": 2.4})
		if absent == null or present == null:
			return
		var changed: int = _difference(absent, present)
		_checks.append({"check": "foreign-" + fog_mode + "-invariant", "passed": changed == 0, "changed_pixels": changed})
		if changed != 0:
			_fail("Changing a hidden foreign resident changed native pixels.")
			return


func _difference(a: Image, b: Image) -> int:
	if a == null or b == null:
		return -1
	var changed: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func _save_life_sheet(name: String, heading: String, captures: Array[Image], labels: Array[String]) -> void:
	var sheet := SubViewport.new()
	sheet.size = Vector2i(captures.size() * LIFE_PANEL.x, 510)
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("#17211e")
	background.size = Vector2(sheet.size)
	sheet.add_child(background)
	_add_label(sheet, heading, Vector2(20, 10), 26, Color("#f0ead9"))
	for index: int in range(captures.size()):
		var panel := TextureRect.new()
		panel.position = Vector2(index * LIFE_PANEL.x, 50)
		panel.texture = ImageTexture.create_from_image(captures[index])
		sheet.add_child(panel)
		_add_label(sheet, labels[index], Vector2(index * LIFE_PANEL.x + 14, 478), 20, Color("#f0ead9"))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Image = sheet.get_texture().get_image()
	if result.save_png(_output.path_join(name + ".png")) != OK:
		_fail("Cannot save life contact sheet.")
	_records.append({"file": name + ".png", "case": "contact-sheet"})
	sheet.free()


func _life_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["res://scripts/view/lumber_hut_life.gd", "res://scripts/view/main_view.gd", "res://tools/preview_lumber_hut_life.gd", "res://art/buildings/lumber_hut/v1/life/resting_lumberjack.png", "res://art/buildings/lumber_hut/v1/life/resting_lumberjack.json"]:
		if FileAccess.file_exists(path):
			hashes[path] = FileAccess.get_sha256(path)
	return hashes


func _fail(message: String) -> void:
	_life_failed = true
	super._fail(message)
