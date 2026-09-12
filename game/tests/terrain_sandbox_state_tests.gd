extends RefCounted

const State = preload("res://scripts/view/terrain_sandbox_state.gd")
const TEST_COUNT: int = 7

static func run() -> Array[String]:
	var failures: Array[String] = []
	var state := State.new()
	var before: Dictionary = state.snapshot()
	if state.values["trees"] or state.values["shadows"] or state.values["grid"] or state.values["markers"]:
		failures.append("Experimental overlays must be opt-in, never presented as original KaM art.")
	for key: String in State.RANGES:
		state.set_value(key, NAN)
		state.set_value(key, "1")
		state.set_value(key, true)
	if state.snapshot() != before:
		failures.append("Invalid numeric values must preserve existing sandbox settings.")
	state.set_value("relief_scale", 999)
	state.set_value("zoom", -4)
	state.set_value("trees", 1)
	state.set_value("unknown", "anything")
	if state.values["relief_scale"] != 1.5 or state.values["zoom"] != 0.5 or state.values["trees"] or state.values.has("unknown"):
		failures.append("Sandbox controls must clamp documented ranges and reject unknown keys or nonboolean toggles.")
	state.set_value("trees", true)
	var document: Dictionary = state.snapshot()
	var restored := State.new()
	if not restored.restore(JSON.parse_string(JSON.stringify(document))) or restored.values != state.values:
		failures.append("Sandbox settings must round-trip through versioned JSON.")
	document["settings"]["trees"] = false
	if not state.values["trees"]:
		failures.append("Settings snapshots must not alias live state.")
	before = restored.snapshot()
	if restored.restore({"settings": {}}) or restored.snapshot() != before:
		failures.append("Invalid saved settings must not replace current state.")
	state.reset()
	if state.values != State.DEFAULTS:
		failures.append("Reset must restore the documented reference preset.")
	_test_texture_pack_defaults_and_round_trips(failures)
	_test_texture_pack_validation(failures)
	_test_legacy_texture_pack_migration(failures)
	return failures

static func _test_texture_pack_defaults_and_round_trips(failures: Array[String]) -> void:
	var state := State.new()
	if state.values["texture_pack"] != "modern" or state.values["comparison"] != 1:
		failures.append("New sessions must compare the modern pack against the original reference.")
	for pack: String in State.TEXTURE_PACKS:
		state.set_value("texture_pack", pack)
		var document: Dictionary = state.snapshot()
		var restored := State.new()
		if document["format"] != State.FORMAT or not restored.restore(JSON.parse_string(JSON.stringify(document))) or restored.values["texture_pack"] != pack:
			failures.append("Both texture packs must round-trip without changing the v1 format: %s." % pack)
		document["settings"]["texture_pack"] = "classic" if pack == "modern" else "modern"
		if state.values["texture_pack"] != pack or restored.values["texture_pack"] != pack:
			failures.append("Texture-pack snapshots must not alias live or restored settings.")
	state.set_value("texture_pack", "classic")
	state.set_value("comparison", 2)
	state.reset()
	if state.values["texture_pack"] != "modern" or state.values["comparison"] != 1:
		failures.append("Reset must select modern textures and the source-reference comparison.")

static func _test_texture_pack_validation(failures: Array[String]) -> void:
	var state := State.new()
	state.set_value("texture_pack", "classic")
	state.set_value("trees", true)
	var before: Dictionary = state.snapshot()
	for invalid: Variant in ["", "Modern", "unknown", null, true, false, 0, 1, 1.0, [], {}]:
		state.set_value("texture_pack", invalid)
		if state.snapshot() != before:
			failures.append("Invalid texture-pack control values must preserve the current preset.")
		var document: Dictionary = {"format": State.FORMAT, "settings": {"texture_pack": invalid, "trees": false}}
		if state.restore(document) or state.snapshot() != before:
			failures.append("Invalid saved texture packs must reject the entire restore without partial changes.")

static func _test_legacy_texture_pack_migration(failures: Array[String]) -> void:
	var legacy: Dictionary = {"format": State.FORMAT, "settings": {"comparison": 2, "patch": 1, "trees": true, "relief_scale": 0.75}}
	var state := State.new()
	if not state.restore(JSON.parse_string(JSON.stringify(legacy))) or state.values["texture_pack"] != "classic":
		failures.append("Legacy v1 presets without a texture pack must retain the original atlas.")
	if state.values["comparison"] != 2 or state.values["patch"] != 1 or not state.values["trees"] or state.values["relief_scale"] != 0.75:
		failures.append("Texture-pack migration must preserve other legacy settings.")
	if legacy["settings"].has("texture_pack"):
		failures.append("Legacy migration must not mutate the input preset.")
	var restored := State.new()
	if not restored.restore(JSON.parse_string(JSON.stringify(state.snapshot()))) or restored.values != state.values:
		failures.append("Migrated classic presets must remain classic after saving and loading again.")
	if not state.restore({"format": State.FORMAT, "settings": {}}) or state.values["texture_pack"] != "classic":
		failures.append("An empty valid legacy preset must also migrate to the classic pack.")
