extends RefCounted

const MainViewClass = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 16 # Eight player flows at both supported window sizes.


# Exercise the rendered controls through viewport dispatch. In particular, the
# map-input check has a positive control on the same buildable tile, so a broken
# fixture cannot pass merely because neither mouse click reached the world.
static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for window_size: Vector2i in [Vector2i(1152, 720), Vector2i(1440, 900)]:
		var viewport := SubViewport.new()
		viewport.size = window_size
		viewport.world_2d = World2D.new()
		host.add_child(viewport)
		var main: MainViewClass = MainScene.instantiate() as MainViewClass
		main.demo_kind = "economy"
		viewport.add_child(main)
		main.set_process(false)
		main.world.economy_enabled = false
		main.camera.position_smoothing_enabled = false
		await _settle(host)
		var fixture_failures: Array[String] = []
		var required_nodes: Array[String] = [
			"OverviewBar", "VillagePanel", "BuildTab", "InspectTab", "BuildBody",
			"BuildingInspectorScroll", "StockpileToggle", "BuildCategory_food",
			"BuildCategory_infrastructure", "Build_field", "Build_road",
			"StockCategory_materials", "StockCategory_food", "StockCategory_military",
			"HelpToggle", "ControlsPanel", "CloseHelp", "CloseStockpile",
		]
		for node_name: String in required_nodes:
			_expect(_control(main, node_name) != null, "HUD must expose " + node_name, fixture_failures)
		if fixture_failures.is_empty():
			_check_layout(main, viewport, fixture_failures)
			await _check_stocks(host, main, viewport, fixture_failures)
			await _check_build_input(host, main, viewport, fixture_failures)
			await _check_school_inspection(host, main, viewport, fixture_failures)
			await _check_repeated_selection(host, main, viewport, fixture_failures)
			await _check_overlay_controls(host, main, viewport, fixture_failures)
			await _check_stable_build_list(host, main, viewport, fixture_failures)
			await _check_stock_panel_fit(host, main, viewport, fixture_failures)
		for failure: String in fixture_failures:
			failures.append("%d×%d: %s" % [window_size.x, window_size.y, failure])
		viewport.free()
	return failures


