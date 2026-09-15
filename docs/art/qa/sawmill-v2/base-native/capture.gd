extends SceneTree

# Isolated actual Main fixture; v2 is injected only here, never into runtime defaults.
const MainScene = preload("res://scenes/main.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
const SawmillLibrary = preload("res://scripts/view/sawmill_sprite_library.gd")
const V2 := "res://art/buildings/sawmill/v2/manifest.json"
const ANCHOR := Vector2i(14, 10)
const SIZE := Vector2i(1400, 720)
var main: Node2D
var viewport: SubViewport
var world: World
var hut: Dictionary
var sawmill: Dictionary
var worker: Dictionary
var out := "res://../docs/art/qa/sawmill-v2/base-native"
var records: Array[Dictionary] = []
var before_hashes := {}
var loaded_pixel_hash := ""

class GroundGuide extends Node2D:
	var view: Node2D
	var building: Dictionary
	func _draw() -> void:
		var shape: Dictionary = view.building_geometry(building)
		for cell: Vector2i in shape["cells"]:
			var poly: PackedVector2Array = view.terrain_renderer.cell_polygon(cell)
			poly.append(poly[0])
			draw_polyline(poly, Color(0.3, 0.85, 1.0, 0.85), 0.8)
		var approach: PackedVector2Array = view.terrain_renderer.cell_polygon(building["entrance"])
		approach.append(approach[0])
		draw_polyline(approach, Color(1.0, 0.7, 0.2), 1.0)
		var door: Vector2 = shape["door"]
		draw_line(door + Vector2(-3,0), door + Vector2(3,0), Color.WHITE, 0.8)
		draw_line(door + Vector2(0,-3), door + Vector2(0,3), Color.WHITE, 0.8)

func _initialize() -> void:
	_run.call_deferred()

func hashes() -> Dictionary:
	var result := {}
	for path: String in [V2, "res://art/buildings/sawmill/v2/finished.png",
		"res://art/buildings/lumber_hut/v1/manifest.json", "res://art/buildings/lumber_hut/v1/finished.png",
		"res://art/units/civilians-basic-v1.png"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Native WindowServer renderer required")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			out = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	before_hashes = hashes()
	root.title = "Pila v2 · první nativní geometrie a porovnání · bez hudby"
	root.size = SIZE
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.size = Vector2(SIZE)
	root.add_child(preview)
	await fixture(false)
	for zoom_value: float in [0.75, 1.0, 2.4]:
		frame_pair(zoom_value)
		await capture("flat-pair-zoom-" + str(zoom_value).replace(".", "_"), zoom_value, false, false)
	frame_sawmill(3.5)
	await capture("flat-door-human", 3.5, false, false)
	await fixture(true)
	frame_sawmill(2.4)
	await capture("raised-footprint", 2.4, true, false)
	var guide := GroundGuide.new()
	guide.view = main
	guide.building = sawmill
	guide.z_index = 500
	main.add_child(guide)
	await capture("raised-footprint-guide", 2.4, true, true)
	guide.free()
	frame_sawmill(3.5)
	await capture("raised-door-human", 3.5, true, false)
	var after: Dictionary = hashes()
	assert(before_hashes == after)
	var f := FileAccess.open(out.path_join("capture-manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"date":"2026-09-12", "engine":Engine.get_version_info()["string"],
		"renderer":RenderingServer.get_video_adapter_name(), "scene":"res://scenes/main.tscn",
		"fixture":"Staged empty buildings and actual outdoor carpenter; frozen noon tick1750. V2 library injected only in this QA instance. No life or operation layers.",
		"normal_gameplay_proof":false, "player_save_or_music_access":false,
		"runtime_default_changed":false, "hashes_before":before_hashes, "hashes_after":after,
		"captures":records}, "\t") + "\n")
	f.close()
	print("SAWMILL V2 BASE NATIVE: %d captures, actual carpenter33world, source hashes unchanged" % records.size())
	quit(0)

func fixture(raised: bool) -> void:
	if main != null:
		main.free()
	world = World.new(Vector2i(28,24))
	world.tick = 1750
	if raised:
		for y: int in range(world.grid.size.y + 1):
			for x: int in range(world.grid.size.x + 1):
				var distance: int = maxi(maxi(14-x, x-18), maxi(9-y, y-11))
				world.grid.set_vertex_height(Vector2i(x,y), maxi(0, 6-maxi(0,distance)*2))
	var hut_id: int = world.place_building("lumber_hut", Vector2i(5,10) if raised else Vector2i(8,10))
	var saw_id: int = world.place_building("sawmill", ANCHOR)
	assert(hut_id != 0 and saw_id != 0)
	hut = world.buildings[hut_id]
	sawmill = world.buildings[saw_id]
	assert(world.building_cells(sawmill).size() == 8)
	world.grid.add_road(sawmill["entrance"])
	world.grid.add_road(hut["entrance"])
	for x: int in range(6,21):
		world.grid.add_road(Vector2i(x,13))
	var worker_id: int = world.spawn_worker(sawmill["entrance"], "carpenter", 0, false)
	assert(worker_id != 0)
	worker = world.workers[worker_id]
	main = MainScene.instantiate()
	main.world = world
	main.sawmill_sprites = SawmillLibrary.new(V2)
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
	var p: Dictionary = main.building_sprite_presentation(sawmill)
	assert(not p.is_empty())
	# The loader deliberately creates a fresh mipmapped ImageTexture, whose
	# resource_path is empty. Verify its actual decoded base pixels instead.
	var pixels: Image = (p["texture"] as Texture2D).get_image()
	if pixels.is_compressed():
		assert(pixels.decompress() == OK)
	pixels.convert(Image.FORMAT_RGBA8)
	pixels.clear_mipmaps()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(pixels.get_data())
	loaded_pixel_hash = hashing.finish().hex_encode()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(V2))
	assert(loaded_pixel_hash == String(data["finished_rgba_sha256"]))
	assert((p["life"] as Dictionary).is_empty() and (p["operation"] as Dictionary).is_empty())
	var foot: Vector2 = main.terrain_renderer.cell_center(worker["position"])
	var wp: Dictionary = main.worker_presentation(worker, foot)
	assert(wp["texture"] != null and is_equal_approx((wp["rect"] as Rect2).size.y,33.0))

