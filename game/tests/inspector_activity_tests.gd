extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const Main = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const Hud = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 7


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_live_read_only_thoughts_and_indoor(failures)
	_test_worker_and_workplace_pause_are_separate(failures)
	_test_building_service_and_construction_controls(failures)
	_test_foreign_and_unknown_targets(failures)
	_test_stale_target_callbacks(failures)
	await _test_actual_selection_and_clicks(host, failures)
	await _test_narrow_inspector_scroll(host, failures)
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _main(world: World, worker_id: int = 0) -> Main:
	var main := Main.new()
	main.world = world
	main._build_ui()
	main.selected_unit_id = worker_id
	main._update_ui()
	return main


static func _fixture() -> Dictionary:
	var world := LegacyFixture.create(Vector2i(18, 12))
	var home: int = world.place_building("sawmill", Vector2i(4, 3))
	var worker: int = world.spawn_worker(world.buildings[home]["entrance"], "carpenter", home)
	world.economy_enabled = true
	return {"world": world, "home": home, "worker": worker}


static func _test_live_read_only_thoughts_and_indoor(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = world.workers[f["worker"]]
	world.enable_fog(1)
	var main: Main = _main(world, f["worker"])
	var thoughts: Dictionary = world.unit_thoughts(worker)
	_check(not thoughts.is_empty() and main.hud._thoughts_panel.visible
		and main.hud._thought_current.text == "Teď: " + String(thoughts["current"])
		and main.hud._thought_next.text == "Potom: " + String(thoughts["next"]),
		"The selected person's Czech current/next text must come directly from its real simulation thoughts", failures)
	var saved: Dictionary = world.to_data()
	var transient: Dictionary = world.workers.duplicate(true)
	for _frame: int in range(5):
		main._update_ui()
	_check(world.to_data() == saved and world.workers == transient,
		"Refreshing thought text must not advance needs, choose work, move people or alter any saved/transient worker state", failures)
	_check(world._enter_worker_building(worker, f["home"]), "Thought UI fixture must enter the actual employee's workplace", failures)
	main._update_ui()
	var indoor: Dictionary = world.unit_thoughts(worker)
	_check(world.is_worker_inside(worker) and main.selected_unit_id == int(f["worker"])
		and main.hud._thoughts_panel.visible and main.hud._activity_panel.visible
		and main.hud._thought_current.text == "Teď: " + String(indoor["current"])
		and not bool(main.worker_satiety_presentation(worker, Vector2.ZERO)["visible"]),
		"An indoor resident must retain its live thoughts and own pause control while its map presentation remains hidden", failures)
	main.free()
	var meal_world := LegacyFixture.create(Vector2i(12, 10))
	var inn: int = meal_world.place_building("inn", Vector2i(4, 3))
	var diner_id: int = meal_world.spawn_worker(meal_world.buildings[inn]["entrance"], "carrier")
	meal_world.buildings[inn]["inputs"]["bread"] = 1
	meal_world.workers[diner_id]["hunger"] = 100
	meal_world.economy_enabled = true
	meal_world.enable_fog(1)
	meal_world.step_tick()
	var diner: Dictionary = meal_world.workers[diner_id]
	var meal_main: Main = _main(meal_world, diner_id)
	var eating: Dictionary = meal_world.unit_thoughts(diner)
	_check(int(diner.get("meal_ticks_left", 0)) > 0 and meal_world.is_worker_inside(diner)
		and meal_main.hud._thoughts_panel.visible and meal_main.hud._activity_panel.visible
		and meal_main.hud._thought_current.text == "Teď: " + String(eating.get("current", ""))
		and meal_main.hud._thought_current.text.contains("Jím"),
		"A real indoor diner must display its current eating thoughts and retain its individual work control", failures)
	meal_main.free()


static func _test_worker_and_workplace_pause_are_separate(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var main: Main = _main(world, f["worker"])
	var events: Array = []
	main.hud.entity_enabled_requested.connect(func(kind: String, id: int, enabled: bool) -> void: events.append([kind, id, enabled]))
	_check(main.hud._activity_button.text == "Pozastavit práci", "An enabled worker must offer the Czech work pause action", failures)
	main.hud._activity_button.pressed.emit()
	_check(not bool(world.workers[f["worker"]].get("enabled", true)) and bool(world.buildings[f["home"]].get("enabled", true))
		and main.hud._activity_button.text == "Pokračovat v práci"
		and events == [["worker", f["worker"], false]],
		"The real HUD signal must pause precisely the selected worker, keep its building enabled and offer resume", failures)
	main.hud._activity_button.pressed.emit()
	world.set_building_enabled(f["home"], false)
	main._update_ui()
	_check(bool(world.workers[f["worker"]].get("enabled", true)) and world.is_worker_work_paused(world.workers[f["worker"]])
		and main.hud._activity_button.text == "Pozastavit práci"
		and main.hud._activity_status.text.contains("Pracoviště je pozastavené"),
		"An individually enabled worker must explain its paused workplace without showing a misleading unit resume action", failures)
	main.hud._activity_button.pressed.emit()
	main.hud._activity_button.pressed.emit()
	_check(bool(world.workers[f["worker"]].get("enabled", true)) and not bool(world.buildings[f["home"]].get("enabled", true))
		and world.is_worker_work_paused(world.workers[f["worker"]]),
		"Resuming the unit must never silently resume its independently paused workplace", failures)
	main.free()


static func _test_building_service_and_construction_controls(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(24, 14))
	var ids: Array[int] = []
	for item: Array in [["sawmill", Vector2i(3, 3)], ["inn", Vector2i(8, 3)], ["school", Vector2i(13, 3)], ["warehouse", Vector2i(18, 3)]]:
		ids.append(world.place_building(String(item[0]), item[1]))
	world.buildings[ids[0]]["outputs"]["plank"] = 3
	world.buildings[ids[1]]["inputs"]["bread"] = 2
	world.buildings[ids[3]]["storage"]["gold"] = 2
	world.economy_enabled = true
	var site: int = world.place_building("lumber_hut", Vector2i(10, 9))
	ids.append(site)
	var main: Main = _main(world)
	for id: int in ids:
		_check(id != 0, "Every service/workplace/site fixture must be an actual building", failures)
		if id == 0:
			continue
		main.selected_cell = world.buildings[id]["position"]
		main._update_ui()
		var before: Dictionary = world.buildings[id].duplicate(true)
		var stock: Dictionary = world.resource_stock("plank")
		_check(main.hud._activity_panel.visible and not main.hud._thoughts_panel.visible
			and main.hud._activity_button.text == ("Pozastavit stavbu" if id == site else "Pozastavit provoz"),
			"Buildings including services and unfinished sites must expose the appropriate Czech pause action, without unit thoughts", failures)
		main.hud._activity_button.pressed.emit()
		var after: Dictionary = world.buildings[id].duplicate(true)
		before.erase("enabled")
		after.erase("enabled")
		_check(not bool(world.buildings[id].get("enabled", true)) and before == after and world.resource_stock("plank") == stock
			and main.hud._activity_button.text == ("Obnovit stavbu" if id == site else "Obnovit provoz"),
			"Pausing from the building inspector must preserve its progress, inventory and queues and expose resume", failures)
		main.hud._activity_button.pressed.emit()
		_check(bool(world.buildings[id].get("enabled", false)), "The same building button must restore only that building's operation", failures)
	main.free()


static func _test_foreign_and_unknown_targets(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(32, 20))
	var local: int = world.spawn_worker(Vector2i(4, 4), "carrier")
	var enemy: int = world.spawn_worker(Vector2i(7, 4), "carrier", 0, true, 0, 2)
	var foreign_building: int = world.place_building("school", Vector2i(27, 15), 2)
	world.enable_fog(1)
	var main: Main = _main(world, enemy)
	_check(world.is_entity_visible(world.workers[enemy]) and not main.hud._activity_panel.visible
		and not main.hud._thoughts_panel.visible and main.hud._thought_current.text.is_empty(),
		"Even a visible foreign unit must expose neither thoughts nor work controls", failures)
	var before: Dictionary = world.to_data()
	main.hud.entity_enabled_requested.emit("worker", enemy, false)
	_check(world.to_data() == before, "A forged foreign-unit UI signal must not mutate the world", failures)
	main.selected_unit_id = 0
	main.selected_cell = world.buildings[foreign_building]["position"]
	main._update_ui()
	_check(not main.hud._activity_panel.visible and main.hud.building_inventory_label.text.is_empty()
		and not main.hud._thoughts_panel.visible,
		"An unknown building must expose no activity action or private inspector text", failures)
	before = world.to_data()
	main.hud.entity_enabled_requested.emit("building", foreign_building, false)
	_check(world.to_data() == before, "Unknown/foreign building signals must be rejected without changing enable flags", failures)
	world.fog.enabled = false
	main.selected_unit_id = enemy
	main._update_ui()
	_check(not main.hud._activity_panel.visible and not main.hud._thoughts_panel.visible,
		"Disabling fog for a scenario must not grant control of foreign workers or their private thoughts", failures)
	main.selected_unit_id = local
	main._update_ui()
	_check(main.hud._activity_panel.visible and main.hud._thoughts_panel.visible,
		"Ownership hiding needs a positive control: the local unit must still expose both panels", failures)
	main.free()


static func _test_stale_target_callbacks(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var other: int = world.spawn_worker(Vector2i(9, 7), "carrier")
	var main: Main = _main(world, f["worker"])
	main.selected_unit_id = other
	main._update_ui()
	var before: Dictionary = world.to_data()
	main.hud.entity_enabled_requested.emit("worker", f["worker"], false)
	main.hud.entity_enabled_requested.emit("building", f["home"], false)
	main.hud.entity_enabled_requested.emit("not_an_entity", other, false)
	_check(world.to_data() == before, "Delayed signals for an old unit, a different entity type or an invalid kind must not target the new selection", failures)
	main.selected_unit_id = 0
	main.selected_cell = world.buildings[f["home"]]["position"]
	main._update_ui()
	before = world.to_data()
	main.hud.entity_enabled_requested.emit("worker", other, false)
	_check(world.to_data() == before, "A delayed unit signal after selecting a building must not change the previous unit", failures)
	main.selected_unit_id = other
	world.tile_reservations.erase(world.workers[other]["position"])
	world.workers.erase(other)
	before = world.to_data()
	main.hud.entity_enabled_requested.emit("worker", other, false)
	_check(world.to_data() == before, "A removed selected unit must be rejected safely when an old control callback arrives", failures)
	main._update_ui()
	_check(not main.hud._activity_panel.visible and not main.hud._thoughts_panel.visible,
		"Deleted selections must clear both new inspector panels", failures)
	main.free()


static func _attach(host: Node, f: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: Main = MainScene.instantiate() as Main
	main.world = f["world"]
	main.honor_launch_arguments = false
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.simulation_speed = 0.0
	return {"viewport": viewport, "main": main}


static func _settle(host: Node) -> void:
	for _frame: int in range(3):
		await host.get_tree().process_frame


static func _click(viewport: SubViewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)


static func _on_screen(control: Control, viewport: SubViewport) -> bool:
	if not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if not Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(rect):
		return false
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is Control and (parent as Control).clip_contents and not (parent as Control).get_global_rect().grow(1).encloses(rect):
			return false
		parent = parent.get_parent()
	return true


static func _center(main: Main, viewport: SubViewport, cell: Vector2i) -> void:
	main._camera_auto_fit = false
	main.camera.zoom = Vector2.ONE
	main.camera.position = main.terrain_renderer.cell_center(cell) - (Vector2(650, 390) - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()


static func _test_actual_selection_and_clicks(host: Node, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var carrier: int = world.spawn_worker(Vector2i(10, 8), "carrier")
	var attached: Dictionary = _attach(host, f)
	var main: Main = attached["main"]
	var viewport: SubViewport = attached["viewport"]
	await _settle(host)
	_center(main, viewport, world.workers[carrier]["position"])
	await _settle(host)
	var feet: Vector2 = main.terrain_renderer.cell_center(world.workers[carrier]["position"])
	var body: Rect2 = main.worker_presentation(world.workers[carrier], feet)["rect"]
	_click(viewport, viewport.get_canvas_transform() * body.get_center())
	await _settle(host)
	_check(main.selected_unit_id == carrier and _on_screen(main.hud._activity_button, viewport),
		"Clicking a real unit body must expose its pause control within the narrow inspector without scrolling", failures)
	_click(viewport, main.hud._activity_button.get_global_rect().get_center())
	await _settle(host)
	_check(not bool(world.workers[carrier].get("enabled", true)) and main.hud._activity_button.text == "Pokračovat v práci",
		"A dispatched mouse click must reach the actual HUD/main worker pause command", failures)
	_click(viewport, main.hud._activity_button.get_global_rect().get_center())
	await _settle(host)
	_check(bool(world.workers[carrier].get("enabled", false)), "A second real click must resume that same selected unit", failures)
	_center(main, viewport, world.buildings[f["home"]]["position"])
	await _settle(host)
	_click(viewport, Vector2(650, 390))
	await _settle(host)
	_check(main.selected_unit_id == 0 and world.building_id_at(main.selected_cell) == int(f["home"])
		and _on_screen(main.hud._activity_button, viewport),
		"A real building selection must replace the unit action with its own operation control", failures)
	_click(viewport, main.hud._activity_button.get_global_rect().get_center())
	await _settle(host)
	_check(not bool(world.buildings[f["home"]].get("enabled", true)) and main.hud._activity_button.text == "Obnovit provoz"
		and bool(world.workers[carrier].get("enabled", false)),
		"The building mouse action must pause its operation without pausing the formerly selected carrier", failures)
	viewport.free()


static func _test_narrow_inspector_scroll(host: Node, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var worker: Dictionary = world.workers[f["worker"]]
	worker["hunger"] = 0
	worker["nutrition_deficit_ticks"] = 39000
	world.set_building_enabled(f["home"], false)
	var attached: Dictionary = _attach(host, f)
	var main: Main = attached["main"]
	var viewport: SubViewport = attached["viewport"]
	main.selected_unit_id = f["worker"]
	main._update_ui()
	await _settle(host)
	var panel: Control = main.find_child("VillagePanel", true, false) as Control
	_check(_on_screen(main.hud._activity_button, viewport) and _on_screen(main.hud._thought_current, viewport)
		and _on_screen(main.hud._thought_next, viewport),
		"At 900px, work controls and current/next thoughts must be immediately readable before the longer nutrition details", failures)
	for control: Control in [main.hud._activity_button, main.hud._activity_status, main.hud._thought_current, main.hud._thought_next, main.hud._satiety_timing]:
		var rect: Rect2 = control.get_global_rect()
		_check(rect.position.x >= panel.get_global_rect().position.x and rect.end.x <= panel.get_global_rect().end.x + 1,
			"Czech inspector text and long nutrition warnings must wrap inside the existing sidebar, not expand it", failures)
	main.hud._inspector_scroll.ensure_control_visible(main.hud._satiety_timing)
	await _settle(host)
	# The warning has to be fully readable. Whether that needs scrolling depends
	# on how much of the sidebar the inspector gets, so the position reached is
	# the baseline rather than a required non-zero offset.
	var reached: int = main.hud._inspector_scroll.scroll_vertical
	_check(_on_screen(main.hud._satiety_timing, viewport),
		"The existing inspector scroll must make the complete critical nutrition warning reachable after adding thoughts", failures)
	main._update_ui()
	await _settle(host)
	_check(main.hud._inspector_scroll.scroll_vertical == reached and _on_screen(main.hud._satiety_timing, viewport),
		"Live thought refresh must preserve the player's scroll position for the same selected unit", failures)
	main.hud._inspector_scroll.ensure_control_visible(main.hud._activity_button)
	await _settle(host)
	_check(_on_screen(main.hud._activity_button, viewport), "The player must be able to scroll back to the entity pause button", failures)
	viewport.free()
