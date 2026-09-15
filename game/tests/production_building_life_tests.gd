extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Life = preload("res://scripts/view/production_building_life.gd")
const SawmillQaAssets = preload("res://tests/sawmill_qa_assets.gd")
const TEST_COUNT := 12

class ObservedWorld extends World:
	var resident_reads := 0
	func workplace_worker(building_id: int) -> Dictionary:
		resident_reads += 1
		return super.workplace_worker(building_id)


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_presence_and_visitors, _test_natural_production_then_rest,
		_test_work_pause, _test_rest_exclusions, _test_inventory_independence, _test_foreign_privacy_before_read,
		_test_construction, _test_time_and_read_only, _test_role_from_catalog,
		_test_imported_rest_body_and_hitmask, _test_imported_looks_keep_body, _test_idle_presence_and_registration]:
		test.call(failures)
	return failures


static func _fixture(inside: bool = false, type: String = "sawmill", role: String = "carpenter") -> Dictionary:
	var world := ObservedWorld.new(Vector2i(24, 18))
	world.tick = 1750
	var building_id: int = world.place_building(type, Vector2i(8, 5))
	var building: Dictionary = world.buildings[building_id]
	var cell: Vector2i = building["entrance"] if inside else Vector2i(13, 9)
	var worker_id: int = world.spawn_worker(cell, role, building_id, true, building_id if inside else 0)
	world.economy_enabled = true
	return {"world": world, "building": building, "worker": world.workers[worker_id], "library": Life.new(),
		"house": {"rect": Rect2(100, 50, 250, 250), "source_to_world": 0.2, "life": {"door": []}}}


