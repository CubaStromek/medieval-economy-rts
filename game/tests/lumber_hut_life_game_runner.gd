extends "res://tests/lumberjack_game_integration_runner.gd"

## Real menu, real Relief worker, actual delivery, rest and exit. No injected
## actions, indoor flags, clock jumps or player-save writes.

func _read_arguments() -> void:
	super._read_arguments()
	output_path = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-life-v1/natural")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output_path = argument.trim_prefix("--capture=")


func _snapshot() -> Dictionary:
	var result: Dictionary = super._snapshot()
	if not result.is_empty():
		var life: Dictionary = game.building_life_presentation(game.world.buildings[home_id])
		var data: Dictionary = {}
		for key: String in ["known", "at_home", "door_open", "window_open", "rest_visible", "rest_worker_id", "time_seconds"]:
			data[key] = life.get(key)
		data["rest_pose"] = game.lumber_hut_life.rest_pose_for(life)
		data["rest_turn"] = game.lumber_hut_life._rest_turn_for(life)
		result["hut_life"] = data
	return result


func _record_phase(phase: String) -> void:
	var life: Dictionary = game.building_life_presentation(game.world.buildings[home_id])
	if phase == "delivered":
		_expect(life.get("at_home", false) and life.get("door_open", false), "Actual indoor delivery opens the door.")
	elif phase in ["walk_axe", "chop-start", "walk_log"]:
		_expect(not life.get("at_home", true) and not life.get("door_open", true), "The door stays closed while its owner is away.")
	await super._record_phase(phase)


func _observe_real_cycle() -> void:
	await super._observe_real_cycle()
	if not failures.is_empty():
		return
	var stop_tick: int = game.world.tick + 400
	var saw_rest: bool = false
	var saw_exit: bool = false
	while game.world.tick < stop_tick:
		var life: Dictionary = game.building_life_presentation(game.world.buildings[home_id])
		if life.get("rest_visible", false) and not saw_rest:
			saw_rest = true
			_expect(_worker_entry().is_empty(), "Rest figure must not duplicate the indoor worker's outdoor sprite.")
			_expect(life.get("window_open", false) and not life.has("light_strength"), "Actual rest opens an unlit window.")
			await _record_home("day-rest")
		if not life.get("at_home", true):
			saw_exit = true
			_expect(not life.get("door_open", true) and not life.get("rest_visible", true), "Actual exit closes the door and removes the resting figure.")
			await _record_home("day-exit")
			break
		await get_tree().process_frame
	_expect(saw_rest and saw_exit, "The real delivered worker must rest, then leave again.")


func _record_home(label: String) -> void:
	var speed: float = game.simulation_speed
	game._set_simulation_speed(0.0)
	phases[label] = _snapshot()
	game._set_zoom(2.4)
	var focus: Vector2 = (game.building_sprite_presentation(game.world.buildings[home_id])["rect"] as Rect2).get_center() - Vector2(0, 10)
	game.camera.position = focus - (game._camera_map_rect().get_center() - game.get_viewport_rect().size * 0.5) / 2.4
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await _capture(label, _snapshot())
	print("LUMBER HUT LIFE: %s at tick %d" % [label, game.world.tick])
	game._set_simulation_speed(speed)


func _finish() -> void:
	code_sha256["res://scripts/view/lumber_hut_life.gd"] = FileAccess.get_sha256("res://scripts/view/lumber_hut_life.gd")
	code_sha256[get_script().resource_path] = FileAccess.get_sha256(get_script().resource_path)
	for file_name: String in ["look.json", "center.png", "left.png", "right.png"]:
		var path: String = "res://art/buildings/lumber_hut/v1/life/look/" + file_name
		if FileAccess.file_exists(path):
			code_sha256[path] = FileAccess.get_sha256(path)
	super._finish()
