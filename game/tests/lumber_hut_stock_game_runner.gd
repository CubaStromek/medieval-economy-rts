extends "res://tests/lumberjack_game_integration_runner.gd"

# Reuses the real menu/Relief/harvest journey. No fabricated worker actions or
# inventory assignments: stock must follow the actual physical hut delivery.

func _read_arguments() -> void:
	super._read_arguments()
	var explicit_output: bool = false
	for argument: String in OS.get_cmdline_user_args():
		explicit_output = explicit_output or argument.begins_with("--capture=")
	if not explicit_output:
		output_path = ProjectSettings.globalize_path("res://../docs/art/qa/lumber-hut-stock-v1/natural")


func _snapshot() -> Dictionary:
	var result: Dictionary = super._snapshot()
	if result.is_empty():
		return result
	var stock: Dictionary = game.building_stock_presentation(game.world.buildings[home_id])
	result["hut_stock"] = {"known": stock.get("known", false), "amount": stock.get("amount", -1),
		"capacity": stock.get("capacity", -1), "has_texture": stock.get("texture") != null}
	return result


func _record_phase(phase: String) -> void:
	var building: Dictionary = game.world.buildings[home_id]
	var stock: Dictionary = game.building_stock_presentation(building)
	_expect(bool(stock.get("known", false)), "The player's completed hut must expose its physical stock presentation.")
	_expect(int(stock.get("amount", -1)) == int(building["outputs"].get("log", 0)),
		"Drawn stock must equal physical outputs at " + phase + ".")
	if phase == "delivered":
		_expect(int(stock.get("amount", -1)) == home_output_before + 1 and stock.get("texture") != null,
			"Real delivery must make the newly stored painted log available in the production renderer.")
		game.selected_cell = building["position"] as Vector2i
		game.selected_unit_id = 0
		game._update_ui()
	else:
		_expect(int(stock.get("amount", -1)) == home_output_before,
			"A log still on its tree or in the worker's hands must not appear in the hut rack.")
	await super._record_phase(phase)


func _finish() -> void:
	for path: String in [get_script().resource_path, "res://scripts/view/lumber_hut_stock_library.gd"]:
		code_sha256[path] = FileAccess.get_sha256(path)
	super._finish()
