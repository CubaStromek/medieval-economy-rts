extends Control

# Native, isolated graphics workbench. Never instantiates the simulation world,
# writes saves, or changes the production scene. All experiments are local.
const Terrain = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const Prototype = preload("res://scripts/view/terrain_renderer.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Objects = preload("res://scripts/view/terrain_sandbox_objects.gd")
const State = preload("res://scripts/view/terrain_sandbox_state.gd")
const DATA_PATH: String = "res://external_assets/terrain-sample/patches.json"
const ATLAS_PATH: String = "res://external_assets/terrain-sample/tiles1.tga"
const OBJECT_PATH: String = "res://external_assets/terrain-sample/objects.json"
const SETTINGS_PATH: String = "res://external_assets/terrain-sandbox/last-settings.json"
const CAPTURE_DIR: String = "res://external_assets/terrain-sandbox/captures"

var state := State.new()
var patches: Array = []
var object_patches: Array = []
var atlas := Image.new()
var before: Node2D
var after: Terrain
var objects: Objects
var current_grid: Grid
var canvas_boxes: Array[SubViewportContainer] = []
var canvases: Array[SubViewport] = []
var worlds: Array[Node2D] = []
var panel_columns: Array[VBoxContainer] = []
var panel_labels: Array[Label] = []
var controls: Dictionary = {}
var value_labels: Dictionary = {}
var crop_choice: OptionButton
var comparison_choice: OptionButton
var status: Label
var inspector: Label
var layer_note: Label
var capture_button: Button
var pan := Vector2.ZERO
var dragging: bool = false
var error_message: String = ""
var capture_busy: bool = false
var last_capture: String = ""

func _ready() -> void:
	_build_ui()
	if get_parent() == get_tree().root:
		get_tree().root.title = "KaM · Grafický sandbox"
		get_tree().root.min_size = Vector2i(1100, 720)
	var data: Variant = _read_json(DATA_PATH)
	if not data is Dictionary or data.get("format") != "kam-visual-sample-v1" or not data.get("patches") is Array or data["patches"].size() != 2:
		_fail("Chybí místní výřezy mapy. Viz docs/terrain-graphics-sandbox.md.")
		return
	patches = data["patches"]
	if not FileAccess.file_exists(ATLAS_PATH) or atlas.load_tga_from_buffer(FileAccess.get_file_as_bytes(ATLAS_PATH)) != OK:
		_fail("Chybí místní atlas terénu. Běžná hra ho nepotřebuje.")
		return
	var object_data: Variant = _read_json(OBJECT_PATH)
	if object_data is Dictionary and object_data.get("format") == "kam-sandbox-objects-v1" and object_data.get("patches") is Array:
		object_patches = object_data["patches"]
	var saved: Variant = _read_json(SETTINGS_PATH)
	if saved != null:
		state.restore(saved)
	_sync_controls()
	select_patch(int(state.values["patch"]))
	resized.connect(_layout_worlds)
	_layout_worlds.call_deferred()

static func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null

func _fail(message: String) -> void:
	error_message = message
	status.text = message
	capture_button.disabled = true

func _label(text: String, font_size: int = 16, muted: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("9dab9f") if muted else Color("e6ecdf"))
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	button.custom_minimum_size.y = 34
	return button

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("111a16")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	page.add_child(header)
	var title := _label("Grafický sandbox", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Uložit nastavení", save_settings))
	capture_button = _button("Pořídit snímek", capture)
	header.add_child(capture_button)
	header.add_child(_button("Výchozí nastavení", reset_settings))
	page.add_child(_label("Mountainous Region · stejný výřez, ovladatelné vrstvy · běžná hra zůstává beze změny", 15, true))
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	page.add_child(main)
	var stage := VBoxContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 10)
	main.add_child(stage)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	stage.add_child(toolbar)
	crop_choice = OptionButton.new()
	crop_choice.add_item("Louka a skála")
	crop_choice.add_item("Břeh jezírka")
	crop_choice.item_selected.connect(select_patch)
	toolbar.add_child(crop_choice)
	comparison_choice = OptionButton.new()
	comparison_choice.add_item("Jen pracovní verze")
	comparison_choice.add_item("Vedle terénní reference")
	comparison_choice.add_item("Vedle dnešní hry")
	comparison_choice.item_selected.connect(_comparison_changed)
	toolbar.add_child(comparison_choice)
	toolbar.add_child(_button("Vycentrovat", reset_camera))
	var panels := HBoxContainer.new()
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_theme_constant_override("separation", 10)
	stage.add_child(panels)
	for index: int in range(2):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panels.add_child(column)
		panel_columns.append(column)
		var label := _label("DNEŠNÍ PROTOTYP" if index == 0 else "PRACOVNÍ VERZE", 15)
		column.add_child(label)
		panel_labels.append(label)
		var box := SubViewportContainer.new()
		box.stretch = true
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size = Vector2(100, 100)
		box.gui_input.connect(_canvas_input.bind(index))
		box.resized.connect(_layout_worlds)
		column.add_child(box)
		canvas_boxes.append(box)
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.gui_disable_input = true
		box.add_child(viewport)
		canvases.append(viewport)
		var world := Node2D.new()
		viewport.add_child(world)
		worlds.append(world)
	inspector = _label("Kolečko: přiblížení · tažení levým / prostředním tlačítkem: posun · 1 / 2: výřez", 14, true)
	inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(inspector)
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 290
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2720")
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	sidebar.add_theme_stylebox_override("panel", style)
	main.add_child(sidebar)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 5)
	scroll.add_child(settings)
	settings.add_child(_label("TERÉN", 15))
	_toggle(settings, "Původní textury", "textures")
	_toggle(settings, "Stínování svahů", "lighting")
	_slider(settings, "Síla stínování", "light_strength", 0, 1.5)
	_slider(settings, "Výraznost výšek", "relief_scale", 0, 1.5)
	_toggle(settings, "Vyhlazené filtrování", "linear_filter")
	_toggle(settings, "Zobrazit mřížku", "grid")
	settings.add_child(HSeparator.new())
	settings.add_child(_label("OBJEKTY · EXPERIMENT", 15))
	_toggle(settings, "Naše náhradní stromy", "trees")
	_toggle(settings, "Jednoduché kontaktní stíny", "shadows")
	_slider(settings, "Velikost stromů", "tree_scale", 0.5, 1.5)
	_toggle(settings, "Pozice původních objektů", "markers")
	layer_note = _label("", 13, true)
	layer_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(layer_note)
	settings.add_child(HSeparator.new())
	_slider(settings, "Přiblížení výřezu", "zoom", 0.5, 3)
	settings.add_child(HSeparator.new())
	var evidence := _label("PODKLADY\nTerén: původní atlas + výšky\nStromy: naše náhradní sprity\nVoda: statická, snímky chybí\n\nReference není screenshot KaM.\nJe to naše vykreslení jeho terénu.", 13, true)
	evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(evidence)
	status = _label("Připraveno · změny platí jen v tomto sandboxu", 14, true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(status)

func _toggle(parent: VBoxContainer, text: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.toggled.connect(_option_changed.bind(key))
	parent.add_child(toggle)
	controls[key] = toggle

func _slider(parent: VBoxContainer, text: String, key: String, minimum: float, maximum: float) -> void:
	var label := _label(text, 13, true)
	label.set_meta("caption", text)
	parent.add_child(label)
	value_labels[key] = label
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.custom_minimum_size.y = 22
	slider.value_changed.connect(_option_changed.bind(key))
	parent.add_child(slider)
	controls[key] = slider

func _sync_controls() -> void:
	for key: String in controls:
		var control: Control = controls[key]
		if control is CheckButton:
			control.set_pressed_no_signal(bool(state.values[key]))
		elif control is HSlider:
			control.set_value_no_signal(float(state.values[key]))
			var label: Label = value_labels[key]
			label.text = String(label.get_meta("caption")) + " · %d %%" % roundi(float(state.values[key]) * 100)
	crop_choice.select(int(state.values["patch"]))
	comparison_choice.select(int(state.values["comparison"]))
	controls["shadows"].disabled = not bool(state.values["trees"])

func _option_changed(value: Variant, key: String) -> void:
	state.set_value(key, value)
	_sync_controls()
	_apply_options()

func set_option(key: String, value: Variant) -> void:
	_option_changed(value, key)

func select_patch(index: int) -> void:
	if index < 0 or index >= patches.size() or not patches[index] is Dictionary:
		return
	var candidate := Terrain.new()
	if not candidate.configure(patches[index], atlas):
		candidate.free()
		_fail("Výřez obsahuje neplatná data; předchozí zobrazení zůstalo zachováno.")
		return
	error_message = ""
	capture_button.disabled = false
	state.set_value("patch", index)
	if objects != null:
		objects.free()
	if after != null:
		after.free()
	after = candidate
	worlds[1].add_child(after)
	objects = Objects.new()
	worlds[1].add_child(objects)
	var source: Array = []
	for patch: Variant in object_patches:
		if patch is Dictionary and patch.get("origin") == patches[index].get("origin") and patch.get("objects") is Array:
			source = patch["objects"]
			break
	objects.configure(after, source)
	layer_note.text = "%d stromů / %d objektů v mapě.\nSprity a jejich ukotvení jsou zatím náhradní; nejde o originál KaM." % [objects.tree_count(), objects.marker_count()]
	_rebuild_before()
	pan = Vector2.ZERO
	_sync_controls()
	_apply_options()
	status.text = "Výřez %s · 22 × 18 polí · voda zůstává statická" % String(patches[index]["name"])

func _rebuild_before() -> void:
	if before != null:
		before.free()
	var data: Dictionary = patches[int(state.values["patch"])]
	if int(state.values["comparison"]) == 2:
		current_grid = _prototype_grid(data)
		var renderer := Prototype.new()
		worlds[0].add_child(renderer)
		renderer.bind_grid(current_grid)
		before = renderer
	else:
		var renderer := Terrain.new()
		renderer.configure(data, atlas)
		worlds[0].add_child(renderer)
		before = renderer
	panel_columns[0].visible = int(state.values["comparison"]) != 0
	panel_labels[0].text = "DNEŠNÍ PROTOTYP" if int(state.values["comparison"]) == 2 else "VÝCHOZÍ TERÉNNÍ REFERENCE"
	panel_labels[1].text = "PRACOVNÍ VERZE · OVLADATELNÉ VRSTVY"
	_layout_worlds.call_deferred()

static func _prototype_grid(data: Dictionary) -> Grid:
	var dimensions: Array = data["size"]
	var grid := Grid.new(Vector2i(int(dimensions[0]), int(dimensions[1])))
	var heights := PackedInt32Array()
	for y: int in range(grid.size.y + 1):
		for x: int in range(grid.size.x + 1):
			heights.append(roundi(float(data["height_halo"][y + 1][x + 1]) * 0.15))
	grid._vertex_heights = heights
	var materials := PackedByteArray()
	var codes: Dictionary = {"g": 0, "d": 1, "w": 2, "r": 3}
	for row: String in data["prototype_terrain"]:
		for code: String in row:
			materials.append(int(codes[code]))
	grid._base_terrain = materials
	grid._record_full_render_change()
	return grid

func _comparison_changed(index: int) -> void:
	state.set_value("comparison", index)
	if after != null:
		_rebuild_before()
	_sync_controls()

func _apply_options() -> void:
	if after == null:
		return
	after.set_visual_options(state.values)
	objects.set_options(state.values)
	objects.queue_redraw()
	_layout_worlds()

func _layout_worlds() -> void:
	if after == null or before == null:
		return
	# A fixed source-scale frame keeps both panes aligned when relief changes.
	var data: Dictionary = patches[int(state.values["patch"])]
	var bounds := Rect2(Vector2.ZERO, Vector2(after.sample_size) * 40)
	for y: int in range(after.sample_size.y + 1):
		for x: int in range(after.sample_size.x + 1):
			bounds = bounds.expand(Terrain.project_vertex(Vector2i(x, y), float(data["height_halo"][y + 1][x + 1]) * 1.5))
	bounds = bounds.grow(32)
	var available: Vector2 = canvas_boxes[1].size
	if panel_columns[0].visible:
		available.x = minf(available.x, canvas_boxes[0].size.x)
	var fit: float = minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var zoom: float = maxf(0.01, fit) * float(state.values["zoom"])
	for index: int in range(2):
		worlds[index].scale = Vector2.ONE * zoom
		worlds[index].position = canvas_boxes[index].size * 0.5 - bounds.get_center() * zoom + pan

func _canvas_input(event: InputEvent, index: int) -> void:
	if after == null:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_option("zoom", float(state.values["zoom"]) * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15))
	elif event is InputEventMouseMotion:
		if dragging and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			pan += event.relative
			_layout_worlds()
		_inspect_at(event.position, index)

func _inspect_at(position: Vector2, index: int) -> void:
	var local: Vector2 = (position - worlds[index].position) / worlds[index].scale
	var data: Dictionary = patches[int(state.values["patch"])]
	# Picking follows visible deformed triangles, never an undeformed top-down grid.
	var renderer: Terrain = after if index == 1 else before as Terrain
	if renderer == null:
		inspector.text = "Dnešní prototyp · podrobnosti polí zkoumej v pracovní verzi vpravo"
		return
	for y: int in range(after.sample_size.y - 1, -1, -1):
		for x: int in range(after.sample_size.x - 1, -1, -1):
			var tl: Vector2 = renderer.projected_point(Vector2(x, y))
			var tr: Vector2 = renderer.projected_point(Vector2(x + 1, y))
			var br: Vector2 = renderer.projected_point(Vector2(x + 1, y + 1))
			var bl: Vector2 = renderer.projected_point(Vector2(x, y + 1))
			if Geometry2D.is_point_in_polygon(local, PackedVector2Array([tl, tr, br])) or Geometry2D.is_point_in_polygon(local, PackedVector2Array([tl, br, bl])):
				var tile: Array = data["tile_rows"][y][x]
				inspector.text = "Pole %d, %d · textura %d · otočení %d° · výška rohu %d · zdrojové souřadnice %d, %d" % [x, y, tile[0], int(tile[1]) * 90, data["height_halo"][y + 1][x + 1], int(data["origin"][0]) + x, int(data["origin"][1]) + y]
				return
	inspector.text = "Kolečko: přiblížení · tažení: posun · 1 / 2: výřez · F: vycentrovat"

func reset_camera() -> void:
	pan = Vector2.ZERO
	state.set_value("zoom", 1.0)
	_sync_controls()
	_layout_worlds()

func reset_settings() -> void:
	state.reset()
	_sync_controls()
	select_patch(0)
	status.text = "Výchozí nastavení obnoveno · uložený preset se změní až tlačítkem Uložit nastavení"

func save_settings() -> void:
	if after == null:
		return
	if _write_json(SETTINGS_PATH, state.snapshot()) == OK:
		status.text = "Nastavení uloženo · načte se při příštím spuštění sandboxu"
	else:
		status.text = "Nastavení nelze uložit: složka sandboxu není zapisovatelná"

static func _write_json(path: String, data: Dictionary) -> Error:
	var absolute: String = ProjectSettings.globalize_path(path)
	var result: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if result != OK:
		return result
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	return file.get_error()

func capture() -> void:
	if capture_busy or after == null:
		return
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_msec())
	var path: String = CAPTURE_DIR + "/sandbox-" + stamp + ".png"
	var absolute: String = ProjectSettings.globalize_path(path)
	var result: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if result == OK:
		result = picture.save_png(absolute)
	if result == OK:
		var metadata: Dictionary = state.snapshot()
		metadata["camera_pan"] = [pan.x, pan.y]
		metadata["limitations"] = ["Static source water", "Prototype tree artwork and anchors", "Experimental contact shadows"]
		var metadata_error: Error = _write_json(path.get_basename() + ".json", metadata)
		last_capture = absolute
		status.text = "Snímek uložen: " + absolute.get_file() + (" (+ nastavení)" if metadata_error == OK else " (nastavení se nepodařilo uložit)")
	else:
		status.text = "Snímek nelze uložit: složka sandboxu není zapisovatelná"
	capture_busy = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_patch(0)
			KEY_2: select_patch(1)
			KEY_F: reset_camera()