static func _check_layout(main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	var overview: Control = _control(main, "OverviewBar")
	var village: Control = _control(main, "VillagePanel")
	_expect(_fully_visible(overview, viewport), "Overview must fit inside the window", failures)
	_expect(_fully_visible(village, viewport), "Village panel must fit inside the window", failures)
	_expect(not overview.get_global_rect().intersects(village.get_global_rect()),
		"Overview and village controls must not overlap", failures)
	_expect(village.size.x < float(viewport.size.x) / 4.0,
		"Sidebar must leave at least three quarters of the width for the map", failures)
	_expect(_control(main, "BuildBody").is_visible_in_tree(), "New games should open the building menu", failures)
	_expect(not _control(main, "BuildingInspectorScroll").is_visible_in_tree(),
		"An empty inspector must not compete with the initial building menu", failures)
	_expect(not main.resource_hud_panel.is_visible_in_tree(), "Detailed stocks should be closed initially", failures)
	for button: Button in [_button(main, "Pauza"), _button(main, "0,5×"), _button(main, "1×"), _button(main, "2×")]:
		_expect(button != null and _fully_visible(button, viewport), "Every speed control must be fully visible", failures)
	var pause: Button = _button(main, "Pauza")
	if pause != null:
		_click(viewport, pause)
		_expect(main.simulation_speed == 0.0 and pause.button_pressed,
			"Pause click must stop time and visibly select Pause", failures)
	var normal: Button = _button(main, "1×")
	if normal != null:
		_click(viewport, normal)
		_expect(main.simulation_speed == 1.0 and normal.button_pressed,
			"Normal-speed click must resume time and visibly select 1×", failures)
		_expect(pause == null or not pause.button_pressed, "Resuming must remove the paused highlight", failures)


static func _check_stocks(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	_click(viewport, _control(main, "StockpileToggle"))
	await _settle(host)
	_expect(_fully_visible(main.resource_hud_panel, viewport), "All stocks must open a panel that fits the window", failures)
	_expect(not main.resource_hud_panel.get_global_rect().intersects(_control(main, "VillagePanel").get_global_rect()),
		"Stock details must leave village controls accessible", failures)
	var seen: Dictionary = {}
	for category: String in ["materials", "food", "military"]:
		var tab: Control = _control(main, "StockCategory_" + category)
		_expect(_fully_visible(tab, viewport), "Stock category " + category + " must be reachable", failures)
		_click(viewport, tab)
		await _settle(host)
		for resource_id: String in main.world.catalog.resources:
			var definition: Dictionary = main.world.catalog.resources[resource_id] as Dictionary
			if String(definition.get("category", "materials")) != category:
				continue
			var amount: Label = main.resource_amount_labels.get(resource_id) as Label
			var breakdown: Label = main.resource_breakdown_labels.get(resource_id) as Label
			if amount == null or breakdown == null:
				failures.append("Stock details omit " + resource_id)
				continue
			_expect(_fully_visible(amount, viewport) and _fully_visible(breakdown, viewport),
				"Opening " + category + " must make " + resource_id + " amounts readable without scrolling", failures)
			var stock: Dictionary = main.world.resource_stock(resource_id)
			_expect(amount.text == str(stock["total"]),
				"Total amount must match the world for " + resource_id, failures)
			_expect(breakdown.text == "Sklad %d · Budovy %d · Neseno %d" % [
				int(stock["warehouse"]), int(stock["buildings"]), int(stock["carried"]),
			], "Inventory locations must match the world for " + resource_id, failures)
			seen[resource_id] = true
	_expect(seen.size() == main.world.catalog.resources.size(), "All catalog resources must be reachable through stock tabs", failures)
	_click(viewport, _control(main, "StockpileToggle"))
	await _settle(host)
	_expect(not main.resource_hud_panel.is_visible_in_tree(), "All stocks must close again to uncover the map", failures)


static func _check_build_input(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	_click(viewport, _control(main, "BuildCategory_food"))
	await _settle(host)
	var field_button: Control = _control(main, "Build_field")
	_expect(_fully_visible(field_button, viewport), "Food tab must expose the wheat-field tool without scrolling", failures)
	_click(viewport, field_button)
	_expect(main.build_mode == "field" and (field_button as Button).button_pressed,
		"Clicking the wheat-field tool must select and highlight field placement", failures)
	var clear_cell: Vector2i = _clear_cell(main, "field")
	if clear_cell == Vector2i(-1, -1):
		failures.append("Map-input fixture requires clear, buildable ground")
		return
	var category: Control = _control(main, "BuildCategory_infrastructure")
	_center_cell_at(main, viewport, clear_cell, category.get_global_rect().get_center())
	await _settle(host)
	var previous_selection: Vector2i = main.selected_cell
	_click(viewport, category)
	await _settle(host)
	_expect(main.selected_cell == previous_selection and main.world.field_id_at(clear_cell) == 0,
		"Clicking HUD above valid ground must not select or build on the map underneath", failures)
	_expect(main.build_mode == "field", "Browsing building categories must not change the active placement tool", failures)
	var map_point := Vector2(float(viewport.size.x) * 0.72, float(viewport.size.y) * 0.60)
	_center_cell_at(main, viewport, clear_cell, map_point)
	await _settle(host)
	_click_position(viewport, map_point)
	_expect(main.world.field_id_at(clear_cell) != 0 and main.selected_cell == clear_cell,
		"The same valid tile must accept placement when clicked on the unobstructed map", failures)
	_click(viewport, _control(main, "BuildTab"))
	await _settle(host)
	_expect(main.build_mode.is_empty(), "Returning explicitly to Build must clear the old placement tool", failures)


static func _check_school_inspection(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	var school_cell: Vector2i = _clear_cell(main, "school")
	var school_id: int = main.world.place_building("school", school_cell)
	if school_id == 0:
		failures.append("Inspector fixture requires a completed school")
		return
	var map_point := Vector2(float(viewport.size.x) * 0.72, float(viewport.size.y) * 0.60)
	_center_cell_at(main, viewport, school_cell, map_point)
	await _settle(host)
	_click_position(viewport, map_point)
	await _settle(host)
	var inspector: Control = _control(main, "BuildingInspectorScroll")
	_expect(main.world.building_id_at(main.selected_cell) == school_id,
		"A map click must select the school", failures)
	_expect(inspector.is_visible_in_tree() and not _control(main, "BuildBody").is_visible_in_tree(),
		"Selecting a school must replace the build menu with its inspector", failures)
	var school: Dictionary = main.world.buildings[school_id] as Dictionary
	# Look the training actions up by node name: the visible label is localized.
	for profession: String in ["lumberjack", "carrier"]:
		var train: Button = _control(main, "Train_" + profession) as Button
		if train == null:
			failures.append("School must offer training for " + profession)
			continue
		_expect(_fully_visible(train, viewport),
			"First school actions must be fully visible without scrolling: " + profession, failures)
		_click(viewport, train)
	_expect((school["training_queue"] as Array) == ["lumberjack", "carrier"],
		"Visible school actions must enqueue the clicked citizens in order", failures)
	_key(viewport, KEY_1)
	await _settle(host)
	_expect(_control(main, "BuildBody").is_visible_in_tree() and not inspector.is_visible_in_tree(),
		"Selecting a different build tool must return from inspection to the building menu", failures)
	_expect(main.build_mode == "road" and (_control(main, "Build_road") as Button).button_pressed,
		"Keyboard-selected construction must have the same visible highlight as a clicked tool", failures)
	_click(viewport, _control(main, "InspectTab"))
	await _settle(host)
	_expect(inspector.is_visible_in_tree(), "Inspect tab must reopen the selected school's details", failures)
	_expect(_fully_visible(_control(main, "Train_carrier"), viewport),
		"Reopening inspection must retain usable first-row training actions", failures)


static func _check_repeated_selection(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	var school_cell: Vector2i = main.selected_cell
	var school_id: int = main.world.building_id_at(school_cell)
	if school_id == 0 or String((main.world.buildings[school_id] as Dictionary).get("type", "")) != "school":
		failures.append("Repeated-selection fixture requires the selected school")
		return
	var inspector: Control = _control(main, "BuildingInspectorScroll")
	var build: Control = _control(main, "BuildBody")
	var map_point := Vector2(float(viewport.size.x) * 0.72, float(viewport.size.y) * 0.60)
	_center_cell_at(main, viewport, school_cell, map_point)
	_click(viewport, _control(main, "BuildTab"))
	await _settle(host)
	_expect(build.is_visible_in_tree() and not inspector.is_visible_in_tree(),
		"Build tab must leave the selected school's inspector", failures)
	_click_position(viewport, map_point)
	await _settle(host)
	_expect(main.selected_cell == school_cell and inspector.is_visible_in_tree() and not build.is_visible_in_tree(),
		"Clicking the same school again must reopen Details even when selection coordinates are unchanged", failures)
	_key(viewport, KEY_1)
	await _settle(host)
	_click_position(viewport, map_point)
	await _settle(host)
	_expect(main.build_mode == "road" and inspector.is_visible_in_tree(),
		"Clicking an existing school while placing roads must inspect it without changing the active road tool", failures)
	_key(viewport, KEY_1)
	await _settle(host)
	_expect(main.build_mode == "road" and build.is_visible_in_tree() and not inspector.is_visible_in_tree(),
		"Repeating the active road shortcut must reopen Build after school inspection", failures)
	_click(viewport, _control(main, "BuildTab"))
	await _settle(host)


static func _check_overlay_controls(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	var help: Control = _control(main, "ControlsPanel")
	var help_toggle: Button = _control(main, "HelpToggle") as Button
	var stocks_toggle: Button = _control(main, "StockpileToggle") as Button
	_click(viewport, help_toggle)
	await _settle(host)
	_expect(help_toggle.button_pressed and _fully_visible(help, viewport),
		"Controls must open readable help within the window and highlight its toggle", failures)
	_click(viewport, _control(main, "CloseHelp"))
	await _settle(host)
	_expect(not help.is_visible_in_tree() and not help_toggle.button_pressed,
		"Closing help must hide it and reset the Controls toggle", failures)
	_click(viewport, stocks_toggle)
	await _settle(host)
	_click(viewport, help_toggle)
	await _settle(host)
	_expect(help.is_visible_in_tree() and help_toggle.button_pressed
		and not main.resource_hud_panel.is_visible_in_tree() and not stocks_toggle.button_pressed,
		"Opening Controls must close stocks and reset the stock toggle", failures)
	_click(viewport, stocks_toggle)
	await _settle(host)
	_expect(main.resource_hud_panel.is_visible_in_tree() and stocks_toggle.button_pressed
		and not help.is_visible_in_tree() and not help_toggle.button_pressed,
		"Opening stocks must close Controls and reset the help toggle", failures)
	_click(viewport, _control(main, "CloseStockpile"))
	await _settle(host)
	_expect(not main.resource_hud_panel.is_visible_in_tree() and not stocks_toggle.button_pressed,
		"The stock Close button must also reset its toolbar toggle", failures)
	_key(viewport, KEY_1)
	_click(viewport, help_toggle)
	await _settle(host)
	_key(viewport, KEY_ESCAPE)
	await _settle(host)
	_expect(not help.is_visible_in_tree() and not help_toggle.button_pressed and main.build_mode.is_empty(),
		"Escape from focused Controls must close help, reset its toggle and leave building mode", failures)
	_click(viewport, stocks_toggle)
	await _settle(host)
	_key(viewport, KEY_ESCAPE)
	await _settle(host)
	_expect(not main.resource_hud_panel.is_visible_in_tree() and not stocks_toggle.button_pressed,
		"Escape from focused All stocks must close its panel and reset its toggle", failures)


# Picking a tool used to add a preview line, a cost hint and a Cancel button to
# the same column, which collapsed the building list under the cursor and cut a
# row in half. The footer now reserves that space at all times.
static func _check_stable_build_list(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	_click(viewport, _control(main, "BuildTab"))
	await _settle(host)
	var list: Control = _control(main, "BuildingMenuScroll")
	var footer: Control = _control(main, "BuildFooter")
	if list == null or footer == null:
		failures.append("The build tab must expose its scrolling list and reserved footer")
		return
	var idle_rect: Rect2 = list.get_global_rect()
	var idle_footer: Rect2 = footer.get_global_rect()
	_click(viewport, _control(main, "Build_road"))
	await _settle(host)
	_expect(main.build_mode == "road", "Build-list stability fixture must actually enter placement mode", failures)
	_expect(list.get_global_rect().is_equal_approx(idle_rect),
		"Selecting a tool must not resize or move the building list", failures)
	_expect(footer.get_global_rect().is_equal_approx(idle_footer),
		"The active-tool footer must keep the same reserved rectangle when a tool is picked", failures)
	_expect(_control(main, "CancelBuild").is_visible_in_tree()
			and _fully_visible(_control(main, "CancelBuild"), viewport),
		"Placement mode must offer a fully visible way out inside that footer", failures)
	_click(viewport, _control(main, "CancelBuild"))
	await _settle(host)
	_expect(main.build_mode.is_empty() and list.get_global_rect().is_equal_approx(idle_rect),
		"Leaving placement must restore the same list rectangle", failures)


# The stock overlay used to reserve a fixed height, so Materials left a third of
# the panel blank. Its height follows the open category instead.
static func _check_stock_panel_fit(host: Node, main: MainViewClass, viewport: SubViewport, failures: Array[String]) -> void:
	_click(viewport, _control(main, "StockpileToggle"))
	await _settle(host)
	await _settle(host)
	var heights: Dictionary = {}
	for category: String in ["materials", "food", "military"]:
		_click(viewport, _control(main, "StockCategory_" + category))
		await _settle(host)
		await _settle(host)
		heights[category] = main.resource_hud_panel.get_global_rect().size.y
		_expect(_fully_visible(main.resource_hud_panel, viewport),
			"The stock panel must stay inside the window for " + category, failures)
	_expect(float(heights["materials"]) < float(heights["military"]),
		"A category with fewer wares must produce a shorter panel than the tallest one", failures)
	_expect(float(heights["materials"]) > 0.0 and float(heights["military"]) < float(viewport.size.y),
		"The fitted panel must stay between a usable minimum and the window height", failures)
	_click(viewport, _control(main, "StockpileToggle"))
	await _settle(host)


static func _clear_cell(main: MainViewClass, kind: String) -> Vector2i:
	for y: int in range(main.world.grid.size.y):
		for x: int in range(main.world.grid.size.x):
			var cell := Vector2i(x, y)
			if main.world.can_place_field(cell) if kind == "field" else main.world.can_place_building(kind, cell):
				return cell
	return Vector2i(-1, -1)


static func _center_cell_at(main: MainViewClass, viewport: SubViewport, cell: Vector2i, screen: Vector2) -> void:
	main.camera.zoom = Vector2.ONE
	var position: Vector2 = main.terrain_renderer.to_global(main.terrain_renderer.cell_center(cell))
	main.camera.position = position - (screen - Vector2(viewport.size) * 0.5)
	main.camera.force_update_scroll()


static func _control(main: MainViewClass, node_name: String) -> Control:
	return main.find_child(node_name, true, false) as Control


static func _button(main: MainViewClass, button_text: String) -> Button:
	for node: Node in main.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == button_text:
			return button
	return null


static func _fully_visible(control: Control, viewport: SubViewport) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(1.0).encloses(rect):
		return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and (ancestor as Control).clip_contents:
			if not (ancestor as Control).get_global_rect().grow(1.0).encloses(rect):
				return false
		ancestor = ancestor.get_parent()
	return true


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


static func _click(viewport: Viewport, control: Control) -> void:
	_click_position(viewport, control.get_global_rect().get_center())


static func _click_position(viewport: Viewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		viewport.push_input(event, true)


static func _key(viewport: Viewport, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

