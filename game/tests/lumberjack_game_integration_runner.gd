extends Node

## Production menu -> authored ReliefDemo -> normal worker logistics. The runner
## changes only menu input, simulation speed and camera; it does not fabricate
## worker actions, move entities, replenish trees or load a player's save.
## Native captures are evidence for the naturally visited directions only.
const SessionScene = preload("res://scenes/game_session.tscn")
const MainViewClass = preload("res://scripts/view/main_view.gd")
const LibraryClass = preload("res://scripts/view/lumberjack_animation_library.gd")
const DEFAULT_OUTPUT := "res://../docs/art/qa/lumberjack-pixellab-game-v1/natural"

var failures: Array[String] = []
var captures: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var phases: Dictionary = {}
var natural_directions: Dictionary = {}
var session: Variant
var game: Variant
var worker_id: int = 0
var home_id: int = 0
var source_id: int = 0
var source_amount_before: int = -1
var home_output_before: int = 0
var output_path: String = ""
var capture_enabled: bool = true
var run_speed: float = 1.0
var max_ticks: int = 1800
var music_status: String = "N/A: this project has no music or audio players"
var code_sha256: Dictionary = {}
var burst_target_frames: int = 0
var burst_frames: Array[Dictionary] = []
var burst_images: Array[Image] = []
var invalid_shadow_polygons: Array[Dictionary] = []


func _ready() -> void:
	_read_arguments()
	for source: String in ["res://tests/lumberjack_game_integration_runner.gd", "res://scripts/view/main_view.gd",
			"res://scripts/view/game_session.gd", "res://scripts/view/lumberjack_presentation.gd",
			"res://scripts/view/lumberjack_animation_library.gd", "res://scripts/view/lumberjack_work_placement.gd",
			"res://scripts/view/solar_shadows.gd",
			"res://scripts/simulation/simulation_world.gd"]:
		code_sha256[source] = FileAccess.get_sha256(source)
	_mute_music_bus_only()
	if capture_enabled and DisplayServer.get_name() == "headless":
		failures.append("Native capture requires a rendered display; use --no-capture for logic only.")
		_finish()
		return
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(output_path)
	if directory_error != OK:
		failures.append("Cannot create capture directory: " + output_path)
		_finish()
		return
	session = SessionScene.instantiate()
	session.honor_launch_arguments = false
	var temporary_slot: String = OS.get_temp_dir().path_join("lumberjack_integration_%d" % OS.get_process_id())
	session.save_path = temporary_slot + ".json"
	session.region_save_path = temporary_slot + "_region.json"
	add_child(session)
	await _settle()
	_expect(session.game == null, "Startup must enter the real main menu before creating a world.")
	await _capture("00-main-menu", {})
	if not await _press_menu_button("NewGameButton"):
		_finish()
		return
	var picker: OptionButton = session.menu.find_child("MapPicker", true, false) as OptionButton
	if picker == null or picker.item_count < 2:
		failures.append("Production map picker must contain the authored Relief scenario.")
		_finish()
		return
	picker.select(1)
	picker.item_selected.emit(1)
	await _capture("01-map-selection", {"map_id": "relief"})
	if not await _press_menu_button("StartMapButton") or session.game == null:
		failures.append("Production Start button must create a game.")
		_finish()
		return
	game = session.game
	game._set_simulation_speed(0.0)
	_expect(game.demo_kind == "relief" and not session.menu.visible, "Normal menu must open Relief and close itself.")
	_expect(game.world.grid.size == Vector2i(28, 22), "Relief must retain its authored map dimensions.")
	_expect(game.lumberjack_sprites.is_ready(), "Production view must load the actual animation package.")
	_expect(game.lumberjack_sprites.errors.is_empty() and game.lumberjack_sprites.warnings.is_empty(),
		"Production animation package must load without reader errors or warnings.")
	for worker: Dictionary in game.world.workers.values():
		if worker.get("type") == "lumberjack" and int(worker.get("home_id", 0)) != 0:
			worker_id = int(worker["id"])
			home_id = int(worker["home_id"])
			break
	if worker_id == 0 or not game.world.buildings.has(home_id):
		failures.append("Authored Relief must provide a lumberjack with its own completed hut.")
		_finish()
		return
	var home: Dictionary = game.world.buildings[home_id]
	_expect(home.get("type") == "lumber_hut" and game.world.is_building_complete(home),
		"The real worker's home must be a completed lumber hut.")
	home_output_before = int(home.get("outputs", {}).get("log", 0))
	await _capture("02-relief-overview", _snapshot())
	game._set_simulation_speed(run_speed)
	await _observe_real_cycle()
	game._set_simulation_speed(0.0)
	_flush_burst_images()
	if burst_target_frames > 0:
		_expect(burst_frames.size() == burst_target_frames, "Actual chop must produce the requested number of rendered burst observations.")
	for required: String in ["walk_axe", "chop-start", "chop-middle", "picked-log", "walk_log", "delivered"]:
		_expect(phases.has(required), "Real simulation must reach " + required + ".")
	_expect(not FileAccess.file_exists(session.save_path) and not FileAccess.file_exists(session.region_save_path),
		"This read-only scenario must not write even its isolated temporary save slots.")
	_finish()


