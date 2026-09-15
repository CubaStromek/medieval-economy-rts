extends SceneTree

# Isolated actual Main renderer; no GameSession, music, settings or saves.
const MainScene = preload("res://scenes/main.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
const SIZE := Vector2i(960, 760)
var main: Node2D
var viewport: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.title = "Pila · kontrola dveří a okna · bez hudby"
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = viewport.get_texture()
	root.add_child(preview)
	var world := World.new(Vector2i(24, 24))
	world.tick = 1750
	var id: int = world.place_building("sawmill", Vector2i(10, 10))
	var building: Dictionary = world.buildings[id]
	var worker_id: int = world.spawn_worker(building["entrance"], "carpenter", id, true, id)
	var worker: Dictionary = world.workers[worker_id]
	world.economy_enabled = true
	main = MainScene.instantiate()
	main.world = world
	main.honor_launch_arguments = false
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.set_process_input(false)
	main.set_process_unhandled_input(false)
	main.hud.visible = false
	main._camera_auto_fit = false
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2.ONE * 4.0
	var shape: Dictionary = main.building_geometry(building)
	main.camera.position = (shape["door"] as Vector2) + Vector2(24, -50)
	main.camera.force_update_scroll()
	var house: Dictionary = main.building_sprite_presentation(building)
	if house.is_empty() or (house.get("life", {}) as Dictionary).is_empty():
		printerr("Production sawmill art/household metadata unavailable")
		quit(1)
		return
	var output: String = ProjectSettings.globalize_path("res://../docs/art/qa/sawmill-v1/life-native").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	await _capture(output.path_join("day-rest.png"))
	worker["state"] = "working"
	worker["action"] = "operate"
	worker["source_id"] = id
	building["process_remaining"] = 30
	await _capture(output.path_join("day-working.png"))
	worker["inside_building_id"] = 0
	worker["position"] = Vector2i(18, 18)
	worker["previous_position"] = Vector2i(18, 18)
	await _capture(output.path_join("day-empty.png"))
	worker["inside_building_id"] = id
	worker["position"] = building["entrance"]
	worker["previous_position"] = building["entrance"]
	worker["state"] = "sleeping"
	worker["action"] = ""
	worker["sleep_home_id"] = id
	world.tick = 4200
	await _capture(output.path_join("night-home.png"))
	var data := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	data.store_string(JSON.stringify({"date":"2026-09-12", "engine":Engine.get_version_info()["string"],
		"scene":"res://scenes/main.tscn", "purpose":"Native aperture coverage and household-state fixtures",
		"scale":4.0, "image_size":[SIZE.x,SIZE.y], "house_manifest_sha256":FileAccess.get_sha256("res://art/buildings/sawmill/v1/manifest.json"),
		"files":["day-rest.png","day-working.png","day-empty.png","night-home.png"], "music_or_save_access":false}, "\t")+"\n")
	data.close()
	print("SAWMILL LIFE NATIVE: 4 actual Main captures -> " + output)
	quit(0)

func _capture(path: String) -> void:
	main.queue_redraw()
	for _frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var result: Image = viewport.get_texture().get_image()
	assert(result.get_size() == SIZE and result.save_png(path) == OK)