func frame_pair(zoom_value: float) -> void:
	var bounds := Rect2()
	for b: Dictionary in [hut,sawmill]:
		var p: Dictionary = main.building_sprite_presentation(b)
		assert(not p.is_empty())
		var r: Rect2 = p["rect"]
		bounds = r if bounds.size == Vector2.ZERO else bounds.merge(r)
	main.camera.position = bounds.get_center() + Vector2(0,8)
	main.camera.zoom = Vector2.ONE * zoom_value
	main.camera.force_update_scroll()

func frame_sawmill(zoom_value: float) -> void:
	var door: Vector2 = main.building_geometry(sawmill)["door"]
	main.camera.position = door + Vector2(23,-40)
	main.camera.zoom = Vector2.ONE * zoom_value
	main.camera.force_update_scroll()

func capture(name: String, zoom_value: float, raised: bool, annotated: bool) -> void:
	main.queue_redraw()
	for i: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	assert(img.get_size() == SIZE and img.save_png(out.path_join(name+".png")) == OK)
	var shape: Dictionary = main.building_geometry(sawmill)
	var p: Dictionary = main.building_sprite_presentation(sawmill)
	var door: Vector2 = shape["door"]
	var foot: Vector2 = main.terrain_renderer.cell_center(worker["position"])
	var wp: Dictionary = main.worker_presentation(worker, foot)
	records.append({"file":name+".png", "sha256":FileAccess.get_sha256(out.path_join(name+".png")),
		"zoom":zoom_value, "tick":world.tick, "terrain_peak_height":6 if raised else 0,
		"guide_overlay":annotated, "size":[img.get_width(),img.get_height()],
		"sawmill_cell":[ANCHOR.x,ANCHOR.y], "occupied_cells":shape["cells"].size(),
		"entrance":[sawmill["entrance"].x,sawmill["entrance"].y],
		"door_world":[door.x,door.y], "worker_foot_world":[foot.x,foot.y],
		"worker_body_height_world":(wp["rect"] as Rect2).size.y,
		"loaded_image":"res://art/buildings/sawmill/v2/finished.png", "verified_loaded_rgba_sha256":loaded_pixel_hash,
		"life_layers":0, "operation_layers":0})