func _observe_real_cycle() -> void:
	var started_at_ms: int = Time.get_ticks_msec()
	var last_tick: int = -1
	var had_log: bool = false
	while int(game.world.tick) < max_ticks and Time.get_ticks_msec() - started_at_ms < 240000:
		await get_tree().process_frame
		_check_actual_shadow_geometry()
		if capture_enabled and phases.has("chop-start") and burst_frames.size() < burst_target_frames:
			await _capture_chop_burst_frame()
		if int(game.world.tick) == last_tick:
			continue
		last_tick = int(game.world.tick)
		var worker: Dictionary = game.world.workers.get(worker_id, {})
		if worker.is_empty():
			failures.append("The tracked authored lumberjack disappeared before delivery.")
			return
		if source_id == 0 and worker.get("action") == "harvest" and game.world.trees.has(int(worker.get("source_id", 0))):
			source_id = int(worker["source_id"])
			source_amount_before = int(game.world.trees[source_id]["amount"])
		var snapshot: Dictionary = _snapshot()
		observations.append(snapshot)
		var pose: Dictionary = snapshot.get("presentation", {})
		var direction: String = String(pose.get("direction", ""))
		if not direction.is_empty():
			natural_directions[direction] = true
		var carrying: bool = worker.get("carrying") == "log"
		if not phases.has("walk_axe") and bool(pose.get("moving", false)) and worker.get("action") == "harvest" and not carrying:
			_expect(pose.get("clip") == "walk_axe", "Real outward movement must select walk_axe.")
			await _record_phase("walk_axe")
		if bool(pose.get("chopping", false)):
			_expect(pose.get("clip") == "chop" and worker.get("state") == "working" and worker.get("action") == "harvest"
				and int(worker.get("work_remaining", 0)) > 0, "Chop must follow actual unfinished harvest work.")
			if not phases.has("chop-start"):
				await _record_phase("chop-start")
			elif not phases.has("chop-middle") and float(pose.get("work_progress", 0.0)) >= 0.42:
				await _record_phase("chop-middle")
			elif not phases.has("chop-end") and float(pose.get("work_progress", 0.0)) >= 0.78:
				await _record_phase("chop-end")
		if carrying and not had_log:
			had_log = true
			_expect(source_id != 0 and source_amount_before >= 1, "Pickup must originate from the tracked real tree.")
			_expect(int(snapshot["tree_amount"]) == source_amount_before - 1, "Picking up a log must consume exactly one from the real tree.")
			_expect(pose.get("clip") == "walk_log" and pose.get("renders_cargo") == "log", "Actual pickup must retain the log in the selected sprite.")
			await _record_phase("picked-log")
		if carrying and bool(pose.get("moving", false)) and not phases.has("walk_log"):
			_expect(pose.get("clip") == "walk_log", "Actual return movement must select walk_log.")
			_expect(MainViewClass.worker_sprite_contains_cargo(worker, _presentation()), "Log sprite must suppress the separate generic cargo marker.")
			await _record_phase("walk_log")
		if had_log and not carrying and int(worker.get("inside_building_id", 0)) == home_id:
			_expect(int(snapshot["home_log_output"]) == home_output_before + 1,
				"Real delivery must add one output log to the worker's own hut.")
			_expect(not bool(snapshot["draw_entry_present"]), "Indoors, the actual worker must leave the draw list.")
			await _record_phase("delivered")
			return
		if last_tick % 100 == 0:
			print("LUMBERJACK REAL CYCLE: tick %d, %s/%s, carrying=%s" % [last_tick, worker.get("state"), worker.get("action"), worker.get("carrying")])
	failures.append("Timed out before the authored worker completed a real harvest and hut delivery.")


