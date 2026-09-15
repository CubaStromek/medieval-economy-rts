extends "res://tests/sawmill_life_game_runner.gd"

## Normal menu/Relief/logistics/schedule/save path. Only UI, camera, playback
## speed and isolated temporary save destinations are changed by this runner.
## The inherited capture helpers observe real rendered frames. Work footage
## buffers raw viewport images at 1x and compresses PNGs after playback stops.
var _motion_frames: Array[Dictionary] = []
var _motion_images: Array[Image] = []
var _motion_report: Dictionary = {}
var _natural_log_deliveries: Array[Dictionary] = []

func _ready() -> void:
	output_path = QaAssets.output_path(true, "natural")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")
	DirAccess.make_dir_recursive_absolute(output_path)
	_mute_music_bus_only()
	if DisplayServer.get_name() == "headless":
		failures.append("Native renderer required for normal-game operation evidence")
		_finish()
		return
	session = SessionScene.instantiate()
	session.honor_launch_arguments = false
	var slot: String = OS.get_temp_dir().path_join("sawmill_operation_%d" % OS.get_process_id())
	session.save_path = slot + ".json"
	session.region_save_path = slot + "_region.json"
	add_child(session)
	await _settle()
	_expect(session.game == null,"Actual startup enters main menu")
	await _capture("00-menu",{})
	if not await _press_menu_button("NewGameButton"):
		_finish()
		return
	var picker: OptionButton = session.menu.find_child("MapPicker",true,false) as OptionButton
	_expect(picker != null and picker.item_count > 1,"Actual map picker exposes Relief")
	if picker == null:
		_finish()
		return
	picker.select(1)
	picker.item_selected.emit(1)
	await _capture("01-map-selection",{})
	if not await _press_menu_button("StartMapButton") or session.game == null:
		failures.append("Actual Start button did not open game")
		_finish()
		return
	game = session.game
	game._set_simulation_speed(0.0)
	game.set_process(false)
	_expect(game.demo_kind == "relief","Normal path loads the authored Relief scenario")
	for worker: Dictionary in game.world.workers.values():
		if worker.get("type") == "carpenter" and int(worker.get("home_id",0)) != 0:
			worker_id = int(worker["id"])
			home_id = int(worker["home_id"])
			break
	_expect(worker_id != 0 and home_id != 0,"Authored Relief carpenter and sawmill exist")
	if worker_id == 0:
		_finish()
		return
	var building: Dictionary = game.world.buildings[home_id]
	_expect(building["type"] == "sawmill" and not game.building_sprite_presentation(building).is_empty(),"Normal path loads production sawmill bitmap")
	var initial_art: Dictionary = _operation_art_snapshot()
	_expect(bool(initial_art.get("available",false)),"Normal path loads authored operation manifest and actual imported layers")
	if not bool(initial_art.get("available",false)):
		_finish()
		return
	_check_drawn_operation("initial")
	await _record("initial",1.0)
	game.set_process(true)
	game._set_simulation_speed(4.0)
	var started: int = Time.get_ticks_msec()
	var last_logs: int = int(building["inputs"].get("log",0))
	while game.world.tick < 3000 and Time.get_ticks_msec() - started < 180000:
		await get_tree().process_frame
		var logs: int = int(building["inputs"].get("log",0))
		if logs > last_logs:
			_natural_log_deliveries.append({"tick":game.world.tick,"before":last_logs,"after":logs})
		last_logs = logs
		var life: Dictionary = game.building_life_presentation(building)
		if life.get("rest_visible",false) and not phases.has("day-rest"):
			_expect(_worker_entry().is_empty(),"Resting carpenter has no duplicate outside sprite")
			_expect(game.production_building_life.rest_rect(life).has_area(),"Normal rest actually loads its sprite")
			_check_drawn_operation("day-rest")
			await _record("day-rest",2.4)
		if life.get("active_work",false) and not phases.has("actual-production"):
			_expect(not life["rest_visible"],"Productive worker excludes the resting figure")
			_check_drawn_operation("actual-production")
			await _record("actual-production",2.4)
			await _record_work_motion()
			# The burst may contain output delivery; keep following this same
			# world rather than restoring any manufactured pre-burst state.
			last_logs = int(building["inputs"].get("log",0))
		if phases.has("actual-production") and int(building["outputs"].get("plank",0)) >= 2 and not phases.has("produced-planks"):
			_check_drawn_operation("produced-planks")
			await _record("produced-planks",2.4)
		if phases.has("day-rest") and phases.has("produced-planks"):
			break
	_expect(phases.has("day-rest") and phases.has("actual-production") and phases.has("produced-planks"),"Real carrier logistics and carpenter batch reach rest, work and two-plank output")
	game._set_simulation_speed(0.0)
	game.set_process(false)
	var before: Dictionary = _snapshot()
	_expect(game._save_game(),"Isolated save succeeds")
	game._load_game()
	await _settle()
	var after: Dictionary = _snapshot()
	_expect(before["tick"] == after["tick"] and before["inputs"] == after["inputs"]
		and before["outputs"] == after["outputs"] and before["process_remaining"] == after["process_remaining"],"Load retains real inventory and partially processed batch")
	_expect(before["operation_art"] == after["operation_art"],"Load reconstructs identical actual layer selection, quantities and loaded worker/log state")
	_check_drawn_operation("loaded")
	await _record("loaded",2.4)
	_finish()

