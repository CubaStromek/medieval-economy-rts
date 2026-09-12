extends Node

const Suite = preload("res://tests/transport_search_tests.gd")


func _ready() -> void:
	var failures: Array[String] = Suite.run()
	for failure: String in failures:
		printerr(failure)
	print("TRANSPORT SEARCH: %d cases, %d failures" % [Suite.TEST_COUNT, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
