class_name MainMenu
extends CanvasLayer

signal new_game_requested(map_id: String)
signal load_game_requested()
signal save_game_requested()
signal resume_requested()
signal quit_requested()

const INK := Color("#e9e9dc")
const MUTED := Color("#a0aba4")
const ACCENT := Color("#d9bd77")
const MAPS: Array[Dictionary] = [
	{
		"id": "test", "title": "Nová osada", "details": "28 × 22 polí  ·  Budování od začátku",
		"description": "Začni se skladem a školou, bez obyvatel. Přiveď první osadníky a postav svou vlastní prosperující vesnici.",
	},
	{
		"id": "relief", "title": "Osídlené údolí", "details": "28 × 22 polí  ·  Kopcovitá krajina",
		"description": "Převezmi malou vesnici s obyvateli. Rozšiřuj osadu mezi kopci a propoj její pracoviště cestami.",
	},
	{
		"id": "economy", "title": "Ekonomická ukázka", "details": "34 × 30 polí  ·  Rozvinuté město",
		"description": "Prozkoumej rozvinuté město s výrobními řetězci. Sleduj práci obyvatel, tok surovin a fungování ekonomiky.",
	},
]

var selected_map_id: String:
	get:
		return String(MAPS[_map_picker.selected]["id"]) if is_instance_valid(_map_picker) else "test"

var _root: Control
var _home_page: VBoxContainer
var _maps_page: VBoxContainer
var _new_game_button: Button
var _load_game_button: Button
var _save_game_button: Button
var _resume_button: Button
var _save_hint: Label
var _error_label: Label
var _map_picker: OptionButton
var _map_title: Label
var _map_details: Label
var _map_description: Label
var _replace_hint: Label
var _has_session: bool = false


class MenuBackdrop extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)


	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("#111d1c"))
		draw_circle(Vector2(w * 0.82, h * 0.22), 44.0, Color("#d9bd7710"))
		draw_circle(Vector2(w * 0.82, h * 0.22), 30.0, Color("#d9bd7714"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.64), Vector2(w * 0.13, h * 0.50),
			Vector2(w * 0.31, h * 0.64), Vector2(w * 0.57, h * 0.47),
			Vector2(w * 0.73, h * 0.56), Vector2(w, h * 0.40),
			Vector2(w, h), Vector2(0, h),
		]), Color("#1b2c27"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.74), Vector2(w * 0.21, h * 0.67),
			Vector2(w * 0.45, h * 0.80), Vector2(w * 0.68, h * 0.64),
			Vector2(w * 0.88, h * 0.75), Vector2(w, h * 0.65),
			Vector2(w, h), Vector2(0, h),
		]), Color("#23382c"))
		for index: int in range(9):
			var x: float = w * (0.025 + float(index) * 0.027)
			var y: float = h * 0.75 - sin(float(index) * 0.8) * 12.0
			var height: float = 34.0 + float(index % 3) * 11.0
			draw_rect(Rect2(x - 2, y - 8, 4, 19), Color("#0e211b"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - height), Vector2(x - 14, y), Vector2(x + 14, y),
			]), Color("#13291f"))
		for index: int in range(4):
			var x: float = w * 0.81 + float(index) * 34.0
			var y: float = h * 0.75 + float(index % 2) * 9.0
			draw_rect(Rect2(x, y - 26, 29, 28), Color("#162720"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 4, y - 26), Vector2(x + 14, y - 44), Vector2(x + 33, y - 26),
			]), Color("#101f1b"))
			draw_rect(Rect2(x + 12, y - 19, 5, 7), Color("#d9bd7750"))
		draw_line(Vector2(32, 32), Vector2(w - 32, 32), Color("#d9bd7729"), 1.0)
		draw_line(Vector2(32, h - 32), Vector2(w - 32, h - 32), Color("#d9bd7729"), 1.0)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	show_home(false, false)


func show_home(has_session: bool, has_save: bool) -> void:
	_has_session = has_session
	visible = true
	_home_page.show()
	_maps_page.hide()
	_resume_button.visible = has_session
	_save_game_button.visible = has_session
	_load_game_button.disabled = not has_save
	_save_hint.visible = not has_save
	_replace_hint.visible = has_session
	_error_label.hide()
	if has_session:
		_resume_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func show_error(message: String) -> void:
	_error_label.text = message
	_error_label.add_theme_color_override("font_color", Color("#f0ac97"))
	_error_label.visible = not message.is_empty()


