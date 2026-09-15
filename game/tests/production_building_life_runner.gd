extends SceneTree

const Suite = preload("res://tests/production_building_life_tests.gd")

func _initialize() -> void:
	var failures: Array[String] = Suite.run()
	for failure: String in failures:
		printerr(failure)
	print("PRODUCTION BUILDING LIFE: %d cases, %d failures" % [Suite.TEST_COUNT, failures.size()])
	quit(0 if failures.is_empty() else 1)