func _record_phase(phase: String) -> void:
	var previous_speed: float = game.simulation_speed
	game._set_simulation_speed(0.0)
	var before: Dictionary = _snapshot()
	phases[phase] = before
	print("LUMBERJACK REAL CYCLE: %s at tick %d" % [phase, game.world.tick])
	var focus: Vector2 = _worker_foot()
	if phase == "delivered":
		focus = game.terrain_renderer.cell_center(game.world.buildings[home_id]["position"] as Vector2i)
	for zoom: float in [1.0, 2.4]:
		game._set_zoom(zoom)
		game.camera.position = focus - (game._camera_map_rect().get_center() - game.get_viewport_rect().size * 0.5) / zoom
		game.camera.reset_smoothing()
		game.camera.force_update_scroll()
		await _capture("%02d-%s-%s" % [phases.size() + 2, phase, "1x" if zoom == 1.0 else "2_4x"], _snapshot())
	var after: Dictionary = _snapshot()
	_expect(before["tick"] == after["tick"] and before["presentation"].get("frame_index") == after["presentation"].get("frame_index"),
		"Pausing for %s must freeze both real simulation and animation." % phase)
	game._set_simulation_speed(previous_speed)


func _snapshot() -> Dictionary:
	if game == null or worker_id == 0:
		return {}
	var worker: Dictionary = game.world.workers[worker_id]
	var pose: Dictionary = _presentation()
	var retained_pose: Dictionary = {}
	for key: String in ["animated_lumberjack", "clip", "direction", "frame_index", "frame_count", "fps", "moving", "chopping", "work_progress", "renders_cargo", "flip_h"]:
		if pose.has(key):
			retained_pose[key] = pose[key]
	var entry: Dictionary = _worker_entry()
	var foot: Vector2 = _worker_foot()
	var screen_foot: Vector2 = game.get_global_transform_with_canvas() * foot
	var retained_worker: Dictionary = {}
	for key: String in ["id", "type", "home_id", "state", "action", "carrying", "source_id", "destination_id", "work_remaining", "inside_building_id", "visual_progress_ticks", "visual_duration_ticks"]:
		retained_worker[key] = worker.get(key)
	for key: String in ["position", "previous_position"]:
		var cell: Vector2i = worker[key] as Vector2i
		retained_worker[key] = [cell.x, cell.y]
	return {"tick": int(game.world.tick), "worker": retained_worker,
		"presentation": retained_pose, "draw_entry_present": not entry.is_empty(),
		"ground_position": _vector_array(entry.get("ground_position", Vector2(worker["position"] as Vector2i))),
		"contact_ground_position": _vector_array(entry.get("contact_ground_position", entry.get("ground_position", Vector2(worker["position"] as Vector2i)))),
		"shadow_ground_position": _vector_array(entry.get("shadow_ground_position", entry.get("ground_position", Vector2(worker["position"] as Vector2i)))),
		"foot_world": [foot.x, foot.y], "foot_screen": [screen_foot.x, screen_foot.y],
		"camera_zoom": game.camera.zoom.x, "accumulator": game.accumulator,
		"tree_id": source_id, "tree_amount": int(game.world.trees.get(source_id, {}).get("amount", 0)),
		"home_log_output": int(game.world.buildings[home_id].get("outputs", {}).get("log", 0))}


