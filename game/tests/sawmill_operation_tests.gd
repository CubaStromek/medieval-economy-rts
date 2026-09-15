extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Life = preload("res://scripts/view/production_building_life.gd")
const Operation = preload("res://scripts/view/sawmill_operation.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT := 22

class ObservedWorld extends World:
	var resident_reads := 0
	func workplace_worker(building_id: int) -> Dictionary:
		resident_reads += 1
		return super.workplace_worker(building_id)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_actual_inventory, _test_real_transport, _test_real_batch,
		_test_pause_holds_batch, _test_observed_interpolation, _test_nutritional_skips,
		_test_gap_and_new_batch, _test_save_world_and_rewind, _test_foreign_before_read,
		_test_supported_and_operator, _test_pose_mapping]:
		test.call(failures)
	_test_normal_scene_tick_observation(host, failures)
	# The art suite reuses the real production fixture above. Load it after this
	# script is ready so the fixture dependency does not become a preload cycle.
	var art_suite: Script = load("res://tests/sawmill_operation_art_tests.gd")
	failures.append_array(await art_suite.run(host))
	return failures


static func _fixture() -> Dictionary:
	var world := ObservedWorld.new(Vector2i(24, 18))
	world.tick = 1750
	var id: int = world.place_building("sawmill", Vector2i(8, 5))
	var building: Dictionary = world.buildings[id]
	var worker_id: int = world.spawn_worker(building["entrance"], "carpenter", id, true, id)
	world.economy_enabled = true
	return {"world": world, "building": building, "worker": world.workers[worker_id],
		"adapter": Operation.new(), "life": Life.new(),
		"house": {"rect": Rect2(100, 50, 250, 250), "source_to_world": 0.2, "life": {"door": []}}}


static func _sample(f: Dictionary, fraction: float = 1.0) -> Dictionary:
	var life: Dictionary = f["life"].presentation_for(f["world"], f["building"], f["house"], fraction)
	return f["adapter"].presentation_for(f["world"], f["building"], life, fraction)


static func _step(f: Dictionary, count: int = 1, observe: bool = true) -> void:
	for _tick: int in range(count):
		f["world"].step_tick()
		if observe:
			f["adapter"].observe_tick(f["world"])


static func _until(f: Dictionary, condition: Callable, ticks: int = 1000) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		_step(f)
	return condition.call()