func _snapshot() -> Dictionary:
	var result: Dictionary = super._snapshot()
	if result.is_empty():
		return result
	result["operation"] = game.building_operation_presentation(game.world.buildings[home_id])
	result["operation_art"] = _operation_art_snapshot()
	return result

func _operation_art_snapshot() -> Dictionary:
	var art: Dictionary = game.building_operation_art_presentation(game.world.buildings[home_id])
	if art.is_empty():
		return {"available":false}
	var data: Dictionary = art["data"]
	var work: Dictionary = data["work"]
	var log_path: String = String(data["stock"]["log"]["texture"])
	var plank_path: String = String(data["stock"]["plank"]["texture"])
	var process_path: String = String(work.get("log",{}).get("texture",""))
	var paths: Array[String] = []
	var logs: int = 0
	var planks: int = 0
	var in_process: bool = false
	var worker: bool = false
	var loaded: bool = true
	for layer: Dictionary in art["layers"]:
		var path: String = String(layer["path"])
		paths.append(path)
		logs += 1 if path == log_path else 0
		planks += 1 if path == plank_path else 0
		in_process = in_process or path == process_path
		worker = worker or path in work["frames"]
		loaded = loaded and layer["texture"] is Texture2D and (layer["texture"] as Texture2D).get_size().x > 0 \
			and (layer["rect"] as Rect2).has_area() and (layer["mask"] as BitMap).get_true_bit_count() > 0
	return {"available":true,"all_layers_loaded":loaded,"layer_paths":paths,
		"drawn_logs":logs,"drawn_planks":planks,"in_process_log_drawn":in_process,
		"working_sprite_drawn":worker,"frame_index":art["frame_index"],
		"fallback_label_count":(art["fallback_labels"] as Array).size()}

func _check_drawn_operation(label: String) -> void:
	var building: Dictionary = game.world.buildings[home_id]
	var operation: Dictionary = game.building_operation_presentation(building)
	var art: Dictionary = _operation_art_snapshot()
	_expect(bool(art.get("available",false)) and bool(art.get("all_layers_loaded",false)),label+": actual loaded operation layers")
	if not bool(art.get("available",false)):
		return
	_expect(int(art["drawn_logs"]) == int(building["inputs"].get("log",0)) \
		and int(art["drawn_planks"]) == int(building["outputs"].get("plank",0)),label+": drawn stock quantities match real inventories")
	_expect(bool(art["in_process_log_drawn"]) == bool(operation["in_process"]),label+": committed log follows actual unfinished batch")
	_expect(bool(art["working_sprite_drawn"]) == bool(operation["active_work"]),label+": loaded worker frame follows productive activity")
	_expect(int(art["fallback_label_count"]) == 0,label+": supported stock uses artwork, not fallback text")