func _worker_entry() -> Dictionary:
	for entry: Dictionary in game._world_draw_entries():
		if entry.get("kind") == "worker" and int(entry.get("id", 0)) == worker_id:
			return entry
	return {}


func _worker_foot() -> Vector2:
	var entry: Dictionary = _worker_entry()
	if not entry.is_empty():
		return entry["position"] as Vector2
	return game.terrain_renderer.cell_center(game.world.workers[worker_id]["position"] as Vector2i)


func _presentation() -> Dictionary:
	if _worker_entry().is_empty():
		return {}
	return game.worker_presentation(game.world.workers[worker_id], _worker_foot())


func _capture(label: String, metadata: Dictionary) -> void:
	await _settle()
	if not capture_enabled:
		return
	if game != null:
		game.queue_redraw()
	await RenderingServer.frame_post_draw
	# Camera smoothing/stretch may change screen coordinates while the scene
	# settles. Capture metadata from the same completed frame as its pixels.
	if game != null and worker_id != 0:
		metadata = _snapshot()
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = output_path.path_join(label + ".png")
	_expect(image != null and not image.is_empty(), "Capture must contain actual rendered pixels: " + label)
	if image == null or image.is_empty():
		return
	_expect(image.save_png(path) == OK, "Capture must write a lossless PNG: " + label)
	captures.append({"file": label + ".png", "sha256": FileAccess.get_sha256(path),
		"width": image.get_width(), "height": image.get_height(),
		"viewport_size": _vector_array(get_viewport().get_visible_rect().size),
		"foot_screen_coordinates": "viewport canvas coordinates, before window stretch", "state": metadata})


func _capture_chop_burst_frame() -> void:
	if not bool(_presentation().get("chopping", false)):
		return
	# Observe real presented frames at the normal simulation speed. Never step
	# ticks manually, freeze work, or synthesize missing frames for the burst.
	await RenderingServer.frame_post_draw
	var state: Dictionary = _snapshot()
	if not bool(state["presentation"].get("chopping", false)):
		return
	var filename: String = "chop-burst/%03d.png" % burst_frames.size()
	var image: Image = get_viewport().get_texture().get_image()
	# PNG compression during playback is expensive enough to miss work phases.
	# Keep rendered pixels temporarily; encode them only after the real cycle.
	burst_images.append(image)
	burst_frames.append({"file": filename,
		"simulation_seconds": float(game.world.tick) * 0.1 + float(game.accumulator),
		"wall_milliseconds": Time.get_ticks_msec(), "state": state})


func _flush_burst_images() -> void:
	if burst_images.is_empty():
		return
	_expect(DirAccess.make_dir_recursive_absolute(output_path.path_join("chop-burst")) == OK,
		"Burst directory must be writable.")
	for index: int in range(burst_images.size()):
		var path: String = output_path.path_join(String(burst_frames[index]["file"]))
		_expect(burst_images[index].save_png(path) == OK, "Actual burst frame must save: " + path)
		burst_frames[index]["sha256"] = FileAccess.get_sha256(path)
	burst_images.clear()


