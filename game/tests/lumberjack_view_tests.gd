extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Library = preload("res://scripts/view/lumberjack_animation_library.gd")
const SaveSystem = preload("res://scripts/simulation/save_system.gd")
const SolarShadows = preload("res://scripts/view/solar_shadows.gd")
const TEST_COUNT: int = 13
const CENTER := Vector2i(8, 8)
const VECTORS := {
	"N": Vector2i(0, -1), "NE": Vector2i(1, -1), "E": Vector2i(1, 0), "SE": Vector2i(1, 1),
	"S": Vector2i(0, 1), "SW": Vector2i(-1, 1), "W": Vector2i(-1, 0), "NW": Vector2i(-1, -1),
}


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	main.world = LegacyFixture.create(Vector2i(32, 18))
	main.world.tick = 1750
	main.simulation_speed = 0.0
	for y: int in range(19):
		for x: int in range(33):
			main.world.grid.set_vertex_height(Vector2i(x, y), 3)
	var worker_id: int = main.world.spawn_worker(CENTER, "lumberjack")
	var tree_id: int = main.world.add_tree(CENTER, 3)
	viewport.add_child(main)
	main.set_process(false)
	if worker_id == 0 or tree_id == 0 or not main.lumberjack_sprites.is_complete():
		failures.append("Actual main-scene fixture must load all animations and create a lumberjack plus mature source tree")
		viewport.free()
		return failures
	var worker: Dictionary = main.world.workers[worker_id]
	_expect(main.world.is_tree_mature(main.world.trees[tree_id]), "Chop mapping must use a real mature source tree", failures)
	_test_all_clip_directions(main, worker, tree_id, failures)
	_test_actual_picking(main, worker, tree_id, failures)
	_test_cargo_suppression(main, worker, tree_id, failures)
	_test_legacy_fallback(main, worker, tree_id, failures)
	_test_read_only_queries(main, worker, tree_id, failures)
	await _test_paused_redraw(host, main, worker, tree_id, failures)
	_test_work_stance_transition(main, worker, tree_id, failures)
	_test_depletion_retains_stance(main, worker, tree_id, failures)
	_test_contact_shadow_depth(main, worker, tree_id, failures)
	_test_foreground_tree_alpha(main, worker, tree_id, failures)
	_test_indoor_entry(main, worker, failures)
	_test_fog_entry(main, worker, failures)
	# Loading replaces worker dictionaries, so this is the final fixture case.
	_test_work_placement_reset_load(main, worker, tree_id, failures)
	viewport.free()
	return failures


static func _set_case(main: MainView, worker: Dictionary, tree_id: int, clip: String, direction: String) -> void:
	_relocate(main, worker, CENTER)
	worker["previous_position"] = CENTER - (VECTORS[direction] as Vector2i)
	worker["visual_duration_ticks"] = 4
	worker["visual_progress_ticks"] = 4 if clip == "chop" else 1
	worker["move_cooldown"] = 0
	worker["state"] = "working" if clip == "chop" else "moving"
	worker["action"] = "deliver_log" if clip == "walk_log" else "harvest"
	worker["source_id"] = tree_id
	worker["work_remaining"] = 24
	worker["carrying"] = "log" if clip == "walk_log" else ""
	worker["inside_building_id"] = 0
	main.world.tick = 1750
	main.accumulator = MainView.FIXED_TICK_SECONDS * 0.25
	main.lumberjack_animation.reset()
	main.lumberjack_work_placement.reset()
	main.world.update_visibility()


