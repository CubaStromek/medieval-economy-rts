extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
var main: Node2D
var viewport: SubViewport
var world: World
var buildings: Array[Dictionary] = []
var out := "res://../docs/art/qa/sawmill-lumber-hut-comparison-2026-09-12"
var records: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.title = "Porovnání pily a dřevorubecké chaty"
	root.size = Vector2i(1400, 720)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1400, 720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(1400, 720)
	root.add_child(preview)
	world = World.new(Vector2i(28, 24))
	world.tick = 1750
	for entry: Dictionary in [{"type":"lumber_hut", "cell":Vector2i(8,10)}, {"type":"sawmill", "cell":Vector2i(14,10)}]:
		var id: int = world.place_building(entry["type"], entry["cell"])
		assert(id != 0)
		buildings.append(world.buildings[id])
		world.grid.add_road(world.buildings[id]["entrance"])
	for x: int in range(6, 21):
		world.grid.add_road(Vector2i(x,13))
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
	main.selected_cell = Vector2i(-1,-1)
	await process_frame
	var bounds := Rect2()
	for b: Dictionary in buildings:
		var p: Dictionary = main.building_sprite_presentation(b)
		assert(not p.is_empty())
		var r: Rect2 = p["rect"]
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
	main.camera.position = bounds.get_center() + Vector2(0,8)
	for zoom_value: float in [1.0, 2.4]:
		main.camera.zoom = Vector2.ONE * zoom_value
		main.camera.force_update_scroll()
		await capture("empty-zoom-" + str(zoom_value).replace(".","_"), zoom_value, false)
	buildings[0]["outputs"]["log"] = 6
	buildings[1]["inputs"]["log"] = 4
	buildings[1]["outputs"]["plank"] = 6
	await capture("full-zoom-2_4", 2.4, true)
	var hashes := {}
	for path: String in ["res://art/buildings/lumber_hut/v1/finished.png", "res://art/buildings/lumber_hut/v1/manifest.json", "res://art/buildings/sawmill/v1/finished.png", "res://art/buildings/sawmill/v1/manifest.json", "res://art/buildings/sawmill/v1/operation/manifest.json"]:
		hashes[path] = FileAccess.get_sha256(path)
	var f := FileAccess.open(out.path_join("capture-manifest.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"date":"2026-09-12", "engine":Engine.get_version_info()["string"], "renderer":RenderingServer.get_video_adapter_name(), "scene":"res://scenes/main.tscn", "fixture":"Two current buildings, same flat terrain, tick1750, zoom, no residents; full stock is deliberately staged for comparison", "runtime_or_assets_modified":false, "captures":records, "hashes":hashes},"\t")+"\n")
	print("COMPARISON: 3 native captures")
	quit(0)

func capture(name: String, zoom_value: float, full: bool) -> void:
	main.queue_redraw()
	for i: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	assert(img.save_png(out.path_join(name+".png")) == OK)
	records.append({"file":name+".png", "zoom":zoom_value,"tick":world.tick,"full_stock":full, "size":[img.get_width(),img.get_height()]})
