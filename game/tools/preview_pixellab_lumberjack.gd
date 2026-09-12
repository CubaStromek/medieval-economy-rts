extends Control

## Standalone asset viewer. Does not instantiate the game or change simulation.
## godot --path game res://tools/preview_pixellab_lumberjack.tscn
## After --: --validate-only [--require-complete], --manifest=res://...,
## or --capture=/absolute/directory (requires a native graphics display).
const Library = preload("res://scripts/view/lumberjack_animation_library.gd")
const DIRECTION_NAMES: Array[String] = ["Sever", "Severovýchod", "Východ", "Jihovýchod", "Jih", "Jihozápad", "Západ", "Severozápad"]
const CLIP_NAMES: Dictionary = {"walk_axe": "Chůze se sekerou", "chop": "Obouruční kácení", "walk_log": "Chůze s kládou"}
const WINDOW_SIZE := Vector2i(1240, 880)

var _library := Library.new()
var _clip_id: String = "walk_axe"
var _elapsed_seconds: float = 0.0
var _playing: bool = true
var _at_rest: bool = false
var _speed: float = 1.0
var _zoom: float = 3.0
var _green: bool = false
var _guides: bool = true
var _capture_directory: String = ""
var _status: Label
var _details: Label
var _pause_button: Button
var _clip_option: OptionButton
var _zoom_option: OptionButton
var _background_option: OptionButton
var _capture_records: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path: String = Library.MANIFEST_PATH
	var validate_only: bool = false
	var require_complete: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="):
			path = argument.trim_prefix("--manifest=")
		elif argument == "--validate-only":
			validate_only = true
		elif argument == "--require-complete":
			require_complete = true
		elif argument.begins_with("--capture="):
			_capture_directory = argument.trim_prefix("--capture=")
	var loaded: bool = _library.load_manifest(path)
	if validate_only:
		var valid: bool = loaded and (not require_complete or _library.is_complete())
		var checks: Dictionary = _validate_playback() if loaded else {}
		valid = valid and bool(checks.get("passed", false))
		print(JSON.stringify({"loaded": loaded, "complete": _library.is_complete(), "checks": checks, "errors": _library.errors, "warnings": _library.warnings}))
		get_tree().quit(0 if valid else 1)
		return
	get_tree().root.title = "Dřevorubec · PixelLab · samostatná ukázka"
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = WINDOW_SIZE
	get_tree().root.min_size = Vector2i(1080, 780)
	# The game uses viewport stretching. Disable it only in this standalone
	# window so 1x means one world pixel per captured pixel, including in QA.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.content_scale_factor = 1.0
	_build_ui()
	if loaded and not _library.clip_ids().has(_clip_id):
		_clip_id = _library.clip_ids()[0]
	_sync_controls()
	if not _capture_directory.is_empty():
		if not loaded or (require_complete and not _library.is_complete()):
			_capture_fail("Balík není dostupný v požadovaném rozsahu.")
		else:
			_capture_all.call_deferred()


