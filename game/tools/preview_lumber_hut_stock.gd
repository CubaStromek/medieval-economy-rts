extends "res://tools/preview_lumber_hut_construction.gd"

# Stock-only visual QA through the production Main scene. Reuses its existing
# isolated construction-preview fixture/capture helpers; no saves or music.
# godot --path game --windowed res://tools/preview_lumber_hut_stock.tscn
var _stock_pixel_checks: Array[Dictionary] = []
var _stock_failed: bool = false


func _run() -> void:
	_output = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-stock-v1").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.is_absolute_path() or DisplayServer.get_name() == "headless":
		_fail("Stock QA requires native graphics and an absolute output directory.")
		return
	if DirAccess.make_dir_recursive_absolute(_output.path_join("frames")) != OK:
		_fail("Cannot create stock QA output directory.")
		return
	get_tree().root.title = "Dřevorubecká chata · kontrola zásob · bez hudby"
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
	if not _main.has_method("building_stock_presentation"):
		_fail("Production Main does not expose building_stock_presentation yet.")
		return
	if int(_world.catalog.building("lumber_hut").get("output_capacity", 0)) != 6:
		_fail("Update stock QA fixtures for the current output capacity.")
		return
	for zoom_value: float in [0.75, 1.0, 2.4]:
		var textures: Array[Texture2D] = []
		var labels: Array[String] = []
		var empty_capture: Image
		var previous_capture: Image
		var zoom_id: String = _zoom_id(zoom_value)
		for amount: int in range(7):
			_building["outputs"]["log"] = amount
			_main.selected_cell = ANCHOR
			_frame_camera(zoom_value)
			var captured: Image = await _capture("frames/" + zoom_id + "-logs-%d" % amount,
				{"case": "stock-amount", "zoom": zoom_value, "expected_amount": amount})
			if captured == null:
				return
			if amount == 0:
				empty_capture = captured
			else:
				var delta: int = _pixel_difference(empty_capture, captured)
				var previous_delta: int = _pixel_difference(previous_capture, captured)
				_stock_pixel_checks.append({"zoom": zoom_value, "amount": amount,
					"changed_from_empty": delta, "changed_from_previous_amount": previous_delta})
				if delta == 0 or previous_delta == 0:
					_fail("Native stock image did not change for %d logs at %.2f zoom." % [amount, zoom_value])
					return
			previous_capture = captured
			textures.append(ImageTexture.create_from_image(captured))
			labels.append("Prázdný stojan · 0 / 6" if amount == 0 else "Klády · %d / 6" % amount)
		await _save_sheet("stock-" + zoom_id, "Dřevorubecká chata · skutečné zásoby · %.2f×" % zoom_value,
			"Herní vykreslení všech 0–6 kusů · stejná kamera a práh · pozastavená simulace", textures, labels)
	await _capture_stock_conditions()
	if _stock_failed:
		return
	await _capture_stock_hud()
	if _stock_failed:
		return
	var manifest: Dictionary = {
		"captured_at": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_video_adapter_name(),
		"scene": "res://scenes/main.tscn",
		"art_manifest_sha256": FileAccess.get_sha256(SpriteLibraryClass.MANIFEST_PATH),
		"unchanged_house_art_sha256": _art_hashes(),
		"stock_art_sha256": _stock_art_hashes(),
		"production_code_sha256": _production_code_hashes(),
		"fixture": "Inherited isolated 32x24 forest/road; selected hut at (14,12); actual Main renderer",
		"simulation": "Paused, inventory and context fields explicitly set; does not claim a live transfer cycle",
		"music": "No game_session or music controller instantiated; no preferences or saved games changed",
		"native_pixel_checks": _stock_pixel_checks,
		"pixel_check_scope": "Whole native frames differ; inspect rack in captures to verify the changed pixels are logs",
		"footprint": "Unchanged source house, scale, threshold, depth, physical 3x2 footprint; existing grounding defect deferred",
		"captures": _records,
	}
	var file: FileAccess = FileAccess.open(_output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write stock capture manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("LUMBER HUT STOCK NATIVE QA: %d captures; %d positive pixel differences → %s" % [_records.size(), _stock_pixel_checks.size(), _output])
	get_tree().quit(0)


func _capture(name: String, metadata: Dictionary) -> Image:
	var result: Image = await super._capture(name, metadata)
	if result == null:
		return null
	var stock: Dictionary = _main.building_stock_presentation(_building)
	var record: Dictionary = _records[-1]
	record["fixture_inventory_log"] = int((_building["outputs"] as Dictionary).get("log", 0))
	record["stock_known"] = bool(stock.get("known", false))
	record["stock_amount"] = stock.get("amount", null)
	record["stock_capacity"] = stock.get("capacity", null)
	record["stock_count_label"] = stock.get("count_label", "")
	record["building_enabled"] = bool(_building.get("enabled", true))
	record["simulation_speed"] = _main.simulation_speed
	record["owner_id"] = _building.get("owner_id", 1)
	record["frame_sha256"] = FileAccess.get_sha256(_output.path_join(name + ".png"))
	if stock.get("rect") is Rect2:
		var rect: Rect2 = stock["rect"]
		record["stock_world_rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if stock.get("texture") is Texture2D:
		var texture: Texture2D = stock["texture"]
		record["stock_texture_size"] = [texture.get_width(), texture.get_height()]
	if metadata.has("expected_amount") and (not bool(stock.get("known", false)) or int(stock.get("amount", -1)) != int(metadata["expected_amount"])):
		_fail("Stock presentation differs from expected visible fixture: " + name)
		return null
	if bool(metadata.get("expected_private", false)) and bool(stock.get("known", false)):
		_fail("Foreign fog fixture disclosed stock: " + name)
		return null
	return result


func _capture_stock_conditions() -> void:
	var cases: Array[Dictionary] = [
		{"id": "noon", "label": "Den · 6 klád", "tick": 1750},
		{"id": "night", "label": "Noc · stejné zásoby", "tick": 4750},
		{"id": "paused", "label": "Provoz i pracovník pozastaven", "paused": true},
		{"id": "inside", "label": "Pracovník uvnitř · stále 6 klád", "inside": true},
		{"id": "raised", "label": "Vyvýšený základ · stejné kotvy", "raised": true},
		{"id": "occlusion", "label": "Překrytí stromem a člověkem", "occlusion": true},
		{"id": "fog-explored", "label": "Cizí prozkoumaný dům · soukromé zásoby", "fog": "explored"},
		{"id": "fog-unknown", "label": "Cizí neznámý dům · skrytý", "fog": "unknown"},
	]
	var textures: Array[Texture2D] = []
	var labels: Array[String] = []
	for context: Dictionary in cases:
		var foreign: bool = context.has("fog")
		await _replace_fixture(bool(context.get("raised", false)), false,
			String(context.get("fog", "visible")), bool(context.get("occlusion", false)))
		_building["outputs"]["log"] = 6
		_world.tick = int(context.get("tick", 1750))
		if bool(context.get("paused", false)) or bool(context.get("inside", false)):
			var inside_id: int = int(_building["id"]) if bool(context.get("inside", false)) else 0
			var worker_id: int = _world.spawn_worker(_building["entrance"], "lumberjack", int(_building["id"]), false, inside_id)
			if bool(context.get("paused", false)):
				_world.set_building_enabled(int(_building["id"]), false)
				_world.set_worker_enabled(worker_id, false)
		_frame_camera(2.4)
		var metadata: Dictionary = {"case": context["id"], "label": context["label"], "zoom": 2.4, "expected_private": foreign}
		if not foreign:
			metadata["expected_amount"] = 6
		var captured: Image = await _capture("frames/context-" + String(context["id"]), metadata)
		if captured == null:
			return
		textures.append(ImageTexture.create_from_image(captured))
		labels.append(String(context["label"]))
	await _save_sheet("contexts", "Dřevorubecká chata · zásoby v herních podmínkách · 2.40×",
		"Denní tónování · pauza a přítomnost nemění zásoby · cizí mlha neodhaluje inventář", textures, labels)
	await _replace_fixture()
	_building["outputs"]["log"] = 6
	_building["construction_remaining"] = 1
	_frame_camera(2.4)
	await _capture("frames/context-unfinished", {"case": "unfinished", "zoom": 2.4,
		"label": "Nedokončený dům nezobrazuje provozní zásoby", "expected_private": true})


func _capture_stock_hud() -> void:
	await _replace_fixture()
	_building["outputs"]["log"] = 6
	_viewport.size = Vector2i(1280, 800)
	_main.hud.visible = true
	await get_tree().process_frame
	_frame_camera(2.4)
	_main.camera.position -= (_main._camera_map_rect().get_center() - Vector2(_viewport.size) * 0.5) / 2.4
	_main.camera.force_update_scroll()
	await _capture("game-stock-complete", {"case": "full-game-hud", "zoom": 2.4, "expected_amount": 6})


func _pixel_difference(a: Image, b: Image) -> int:
	var changed: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed


func _production_code_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["res://scripts/view/main_view.gd", "res://scripts/view/lumber_hut_sprite_library.gd",
			"res://scripts/view/lumber_hut_stock_library.gd", "res://tools/preview_lumber_hut_stock.gd"]:
		if FileAccess.file_exists(path):
			hashes[path] = FileAccess.get_sha256(path)
	return hashes


func _stock_art_hashes() -> Dictionary:
	var directory: String = "res://art/buildings/lumber_hut/v1/stock/"
	var hashes: Dictionary = {"manifest.json": FileAccess.get_sha256(directory + "manifest.json")}
	for amount: int in range(7):
		var file_name: String = "logs-%d.png" % amount
		hashes[file_name] = FileAccess.get_sha256(directory + file_name)
	return hashes


func _fail(message: String) -> void:
	_stock_failed = true
	super._fail(message)
