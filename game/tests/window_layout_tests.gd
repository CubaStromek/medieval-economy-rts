extends RefCounted

const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const GameHudClass = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 5


# SubViewports exercise logical layouts independently of the headless display.
# Project settings cover the native window policy and expansion to its aspect.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_check_window_policy(failures)
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1680, 720)]:
		var viewport: SubViewport = _viewport(host, viewport_size)
		var main: MainViewClass = _main(viewport)
		await _settle(host)
		_check_layout(main, viewport, "Startup %s" % viewport_size, failures)
		_check_camera_fit(main, viewport, "Startup %s" % viewport_size, failures)
		viewport.free()
	await _check_live_resize(host, failures)
	await _check_manual_camera_resize(host, failures)
	return failures


static func _check_window_policy(failures: Array[String]) -> void:
	_expect(int(ProjectSettings.get_setting("display/window/size/mode", Window.MODE_WINDOWED)) == Window.MODE_MAXIMIZED,
		"Standalone play must start maximized, not at a fixed or exclusive fullscreen size", failures)
	_expect(bool(ProjectSettings.get_setting("display/window/size/resizable", true)),
		"The native game window must remain resizable", failures)
	_expect(String(ProjectSettings.get_setting("display/window/stretch/mode", "disabled")) == "canvas_items",
		"Canvas-item scaling must keep the HUD readable at monitor resolution", failures)
	_expect(String(ProjectSettings.get_setting("display/window/stretch/aspect", "keep")) == "expand",
		"The logical viewport must expand to the available aspect instead of adding black bars", failures)


static func _check_live_resize(host: Node, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host, Vector2i(1152, 720))
	var main: MainViewClass = _main(viewport)
	await _settle(host)
	_check_camera_fit(main, viewport, "Before resize", failures)
	var initial_position: Vector2 = main.camera.position
	var initial_zoom: Vector2 = main.camera.zoom
	for viewport_size: Vector2i in [Vector2i(1680, 720), Vector2i(1280, 900), Vector2i(1280, 720)]:
		viewport.size = viewport_size
		# No explicit recenter call: the actual viewport resize must drive the view.
		await _settle(host)
		_check_layout(main, viewport, "Resized %s" % viewport_size, failures)
		_check_camera_fit(main, viewport, "Resized %s" % viewport_size, failures)
		if viewport_size == Vector2i(1280, 900):
			_expect(not main.camera.zoom.is_equal_approx(initial_zoom),
				"Giving the overview more height must recompute the map's fit zoom", failures)
			_expect(not main.camera.position.is_equal_approx(initial_position),
				"The resized overview must adjust its framing as the map's fit zoom changes", failures)
	viewport.free()


static func _check_manual_camera_resize(host: Node, failures: Array[String]) -> void:
	var viewport: SubViewport = _viewport(host, Vector2i(1280, 720))
	var main: MainViewClass = _main(viewport)
	await _settle(host)
	var overview_zoom: Vector2 = main.camera.zoom
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.position = Vector2(980, 410)
	event.global_position = event.position
	viewport.push_input(event, true)
	await _settle(host)
	_expect(not main.camera.zoom.is_equal_approx(overview_zoom),
		"Manual-camera fixture must really zoom through normal viewport input", failures)
	var manual_position: Vector2 = main.camera.position
	var manual_zoom: Vector2 = main.camera.zoom
	viewport.size = Vector2i(1680, 900)
	await _settle(host)
	_check_layout(main, viewport, "Manual camera after resize", failures)
	_expect(main.camera.position.is_equal_approx(manual_position) and main.camera.zoom.is_equal_approx(manual_zoom),
		"Resizing after manual camera control must retain the player's position and zoom", failures)
	viewport.free()


static func _check_layout(main: MainViewClass, viewport: SubViewport, label: String, failures: Array[String]) -> void:
	var expected_view := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var root: Control = main.find_child("HudRoot", true, false) as Control
	if root == null:
		failures.append(label + ": HUD root must exist")
		return
	_expect(root.get_global_rect().is_equal_approx(expected_view),
		label + ": HUD must fill the whole logical viewport instead of retaining a fixed rectangle", failures)
	# The event strip is part of the status bar now, so there is no separate
	# floating panel for overlays to cover.
	for node_name: String in ["OverviewBar", "StatusBar", "VillagePanel"]:
		var panel: Control = main.find_child(node_name, true, false) as Control
		if panel == null:
			failures.append(label + ": Missing " + node_name)
			continue
		var rect: Rect2 = panel.get_global_rect()
		_expect(expected_view.grow(1.0).encloses(rect), label + ": " + node_name + " must stay inside the resized window", failures)
		if node_name in ["OverviewBar", "StatusBar"]:
			_expect(absf(rect.position.x - GameHudClass.EDGE) < 1.0
					and absf(rect.end.x - (viewport.size.x - GameHudClass.EDGE)) < 1.0,
				label + ": " + node_name + " must span the available width", failures)
		if node_name == "StatusBar":
			_expect(absf(rect.position.y - (viewport.size.y - GameHudClass.STATUS_TOP)) < 1.0,
				label + ": Time controls must follow the bottom window edge", failures)
		if node_name == "VillagePanel":
			_expect(absf(rect.position.y - GameHudClass.MAP_TOP) < 1.0
					and absf(rect.end.y - (viewport.size.y - GameHudClass.DOCK_BOTTOM)) < 1.0,
				label + ": Sidebar must use the available height", failures)
			_expect(rect.size.x < float(viewport.size.x) / 4.0,
				label + ": Sidebar must leave at least three quarters of the width to the map", failures)


static func _check_camera_fit(main: MainViewClass, viewport: SubViewport, label: String, failures: Array[String]) -> void:
	var available := Rect2(Vector2(GameHudClass.MAP_LEFT, GameHudClass.MAP_TOP),
		Vector2(viewport.size) - Vector2(GameHudClass.MAP_LEFT + GameHudClass.EDGE, GameHudClass.MAP_TOP + GameHudClass.MAP_BOTTOM))
	var bounds: Rect2 = main.terrain_renderer.map_bounds().grow(44.0)
	var transform: Transform2D = viewport.get_canvas_transform()
	var screen_bounds: Rect2 = transform * bounds
	_expect(screen_bounds.get_center().distance_to(available.get_center()) < 1.0,
		label + ": Overview must center the map in the current unobstructed area", failures)
	_expect(available.grow(1.0).encloses(screen_bounds),
		label + ": The initial map overview must fit between the current HUD edges", failures)
	_expect(absf(screen_bounds.size.x - available.size.x) < 1.0 or absf(screen_bounds.size.y - available.size.y) < 1.0,
		label + ": Overview must use the available width or height instead of staying unnecessarily small", failures)


static func _viewport(host: Node, viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.world_2d = World2D.new()
	host.add_child(viewport)
	return viewport


static func _main(viewport: SubViewport) -> MainViewClass:
	var main: MainViewClass = MainScene.instantiate() as MainViewClass
	main.demo_kind = "test"
	viewport.add_child(main)
	main.set_process(false)
	main.world.economy_enabled = false
	main.camera.position_smoothing_enabled = false
	return main


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
