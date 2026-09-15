extends Node

# Native Main rendering for authored state fixtures. No GameSession/music,
# player preferences or saves are opened. This is visual QA, not new gameplay.
const MainScene = preload("res://scenes/main.tscn")
const World = preload("res://scripts/simulation/simulation_world.gd")
const QaAssets = preload("res://tests/sawmill_qa_assets.gd")
const PANEL := Vector2i(640, 460)
const ANCHOR := Vector2i(10, 10)
var _main: Node2D
var _viewport: SubViewport
var _world: World
var _building: Dictionary
var _worker: Dictionary
var _output: String
var _records: Array[Dictionary] = []
var _preview: TextureRect
var _loaded_house_rgba_sha256: String

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Sawmill visual QA needs native rendering")
		get_tree().quit(1)
		return
	_output = QaAssets.output_path(false, "visual")
	var sheets_only: bool = OS.get_cmdline_user_args().has("--sheets-only")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	if not _output.is_absolute_path():
		get_tree().quit(1)
		return
	if sheets_only:
		await _rebuild_sheets()
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_output.path_join("frames"))
	DirAccess.make_dir_recursive_absolute(_output.path_join("motion"))
	get_tree().root.title = "Pila · život budovy · nativní QA bez hudby"
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(960, 690)
	_viewport = SubViewport.new()
	_viewport.size = PANEL
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_preview = TextureRect.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture = _viewport.get_texture()
	add_child(_preview)
	await _fixture()
	var states: Array[Dictionary] = [
		{"id":"day-away", "label":"Den · tesař mimo dům"},
		{"id":"day-rest", "label":"Den · odpočinek doma"},
		{"id":"day-work", "label":"Den · skutečná práce"},
		{"id":"day-paused", "label":"Den · osobní pauza doma"},
	]
	var state_textures: Array[Texture2D] = []
	var state_labels: Array[String] = []
	for state: Dictionary in states:
		_apply_state(String(state["id"]))
		_frame(2.4)
		var captured: Image = await _capture("frames/" + String(state["id"]), {"kind":"household-state", "state":state["id"], "zoom":2.4})
		state_textures.append(ImageTexture.create_from_image(captured))
		state_labels.append(String(state["label"]))
	await _sheet("states", "Pila · život podle skutečného obyvatele", state_textures, state_labels, 3)
	var context_textures: Array[Texture2D] = []
	var context_labels: Array[String] = []
	for zoom_value: float in [0.75, 1.0, 2.4]:
		await _fixture()
		_apply_state("day-rest")
		_frame(zoom_value)
		var id: String = "zoom-" + str(zoom_value).replace(".", "_")
		context_textures.append(ImageTexture.create_from_image(await _capture("frames/" + id, {"kind":"zoom", "zoom":zoom_value})))
		context_labels.append("Herní měřítko %.2f×" % zoom_value)
	await _fixture(true)
	_apply_state("day-rest")
	_main.selected_cell = ANCHOR
	_frame(2.4)
	context_textures.append(ImageTexture.create_from_image(await _capture("frames/raised-footprint", {"kind":"raised-platform", "zoom":2.4, "height":6, "selected":true})))
	context_labels.append("Vyvýšená rovina · skutečných 4×2 polí")
	await _fixture(false, true)
	_apply_state("day-rest")
	_frame(2.4)
	context_textures.append(ImageTexture.create_from_image(await _capture("frames/front-tree", {"kind":"front-tree", "zoom":2.4})))
	context_labels.append("Přední strom · stejné řazení objektů")
	await _sheet("context", "Pila · měřítko, zemní kontakt a zakrytí", context_textures, context_labels, 3)
	await _fixture()
	_apply_state("day-rest")
	_frame(4.0)
	var base: Dictionary = _main.building_life_presentation(_building)
	var rest_rect: Rect2 = _main.production_building_life.rest_rect(base)
	var rest_available: bool = rest_rect.has_area()
	if rest_available:
		# One restrained 12-second cycle at 8 fps; only the authored resident's
		# head is animated. The test fixture never advances the economy.
		var body_rect: Rect2 = rest_rect
		_main.camera.position = body_rect.get_center() + Vector2(0,-5)
		_main.camera.zoom = Vector2.ONE * 6.0
		_main.camera.force_update_scroll()
		for frame: int in range(96):
			_world.tick = 1800 + frame * 5 / 4
			_main.accumulator = float(frame % 4) * 0.025
			var life: Dictionary = _main.building_life_presentation(_building)
			assert(_main.production_building_life.rest_rect(life) == body_rect)
			await _capture("motion/rest-%03d" % frame, {"kind":"head-cycle", "frame":frame, "fps":8, "zoom":6.0})
	var manifest := FileAccess.open(_output.path_join("capture-manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"date":"2026-09-12", "engine":Engine.get_version_info()["string"],
		"renderer":RenderingServer.get_video_adapter_name(), "scene":"res://scenes/main.tscn", "panel_size":[PANEL.x,PANEL.y],
		"fixture":"Paused exact states; normal renderer, physical footprint, terrain, fog and time-dependent household layers",
		"production_manifest_path":QaAssets.manifest_path(),
		"production_manifest_sha256":FileAccess.get_sha256(QaAssets.manifest_path()),
		"asset_hashes":QaAssets.asset_hashes(),
		"rest_asset_available":rest_available, "music_or_save_access":false, "captures":_records}, "\t")+"\n")
	manifest.close()
	print("SAWMILL VISUAL QA: %d captures, rest asset available=%s -> %s" % [_records.size(), rest_available, _output])
	get_tree().quit(0)

