extends "res://tests/sawmill_operation_game_runner.gd"

## Actual menu and authored Relief economy. This runner changes only UI,
## camera, playback speed and temporary save destinations. No worker, stock,
## clock or work state is manufactured, and no simulation tick is stepped here.
const IDLE_DURATION_SECONDS := 12.0
const IDLE_SAMPLE_MICROSECONDS := 66667
const EXPECTED_FIRST_LOG_TICK := 234
const DEFAULT_IDLE_OUTPUT := "res://../docs/art/qa/carpenter-idle-v1/natural"

var _idle_images: Array[Image] = []
var _idle_frames: Array[Dictionary] = []
var _idle_report: Dictionary = {}
var _pause_report: Dictionary = {}
var _idle_zoom := 2.4
var _first_idle_tick := -1
var _first_work_tick := -1
var _fixed_rect := Rect2()
var _fixed_foot := Vector2.ZERO
var _fixed_screen_foot := Vector2.ZERO
var _idle_body_crop := Rect2i()


func _ready() -> void:
	output_path = ProjectSettings.globalize_path(DEFAULT_IDLE_OUTPUT).simplify_path()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--zoom="):
			_idle_zoom = clampf(argument.trim_prefix("--zoom=").to_float(), 1.0, 4.0)
	DirAccess.make_dir_recursive_absolute(output_path)
	_mute_music_bus_only()
	if DisplayServer.get_name() == "headless":
		failures.append("Native renderer required for real carpenter idle evidence")
		_finish()
		return
	session = SessionScene.instantiate()
	session.honor_launch_arguments = false
	var slot: String = OS.get_temp_dir().path_join("carpenter_idle_%d" % OS.get_process_id())
	session.save_path = slot + ".json"
	session.region_save_path = slot + "_region.json"
	add_child(session)
	await _settle()
	_expect(session.game == null, "Actual startup enters main menu")
	await _capture("00-menu", {})
	if not await _press_menu_button("NewGameButton"):
		_finish()
		return
	var picker: OptionButton = session.menu.find_child("MapPicker", true, false) as OptionButton
	_expect(picker != null and picker.item_count > 1, "Actual map picker exposes Relief")
	if picker == null:
		_finish()
		return
	picker.select(1)
	picker.item_selected.emit(1)
	await _capture("01-map-selection", {})
	if not await _press_menu_button("StartMapButton") or session.game == null:
		failures.append("Actual Start button did not open game")
		_finish()
		return
	game = session.game
	game._set_simulation_speed(0.0)
	_expect(game.demo_kind == "relief", "Normal path loads authored Relief")
	for worker: Dictionary in game.world.workers.values():
		if worker.get("type") == "carpenter" and int(worker.get("home_id", 0)) != 0:
			worker_id = int(worker["id"])
			home_id = int(worker["home_id"])
			break
	_expect(worker_id != 0 and home_id != 0, "Authored carpenter and sawmill exist")
	if worker_id == 0:
		_finish()
		return
	var building: Dictionary = game.world.buildings[home_id]
	_expect(not game.building_sprite_presentation(building).is_empty(), "Normal path loads production house")
	_check_drawn_operation("initial")
	await _record("initial", 1.0)
	game._set_simulation_speed(1.0)
	var deadline_ms: int = Time.get_ticks_msec() + 90000
	var last_logs: int = int(building["inputs"].get("log", 0))
	while int(game.world.tick) < 1000 and Time.get_ticks_msec() < deadline_ms:
		await get_tree().process_frame
		var logs: int = int(building["inputs"].get("log", 0))
		if logs > last_logs:
			_natural_log_deliveries.append({"tick": game.world.tick, "before": last_logs, "after": logs})
		last_logs = logs
		var life: Dictionary = game.building_life_presentation(building)
		if bool(life.get("rest_visible", false)) and _first_idle_tick < 0:
			_first_idle_tick = int(game.world.tick)
			_expect(int(building["inputs"].get("log", 0)) == 0 and int(building["process_remaining"]) == 0,
				"Initial idle precedes any delivered log or committed batch")
			_expect(_first_idle_tick + ceili(IDLE_DURATION_SECONDS / MainViewClass.FIXED_TICK_SECONDS) < EXPECTED_FIRST_LOG_TICK,
				"Authored initial idle leaves twelve seconds before the known first delivery")
			await _record("day-rest", _idle_zoom)
			await _record_idle_motion()
			if not bool(game.building_life_presentation(building).get("rest_visible", false)):
				failures.append("Initial rest ended before the uninterrupted idle burst completed")
				break
			await _prove_pause()
			game._set_simulation_speed(1.0)
		if bool(life.get("active_work", false)):
			_first_work_tick = int(game.world.tick)
			_check_drawn_operation("actual-production")
			_expect(not bool(life.get("rest_visible", false)), "Real work onset removes idle animation")
			await _record("actual-production", _idle_zoom)
			break
	game._set_simulation_speed(0.0)
	_expect(_first_idle_tick >= 0 and _first_work_tick > _first_idle_tick, "Same real world reaches indoor rest and then productive work")
	_expect(not _natural_log_deliveries.is_empty(), "A real carrier delivery precedes productive work")
	_expect(session != null and not FileAccess.file_exists(session.save_path) and not FileAccess.file_exists(session.region_save_path),
		"Neither player saves nor even the isolated temporary save destinations were written")
	_finish()