static func _start(f: Dictionary, amount: int = 1) -> bool:
	f["building"]["inputs"]["log"] = amount
	return _until(f, func() -> bool: return bool(_sample(f)["active_work"]))


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _test_actual_inventory(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	# Unrelated physical cargo and storage cannot fill a sawmill's own racks.
	f["worker"]["carrying"] = "log"
	f["building"]["storage"] = {"log": 500, "plank": 500}
	for logs: int in range(5):
		for planks: int in range(7):
			f["building"]["inputs"]["log"] = logs
			f["building"]["outputs"]["plank"] = planks
			var sample: Dictionary = _sample(f)
			_check(int(sample["input_amount"]) == logs and int(sample["output_amount"]) == planks
				and int(sample["input_capacity"]) == 4 and int(sample["output_capacity"]) == 6
				and not bool(sample["in_process"]) and not bool(sample["active_work"]),
				"Every 0–4/0–6 rack state must represent only the actual local inventory", failures)
	f["world"].catalog.buildings["sawmill"]["input_capacity"] = 3
	f["world"].catalog.buildings["sawmill"]["output_capacity"] = 5
	var overflow: Dictionary = _sample(f)
	_check(int(overflow["input_capacity"]) == 3 and int(overflow["output_capacity"]) == 5
		and int(overflow["input_amount"]) == 4 and int(overflow["output_amount"]) == 6,
		"Capacity comes from the current catalog without silently rewriting existing quantities", failures)


static func _test_real_transport(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	world.economy_enabled = false
	var store_id: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[store_id]["storage"]["log"] = 1
	var carrier_id: int = world.spawn_worker(Vector2i(3, 7), "carrier")
	world.economy_enabled = true
	world.set_worker_enabled(f["worker"]["id"], false)
	_check(_until(f, func() -> bool: return world.workers[carrier_id]["carrying"] == "log"),
		"Real carrier must pick up the reserved input log", failures)
	_check(int(_sample(f)["input_amount"]) == 0, "An input in transit must not appear at the sawmill", failures)
	_check(_until(f, func() -> bool: return int(_sample(f)["input_amount"]) == 1),
		"The rack must gain its log on the carrier's actual delivery", failures)
	world.set_worker_enabled(carrier_id, false)
	world.set_worker_enabled(f["worker"]["id"], true)
	_check(_until(f, func() -> bool: return int(_sample(f)["output_amount"]) == 2),
		"A real delivered log must become two physical output planks", failures)
	world.set_worker_enabled(carrier_id, true)
	_check(_until(f, func() -> bool: return world.workers[carrier_id]["carrying"] == "plank"),
		"Real carrier must collect one output plank", failures)
	_check(int(_sample(f)["output_amount"]) == 1,
		"The output rack must lose its plank at pickup, before warehouse delivery", failures)


static func _test_real_batch(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f), "A real resident must begin the sawmill recipe", failures)
	var start: Dictionary = _sample(f)
	_check(int(start["input_amount"]) == 0 and int(start["output_amount"]) == 0
		and int(start["in_process_log_count"]) == 1 and int(start["total_work_ticks"]) == 60
		and int(start["completed_work_ticks"]) == 0,
		"Batch start must move one log from the input rack to its separate workpiece", failures)
	_step(f, 59)
	var last: Dictionary = _sample(f)
	_check(int(last["completed_work_ticks"]) == 59 and int(last["output_amount"]) == 0
		and bool(last["in_process"]), "No output plank may appear before the full sixty productive ticks", failures)
	_step(f)
	var done: Dictionary = _sample(f)
	_check(int(done["output_amount"]) == 2 and int(done["input_amount"]) == 0
		and not bool(done["in_process"]) and int(done["in_process_log_count"]) == 0
		and not bool(done["active_work"]), "Completion replaces the workpiece with exactly two stored planks", failures)


static func _test_pause_holds_batch(failures: Array[String]) -> void:
	for kind: String in ["worker", "building"]:
		var f: Dictionary = _fixture()
		_check(_start(f), "Pause fixture must begin a paid batch", failures)
		_step(f, 7)
		var world: World = f["world"]
		var remaining: int = f["building"]["process_remaining"]
		if kind == "worker":
			world.set_worker_enabled(f["worker"]["id"], false)
		else:
			world.set_building_enabled(f["building"]["id"], false)
		_step(f, 10)
		var paused: Dictionary = _sample(f, 0.2)
		_check(bool(paused["in_process"]) and int(paused["in_process_log_count"]) == 1
			and not bool(paused["active_work"]) and int(f["building"]["process_remaining"]) == remaining
			and float(paused["observed_work_ticks"]) == 7.0 and Operation.pose_index_for(paused, 6) == -1,
			"%s must retain the committed log and hold the productive clock without a working figure" % kind, failures)
		world.set_worker_enabled(f["worker"]["id"], true)
		world.set_building_enabled(f["building"]["id"], true)
		_check(_until(f, func() -> bool: return int(_sample(f)["output_amount"]) == 2),
			"Resuming %s must finish the paid log without consuming another input" % kind, failures)


static func _test_observed_interpolation(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f), "Interpolation fixture must begin work", failures)
	_step(f, 7)
	f["adapter"].reset()
	_check(float(_sample(f, 0.25)["observed_work_ticks"]) == 7.0,
		"The first observation of a mid-batch load must snap to earned work", failures)
	_step(f)
	var saved: Dictionary = f["world"].to_data()
	for fraction: float in [0.0, 0.25, 0.5, 1.0, 0.25]:
		_check(is_equal_approx(float(_sample(f, fraction)["observed_work_ticks"]), 7.0 + fraction),
			"Repeated drawing/picking must interpolate only the last observed 7→8 productive interval", failures)
	_check(f["world"].to_data() == saved, "Sampling stock and poses cannot mutate saved world or worker effort", failures)


