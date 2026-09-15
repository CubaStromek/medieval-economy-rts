extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
const QaAssets = preload("res://tests/sawmill_qa_assets.gd")
var main: Node2D
var viewport: SubViewport
var world: World
var buildings: Array[Dictionary] = []
var out := "res://../docs/art/qa/sawmill-v2/dynamic-native"
var records: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			out = arg.trim_prefix("--output=")
	root.title = "Pila v2 a chata · plné sklady · stejný nativní záběr"
	root.size = Vector2i(1400,720)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1400,720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(1400,720)
	root.add_child(preview)
	world = World.new(Vector2i(28,24))
	world.tick = 1750
	for entry: Dictionary in [{"type":"lumber_hut","cell":Vector2i(8,10)},{"type":"sawmill","cell":Vector2i(14,10)}]:
		var id: int = world.place_building(entry["type"],entry["cell"])
		assert(id != 0)
		buildings.append(world.buildings[id])
		world.grid.add_road(world.buildings[id]["entrance"])
	buildings[0]["outputs"]["log"] = 6
	buildings[1]["inputs"]["log"] = 4
	buildings[1]["outputs"]["plank"] = 6
	main = MainScene.instantiate()
	main.world = world
	main.sawmill_sprites = QaAssets.Sprites.new(QaAssets.manifest_path())
	main.honor_launch_arguments = false
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.set_process_input(false)
	main.set_process_unhandled_input(false)
	main.hud.visible = false
	main._camera_auto_fit = false
	main.camera.position_smoothing_enabled = false
	main.selected_cell = Vector2i(-1,-1)
	await process_frame
	var bounds := Rect2()
	for b: Dictionary in buildings:
		var p: Dictionary = main.building_sprite_presentation(b)
		assert(not p.is_empty())
		var r: Rect2 = p["rect"]
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
	main.camera.position = bounds.get_center()+Vector2(0,8)
	var operation: Dictionary = main.building_operation_art_presentation(buildings[1])
	assert(not operation.is_empty())
	var paths: Array[String] = []
	for layer: Dictionary in operation["layers"]:
		paths.append(String(layer["path"]))
	assert(paths.size() >= 2)
	var before: Dictionary = QaAssets.asset_hashes()
	for zoom_value: float in [1.0,2.4]:
		main.camera.zoom = Vector2.ONE*zoom_value
		main.camera.force_update_scroll()
		main.queue_redraw()
		for i: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var name: String = "full-pair-zoom-"+str(zoom_value).replace(".","_")+".png"
		var img: Image = viewport.get_texture().get_image()
		assert(img.save_png(out.path_join(name)) == OK)
		records.append({"file":name,"sha256":FileAccess.get_sha256(out.path_join(name)),"zoom":zoom_value,
			"tick":world.tick,"hut_logs":6,"sawmill_logs":4,"sawmill_planks":6,"sawmill_loaded_layer_paths":paths})
	assert(before == QaAssets.asset_hashes())
	var f := FileAccess.open(out.path_join("full-pair-manifest.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"date":"2026-09-12","scene":"res://scenes/main.tscn",
		"fixture":"Same-frame flat noon comparison, fully stocked buildings, no residents; staged inventories, not gameplay",
		"engine":Engine.get_version_info()["string"],"renderer":RenderingServer.get_video_adapter_name(),
		"production_manifest_path":QaAssets.manifest_path(),"asset_hashes_before_after":before,
		"captures":records},"\t")+"\n")
	f.close()
	print("SAWMILL V2 FULL PAIR: 2 native captures, hashes unchanged")
	quit(0)