func _record_work_motion() -> void:
	var old_speed: float = game.simulation_speed
	game._set_simulation_speed(1.0)
	# The camera has just been settled by _record. No capture-induced pauses,
	# manual ticks, altered clocks, PNG encoding or fabricated interpolation
	# occur during this interval. GPU readback cost is measured and reported.
	var start_us: int = Time.get_ticks_usec()
	var next_us: int = start_us
	var deadline_us: int = start_us + 3500000
	var observed_frames: Dictionary = {}
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
		_motion_images.append(pixels)
		_motion_frames.append({"file":"work-motion/%03d.png" % _motion_frames.size(),
			"wall_microseconds":captured_us,"elapsed_seconds":float(captured_us-start_us)/1000000.0,
			"simulation_seconds":float(game.world.tick)*0.1+float(game.accumulator),
			"readback_microseconds":read_done_us-read_start_us,"simulation_speed":game.simulation_speed,"state":state})
		if bool(state["operation_art"].get("working_sprite_drawn",false)):
			observed_frames[int(state["operation_art"]["frame_index"])] = true
		# Drop missed sampling slots instead of recording catch-up duplicates.
		next_us = start_us + (int((read_done_us-start_us)/100000)+1)*100000
	game._set_simulation_speed(0.0)
	_expect(_motion_frames.size() >= 28,"Normal 1x work capture obtains approximately 10 frames/s for 3.5 seconds")
	_expect(observed_frames.size() >= 4,"Normal work playback visibly selects multiple loaded authored frames")
	var first: Dictionary = _motion_frames.front() if not _motion_frames.is_empty() else {}
	var last: Dictionary = _motion_frames.back() if not _motion_frames.is_empty() else {}
	_motion_report = {"requested_duration_seconds":3.5,"requested_sample_interval_seconds":0.1,
		"png_compression_during_playback":false,"manual_tick_during_playback":false,
		"distinct_loaded_work_frames":observed_frames.keys(),"frame_count":_motion_frames.size()}
	if not first.is_empty():
		_motion_report["observed_wall_seconds"] = float(last["wall_microseconds"]-first["wall_microseconds"])/1000000.0
		_motion_report["observed_simulation_seconds"] = float(last["simulation_seconds"])-float(first["simulation_seconds"])
		_expect(float(_motion_report["observed_wall_seconds"]) >= 3.0,"Recorded work spans at least three actual seconds")
	_flush_work_motion()
	game._set_simulation_speed(old_speed)

func _flush_work_motion() -> void:
	DirAccess.make_dir_recursive_absolute(output_path.path_join("work-motion"))
	for index: int in range(_motion_images.size()):
		var path: String = output_path.path_join(String(_motion_frames[index]["file"]))
		_expect(_motion_images[index].save_png(path) == OK,"Buffered normal-play frame writes after capture")
		_motion_frames[index]["sha256"] = FileAccess.get_sha256(path)
	_motion_images.clear()

func _finish() -> void:
	var hashes: Dictionary = {}
	for resource: String in ["res://scripts/view/main_view.gd","res://scripts/view/sawmill_sprite_library.gd",
		"res://scripts/view/production_building_life.gd","res://scripts/view/sawmill_operation.gd",
		"res://scripts/view/sawmill_operation_art.gd",get_script().resource_path,"res://tests/sawmill_qa_assets.gd"]:
		hashes[resource] = FileAccess.get_sha256(resource)
	hashes.merge(QaAssets.asset_hashes())
	var report: Dictionary = {"date":Time.get_datetime_string_from_system(),"engine":Engine.get_version_info()["string"],
		"scenario":"actual menu -> authored Relief -> actual carrier/log batch -> working animation at1x -> output -> isolated save/load",
		"synthetic_worker_or_stock_or_clock_states":false,
		"player_saves_accessed":false,"music":music_status,"hashes":hashes,"phases":phases,"captures":captures,
		"natural_input_increases":_natural_log_deliveries,"motion":_motion_report,"motion_frames":_motion_frames,"failures":failures}
	var file := FileAccess.open(output_path.path_join("report.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t")+"\n")
	for failure: String in failures:
		printerr(failure)
	print("SAWMILL OPERATION NATURAL QA: %d phases, %d captures, %d motion frames, %d failures" % [phases.size(),captures.size(),_motion_frames.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
