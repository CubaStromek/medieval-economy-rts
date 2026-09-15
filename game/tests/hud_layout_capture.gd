extends Node

## Temporary UI review harness: boots the real session, opens actual HUD states
## and captures them at several window sizes. It changes only window size,
## selection, build mode and panel visibility - no simulation fabrication.
const SessionScene = preload("res://scenes/game_session.tscn")
const UiScaleClass = preload("res://scripts/view/ui_scale.gd")

var session: Variant
var game: Variant
var output_path: String = "res://../.ui-review"
var sizes: Array[Vector2i] = [Vector2i(1152, 720), Vector2i(1920, 1080), Vector2i(1280, 800)]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	session = SessionScene.instantiate()
	session.honor_launch_arguments = false
	var slot: String = OS.get_temp_dir().path_join("hud_review_%d" % OS.get_process_id())
	session.save_path = slot + ".json"
	session.region_save_path = slot + "_region.json"
	add_child(session)
	await _settle()
	await _capture("00-main-menu")
	session._start_new_game("economy")
	game = session.game
	await _settle()
	await _settle()
	game.simulation_speed = 0.0
	for size: Vector2i in sizes:
		var tag: String = "%dx%d" % [size.x, size.y]
		get_tree().root.size = size
		# Mirror the real window path, which the session only runs when it is the
		# root scene; without this the capture would show the unscaled HUD.
		UiScaleClass.apply(get_tree().root)
		await _settle()
		await _settle()
		await _capture("10-idle-%s" % tag)
		game.hud._stock_toggle.button_pressed = true
		await _settle()
		await _capture("11-stocks-%s" % tag)
		game.hud._show_resource_category(2)
		await _settle()
		await _settle()
		await _capture("11b-stocks-equipment-%s" % tag)
		game.hud._show_resource_category(0)
		game.hud._stock_toggle.button_pressed = false
		game.hud._help_button.button_pressed = true
		await _capture("12-help-%s" % tag)
		game.hud._help_button.button_pressed = false
		game.build_mode = "lumber_hut"
		game.hud.show_build_tool("lumber_hut")
		await _settle()
		await _capture("13-placing-%s" % tag)
		game.build_mode = ""
		game.hud.show_build_tool("")
		game.hud._show_dock(false)
		# Select an actual finished building from the demo settlement.
		var picked: int = 0
		for building_id: int in game.world.buildings:
			var building: Dictionary = game.world.buildings[building_id]
			if String(building.get("type", "")) == "bakery":
				picked = building_id
				break
		if picked == 0:
			for building_id: int in game.world.buildings:
				picked = building_id
				break
		if picked != 0:
			game.selected_cell = game.world.building_cells(game.world.buildings[picked])[0]
			game.selected_unit_id = 0
			await _settle()
			game.hud._show_dock(true)
			await _capture("14-building-%s" % tag)
		var unit_id: int = 0
		for worker_id: int in game.world.workers:
			unit_id = worker_id
			break
		if unit_id != 0:
			game.selected_unit_id = unit_id
			game.selected_cell = Vector2i(-1, -1)
			await _settle()
			game.hud._show_dock(true)
			await _capture("15-unit-%s" % tag)
		game.selected_unit_id = 0
		game.selected_cell = Vector2i(-1, -1)
		game.hud._show_dock(false)
	print("HUD_CAPTURE_DONE")
	get_tree().quit()


func _capture(label: String) -> void:
	await _settle()
	if game != null:
		game.queue_redraw()
		game.hud.refresh(game.world, game.selected_cell, game.build_mode, game.simulation_speed,
			0.1, game.selected_unit_id)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("CAPTURE_FAILED ", label)
		return
	var path: String = ProjectSettings.globalize_path(output_path).path_join(label + ".png")
	image.save_png(path)
	print("CAPTURED ", label, " ", image.get_width(), "x", image.get_height())


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
