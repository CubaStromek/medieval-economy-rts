extends Node

const World = preload("res://scripts/simulation/simulation_world.gd")
const Presentation = preload("res://scripts/view/lumberjack_presentation.gd")
const TEST_COUNT: int = 10


func _ready() -> void:
	var failures: Array[String] = run(self)
	for failure: String in failures:
		push_error(failure)
	print("LUMBERJACK PRESENTATION: %d groups; %d failures" % [TEST_COUNT, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


static func run(_host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_directions(failures)
	_test_motion_priority(failures)
	_test_work_eligibility(failures)
	_test_coincident_tree(failures)
	_test_observed_work(failures)
	_test_distance_and_pause(failures)
	_test_turns_and_tick_sampling(failures)
	_test_slope_distance(failures)
	_test_visibility(failures)
	_test_save_and_read_only(failures)
	return failures


static func _fixture() -> Dictionary:
	var world := World.new(Vector2i(16, 12))
	var id: int = world.spawn_worker(Vector2i(5, 5), "lumberjack")
	var tree: int = world.add_tree(Vector2i(5, 5), 3)
	return {"world": world, "worker": world.workers[id], "tree": tree}


static func _working(fixture: Dictionary) -> void:
	var worker: Dictionary = fixture["worker"]
	worker["state"] = "working"
	worker["action"] = "harvest"
	worker["source_id"] = fixture["tree"]
	worker["work_remaining"] = 30


static func _edge(worker: Dictionary, from: Vector2i, to: Vector2i, progress: int, duration: int) -> void:
	worker["previous_position"] = from
	worker["position"] = to
	worker["visual_progress_ticks"] = progress
	worker["visual_duration_ticks"] = duration


static func _test_directions(failures: Array[String]) -> void:
	var directions: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var vectors: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
	var fixture: Dictionary = _fixture()
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	for index: int in range(8):
		_edge(worker, Vector2i(5,5) - vectors[index], Vector2i(5,5), 1, 4)
		var pose: Dictionary = helper.sample(fixture["world"], worker, 0.25)
		_expect(pose["direction"] == directions[index] and pose["clip"] == "walk_axe", "Authored direction " + directions[index], failures)
	_expect(Presentation.direction_for_vector(Vector2i.ZERO) == "S", "Zero vector has explicit initial S", failures)
	_expect(Presentation.direction_for_vector(Vector2i.ZERO, "invalid") == "S", "Invalid fallback cannot invent an absent direction", failures)


static func _test_motion_priority(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	_working(fixture)
	_edge(worker, Vector2i(4,5), Vector2i(5,5), 1, 4)
	_expect(helper.sample(fixture["world"], worker, 0.5)["clip"] == "walk_axe", "Committed motion precedes harvest", failures)
	worker["state"] = "idle"
	worker["carrying"] = "log"
	var pose: Dictionary = helper.sample(fixture["world"], worker, 0.5)
	_expect(pose["moving"] and pose["clip"] == "walk_log" and not pose["at_rest"], "Cancelled idle task keeps its committed loaded step", failures)
	worker["visual_progress_ticks"] = 4
	pose = helper.sample(fixture["world"], worker, 0.5)
	_expect(pose["clip"] == "walk_log" and pose["at_rest"], "Blocked/stationary cargo keeps the authored log", failures)
	worker["carrying"] = "stone"
	_expect(helper.sample(fixture["world"], worker, 0.5)["clip"] == "walk_axe", "Other cargo never becomes a fictional log", failures)


static func _test_work_eligibility(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var tree: Dictionary = world.trees[fixture["tree"]]
	var helper := Presentation.new()
	_working(fixture)
	_expect(helper.sample(world, worker, 0.0)["chopping"], "Real mature source with active work uses chop", failures)
	for change: Dictionary in [{"state":"moving"}, {"action":"eat"}, {"work_remaining":0}, {"enabled":false}, {"source_id":9999}, {"carrying":"log"}]:
		var altered: Dictionary = worker.duplicate(true)
		altered.merge(change, true)
		_expect(not helper.sample(world, altered, 0.0)["chopping"], "Invalid work must not animate: " + str(change), failures)
	tree["age_ticks"] = 0
	_expect(not helper.sample(world, worker, 0.0)["chopping"], "Sapling is not a valid working source", failures)
	tree["age_ticks"] = World.TREE_MATURE_AGE_TICKS
	tree["amount"] = 0
	_expect(not helper.sample(world, worker, 0.0)["chopping"], "Depleted source is not productive work", failures)
	tree["amount"] = 3
	world.economy_enabled = true
	world.tick = 4000
	_expect(not helper.sample(world, worker, 0.0)["chopping"], "Night work restrictions remain authoritative", failures)


static func _test_coincident_tree(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	_working(fixture)
	_edge(worker, Vector2i(6,5), Vector2i(5,5), 4, 4)
	var before: Dictionary = worker.duplicate(true)
	_expect(helper.sample(fixture["world"], worker, 0.0)["direction"] == "W", "Zero tree-worker vector retains real westward arrival", failures)
	_expect(worker == before, "Choosing working direction must not move worker or target", failures)
	worker["previous_position"] = worker["position"]
	_expect(helper.sample(fixture["world"], worker, 0.0)["direction"] == "W", "Cached heading survives a genuinely zero movement vector", failures)
	helper.reset()
	_expect(helper.sample(fixture["world"], worker, 0.0)["direction"] == "S", "Fresh coincident worker has deterministic S without fabricated neighbor", failures)


static func _test_observed_work(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	_working(fixture)
	var first: Dictionary = helper.sample(world, worker, 0.0)
	_expect(first["work_cycles"] == 2 and is_zero_approx(first["elapsed_seconds"]), "Thirty productive ticks select exactly two authored cycles", failures)
	world.tick += 1
	worker["work_remaining"] = 29
	helper.sample(world, worker, 0.0) # Same observation order as main._process.
	var half: Dictionary = helper.sample(world, worker, 0.5)
	_expect(is_equal_approx(half["work_progress"], 0.5 / 30.0), "Interpolate only the observed completed productive tick", failures)
	_expect(is_equal_approx(half["elapsed_seconds"], (0.5 / 30.0) * 2.0 * (4.0/3.0)), "Whole-cycle timing follows real work progress", failures)
	_expect(half == helper.sample(world, worker, 0.5), "Repeated draw/hit work samples are idempotent", failures)
	world.tick += 1 # Nutrition can deny this productive tick; remaining stays29.
	var held: Dictionary = helper.sample(world, worker, 0.0)
	_expect(is_equal_approx(held["work_progress"], 1.0 / 30.0) and held == helper.sample(world, worker, 0.9), "Skipped productive tick must hold, not predict more work", failures)


static func _test_distance_and_pause(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	_edge(worker, Vector2i(4,5), Vector2i(5,5), 0, 4)
	helper.sample(world, worker, 0.0)
	worker["visual_progress_ticks"] = 1
	world.tick = 1
	helper.sample(world, worker, 0.0)
	var pose: Dictionary = helper.sample(world, worker, 0.6)
	_expect(is_equal_approx(pose["distance_world_px"], 16.0) and is_equal_approx(pose["elapsed_seconds"], 0.8), "Sixteen interpolated world pixels produce one double-step", failures)
	for repeat: int in range(5):
		_expect(helper.sample(world, worker, 0.6) == pose, "Paused/redrawn movement does not advance #" + str(repeat), failures)
	worker["carrying"] = "log"
	var loaded: Dictionary = helper.sample(world, worker, 0.6)
	_expect(loaded["clip"] == "walk_log" and loaded["distance_world_px"] == pose["distance_world_px"], "Changing cargo keeps distance phase", failures)
	var slow := Presentation.new()
	_edge(worker, Vector2i(4,5), Vector2i(5,5), 2, 8)
	_expect(is_equal_approx(slow.sample(world, worker, 0.0)["distance_world_px"], 10.0), "Slow terrain quarter-step measures ten pixels, not elapsed wall time", failures)


static func _test_turns_and_tick_sampling(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	_edge(worker, Vector2i(4,4), Vector2i(5,4), 0, 2)
	helper.sample(world, worker, 0.0)
	world.tick = 1
	worker["visual_progress_ticks"] = 1
	helper.sample(world, worker, 0.0)
	world.tick = 2
	_edge(worker, Vector2i(5,4), Vector2i(5,5), 0, 2)
	helper.sample(world, worker, 0.0)
	world.tick = 3
	worker["visual_progress_ticks"] = 1
	var turn: Dictionary = helper.sample(world, worker, 0.0)
	_expect(is_equal_approx(turn["distance_world_px"], 60.0) and turn["direction"] == "S", "Per-tick observations preserve the full corner path across multiple ticks per frame", failures)
	_expect(turn == helper.sample(world, worker, 0.0), "Final draw after batched ticks adds no distance", failures)
	world.tick = 4
	_edge(worker, Vector2i(5,5), Vector2i(6,6), 0, 4)
	helper.sample(world, worker, 0.0)
	world.tick = 6
	worker["visual_progress_ticks"] = 2
	var diagonal: Dictionary = helper.sample(world, worker, 0.0)
	_expect(is_equal_approx(diagonal["distance_world_px"], 80.0 + sqrt(800.0)), "Diagonal contributes its actual half-edge length without resetting heading changes", failures)


static func _test_slope_distance(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	# A plane rising one height unit per X: east travel projects (40,-8).
	for y: int in range(4, 8):
		for x: int in range(3, 8):
			world.grid.set_vertex_height(Vector2i(x,y), x - 3)
	_edge(worker, Vector2i(4,5), Vector2i(5,5), 2, 4)
	var pose: Dictionary = Presentation.new().sample(world, worker, 0.0)
	_expect(is_equal_approx(pose["distance_world_px"], Vector2(20,-4).length()), "Slope distance uses the same center +0.5 height projection as the renderer", failures)
	_expect(pose["direction"] == "E", "Height projection must never change logical facing", failures)


static func _test_visibility(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	worker["inside_building_id"] = 99
	_expect(not helper.sample(world, worker, 0.0)["visible"], "Indoor retained worker cannot expose any presentation", failures)
	worker["inside_building_id"] = 0
	world.enable_fog(2)
	_expect(not helper.sample(world, worker, 0.0)["visible"], "Unseen foreign worker cannot expose animation state", failures)
	worker["type"] = "carrier"
	_expect(not helper.sample(world, worker, 0.0)["handled"], "Other professions stay with their existing renderer", failures)


static func _test_save_and_read_only(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var worker: Dictionary = fixture["worker"]
	var helper := Presentation.new()
	world.tick = 100
	_edge(worker, Vector2i(6,5), Vector2i(5,5), 2, 4)
	var saved: Dictionary = world.to_data()
	var workers: Dictionary = world.workers.duplicate(true)
	var trees: Dictionary = world.trees.duplicate(true)
	for fraction: float in [0.0,0.25,0.5,0.75,0.75]:
		helper.sample(world, worker, fraction)
	_expect(saved == world.to_data() and workers == world.workers and trees == world.trees, "Sampling must preserve authoritative and saved fields including nutrition/work effort", failures)
	var loaded := World.new()
	_expect(loaded.from_data(saved), "Actual save loads without new animation fields or format change", failures)
	var loaded_worker: Dictionary = loaded.workers[int(worker["id"])]
	var pose: Dictionary = helper.sample(loaded, loaded_worker, 0.0)
	_expect(pose["direction"] == "S" and pose["at_rest"] and is_zero_approx(pose["distance_world_px"]), "New world identity discards transient heading/distance and uses loaded state", failures)
	_edge(loaded_worker, Vector2i(6,5), Vector2i(5,5), 2, 4)
	helper.sample(loaded, loaded_worker, 0.25)
	loaded.tick -= 1
	loaded_worker["previous_position"] = loaded_worker["position"]
	pose = helper.sample(loaded, loaded_worker, 0.0)
	_expect(pose["direction"] == "S" and is_zero_approx(pose["distance_world_px"]), "Backward simulation tick resets local presentation history", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
