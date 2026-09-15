extends Node

const Suite = preload("res://tests/building_worker_appearance_tests.gd")


func _ready() -> void:
	var failures: Array[String] = await Suite.run(self)
	for failure: String in failures:
		printerr(failure)
	var native: bool = DisplayServer.get_name() != "headless"
	print("BUILDING WORKER APPEARANCE: %d cases, %d executed, %d native pixel cases, %d failures" % [
		Suite.TEST_COUNT, Suite.TEST_COUNT if native else 1,
		Suite.NATIVE_PIXEL_TEST_COUNT if native else 0, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
