extends SceneTree

# Native Main terrain and actual carpenter reference. Run from project root:
# godot --path game --windowed --script ../docs/art/qa/sawmill-v1/generate-ground-guide.gd
# No GameSession, music, player settings or saved game is instantiated.
const MainScene = preload("res://scenes/main.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
const ANCHOR := Vector2i(10, 10)
const SIZE := Vector2i(1024, 1024)
const CAMERA_CENTER := Vector2(480, 368)
const ZOOM: float = 4.0
const OUT: String = "res://../docs/art/qa/sawmill-v1"

class GuideOverlay extends Node2D:
	func _draw() -> void:
		var yellow := Color("ffe598")
		var cyan := Color("7fe9f5")
		draw_rect(Rect2(192, 480, 640, 320), Color(0.9, 0.67, 0.15, 0.10))
		for x: int in range(192, 833, 160):
			draw_line(Vector2(x, 480), Vector2(x, 800), yellow, 2)
		for y: int in range(480, 801, 160):
			draw_line(Vector2(192, y), Vector2(832, y), yellow, 2)
		draw_rect(Rect2(192, 480, 640, 320), yellow, false, 4)
		draw_rect(Rect2(352, 800, 160, 160), Color(0.1, 0.6, 0.8, 0.14))
		draw_rect(Rect2(352, 800, 160, 160), cyan, false, 3)
		draw_line(Vector2(396, 800), Vector2(468, 800), cyan, 8)
		draw_line(Vector2(432, 860), Vector2(432, 819), cyan, 3)
		draw_line(Vector2(420, 831), Vector2(432, 819), cyan, 3)
		draw_line(Vector2(444, 831), Vector2(432, 819), cyan, 3)
		draw_string(ThemeDB.fallback_font, Vector2(192, 442), "PILA / SAWMILL  ·  4 x 2 cells", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, yellow)
		draw_string(ThemeDB.fallback_font, Vector2(192, 471), "Ground contacts inside yellow rectangle. Front faces DOWN.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, yellow)
		draw_string(ThemeDB.fallback_font, Vector2(356, 939), "CLEAR ENTRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, cyan)
		draw_string(ThemeDB.fallback_font, Vector2(352, 993), "Door threshold (432, 800)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cyan)
		draw_string(ThemeDB.fallback_font, Vector2(846, 920), "Carpenter", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(846, 945), "33 world px", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(192, 80), "TECHNICAL GROUND GUIDE  ·  actual game terrain  ·  4x", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff0cc"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		quit(1)
		return
	root.title = "Pila · půdorysný podklad · bez hudby"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(800, 800)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.texture = viewport.get_texture()
	root.add_child(display)
	var world := World.new(Vector2i(24, 24))
	world.economy_enabled = true
	world.tick = 1750
	var cells: Array[Vector2i] = world.placement_cells("sawmill", ANCHOR)
	var entrance: Vector2i = world.placement_entrance("sawmill", ANCHOR)
	assert(cells.size() == 8 and entrance == Vector2i(11, 11))
	var worker_id: int = world.spawn_worker(Vector2i(14, 11), "carpenter")
	assert(worker_id != 0)
	var main: Node2D = MainScene.instantiate()
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
	main.camera.zoom = Vector2.ONE * ZOOM
	main.camera.position = CAMERA_CENTER
	main.camera.force_update_scroll()
	main.selected_cell = Vector2i(-1, -1)
	main.queue_redraw()
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	viewport.add_child(canvas)
	var overlay := GuideOverlay.new()
	canvas.add_child(overlay)
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var transform: Transform2D = main.get_global_transform_with_canvas()
	var ground_origin: Vector2 = transform * Vector2(400, 360)
	var threshold: Vector2 = transform * Vector2(460, 440)
	assert(ground_origin.distance_to(Vector2(192, 480)) < 0.01)
	assert(threshold.distance_to(Vector2(432, 800)) < 0.01)
	var output_dir: String = ProjectSettings.globalize_path(OUT).simplify_path()
	var result: Image = viewport.get_texture().get_image()
	assert(result.get_size() == SIZE)
	assert(result.save_png(output_dir.path_join("guide.png")) == OK)
	var human_size: Vector2 = main.unit_sprites.sprite_size("carpenter")
	var records: Dictionary = {
		"date": "2026-09-12", "purpose": "Native ground generation guide, not building artwork or production QA",
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_video_adapter_name(),
		"scene": "res://scenes/main.tscn", "no_gameplay_changes": true, "music_or_save_access": false,
		"building_id": "sawmill", "catalog_sha256": FileAccess.get_sha256("res://data/buildings.json"),
		"footprint_version": world.placement_footprint_version("sawmill"), "footprint": [4, 2], "mask": ["####", "#E##"],
		"anchor_cell": [10, 10], "door_cell": [11, 10], "entrance_cell": [11, 11], "occupied_count": cells.size(),
		"ground_origin_world": [400, 360], "ground_bounds_world": [400, 360, 560, 440],
		"door_threshold_world": [460, 440], "entrance_bounds_world": [440, 440, 480, 480],
		"canvas": [1024, 1024], "camera_center_world": [480, 368], "zoom": 4.0,
		"source_to_world": 0.25, "cell_source_px": 160, "ground_bounds_source": [192, 480, 832, 800],
		"door_threshold_source": [432, 800], "approach_bounds_source": [352, 800, 512, 960],
		"human": {"role": "carpenter", "cell": [14, 11], "feet_source": [912, 880], "actual_sprite_size_world": [human_size.x, human_size.y], "nominal_human_height_world": 33},
		"ground_height": 0, "tick": 1750, "screenshot_sha256": FileAccess.get_sha256(output_dir.path_join("guide.png")),
		"checks": {"real_placement_cells": true, "real_entrance": true, "camera_transform_ground_origin": true, "camera_transform_threshold": true, "image_dimensions": true}
	}
	var metadata := FileAccess.open(output_dir.path_join("geometry.json"), FileAccess.WRITE)
	assert(metadata != null)
	metadata.store_string(JSON.stringify(records, "\t") + "\n")
	metadata.close()
	print("SAWMILL GROUND GUIDE: " + output_dir + "/guide.png; checked 8 cells, threshold (432,800), actual carpenter %.2f px" % human_size.y)
	quit(0)
