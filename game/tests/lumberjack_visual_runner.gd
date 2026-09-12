extends Node

## Explicitly artificial state coverage through the actual MainScene renderer.
## The separate game-integration runner owns the natural economic journey.
const MainScene = preload("res://scenes/main.tscn")
const WorldClass = preload("res://scripts/simulation/simulation_world.gd")
const DIRS: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const VECTORS: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
const DEFAULT_OUTPUT := "res://../docs/art/qa/lumberjack-pixellab-game-v1/visual"
var game: Node2D
var output: String
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var pixel_checks: Array[Dictionary] = []
var ids: Array[int] = []
var active_clip: String = ""
var code_at_start: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Lumberjack visual QA requires actual native graphics.")
		get_tree().quit(1)
		return
	output = ProjectSettings.globalize_path(DEFAULT_OUTPUT)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			output = argument.trim_prefix("--capture=")
	DirAccess.make_dir_recursive_absolute(output)
	for source: String in ["res://scripts/view/main_view.gd", "res://scripts/view/lumberjack_presentation.gd", "res://scripts/view/lumberjack_work_placement.gd", "res://scripts/view/lumberjack_animation_library.gd", "res://scripts/view/terrain_renderer.gd", "res://scripts/view/solar_shadows.gd"]:
		code_at_start[source] = FileAccess.get_sha256(source)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.content_scale_factor = 1.0
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1600, 1000)
	game = MainScene.instantiate()
	game.honor_launch_arguments = false
	game.world = WorldClass.new(Vector2i(22, 18))
	add_child(game)
	game.set_process(false)
	game.simulation_speed = 0.0
	# The fixture jumps between prescribed views. Settle those camera jumps
	# immediately so paired native pixels use the identical transform.
	game.camera.position_smoothing_enabled = false
	game.camera.reset_smoothing()
	for clip: String in ["walk_axe", "chop", "walk_log"]:
		_configure(clip)
		for zoom: float in [0.75, 1.0, 2.4]:
			_focus(zoom)
			await _capture("all8-%s-%s" % [clip, str(zoom).replace(".", "_")])
	_configure("chop")
	for worker: Dictionary in game.world.workers.values():
		worker["work_remaining"] = 26
	game.lumberjack_animation.reset()
	_focus(2.4)
	await _capture("all8-chop-windup-2_4")
	_configure("walk_log")
	game.world.tick = 4500
	game._update_ui()
	_focus(2.4)
	await _capture("all8-walk_log-night-2_4")
	for clip: String in ["walk_axe", "chop"]:
		_configure(clip, true)
		_focus(2.4)
		await _capture("all8-%s-raised-slope-2_4" % clip)
	await _visibility_pairs()
	await _flat_boundary_pixels()
	for source: String in code_at_start:
		_expect(code_at_start[source] == FileAccess.get_sha256(source), "Runtime source remained stable during native capture: " + source)
	var manifest_path: String = "res://art/units/lumberjack-pixellab-v2/manifest.json"
	var report := {"artificial_states": true, "normal_game_journey": false,
		"captured_at_utc": Time.get_datetime_string_from_system(true), "code_sha256_at_start": code_at_start,
		"state_setup": "Authored fixture positions, heading, work_remaining, cargo, tick and relief; camera smoothing disabled only for instantaneous QA jumps; no gameplay progression is claimed.",
		"renderer": "res://scenes/main.tscn and its production worker/dynamic-row path",
		"engine": Engine.get_version_info()["string"], "display_server": DisplayServer.get_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "manifest_sha256": FileAccess.get_sha256(manifest_path),
		"main_view_sha256": FileAccess.get_sha256("res://scripts/view/main_view.gd"),
		"helper_sha256": FileAccess.get_sha256("res://scripts/view/lumberjack_presentation.gd"),
		"captures": captures, "pixel_checks": pixel_checks, "failures": failures}
	var report_file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	for failure: String in failures:
		printerr(failure)
	print("LUMBERJACK ARTIFICIAL VISUAL QA: %d native captures; %d failures" % [captures.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _configure(clip: String, raised: bool = false) -> void:
	active_clip = clip
	var world := WorldClass.new(Vector2i(22, 18))
	world.tick = 1750 # Noon; no automatic work or movement is executed.
	if raised:
		for y: int in range(19):
			for x: int in range(23):
				world.grid.set_vertex_height(Vector2i(x,y), clampi(7-y, 0, 3))
	ids.clear()
	for index: int in range(8):
		var position := Vector2i(5 + (index % 4) * 3, 5 + (index / 4) * 4)
		var id: int = world.spawn_worker(position, "lumberjack")
		_expect(id != 0, "Fixture must spawn direction " + DIRS[index])
		if id == 0:
			continue
		ids.append(id)
		var worker: Dictionary = world.workers[id]
		worker["previous_position"] = position - VECTORS[index]
		worker["visual_duration_ticks"] = 4
		worker["visual_progress_ticks"] = 4 if clip == "chop" else 2
		worker["state"] = "working" if clip == "chop" else "moving"
		worker["carrying"] = "log" if clip == "walk_log" else ""
		if clip == "chop":
			worker["action"] = "harvest"
			worker["source_id"] = world.add_tree(position, 3)
			worker["work_remaining"] = 20
			_expect(int(worker["source_id"]) != 0, "Chop source is a real mature fixture tree")
	game.world = world
	game.accumulator = game.FIXED_TICK_SECONDS * 0.35
	game.lumberjack_animation.reset()
	game.terrain_renderer.bind_grid(world.grid)
	game.selected_unit_id = 0
	game.selected_cell = Vector2i(-1,-1)
	game._update_ui()
	game.queue_redraw()


func _focus(zoom: float, ground: Vector2 = Vector2(9.5, 7.0)) -> void:
	game._set_zoom(zoom)
	var target: Vector2 = game.terrain_renderer.project_grid_position(ground)
	game.camera.position = target - (game._camera_map_rect().get_center() - get_viewport().get_visible_rect().size * 0.5) / zoom
	game.camera.force_update_scroll()
	game.queue_redraw()


func _states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in game._world_draw_entries():
		if entry["kind"] != "worker":
			continue
		var worker: Dictionary = entry["state"]
		var pose: Dictionary = game.worker_presentation(worker, entry["position"])
		result.append({"id": worker["id"], "clip": pose.get("clip"), "direction": pose.get("direction"),
			"frame_index": pose.get("frame_index"), "fps": pose.get("fps"), "moving": pose.get("moving"),
			"chopping": pose.get("chopping"), "renders_cargo": pose.get("renders_cargo"),
			"ground": [entry["ground_position"].x, entry["ground_position"].y],
			"foot_world": [entry["position"].x, entry["position"].y],
			"foot_screen": _array(game.get_global_transform_with_canvas() * (entry["position"] as Vector2)),
			"visual_depth": _array(game._entry_depth_position(entry)),
			"work_remaining": worker["work_remaining"], "source_id": worker["source_id"]})
	return result


func _capture(label: String) -> Image:
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _write_capture(label)


func _write_capture(label: String) -> Image:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = output.path_join(label + ".png")
	_expect(image != null and not image.is_empty(), "Native pixels exist: " + label)
	if image == null or image.is_empty():
		return image
	_expect(image.save_png(path) == OK, "Write PNG: " + label)
	captures.append({"file": label + ".png", "sha256": FileAccess.get_sha256(path),
		"artificial_states": true, "zoom": game.camera.zoom.x, "tick": game.world.tick,
		"size_px": [image.get_width(),image.get_height()], "states": _states()})
	return image


func _visibility_pairs() -> void:
	_configure("walk_log")
	_focus(2.4)
	var positive: Image = await _capture("visibility-positive-outdoor")
	_expect(_states().size() == 8, "Positive visibility control must show all eight loaded sprites")
	game.world.enable_fog(2)
	var explored: Array[Vector2i] = []
	for y: int in range(18):
		for x: int in range(22):
			explored.append(Vector2i(x,y))
	game.world.fog.restore_explored(explored)
	var hidden: Image = await _capture("visibility-fog-hidden")
	_expect(_states().is_empty(), "Fog must remove every foreign fixture unit")
	game.world.workers.clear()
	var absent: Image = await _capture("visibility-fog-empty-control")
	_compare_map("fog hidden versus no workers", hidden, absent)
	_expect(_different_pixels(positive, hidden, Rect2i(game._camera_map_rect())) > 0, "Fog pair has a nonempty positive image difference")
	_configure("walk_log")
	_focus(2.4)
	var building: int = game.world.place_building("warehouse", Vector2i(1,13))
	_expect(building != 0, "Indoor negative control needs a real complete building")
	if building == 0:
		return
	var entrance: Vector2i = game.world.buildings[building]["entrance"]
	for worker: Dictionary in game.world.workers.values():
		worker["position"] = entrance
		worker["previous_position"] = entrance
		worker["visual_progress_ticks"] = 4
	_focus(2.4, Vector2(entrance))
	var outside: Image = await _capture("visibility-indoor-outside-control")
	_expect(_states().size() == 8, "Indoor positive control submits the loaded units at the same entrance")
	for worker: Dictionary in game.world.workers.values():
		worker["inside_building_id"] = building
	var indoors: Image = await _capture("visibility-indoor-hidden")
	_expect(_states().is_empty(), "Real indoor field removes sprite, cargo and unit shadow")
	var visible_difference := _different_pixels(outside, indoors, Rect2i(game._camera_map_rect()))
	_expect(visible_difference > 0, "Indoor positive control has visible pixels at the same camera/entrance")
	pixel_checks.append({"check": "indoor positive control at identical entrance and camera", "different_pixels": visible_difference})
	game.world.workers.clear()
	var no_workers: Image = await _capture("visibility-indoor-empty-control")
	_compare_map("indoor hidden versus no workers", indoors, no_workers)


func _flat_boundary_pixels() -> void:
	_configure("walk_axe")
	var id: int = ids[7]
	var worker: Dictionary = game.world.workers[id]
	for other: int in ids:
		if other != id:
			game.world.workers.erase(other)
	# Explicit artificial phase seed, then an unobserved discontinuity. It uses
	# the public selector without altering its cache or production implementation.
	worker["previous_position"] = Vector2i(2,2)
	worker["position"] = Vector2i(3,2)
	worker["visual_duration_ticks"] = 100
	worker["visual_progress_ticks"] = 10
	game.accumulator = 0.0
	game.lumberjack_animation.reset()
	game.lumberjack_animation.sample(game.world, worker, 0.0) # Four px phase seed.
	game.world.tick += 1
	worker["previous_position"] = Vector2i(6,6)
	worker["position"] = Vector2i(5,5)
	worker["visual_progress_ticks"] = 52
	_focus(2.4, Vector2(5.48,5.48))
	var actual: Image = await _capture("flat-boundary-actual")
	var entries: Array = game._world_draw_entries()
	var entry: Dictionary = {}
	for candidate: Dictionary in entries:
		if candidate["kind"] == "worker":
			entry = candidate
	_expect(not entry.is_empty(), "Boundary worker must be visible")
	if entry.is_empty():
		return
	var pose: Dictionary = game.worker_presentation(worker, entry["position"])
	_expect(pose.get("direction") == "NW" and int(pose.get("frame_index", -1)) == 1, "Boundary positive control selects actual NW frame1 with alpha bottom221")
	# Remove only this submission from retained object rows; keep the terrain,
	# lighting and shadow rows. Submit the same draw function after all terrain.
	for row: int in game._row_entries:
		var filtered: Array = []
		for candidate: Dictionary in game._row_entries[row]:
			if not (candidate["kind"] == "worker" and int(candidate["id"]) == id):
				filtered.append(candidate)
		game._row_entries[row] = filtered
		game._dynamic_rows[row].queue_redraw()
	var reference := Node2D.new()
	reference.z_index = 4090
	reference.texture_filter = game.texture_filter
	game.add_child(reference)
	reference.draw.connect(func() -> void:
		var previous_canvas: CanvasItem = game._draw_canvas
		game._draw_canvas = reference
		game._draw_worker(worker, entry["position"])
		game._draw_canvas = previous_canvas)
	reference.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var oracle: Image = _write_capture("flat-boundary-unobstructed-reference")
	var foot: Vector2 = game.get_global_transform_with_canvas() * (entry["position"] as Vector2)
	var roi := Rect2i(Vector2i(floori(foot.x - 12.0 * 2.4), floori(foot.y)), Vector2i(60, 11))
	var difference: int = _different_pixels(actual, oracle, roi)
	pixel_checks.append({"check":"flat boundary actual versus identical draw above terrain", "different_pixels":difference,
		"roi_screen_px":[roi.position.x,roi.position.y,roi.size.x,roi.size.y],"direction":"NW","frame_index":1,
		"source_alpha_bottom_exclusive":221,"common_anchor_y":205,"extension_world_px":16.0*33.0/163.0,
		"artificial_phase_seed_world_px":4.0,"same_filter_and_canvas_light":true})
	_expect(difference == 0, "Lower pixels crossing a flat row boundary must equal the unobstructed reference")
	reference.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var empty: Image = _write_capture("flat-boundary-no-sprite-control")
	var positive_pixels: int = _different_pixels(oracle, empty, roi)
	pixel_checks.append({"check":"boundary lower-pixel positive control against no sprite", "different_pixels":positive_pixels,
		"roi_screen_px":[roi.position.x,roi.position.y,roi.size.x,roi.size.y]})
	_expect(positive_pixels > 0, "Boundary ROI must contain actual drawn lower sprite pixels, not only identical empty terrain")


func _compare_map(label: String, first: Image, second: Image) -> void:
	var difference: int = _different_pixels(first, second, Rect2i(game._camera_map_rect()))
	pixel_checks.append({"check":label,"different_pixels":difference})
	_expect(difference == 0, label + " must have identical map pixels")


func _different_pixels(first: Image, second: Image, region: Rect2i) -> int:
	var difference: int = 0
	var roi: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, first.get_size()))
	for y: int in range(roi.position.y, roi.end.y):
		for x: int in range(roi.position.x, roi.end.x):
			if first.get_pixel(x,y) != second.get_pixel(x,y):
				difference += 1
	return difference


static func _array(point: Vector2) -> Array[float]:
	return [point.x, point.y]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