func _process(delta: float) -> void:
	if _playing and _library.is_ready():
		_elapsed_seconds += delta * _speed
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_pause()
		accept_event()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Dřevorubec · animační sada"
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(24, 15)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Samostatná ukázka assetů v Godotu · běžná hra a její simulace zde nejsou zapojené"
	subtitle.position = Vector2(24, 51)
	subtitle.modulate = Color("abb9bc")
	add_child(subtitle)
	var controls := HBoxContainer.new()
	controls.position = Vector2(24, 86)
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	_clip_option = OptionButton.new()
	for clip_id: String in Library.CLIPS:
		_clip_option.add_item(String(CLIP_NAMES[clip_id]))
	_clip_option.item_selected.connect(_select_clip)
	controls.add_child(_clip_option)
	_pause_button = Button.new()
	_pause_button.pressed.connect(_toggle_pause)
	controls.add_child(_pause_button)
	var rest := Button.new()
	rest.text = "Klidový snímek"
	rest.pressed.connect(_show_rest)
	controls.add_child(rest)
	var step := Button.new()
	step.text = "Další snímek"
	step.tooltip_text = "Posune společný čas o jeden snímek nejrychlejšího dostupného směru."
	step.pressed.connect(_step_frame)
	controls.add_child(step)
	var speed := OptionButton.new()
	for value: float in [0.25, 0.5, 1.0, 2.0]:
		speed.add_item("Tempo %.2f×" % value)
	speed.select(2)
	speed.item_selected.connect(func(index: int) -> void: _speed = [0.25, 0.5, 1.0, 2.0][index])
	controls.add_child(speed)
	_zoom_option = OptionButton.new()
	for value: int in [1, 2, 3, 4]:
		_zoom_option.add_item("Měřítko %d×" % value)
	_zoom_option.item_selected.connect(func(index: int) -> void: _zoom = float(index + 1))
	controls.add_child(_zoom_option)
	_background_option = OptionButton.new()
	_background_option.add_item("Tmavé pozadí")
	_background_option.add_item("Zelené pozadí")
	_background_option.item_selected.connect(func(index: int) -> void: _green = index == 1)
	controls.add_child(_background_option)
	var guides := CheckButton.new()
	guides.text = "Kotvy"
	guides.button_pressed = _guides
	guides.toggled.connect(func(value: bool) -> void: _guides = value)
	controls.add_child(guides)
	_status = Label.new()
	_status.position = Vector2(24, 132)
	_status.size = Vector2(1180, 46)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_details = Label.new()
	_details.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_details.offset_left = 24
	_details.offset_top = -29
	_details.offset_right = -24
	_details.modulate = Color("abb9bc")
	add_child(_details)
	_refresh_status()


func _refresh_status() -> void:
	if not _library.is_ready():
		_status.text = "Sadu nelze načíst: " + "; ".join(_library.errors)
		_status.modulate = Color("ffaaa0")
		_details.text = _library.manifest_path
		return
	_status.text = "3 klipy × 8 směrů · vizuální kvalitu a návaznost smyček posuzujte přehráváním."
	if not _library.is_complete():
		var delivered: int = 0
		for clip_id: String in Library.CLIPS:
			for direction: String in Library.DIRECTIONS:
				if _library.frame_count(clip_id, direction) > 0:
					delivered += 1
		_status.text = "DÍLČÍ SADA · dodáno %d z 24 kombinací klipu a směru; %d zatím chybí. " % [delivered, 24 - delivered] + " ".join(_library.warnings)
		_status.modulate = Color("f3cf85")
	_details.text = "Tělo %.1f zdrojových px → 33 world px · společná kotva (%.1f, %.1f) · celé plátno · mezerník pozastaví" % [_library.body_height_source_px, _library.anchor_source_px.x, _library.anchor_source_px.y]


func _sync_controls() -> void:
	_clip_option.select(Library.CLIPS.find(_clip_id))
	_pause_button.text = "Pozastavit" if _playing else "Přehrát"
	_zoom_option.select(int(_zoom) - 1)
	_background_option.select(1 if _green else 0)


func _select_clip(index: int) -> void:
	_clip_id = Library.CLIPS[index]
	_elapsed_seconds = 0.0
	_at_rest = false


func _toggle_pause() -> void:
	_playing = not _playing
	if _playing:
		_at_rest = false
	_pause_button.text = "Pozastavit" if _playing else "Přehrát"


func _show_rest() -> void:
	_playing = false
	_at_rest = true
	_elapsed_seconds = float(_library.rest_frame(_clip_id)) / _fastest_fps(_clip_id)
	_sync_controls()


func _step_frame() -> void:
	_playing = false
	_at_rest = false
	var fps_value: float = _fastest_fps(_clip_id)
	_elapsed_seconds = float(floori(_elapsed_seconds * fps_value + 0.000001) + 1) / fps_value + 0.0000001
	_sync_controls()


