extends Node

# Native captures of the real Main scene, including its terrain/object rows,
# solar lighting, fog, selection and unit drawing. No game session, music
# controller, player settings or save files are loaded or written.
# godot --path game --windowed res://tools/preview_lumber_hut_construction.tscn
# Optional: -- --output=/absolute/directory or --validate-only (headless allowed).
const MainScene = preload("res://scenes/main.tscn")
const WorldClass = preload("res://scripts/simulation/simulation_world.gd")
const SpriteLibraryClass = preload("res://scripts/view/lumber_hut_sprite_library.gd")
const PANEL_SIZE := Vector2i(480, 360)
const SHEET_SIZE := Vector2i(1920, 872)
const ANCHOR := Vector2i(14, 12)
const STAGES: Array[Dictionary] = [
	{"id": "00-site", "label": "Připravený základ · 0/33", "remaining": 120, "step": 0},
	{"id": "01-wood-01", "label": "Dřevěná konstrukce · 1/12", "remaining": 119, "step": 1},
	{"id": "02-wood-06", "label": "Dřevěná konstrukce · 6/12", "remaining": 84, "step": 6},
	{"id": "03-wood-12", "label": "Dřevěná konstrukce · 12/12", "remaining": 48, "step": 12},
	{"id": "04-finish-01", "label": "Dokončování · 1/21", "remaining": 47, "step": 13},
	{"id": "05-finish-11", "label": "Dokončování · 11/21", "remaining": 24, "step": 23},
	{"id": "06-finish-21", "label": "Dokončování · 21/21", "remaining": 1, "step": 33},
	{"id": "07-complete", "label": "Hotová chata", "remaining": 0, "step": 33},
]

