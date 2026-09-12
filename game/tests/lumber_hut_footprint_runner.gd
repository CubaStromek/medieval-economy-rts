extends Node

const Suite = preload("res://tests/lumber_hut_footprint_tests.gd")


func _ready() -> void:
	var failures: Array[String] = Suite.run()
	for failure: String in failures:
		printerr(failure)
	print("LUMBER HUT FOOTPRINT: %d cases, %d failures" % [Suite.TEST_COUNT, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
