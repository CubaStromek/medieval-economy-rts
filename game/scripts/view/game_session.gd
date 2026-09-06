extends Node

const MainScene = preload("res://scenes/main.tscn")
const MainView = preload("res://scripts/view/main_view.gd")
const MainMenu = preload("res://scripts/view/main_menu.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")

var game: MainView
var menu: MainMenu
var save_path: String = SaveSystemClass.DEFAULT_PATH
var honor_launch_arguments: bool = true


func _ready() -> void:
	_configure_window()
	menu = MainMenu.new()
	menu.name = "MainMenu"
	menu.new_game_requested.connect(_start_new_game)
	menu.load_game_requested.connect(_load_saved_game)
	menu.resume_requested.connect(_resume_game)
	menu.save_game_requested.connect(_save_game)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	add_child(menu)
	_show_main_menu()
	if honor_launch_arguments:
		var arguments: PackedStringArray = OS.get_cmdline_user_args()
		if arguments.has("--economy-demo"):
			_start_new_game("economy")
		elif arguments.has("--relief-demo"):
			_start_new_game("relief")


func _configure_window() -> void:
	if get_parent() != get_tree().root or Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	var arguments: PackedStringArray = OS.get_cmdline_args()
	if arguments.has("--windowed") or arguments.has("-w") or arguments.has("--resolution"):
		return
	var window: Window = get_tree().root
	if window.mode == Window.MODE_WINDOWED:
		window.mode = ProjectSettings.get_setting("display/window/size/mode", Window.MODE_MAXIMIZED) as Window.Mode


func _show_main_menu() -> void:
	if game != null:
		# Disable the whole gameplay subtree, including input and the HUD. Its
		# simulation speed and fractional tick remain intact for Resume.
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.hide()
		game.hud.hide()
	menu.show_home(game != null, FileAccess.file_exists(save_path))
	if get_viewport() == get_tree().root:
		get_tree().root.title = "Medieval Economy RTS · Hlavní menu"


func _resume_game() -> void:
	if game == null:
		return
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
		get_tree().root.title = "Medieval Economy RTS"


func _start_new_game(map_id: String) -> void:
	if map_id not in ["test", "relief", "economy"]:
		menu.show_error("Tato mapa není dostupná. Vyber jinou mapu.")
		return
	_open_game(map_id)


func _load_saved_game() -> void:
	# Validate in isolation before replacing a running session.
	var restored := World.new()
	if not SaveSystemClass.load_world(restored, save_path):
		menu.show_error("Uloženou hru se nepodařilo načíst. Soubor chybí nebo je poškozený.")
		return
	_open_game(SaveSystemClass.saved_map_id(save_path), restored)


func _open_game(map_id: String, restored: World = null) -> void:
	if game != null:
		remove_child(game)
		game.queue_free()
	game = MainScene.instantiate() as MainView
	game.honor_launch_arguments = false
	game.demo_kind = map_id
	game.save_path = save_path
	game.world = restored
	game.main_menu_requested.connect(_show_main_menu)
	add_child(game)
	_resume_game()


func _save_game() -> void:
	if game == null:
		return
	var saved: bool = game._save_game()
	menu.show_home(true, FileAccess.file_exists(save_path))
	if saved:
		menu.show_status("Hra byla uložena.")
	else:
		menu.show_error("Hru se nepodařilo uložit. Zkus to znovu.")
