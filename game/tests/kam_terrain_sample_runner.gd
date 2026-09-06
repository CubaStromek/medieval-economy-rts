extends Node

# Standalone tests: no original KaM assets, game world or save files required.
const Tests = preload("res://tests/kam_terrain_sample_tests.gd")

func _ready() -> void:
	var failures: Array[String] = Tests.run()
	for failure: String in failures:
		printerr(failure)
	print("REFERENCE TERRAIN TESTS: %d cases, %d failures" % [Tests.TEST_COUNT, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
