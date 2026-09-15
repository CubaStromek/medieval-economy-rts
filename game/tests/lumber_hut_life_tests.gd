extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const House = preload("res://scripts/view/lumber_hut_sprite_library.gd")
const Life = preload("res://scripts/view/lumber_hut_life.gd")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const Footprint = preload("res://scripts/view/building_footprint_renderer.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 12


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library := Life.new()
	for test: Callable in [_test_actual_owner_and_visitors, _test_rest_requires_rest,
		_test_real_delivery_and_departure, _test_paused_worker_returns,
		_test_stock_independence, _test_private_presence, _test_construction_and_revisions,
		_test_indoor_save_round_trip, _test_imported_rest_alpha_and_ground, _test_day_window_and_looking,
		_test_imported_head_looks]:
		test.call(library, failures)
	await _test_actual_scene_time_and_pause(host, failures)
	return failures


static func _fixture(revision: int = 2) -> Dictionary:
	var world := World.new(Vector2i(24, 18))
	world.default_footprint_version = revision
	world.tick = 1750 # Noon; all ordinary round trips remain in daylight.
	var id: int = world.place_building("lumber_hut", Vector2i(10, 8))
	var building: Dictionary = world.buildings[id]
	return {"world": world, "id": id, "building": building, "door": building["entrance"]}


static func _owner(fixture: Dictionary, inside: bool = false) -> Dictionary:
	var world: World = fixture["world"]
	var cell: Vector2i = fixture["door"] if inside else Vector2i(14, 9)
	var id: int = world.spawn_worker(cell, "lumberjack", int(fixture["id"]), true,
		int(fixture["id"]) if inside else 0)
	return world.workers[id]


static func _presentation(library: Life, fixture: Dictionary, fraction: float = 0.0) -> Dictionary:
	var world: World = fixture["world"]
	var house := House.new()
	var building: Dictionary = fixture["building"]
	var sprite: Dictionary = house.presentation_for(building,
		world.catalog.building("lumber_hut"), Vector2(500, 360))
	return library.presentation_for(world, building, sprite, fraction)


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _until(world: World, condition: Callable, max_ticks: int = 900) -> bool:
	for _tick: int in range(max_ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _test_actual_owner_and_visitors(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = _owner(f)
	var visitor: int = world.spawn_worker(f["door"], "carrier", 0, false, f["id"])
	_check(visitor != 0 and world.is_worker_inside(world.workers[visitor]),
		"Presence fixture must have a real indoor carrier visitor", failures)
	var life: Dictionary = _presentation(library, f)
	_check(bool(life.get("known", false)) and not bool(life.get("at_home", true))
		and not bool(life.get("door_open", true)) and not bool(life.get("rest_visible", true)),
		"An assigned outdoor lumberjack and an indoor carrier must leave the owner's door closed", failures)
	# Physical presence in another actual house still does not mean home.
	var other: int = world.place_building("lumber_hut", Vector2i(4, 4))
	world._release_worker_tile(worker)
	worker["position"] = world.buildings[other]["entrance"]
	worker["inside_building_id"] = other
	_check(not bool(_presentation(library, f).get("at_home", true)),
		"The hut's assigned worker visiting another house must not open this hut", failures)
	worker["position"] = f["door"]
	worker["inside_building_id"] = f["id"]
	life = _presentation(library, f)
	_check(bool(life.get("at_home", false)) and bool(life.get("door_open", false))
		and bool(life.get("rest_visible", false)) and int(life.get("rest_worker_id", 0)) == int(worker["id"]),
		"The visible resting resident must retain the identity of the physically present lumberjack", failures)
	worker["home_id"] = other
	_check(not bool(_presentation(library, f).get("at_home", true)),
		"An indoor lumberjack belonging to a different hut is not this hut's home resident", failures)


static func _test_rest_requires_rest(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var worker: Dictionary = _owner(f, true)
	for sample: Array in [["idle", "", "log"], ["working", "harvest_tree", ""],
		["moving", "deliver_log", ""], ["idle", "deliver_log", ""]]:
		worker["state"] = sample[0]
		worker["action"] = sample[1]
		worker["carrying"] = sample[2]
		var life: Dictionary = _presentation(library, f)
		_check(bool(life.get("at_home", false)) and bool(life.get("door_open", false))
			and not bool(life.get("rest_visible", true)) and not bool(life.get("window_open", true)),
			"Physical presence opens the door but cargo or active work cannot show a resting duplicate (%s)" % str(sample), failures)
	worker["state"] = "idle"
	worker["action"] = ""
	worker["carrying"] = ""
	_check(bool(_presentation(library, f).get("rest_visible", false)),
		"An idle empty-handed resident must show the daytime resting pose", failures)


static func _test_real_delivery_and_departure(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = _owner(f)
	world.add_tree(Vector2i(15, 9), 2)
	var saw_cargo: bool = false
	var saw_final_step: bool = false
	var delivered: bool = false
	for _tick: int in range(900):
		world.step_tick()
		var life: Dictionary = _presentation(library, f)
		if not world.is_worker_inside(worker):
			_check(not bool(life.get("at_home", true)) and not bool(life.get("door_open", true))
				and not bool(life.get("rest_visible", true)),
				"The actual outdoor harvesting and delivery route must keep the hut closed", failures)
		if worker["carrying"] == "log":
			saw_cargo = true
			if worker["position"] == f["door"] and int(worker["visual_progress_ticks"]) < int(worker["visual_duration_ticks"]):
				saw_final_step = true
				_check(not bool(life.get("at_home", true)),
					"Logical arrival must not open the door before the last visible movement finishes", failures)
		if int(f["building"]["outputs"]["log"]) == 1:
			delivered = true
			_check(world.is_worker_inside(worker) and worker["carrying"] == ""
				and bool(life.get("door_open", false)) and bool(life.get("rest_visible", false)),
				"The actual completed handover must open the door and display the same resting resident", failures)
			break
	_check(saw_cargo and saw_final_step and delivered,
		"The presence integration fixture must observe real cargo, final doorway interpolation and indoor handover", failures)
	if not delivered:
		return
	for _tick: int in range(6):
		world.step_tick()
		_check(world.is_worker_inside(worker) and bool(_presentation(library, f).get("door_open", false)),
			"The door must remain open throughout the actual six-tick indoor rest", failures)
	_check(_until(world, func() -> bool: return not world.is_worker_inside(worker), 20),
		"The next real harvesting job must physically bring the resident back outside", failures)
	var departed: Dictionary = _presentation(library, f)
	_check(not bool(departed.get("door_open", true)) and not bool(departed.get("rest_visible", true))
		and worker["position"] == f["door"] and int(world.tile_reservations.get(f["door"], 0)) == int(worker["id"])
		and world.workers.size() == 1,
		"Actual departure must remove the resting pose immediately and restore the one real outdoor worker", failures)


static func _test_paused_worker_returns(library: Life, failures: Array[String]) -> void:
	for pause_building: bool in [false, true]:
		var f: Dictionary = _fixture()
		var world: World = f["world"]
		var worker: Dictionary = _owner(f)
		world.add_tree(Vector2i(15, 9), 3)
		if not _until(world, func() -> bool: return worker["state"] == "working"):
			failures.append("Pause presence fixture must first reach actual harvesting work")
			continue
		if pause_building:
			world.set_building_enabled(f["id"], false)
		else:
			world.set_worker_enabled(int(worker["id"]), false)
		_check(not bool(_presentation(library, f).get("at_home", true)),
			"Pausing work must not open the door while the resident is still outside", failures)
		if not _until(world, func() -> bool: return world.is_worker_inside(worker)):
			failures.append("A paused resident must actually return through its hut door")
			continue
		var life: Dictionary = _presentation(library, f)
		_check(world.is_worker_work_paused(worker) and bool(life.get("door_open", false))
			and bool(life.get("rest_visible", false)),
			"Stopping the worker or the building must retain the actual daytime resident's open door and resting pose", failures)


static func _test_stock_independence(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var worker: Dictionary = _owner(f, true)
	var world: World = f["world"]
	for inside: bool in [true, false]:
		worker["inside_building_id"] = f["id"] if inside else 0
		for tick: int in [1750, 4750]:
			world.tick = tick
			var before: Dictionary = _presentation(library, f)
			for amount: int in range(7):
				f["building"]["outputs"]["log"] = amount
				f["building"]["inputs"]["log"] = 6 - amount
				f["building"]["reserved_incoming"] = {"log": amount}
				_check(_presentation(library, f) == before,
					"Every 0–6 stock level and incoming reservation must leave independent presence state unchanged", failures)


static func _test_private_presence(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = _owner(f, true)
	f["building"]["owner_id"] = 2
	worker["owner_id"] = 2
	world.fog.enabled = true
	world.tick = 4750
	var actual_workers: Dictionary = world.workers
	# A malformed private value proves the foreign return precedes iteration,
	# casts or workplace lookup, rather than just erasing leaked output later.
	world.workers = {"unreadable": "private workers must not be inspected"}
	for visible: bool in [false, true]:
		world.fog.explored[f["building"]["position"]] = true
		if visible:
			world.fog.visible[f["building"]["position"]] = true
		var hidden: Dictionary = _presentation(library, f)
		_check(not bool(hidden.get("known", true)) and not bool(hidden.get("at_home", true))
			and not bool(hidden.get("rest_visible", true)) and not bool(hidden.get("window_open", true))
			and int(hidden.get("rest_worker_id", -1)) == 0,
			"Explored and currently visible foreign huts must retain neutral unknown presence without reading private workers", failures)
	world.workers = actual_workers
	world.fog.enabled = false
	_check(bool(_presentation(library, f).get("known", false)) and bool(_presentation(library, f).get("at_home", false)),
		"Disabling fog must restore the existing no-fog disclosure policy for a real foreign resident", failures)
	world.fog.enabled = true
	f["building"]["owner_id"] = 1
	worker["owner_id"] = 1
	_check(bool(_presentation(library, f).get("at_home", false)),
		"Fog must not suppress the local player's own physically present resident", failures)


static func _test_construction_and_revisions(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_owner(f, true)
	var building: Dictionary = f["building"]
	for remaining: int in [120, 1]:
		building["construction_remaining"] = remaining
		_check(_presentation(library, f).is_empty(), "An unfinished hut must not display completed-house life layers", failures)
	building["construction_remaining"] = 0
	building["foundation_work_remaining"] = 1
	_check(_presentation(library, f).is_empty(), "Ground leveling must not display a finished house's occupants", failures)
	building["foundation_work_remaining"] = 0
	for revision: int in [1, 2]:
		var registered: Dictionary = _fixture(revision)
		_owner(registered, true)
		var life: Dictionary = _presentation(library, registered)
		_check(not life.is_empty() and bool(life.get("at_home", false))
			and (life.get("rect", Rect2()) as Rect2).size.x > 0.0 and float(life.get("source_to_world", 0.0)) > 0.0,
			"Both supported saved footprint revisions must retain registered dynamic layers", failures)
	building["footprint_version"] = 0
	_check(_presentation(library, f).is_empty(), "Legacy one-cell huts must retain their existing renderer without misregistered overlays", failures)


static func _test_indoor_save_round_trip(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = _owner(f)
	world.set_worker_enabled(int(worker["id"]), false)
	if not _until(world, func() -> bool: return world.is_worker_inside(worker)):
		failures.append("Life save fixture must observe the real resident enter its own hut")
		return
	var source_data: Dictionary = world.to_data()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(source_data)) as Dictionary
	var before: Dictionary = _presentation(library, f)
	var restored := World.new()
	if not restored.from_data(snapshot):
		failures.append("The normal JSON loader must accept the real indoor resident fixture")
		return
	var loaded: Dictionary = {"world": restored, "id": f["id"], "building": restored.buildings[f["id"]]}
	_check(restored.to_data() == source_data,
		"The normal loader must preserve the resident fixture's saved simulation state", failures)
	_check(_presentation(library, loaded) == before and restored.is_worker_inside(restored.workers[worker["id"]]),
		"Save/load must restore exact hut life and resident identity from existing indoor fields without new simulation data", failures)
	var saved: Dictionary = restored.to_data()
	var workers: Dictionary = restored.workers.duplicate(true)
	for _frame: int in range(12):
		_presentation(library, loaded, 0.5)
	_check(restored.to_data() == saved and restored.workers == workers,
		"Repeated life presentation must not mutate saved data or transient worker state", failures)


static func _test_imported_rest_alpha_and_ground(library: Life, failures: Array[String]) -> void:
	var texture: Texture2D = load("res://art/buildings/lumber_hut/v1/life/resting_lumberjack.png") as Texture2D
	if texture == null:
		failures.append("The resting resident must load through the actual imported production PNG")
		return
	var pixels: Image = texture.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	_check(pixels.get_size() == Vector2i(256, 256), "The actual rest pose must retain its registered canvas", failures)
	if pixels.get_size() != Vector2i(256, 256):
		return
	var empty_border: bool = true
	for edge: int in range(256):
		for point: Vector2i in [Vector2i(edge, 0), Vector2i(edge, 255), Vector2i(0, edge), Vector2i(255, edge)]:
			empty_border = empty_border and is_zero_approx(pixels.get_pixelv(point).a)
	var used: Rect2i = pixels.get_used_rect()
	_check(empty_border and used.has_area() and used.size.x < 128 and used.size.y < 220,
		"The resting resident needs true alpha around its whole border and a tight nonempty body silhouette", failures)
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = _owner(f, true)
	var terrain := Terrain.new()
	terrain.bind_grid(world.grid)
	var shape: Dictionary = Footprint.geometry(world, terrain, f["building"])
	var house := House.new()
	var sprite: Dictionary = house.presentation_for(f["building"], world.catalog.building("lumber_hut"), shape["door"])
	var life: Dictionary = library.presentation_for(world, f["building"], sprite)
	# Alpha comparisons below target the exact center source, not an arbitrary
	# side/transition chosen by the resident-specific phase at this fixture tick.
	for sample: int in range(24):
		life["time_seconds"] = float(sample) * 0.5
		if is_zero_approx(float(Life._rest_turn_for(life)["amount"])):
			break
	var rect: Rect2 = Life.rest_rect(life)
	if not rect.has_area():
		failures.append("The imported rest pose must produce a registered drawable rectangle")
		terrain.free()
		return
	var pixel_scale: float = rect.size.x / float(pixels.get_width())
	_check(absf(float(used.size.y) * pixel_scale - 33.0) < 1.0,
		"The actual alpha body must match the hut's 33-world-pixel human scale", failures)
	var hits_match: bool = true
	var opaque_count: int = 0
	var transparent_count: int = 0
	var body_point := Vector2.INF
	for y: int in range(0, 256, 4):
		for x: int in range(0, 256, 4):
			var alpha: float = pixels.get_pixel(x, y).a
			var point: Vector2 = rect.position + Vector2(x + 0.5, y + 0.5) * pixel_scale
			if alpha > 0.95:
				opaque_count += 1
				body_point = point
				hits_match = hits_match and Life.contains_point(life, point)
			elif is_zero_approx(alpha):
				transparent_count += 1
				hits_match = hits_match and not Life.contains_point(life, point)
	_check(hits_match and opaque_count > 100 and transparent_count > 1000,
		"Actual opaque rest pixels must be selectable while transparent canvas/body gaps never form a rectangular hit area", failures)
	var ground_samples: int = 0
	var boots_on_footprint: bool = true
	# Test the actual sole pixels, not merely a metadata point that could sit
	# correctly while the painted boot extends onto a free approach cell.
	for y: int in range(used.end.y - 3, used.end.y):
		for x: int in range(used.position.x, used.end.x):
			if pixels.get_pixel(x, y).a < 0.5:
				continue
			ground_samples += 1
			var sole: Vector2 = rect.position + Vector2(x + 0.5, y + 0.5) * pixel_scale
			var on_ground: bool = false
			for polygon: PackedVector2Array in shape["foundations"]:
				on_ground = on_ground or Geometry2D.is_point_in_polygon(sole, polygon)
			boots_on_footprint = boots_on_footprint and on_ground
	_check(ground_samples > 5 and boots_on_footprint,
		"The measured rest-pose sole must contact occupied hut ground without standing on the free doorway approach", failures)
	for state: String in ["away", "private"]:
		worker["inside_building_id"] = 0 if state == "away" else int(f["id"])
		world.tick = 1750
		world.fog.enabled = state == "private"
		f["building"]["owner_id"] = 2 if state == "private" else 1
		worker["owner_id"] = f["building"]["owner_id"]
		var hidden: Dictionary = library.presentation_for(world, f["building"], sprite)
		_check(not bool(hidden.get("rest_visible", true)) and not Life.contains_point(hidden, body_point),
			"The same genuinely opaque rest pixel must lose its hit area when absent or private (%s)" % state, failures)
	terrain.free()


static func _test_day_window_and_looking(library: Life, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = _owner(f, true)
	for inside: bool in [false, true]:
		worker["inside_building_id"] = int(f["id"]) if inside else 0
		for tick: int in [1750, 4750]:
			world.tick = tick
			var life: Dictionary = _presentation(library, f)
			_check(bool(life.get("window_open", not inside)) == inside,
				"An idle resident at home must open the window at any tick; absence must close it", failures)
			if inside:
				_check(bool(life.get("rest_visible", false)) and not life.has("light_strength") and not life.has("smoke_strength"),
					"An open window must remain unlit and without chimney smoke while its resident rests", failures)
			if not bool(life.get("rest_visible", false)):
				_check(Life.rest_pose_for(life) == "center", "Hidden resting poses must resolve to neutral center", failures)
	# Keep the person physically at home by stopping work through the normal
	# control API, then let actual simulation time drive a complete look cycle.
	world.tick = 1750
	world.set_worker_enabled(int(worker["id"]), false)
	var poses: Dictionary = {}
	var only_supported: bool = true
	var stable_same_time: bool = true
	var open_unlit_throughout: bool = true
	for _tick: int in range(140):
		world.step_tick()
		var life: Dictionary = _presentation(library, f)
		var pose: String = Life.rest_pose_for(life)
		poses[pose] = true
		only_supported = only_supported and pose in ["center", "left", "right"]
		stable_same_time = stable_same_time and Life.rest_pose_for(life) == pose \
			and Life.rest_pose_for(_presentation(library, f)) == pose
		open_unlit_throughout = open_unlit_throughout and world.is_worker_inside(worker) \
			and bool(life.get("rest_visible", false)) and bool(life.get("window_open", false))
	_check(only_supported and poses.has("center") and poses.has("left") and poses.has("right"),
		"A long actual daytime rest must gently visit all three delivered head directions", failures)
	_check(stable_same_time and open_unlit_throughout,
		"Looking must be deterministic at a fixed simulation time and preserve the occupied, unlit open-window state", failures)
	worker["action"] = "deliver_log"
	var delivering: Dictionary = _presentation(library, f)
	_check(not bool(delivering.get("rest_visible", true)) and not bool(delivering.get("window_open", true))
		and Life.rest_pose_for(delivering) == "center",
		"Actual delivery action must suppress the daytime rest window and look pose even for a paused home resident", failures)
	world.fog.enabled = true
	f["building"]["owner_id"] = 2
	worker["owner_id"] = 2
	var private_life: Dictionary = _presentation(library, f)
	_check(not bool(private_life.get("window_open", true)) and Life.rest_pose_for(private_life) == "center",
		"A foreign private hut must disclose neither open occupancy window nor head direction", failures)


static func _test_imported_head_looks(library: Life, failures: Array[String]) -> void:
	var directory: String = "res://art/buildings/lumber_hut/v1/life/look/"
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "look.json")) as Dictionary
	var original_metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Life.REST_MANIFEST)) as Dictionary
	_check(metadata.get("production_ground_contact") == original_metadata.get("production_ground_contact")
		and metadata.get("production_body_height_px") == original_metadata.get("production_body_height_px"),
		"Head variants must retain the original measured feet anchor and human scale", failures)
	var collar: int = int(metadata.get("collar_y", -1))
	if collar != 82:
		failures.append("Delivered look variants must declare their measured protected body boundary at source row 82")
		return
	var original_texture: Texture2D = load("res://art/buildings/lumber_hut/v1/life/resting_lumberjack.png") as Texture2D
	var original: Image = original_texture.get_image()
	if original.is_compressed():
		original.decompress()
	original.convert(Image.FORMAT_RGBA8)
	original.clear_mipmaps()
	var body_region := Rect2i(0, collar, 256, 256 - collar)
	var head_region := Rect2i(0, 0, 256, collar)
	var original_body: PackedByteArray = original.get_region(body_region).get_data()
	var heads: Dictionary = {}
	for pose: String in ["center", "left", "right"]:
		var path: String = directory + String((metadata.get("frames", {}) as Dictionary).get(pose, ""))
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			failures.append("Every delivered head direction must load as an actual imported PNG: " + pose)
			continue
		var pixels: Image = texture.get_image()
		if pixels.is_compressed():
			pixels.decompress()
		pixels.convert(Image.FORMAT_RGBA8)
		pixels.clear_mipmaps()
		if pixels.get_size() != Vector2i(256, 256):
			failures.append("Head direction must preserve the shared 256px registered canvas: " + pose)
			continue
		heads[hash(pixels.get_region(head_region).get_data())] = true
		_check(pixels.get_region(body_region).get_data() == original_body,
			"Every body, arm and boot pixel below the collar must stay byte-identical in the imported " + pose + " pose", failures)
		if pose == "center":
			_check(pixels.get_region(Rect2i(0, 0, 256, 256)).get_data()
				== original.get_region(Rect2i(0, 0, 256, 256)).get_data(),
				"The center pose must be the exact existing resting sprite", failures)
	_check(heads.size() == 3, "Three delivered directions must contain three genuinely different head images", failures)
	var expected_cache: int = 2 * (Life.LOOK_TURN_STEPS + 1)
	_check(Life._look_textures.size() == expected_cache and Life._look_masks.size() == expected_cache,
		"The runtime must actually load and cache both complete head-turn transitions and their matching alpha masks", failures)
	var cache_bodies_unchanged: bool = true
	var left_changes: Dictionary = {}
	var right_changes: Dictionary = {}
	for key: String in Life._look_textures:
		var pixels: Image = (Life._look_textures[key] as Texture2D).get_image()
		# get_region preserves a mip chain, whose coarse collar samples can
		# include the turned head. Compare registered source/body pixels only.
		pixels.clear_mipmaps()
		cache_bodies_unchanged = cache_bodies_unchanged and pixels.get_region(body_region).get_data() == original_body
		if key.begins_with("left:"):
			left_changes[hash(pixels.get_region(head_region).get_data())] = true
		else:
			right_changes[hash(pixels.get_region(head_region).get_data())] = true
	_check(cache_bodies_unchanged,
		"Every cached transition must keep all body/foot RGBA bytes fixed", failures)
	_check(left_changes.size() == Life.LOOK_TURN_STEPS + 1 and right_changes.size() == Life.LOOK_TURN_STEPS + 1,
		"Each cached head turn must have distinct transition pixels (left %d, right %d)" % [left_changes.size(), right_changes.size()], failures)
	var f: Dictionary = _fixture()
	_owner(f, true)
	var life: Dictionary = _presentation(library, f)
	var fixed_rect: Rect2 = Life.rest_rect(life)
	for sample: int in range(48):
		life["time_seconds"] = float(sample) * 0.25
		_check(Life.rest_rect(life) == fixed_rect,
			"All turns and transition amounts must retain the exact body and foot registration", failures)


static func _test_actual_scene_time_and_pause(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 650)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	var f: Dictionary = _fixture()
	_owner(f, true)
	main.world = f["world"]
	main.world.tick = 4750
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.hud.visible = false
	var actual: Dictionary = main.building_life_presentation(f["building"])
	_check(bool(actual.get("at_home", false)) and not actual.has("night"),
		"The actual main scene must expose the loaded hut's physical presence without any night state", failures)
	var saved: Dictionary = main.world.to_data()
	main.accumulator = MainView.FIXED_TICK_SECONDS * 0.25
	var fractional: Dictionary = main.building_life_presentation(f["building"])
	_check(is_equal_approx(float(fractional.get("time_seconds", -1.0)), 475.025),
		"The actual scene must derive animation time from saved ticks plus its fractional simulation accumulator", failures)
	for _frame: int in range(8):
		main._process(0.033)
	_check(main.world.to_data() == saved and main.building_life_presentation(f["building"]) == fractional,
		"Global pause must freeze the partially advanced animation time, presence and world state", failures)
	main._set_simulation_speed(2.0)
	main._process(0.01)
	_check(main.world.tick == 4750 and is_equal_approx(float(main.building_life_presentation(f["building"])
		.get("time_seconds", -1.0)) - float(fractional["time_seconds"]), 0.02),
		"Double speed must advance dynamic hut time at twice wall time between simulation steps", failures)
	var library := Life.new()
	_check(is_equal_approx(float(_presentation(library, f, -5.0).get("time_seconds", -1.0)), 475.0)
		and is_equal_approx(float(_presentation(library, f, 20.0).get("time_seconds", -1.0)), 475.1),
		"Presentation must clamp its interpolation fraction instead of extrapolating future animation frames", failures)
	main.world.tick = 1750
	main.accumulator = MainView.FIXED_TICK_SECONDS * 0.75
	main._set_simulation_speed(0.0)
	var day_rest: Dictionary = main.building_life_presentation(f["building"])
	var frozen_pose: String = Life.rest_pose_for(day_rest)
	_check(bool(day_rest.get("rest_visible", false)) and bool(day_rest.get("window_open", false))
		and not day_rest.has("light_strength"),
		"The actual main scene must display its present daytime resident beside an open unlit window", failures)
	for _frame: int in range(12):
		main._process(0.033)
	_check(main.building_life_presentation(f["building"]) == day_rest
		and Life.rest_pose_for(main.building_life_presentation(f["building"])) == frozen_pose,
		"Global pause in the actual daytime main scene must freeze the head direction and open window exactly", failures)
	viewport.free()
	await host.get_tree().process_frame
