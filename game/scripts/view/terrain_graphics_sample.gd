extends Node2D

# Standalone visual experiment. No live world, save file or production renderer
# is replaced. Original reference art and map patches are external local data.
const ReferenceRenderer = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const CurrentRenderer = preload("res://scripts/view/terrain_renderer.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const DATA_PATH: String = "res://external_assets/terrain-sample/patches.json"
const ATLAS_PATH: String = "res://external_assets/terrain-sample/tiles1.tga"

var patches: Array = []
var selected_patch: int = 0
var atlas: Image
var before: CurrentRenderer
var after: ReferenceRenderer
var current_grid: Grid
var heading: Label
var description: Label
var footer: Label
var before_label: Label
var after_label: Label
var buttons: Array[Button] = []
var error_message: String = ""

func _ready() -> void:
	_build_ui()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not parsed is Dictionary or parsed.get("format") != "kam-visual-sample-v1" or not parsed.get("patches") is Array:
		_error("Chybí místní referenční data. Viz docs/terrain-graphics-sample.md.")
		return
	patches = parsed["patches"]
	atlas = Image.new()
	var atlas_error: Error = atlas.load_tga_from_buffer(FileAccess.get_file_as_bytes(ATLAS_PATH)) if FileAccess.file_exists(ATLAS_PATH) else ERR_FILE_NOT_FOUND
	if atlas_error != OK or atlas.get_size() != Vector2i(512, 512):
		_error("Chybí místní atlas Tiles1.tga (512 × 512). Běžná hra zůstává beze změny.")
		return
	get_viewport().size_changed.connect(_layout)
	select_patch(0)
	if get_parent() == get_tree().root:
		get_tree().root.title = "KaM · Vzorek grafiky terénu"

func _error(message: String) -> void:
	error_message = message
	description.text = message
	_layout()

func _label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	add_child(result)
	return result

func _build_ui() -> void:
	heading = _label("Jak může vypadat terén podle KaM", 30, Color("e9eadd"))
	description = _label("Stejná mapová data · skutečné vykreslení v Godotu", 17, Color("a6b5a8"))
	before_label = _label("DNEŠNÍ PROTOTYP", 18, Color("d5b878"))
	after_label = _label("REFERENČNÍ VZOREK KaM", 18, Color("9dd3ad"))
	footer = _label("22 × 18 polí · místní referenční textury · statická voda · bez objektů a změn běžné hry", 16, Color("a6b5a8"))
	for index: int in range(2):
		var button := Button.new()
		button.text = "Louka a skála" if index == 0 else "Břeh jezírka"
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(select_patch.bind(index))
		add_child(button)
		buttons.append(button)

func select_patch(index: int) -> void:
	if index < 0 or index >= patches.size() or not patches[index] is Dictionary:
		return
	var data: Dictionary = patches[index]
	var candidate := ReferenceRenderer.new()
	if not candidate.configure(data, atlas):
		candidate.free()
		_error("Referenční výřez nelze vykreslit: data nesplňují podmínky vzorku.")
		return
	error_message = ""
	selected_patch = index
	if before != null:
		before.free()
	if after != null:
		after.free()
	var dimensions: Array = data["size"]
	current_grid = Grid.new(Vector2i(int(dimensions[0]), int(dimensions[1])))
	var heights := PackedInt32Array()
	for y: int in range(current_grid.size.y + 1):
		for x: int in range(current_grid.size.x + 1):
			heights.append(roundi(float(data["height_halo"][y + 1][x + 1]) * 0.15))
	current_grid._vertex_heights = heights
	var materials := PackedByteArray()
	var codes: Dictionary = {"g": 0, "d": 1, "w": 2, "r": 3}
	for row: String in data["prototype_terrain"]:
		for code: String in row:
			materials.append(int(codes[code]))
	current_grid._base_terrain = materials
	current_grid._record_full_render_change()
	before = CurrentRenderer.new()
	add_child(before)
	before.bind_grid(current_grid)
	after = candidate
	add_child(after)
	description.text = String(data["name"]) + " · Mountainous Region · stejná mapová data, jiné vykreslování"
	for i: int in range(buttons.size()):
		buttons[i].disabled = i == index
	_layout()

func _layout() -> void:
	var size: Vector2 = get_viewport_rect().size
	heading.position = Vector2(28, 18)
	description.position = Vector2(28, 62)
	buttons[0].position = Vector2(maxf(680, size.x - 350), 24)
	buttons[0].size = Vector2(164, 42)
	buttons[1].position = Vector2(maxf(852, size.x - 178), 24)
	buttons[1].size = Vector2(150, 42)
	var width: float = (size.x - 80.0) * 0.5
	before_label.position = Vector2(28, 112)
	after_label.position = Vector2(52 + width, 112)
	footer.position = Vector2(28, size.y - 40)
	if before != null and after != null and error_message.is_empty():
		var bounds: Rect2 = before.map_bounds().merge(after.bounds()).grow(8)
		var region := Rect2(Vector2(28, 150), Vector2(width, maxf(120, size.y - 218)))
		var zoom: float = minf(region.size.x / bounds.size.x, region.size.y / bounds.size.y)
		for item: Node2D in [before, after]:
			item.scale = Vector2.ONE * zoom
		before.position = region.get_center() - bounds.get_center() * zoom
		region.position.x += width + 24
		after.position = region.get_center() - bounds.get_center() * zoom
	queue_redraw()

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("111b17"))
	var size: Vector2 = get_viewport_rect().size
	draw_line(Vector2(size.x * 0.5, 110), Vector2(size.x * 0.5, size.y - 66), Color("354338"), 1)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			select_patch(0)
		elif event.keycode == KEY_2:
			select_patch(1)
		elif event.keycode == KEY_SPACE:
			select_patch(1 - selected_patch)
