extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const MainScene = preload("res://scenes/main.tscn")
const MainView = preload("res://scripts/view/main_view.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 2 # Real placement/cancellation at both supported sizes.


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for window_size: Vector2i in [Vector2i(1152, 720), Vector2i(1440, 900)]:
		var viewport := SubViewport.new()
		viewport.size = window_size
		viewport.world_2d = World2D.new()
		host.add_child(viewport)
		var main: MainView = MainScene.instantiate() as MainView
		viewport.add_child(main)
		main.set_process(false)
		main.world = LegacyFixture.create(Vector2i(16, 12))
		var store_cell := Vector2i(2, 2)
		var store_id: int = main.world.place_building("warehouse", store_cell)
		main.world.economy_enabled = true
		main.terrain_renderer.bind_grid(main.world.grid)
		main.camera.position_smoothing_enabled = false
		main.camera.zoom = Vector2.ONE
		await _settle(host)
		var site_cell := Vector2i(9, 5)
		var point := Vector2(float(window_size.x) * 0.7, float(window_size.y) * 0.5)
		_center(main, viewport, site_cell, point)
		_key(viewport, KEY_5)
		await _settle(host)
		_click(viewport, point)
		await _settle(host)
		var site_id: int = main.world.building_id_at(site_cell)
		_check(site_id != 0, "School shortcut and map click must create an actual site", failures)
		var cancel: Button = main.find_child("CancelConstruction", true, false) as Button
		var stop: Button = main.find_child("CancelBuild", true, false) as Button
		if site_id == 0 or cancel == null or stop == null:
			failures.append("Construction UI fixture needs a site and both distinct buttons")
			viewport.free()
			continue
		_check(int(main.world.buildings[site_id]["construction_remaining"]) > 0, "Placed school must be unfinished", failures)
		_check(_on_screen(cancel, viewport), "Cancel construction must be visible in Details without scrolling", failures)
		_check(not cancel.disabled, "Cancellation must remain enabled while the site is unfinished", failures)
		_check(stop.text.contains("Stop placing"), "Esc button must clearly describe placement mode, not site removal", failures)
		_key(viewport, KEY_ESCAPE)
		await _settle(host)
		_check(main.build_mode.is_empty() and main.world.buildings.has(site_id), "Esc must exit placement without deleting the site", failures)
		_check(_on_screen(cancel, viewport), "Site cancellation must remain available after leaving placement mode", failures)
		_click(viewport, cancel.get_global_rect().get_center())
		await _settle(host)
		_check(not main.world.buildings.has(site_id) and main.world.grid.is_walkable(site_cell), "Actual cancellation click must remove the site and unblock ground", failures)
		_check(main.build_mode.is_empty() and main.selected_cell == Vector2i(-1, -1), "Cancellation must clear selection and avoid unintended replacement", failures)
		_check(not cancel.is_visible_in_tree(), "Deleted site must no longer expose the cancellation button", failures)
		_check(main.world.can_place_building("school", site_cell), "The freed tile must be immediately reusable", failures)
		_center(main, viewport, store_cell, point)
		await _settle(host)
		_click(viewport, point)
		await _settle(host)
		_check(main.world.building_id_at(main.selected_cell) == store_id, "Completed warehouse must be selected by the map click", failures)
		_check(not cancel.is_visible_in_tree(), "Completed buildings must never offer construction cancellation", failures)
		var restored := LegacyFixture.create()
		_check(restored.from_data(main.world.to_data()), "UI cancellation must leave a saveable world", failures)
		viewport.free()
	return failures


static func _center(main: MainView, viewport: SubViewport, cell: Vector2i, point: Vector2) -> void:
	var world_position: Vector2 = main.terrain_renderer.to_global(main.terrain_renderer.cell_center(cell))
	main.camera.position = world_position - (point - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _click(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		viewport.push_input(event, true)


static func _key(viewport: Viewport, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)


static func _on_screen(control: Control, viewport: SubViewport) -> bool:
	if not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if not Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(rect):
		return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			if not (ancestor as Control).get_global_rect().encloses(rect):
				return false
		ancestor = ancestor.get_parent()
	return true


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