static func _test_nutritional_skips(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f), "Nutrition fixture must begin production", failures)
	f["worker"]["hunger"] = 0
	f["worker"]["nutrition_deficit_ticks"] = 24000
	f["worker"]["work_effort_remainder"] = 0
	var skipped: int = 0
	for _index: int in range(30):
		var before: int = f["building"]["process_remaining"]
		_step(f)
		var sample: Dictionary = _sample(f, 0.25)
		if int(f["building"]["process_remaining"]) == before:
			skipped += 1
			_check(float(sample["observed_work_ticks"]) == float(60 - before)
				and _sample(f, 0.75)["progress"] == sample["progress"],
				"A nutritionally skipped tick must hold all animation fractions at the actual work already done", failures)
		var effort: int = f["worker"]["work_effort_remainder"]
		_sample(f, 0.9)
		_sample(f, 0.1)
		_check(int(f["worker"]["work_effort_remainder"]) == effort,
			"Rendering must never call the mutating work-efficiency gate", failures)
	_check(skipped == 6 and int(_sample(f)["completed_work_ticks"]) == 24,
		"The real eighty-percent worker must display 24 productive and six held ticks", failures)


static func _test_gap_and_new_batch(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f, 2), "Two-log fixture must begin first batch", failures)
	_step(f, 20, false)
	_check(float(_sample(f, 0.1)["observed_work_ticks"]) == 20.0,
		"An unobserved simulation gap must snap to actual work without fabricating an animation interval", failures)
	_check(_until(f, func() -> bool: return int(f["building"]["outputs"]["plank"]) == 2 and int(f["building"]["process_remaining"]) == 60),
		"The second input must start a distinct new batch", failures)
	_check(float(_sample(f, 0.5)["observed_work_ticks"]) == 0.0
		and int(_sample(f)["in_process_log_count"]) == 1,
		"New batch must reset its pose clock while retaining only its own committed log", failures)


static func _test_save_world_and_rewind(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f), "Save fixture must begin work", failures)
	_step(f, 17)
	var saved: Dictionary = f["world"].to_data()
	var loaded := World.new()
	_check(loaded.from_data(JSON.parse_string(JSON.stringify(saved))) and loaded.to_data() == saved,
		"The existing save format must retain the exact paid sawmill batch", failures)
	f["world"] = loaded
	f["building"] = loaded.buildings[f["building"]["id"]]
	_check(float(_sample(f, 0.1)["observed_work_ticks"]) == 17.0 and loaded.to_data() == saved,
		"A new world identity must discard interpolation history without changing loaded data", failures)
	loaded.tick -= 5
	f["building"]["process_remaining"] = 50
	_check(float(_sample(f, 0.1)["observed_work_ticks"]) == 10.0,
		"A tick rewind must discard future cached animation history", failures)


static func _test_foreign_before_read(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f), "Foreign fixture must first cache a local batch", failures)
	var world: ObservedWorld = f["world"]
	world.enable_fog()
	f["building"]["owner_id"] = 2
	f["worker"]["owner_id"] = 2
	# These deliberately invalid values make any premature private read fail.
	f["building"]["inputs"] = "private inventory must not be cast"
	f["building"]["outputs"] = "private inventory must not be cast"
	f["building"]["process_remaining"] = Vector2.INF
	f["building"]["recipe_id"] = Vector2.INF
	world.resident_reads = 0
	f["adapter"].observe_tick(world)
	var hidden: Dictionary = _sample(f)
	_check(not bool(hidden["known"]) and int(hidden["input_amount"]) == -1
		and int(hidden["output_amount"]) == -1 and int(hidden["in_process_log_count"]) == -1
		and not bool(hidden["active_work"]) and world.resident_reads == 0,
		"Foreign fog must return unknown before inventory, recipe, batch or resident lookup", failures)