func _fastest_fps(clip_id: String) -> float:
	var result: float = 0.01
	for direction: String in Library.DIRECTIONS:
		if _library.frame_count(clip_id, direction) > 0:
			result = maxf(result, _library.fps(clip_id, direction))
	return result


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10191d"))
	var font: Font = ThemeDB.fallback_font
	var gap: float = 14.0
	var card_size := Vector2((size.x - 48.0 - gap * 3.0) / 4.0, (size.y - 224.0 - gap) / 2.0)
	for index: int in range(Library.DIRECTIONS.size()):
		var direction: String = Library.DIRECTIONS[index]
		var origin := Vector2(24.0 + (index % 4) * (card_size.x + gap), 183.0 + (index / 4) * (card_size.y + gap))
		var card := Rect2(origin, card_size)
		draw_style_box(_card_style(), card)
		draw_string(font, origin + Vector2(14, 26), direction + " · " + DIRECTION_NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("edf3eb"))
		var feet: Vector2 = origin + Vector2(card_size.x * 0.5, card_size.y * 0.72)
		var frame: int = _library.frame_index(_clip_id, direction, _elapsed_seconds, _at_rest)
		var sample: Dictionary = _library.presentation_frame(_clip_id, direction, feet, frame)
		if sample.has("error"):
			draw_string(font, origin + Vector2(14, card_size.y * 0.53), "Tento směr zatím chybí", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f3cf85"))
			continue
		var world_rect: Rect2 = sample["rect"] as Rect2
		var rect := Rect2(feet + (world_rect.position - feet) * _zoom, world_rect.size * _zoom)
		if _guides:
			draw_rect(rect, Color(0.7, 0.85, 0.72, 0.20), false)
			draw_line(feet + Vector2(-40, 0), feet + Vector2(40, 0), Color(1.0, 0.84, 0.5, 0.45))
		draw_texture_rect(sample["texture"] as Texture2D, rect, false)
		if _guides:
			draw_line(feet + Vector2(-4, 0), feet + Vector2(4, 0), Color("ffd88c"), 1.0)
			draw_line(feet + Vector2(0, -4), feet + Vector2(0, 4), Color("ffd88c"), 1.0)
		var details: String = "%d / %d snímků · %.1f fps · %.0f×" % [frame + 1, _library.frame_count(_clip_id, direction), _library.fps(_clip_id, direction), _zoom]
		draw_string(font, origin + Vector2(14, card_size.y - 15), details, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c8d5c4"))


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("465837") if _green else Color("243035")
	style.border_color = Color("516642") if _green else Color("36474e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _validate_playback() -> Dictionary:
	var checked_frames: int = 0
	var failures: Array[String] = []
	for clip_id: String in _library.clip_ids():
		for direction: String in Library.DIRECTIONS:
			var count: int = _library.frame_count(clip_id, direction)
			if count == 0:
				continue
			var rate: float = _library.fps(clip_id, direction)
			for frame: int in range(count):
				var time: float = (float(frame) + 0.25) / rate
				var sample: Dictionary = _library.presentation_for(clip_id, direction, Vector2(70, 90), time)
				if sample.get("frame_index", -1) != frame or sample.get("flip_h", true) or not (sample.get("texture") is AtlasTexture):
					failures.append("Nesprávný výběr snímku " + clip_id + "/" + direction + "/" + str(frame))
				var rect: Rect2 = sample.get("rect", Rect2()) as Rect2
				if not (rect.position + _library.anchor_source_px * _library.world_px_per_source_px).is_equal_approx(Vector2(70, 90)) or not rect.size.is_equal_approx(Vector2(_library.source_canvas_px) * _library.world_px_per_source_px):
					failures.append("Nesprávná registrace " + clip_id + "/" + direction)
				checked_frames += 1
			if _library.frame_index(clip_id, direction, (float(count) + 0.25) / rate) != 0:
				failures.append("Smyčka se nepřetočila: " + clip_id + "/" + direction)
			if _library.frame_index(clip_id, direction, 123.0, true) != _library.rest_frame(clip_id):
				failures.append("Klidový snímek se nerespektuje: " + clip_id)
	return {"passed": failures.is_empty() and checked_frames > 0, "checked_frames": checked_frames, "failures": failures, "scope": "atlas regions, alpha, hash, registration, frame selection, loop wrap, rest frame; no visual or gameplay acceptance"}


func _capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		_capture_fail("Nativní snímky vyžadují grafický režim; vynechte --headless.")
		return
	if not _capture_directory.is_absolute_path():
		_capture_fail("Výstup snímků musí být absolutní adresář.")
		return
	var error: Error = DirAccess.make_dir_recursive_absolute(_capture_directory)
	if error != OK:
		_capture_fail("Nelze vytvořit adresář snímků: " + error_string(error))
		return
	_playing = false
	_at_rest = false
	for clip_id: String in _library.clip_ids():
		_clip_id = clip_id
		var longest_seconds: float = 0.0
		for direction: String in Library.DIRECTIONS:
			if _library.frame_count(clip_id, direction) > 0:
				longest_seconds = maxf(longest_seconds, float(_library.frame_count(clip_id, direction)) / _library.fps(clip_id, direction))
		for phase: float in [0.0, 0.25, 0.5, 0.75]:
			_zoom = 3.0
			_green = false
			_elapsed_seconds = longest_seconds * phase + 0.25 / _fastest_fps(clip_id)
			if not await _capture_one("%s-dark-3x-phase-%02d.png" % [clip_id, roundi(phase * 100)]):
				return
		_zoom = 1.0
		_green = true
		if not await _capture_one(clip_id + "-green-1x.png"):
			return
	var report: Dictionary = {
		"captured_at": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(), "scene": "res://tools/preview_pixellab_lumberjack.tscn",
		"window_content_scale_mode": get_tree().root.content_scale_mode,
		"window_content_scale_factor": get_tree().root.content_scale_factor,
		"world_to_capture_px_at_1x": 1.0,
		"manifest": _library.manifest_path, "manifest_sha256": FileAccess.get_sha256(_library.manifest_path),
		"complete": _library.is_complete(), "simulated_gameplay": false,
		"scope": "Native standalone asset preview; normal game path and user visual approval are not established.",
		"checks": _validate_playback(), "captures": _capture_records,
	}
	var file: FileAccess = FileAccess.open(_capture_directory.path_join("native-capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		_capture_fail("Nelze zapsat evidenci nativních snímků.")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PIXELLAB NATIVE PREVIEW: %d captures → %s" % [_capture_records.size(), _capture_directory])
	get_tree().quit(0)


func _capture_one(filename: String) -> bool:
	_sync_controls()
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_capture_fail("Renderer nevrátil snímek.")
		return false
	var destination: String = _capture_directory.path_join(filename)
	if image.save_png(destination) != OK:
		_capture_fail("Nelze uložit snímek " + destination)
		return false
	var indices: Dictionary = {}
	var rates: Dictionary = {}
	for direction: String in Library.DIRECTIONS:
		indices[direction] = _library.frame_index(_clip_id, direction, _elapsed_seconds)
		if _library.frame_count(_clip_id, direction) > 0:
			rates[direction] = _library.fps(_clip_id, direction)
	_capture_records.append({"file": filename, "sha256": FileAccess.get_sha256(destination), "clip": _clip_id, "frames_zero_based": indices, "fps_by_direction": rates, "elapsed_seconds": _elapsed_seconds, "zoom": _zoom, "background": "green" if _green else "dark", "size_px": [image.get_width(), image.get_height()]})
	return true


func _capture_fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
