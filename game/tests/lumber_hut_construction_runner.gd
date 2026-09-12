extends Node

const Suite = preload("res://tests/lumber_hut_construction_tests.gd")


func _ready() -> void:
	var failures: Array[String] = await Suite.run(self)
	for failure: String in failures:
		printerr(failure)
	print("LUMBER HUT CONSTRUCTION: %d cases, %d failures" % [Suite.TEST_COUNT, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
