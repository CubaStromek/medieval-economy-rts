extends "res://tests/lumberjack_game_integration_runner.gd"

const QaAssets = preload("res://tests/sawmill_qa_assets.gd")

## Actual menu -> authored Relief -> carrier delivery -> carpenter work/rest ->
## isolated save/load. Changes only UI/camera/speed and an isolated save.
func _ready() -> void:
	output_path = QaAssets.output_path(false, "natural")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")
	DirAccess.make_dir_recursive_absolute(output_path)
	_mute_music_bus_only()
	if DisplayServer.get_name() == "headless":
		failures.append("Native renderer required for normal-game evidence")
		_finish()
		return
	session = SessionScene.instantiate()
	session.honor_launch_arguments = false
	var slot: String = OS.get_temp_dir().path_join("sawmill_life_%d" % OS.get_process_id())
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
	game.set_process(false)
	for worker: Dictionary in game.world.workers.values():
		if worker.get("type") == "carpenter" and int(worker.get("home_id", 0)) != 0:
			worker_id = int(worker["id"])
			home_id = int(worker["home_id"])
			break
	_expect(worker_id != 0 and home_id != 0, "Authored Relief carpenter and sawmill exist")
	if worker_id == 0:
		_finish()
		return
	var building: Dictionary = game.world.buildings[home_id]
	_expect(building["type"] == "sawmill" and not game.building_sprite_presentation(building).is_empty(), "Normal path loads production sawmill bitmap")
	await _record("initial", 1.0)
	game.set_process(true)
	game._set_simulation_speed(4.0)
	var started: int = Time.get_ticks_msec()
	while game.world.tick < 2400 and Time.get_ticks_msec() - started < 180000:
		await get_tree().process_frame
		var life: Dictionary = game.building_life_presentation(building)
		if life.get("rest_visible", false) and not phases.has("day-rest"):
			_expect(_worker_entry().is_empty(), "Resting carpenter does not duplicate outdoor worker")
			_expect(life.get("window_open", false) and not life.has("light_strength"), "Natural rest opens dark window")
			_expect(game.production_building_life.rest_rect(life).has_area(), "Actual resting asset is loaded, not merely a true state flag")
			await _record("day-rest", 2.4)
		if life.get("active_work", false) and not phases.has("actual-production"):
			_expect(not life["rest_visible"] and life["door_open"] and not life["window_open"], "Actual production excludes rest and dark resting window")
			await _record("actual-production", 2.4)
		if phases.has("actual-production") and int(building["outputs"]["plank"]) >= 2 and not phases.has("produced-planks"):
			await _record("produced-planks", 1.0)
		if phases.has("day-rest") and phases.has("produced-planks"):
			break
	_expect(phases.has("day-rest") and phases.has("actual-production") and phases.has("produced-planks"), "Natural log delivery and carpenter batch must produce2planks with day rest observed")
	game._set_simulation_speed(0.0)
	game.set_process(false)
	var before: Dictionary = _snapshot()
	_expect(game._save_game(), "Save to isolated slot succeeds")
	game._load_game()
	await _settle()
	var after: Dictionary = _snapshot()
	_expect(before["tick"] == after["tick"] and before["life"]["at_home"] == after["life"]["at_home"]
		and before["outputs"] == after["outputs"], "Save/load retains presence and output inventory")
	await _record("loaded", 2.4)
	_finish()


func _record(label: String, zoom: float) -> void:
	var speed: float = game.simulation_speed
	game._set_simulation_speed(0.0)
	game.selected_cell = game.world.buildings[home_id]["position"]
	game._update_ui()
	game._set_zoom(zoom)
	var sprite: Dictionary = game.building_sprite_presentation(game.world.buildings[home_id])
	var focus: Vector2 = QaAssets.focus(sprite)
	game.camera.position = focus - (game._camera_map_rect().get_center() - game.get_viewport_rect().size * 0.5) / zoom
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	phases[label] = _snapshot()
	await _capture(label, phases[label])
	print("SAWMILL NATURAL: %s tick%d" % [label, game.world.tick])
	game._set_simulation_speed(speed)


func _snapshot() -> Dictionary:
	if game == null or worker_id == 0 or not game.world.workers.has(worker_id):
		return {}
	var b: Dictionary = game.world.buildings[home_id]
	var w: Dictionary = game.world.workers[worker_id]
	var life: Dictionary = game.building_life_presentation(b)
	var public_life: Dictionary = {}
	for key: String in ["known", "at_home", "active_work", "door_open", "window_open", "rest_visible"]:
		public_life[key] = life.get(key)
	public_life["pose"] = game.production_building_life.rest_pose_for(life)
	return {"tick": game.world.tick, "worker_id": worker_id, "home_id": home_id,
		"worker_state": w["state"], "worker_action": w["action"], "inside_building_id": w["inside_building_id"],
		"carrying": w["carrying"], "inputs": b["inputs"].duplicate(), "outputs": b["outputs"].duplicate(),
		"process_remaining": b["process_remaining"], "life": public_life, "outdoor_sprite_present": not _worker_entry().is_empty()}


func _finish() -> void:
	var hashes: Dictionary = {}
	for resource: String in ["res://scripts/view/main_view.gd", "res://scripts/view/sawmill_sprite_library.gd", "res://scripts/view/production_building_life.gd",
			get_script().resource_path, "res://tests/sawmill_qa_assets.gd"]:
		hashes[resource] = FileAccess.get_sha256(resource)
	hashes.merge(QaAssets.asset_hashes())
	var report: Dictionary = {"date": Time.get_datetime_string_from_system(), "engine": Engine.get_version_info()["string"],
		"scenario": "actual menu -> authored Relief -> carpenter rest -> actual carrier/log batch -> isolated save/load",
		"synthetic_worker_or_stock_or_clock_states": false, 
		"player_saves_accessed": false, "music": music_status, "hashes": hashes, "phases": phases, "captures": captures, "failures": failures}
	var file: FileAccess = FileAccess.open(output_path.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures:
		printerr(failure)
	print("SAWMILL NATURAL QA: %d phases,%d captures,%d failures" % [phases.size(), captures.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
