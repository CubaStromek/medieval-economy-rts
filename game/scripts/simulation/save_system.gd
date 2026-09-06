class_name SaveSystem
extends RefCounted

const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")

const DEFAULT_PATH := "user://medieval_economy_rts_save.json"


static func save_world(world: SimulationWorldClass, path: String = DEFAULT_PATH, map_id: String = "") -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var data: Dictionary = world.to_data()
	# Optional menu metadata; old snapshots and simulation-only callers remain valid.
	if map_id in ["test", "relief", "economy", "mountainous-region"]:
		data["scenario_id"] = map_id
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	return file.get_error() == OK


static func load_world(world: SimulationWorldClass, path: String = DEFAULT_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return false
	return world.from_data(parsed as Dictionary)


static func saved_map_id(path: String = DEFAULT_PATH) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "test"
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return "test"
	var parsed: Variant = json.data
	if parsed is Dictionary:
		var map_id: Variant = parsed.get("scenario_id", "test")
		if map_id is String and map_id in ["test", "relief", "economy", "mountainous-region"]:
			return map_id
	# Older saves never recorded their starting scenario; retain their former reset.
	return "test"
