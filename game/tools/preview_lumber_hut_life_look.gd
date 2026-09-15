extends "res://tools/preview_lumber_hut_life.gd"

# Follow-up evidence has its own directory; previous life-v1 stays historical.
const Life = preload("res://scripts/view/lumber_hut_life.gd")
const LOOK_FPS := 20
const LOOK_FRAMES := 12 * LOOK_FPS


func _run() -> void:
	_output = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-life-look-v1").simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.is_absolute_path() or DisplayServer.get_name() == "headless":
		_fail("Look QA needs native graphics and an absolute output directory.")
		return
	if DirAccess.make_dir_recursive_absolute(_output.path_join("frames")) != OK:
		_fail("Cannot create look QA directory.")
		return
	get_tree().root.title = "Dřevorubecká chata · okno a rozhlížení · bez hudby"
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
	if not ResourceLoader.exists(Life.LOOK_MANIFEST.get_base_dir().path_join("left.png")):
		_fail("The final imported head poses are required.")
		return
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
		if not _dark_window_probe(captures[0], captures[1], zoom_value):
			return
		await _save_life_sheet("look-" + _zoom_id(zoom_value), "Otevřené okno při odpočinku · %.2f×" % zoom_value, captures, labels)
		if is_equal_approx(zoom_value, 2.4):
			var showcase: Array[Image] = [captures[0], captures[1]]
			var showcase_labels: Array[String] = ["Venku · zavřeno", "Odpočinek · otevřené tmavé okno"]
			await _save_life_sheet("showcase", "Dřevorubecká chata · denní okno a klidné rozhlížení", showcase, showcase_labels)
	await _capture_head_cycle()
	if _life_failed:
		return
	await _capture_contexts()
	if _life_failed:
		return
	await _capture_day_fog()
	if _life_failed:
		return
	var manifest: Dictionary = {"captured_at": Time.get_datetime_string_from_system(),
		"project": ProjectSettings.globalize_path("res://"),
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_video_adapter_name(),
		"scene": "res://scenes/main.tscn", "art_sha256": _art_hashes(), "production_sha256": _look_hashes(),
		"fixture": "Production Main, isolated32x24 world, current footprint; assigned worker enters/leaves through IndoorWorkers; explicit state/tick samples",
		"animation": "240 native frames, 20fps, one full12s production phase cycle; actual sampled simulation timestamps in each record; no economic work claimed",
		"lighting_control": "No day/night lighting; measured body/feet regions stay pixel-identical",
		"music": "No music controller, settings or player saves loaded", "native_pixel_checks": _checks, "captures": _records}
	var file: FileAccess = FileAccess.open(_output.path_join("capture-manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("LUMBER HUT LOOK NATIVE QA: %d captures; %d controls; %s" % [_records.size(), _checks.size(), _output])
	get_tree().quit(0)


func _capture(name: String, metadata: Dictionary) -> Image:
	var result: Image = await super._capture(name, metadata)
	if result == null:
		return null
	var life: Dictionary = _main.building_life_presentation(_building)
	var record: Dictionary = _records[-1]
	record["window_open"] = life.get("window_open", false)
	record["rest_pose"] = Life.rest_pose_for(life)
	record["rest_turn"] = Life._rest_turn_for(life)
	var rest: Rect2 = Life.rest_rect(life)
	record["rest_rect"] = [rest.position.x, rest.position.y, rest.size.x, rest.size.y]
	if bool(life.get("rest_visible", false)) and (not bool(life.get("window_open", false)) or life.has("light_strength")):
		_fail("Day rest must open an unlit window: " + name)
		return null
	return result


func _dark_window_probe(closed: Image, opened: Image, zoom_value: float) -> bool:
	# Interior point avoids cross bars; a tiny source-space neighborhood stays
	# inside the aperture at every zoom, rather than sampling brighter plaster.
	var probe: Vector2i = _source_screen(Vector2(495, 351))
	var a: Color = closed.get_pixelv(probe)
	var b: Color = opened.get_pixelv(probe)
	var darkening: float = a.get_luminance() - b.get_luminance()
	var passed: bool = darkening > 0.03
	_checks.append({"check": "day-window-open-dark-" + _zoom_id(zoom_value), "passed": passed,
		"source_probe": [495, 351], "screen_probe": [probe.x, probe.y], "closed_rgb": [a.r, a.g, a.b],
		"opened_rgb": [b.r, b.g, b.b], "luminance_drop": darkening, "minimum_drop": 0.03})
	if not passed:
		_fail("Native daytime aperture did not darken at %.2f zoom." % zoom_value)
	return passed


func _set_look_phase(phase: float) -> void:
	var seconds: float = 180.0 - float(_worker["id"]) * 0.73 + phase
	_world.tick = floori(seconds / 0.1)
	_main.accumulator = seconds - float(_world.tick) * 0.1


func _rest_region(source: Rect2) -> Rect2i:
	var life: Dictionary = _main.building_life_presentation(_building)
	var rest: Rect2 = Life.rest_rect(life)
	var scale: Vector2 = rest.size / 256.0
	var transform: Transform2D = _main.get_global_transform_with_canvas()
	var first: Vector2 = transform * (rest.position + source.position * scale)
	var last: Vector2 = transform * (rest.position + source.end * scale)
	return Rect2i(Vector2i(first.floor()), Vector2i((last - first).ceil())).intersection(Rect2i(Vector2i.ZERO, LIFE_PANEL))


func _capture_head_cycle() -> void:
	await _new_fixture()
	_set_case(CASES[1])
	_set_look_phase(0.0)
	_frame_camera(2.4)
	var head_region: Rect2i = _rest_region(Rect2(98, 39, 44, 46))
	var body_region: Rect2i = _rest_region(Rect2(94, 91, 58, 115))
	var feet_region: Rect2i = _rest_region(Rect2(94, 185, 58, 23))
	var first: Image
	var greatest_body_change: int = 0
	var greatest_feet_change: int = 0
	var maximum_head_change: int = 0
	var changed_frames: int = 0
	var endpoint_images: Dictionary = {}
	var concat := PackedStringArray(["ffconcat version 1.0"])
	var rect_at_start: Rect2
	for index: int in range(LOOK_FRAMES):
		_set_look_phase(float(index) / LOOK_FPS)
		var captured: Image = await _capture("frames/look-%03d" % index, {"case": "full-head-cycle", "index": index, "zoom": 2.4, "phase": float(index) / LOOK_FPS, "duration_seconds": 1.0 / LOOK_FPS})
		if captured == null:
			return
		var life: Dictionary = _main.building_life_presentation(_building)
		var pose: String = Life.rest_pose_for(life)
		var turn: Dictionary = Life._rest_turn_for(life)
		if index == 0:
			first = captured
			rect_at_start = Life.rest_rect(life)
			endpoint_images["center"] = captured
		elif Life.rest_rect(life) != rect_at_start:
			_fail("Head motion moved the resting body's registered rectangle.")
			return
		if pose != "center" and float(turn["amount"]) >= 0.999 and not endpoint_images.has(pose):
			endpoint_images[pose] = captured
		var body_change: int = _difference(first.get_region(body_region), captured.get_region(body_region))
		var feet_change: int = _difference(first.get_region(feet_region), captured.get_region(feet_region))
		var head_change: int = _difference(first.get_region(head_region), captured.get_region(head_region))
		greatest_body_change = maxi(greatest_body_change, body_change)
		greatest_feet_change = maxi(greatest_feet_change, feet_change)
		maximum_head_change = maxi(maximum_head_change, head_change)
		if head_change > 0:
			changed_frames += 1
		concat.append("file 'frames/look-%03d.png'" % index)
		concat.append("duration %.2f" % (1.0 / LOOK_FPS))
	var cycle_ok: bool = greatest_body_change == 0 and greatest_feet_change == 0 and maximum_head_change > 0 and endpoint_images.has("left") and endpoint_images.has("right")
	_checks.append({"check": "head-motion-fixed-body-and-feet", "passed": cycle_ok, "frames": LOOK_FRAMES,
		"maximum_body_changed_pixels": greatest_body_change, "maximum_feet_changed_pixels": greatest_feet_change,
		"maximum_head_changed_pixels": maximum_head_change, "head_changed_frames": changed_frames,
		"head_region": [head_region.position.x, head_region.position.y, head_region.size.x, head_region.size.y],
		"body_region": [body_region.position.x, body_region.position.y, body_region.size.x, body_region.size.y],
		"feet_region": [feet_region.position.x, feet_region.position.y, feet_region.size.x, feet_region.size.y]})
	if not cycle_ok:
		_fail("Native head cycle did not change just the head on its stationary body.")
		return
	var endpoints: Array[Image] = [endpoint_images["left"], endpoint_images["center"], endpoint_images["right"]]
	var labels: Array[String] = ["Pohled vlevo", "Klidová poloha", "Pohled vpravo"]
	await _save_life_sheet("head-poses", "Skutečné herní fáze · tělo i chodidla stojí na místě", endpoints, labels)
	var file: FileAccess = FileAccess.open(_output.path_join("look.ffconcat"), FileAccess.WRITE)
	file.store_string("\n".join(concat) + "\n")
	_set_look_phase(2.25)
	_frame_camera(2.4)
	var paused_a: Image = await _capture("frames/look-pause-a", {"case": "paused-turn", "zoom": 2.4})
	await get_tree().create_timer(0.4).timeout
	_main._process(0.4)
	var paused_b: Image = await _capture("frames/look-pause-b", {"case": "paused-turn", "zoom": 2.4})
	var pause_change: int = _difference(paused_a, paused_b)
	_checks.append({"check": "pause-freezes-mid-turn", "passed": pause_change == 0, "changed_pixels": pause_change})
	if pause_change != 0:
		_fail("Paused head turn kept moving in the native frame.")


func _capture_day_fog() -> void:
	for fog_mode: String in ["explored", "unknown"]:
		await _new_fixture(false, fog_mode)
		_set_case(CASES[0])
		_frame_camera(2.4)
		var absent: Image = await _capture("frames/day-fog-" + fog_mode + "-away", {"private": true, "zoom": 2.4})
		_set_case(CASES[1])
		_frame_camera(2.4)
		var present: Image = await _capture("frames/day-fog-" + fog_mode + "-home", {"private": true, "zoom": 2.4})
		var changed: int = _difference(absent, present)
		_checks.append({"check": "day-foreign-" + fog_mode + "-invariant", "passed": changed == 0, "changed_pixels": changed})
		if changed != 0:
			_fail("Foreign daytime window/head revealed hidden presence.")
			return


func _look_hashes() -> Dictionary:
	var result: Dictionary = _life_hashes()
	for path: String in [get_script().resource_path, Life.LOOK_MANIFEST, Life.LOOK_MANIFEST.get_base_dir().path_join("center.png"), Life.LOOK_MANIFEST.get_base_dir().path_join("left.png"), Life.LOOK_MANIFEST.get_base_dir().path_join("right.png")]:
		result[path] = FileAccess.get_sha256(path)
	return result
