extends Node

const MainScene = preload("res://scenes/main.tscn")
const MainView = preload("res://scripts/view/main_view.gd")
const MainMenu = preload("res://scripts/view/main_menu.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const ImportedTerrain = preload("res://scripts/simulation/imported_terrain.gd")
const RegionStart = preload("res://scripts/simulation/mountainous_region_start.gd")
const SandboxScene = preload("res://scenes/terrain_graphics_sandbox.tscn")
const UiScaleClass = preload("res://scripts/view/ui_scale.gd")

var game: MainView
var menu: MainMenu
var sandbox: Control
var sandbox_layer: CanvasLayer
var save_path: String = SaveSystemClass.DEFAULT_PATH
var region_save_path: String = MainView.TERRAIN_STUDY_SAVE_PATH
var terrain_map_path: String = ImportedTerrain.DEFAULT_PATH
var honor_launch_arguments: bool = true


func _ready() -> void:
	_configure_window()
	menu = MainMenu.new()
	menu.name = "MainMenu"
	menu.new_game_requested.connect(_start_new_game)
	menu.load_game_requested.connect(_load_saved_game)
	menu.resume_requested.connect(_resume_game)
	menu.save_game_requested.connect(_save_game)
	menu.graphics_sandbox_requested.connect(_open_graphics_sandbox)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	add_child(menu)
	_show_main_menu()
	if honor_launch_arguments:
		var arguments: PackedStringArray = OS.get_cmdline_user_args()
		if arguments.has("--economy-demo"):
			_start_new_game("economy")
		elif arguments.has("--relief-demo"):
			_start_new_game("relief")
		elif arguments.has("--mountainous-region"):
			_start_new_game("mountainous-region")
		elif arguments.has("--graphics-sandbox"):
			_open_graphics_sandbox()


func _configure_window() -> void:
	if get_parent() != get_tree().root or Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	var window: Window = get_tree().root
	# A larger monitor has to buy visible map, not proportionally larger panels.
	UiScaleClass.apply(window)
	if not window.size_changed.is_connected(_apply_ui_scale):
		window.size_changed.connect(_apply_ui_scale)
	var arguments: PackedStringArray = OS.get_cmdline_args()
	if arguments.has("--windowed") or arguments.has("-w") or arguments.has("--resolution"):
		return
	if window.mode == Window.MODE_WINDOWED:
		window.mode = ProjectSettings.get_setting("display/window/size/mode", Window.MODE_MAXIMIZED) as Window.Mode


func _apply_ui_scale() -> void:
	if is_inside_tree():
		UiScaleClass.apply(get_tree().root)


func _show_main_menu() -> void:
	_close_sandbox()
	if game != null:
		# Disable the whole gameplay subtree, including input and the HUD. Its
		# simulation speed and fractional tick remain intact for Resume.
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.hide()
		game.hud.hide()
	_refresh_menu()
	if get_viewport() == get_tree().root:
		get_tree().root.title = "Medieval Economy RTS · Hlavní menu"


func _resume_game() -> void:
	if game == null:
		return
	_close_sandbox()
	menu.hide()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	game.show()
	game.hud.show()
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.camera.make_current()
	game.camera.force_update_scroll()
	if get_viewport() == get_tree().root:
		game._update_window_title()


func _start_new_game(map_id: String) -> void:
	if map_id not in ["test", "relief", "economy", "mountainous-region"]:
		menu.show_error("Tato mapa není dostupná. Vyber jinou mapu.")
		return
	if map_id == "mountainous-region":
		# The optional landscape must be ready before an existing game is replaced.
		var imported: Dictionary = ImportedTerrain.load_world(terrain_map_path)
		var prepared: World = imported.get("world") as World
		if prepared == null or not RegionStart.matches_import(prepared, imported):
			menu.show_error("Mapu Mountainous Region nelze otevřít. Její místní data chybí nebo nejsou platná.")
			return
		prepared.economy_enabled = false
		if not prepared.can_place_building("warehouse", RegionStart.WAREHOUSE_CELL) or not prepared.can_place_building("school", RegionStart.SCHOOL_CELL):
			menu.show_error("Mapa Mountainous Region nemá dostupné místo pro počáteční osadu.")
			return
		RegionStart.apply_if_supported(prepared, imported)
		prepared.enable_fog()
		_open_game(map_id, prepared)
		return
	_open_game(map_id)


func _load_saved_game() -> void:
	# Validate in isolation before replacing a running session.
	var restored := World.new()
	var path: String = menu.selected_save_path
	if path.is_empty():
		path = save_path
	if not SaveSystemClass.load_world(restored, path):
		menu.show_error("Uloženou hru se nepodařilo načíst. Soubor chybí nebo je poškozený.")
		return
	_open_game(SaveSystemClass.saved_map_id(path), restored, path)


func _open_game(map_id: String, restored: World = null, loaded_path: String = "") -> void:
	_close_sandbox()
	if game != null:
		remove_child(game)
		game.queue_free()
	game = MainScene.instantiate() as MainView
	game.honor_launch_arguments = false
	game.demo_kind = map_id
	game.save_path = save_path
	game.save_path_override = loaded_path if not loaded_path.is_empty() else (region_save_path if map_id == "mountainous-region" else save_path)
	game.terrain_map_path = terrain_map_path
	game.world = restored
	game.main_menu_requested.connect(_show_main_menu)
	add_child(game)
	_resume_game()


func _save_game() -> void:
	if game == null:
		return
	var saved: bool = game._save_game()
	_refresh_menu()
	if saved:
		menu.show_status("Hra byla uložena.")
	else:
		menu.show_error("Hru se nepodařilo uložit. Zkus to znovu.")


func _refresh_menu() -> void:
	var saves: Array[Dictionary] = []
	if FileAccess.file_exists(save_path):
		saves.append({"path": save_path, "title": "Běžná hra"})
	if region_save_path != save_path and FileAccess.file_exists(region_save_path):
		saves.append({"path": region_save_path, "title": "Mountainous Region"})
	menu.set_saved_games(saves)
	menu.show_home(game != null, not saves.is_empty())


func _open_graphics_sandbox() -> void:
	_show_main_menu()
	menu.hide()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	# A separate screen layer keeps this Control independent of the game's
	# active Camera2D, including when opened from a zoomed or panned map.
	sandbox_layer = CanvasLayer.new()
	sandbox_layer.name = "GraphicsSandboxLayer"
	sandbox_layer.layer = 10
	add_child(sandbox_layer)
	sandbox = SandboxScene.instantiate() as Control
	sandbox.connect("main_menu_requested", _show_main_menu)
	sandbox_layer.add_child(sandbox)
	if get_viewport() == get_tree().root:
		get_tree().root.title = "Medieval Economy RTS · Grafický sandbox"


func _close_sandbox() -> void:
	if sandbox_layer == null:
		return
	remove_child(sandbox_layer)
	sandbox_layer.queue_free()
	sandbox_layer = null
	sandbox = null