static func _test_supported_and_operator(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	f["world"].workers.clear()
	f["world"].economy_enabled = false
	f["building"]["inputs"]["log"] = 1
	_step(f, 5)
	var legacy: Dictionary = _sample(f)
	_check(bool(legacy["in_process"]) and int(legacy["completed_work_ticks"]) > 0
		and not bool(legacy["active_work"]), "Legacy unattended processing may keep a workpiece but cannot invent a carpenter", failures)
	for pair: Array in [["construction_remaining", 1], ["footprint_version", 0], ["type", "lumber_hut"]]:
		var key: String = pair[0]
		var before: Variant = f["building"][key]
		f["building"][key] = pair[1]
		_check(_sample(f).is_empty(), "Unfinished, legacy-footprint or non-sawmill buildings must not receive operation art", failures)
		f["building"][key] = before


static func _test_pose_mapping(failures: Array[String]) -> void:
	for pair: Array in [[0, 0], [1, 1], [5, 5], [9, 9], [10, 0], [15, 5], [59, 9]]:
		var operation: Dictionary = {"known": true, "active_work": true, "in_process": true,
			"progress": float(pair[0]) / 60.0}
		_check(Operation.pose_index_for(operation, 10) == int(pair[1]),
			"Six productive loops must map measured batch ticks consistently at all frame boundaries", failures)
	for key: String in ["known", "active_work", "in_process"]:
		var operation: Dictionary = {"known": true, "active_work": true, "in_process": true, "progress": 0.5}
		operation[key] = false
		_check(Operation.pose_index_for(operation, 6) == -1, "Invisible or inactive operators cannot acquire work poses", failures)
	_check(Operation.pose_index_for({"known": true, "active_work": true, "in_process": true, "progress": NAN}, 6) == -1,
		"A nonfinite pose clock must fail closed", failures)


static func _test_normal_scene_tick_observation(host: Node, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(_start(f), "Normal-scene fixture must begin a real sawmill batch", failures)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	main.world = f["world"]
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.hud.visible = false
	main.simulation_speed = 1.0
	# The scene start restarts the game clock; consume it like the first real frame.
	main._advance_simulation(0.0)
	main.accumulator = 0.0
	main._process(MainView.FIXED_TICK_SECONDS * 5.25)
	var sample: Dictionary = main.building_operation_presentation(f["building"])
	_check(int(sample["completed_work_ticks"]) == 5 and is_equal_approx(float(sample["observed_work_ticks"]), 4.25),
		"Normal MainView fast-play must observe every simulation tick between draws, yielding the last 4→5 interval", failures)
	main.simulation_speed = 0.0
	var saved: Dictionary = main.world.to_data()
	for _frame: int in range(4):
		main._process(0.033)
	_check(main.world.to_data() == saved and main.building_operation_presentation(f["building"]) == sample,
		"Global pause must keep the scene's physical stocks, batch and fractional work pose unchanged", failures)
	# Load the same tick into the same World object: neither automatic identity
	# nor rewind detection can hide a missing normal-scene reset hook here.
	var temporary_root: String = OS.get_environment("TMPDIR")
	if temporary_root.is_empty():
		temporary_root = "/tmp"
	var path: String = temporary_root.path_join("sawmill-operation-load-%d.json" % main.get_instance_id())
	var wrote: bool = SaveSystemClass.save_world(main.world, path, "test")
	_check(wrote, "The same-world operation reload fixture must be saved successfully", failures)
	if wrote:
		var world_identity: int = main.world.get_instance_id()
		main.save_path_override = path
		main._load_game()
		var loaded: Dictionary = main.building_operation_presentation(main.world.buildings[f["building"]["id"]])
		_check(main.world.get_instance_id() == world_identity and int(loaded["completed_work_ticks"]) == 5
			and float(loaded["observed_work_ticks"]) == 5.0 and main.accumulator == 0.0,
			"Normal same-world/same-tick load must reset the old fractional pose and show exact saved productive work", failures)
		DirAccess.remove_absolute(path)
	viewport.free()