static func _life(f: Dictionary, fraction: float = 0.0) -> Dictionary:
	return f["library"].presentation_for(f["world"], f["building"], f["house"], fraction)


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _until(world: World, condition: Callable, ticks: int = 900) -> bool:
	for _index: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _test_presence_and_visitors(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var building: Dictionary = f["building"]
	var visitor: int = world.spawn_worker(building["entrance"], "carrier", 0, false, building["id"])
	_check(visitor != 0 and not bool(_life(f)["at_home"]) and not bool(_life(f)["door_open"]),
		"An assigned outdoor carpenter and indoor carrier must not become a resting sawmill owner", failures)
	world.set_worker_enabled(f["worker"]["id"], false)
	_check(_until(world, func() -> bool: return bool(_life(f)["at_home"])),
		"A personally paused carpenter must physically return through normal routing", failures)
	var life: Dictionary = _life(f)
	_check(bool(life["door_open"]) and bool(life["window_open"]) and bool(life["rest_visible"])
		and int(life["rest_worker_id"]) == int(f["worker"]["id"]) and not life.has("light_strength"),
		"Only the actual resident supplies the dark open window and resting figure", failures)


static func _test_natural_production_then_rest(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var building: Dictionary = f["building"]
	building["inputs"]["log"] = 1
	_check(_until(world, func() -> bool: return bool(_life(f)["active_work"])),
		"The production fixture must walk its real carpenter inside and start a real log batch", failures)
	var active: Dictionary = _life(f)
	_check(bool(active["at_home"]) and bool(active["door_open"]) and not bool(active["rest_visible"])
		and not bool(active["window_open"]) and not active.has("smoke_strength"),
		"Actual sawmill production cannot display the household resting figure/window", failures)
	_check(_until(world, func() -> bool: return int(building["outputs"]["plank"]) == 2 and bool(_life(f)["rest_visible"])),
		"Finishing the real last log batch must leave an idle indoor carpenter available to rest", failures)
	_check(int(building["inputs"]["log"]) == 0 and int(building["process_remaining"]) == 0,
		"The real production rest sample must retain the catalog's one-log/two-plank accounting", failures)
	building["inputs"]["log"] = 1
	_check(_until(world, func() -> bool: return bool(_life(f)["active_work"]) and not bool(_life(f)["rest_visible"])),
		"A newly available log must end the rest pose immediately when normal production resumes", failures)


static func _test_work_pause(failures: Array[String]) -> void:
	for pause_building: bool in [false, true]:
		var f: Dictionary = _fixture(true)
		var world: World = f["world"]
		f["building"]["inputs"]["log"] = 1
		_check(_until(world, func() -> bool: return bool(_life(f)["active_work"])), "Pause fixture must start production", failures)
		var remaining: int = int(f["building"]["process_remaining"])
		if pause_building:
			world.set_building_enabled(f["building"]["id"], false)
		else:
			world.set_worker_enabled(f["worker"]["id"], false)
		world.step_tick()
		_check(bool(_life(f)["rest_visible"]) and not bool(_life(f)["active_work"])
			and int(f["building"]["process_remaining"]) == remaining,
			"Personal/building pause may expose the actual indoor rest without advancing the saved batch", failures)


static func _test_rest_exclusions(failures: Array[String]) -> void:
	var f: Dictionary = _fixture(true)
	var worker: Dictionary = f["worker"]
	for sample: Array in [["idle", "deliver_plank", "", 0], ["idle", "", "plank", 0],
		["idle", "eat", "", 1], ["moving", "pause_return", "", 0],
		["working", "operate", "", 0]]:
		worker["state"] = sample[0]
		worker["action"] = sample[1]
		worker["carrying"] = sample[2]
		worker["meal_ticks_left"] = sample[3]
		_check(not bool(_life(f)["rest_visible"]), "Cargo, work, food and movement cannot masquerade as household rest: " + str(sample), failures)


static func _test_inventory_independence(failures: Array[String]) -> void:
	var f: Dictionary = _fixture(true)
	for stocks: Array in [[0, 0], [4, 0], [0, 6], [4, 6]]:
		f["building"]["inputs"]["log"] = stocks[0]
		f["building"]["outputs"]["plank"] = stocks[1]
		_check(bool(_life(f)["rest_visible"]) and not bool(_life(f)["active_work"]),
			"Reading stock alone must never start an animation or change actual indoor rest", failures)


static func _test_foreign_privacy_before_read(failures: Array[String]) -> void:
	var f: Dictionary = _fixture(true)
	var world: ObservedWorld = f["world"]
	world.enable_fog()
	f["building"]["owner_id"] = 2
	f["worker"]["owner_id"] = 2
	world.resident_reads = 0
	var life: Dictionary = _life(f)
	_check(not bool(life["known"]) and world.resident_reads == 0 and not bool(life["rest_visible"]),
		"Foreign fog privacy must return before workplace_worker is read, even for a real indoor resident", failures)


static func _test_construction(failures: Array[String]) -> void:
	var f: Dictionary = _fixture(true)
	f["building"]["construction_remaining"] = 1
	_check(_life(f).is_empty(), "A final-looking but unfinished construction tick must not display household life", failures)
	f["building"]["construction_remaining"] = 0
	f["house"]["life"] = {}
	_check(_life(f).is_empty(), "Unauthored buildings cannot acquire generic geometry or a resident sprite", failures)


static func _test_time_and_read_only(failures: Array[String]) -> void:
	var f: Dictionary = _fixture(true)
	var before: String = JSON.stringify([f["building"], f["worker"]])
	var a: Dictionary = _life(f, 0.25)
	var b: Dictionary = _life(f, 0.25)
	_check(a == b and JSON.stringify([f["building"], f["worker"]]) == before,
		"Repeated paused-time presentation must be deterministic and not mutate worker/stock/state", failures)
	var fixed_rect: Rect2 = a["rect"]
	var poses: Dictionary = {}
	for sample_tick: int in range(120):
		f["world"].tick = 1800 + sample_tick
		var sample: Dictionary = _life(f)
		poses[f["library"].rest_pose_for(sample)] = true
		_check(sample["rect"] == fixed_rect, "Looking must never move the registered house/body rectangle", failures)
	_check(poses.has("left") and poses.has("right") and poses.has("center"),
		"The fixed-body rest rhythm must include restrained left/center/right looks", failures)


static func _test_role_from_catalog(failures: Array[String]) -> void:
	var f: Dictionary = _fixture(true, "bakery", "baker")
	_check(bool(_life(f)["at_home"]) and bool(_life(f)["rest_visible"]),
		"The same household state adapter must use the actual catalog profession rather than hardcoded carpenter identity", failures)


static func _rest_fixture() -> Dictionary:
	var f: Dictionary = _fixture(true)
	var life: Dictionary = SawmillQaAssets.manifest().get("life", {})
	f["house"]["life"]["rest_sprite"] = (life.get("rest_sprite", {}) as Dictionary).duplicate(true)
	f["house"]["life"]["rest_foot"] = [100,220]
	return f


static func _test_imported_rest_body_and_hitmask(failures: Array[String]) -> void:
	var f: Dictionary = _rest_fixture()
	var life: Dictionary = _life(f)
	var rect: Rect2 = f["library"].rest_rect(life)
	_check(rect.has_area() and rect.size.is_equal_approx(Vector2(51.2,51.2)),
		"The delivered 256px carpenter with measured 165px body must use33worldpx, independently of the house canvas", failures)
	if not rect.has_area():
		return
	var rest: Dictionary = f["house"]["life"]["rest_sprite"]
	var anchor: Array = rest["ground_contact"]
	var foot: Vector2 = rect.position + Vector2(float(anchor[0]),float(anchor[1])) * 0.2
	_check(foot.is_equal_approx(Vector2(120,94)), "The delivered carpenter's actual foot must register to the authored building rest point", failures)
	_check(not f["library"].contains_point(life,rect.position+Vector2(0.5,0.5)), "Transparent rest-canvas padding must not be a clickable worker", failures)
	var pixels: Image = _imported_image(rest["texture"])
	var visible: Vector2i = Vector2i(-1,-1)
	for y: int in range(100,180):
		for x: int in range(pixels.get_width()):
			if pixels.get_pixel(x,y).a > 0.9:
				visible = Vector2i(x,y)
				break
		if visible.x >= 0:
			break
	_check(visible.x >= 0 and f["library"].contains_point(life,rect.position+(Vector2(visible)+Vector2(0.5,0.5))*0.2),
		"A genuinely opaque torso pixel must select the actual resting worker", failures)
	for sample_tick: int in range(120):
		f["world"].tick = 1800+sample_tick
		_check(f["library"].rest_rect(_life(f)) == rect, "Actual head-look frames must retain one fixed measured rest rectangle", failures)


static func _test_imported_looks_keep_body(failures: Array[String]) -> void:
	var rest: Dictionary = _rest_fixture()["house"]["life"]["rest_sprite"]
	_check(not rest.is_empty() and ResourceLoader.exists(String(rest.get("texture", ""))),
		"Head-look checks must load the resting carpenter referenced by the active sawmill manifest", failures)
	if rest.is_empty() or not ResourceLoader.exists(String(rest.get("texture", ""))):
		return
	var original: Image = _imported_image(rest["texture"])
	for side: String in ["left","right"]:
		var path: String = String((rest.get("look_textures", {}) as Dictionary).get(side, ""))
		_check(not path.is_empty() and ResourceLoader.exists(path), "The active sawmill must deliver its actual " + side + " rest look", failures)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var pose: Image = _imported_image(path)
		_check(pose.get_size()==original.get_size(), "Each delivered head look needs the identical sprite canvas", failures)
		var changed_head := 0
		var changed_body := 0
		for y: int in range(original.get_height()):
			for x: int in range(original.get_width()):
				if original.get_pixel(x,y)!=pose.get_pixel(x,y):
					if y>=79:
						changed_body+=1
					else:
						changed_head+=1
		_check(changed_body==0 and changed_head>0,
			"Delivered "+side+" look must change the head while preserving every torso/arm/foot RGBA pixel", failures)


static func _imported_image(path: String) -> Image:
	var pixels: Image = (load(path) as Texture2D).get_image()
	if pixels.is_compressed():
		pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	return pixels


static func _test_idle_presence_and_registration(failures: Array[String]) -> void:
	var f: Dictionary = _rest_fixture()
	var life: Dictionary = _life(f)
	var rect: Rect2 = f["library"].rest_rect(life)
	var before: String = JSON.stringify(f["world"].to_data())
	var offsets: Dictionary = {}
	for index: int in range(49):
		var sample: Dictionary = life.duplicate(true)
		sample["time_seconds"] = float(index) * 0.1
		var motion: Dictionary = f["library"].rest_motion_for(sample)
		_check(not motion.is_empty(), "The actual active sawmill must enable its authored idle body motion", failures)
		if motion.is_empty():
			continue
		offsets[str(motion["offset_world"])] = true
		_check((motion["offset_world"] as Vector2).length() <= 0.324 \
			and is_equal_approx(float(motion["fixed_from_y"]), 142.0) \
			and f["library"].rest_rect(sample) == rect,
			"Real idle must move only the restrained upper body and keep its foot registration fixed", failures)
	_check(offsets.size() > 10 and JSON.stringify(f["world"].to_data()) == before,
		"Visible idle offsets need actual variation without mutating any serialized game state", failures)
	for key: String in ["known", "rest_visible"]:
		var hidden: Dictionary = life.duplicate(true)
		hidden[key] = false
		_check(f["library"].rest_motion_for(hidden).is_empty(),
			"A hidden or non-resting worker must not expose an idle body motion", failures)
	var invalid_house: Dictionary = f["house"].duplicate(true)
	invalid_house["life"]["rest_sprite"]["idle_motion"]["fixed_from_y"] = 220
	var invalid: Dictionary = f["library"].presentation_for(f["world"], f["building"], invalid_house)
	_check(not f["library"].rest_rect(invalid).has_area(),
		"Idle data extending deformation through the measured supporting foot must fail safely", failures)