func show_status(message: String) -> void:
	_error_label.text = message
	_error_label.add_theme_color_override("font_color", ACCENT)
	_error_label.visible = not message.is_empty()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _maps_page.visible:
		_back_to_home()
	elif _has_session:
		resume_requested.emit()
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = _menu_theme()
	add_child(_root)
	var backdrop := MenuBackdrop.new()
	_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size.x = 540
	panel.add_theme_stylebox_override("panel", _style(Color("#172421f5"), Color("#d9bd7750"), 12))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 5)
	column.add_child(brand)
	_label(brand, "BUDUJ  ·  OBCHODUJ  ·  ROZVÍJEJ", 11, ACCENT)
	_label(brand, "MEDIEVAL ECONOMY", 32, INK)
	_label(brand, "R T S   /   Život tvé osady začíná tady.", 13, MUTED)
	column.add_child(HSeparator.new())
	_build_home(column)
	_build_maps(column)
	_error_label = _label(column, "", 13, Color("#f0ac97"))
	_error_label.name = "ErrorLabel"
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.hide()
	var footer: Label = _label(column, "Šipky / Tab  ·  Výběr       Enter  ·  Potvrdit       Esc  ·  Zpět", 11, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_home(parent: Control) -> void:
	_home_page = VBoxContainer.new()
	_home_page.name = "HomePage"
	_home_page.add_theme_constant_override("separation", 9)
	parent.add_child(_home_page)
	_resume_button = _button(_home_page, "Pokračovat ve hře", "ResumeButton", true)
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	_new_game_button = _button(_home_page, "Nová hra", "NewGameButton", true)
	_new_game_button.pressed.connect(_show_maps)
	_load_game_button = _button(_home_page, "Načíst hru", "LoadGameButton")
	_load_game_button.pressed.connect(func() -> void: load_game_requested.emit())
	_save_hint = _label(_home_page, "Zatím nemáš uloženou hru. Hru uložíš klávesou F5.", 12, MUTED)
	_save_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_hint.custom_minimum_size.y = 34
	_save_game_button = _button(_home_page, "Uložit hru", "SaveGameButton")
	_save_game_button.pressed.connect(func() -> void: save_game_requested.emit())
	var quit_button: Button = _button(_home_page, "Ukončit", "QuitButton")
	quit_button.pressed.connect(func() -> void: quit_requested.emit())


func _build_maps(parent: Control) -> void:
	_maps_page = VBoxContainer.new()
	_maps_page.name = "MapsPage"
	_maps_page.add_theme_constant_override("separation", 12)
	parent.add_child(_maps_page)
	_label(_maps_page, "Vyber si mapu", 22, INK)
	_map_picker = OptionButton.new()
	_map_picker.name = "MapPicker"
	_map_picker.custom_minimum_size.y = 46
	_map_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in MAPS:
		_map_picker.add_item(String(entry["title"]))
	_maps_page.add_child(_map_picker)
	_map_picker.item_selected.connect(_update_map_description)
	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size.y = 138
	details_panel.add_theme_stylebox_override("panel", _style(Color("#10201b"), Color("#d9bd7728"), 8))
	_maps_page.add_child(details_panel)
	var details_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		details_margin.add_theme_constant_override("margin_" + side, 16)
	details_panel.add_child(details_margin)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 7)
	details_margin.add_child(details)
	_map_title = _label(details, "", 20, ACCENT)
	_map_details = _label(details, "", 12, MUTED)
	_map_description = _label(details, "", 14, INK)
	_map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_map_description(0)
	_replace_hint = _label(_maps_page, "Spuštěním nové mapy nahradíš rozehranou hru.", 12, MUTED)
	_replace_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_replace_hint.hide()
	var start_button: Button = _button(_maps_page, "Spustit mapu", "StartMapButton", true)
	start_button.pressed.connect(func() -> void: new_game_requested.emit(selected_map_id))
	var back_button: Button = _button(_maps_page, "Zpět", "BackButton")
	back_button.pressed.connect(_back_to_home)


func _show_maps() -> void:
	_home_page.hide()
	_maps_page.show()
	_error_label.hide()
	_map_picker.grab_focus()


func _back_to_home() -> void:
	_maps_page.hide()
	_home_page.show()
	_error_label.hide()
	_new_game_button.grab_focus()


func _update_map_description(index: int) -> void:
	var entry: Dictionary = MAPS[index]
	_map_title.text = String(entry["title"])
	_map_details.text = String(entry["details"])
	_map_description.text = String(entry["description"])


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, node_name: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("#d9bd77"), Color("#e4cb91"), 6))
		button.add_theme_stylebox_override("hover", _style(Color("#e9ce8c"), Color("#f1daac"), 6))
		button.add_theme_stylebox_override("pressed", _style(Color("#b99b5e"), Color("#d9bd77"), 6))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color("#1b2820"))
	parent.add_child(button)
	return button


func _menu_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for type_name: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, _style(Color("#23352d"), Color("#485448"), 6))
		theme.set_stylebox("hover", type_name, _style(Color("#304537"), ACCENT, 6))
		theme.set_stylebox("pressed", type_name, _style(Color("#14251e"), ACCENT, 6))
		theme.set_stylebox("disabled", type_name, _style(Color("#1b2923"), Color("#344037"), 6))
		var focus_style: StyleBoxFlat = _style(Color.TRANSPARENT, Color("#f8e4b3"), 6)
		focus_style.set_border_width_all(2)
		focus_style.expand_margin_left = 3
		focus_style.expand_margin_right = 3
		focus_style.expand_margin_top = 3
		focus_style.expand_margin_bottom = 3
		theme.set_stylebox("focus", type_name, focus_style)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type_name, INK)
		theme.set_color("font_disabled_color", type_name, Color("#68766b"))
	theme.set_stylebox("panel", "PopupMenu", _style(Color("#1a2b23"), Color("#897b56"), 6))
	theme.set_stylebox("hover", "PopupMenu", _style(Color("#3b4b35"), Color.TRANSPARENT, 4))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", ACCENT)
	theme.set_constant("v_separation", "PopupMenu", 16)
	var separator := StyleBoxLine.new()
	separator.color = Color("#d9bd7733")
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	return theme


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