var _output: String
var _records: Array[Dictionary] = []
var _viewport: SubViewport
var _main: Node2D
var _world: WorldClass
var _building: Dictionary
var _preview: TextureRect


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_output = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-construction-v1").simplify_path()
	var validate_only: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		elif argument == "--validate-only":
			validate_only = true
	if not _output.is_absolute_path():
		_fail("QA output must be an absolute directory.")
		return
	if not _validate_fixtures():
		return
	if validate_only:
		print("LUMBER HUT QA FIXTURES: eight exact stage states; no rendering attempted.")
		get_tree().quit(0)
		return
	if DisplayServer.get_name() == "headless":
		_fail("Native graphics are required. Omit --headless to capture the game.")
		return
	var sprites := SpriteLibraryClass.new()
	if not sprites.supports({"type": "lumber_hut", "footprint_version": 1}):
		_fail("The authored lumber hut sprite assets must be present and imported before visual QA.")
		return
	var error: Error = DirAccess.make_dir_recursive_absolute(_output.path_join("frames"))
	if error != OK:
		_fail("Cannot create output directory: " + error_string(error))
		return
	get_tree().root.title = "Dřevorubecká chata · kontrola výstavby · bez hudby"
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1200, 600)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)
	_viewport = SubViewport.new()
	_viewport.size = PANEL_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_preview.texture = _viewport.get_texture()
	await _replace_fixture()
	for zoom_value: float in [0.75, 1.0, 2.4]:
		var textures: Array[Texture2D] = []
		var labels: Array[String] = []
		var zoom_id: String = _zoom_id(zoom_value)
		for stage: Dictionary in STAGES:
			_building["construction_remaining"] = int(stage["remaining"])
			_main.selected_cell = Vector2i(-1, -1)
			_frame_camera(zoom_value)
			var captured: Image = await _capture("frames/" + zoom_id + "-" + String(stage["id"]), {
				"case": "construction", "zoom": zoom_value, "label": stage["label"],
			})
			if captured == null:
				return
			textures.append(ImageTexture.create_from_image(captured))
			labels.append(String(stage["label"]))
		await _save_sheet("construction-" + zoom_id, "Dřevorubecká chata · 12 + 21 kroků · %.2f×" % zoom_value,
			"Skutečné herní vykreslení · stejný práh a měřítko · pozastavená simulace · člověk u vstupu", textures, labels)
	await _capture_conditions()
	await _capture_animation()
	await _capture_settlement()
	if _records.is_empty():
		_fail("No native captures were produced.")
		return
	var manifest: Dictionary = {
		"captured_at": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scene": "res://scenes/main.tscn",
		"art_manifest_sha256": FileAccess.get_sha256(SpriteLibraryClass.MANIFEST_PATH),
		"art_sha256": _art_hashes(),
		"fixture": "Deterministic temporary forest and road; actual Main draw path; HUD hidden in panels",
		"simulation": "paused; existing remaining-work fields authored for exact graphics samples",
		"music": "No game_session or music controller instantiated; no preferences changed",
		"captures": _records,
	}
	var file: FileAccess = FileAccess.open(_output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write capture manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("LUMBER HUT NATIVE QA: %d captures → %s" % [_records.size(), _output])
	get_tree().quit(0)


func _validate_fixtures() -> bool:
	var world := WorldClass.new(Vector2i(32, 24))
	var definition: Dictionary = world.catalog.building("lumber_hut")
	if int(definition.get("construction_ticks", 0)) != 120:
		_fail("Construction duration changed; update the exact QA stage fixtures.")
		return false
	for stage: Dictionary in STAGES:
		var state: Dictionary = SpriteLibraryClass.state_for({"construction_remaining": stage["remaining"]}, definition)
		if int(state["step"]) != int(stage["step"]):
			_fail("Fixture does not map to the intended construction stage: " + String(stage["id"]))
			return false
	return true


func _replace_fixture(raised: bool = false, earthwork: bool = false, fog_mode: String = "visible", occlusion: bool = false) -> void:
	if _main != null:
		_main.free()
	_world = WorldClass.new(Vector2i(32, 24))
	_world.tick = 1750 # noon, using the unchanged game clock
	if raised:
		for y: int in range(_world.grid.size.y + 1):
			for x: int in range(_world.grid.size.x + 1):
				var distance: int = maxi(maxi(14 - x, x - 17), maxi(11 - y, y - 13))
				_world.grid.set_vertex_height(Vector2i(x, y), maxi(0, 6 - maxi(0, distance) * 2))
	if earthwork:
		_world.grid.set_vertex_height(ANCHOR + Vector2i(1, 0), 2)
	_world.economy_enabled = true
	var owner: int = 2 if fog_mode != "visible" else 1
	var building_id: int = _world.place_building("lumber_hut", ANCHOR, owner)
	if building_id == 0:
		_fail("Cannot place the QA lumber hut fixture.")
		return
	_building = _world.buildings[building_id]
	_building["construction_remaining"] = 0 if not earthwork else 120
	for x: int in range(9, 22):
		_world.grid.add_road(Vector2i(x, 14))
	_world.grid.add_road(_building["entrance"])
	for cell: Vector2i in [Vector2i(11, 8), Vector2i(13, 8), Vector2i(18, 8), Vector2i(20, 11), Vector2i(21, 16), Vector2i(10, 16)]:
		_world.add_tree(cell, 3)
	if occlusion:
		_world.add_tree(Vector2i(13, 13), 3)
	_world.spawn_worker(_building["entrance"], "builder", 0, false, 0, owner)
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
	_main.save_path_override = "user://lumber-hut-qa-never-written.json"
	_viewport.add_child(_main)
	_main.set_process(false)
	_main.set_process_input(false)
	_main.set_process_unhandled_input(false)
	_main.hud.visible = false
	_main._camera_auto_fit = false
	_main.camera.position_smoothing_enabled = false
	_main.selected_cell = ANCHOR if fog_mode == "visible" else Vector2i(-1, -1)
	_frame_camera(2.4)
	await get_tree().process_frame


func _frame_camera(zoom_value: float) -> void:
	var door: Vector2 = _main.terrain_renderer.project_grid_position(Vector2(_world.building_door_cell(_building)) + Vector2(0.0, 0.5))
	var reference: Dictionary = _building.duplicate()
	reference["construction_remaining"] = 0
	reference["foundation_work_remaining"] = 0
	var reference_sprite: Dictionary = _main.lumber_hut_sprites.presentation_for(reference, _world.catalog.building("lumber_hut"), door)
	_main.camera.zoom = Vector2(zoom_value, zoom_value)
	# Frame the complete house and its real game labels, with one stable view for
	# every stage. Neither the lower foreground nor the progress bar may be cut
	# off by the viewport and masquerade as a terrain-row rendering regression.
	_main.camera.position = door + Vector2(-40.0, -20.0)
	if not reference_sprite.is_empty():
		var sprite_rect: Rect2 = reference_sprite["rect"]
		var source_scale: float = float(reference_sprite["source_to_world"])
		var texture: Texture2D = reference_sprite["texture"] as Texture2D
		var used: Rect2i = texture.get_image().get_used_rect()
		var bounds := Rect2(sprite_rect.position + Vector2(used.position) * source_scale, Vector2(used.size) * source_scale)
		var label_point: Vector2 = sprite_rect.position + (reference_sprite.get("label_anchor", Vector2.ZERO) as Vector2) * source_scale
		bounds = bounds.merge(Rect2(label_point + Vector2(-65, -20), Vector2(130, 22)))
		_main.camera.position = bounds.get_center()
	_main.camera.force_update_scroll()
	_main._update_ui()
	_main.queue_redraw()


func _capture(name: String, metadata: Dictionary) -> Image:
	_main.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Image = _viewport.get_texture().get_image()
	if result == null or result.is_empty() or result.get_size() != _viewport.size:
		_fail("Native capture did not return the expected image: " + name)
		return null
	if result.save_png(_output.path_join(name + ".png")) != OK:
		_fail("Cannot save native capture: " + name)
		return null
	var state: Dictionary = SpriteLibraryClass.state_for(_building, _world.catalog.building("lumber_hut"))
	var record: Dictionary = metadata.duplicate(true)
	record.merge({"file": name + ".png", "size": [result.get_width(), result.get_height()],
		"stage": state, "tick": _world.tick, "foundation_remaining": _building["foundation_work_remaining"],
		"door_cell": [_world.building_door_cell(_building).x, _world.building_door_cell(_building).y],
		"fog_state": _world.fog_state(ANCHOR), "painted_terrain": _main.terrain_renderer.painted_mode_active()})
	_records.append(record)
	return result


func _capture_conditions() -> void:
	var cases: Array[Dictionary] = [
		{"id": "noon", "label": "Den · výběr + člověk u vstupu", "tick": 1750},
		{"id": "dusk", "label": "Soumrak · stejné materiály", "tick": 3625},
		{"id": "night", "label": "Noc · herní tónování", "tick": 4750},
		{"id": "raised", "label": "Vyvýšený rovný základ", "raised": true},
		{"id": "earthwork", "label": "Srovnávání · bez střechy", "earthwork": true},
		{"id": "occlusion", "label": "Překrytí stromem a člověkem", "occlusion": true},
		{"id": "fog-explored", "label": "Cizí dům · prozkoumaná mlha", "fog": "explored"},
		{"id": "fog-unknown", "label": "Neznámé území · dům skrytý", "fog": "unknown"},
	]
	var textures: Array[Texture2D] = []
	var labels: Array[String] = []
	for context: Dictionary in cases:
		await _replace_fixture(bool(context.get("raised", false)), bool(context.get("earthwork", false)),
			String(context.get("fog", "visible")), bool(context.get("occlusion", false)))
		_world.tick = int(context.get("tick", 1750))
		_frame_camera(2.4)
		var captured: Image = await _capture("frames/context-" + String(context["id"]), {
			"case": context["id"], "label": context["label"], "zoom": 2.4,
		})
		if captured == null:
			return
		textures.append(ImageTexture.create_from_image(captured))
		labels.append(String(context["label"]))
	await _save_sheet("contexts", "Dřevorubecká chata · kontrola ve hře · 2.40×",
		"Den / soumrak / noc · terén a pořadí překrytí · mlha skrývá cizí jednotky", textures, labels)


func _capture_settlement() -> void:
	# A full Main HUD frame complements the readable, tightly framed sheets.
	# This authored QA settlement exists only in memory, like all other cases.
	await _replace_fixture()
	_world.economy_enabled = false
	_world.place_building("warehouse", Vector2i(8, 12))
	_world.place_building("school", Vector2i(9, 18))
	_world.economy_enabled = true
	_world.spawn_worker(Vector2i(17, 14), "lumberjack", 0, false)
	_viewport.size = Vector2i(1280, 800)
	_main.hud.visible = true
	await get_tree().process_frame
	for remaining: int in [48, 0]:
		_building["construction_remaining"] = remaining
		_frame_camera(1.8)
		_main.camera.position -= (_main._camera_map_rect().get_center() - Vector2(_viewport.size) * 0.5) / 1.8
		_main.camera.force_update_scroll()
		var id: String = "game-construction" if remaining > 0 else "game-complete"
		await _capture(id, {"case": "full-game-hud", "zoom": 1.8, "remaining": remaining})


func _capture_animation() -> void:
	# Each frame is captured independently through the same real game drawing.
	# The concat list can make a GIF/video without inventing intermediate art.
	await _replace_fixture()
	_viewport.size = Vector2i(640, 480)
	_main.selected_cell = Vector2i(-1, -1)
	var annotation := CanvasLayer.new()
	annotation.layer = 100
	_viewport.add_child(annotation)
	var bar := ColorRect.new()
	bar.color = Color("#17211e")
	bar.size = Vector2(640, 52)
	annotation.add_child(bar)
	var label := Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color("#f0ead9"))
	annotation.add_child(label)
	var concat: PackedStringArray = PackedStringArray(["ffconcat version 1.0"])
	for step: int in range(SpriteLibraryClass.TOTAL_STEPS + 1):
		_building["construction_remaining"] = _remaining_for_step(step)
		if step == 0:
			label.text = "Připravené staveniště"
		elif step <= SpriteLibraryClass.WOOD_STEPS:
			label.text = "Dřevěná konstrukce · %d / 12" % step
		else:
			label.text = "Dokončování · %d / 21" % (step - SpriteLibraryClass.WOOD_STEPS)
		_frame_camera(2.4)
		var name: String = "frames/animation-%02d" % step
		var captured: Image = await _capture(name, {"case": "animation", "zoom": 2.4, "step": step})
		if captured == null:
			return
		concat.append("file '%s.png'" % name)
		concat.append("duration %.2f" % (1.0 if step == 0 else (2.0 if step == 33 else 0.22)))
	concat.append("file 'frames/animation-33.png'")
	var file: FileAccess = FileAccess.open(_output.path_join("construction.ffconcat"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save animation frame list.")
		return
	file.store_string("\n".join(concat) + "\n")
	annotation.free()
	_viewport.size = PANEL_SIZE


func _remaining_for_step(step: int) -> int:
	if step == SpriteLibraryClass.TOTAL_STEPS:
		return 0
	var definition: Dictionary = _world.catalog.building("lumber_hut")
	for remaining: int in range(120, 0, -1):
		var state: Dictionary = SpriteLibraryClass.state_for({"construction_remaining": remaining}, definition)
		if int(state["step"]) == step:
			return remaining
	_fail("No simulation work value maps to animation step %d." % step)
	return 120


func _save_sheet(name: String, heading: String, subtitle: String, textures: Array[Texture2D], labels: Array[String]) -> void:
	var sheet := SubViewport.new()
	sheet.size = SHEET_SIZE
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("#17211e")
	background.size = Vector2(SHEET_SIZE)
	sheet.add_child(background)
	_add_label(sheet, heading, Vector2(24, 12), 28, Color("#f0ead9"))
	_add_label(sheet, subtitle, Vector2(24, 51), 17, Color("#b4c0ad"))
	for index: int in range(textures.size()):
		var position_in_sheet := Vector2((index % 4) * PANEL_SIZE.x, 88 + (index / 4) * 392)
		var texture_rect := TextureRect.new()
		texture_rect.position = position_in_sheet
		texture_rect.size = Vector2(PANEL_SIZE)
		texture_rect.texture = textures[index]
		sheet.add_child(texture_rect)
		_add_label(sheet, labels[index], position_in_sheet + Vector2(12, 365), 19, Color("#f0ead9"))
	_preview.texture = sheet.get_texture()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Image = sheet.get_texture().get_image()
	if result == null or result.is_empty() or result.save_png(_output.path_join(name + ".png")) != OK:
		_fail("Cannot save construction contact sheet: " + name)
	else:
		_records.append({"file": name + ".png", "case": "contact-sheet", "size": [SHEET_SIZE.x, SHEET_SIZE.y]})
	_preview.texture = _viewport.get_texture()
	sheet.free()


func _add_label(parent: Node, text: String, label_position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = label_position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _zoom_id(value: float) -> String:
	return "zoom-" + ("%.2f" % value).replace(".", "-")


func _art_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for file_name: String in ["wood.png", "finished.png", "wood-mask.png", "finished-mask.png"]:
		hashes[file_name] = FileAccess.get_sha256(SpriteLibraryClass.MANIFEST_PATH.get_base_dir().path_join(file_name))
	return hashes


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
