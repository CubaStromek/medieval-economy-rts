extends "res://tools/preview_sawmill_life.gd"

## Isolated native QA of the real Main sawmill renderer. Reuses terrain,
## camera and sheet helpers; never creates GameSession, music or player saves.
## State fixtures verify visuals; a separate final sequence advances the real
## economy from one delivered log through its completed two-plank batch.

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Sawmill operation QA requires native rendering")
		get_tree().quit(1)
		return
	_output = QaAssets.output_path(true, "native")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	assert(_output.is_absolute_path())
	for folder: String in ["frames", "motion", "actual"]:
		DirAccess.make_dir_recursive_absolute(_output.path_join(folder))
	get_tree().root.title = "Pila · zásoby a práce · nativní QA bez hudby"
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(960,690)
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
	if (_main.building_sprite_presentation(_building).get("operation", {}) as Dictionary).is_empty():
		printerr("Sawmill operation manifest is not yet authored; no passing QA claimed")
		get_tree().quit(2)
		return
	var assets_at_start: Dictionary = _asset_hashes()
	await _stock_matrix()
	await _activity_matrix()
	await _context_matrix()
	await _work_loop()
	await _actual_batch()
	var manifest := FileAccess.open(_output.path_join("capture-manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"date":"2026-09-12", "engine":Engine.get_version_info()["string"],
		"renderer":RenderingServer.get_video_adapter_name(), "scene":"res://scenes/main.tscn", "panel_size":[PANEL.x,PANEL.y],
		"fixture":"Exact state fixtures plus a real economy batch; no main-menu journey in this runner",
		"production_manifest_path":QaAssets.manifest_path(),
		"production_manifest_sha256":FileAccess.get_sha256(QaAssets.manifest_path()),
		"asset_hashes_at_start":assets_at_start,"asset_hashes_at_end":_asset_hashes(),
		"music_or_player_save_access":false, "captures":_records},"\t")+"\n")
	manifest.close()
	print("SAWMILL OPERATION NATIVE QA: %d captures -> %s" % [_records.size(),_output])
	get_tree().quit(0)

func _set_stock(logs: int, planks: int) -> void:
	_building["inputs"]["log"] = logs
	_building["outputs"]["plank"] = planks

func _stock_matrix() -> void:
	var textures: Array[Texture2D] = []
	var labels: Array[String] = []
	_apply_state("day-away")
	_frame(2.4)
	for logs: int in range(5):
		for planks: int in range(7):
			_set_stock(logs,planks)
			textures.append(ImageTexture.create_from_image(await _capture("frames/stock-%d-%d" % [logs,planks],{"kind":"stock", "logs":logs,"planks":planks})))
			labels.append("Klády %d / prkna %d" % [logs,planks])
	await _sheet("stocks","Pila · všech35 kombinací skutečné zásoby",textures,labels,7)

func _activity_matrix() -> void:
	var textures: Array[Texture2D] = []
	var labels: Array[String] = []
	var states: Array[String] = ["day-work","day-rest","day-paused","day-away"]
	var titles: Array[String] = ["Práce · rozpracovaná kláda","Odpočinek · zásoby zůstávají","Pauza · nedokončená dávka","Tesař venku · nedokončená dávka"]
	for index: int in range(states.size()):
		_apply_state(states[index])
		_set_stock(3,2)
		_building["process_remaining"] = 30 if index != 1 else 0
		_main.sawmill_operation.reset()
		_main.sawmill_operation.observe_tick(_world)
		_frame(2.4)
		textures.append(ImageTexture.create_from_image(await _capture("frames/"+states[index],{"kind":"activity", "state":states[index]})))
		labels.append(titles[index])
	await _sheet("activity","Pila · zásoba, přítomnost a výroba mají vlastní stav",textures,labels,3)