static func _test_all_clip_directions(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for clip: String in Library.CLIPS:
		for direction: String in Library.DIRECTIONS:
			_set_case(main, worker, tree_id, clip, direction)
			var entry: Dictionary = _entry(main, int(worker["id"]))
			if entry.is_empty():
				failures.append("Actual main draw list omitted " + clip + "/" + direction)
				continue
			var feet: Vector2 = entry["position"]
			var presentation: Dictionary = main.worker_presentation(worker, feet)
			_expect(bool(presentation.get("animated_lumberjack", false)) and presentation.get("clip") == clip
				and presentation.get("direction") == direction and not bool(presentation.get("flip_h", true)),
				"Main scene must select authored, unmirrored " + clip + "/" + direction, failures)
			_expect(presentation.get("texture") == main.lumberjack_sprites.texture_for(clip, direction, int(presentation.get("frame_index", -1)))
				and presentation.get("rect") == main.lumberjack_sprites.sprite_rect(feet),
				"Main scene must use the selected frame and common registration at terrain-projected feet", failures)
			_expect(bool(presentation.get("chopping", false)) == (clip == "chop")
				and bool(presentation.get("moving", false)) == (clip != "chop"),
				"Animation activity must distinguish actual movement from productive chopping", failures)
			seen[clip + "/" + direction] = true
	_expect(seen.size() == 24, "Actual main-scene branch must exercise all 24 clip/direction combinations", failures)


static func _test_actual_picking(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "walk_axe", "S")
	# Isolate unit-alpha picking in front of the source tree. Foreground-tree
	# blocking has its own positive overlap and transparent-hole case below.
	worker["previous_position"] = CENTER
	worker["visual_progress_ticks"] = worker["visual_duration_ticks"]
	worker["action"] = "idle"
	worker["source_id"] = 0
	var entry: Dictionary = _entry(main, int(worker["id"]))
	var presentation: Dictionary = main.worker_presentation(worker, entry["position"])
	var samples: Dictionary = _source_sample_points(presentation)
	_expect(samples.has("opaque") and samples.has("clear"), "Actual source texture must provide visible and transparent picking samples", failures)
	if samples.has("opaque"):
		_expect(main._worker_id_at_visual_position(samples["opaque"]) == int(worker["id"]),
			"The actual painter-order picking path must select a visible lumberjack pixel", failures)
	if samples.has("clear"):
		_expect(main._worker_id_at_visual_position(samples["clear"]) == 0,
			"The actual main-scene picker must reject the animated canvas transparent padding", failures)


static func _test_cargo_suppression(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "walk_log", "NE")
	var feet: Vector2 = _entry(main, int(worker["id"]))["position"]
	var carried: Dictionary = main.worker_presentation(worker, feet)
	_expect(carried.get("clip") == "walk_log" and MainView.worker_sprite_contains_cargo(worker, carried),
		"The real selected log clip must suppress the additional legacy cargo mark", failures)
	worker["carrying"] = "plank"
	var other: Dictionary = main.worker_presentation(worker, feet)
	_expect(not MainView.worker_sprite_contains_cargo(worker, other), "Unbaked wares must retain the established cargo overlay", failures)
	worker["carrying"] = ""
	_expect(not MainView.worker_sprite_contains_cargo(worker, carried), "An old log presentation must not claim current cargo when the worker is empty", failures)


static func _test_legacy_fallback(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "walk_log", "W")
	var feet: Vector2 = _entry(main, int(worker["id"]))["position"]
	var shared: Library = main.lumberjack_sprites
	main.lumberjack_sprites = Library.new()
	var fallback: Dictionary = main.worker_presentation(worker, feet)
	_expect(not bool(fallback.get("animated_lumberjack", false)) and fallback.get("texture") == main.unit_sprites.texture_for("lumberjack"),
		"An injected unloaded reader must use the visible legacy lumberjack fallback", failures)
	_expect(not MainView.worker_sprite_contains_cargo(worker, fallback), "Missing animation assets must not remove the legacy log overlay", failures)
	main.lumberjack_sprites = shared
	worker["type"] = "carrier"
	var other_role: Dictionary = main.worker_presentation(worker, feet)
	_expect(not bool(other_role.get("animated_lumberjack", false)) and other_role.get("texture") == main.unit_sprites.texture_for("carrier"),
		"Other professions must keep the existing sprite branch", failures)
	worker["type"] = "lumberjack"
	_expect(shared.is_ready() and main.lumberjack_sprites == Library.shared(), "Fallback injection must not reload or mutate the shared reader", failures)


static func _test_read_only_queries(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "chop", "SE")
	var feet: Vector2 = _entry(main, int(worker["id"]))["position"]
	var save: Dictionary = main.world.to_data()
	var workers: Dictionary = main.world.workers.duplicate(true)
	var trees: Dictionary = main.world.trees.duplicate(true)
	var initial: Dictionary = main.worker_presentation(worker, feet)
	for index: int in range(8):
		main.worker_presentation(worker, feet)
		main.worker_satiety_presentation(worker, feet)
		main._worker_id_at_visual_position(feet + Vector2(0, -18))
	_expect(main.worker_presentation(worker, feet) == initial, "Repeated render/UI/picking samples at the same time must be idempotent", failures)
	_expect(main.world.to_data() == save and main.world.workers == workers and main.world.trees == trees,
		"Render, hunger and selection queries must not advance work or mutate saved/transient simulation state", failures)


static func _test_paused_redraw(host: Node, main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	var draws: Array[int] = [0]
	main.draw.connect(func() -> void: draws[0] += 1)
	for clip: String in ["walk_axe", "chop"]:
		_set_case(main, worker, tree_id, clip, "E")
		main.simulation_speed = 0.0
		var entry: Dictionary = _entry(main, int(worker["id"]))
		var initial: Dictionary = main.worker_presentation(worker, entry["position"])
		var save: Dictionary = main.world.to_data()
		var workers: Dictionary = main.world.workers.duplicate(true)
		for frame: int in range(3):
			main._process(1.0 / 30.0)
			main.queue_redraw()
			await host.get_tree().process_frame
			var now: Dictionary = _entry(main, int(worker["id"]))
			var presentation: Dictionary = main.worker_presentation(worker, now["position"])
			_expect(presentation.get("frame_index") == initial.get("frame_index") and presentation.get("rect") == initial.get("rect")
				and presentation.get("texture") == initial.get("texture") and now["position"] == entry["position"],
				"Paused " + clip + " must retain frame, texture, rectangle and physical feet across actual redraws", failures)
		_expect(main.world.to_data() == save and main.world.workers == workers, "Paused processing must leave authoritative state unchanged", failures)
	_expect(draws[0] > 0, "Pause test must execute the real MainScene draw path", failures)


static func _test_work_stance_transition(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	for direction: String in Library.DIRECTIONS:
		_set_case(main, worker, tree_id, "walk_axe", direction)
		worker["visual_duration_ticks"] = 1000
		main.accumulator = 0.0
		var previous_offset: float = -1.0
		var near_arrival := Vector2.ZERO
		var arrival := Vector2.ZERO
		for progress: int in [0, 250, 500, 750, 999, 1000]:
			worker["visual_progress_ticks"] = progress
			var entry: Dictionary = _read_only_entry(main, worker, failures)
			var contact: Vector2 = entry["contact_ground_position"]
			var offset: Vector2 = contact - (entry["ground_position"] as Vector2)
			_expect(worker["position"] == CENTER, "Approach presentation must keep the committed simulation cell", failures)
			_expect(offset.length() + 0.00001 >= previous_offset and absf(offset.x) <= 0.45 and absf(offset.y) <= 0.45,
				"Approach must increase a bounded in-cell work stance in " + direction, failures)
			if progress == 0:
				_expect(offset.is_zero_approx(), "First approach sample must start on the ordinary movement path", failures)
			if progress == 999:
				near_arrival = contact
			if progress == 1000:
				arrival = contact
				_expect(offset.length() > 0.01, "The actual work stance must produce a measurable placement change", failures)
			previous_offset = offset.length()
		worker["state"] = "working"
		var chop: Dictionary = _read_only_entry(main, worker, failures)
		_expect(arrival.distance_to(near_arrival) < 0.002 and (chop["contact_ground_position"] as Vector2).is_equal_approx(arrival),
			"Last approach sample must join chopping continuously in " + direction, failures)
		worker["carrying"] = "log"
		worker["action"] = "deliver_log"
		worker["work_remaining"] = 0
		var pickup: Dictionary = _read_only_entry(main, worker, failures)
		_expect((pickup["contact_ground_position"] as Vector2).is_equal_approx(arrival) and worker["position"] == CENTER,
			"Pickup must retain the work stance without moving the logical worker", failures)
		if direction == "W":
			var world_shift: Vector2 = (pickup["position"] as Vector2) - main.terrain_renderer.cell_center(CENTER)
			_expect(world_shift.x > 10.0 and world_shift.x < 10.5 and absf(world_shift.y) < 0.1,
				"The inspected west strike must place the worker about ten world pixels right of its trunk", failures)
		var destination: Vector2i = CENTER - (VECTORS[direction] as Vector2i)
		_relocate(main, worker, destination)
		worker["previous_position"] = CENTER
		worker["state"] = "moving"
		previous_offset = INF
		for progress: int in [0, 1, 250, 500, 750, 1000]:
			worker["visual_progress_ticks"] = progress
			var entry: Dictionary = _read_only_entry(main, worker, failures)
			var contact: Vector2 = entry["contact_ground_position"]
			var offset: Vector2 = contact - (entry["ground_position"] as Vector2)
			_expect(offset.length() <= previous_offset + 0.00001 and worker["position"] == destination,
				"First departing edge must reduce the work offset without changing its committed destination", failures)
			if progress == 0:
				_expect(contact.is_equal_approx(arrival), "Departure must start exactly at the pickup ground contact", failures)
			if progress == 1:
				_expect(contact.distance_to(arrival) < 0.002, "Departure must leave its pickup contact continuously", failures)
			if progress == 1000:
				_expect(offset.is_zero_approx(), "First departure must end on the ordinary movement path", failures)
			previous_offset = offset.length()
		_relocate(main, worker, destination - (VECTORS[direction] as Vector2i))
		worker["previous_position"] = destination
		worker["visual_progress_ticks"] = 0
		var next_edge: Dictionary = _read_only_entry(main, worker, failures)
		_expect(next_edge["contact_ground_position"] == next_edge["ground_position"],
			"Later movement edges must not retain a remote source-tree stance", failures)


static func _test_depletion_retains_stance(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "chop", "W")
	var before: Vector2 = _read_only_entry(main, worker, failures)["contact_ground_position"]
	var source: Dictionary = main.world.trees[tree_id]
	main.world.trees.erase(tree_id)
	worker["carrying"] = "log"
	worker["action"] = "deliver_log"
	worker["work_remaining"] = 0
	var pickup: Dictionary = _read_only_entry(main, worker, failures)
	_expect((pickup["contact_ground_position"] as Vector2).is_equal_approx(before) and worker["position"] == CENTER,
		"Depleting the actual source must preserve pickup stance while the log stays in the same simulation cell", failures)
	_relocate(main, worker, CENTER + Vector2i(1, 0))
	worker["previous_position"] = CENTER
	worker["visual_duration_ticks"] = 4
	worker["visual_progress_ticks"] = 0
	main.accumulator = 0.0
	var departure: Dictionary = _read_only_entry(main, worker, failures)
	_expect((departure["contact_ground_position"] as Vector2).is_equal_approx(before),
		"A depleted tree must not cause a jump at the first departure sample", failures)
	worker["visual_progress_ticks"] = 4
	var finished: Dictionary = _read_only_entry(main, worker, failures)
	_expect(finished["contact_ground_position"] == finished["ground_position"],
		"A remembered depleted source must release its stance by the end of the first departure", failures)
	main.world.trees[tree_id] = source


static func _test_contact_shadow_depth(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "chop", "W")
	var entry: Dictionary = _read_only_entry(main, worker, failures)
	var contact: Vector2 = entry["contact_ground_position"]
	var depth: Vector2 = entry["visual_ground_position"]
	_expect(contact != entry["ground_position"] and entry["shadow_ground_position"] == contact
		and (entry["position"] as Vector2).is_equal_approx(main.terrain_renderer.project_grid_position(contact)),
		"Sprite and shadow receiver must share the terrain-projected work contact, distinct from the simulation path", failures)
	_expect(MainView._entry_depth_position(entry) == depth and is_equal_approx(depth.x, contact.x)
		and depth.y > contact.y and depth.y - contact.y < 0.1,
		"Painter ordering and terrain picking must use the bounded visual margin beyond physical contact", failures)
	var solar: Dictionary = {"shadow_opacity": 0.4, "shadow_vector": Vector2(0.8, 0.6)}
	var control: Dictionary = entry.duplicate()
	control.erase("shadow_ground_position")
	control["ground_position"] = contact
	var actual_rows: Dictionary = SolarShadows.rows_for(main.terrain_renderer, entry, solar)
	var unplaced: Dictionary = entry.duplicate()
	unplaced.erase("shadow_ground_position")
	_expect(not actual_rows.is_empty() and actual_rows == SolarShadows.rows_for(main.terrain_renderer, control, solar)
		and actual_rows != SolarShadows.rows_for(main.terrain_renderer, unplaced, solar),
		"Actual cast-shadow polygons must follow the shifted contact; the old logical receiver must give a different result", failures)
	var depth_only: Dictionary = entry.duplicate()
	depth_only["visual_ground_position"] = depth + Vector2(0.0, 2.0)
	_expect(actual_rows == SolarShadows.rows_for(main.terrain_renderer, depth_only, solar)
		and depth_only["position"] == entry["position"], "Changing sorting metadata must not move the sprite or its cast shadow", failures)


static func _test_foreground_tree_alpha(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "walk_axe", "S")
	worker["previous_position"] = CENTER
	worker["visual_progress_ticks"] = worker["visual_duration_ticks"]
	worker["action"] = "idle"
	worker["source_id"] = 0
	var worker_id: int = int(worker["id"])
	var presentation: Dictionary = main.worker_presentation(worker, _entry(main, worker_id)["position"])
	var worker_image: Image = _presentation_image(presentation)
	var worker_rect: Rect2 = presentation["rect"]
	var blocked_count: int = 0
	var hole_count: int = 0
	# Use real mature atlas cells and painter ordering. Both sample types must
	# intersect a visible worker pixel; absent coverage explicitly fails below.
	for delta: Vector2i in [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var front_id: int = main.world.add_tree(CENTER + delta, 3)
		if front_id == 0:
			continue
		var tree: Dictionary = main.world.trees[front_id]
		var tree_feet: Vector2 = main.terrain_renderer.cell_center(tree["position"])
		var front: Dictionary = main.tree_sprites.presentation_for(tree, main.world.tree_growth_stage(tree), tree_feet)
		var tree_image: Image = _presentation_image(front)
		var tree_rect: Rect2 = front["rect"]
		var samples: Dictionary = {}
		for y: int in range(worker_image.get_height()):
			for x: int in range(worker_image.get_width()):
				if worker_image.get_pixel(x, y).a < 0.5:
					continue
				var point: Vector2 = worker_rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * worker_rect.size / Vector2(worker_image.get_size())
				if not tree_rect.has_point(point):
					continue
				var pixel: Vector2 = (point - tree_rect.position) / tree_rect.size * Vector2(tree_image.get_size())
				var alpha: float = tree_image.get_pixel(floori(pixel.x), floori(pixel.y)).a
				if alpha >= 0.5 and not samples.has("blocked"):
					samples["blocked"] = point
				if alpha == 0.0 and not samples.has("hole"):
					samples["hole"] = point
			if samples.size() == 2:
				break
		for kind: String in samples:
			var point: Vector2 = samples[kind]
			var expected: int = 0 if kind == "blocked" else worker_id
			_expect(main._worker_id_at_visual_position(point) == expected,
				"Foreground tree " + kind + " alpha must govern selection at an actual opaque worker pixel", failures)
			main.world.trees.erase(front_id)
			_expect(main._worker_id_at_visual_position(point) == worker_id,
				"Removing the tested foreground tree must reveal the same selectable worker pixel", failures)
			main.world.trees[front_id] = tree
			if kind == "blocked":
				blocked_count += 1
			else:
				hole_count += 1
		main.world.trees.erase(front_id)
	_expect(blocked_count > 0 and hole_count > 0,
		"Tree-alpha regression needs nonempty opaque overlap AND a transparent hole over actual visible worker pixels", failures)


static func _test_work_placement_reset_load(main: MainView, worker: Dictionary, tree_id: int, failures: Array[String]) -> void:
	_set_case(main, worker, tree_id, "chop", "W")
	var worker_id: int = int(worker["id"])
	var posed: Dictionary = _entry(main, worker_id)
	_expect(posed["contact_ground_position"] != posed["ground_position"], "Reset/load test must start from a cached nonzero work stance", failures)
	worker["carrying"] = "log"
	worker["action"] = "deliver_log"
	worker["work_remaining"] = 0
	main.lumberjack_work_placement.reset()
	var reset_entry: Dictionary = _read_only_entry(main, worker, failures)
	_expect(reset_entry["contact_ground_position"] == reset_entry["ground_position"],
		"Reset must clear stale work history without guessing a source for a carried log", failures)
	# Existing saves intentionally omit action, previous_position and animation
	# history. Loading guarantees current cargo/cell, not an identical old pose.
	_set_case(main, worker, tree_id, "chop", "W")
	_entry(main, worker_id)
	worker["carrying"] = "log"
	worker["action"] = "deliver_log"
	worker["work_remaining"] = 0
	var saved_cell: Vector2i = worker["position"]
	var saved_reader: Library = main.lumberjack_sprites
	var old_path: String = main.save_path_override
	var path: String = "/private/tmp/lumberjack-work-placement-tests-%d.json" % main.get_instance_id()
	if not SaveSystem.save_world(main.world, path, "test"):
		failures.append("Work-placement load case must write its isolated actual save")
		return
	main.save_path_override = path
	main._load_game()
	main.save_path_override = old_path
	DirAccess.remove_absolute(path)
	var loaded: Dictionary = main.world.workers.get(worker_id, {})
	_expect(not loaded.is_empty() and loaded.get("position") == saved_cell and loaded.get("carrying") == "log",
		"Actual MainScene load must keep the carried log and simulation cell", failures)
	if loaded.is_empty():
		return
	var loaded_entry: Dictionary = _read_only_entry(main, loaded, failures)
	var loaded_presentation: Dictionary = main.worker_presentation(loaded, loaded_entry["position"])
	_expect(loaded_entry["contact_ground_position"] == loaded_entry["ground_position"] and loaded_presentation.get("clip") == "walk_log",
		"Actual load must clear pre-load placement and animation history, then derive a log pose from loaded state", failures)
	_expect(main.lumberjack_sprites == saved_reader and saved_reader == Library.shared(),
		"Loading simulation state must retain the existing immutable shared sprite reader", failures)


static func _read_only_entry(main: MainView, worker: Dictionary, failures: Array[String]) -> Dictionary:
	var save: Dictionary = main.world.to_data()
	var workers: Dictionary = main.world.workers.duplicate(true)
	var trees: Dictionary = main.world.trees.duplicate(true)
	var entry: Dictionary = _entry(main, int(worker["id"]))
	_expect(not entry.is_empty() and main.world.to_data() == save and main.world.workers == workers and main.world.trees == trees,
		"Work-placement sampling must not mutate authoritative or transient simulation state", failures)
	return entry


static func _presentation_image(presentation: Dictionary) -> Image:
	var texture: AtlasTexture = presentation["texture"] as AtlasTexture
	var source: Image = texture.atlas.get_image()
	if source.is_compressed():
		source.decompress()
	return source.get_region(Rect2i(texture.region))


static func _test_indoor_entry(main: MainView, worker: Dictionary, failures: Array[String]) -> void:
	var building_id: int = main.world.place_building("warehouse", Vector2i(3, 3))
	_expect(building_id != 0, "Indoor test needs a real completed warehouse", failures)
	if building_id == 0:
		return
	var door: Vector2i = main.world.buildings[building_id]["entrance"]
	_relocate(main, worker, door)
	worker["state"] = "idle"
	worker["action"] = "idle"
	worker["visual_duration_ticks"] = 1
	worker["visual_progress_ticks"] = 1
	worker["move_cooldown"] = 0
	_expect(not _entry(main, int(worker["id"])).is_empty(), "Outdoor doorway worker must be present before the visibility test", failures)
	_expect(main.world._enter_worker_building(worker, building_id), "Worker must actually enter the building through the simulation helper", failures)
	var feet: Vector2 = main.terrain_renderer.cell_center(door)
	_expect(_entry(main, int(worker["id"])).is_empty() and not bool(main.worker_satiety_presentation(worker, feet).get("visible", true)),
		"Indoor lumberjacks must submit neither unit draw entries nor hunger UI", failures)
	_expect(main._worker_id_at_visual_position(feet + Vector2(0, -18)) == 0, "An indoor lumberjack must not remain selectable over its building", failures)
	_expect(main.world._try_exit_worker_building(worker), "Fixture must exit normally without changing shared animation resources", failures)


static func _test_fog_entry(main: MainView, worker: Dictionary, failures: Array[String]) -> void:
	_relocate(main, worker, CENTER)
	var enemy_id: int = main.world.spawn_worker(Vector2i(13, 8), "lumberjack", 0, true, 0, 2)
	_expect(enemy_id != 0, "Fog test needs a real foreign lumberjack", failures)
	if enemy_id == 0:
		return
	var enemy: Dictionary = main.world.workers[enemy_id]
	enemy["carrying"] = "log"
	main.world.enable_fog(1)
	_expect(main.world.is_entity_visible(enemy) and not _entry(main, enemy_id).is_empty(),
		"Foreign lumberjack must first be visible through actual local sight", failures)
	_relocate(main, worker, Vector2i(26, 8))
	main.world.update_visibility()
	var feet: Vector2 = main.terrain_renderer.cell_center(enemy["position"])
	_expect(main.world.is_cell_explored(enemy["position"]) and not main.world.is_entity_visible(enemy),
		"Moving the observer away must preserve explored ground while removing current enemy sight", failures)
	_expect(_entry(main, enemy_id).is_empty() and not bool(main.worker_satiety_presentation(enemy, feet).get("visible", true)),
		"Fog-hidden lumberjacks must not submit draw entries or hunger/cargo state UI", failures)
	_expect(main._worker_id_at_visual_position(feet + Vector2(0, -18)) == 0, "A hidden enemy sprite must not remain selectable", failures)


static func _relocate(main: MainView, worker: Dictionary, position: Vector2i) -> void:
	main.world._release_worker_tile(worker)
	worker["position"] = position
	worker["previous_position"] = position
	main.world.tile_reservations[position] = int(worker["id"])


static func _entry(main: MainView, worker_id: int) -> Dictionary:
	for entry: Dictionary in main._world_draw_entries():
		if entry["kind"] == "worker" and int(entry["id"]) == worker_id:
			return entry
	return {}


static func _source_sample_points(presentation: Dictionary) -> Dictionary:
	var texture: AtlasTexture = presentation["texture"] as AtlasTexture
	var atlas: Image = texture.atlas.get_image()
	if atlas.is_compressed():
		atlas.decompress()
	var image: Image = atlas.get_region(Rect2i(texture.region))
	var rect: Rect2 = presentation["rect"]
	var samples: Dictionary = {}
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var alpha: float = image.get_pixel(x, y).a
			var point: Vector2 = rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * rect.size / Vector2(image.get_size())
			if alpha >= 0.5 and not samples.has("opaque"):
				samples["opaque"] = point
			if alpha == 0.0 and not samples.has("clear"):
				samples["clear"] = point
		if samples.size() == 2:
			return samples
	return samples


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
