extends Node

## Scene-based focused verification of the active artwork revision. The
## expected-art argument prevents a successful run against an older default
## from being mistaken for verification of newly authored resources.
const Sprites = preload("res://tests/sawmill_sprite_tests.gd")
const Life = preload("res://tests/production_building_life_tests.gd")
const Operation = preload("res://tests/sawmill_operation_tests.gd")
const QaAssets = preload("res://tests/sawmill_qa_assets.gd")
const Appearance = preload("res://tests/building_worker_appearance_tests.gd")
const Idle = preload("res://tests/building_worker_idle_tests.gd")


func _ready() -> void:
	# The suites instantiate the normal library default. Preview-only manifest
	# overrides must never make this runner certify a different artwork set.
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(QaAssets.Sprites.MANIFEST_PATH))
	var actual: String = String(manifest.get("asset_version", "")) if manifest is Dictionary else ""
	var expected: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expected-art="):
			expected = argument.trim_prefix("--expected-art=")
	print("SAWMILL REVISION ASSET: %s · %s · SHA256 %s" % [actual,
		QaAssets.Sprites.MANIFEST_PATH, FileAccess.get_sha256(QaAssets.Sprites.MANIFEST_PATH)])
	if actual.is_empty() or (not expected.is_empty() and actual != expected):
		printerr("Expected sawmill artwork %s; active manifest is %s. No passing revision verification claimed." % [expected, actual])
		get_tree().quit(1)
		return
	var failures: Array[String] = []
	failures.append_array(await Sprites.run(self))
	failures.append_array(Life.run())
	failures.append_array(await Operation.run(self))
	failures.append_array(await Appearance.run(self))
	failures.append_array(await Idle.run(self))
	for failure: String in failures:
		printerr(failure)
	var appearance_count: int = Appearance.TEST_COUNT - Appearance.NATIVE_PIXEL_TEST_COUNT \
		if DisplayServer.get_name() == "headless" else Appearance.TEST_COUNT
	var idle_count: int = Idle.TEST_COUNT - Idle.NATIVE_PIXEL_TEST_COUNT \
		if DisplayServer.get_name() == "headless" else Idle.TEST_COUNT
	print("SAWMILL REVISION %s: %d cases, %d failures" % [actual,
		Sprites.TEST_COUNT + Life.TEST_COUNT + Operation.TEST_COUNT + appearance_count + idle_count, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
