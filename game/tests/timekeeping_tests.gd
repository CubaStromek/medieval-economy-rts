extends RefCounted

## Game time follows real time like KaM Remake: slow frames replay the owed
## ticks instead of slowing the game, within a capped backlog and frame budget.
const World = preload("res://scripts/simulation/simulation_world.gd")
const MainScene = preload("res://scenes/main.tscn")
const MainView = preload("res://scripts/view/main_view.gd")
const TEST_COUNT: int = 5
const TICK: float = MainView.FIXED_TICK_SECONDS


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_long_frame_replays_owed_ticks, _test_frame_split_holds_time,
		_test_stall_backlog_is_capped, _test_budget_keeps_owed_ticks, _test_restart_ignores_loading_time]:
		var scene: Dictionary = _scene(host)
		test.call(scene["main"], failures)
		(scene["viewport"] as SubViewport).free()
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _scene(host: Node) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	main.world = World.new(Vector2i(12, 10))
	viewport.add_child(main)
	# Frames of the host tree must not add ticks; each test drives time itself.
	main.set_process(false)
	main.hud.visible = false
	main.simulation_speed = 1.0
	# The scene start restarted the clock; consume it like the first real frame.
	main._advance_simulation(0.0)
	return {"main": main, "viewport": viewport}


static func _test_long_frame_replays_owed_ticks(main: MainView, failures: Array[String]) -> void:
	main.accumulator = 0.04
	main._process(2.5)
	_check(main.world.tick == 25 and absf(main.accumulator - 0.04) < 0.000001,
		"A 2.5 s frame at 1x must replay all 25 owed ticks and keep the fractional tick (was capped at 8)", failures)


static func _test_frame_split_holds_time(main: MainView, failures: Array[String]) -> void:
	main._set_simulation_speed(2.0)
	for delta: float in [0.016, 0.9, 0.3, 0.033, 0.251]:
		main._advance_simulation(delta)
	_check(main.world.tick == 30 and absf(main.accumulator) < 0.000001,
		"1.5 s of uneven frames at 2x must play exactly 30 ticks, the same as one frame", failures)
	main.accumulator = TICK * 0.3
	main._set_simulation_speed(0.5)
	var played: int = main._advance_simulation(0.5)
	_check(played == 2 and absf(main.accumulator - 0.08) < 0.000001,
		"A speed change must keep the fractional tick and count later time at the new speed", failures)
	main._set_simulation_speed(0.0)
	_check(main._advance_simulation(5.0) == 0 and absf(main.accumulator - 0.08) < 0.000001 and main.world.tick == 32,
		"Pause must neither play ticks nor owe time for the paused seconds", failures)


static func _test_stall_backlog_is_capped(main: MainView, failures: Array[String]) -> void:
	var played: int = main._advance_simulation(60.0)
	_check(played == MainView.MAX_TICK_BACKLOG and main.world.tick == MainView.MAX_TICK_BACKLOG and absf(main.accumulator) < 0.000001,
		"A one-minute stall must replay only the capped 10 s backlog, not the whole minute", failures)
	_check(main._advance_simulation(0.1) == 1 and main.world.tick == MainView.MAX_TICK_BACKLOG + 1,
		"Normal frames after a capped stall must continue at real time", failures)


static func _test_budget_keeps_owed_ticks(main: MainView, failures: Array[String]) -> void:
	# A zero budget stops after the one tick that always runs.
	main.catch_up_budget_usec = 0
	var played: int = main._advance_simulation(1.0)
	_check(played == 1 and absf(main.accumulator - 0.9) < 0.000001,
		"An exhausted frame budget must leave the remaining ticks owed instead of dropping them", failures)
	for _frame: int in range(9):
		played += main._advance_simulation(0.0)
	_check(played == 10 and main.world.tick == 10 and absf(main.accumulator) < 0.000001
		and main._advance_simulation(0.0) == 0,
		"Owed ticks must be caught up over the following frames without losing or adding game time", failures)


static func _test_restart_ignores_loading_time(main: MainView, failures: Array[String]) -> void:
	main.accumulator = TICK * 0.6
	main._restart_game_clock()
	_check(main._advance_simulation(30.0) == 0 and main.world.tick == 0 and main.accumulator < TICK,
		"The frame after a load or restart must not replay the real time spent loading", failures)
	main.accumulator = 0.0
	_check(main._advance_simulation(0.35) == 3 and main.world.tick == 3,
		"Only the first frame after a restart is limited; later frames count their full time", failures)
	main.accumulator = TICK * 0.6
	main._reset_demo()
	_check(main.accumulator == 0.0 and main._advance_simulation(30.0) == 0,
		"Resetting the demo must restart the game clock", failures)