func _snapshot() -> Dictionary:
	var state: Dictionary = super._snapshot()
	if state.is_empty():
		return state
	var life: Dictionary = game.building_life_presentation(game.world.buildings[home_id])
	var rect: Rect2 = game.production_building_life.rest_rect(life)
	state["simulation_seconds"] = float(game.world.tick) * MainViewClass.FIXED_TICK_SECONDS + float(game.accumulator)
	state["life_time_seconds"] = float(life.get("time_seconds", 0.0))
	state["simulation_speed"] = game.simulation_speed
	state["rest_rect_world"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	state["camera_zoom"] = game.camera.zoom.x
	if rect.has_area():
		var foot: Vector2 = _rest_foot(life)
		var screen: Vector2 = game.get_global_transform_with_canvas() * foot
		state["rest_foot_world"] = [foot.x, foot.y]
		state["rest_foot_screen"] = [screen.x, screen.y]
	# The runtime may expose additional view-only breathing/shoulder geometry.
	# Keep this runner usable while that independent implementation is authored.
	if game.production_building_life.has_method("rest_motion_for"):
		state["rest_motion"] = _json_geometry(game.production_building_life.call("rest_motion_for", life))
	return state


func _record_idle_motion() -> void:
	game._set_simulation_speed(0.0)
	await _settle()
	await RenderingServer.frame_post_draw
	var life: Dictionary = game.building_life_presentation(game.world.buildings[home_id])
	_fixed_rect = game.production_building_life.rest_rect(life)
	_expect(_fixed_rect.has_area(), "Actually loaded idle asset has a native draw rectangle")
	if not _fixed_rect.has_area():
		return
	_fixed_foot = _rest_foot(life)
	_fixed_screen_foot = game.get_global_transform_with_canvas() * _fixed_foot
	var screen_rect: Rect2 = game.get_global_transform_with_canvas() * _fixed_rect
	_idle_body_crop = Rect2i(screen_rect.grow(4.0))
	game._set_simulation_speed(1.0)
	var start_us: int = Time.get_ticks_usec()
	var next_us: int = start_us
	var deadline_us: int = start_us + int(IDLE_DURATION_SECONDS * 1000000.0)
	var look_keys: Dictionary = {}
	var motion_offsets: Dictionary = {}
	var uninterrupted: bool = true
	var stable_ground: bool = true
	while Time.get_ticks_usec() <= deadline_us:
		await get_tree().process_frame
		if Time.get_ticks_usec() < next_us:
			continue
		await RenderingServer.frame_post_draw
		var captured_us: int = Time.get_ticks_usec()
		var state: Dictionary = _snapshot()
		var read_start_us: int = Time.get_ticks_usec()
		var pixels: Image = get_viewport().get_texture().get_image()
		var read_done_us: int = Time.get_ticks_usec()
		_idle_images.append(pixels)
		_idle_frames.append({"file": "idle-motion/%03d.png" % _idle_frames.size(),
			"wall_microseconds": captured_us, "elapsed_seconds": float(captured_us - start_us) / 1000000.0,
			"simulation_seconds": state["simulation_seconds"], "readback_microseconds": read_done_us - read_start_us,
			"simulation_speed": game.simulation_speed, "state": state})
		life = game.building_life_presentation(game.world.buildings[home_id])
		uninterrupted = uninterrupted and bool(life.get("rest_visible", false)) and not bool(life.get("active_work", false)) \
			and int(state["inputs"].get("log", 0)) == 0 and int(state["process_remaining"]) == 0 \
			and not bool(state["outdoor_sprite_present"]) and is_equal_approx(float(game.simulation_speed), 1.0)
		stable_ground = stable_ground and game.production_building_life.rest_rect(life) == _fixed_rect \
			and _rest_foot(life).is_equal_approx(_fixed_foot) \
			and (game.get_global_transform_with_canvas() * _rest_foot(life)).is_equal_approx(_fixed_screen_foot)
		look_keys[String(state["life"]["pose"])] = true
		var motion: Dictionary = state.get("rest_motion", {})
		if motion.has("source_offset"):
			motion_offsets[JSON.stringify(motion["source_offset"])] = true
		if not uninterrupted:
			break
		# Skip missed slots rather than adding catch-up duplicates. No image
		# encoding, clock stepping, state restoration or capture pause occurs.
		next_us = start_us + (int((read_done_us - start_us) / IDLE_SAMPLE_MICROSECONDS) + 1) * IDLE_SAMPLE_MICROSECONDS
	game._set_simulation_speed(0.0)
	_idle_report = {"requested_duration_seconds": IDLE_DURATION_SECONDS,
		"requested_sample_interval_seconds": float(IDLE_SAMPLE_MICROSECONDS) / 1000000.0,
		"frame_count": _idle_frames.size(), "png_compression_during_playback": false, "manual_ticks": false,
		"uninterrupted_real_idle": uninterrupted, "ground_and_registration_fixed": stable_ground,
		"observed_head_looks": look_keys.keys(), "distinct_exposed_body_offsets": motion_offsets.size(),
		"camera_zoom": game.camera.zoom.x, "requested_camera_zoom": _idle_zoom,
		"body_crop_viewport": [_idle_body_crop.position.x, _idle_body_crop.position.y, _idle_body_crop.size.x, _idle_body_crop.size.y]}
	if not _idle_frames.is_empty():
		var first: Dictionary = _idle_frames.front()
		var last: Dictionary = _idle_frames.back()
		_idle_report["observed_wall_seconds"] = float(last["wall_microseconds"] - first["wall_microseconds"]) / 1000000.0
		_idle_report["observed_simulation_seconds"] = float(last["simulation_seconds"]) - float(first["simulation_seconds"])
		_expect(float(_idle_report["observed_wall_seconds"]) >= 11.5 and float(_idle_report["observed_simulation_seconds"]) >= 11.5,
			"Uninterrupted idle covers approximately twelve actual and simulation seconds")
	_expect(_idle_frames.size() >= 135, "Normal twelve-second capture records approximately fifteen real frames per second")
	_expect(uninterrupted, "Entire burst remains actual indoor idle before first log delivery")
	_expect(stable_ground, "Draw rectangle, world foot and native screen foot stay fixed while upper body moves")
	_expect(look_keys.has("left") and look_keys.has("center") and look_keys.has("right"), "Existing left/center/right glances survive the idle cycle")
	_expect(motion_offsets.size() >= 3, "Actual enabled idle renderer exposes changing breathing/shoulder offsets")
	_flush_idle_images()


func _prove_pause() -> void:
	# Use the actual pause action. The preceding image flush happened paused;
	# return to 1x before toggling so this validates the same user-facing path.
	game._set_simulation_speed(1.0)
	game._toggle_pause()
	await _settle()
	await RenderingServer.frame_post_draw
	var first_state: Dictionary = _snapshot()
	var first_image: Image = get_viewport().get_texture().get_image()
	var started_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_ms < 700:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var second_state: Dictionary = _snapshot()
	var second_image: Image = get_viewport().get_texture().get_image()
	var crop: Rect2i = _idle_body_crop.intersection(Rect2i(Vector2i.ZERO, first_image.get_size()))
	var first_hash: String = _image_hash(first_image.get_region(crop))
	var second_hash: String = _image_hash(second_image.get_region(crop))
	_pause_report = {"wall_milliseconds": Time.get_ticks_msec() - started_ms,
		"before": first_state, "after": second_state, "body_crop_rgba_sha256_before": first_hash,
		"body_crop_rgba_sha256_after": second_hash, "native_pixels_identical": first_hash == second_hash}
	_expect(first_state == second_state, "Pause freezes simulation, glances and exposed idle geometry")
	_expect(first_hash == second_hash, "Paused native carpenter pixels remain identical")
	_expect(first_image.save_png(output_path.path_join("pause-start.png")) == OK, "Pause start frame is saved")
	_expect(second_image.save_png(output_path.path_join("pause-end.png")) == OK, "Pause end frame is saved")
	phases["paused-idle"] = second_state
	game._toggle_pause()
	_expect(is_equal_approx(float(game.simulation_speed), 1.0), "Pause resumes at actual 1x")


func _flush_idle_images() -> void:
	DirAccess.make_dir_recursive_absolute(output_path.path_join("idle-motion"))
	for index: int in range(_idle_images.size()):
		var path: String = output_path.path_join(String(_idle_frames[index]["file"]))
		_expect(_idle_images[index].save_png(path) == OK, "Buffered native idle frame writes after playback stops")
		_idle_frames[index]["sha256"] = FileAccess.get_sha256(path)
	_idle_images.clear()


func _rest_foot(life: Dictionary) -> Vector2:
	var config: Dictionary = life.get("config", {})
	var point: Array = config.get("rest_foot", [0.0, 0.0])
	return (life.get("rect", Rect2()) as Rect2).position + Vector2(float(point[0]), float(point[1])) * float(life.get("source_to_world", 0.0))


func _image_hash(pixels: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels.get_data())
	return hash.finish().hex_encode()


func _json_geometry(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Rect2 or value is Rect2i:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _json_geometry(value[key])
		return result
	if value is Array or value is PackedVector2Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_geometry(item))
		return result
	return value


func _finish() -> void:
	var hashes: Dictionary = QaAssets.asset_hashes()
	for source: String in [get_script().resource_path, "res://tests/sawmill_operation_game_runner.gd",
			"res://tests/sawmill_life_game_runner.gd", "res://scripts/view/main_view.gd",
			"res://scripts/view/production_building_life.gd", "res://scripts/view/building_worker_appearance.gd",
			"res://scripts/view/building_worker_idle.gd"]:
		hashes[source] = FileAccess.get_sha256(source)
	var report: Dictionary = {"date": Time.get_datetime_string_from_system(), "engine": Engine.get_version_info()["string"],
		"scenario": "actual menu -> authored Relief -> natural home entry -> uninterrupted idle12s at1x -> real pause -> carrier delivery -> real work onset",
		"synthetic_worker_or_stock_or_clock_states": false, "manual_simulation_ticks": false,
		"player_saves_accessed": false, "temporary_save_paths_only": true, "music": music_status,
		"first_idle_tick": _first_idle_tick, "first_work_tick": _first_work_tick, "natural_input_increases": _natural_log_deliveries,
		"hashes": hashes, "phases": phases, "captures": captures, "idle_motion": _idle_report,
		"idle_frames": _idle_frames, "pause": _pause_report, "failures": failures,
		"coverage_limit": "Natural Relief dawn and actual first idle/work. Ground registration and paused native crop are checked; upper-body motion and fixed soles still require visual review of the actual frames."}
	var file: FileAccess = FileAccess.open(output_path.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures:
		printerr(failure)
	print("CARPENTER IDLE NATURAL QA: %d idle frames, rest tick%d, work tick%d, %d failures" % [_idle_frames.size(), _first_idle_tick, _first_work_tick, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
