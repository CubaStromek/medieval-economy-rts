extends "res://tools/preview_lumber_hut_construction.gd"

# Native production-renderer evidence for the expressly authorized geometry
# revision. No image processing, regenerated artwork, saved games or settings.
var _qa_version: int = 2
var _qa_anchor := ANCHOR + Vector2i(-1, 1)
var _contacts: Array[Dictionary] = []
var _stable_rect := Rect2()


func _run() -> void:
	_output = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-footprint-v2").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.is_absolute_path() or DisplayServer.get_name() == "headless":
		_fail("Footprint QA requires native graphics and an absolute output directory.")
		return
	if DirAccess.make_dir_recursive_absolute(_output.path_join("frames")) != OK:
		_fail("Cannot create footprint QA output directory.")
		return
	get_tree().root.title = "Dřevorubecká chata · půdorys a vstup · bez hudby"
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
	# Preserve the exact door and camera between the historical/new comparison.
	for version: int in [1, 2]:
		_qa_version = version
		await _replace_fixture()
		_frame_camera(2.4)
		var rect: Rect2 = _main.building_sprite_presentation(_building)["rect"]
		if version == 1:
			_stable_rect = rect
		elif rect != _stable_rect:
			_fail("Expanding the footprint moved or rescaled the existing artwork.")
			return
		for amount: int in [0, 6]:
			_building["outputs"]["log"] = amount
			await _capture("frames/footprint-v%d-logs-%d" % [version, amount], {"case": "same-door-comparison"})
	if not _check_contacts("flat"):
		return
	for zoom_value: float in [0.75, 1.0]:
		_frame_camera(zoom_value)
		await _capture("frames/" + _zoom_id(zoom_value), {"case": "zoom", "zoom": zoom_value})
	_frame_camera(2.4)
	_building["outputs"]["log"] = 0
	var stage_textures: Array[Texture2D] = []
	var stage_labels: Array[String] = []
	for step: int in range(SpriteLibraryClass.TOTAL_STEPS + 1):
		_building["construction_remaining"] = _remaining_for_step(step)
		var house: Dictionary = _main.building_sprite_presentation(_building)
		if house.get("rect") != _stable_rect or int(house["step"]) != step:
			_fail("A construction stage moved or did not match its real work state.")
			return
		var captured: Image = await _capture("frames/stage-%02d" % step, {"case": "construction", "expected_step": step})
		if captured == null:
			return
		stage_textures.append(ImageTexture.create_from_image(captured))
		stage_labels.append("Staveniště" if step == 0 else "Krok %d / 33" % step)
		if stage_textures.size() == 8 or step == SpriteLibraryClass.TOTAL_STEPS:
			await _save_sheet("stages-%02d-%02d" % [step-stage_textures.size()+1, step],
				"Rozšířený půdorys · původní stavební kroky", "Stejný práh, měřítko i obrazy · nativní vykreslení · 2.40×", stage_textures, stage_labels)
			stage_textures.clear()
			stage_labels.clear()
	await _capture_conditions()
	await _replace_fixture(true)
	if not _check_contacts("raised-flat"):
		return
	await _capture("frames/raised-contacts", {"case": "raised-contact"})
	await _capture_settlement()
	await _replace_fixture()
	_viewport.size = Vector2i(750, 560)
	_building["outputs"]["log"] = 6
	_frame_camera(3.2)
	await _capture("footprint-complete", {"case": "complete-detail", "zoom": 3.2})
	if not await _capture_pointer_placement():
		return
	var file := FileAccess.open(_output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write footprint QA manifest.")
		return
	file.store_string(JSON.stringify({"captured_at": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_video_adapter_name(),
		"scene": "res://scenes/main.tscn", "art_sha256": _art_hashes(),
		"manifest_sha256": FileAccess.get_sha256(SpriteLibraryClass.MANIFEST_PATH),
		"fixture": "Paused isolated forest, unchanged physical door at (16,12); v1anchor(14,12),v2anchor(13,13)",
		"simulation": "Exact construction/inventory/context fixtures; natural gameplay captured separately",
		"contact_checks": _contacts, "captures": _records}, "\t") + "\n")
	print("LUMBER HUT FOOTPRINT NATIVE QA: %d captures; %d grounded contacts" % [_records.size(), _contacts.size()])
	get_tree().quit(0)


func _capture_pointer_placement() -> bool:
	# Exercise the actual input dispatch: hover then click, without changing
	# placement rules or writing a building directly into simulation state.
	var anchor := Vector2i(6, 19)
	_main.set_process_input(true)
	_main.set_process_unhandled_input(true)
	_main._set_build_mode("lumber_hut")
	_main.camera.zoom = Vector2.ONE * 2.4
	_main.camera.position = _main.terrain_renderer.cell_center(anchor) + Vector2(50, -35)
	_main.camera.force_update_scroll()
	await get_tree().process_frame
	var screen: Vector2 = _main.get_global_transform_with_canvas() * _main.terrain_renderer.cell_center(anchor)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	_viewport.push_input(motion, true)
	await get_tree().process_frame
	var preview: Dictionary = _main.placement_preview.duplicate(true)
	if not bool(preview.get("valid", false)) or (preview.get("cells", []) as Array).size() != 9:
		_fail("Real pointer did not expose a valid nine-cell hut preview.")
		return false
	await _capture("placement-preview", {"case": "real-pointer-hover", "preview_anchor": [anchor.x, anchor.y], "preview_cells": 9})
	var click := InputEventMouseButton.new()
	click.position = screen
	click.global_position = screen
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_viewport.push_input(click, true)
	await get_tree().process_frame
	var id: int = _world.building_id_at(anchor)
	if id == 0:
		_fail("Real pointer click did not place the previewed hut.")
		return false
	_building = _world.buildings[id]
	_qa_anchor = anchor
	if _world.building_cells(_building) != preview["cells"] or _building["entrance"] != preview["entrance"]:
		_fail("Placed ground or doorway differs from the preceding pointer preview.")
		return false
	_main._set_build_mode("")
	await _capture("placement-committed", {"case": "real-pointer-click", "matches_preview": true})
	# Completion here is an explicitly authored visual sample. Real paid
	# construction and all intermediate saves are exercised by the tests.
	_building["construction_remaining"] = 0
	await _capture("placement-finished-fixture", {"case": "same-position-completion-fixture", "matches_preview": true})
	_main.set_process_input(false)
	_main.set_process_unhandled_input(false)
	return true


func _replace_fixture(raised: bool = false, earthwork: bool = false, fog_mode: String = "visible", occlusion: bool = false) -> void:
	if _main != null:
		_main.free()
	_qa_anchor = ANCHOR + Vector2i(-1, 1) if _qa_version == 2 else ANCHOR
	_world = WorldClass.new(Vector2i(32, 24))
	_world.default_footprint_version = _qa_version
	_world.tick = 1750
	if raised:
		# Plateau includes all occupied corners and the outside doorway; slopes
		# remain visible around it, without an unprepared fixture foundation.
		for y: int in range(_world.grid.size.y + 1):
			for x: int in range(_world.grid.size.x + 1):
				var distance: int = maxi(maxi(13 - x, x - 17), maxi(11 - y, y - 14))
				_world.grid.set_vertex_height(Vector2i(x, y), maxi(0, 6 - maxi(0, distance) * 2))
	if earthwork:
		_world.grid.set_vertex_height(_qa_anchor + Vector2i(1, 0), 2)
	_world.economy_enabled = true
	var owner: int = 2 if fog_mode != "visible" else 1
	var id: int = _world.place_building("lumber_hut", _qa_anchor, owner)
	if id == 0:
		_fail("Cannot place footprint QA fixture.")
		return
	_building = _world.buildings[id]
	_building["construction_remaining"] = 120 if earthwork else 0
	for x: int in range(9, 22):
		_world.grid.add_road(Vector2i(x, 14))
	_world.grid.add_road(_building["entrance"])
	for cell: Vector2i in [Vector2i(11, 8), Vector2i(13, 8), Vector2i(18, 8), Vector2i(20, 11), Vector2i(21, 16), Vector2i(10, 16)]:
		_world.add_tree(cell, 3)
	if occlusion:
		_world.add_tree(Vector2i(12, 14), 3)
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
	_main.save_path_override = "user://lumber-hut-footprint-qa-never-written.json"
	_viewport.add_child(_main)
	_main.set_process(false)
	_main.set_process_input(false)
	_main.set_process_unhandled_input(false)
	_main.hud.visible = false
	_main._camera_auto_fit = false
	_main.camera.position_smoothing_enabled = false
	_main.selected_cell = _qa_anchor if fog_mode == "visible" else Vector2i(-1, -1)
	_frame_camera(2.4)
	await get_tree().process_frame


func _capture(name: String, metadata: Dictionary) -> Image:
	var result: Image = await super._capture(name, metadata)
	if result != null:
		var record: Dictionary = _records[-1]
		record["footprint_version"] = _building["footprint_version"]
		record["occupied_cells"] = _world.building_cells(_building).size()
		record["anchor"] = [_qa_anchor.x, _qa_anchor.y]
		record["entrance"] = [_building["entrance"].x, _building["entrance"].y]
		record["fog_state"] = _world.fog_state(_qa_anchor)
		record["stock"] = _building["outputs"].get("log", 0)
		record["sha256"] = FileAccess.get_sha256(_output.path_join(name + ".png"))
	return result


func _check_contacts(context: String) -> bool:
	var house: Dictionary = _main.building_sprite_presentation(_building)
	if house.is_empty():
		_fail("Contact QA requires a finished, prepared house: " + context)
		return false
	var shape: Dictionary = _main.building_geometry(_building)
	var points: Dictionary = {"west-bay-stone": Vector2(44,454), "front-bay-foot": Vector2(128,548),
		"rack-foot": Vector2(190,576), "cabin-front-stone": Vector2(421,468), "timber-rear-foot": Vector2(334,405)}
	for key: String in points:
		var point: Vector2 = (house["rect"] as Rect2).position + (points[key] as Vector2) * float(house["source_to_world"])
		var contained: bool = false
		for polygon: PackedVector2Array in shape["foundations"]:
			contained = contained or Geometry2D.is_point_in_polygon(point, polygon)
		_contacts.append({"context": context, "contact": key, "source": [points[key].x, points[key].y],
			"world": [point.x, point.y], "inside_occupied_ground": contained})
		if not contained:
			_fail("Measured contact lies outside actual occupied ground: " + key + " " + context)
			return false
	return true
