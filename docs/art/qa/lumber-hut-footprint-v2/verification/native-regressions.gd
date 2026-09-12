extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	var count: int = 0
	for path: String in ["res://tests/lumber_hut_construction_tests.gd", "res://tests/lumber_hut_stock_tests.gd",
			"res://tests/footprint_view_tests.gd", "res://tests/relief_view_tests.gd", "res://tests/slope_readability_tests.gd"]:
		var suite = load(path)
		var results: Array[String] = await suite.run(root)
		count += int(suite.TEST_COUNT)
		failures.append_array(results)
		print("NATIVE ", path, ": ", suite.TEST_COUNT, " cases, ", results.size(), " failures")
	for failure: String in failures:
		printerr(failure)
	print("LUMBER FOOTPRINT NATIVE REGRESSIONS: ", count, " cases, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
