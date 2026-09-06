extends RefCounted

const State = preload("res://scripts/view/terrain_sandbox_state.gd")
const TEST_COUNT: int = 4

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
	return failures