func _check_actual_shadow_geometry() -> void:
	# Inspect the actual retained polygons sent to the production CanvasItem,
	# so a zero-triangle runtime error cannot hide behind a passing work cycle.
	for row: Variant in game._row_shadows:
		for shadow: Dictionary in game._row_shadows[row]:
			if not game._fog_entry_visible(String(shadow["kind"]), shadow["state"]):
				continue
			var points: PackedVector2Array = shadow.get("draw_points", shadow["points"])
			if Geometry2D.triangulate_polygon(points).is_empty():
				_expect(false, "Actual production shadow polygon must triangulate.")
				var coordinates: Array = []
				for point: Vector2 in points:
					coordinates.append(_vector_array(point))
				var map_coordinates: Array = []
				for point: Vector2 in shadow["points"]:
					map_coordinates.append(_vector_array(point))
				var entity_id: int = int(shadow.get("state", {}).get("id", 0))
				var record: Dictionary = {"tick": int(game.world.tick), "accumulator": game.accumulator,
					"row": row, "kind": shadow.get("kind"), "entity_id": entity_id,
					"points": map_coordinates, "draw_points": coordinates,
					"draw_origin": _vector_array(shadow.get("draw_origin", Vector2.ZERO))}
				for entry: Dictionary in game._world_draw_entries():
					if entry.get("kind") == shadow.get("kind") and int(entry.get("id", 0)) == entity_id:
						for key: String in ["ground_position", "contact_ground_position", "shadow_ground_position", "visual_ground_position", "position"]:
							if entry.has(key):
								record[key] = _vector_array(entry[key])
				invalid_shadow_polygons.append(record)


func _press_menu_button(node_name: String) -> bool:
	var button: Button = session.menu.find_child(node_name, true, false) as Button
	if button == null or not button.is_visible_in_tree() or button.disabled:
		failures.append("Production menu button unavailable: " + node_name)
		return false
	var position: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		get_viewport().push_input(event, true)
	await _settle()
	return true


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _mute_music_bus_only() -> void:
	# No audio is implemented in this project today. Honor a future dedicated
	# music bus without muting Master or changing sound-effect preferences.
	for index: int in range(AudioServer.bus_count):
		var bus_name: String = String(AudioServer.get_bus_name(index)).to_lower()
		if "music" in bus_name or "hudba" in bus_name:
			AudioServer.set_bus_mute(index, true)
			music_status = "Dedicated music bus muted; SFX and Master unchanged"


func _read_arguments() -> void:
	output_path = ProjectSettings.globalize_path(DEFAULT_OUTPUT)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")
		elif argument == "--no-capture":
			capture_enabled = false
		elif argument.begins_with("--speed="):
			run_speed = clampf(argument.trim_prefix("--speed=").to_float(), 0.5, 4.0)
		elif argument.begins_with("--max-ticks="):
			max_ticks = maxi(100, argument.trim_prefix("--max-ticks=").to_int())
		elif argument.begins_with("--chop-burst="):
			burst_target_frames = clampi(argument.trim_prefix("--chop-burst=").to_int(), 0, 120)


func _vector_array(value: Vector2) -> Array:
	return [value.x, value.y]


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _finish() -> void:
	var manifest_path: String = ProjectSettings.globalize_path(LibraryClass.MANIFEST_PATH)
	var report: Dictionary = {"schema_version": 1, "scenario": "production menu -> relief -> authored lumberjack and hut",
		"synthetic_worker_or_world_states": false, "player_save_loaded": false,
		"music": music_status, "engine": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"package_manifest_sha256": FileAccess.get_sha256(manifest_path) if FileAccess.file_exists(manifest_path) else "missing",
		"script_sha256": code_sha256.get(get_script().resource_path, "missing"), "code_sha256_at_start": code_sha256,
		"worker_id": worker_id, "home_id": home_id, "source_id": source_id,
		"source_amount_before": source_amount_before, "home_output_before": home_output_before,
		"natural_directions_observed": natural_directions.keys(), "phases": phases,
		"captures": captures, "chop_burst": burst_frames, "chop_burst_target": burst_target_frames,
		"invalid_shadow_polygons": invalid_shadow_polygons,
		"observations": observations, "failures": failures,
		"coverage_limit": "Only authored normal simulation at its natural dawn lighting and visibility. All-eight-direction, fog and lighting fixtures are separate tests; screenshots require visual review."}
	var file: FileAccess = FileAccess.open(output_path.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	else:
		failures.append("Cannot write integration report.")
	for failure: String in failures:
		printerr(failure)
	print("LUMBERJACK GAME INTEGRATION: %d phases, %d captures, %d failures" % [phases.size(), captures.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
