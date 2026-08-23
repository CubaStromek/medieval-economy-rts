class_name SaveSystem
extends RefCounted

const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")

const DEFAULT_PATH := "user://medieval_economy_rts_save.json"


static func save_world(world: SimulationWorldClass, path: String = DEFAULT_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(world.to_data(), "  "))
	return true


static func load_world(world: SimulationWorldClass, path: String = DEFAULT_PATH) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	return world.from_data(parsed as Dictionary)