func _fixture(raised: bool = false, front_tree: bool = false) -> void:
	if _main != null:
		_main.free()
	_world = World.new(Vector2i(24, 24))
	_world.tick = 1750
	if raised:
		for y: int in range(_world.grid.size.y + 1):
			for x: int in range(_world.grid.size.x + 1):
				var distance: int = maxi(maxi(10 - x, x - 14), maxi(9 - y, y - 11))
				_world.grid.set_vertex_height(Vector2i(x,y), maxi(0, 6 - maxi(0,distance) * 2))
	var id: int = _world.place_building("sawmill", ANCHOR)
	assert(id != 0)
	_building = _world.buildings[id]
	var worker_id: int = _world.spawn_worker(_building["entrance"], "carpenter", id, true, id)
	assert(worker_id != 0)
	_worker = _world.workers[worker_id]
	_world.economy_enabled = true
	for x: int in range(7,17):
		_world.grid.add_road(Vector2i(x,12))
	_world.grid.add_road(_building["entrance"])
	if front_tree:
		assert(_world.add_tree(Vector2i(12,11),3) != 0)
	_main = MainScene.instantiate()
	_main.world = _world
	_main.sawmill_sprites = QaAssets.Sprites.new(QaAssets.manifest_path())
	_main.honor_launch_arguments = false
	_main.simulation_speed = 0.0
	_viewport.add_child(_main)
	_main.set_process(false)
	_main.set_process_input(false)
	_main.set_process_unhandled_input(false)
	_main.hud.visible = false
	_main._camera_auto_fit = false
	_main.camera.position_smoothing_enabled = false
	_main.selected_cell = Vector2i(-1,-1)
	assert(not _main.building_sprite_presentation(_building).is_empty())
	var house: Dictionary = _main.building_sprite_presentation(_building)
	var loaded: Image = (house["texture"] as Texture2D).get_image()
	if loaded.is_compressed():
		assert(loaded.decompress() == OK)
	loaded.convert(Image.FORMAT_RGBA8)
	loaded.clear_mipmaps()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(loaded.get_data())
	_loaded_house_rgba_sha256 = hashing.finish().hex_encode()
	assert(_loaded_house_rgba_sha256 == String(QaAssets.manifest()["finished_rgba_sha256"]))
	await get_tree().process_frame