func _context_matrix() -> void:
	var textures: Array[Texture2D] = []
	var labels: Array[String] = []
	for zoom_value: float in [0.75,1.0,2.4]:
		await _fixture()
		_apply_state("day-work")
		_set_stock(4,4)
		_frame(zoom_value)
		textures.append(ImageTexture.create_from_image(await _capture("frames/zoom-"+str(zoom_value).replace(".","_"),{"kind":"zoom","zoom":zoom_value})))
		labels.append("Herní měřítko %.2f×" % zoom_value)
	await _fixture(true)
	_apply_state("day-work")
	_set_stock(4,4)
	_main.selected_cell = ANCHOR
	_frame(2.4)
	textures.append(ImageTexture.create_from_image(await _capture("frames/raised-footprint",{"kind":"raised-platform","height":6,"selected":true})))
	labels.append("Vyvýšená plošina · 4 × 2 polí")
	await _fixture(false,true)
	_apply_state("day-work")
	_set_stock(4,4)
	_frame(2.4)
	textures.append(ImageTexture.create_from_image(await _capture("frames/front-tree",{"kind":"front-tree"})))
	labels.append("Přední strom · zakrytí dílny")
	await _sheet("context","Pila · provoz v herním měřítku a na terénu",textures,labels,3)

func _work_loop() -> void:
	await _fixture()
	_apply_state("day-work")
	_set_stock(3,2)
	_frame(4.0)
	# Forty frames sample one productive second at 40 fps, not wall time.
	# Each preceding whole tick is observed before its next interpolation.
	_main.sawmill_operation.reset()
	_building["process_remaining"] = 60
	_main.sawmill_operation.observe_tick(_world)
	for index: int in range(40):
		_world.tick = 1751 + index / 4
		_building["process_remaining"] = 59 - index / 4
		_main.sawmill_operation.observe_tick(_world)
		_main.accumulator = float(index % 4) * 0.025
		await _capture("motion/work-%03d" % index,{"kind":"productive-loop","frame":index,"fps":40,"zoom":4.0})

func _actual_batch() -> void:
	await _fixture()
	_apply_state("day-rest")
	_set_stock(1,0)
	_frame(2.4)
	await _capture("actual/00-delivered",{"kind":"real-economy", "stage":"delivered"})
	var started: bool = false
	var checkpoints: Array[int] = []
	for index: int in range(180):
		_world.step_tick()
		_main.sawmill_operation.observe_tick(_world)
		_main.accumulator = 0.0
		var remaining: int = int(_building.get("process_remaining",0))
		if remaining > 0 and not started:
			started = true
			await _capture("actual/01-started",{"kind":"real-economy", "stage":"started","tick":_world.tick})
		if started and remaining in [45,30,15] and remaining not in checkpoints:
			checkpoints.append(remaining)
			await _capture("actual/progress-%02d" % remaining,{"kind":"real-economy", "stage":"working","tick":_world.tick})
		if int(_building["outputs"].get("plank",0)) == 2:
			assert(started and int(_building["inputs"].get("log",0)) == 0 and remaining == 0)
			await _capture("actual/02-produced",{"kind":"real-economy", "stage":"produced","tick":_world.tick})
			for _idle_tick: int in range(3):
				_world.step_tick()
				_main.sawmill_operation.observe_tick(_world)
			await _capture("actual/03-rest",{"kind":"real-economy", "stage":"rest","tick":_world.tick})
			return
	assert(false,"Sawmill did not complete its actual one-log batch in 180 ticks")

func _capture(name: String, metadata: Dictionary) -> Image:
	var result: Image = await super._capture(name,metadata)
	var record: Dictionary = _records[-1]
	record["operation"] = _main.building_operation_presentation(_building)
	var art: Dictionary = _main.building_operation_art_presentation(_building)
	var paths: Array[String] = []
	for layer: Dictionary in art.get("layers",[]):
		paths.append(String(layer["path"]))
	record["operation_art"] = {"available":not art.is_empty(),"frame_index":art.get("frame_index",-1),"layer_paths":paths}
	return result

func _asset_hashes() -> Dictionary:
	return QaAssets.asset_hashes()
