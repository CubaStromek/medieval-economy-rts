extends Node

const SUITES: Array = [
	preload("res://tests/kam_terrain_sample_tests.gd"),
	preload("res://tests/kam_terrain_sandbox_renderer_tests.gd"),
	preload("res://tests/terrain_sandbox_objects_tests.gd"),
	preload("res://tests/terrain_sandbox_state_tests.gd"),
]

func _ready() -> void:
	var count: int = 0
	var failures: Array[String] = []
	for suite: Variant in SUITES:
		count += int(suite.TEST_COUNT)
		failures.append_array(suite.run())
	for failure: String in failures:
		printerr(failure)
	print("GRAPHICS SANDBOX: %d cases, %d failures" % [count, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