func _apply_state(state: String) -> void:
	var inside: bool = not state.ends_with("away")
	_worker["inside_building_id"] = _building["id"] if inside else 0
	_worker["position"] = _building["entrance"] if inside else Vector2i(19,19)
	_worker["previous_position"] = _worker["position"]
	_worker["state"] = "working" if state == "day-work" else "idle"
	_worker["action"] = "operate" if state == "day-work" else ""
	_worker["source_id"] = _building["id"] if state == "day-work" else 0
	_worker["enabled"] = state != "day-paused"
	_building["process_remaining"] = 30 if state == "day-work" else 0
	_world.tick = 1750
	_main.accumulator = 0.0

func _frame(zoom_value: float) -> void:
	_main.camera.zoom = Vector2.ONE * zoom_value
	_main.camera.position = QaAssets.focus(_main.building_sprite_presentation(_building))
	_main.camera.force_update_scroll()
	_main.queue_redraw()

func _capture(name: String, metadata: Dictionary) -> Image:
	_main.queue_redraw()
	for _frame_index: int in range(2):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var result: Image = _viewport.get_texture().get_image()
	assert(result.get_size() == PANEL)
	assert(result.save_png(_output.path_join(name+".png")) == OK)
	var record: Dictionary = metadata.duplicate()
	record["file"] = name+".png"
	record["production_manifest_path"] = QaAssets.manifest_path()
	record["verified_loaded_house_rgba_sha256"] = _loaded_house_rgba_sha256
	var life: Dictionary = _main.building_life_presentation(_building)
	for key: String in ["known","at_home","active_work","door_open","window_open","rest_visible"]:
		record[key] = life.get(key)
	_records.append(record)
	return result

func _sheet(name: String, title: String, textures: Array[Texture2D], labels: Array[String], columns: int) -> void:
	var sheet := SubViewport.new()
	var card := Vector2i(480,370)
	var rows: int = ceili(float(textures.size()) / columns)
	sheet.size = Vector2i(card.x*columns, card.y*rows+64)
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var background := ColorRect.new()
	background.color = Color("#152017")
	background.size = sheet.size
	sheet.add_child(background)
	var heading := Label.new()
	heading.text = title
	heading.position = Vector2(20,12)
	heading.add_theme_font_size_override("font_size",24)
	sheet.add_child(heading)
	for index: int in range(textures.size()):
		var top := Vector2((index%columns)*card.x, (index/columns)*card.y+64)
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.texture = textures[index]
		image.position = top
		image.size = Vector2(card.x,card.y-25)
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sheet.add_child(image)
		var caption := Label.new()
		caption.text = labels[index]
		caption.position = top+Vector2(12,card.y-27)
		caption.add_theme_font_size_override("font_size",18)
		sheet.add_child(caption)
	for _settle: int in range(3):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var result: Image = sheet.get_texture().get_image()
	assert(result.save_png(_output.path_join(name+".png")) == OK)
	sheet.free()

func _rebuild_sheets() -> void:
	var groups: Array[Dictionary] = [
		{"name":"states", "title":"Pila · život podle skutečného obyvatele",
		 "files":["day-away","day-rest","day-work","day-paused"],
		 "labels":["Den · tesař mimo dům","Den · odpočinek doma","Den · skutečná práce","Den · osobní pauza doma"]},
		{"name":"context", "title":"Pila · měřítko, zemní kontakt a zakrytí",
		 "files":["zoom-0_75","zoom-1_0","zoom-2_4","raised-footprint","front-tree"],
		 "labels":["Herní měřítko 0.75×","Herní měřítko 1.00×","Herní měřítko 2.40×","Vyvýšená rovina · skutečných 4×2 polí","Přední strom · stejné řazení objektů"]},
	]
	for group: Dictionary in groups:
		var textures: Array[Texture2D] = []
		var labels: Array[String] = []
		for file: String in group["files"]:
			var pixels: Image = Image.load_from_file(_output.path_join("frames/"+file+".png"))
			assert(pixels != null and not pixels.is_empty())
			textures.append(ImageTexture.create_from_image(pixels))
		for label: String in group["labels"]:
			labels.append(label)
		await _sheet(group["name"],group["title"],textures,labels,3)
