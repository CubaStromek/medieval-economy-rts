class_name GameHud
extends CanvasLayer

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const ResourceIconClass = preload("res://scripts/view/resource_icon.gd")
const EconomyActionsClass = preload("res://scripts/view/economy_actions.gd")
const WorkplacesClass = preload("res://scripts/simulation/workplaces.gd")
const DayCycleClass = preload("res://scripts/simulation/day_cycle.gd")
const SkyClockClass = preload("res://scripts/view/sky_clock.gd")

const CATEGORIES: Array[String] = ["infrastructure", "food", "mining", "military"]
const CATEGORY_NAMES: Array[String] = ["Infrastructure", "Food", "Mining", "Military"]
const STOCK_CATEGORIES: Array[String] = ["materials", "food", "military"]
const SUMMARY_RESOURCES: Array[String] = ["log", "plank", "stone", "bread", "gold"]
const MAP_LEFT: float = 364.0
const MAP_TOP: float = 102.0
const MAP_BOTTOM: float = 100.0
const INK := Color("#e9e9dc")
const MUTED := Color("#a0aba4")
const ACCENT := Color("#d9bd77")

signal terrain_rules_requested(enabled: bool)
signal build_mode_requested(mode: String)
signal simulation_speed_requested(speed: float)
signal unit_training_requested(unit_type: String)
signal production_order_requested(recipe_id: String)
signal recruitment_requested(soldier_type: String)
signal trade_requested(give_resource: String, receive_resource: String)
signal construction_cancel_requested()
signal soldier_food_requested(unit_id: int)
signal army_food_requested()
signal main_menu_requested()
signal entity_enabled_requested(entity_type: String, entity_id: int, enabled: bool)

var resource_hud_panel: PanelContainer
var resource_amount_labels: Dictionary = {}
var resource_breakdown_labels: Dictionary = {}
var building_inventory_label: Label
var placement_preview_label: Label
var _placement_preview_color: Color = Color.TRANSPARENT
var production_detail_label: Label
var training_panel: VBoxContainer
var mode_label: Label
var event_label: Label

var _catalog: DefinitionCatalogClass
var _include_main_menu: bool = false
var _root: Control
var _build_groups: Dictionary = {}
var _resource_items: Dictionary = {}
var _summary_amounts: Dictionary = {}
var _summary_items: Dictionary = {}
var _build_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _category_buttons: Array[Button] = []
var _stock_buttons: Array[Button] = []
var _actions: EconomyActionsClass
var _inspector_scroll: ScrollContainer
var _build_scroll: ScrollContainer
var _stock_scroll: ScrollContainer
var _build_body: VBoxContainer
var _build_tab: Button
var _inspect_tab: Button
var _stock_toggle: Button
var _selection_hint: Label
var _empty_selection: VBoxContainer
var _build_hint: Label
var _cancel_build: Button
var _construction_panel: VBoxContainer
var _soldier_food_panel: VBoxContainer
var _soldier_food_button: Button
var _supply_army_button: Button
var _satiety_panel: VBoxContainer
var _satiety_label: Label
var _satiety_bar: ProgressBar
var _satiety_timing: Label
var _satiety_fill: StyleBoxFlat
var _activity_panel: VBoxContainer
var _activity_button: Button
var _activity_status: Label
var _activity_target_type: String = ""
var _activity_target_id: int = 0
var _activity_next_enabled: bool = true
var _thoughts_panel: VBoxContainer
var _thought_current: Label
var _thought_next: Label
var _selected_unit_id: int = 0
var _last_unit_selection: int = 0
var _clock_label: Label
var _sky_clock: SkyClockClass
var _citizens_label: Label
var _help_panel: PanelContainer
var _help_button: Button
var _terrain_button: Button
var _last_selection: Vector2i = Vector2i(-999, -999)
var _last_build_mode: String = ""


func configure(catalog: DefinitionCatalogClass, include_main_menu: bool = false) -> void:
	_catalog = catalog
	_include_main_menu = include_main_menu
	name = "HudLayer"
	_build_ui()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only the actual panels block map input.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _hud_theme()
	add_child(_root)
	_build_overview()
	_build_dock()
	_build_status_bar()
	_build_sky_clock()
	_build_resource_hud()
	_build_help()
	resource_hud_panel.visibility_changed.connect(_update_sky_visibility)
	_help_panel.visibility_changed.connect(_update_sky_visibility)
	_update_sky_visibility()


func _build_sky_clock() -> void:
	_sky_clock = SkyClockClass.new()
	_root.add_child(_sky_clock)
	_sky_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_sky_clock.offset_left = -196.0
	_sky_clock.offset_right = -12.0
	_sky_clock.offset_top = MAP_TOP
	_sky_clock.offset_bottom = MAP_TOP + 86.0


func update_sky_time(tick: int, fraction: float = 0.0) -> void:
	_sky_clock.set_time(tick, fraction)


func _update_sky_visibility() -> void:
	_sky_clock.visible = not resource_hud_panel.visible and not _help_panel.visible


func _build_overview() -> void:
	var panel: PanelContainer = _panel("OverviewBar", Control.PRESET_TOP_WIDE, Rect2(12, 12, -24, 78))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_margin(panel, 14, 10).add_child(row)
	var brand := VBoxContainer.new()
	brand.custom_minimum_size.x = 158
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(brand)
	_text_label(brand, "MEDIEVAL ECONOMY", 14, ACCENT)
	_text_label(brand, "Settlement overview", 11, MUTED)
	row.add_child(VSeparator.new())
	for resource_id: String in SUMMARY_RESOURCES:
		_resource_tile(row, resource_id, true)
	_stock_toggle = _button(row, "All stocks", "StockpileToggle")
	_stock_toggle.custom_minimum_size = Vector2(100, 36)
	_stock_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	_stock_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stock_toggle.toggle_mode = true
	_stock_toggle.tooltip_text = "Show every material, food and equipment stock."
	_stock_toggle.toggled.connect(func(opened: bool) -> void:
		resource_hud_panel.visible = opened
		if opened:
			_close_help()
	)


func _build_dock() -> void:
	var panel: PanelContainer = _panel("VillagePanel", Control.PRESET_LEFT_WIDE, Rect2(12, MAP_TOP, 340, -MAP_TOP - 66))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin(panel, 12, 12).add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	_build_tab = _button(tabs, "Build", "BuildTab")
	_inspect_tab = _button(tabs, "Details", "InspectTab")
	_build_tab.toggle_mode = true
	_inspect_tab.toggle_mode = true
	_build_tab.pressed.connect(func() -> void:
		build_mode_requested.emit("")
		_show_dock(false)
	)
	_inspect_tab.pressed.connect(func() -> void:
		build_mode_requested.emit("")
		_show_dock(true)
	)
	placement_preview_label = _text_label(column, "", 13)
	placement_preview_label.name = "PlacementPreviewLabel"
	placement_preview_label.custom_minimum_size.y = 44
	placement_preview_label.visible = false
	_build_body = VBoxContainer.new()
	_build_body.name = "BuildBody"
	_build_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_body.add_theme_constant_override("separation", 10)
	column.add_child(_build_body)
	_text_label(_build_body, "BUILD YOUR SETTLEMENT", 11, ACCENT)
	var categories := GridContainer.new()
	categories.columns = 2
	categories.add_theme_constant_override("h_separation", 6)
	categories.add_theme_constant_override("v_separation", 6)
	_build_body.add_child(categories)
	for index: int in range(CATEGORIES.size()):
		var button: Button = _button(categories, CATEGORY_NAMES[index], "BuildCategory_" + CATEGORIES[index])
		button.toggle_mode = true
		button.custom_minimum_size.y = 30
		button.pressed.connect(_show_build_category.bind(index))
		_category_buttons.append(button)
	_build_scroll = ScrollContainer.new()
	_build_scroll.name = "BuildingMenuScroll"
	_build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_body.add_child(_build_scroll)
	var build_column := VBoxContainer.new()
	build_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_scroll.add_child(build_column)
	for category: String in CATEGORIES:
		var grid := GridContainer.new()
		grid.name = "BuildingTools" if category == "infrastructure" else category.capitalize() + "BuildingTools"
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		build_column.add_child(grid)
		_build_groups[category] = grid
	_add_tool_button(_build_groups["infrastructure"] as Control, "1  Stone road", "road")
	_add_tool_button(_build_groups["food"] as Control, "0  Wheat field", "field")
	_add_tool_button(_build_groups["food"] as Control, "Vine field", "vine_field")
	var shortcut_labels: Dictionary = {
		"warehouse": "2  Warehouse", "lumber_hut": "3  Lumberjack Hut", "sawmill": "4  Sawmill",
		"school": "5  School", "quarry": "6  Quarry", "farm": "7  Farm",
		"mill": "8  Mill", "bakery": "9  Bakery",
	}
	for building_type: String in _catalog.buildings:
		var definition: Dictionary = _catalog.building(building_type)
		var category: String = String(definition.get("category", "infrastructure"))
		if not _build_groups.has(category):
			category = "infrastructure"
		_add_tool_button(_build_groups[category] as Control,
			String(shortcut_labels.get(building_type, definition.get("display_name", building_type.capitalize()))), building_type)
	_supply_army_button = _button(_build_groups["military"] as Control, "Supply army", "SupplyArmy")
	_supply_army_button.custom_minimum_size.y = 44
	_supply_army_button.tooltip_text = "Request a carried food ration for every soldier below the feeding threshold. Select a soldier on the map to supply one unit."
	_supply_army_button.pressed.connect(army_food_requested.emit)
	_build_hint = _text_label(_build_body, "", 12, MUTED)
	_build_hint.custom_minimum_size.y = 64
	_show_build_category(0)

	_inspector_scroll = ScrollContainer.new()
	_inspector_scroll.name = "BuildingInspectorScroll"
	_inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_inspector_scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 12)
	_inspector_scroll.add_child(inspector)
	_selection_hint = _text_label(inspector, "SELECTION", 11, ACCENT)
	_empty_selection = VBoxContainer.new()
	_empty_selection.add_theme_constant_override("separation", 12)
	inspector.add_child(_empty_selection)
	_text_label(_empty_selection, "Select something on the map", 20)
	_text_label(_empty_selection, "Click a building to see its supplies, workers and available actions.\n\nBars above people show satiety. Click a person for details; select a soldier to request food.\n\nFields show crop growth. Deposits show remaining resources.", 13, MUTED)
	_text_label(_empty_selection, "Need more citizens?\nSelect a School to train them.", 13, ACCENT)
	building_inventory_label = _text_label(inspector, "", 14)
	building_inventory_label.name = "BuildingInventoryLabel"
	_activity_panel = VBoxContainer.new()
	_activity_panel.name = "EntityActivityPanel"
	_activity_panel.add_theme_constant_override("separation", 5)
	inspector.add_child(_activity_panel)
	_activity_button = _button(_activity_panel, "", "ToggleEntityActivity")
	_activity_button.custom_minimum_size.y = 38
	_activity_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_button.pressed.connect(_request_activity_change)
	_activity_status = _text_label(_activity_panel, "", 12, MUTED)
	_activity_status.name = "EntityActivityStatus"
	_activity_panel.visible = false
	_thoughts_panel = VBoxContainer.new()
	_thoughts_panel.name = "UnitThoughtsPanel"
	_thoughts_panel.add_theme_constant_override("separation", 5)
	inspector.add_child(_thoughts_panel)
	_text_label(_thoughts_panel, "Co si myslím", 13, ACCENT)
	_thought_current = _text_label(_thoughts_panel, "", 12, INK)
	_thought_current.name = "UnitThoughtCurrent"
	_thought_next = _text_label(_thoughts_panel, "", 12, MUTED)
	_thought_next.name = "UnitThoughtNext"
	_thoughts_panel.visible = false
	_satiety_panel = VBoxContainer.new()
	_satiety_panel.name = "UnitSatietyPanel"
	_satiety_panel.add_theme_constant_override("separation", 5)
	inspector.add_child(_satiety_panel)
	_satiety_label = _text_label(_satiety_panel, "", 14, ACCENT)
	_satiety_label.name = "UnitSatietyLabel"
	_satiety_bar = ProgressBar.new()
	_satiety_bar.name = "UnitSatietyBar"
	_satiety_bar.min_value = 0.0
	_satiety_bar.max_value = 100.0
	_satiety_bar.step = 0.0
	_satiety_bar.show_percentage = false
	_satiety_bar.custom_minimum_size.y = 10
	_satiety_bar.add_theme_stylebox_override("background", _surface(Color("#101917"), Color("#435449")))
	_satiety_fill = StyleBoxFlat.new()
	_satiety_fill.bg_color = Color("#92bd6b")
	_satiety_fill.set_corner_radius_all(3)
	_satiety_bar.add_theme_stylebox_override("fill", _satiety_fill)
	_satiety_panel.add_child(_satiety_bar)
	_text_label(_satiety_panel, "0% empty · 100% full", 10, MUTED)
	_satiety_timing = _text_label(_satiety_panel, "", 12, MUTED)
	_satiety_timing.name = "UnitSatietyTiming"
	_satiety_timing.mouse_filter = Control.MOUSE_FILTER_PASS
	_satiety_panel.visible = false
	_construction_panel = VBoxContainer.new()
	_construction_panel.name = "ConstructionActions"
	_construction_panel.add_theme_constant_override("separation", 6)
	inspector.add_child(_construction_panel)
	var cancel_site: Button = _button(_construction_panel, "Cancel construction", "CancelConstruction")
	cancel_site.custom_minimum_size.y = 38
	cancel_site.add_theme_color_override("font_color", Color("#f0b49b"))
	cancel_site.tooltip_text = "Remove this unfinished building. Delivered materials return to a reachable warehouse; carriers keep and redirect their cargo."
	cancel_site.pressed.connect(construction_cancel_requested.emit)
	_text_label(_construction_panel, "Removes this site and returns delivered materials to storage. Already moved soil stays changed.", 11, MUTED)
	_construction_panel.visible = false
	production_detail_label = _text_label(inspector, "", 12, MUTED)
	production_detail_label.name = "ProductionDetailLabel"
	_soldier_food_panel = VBoxContainer.new()
	_soldier_food_panel.name = "SoldierFoodActions"
	inspector.add_child(_soldier_food_panel)
	_soldier_food_button = _button(_soldier_food_panel, "Supply food", "SupplySoldierFood")
	_soldier_food_button.custom_minimum_size.y = 40
	_soldier_food_button.pressed.connect(func() -> void: soldier_food_requested.emit(_selected_unit_id))
	_soldier_food_panel.visible = false
	_actions = EconomyActionsClass.new()
	inspector.add_child(_actions)
	_actions.configure(_catalog)
	_actions.unit_training_requested.connect(unit_training_requested.emit)
	_actions.production_order_requested.connect(production_order_requested.emit)
	_actions.recruitment_requested.connect(recruitment_requested.emit)
	_actions.trade_requested.connect(trade_requested.emit)
	training_panel = _actions.training_panel
	column.add_child(HSeparator.new())
	mode_label = _text_label(column, "Select / explore", 13, ACCENT)
	mode_label.name = "ActiveToolLabel"
	_cancel_build = _button(column, "Stop placing  ·  Esc", "CancelBuild")
	_cancel_build.tooltip_text = "Leave placement mode. To remove an existing unfinished building, select it and choose Cancel construction in Details."
	_cancel_build.pressed.connect(build_mode_requested.emit.bind(""))
	_cancel_build.visible = false
	_show_dock(false)


func _build_status_bar() -> void:
	var panel: PanelContainer = _panel("StatusBar", Control.PRESET_BOTTOM_WIDE, Rect2(12, -54, -24, 42))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_margin(panel, 12, 5).add_child(row)
	_clock_label = _text_label(row, "Day 1 · 05:00 · Dawn", 14, ACCENT)
	_clock_label.name = "DayClockLabel"
	_clock_label.custom_minimum_size.x = 210
	_clock_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(VSeparator.new())
	_citizens_label = _text_label(row, "", 12, MUTED)
	_citizens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_citizens_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_citizens_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(VSeparator.new())
	_text_label(row, "TIME", 10, MUTED)
	_add_speed_button(row, "Pause", 0.0)
	_add_speed_button(row, "0.5×", 0.5)
	_add_speed_button(row, "1×", 1.0)
	_add_speed_button(row, "2×", 2.0)
	_terrain_button = _button(row, "Terrain", "TerrainOverlayToggle")
	_terrain_button.toggle_mode = true
	_terrain_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_terrain_button.tooltip_text = "Show terrain rules (F2): green level, amber slope, red blocked"
	_terrain_button.toggled.connect(func(enabled: bool) -> void: terrain_rules_requested.emit(enabled))
	_help_button = _button(row, "Controls", "HelpToggle")
	_help_button.toggle_mode = true
	_help_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_help_button.toggled.connect(func(opened: bool) -> void:
		_help_panel.visible = opened
		if opened:
			_close_stocks()
	)
	if _include_main_menu:
		var menu_button: Button = _button(row, "Menu", "MenuButton")
		menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		menu_button.tooltip_text = "Hlavní menu (Esc)"
		menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	var events: PanelContainer = _panel("ActivityPanel", Control.PRESET_BOTTOM_WIDE, Rect2(MAP_LEFT, -96, -MAP_LEFT - 12, 30))
	events.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var event_row := HBoxContainer.new()
	event_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin(events, 10, 5).add_child(event_row)
	_text_label(event_row, "LATEST", 10, ACCENT)
	event_label = _text_label(event_row, "", 11, MUTED)
	event_label.name = "EventLabel"
	event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	event_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_resource_hud() -> void:
	resource_hud_panel = _panel("ResourceStatusBar", Control.PRESET_TOP_WIDE, Rect2(MAP_LEFT, MAP_TOP, -MAP_LEFT - 12, 480))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin(resource_hud_panel, 16, 14).add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = _text_label(header, "All stockpiles", 20, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button: Button = _button(header, "Close", "CloseStockpile")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_close_stocks)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	var names: Array[String] = ["Materials", "Food", "Equipment"]
	for index: int in range(STOCK_CATEGORIES.size()):
		var button: Button = _button(tabs, names[index], "StockCategory_" + STOCK_CATEGORIES[index])
		button.toggle_mode = true
		button.pressed.connect(_show_resource_category.bind(index))
		_stock_buttons.append(button)
	_text_label(column, "Total stock = warehouses + buildings + carried wares. Roads and vine fields spend warehouse stock.", 11, MUTED)
	_stock_scroll = ScrollContainer.new()
	_stock_scroll.name = "StockpileScroll"
	_stock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_stock_scroll)
	var items := GridContainer.new()
	items.name = "ResourceItems"
	# Keep all 13 equipment wares within three rows at the minimum window size.
	items.columns = 5
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("h_separation", 8)
	items.add_theme_constant_override("v_separation", 12)
	_stock_scroll.add_child(items)
	for resource_id: String in _hud_resource_ids():
		_resource_tile(items, resource_id, false)
	_show_resource_category(0)
	resource_hud_panel.visible = false


func _build_help() -> void:
	_help_panel = _panel("ControlsPanel", Control.PRESET_BOTTOM_RIGHT, Rect2(-420, -332, 408, 268))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_margin(_help_panel, 18, 16).add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = _text_label(header, "Controls", 20, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button: Button = _button(header, "Close", "CloseHelp")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_close_help)
	var shortcuts := GridContainer.new()
	shortcuts.columns = 2
	shortcuts.add_theme_constant_override("h_separation", 16)
	shortcuts.add_theme_constant_override("v_separation", 7)
	column.add_child(shortcuts)
	var entries: Array[Array] = [
		["Left click", "Select a unit or building / place"],
		["Esc", "Stop placing / close panels / menu"],
		["MMB / WASD / arrows", "Move camera"],
		["Mouse wheel", "Zoom"], ["Space", "Pause / resume"],
		["1–9, 0", "Building shortcuts"], ["F5 / F9", "Save / load"],
		["F2 / R", "Terrain rules / reset demo"],
	]
	for entry: Array in entries:
		var key_label: Label = _text_label(shortcuts, String(entry[0]), 12, ACCENT)
		key_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var action_label: Label = _text_label(shortcuts, String(entry[1]), 12)
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help_panel.visible = false


func has_open_overlay() -> bool:
	return resource_hud_panel.visible or _help_panel.visible


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if resource_hud_panel.visible or _help_panel.visible:
			_close_stocks()
			_close_help()
			build_mode_requested.emit("")
			get_viewport().set_input_as_handled()


func _show_dock(inspect: bool) -> void:
	_build_body.visible = not inspect
	_inspector_scroll.visible = inspect
	_build_tab.set_pressed_no_signal(not inspect)
	_inspect_tab.set_pressed_no_signal(inspect)


func inspect_selection() -> void:
	# A repeated click is still a selection intent, even on the same tile.
	if building_inventory_label.visible:
		_show_dock(true)


func show_build_tool(mode: String) -> void:
	if mode.is_empty():
		return
	var category: String = "food" if mode in ["field", "vine_field"] else String(_catalog.building(mode).get("category", "infrastructure"))
	var index: int = CATEGORIES.find(category)
	if index >= 0:
		_show_build_category(index)
	_show_dock(false)
	_reveal_build_button.call_deferred(mode)


func _reveal_build_button(mode: String) -> void:
	# Let containers resize for the placement hint and Cancel button first.
	await get_tree().process_frame
	if _build_body.visible and _build_buttons.has(mode):
		_build_scroll.ensure_control_visible(_build_buttons[mode] as Control)


func _show_build_category(index: int) -> void:
	for category: String in _build_groups:
		(_build_groups[category] as Control).visible = category == CATEGORIES[index]
	for button_index: int in range(_category_buttons.size()):
		_category_buttons[button_index].set_pressed_no_signal(button_index == index)
	_build_scroll.scroll_vertical = 0


func _show_resource_category(index: int) -> void:
	for resource_id: String in _resource_items:
		var category: String = String((_catalog.resources[resource_id] as Dictionary).get("category", "materials"))
		(_resource_items[resource_id] as Control).visible = category == STOCK_CATEGORIES[index]
	for button_index: int in range(_stock_buttons.size()):
		_stock_buttons[button_index].set_pressed_no_signal(button_index == index)
	_stock_scroll.scroll_vertical = 0


func _close_stocks() -> void:
	resource_hud_panel.visible = false
	_stock_toggle.set_pressed_no_signal(false)


func _close_help() -> void:
	_help_panel.visible = false
	_help_button.set_pressed_no_signal(false)


func _resource_tile(parent: Control, resource_id: String, summary: bool) -> void:
	var definition: Dictionary = _catalog.resources.get(resource_id, {}) as Dictionary
	var display_name: String = String(definition.get("display_name", resource_id.capitalize()))
	var icon_color := Color.from_string("#" + String(definition.get("color", "888888")), Color.GRAY)
	var item := HBoxContainer.new()
	item.name = ("Summary_" if summary else "Stock_") + resource_id
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 6)
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.tooltip_text = "%s: total stock across the settlement." % display_name
	parent.add_child(item)
	var icon: ResourceIconClass = ResourceIconClass.new()
	icon.configure(resource_id, icon_color)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	item.add_child(column)
	var title: Label = _text_label(column, display_name, 11, MUTED)
	title.custom_minimum_size.x = 55
	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 5)
	column.add_child(values)
	var amount: Label = _text_label(values, "0", 20)
	amount.name = display_name.replace(" ", "") + "TotalAmount"
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text_label(values, "total", 11, ACCENT)
	if summary:
		_summary_amounts[resource_id] = amount
		_summary_items[resource_id] = item
	else:
		var breakdown: Label = _text_label(column, "Warehouse: 0\nBuildings: 0\nCarried: 0", 11, MUTED)
		breakdown.name = display_name.replace(" ", "") + "StockBreakdown"
		breakdown.autowrap_mode = TextServer.AUTOWRAP_OFF
		_resource_items[resource_id] = item
		resource_amount_labels[resource_id] = amount
		resource_breakdown_labels[resource_id] = breakdown


func _hud_resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for resource_id: String in _catalog.resources:
		ids.append(resource_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(_catalog.resources[a].get("hud_order", 1000)) < int(_catalog.resources[b].get("hud_order", 1000))
	)
	return ids


func _add_tool_button(parent: Control, text_value: String, mode: String) -> void:
	var button: Button = _button(parent, text_value, "Build_" + mode)
	button.custom_minimum_size.y = 44
	button.toggle_mode = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var definition: Dictionary = _catalog.building(mode)
	var display_name: String = String(definition.get("display_name", text_value))
	button.tooltip_text = display_name + "\n" + _build_mode_hint(mode)
	var cost: Dictionary = _build_cost(mode)
	if not cost.is_empty():
		button.tooltip_text += "\nConstruction: " + _resource_amounts_text(cost)
	button.pressed.connect(build_mode_requested.emit.bind(mode))
	_build_buttons[mode] = button


func _build_cost(mode: String) -> Dictionary:
	if mode == "road":
		return _catalog.economy.get("road_cost", {}) as Dictionary
	if mode == "vine_field":
		return _catalog.economy.get("vine_field_cost", {}) as Dictionary
	return _catalog.building(mode).get("construction_cost", {}) as Dictionary


func _add_speed_button(parent: Control, text_value: String, speed: float) -> void:
	var button: Button = _button(parent, text_value, "Speed_" + str(speed))
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(42, 30)
	button.toggle_mode = true
	button.pressed.connect(simulation_speed_requested.emit.bind(speed))
	_speed_buttons[speed] = button


func refresh(world: SimulationWorldClass, selected_cell: Vector2i, build_mode: String, simulation_speed: float, tick_seconds: float, selected_unit_id: int = 0) -> void:
	if resource_hud_panel == null:
		return
	update_sky_time(world.tick)
	var stocks: Dictionary = world.resource_stocks()
	for resource_id: String in resource_amount_labels:
		var stock: Dictionary = stocks[resource_id]
		var total: String = str(stock["total"])
		var breakdown: String = "Warehouse: %d\nBuildings: %d\nCarried: %d" % [
			stock["warehouse"], stock["buildings"], stock["carried"],
		]
		var display_name: String = String(_catalog.resources[resource_id].get("display_name", resource_id))
		var tooltip: String = "%s — total: %s\n%s\nRoads and vine fields spend warehouse stock.\nConsumed materials are no longer included." % [display_name, total, breakdown]
		(resource_amount_labels[resource_id] as Label).text = total
		(resource_breakdown_labels[resource_id] as Label).text = breakdown
		(_resource_items[resource_id] as Control).tooltip_text = tooltip
		if _summary_amounts.has(resource_id):
			(_summary_amounts[resource_id] as Label).text = total
			(_summary_items[resource_id] as Control).tooltip_text = tooltip
	var selected_unit: Dictionary = world.workers.get(selected_unit_id, {}) as Dictionary
	if not selected_unit.is_empty() and not can_inspect_worker(world, selected_unit):
		selected_unit = {}
	if selected_unit_id != 0 and selected_unit.is_empty():
		selected_cell = Vector2i(-1, -1) # A hidden unit must not select the building under its feet.
	_selected_unit_id = selected_unit_id if not selected_unit.is_empty() else 0
	_refresh_satiety_panel(world, selected_unit, simulation_speed, tick_seconds)
	var inventory_text: String = _selected_building_inventory_text(world, selected_cell) if selected_unit.is_empty() else _unit_inventory_text(selected_unit)
	building_inventory_label.text = inventory_text
	building_inventory_label.visible = not inventory_text.is_empty()
	production_detail_label.text = _selected_production_text(world, selected_cell) if selected_unit.is_empty() else _unit_detail_text(world, selected_unit)
	production_detail_label.visible = not production_detail_label.text.is_empty()
	var building_id: int = world.building_id_at(selected_cell) if selected_unit.is_empty() else 0
	var selected_building: Dictionary = world.buildings.get(building_id, {}) as Dictionary
	if not selected_building.is_empty() and world.fog.enabled \
			and (not world.is_cell_explored(selected_cell) or not world.is_local_entity(selected_building)):
		selected_building = {}
	_refresh_activity_panel(world, selected_unit, selected_building)
	_refresh_unit_thoughts(world, selected_unit)
	_construction_panel.visible = int(selected_building.get("construction_remaining", 0)) > 0
	_actions.refresh(world, selected_building)
	_actions.visible = not _construction_panel.visible and selected_unit.is_empty() \
		and (not world.fog.enabled or not selected_building.is_empty())
	_soldier_food_panel.visible = not selected_unit.is_empty() and _catalog.soldiers.has(String(selected_unit["type"]))
	_soldier_food_button.disabled = not world.economy_enabled or selected_unit.is_empty() or not _can_request_soldier_food(selected_unit)
	_soldier_food_button.tooltip_text = "Below %.0f%% satiety, request one Bread, Sausage, Wine or Fish. A carrier brings it from a warehouse or producer and restores full satiety. The soldier stays at its post." % _soldier_feeding_percent()
	_selection_hint.text = "UNIT DETAILS" if not selected_unit.is_empty() else ("BUILDING DETAILS" if building_id != 0 else "LAND DETAILS")
	_empty_selection.visible = inventory_text.is_empty()
	if (_selected_unit_id == 0 and selected_cell != _last_selection) or _last_unit_selection != _selected_unit_id:
		_last_selection = selected_cell
		_last_unit_selection = _selected_unit_id
		_inspector_scroll.scroll_vertical = 0
		if not inventory_text.is_empty():
			_show_dock(true)
	if build_mode != _last_build_mode:
		_last_build_mode = build_mode
		show_build_tool(build_mode)
	for mode: String in _build_buttons:
		(_build_buttons[mode] as Button).set_pressed_no_signal(mode == build_mode)
	for speed: float in _speed_buttons:
		(_speed_buttons[speed] as Button).set_pressed_no_signal(is_equal_approx(speed, simulation_speed))
	var fallback_name: String = "Wheat field" if build_mode == "field" else ("Vine field" if build_mode == "vine_field" else "Stone road")
	mode_label.text = "Select / explore" if build_mode.is_empty() else "Placing: " + String(_catalog.building(build_mode).get("display_name", fallback_name))
	_cancel_build.visible = not build_mode.is_empty()
	var cost: Dictionary = _build_cost(build_mode)
	_build_hint.text = "Build on level ground, including plateaus.\nTerrain (F2) shows slopes and blocked mountains." if build_mode.is_empty() else _build_mode_hint(build_mode)
	if not cost.is_empty():
		_build_hint.text = "Cost: " + _resource_amounts_text(cost) + "\n" + _build_hint.text
	var calendar: Dictionary = world.calendar_time()
	_clock_label.text = "Day %d · %02d:%02d · %s" % [
		int(calendar["day"]), int(calendar["hour"]), int(calendar["minute"]), String(calendar["phase"]).capitalize(),
	]
	var seconds: int = int(float(world.tick) * tick_seconds)
	var cycle_minutes: float = float(DayCycleClass.TICKS_PER_DAY) * DayCycleClass.TICK_SECONDS / 60.0
	_clock_label.tooltip_text = "%s\nFull day/night cycle: %.0f minutes at 1×.\n%s\nElapsed simulation time: %02d:%02d:%02d" % [
		_clock_label.text, cycle_minutes,
		"Simulation paused" if is_zero_approx(simulation_speed) else "Simulation speed: %.1f×" % simulation_speed,
		seconds / 3600, (seconds / 60) % 60, seconds % 60,
	]
	_clock_label.tooltip_text += "\nCivilian work: 05:00–20:00. Sleep: 20:00–05:00.\nSpecialists sleep at their workplace; carriers and builders use assigned Workers' Cottages, with warehouses as overflow shelter.\nSoldiers and guards stay active at night."
	var counts: Dictionary = _food_summary(world)
	_citizens_label.text = "%d citizens · %d soldiers" % [counts["citizens"], counts["soldiers"]]
	_citizens_label.tooltip_text = _worker_summary_text(world, counts)
	var sleeping: int = int(counts["sleeping"])
	if sleeping > 0:
		_citizens_label.text += " · %d sleeping" % sleeping
	var hungry: int = int(counts["hungry"])
	if hungry > 0:
		_citizens_label.text += "  ·  %d hungry" % hungry
	if int(counts["arriving"]) > 0:
		_citizens_label.text += " · %d food arriving" % int(counts["arriving"])
	_citizens_label.add_theme_color_override("font_color", Color("#edb27d") if hungry > 0 else MUTED)
	_supply_army_button.disabled = not world.economy_enabled or int(counts["eligible"]) == 0
	event_label.text = "" if world.event_log.is_empty() else String(world.event_log.front())
	event_label.tooltip_text = "\n".join(world.event_log)


static func can_inspect_worker(world: SimulationWorldClass, worker: Dictionary) -> bool:
	if worker.is_empty() or not world.is_local_entity(worker):
		return false
	if not world.fog.enabled:
		return true
	if not world.is_worker_inside(worker):
		return world.is_entity_visible(worker)
	var building: Dictionary = world.buildings.get(int(worker.get("inside_building_id", 0)), {}) as Dictionary
	if building.is_empty():
		return false
	for cell: Vector2i in world.building_cells(building):
		if world.is_cell_explored(cell):
			return true
	return false


func _refresh_activity_panel(world: SimulationWorldClass, worker: Dictionary, building: Dictionary) -> void:
	_activity_target_type = ""
	_activity_target_id = 0
	_activity_panel.visible = false
	_activity_button.disabled = true
	_activity_status.text = ""
	if not worker.is_empty() and can_inspect_worker(world, worker):
		_activity_target_type = "worker"
		_activity_target_id = int(worker["id"])
		var enabled: bool = bool(worker.get("enabled", true))
		_activity_next_enabled = not enabled
		_activity_button.text = "Pozastavit práci" if enabled else "Pokračovat v práci"
		_activity_status.text = "Práce této jednotky je povolená." if enabled else "Práce této jednotky je pozastavená."
		var home: Dictionary = world.buildings.get(int(worker.get("home_id", 0)), {}) as Dictionary
		if not home.is_empty() and not bool(home.get("enabled", true)) and world.is_worker_work_paused(worker):
			_activity_status.text += "\nPracoviště je pozastavené. Pro práci obnovte i jeho provoz."
		_activity_button.tooltip_text = "Mění jen práci této jednotky, ne jejího pracoviště. Jídlo, spánek a uhnutí z cesty zůstávají možné. Již nesený náklad může doručit."
	elif not building.is_empty() and world.is_local_entity(building):
		_activity_target_type = "building"
		_activity_target_id = int(building["id"])
		var enabled: bool = bool(building.get("enabled", true))
		var unfinished: bool = int(building.get("construction_remaining", 0)) > 0 or int(building.get("foundation_work_remaining", 0)) > 0
		_activity_next_enabled = not enabled
		if unfinished:
			_activity_button.text = "Pozastavit stavbu" if enabled else "Obnovit stavbu"
			_activity_status.text = "Stavba je povolená." if enabled else "Stavba je pozastavená."
		else:
			_activity_button.text = "Pozastavit provoz" if enabled else "Obnovit provoz"
			_activity_status.text = "Provoz je povolený." if enabled else "Provoz je pozastavený."
		_activity_button.tooltip_text = "Pozastaví práci a nové služby této budovy. Zásoby, fronty a rozestavěná práce zůstanou zachované. Hotové zboží mohou nosiči odvézt."
	_activity_panel.visible = _activity_target_id != 0
	_activity_button.disabled = _activity_target_id == 0


func _request_activity_change() -> void:
	if _activity_target_id == 0 or _activity_button.disabled or not _activity_panel.visible or not _inspector_scroll.visible:
		return
	# The first listener refreshes this HUD synchronously. Snapshot all values
	# so later listeners still receive the original request, not the next toggle.
	var target_type: String = _activity_target_type
	var target_id: int = _activity_target_id
	var requested_enabled: bool = _activity_next_enabled
	entity_enabled_requested.emit(target_type, target_id, requested_enabled)


func _refresh_unit_thoughts(world: SimulationWorldClass, worker: Dictionary) -> void:
	var thoughts: Dictionary = world.unit_thoughts(worker) if not worker.is_empty() and can_inspect_worker(world, worker) else {}
	_thoughts_panel.visible = not thoughts.is_empty()
	_thought_current.text = "Teď: " + String(thoughts.get("current", "")) if not thoughts.is_empty() else ""
	_thought_next.text = "Potom: " + String(thoughts.get("next", "")) if not thoughts.is_empty() else ""


func _panel(node_name: String, preset: Control.LayoutPreset, offsets: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	_root.add_child(panel)
	panel.set_anchors_preset(preset)
	panel.offset_left = offsets.position.x
	panel.offset_top = offsets.position.y
	panel.offset_right = offsets.end.x
	panel.offset_bottom = offsets.end.y
	return panel


func _margin(parent: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _text_label(parent: Control, value: String, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(parent: Control, value: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func _surface(bg: Color, border: Color, padding: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _hud_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", INK)
	var panel_style: StyleBoxFlat = _surface(Color("#18211f"), Color("#45514a"), 0)
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 0
	result.set_stylebox("panel", "PanelContainer", panel_style)
	for control_type: String in ["Button", "OptionButton"]:
		result.set_stylebox("normal", control_type, _surface(Color("#26322d"), Color("#45554a")))
		result.set_stylebox("hover", control_type, _surface(Color("#35483b"), Color("#9ba580")))
		result.set_stylebox("pressed", control_type, _surface(Color("#48583b"), ACCENT))
		result.set_stylebox("disabled", control_type, _surface(Color("#202724"), Color("#35413a")))
		var focus: StyleBoxFlat = _surface(Color.TRANSPARENT, ACCENT)
		focus.draw_center = false
		focus.set_border_width_all(2)
		result.set_stylebox("focus", control_type, focus)
		result.set_color("font_color", control_type, INK)
		result.set_color("font_pressed_color", control_type, Color("#fff0c6"))
		result.set_color("font_hover_color", control_type, Color.WHITE)
		result.set_color("font_disabled_color", control_type, Color("#7c8981"))
		result.set_font_size("font_size", control_type, 12)
	result.set_stylebox("panel", "PopupMenu", _surface(Color("#18211f"), Color("#697961")))
	return result


func _worker_summary_text(world: SimulationWorldClass, counts: Dictionary = {}) -> String:
	if counts.is_empty():
		counts = _food_summary(world)
	var summary: String = "Citizens %d • Carriers %d • Gardeners %d\nSoldiers %d • Hungry %d\nArmy food requested %d • Food arriving %d\nBars show satiety: 0%% empty, 100%% full. Empty satiety is not immediate starvation. A separate reserve lasts %d game days without food; meals rebuild it gradually. Citizens visit an Inn automatically. Supply soldiers manually below %.0f%% satiety." % [
		counts["citizens"], counts["carrier"], counts["gardener"], counts["soldiers"], counts["hungry"],
		counts["requested"], counts["arriving"], int(_catalog.economy.get("nutrition_survival_days", 7)), _soldier_feeding_percent(),
	]
	return summary + "\nSleeping %d • Civilian rest 20:00–05:00. Sleep slows satiety loss, not the long-term reserve clock. Walking is never slowed by hunger." % int(counts["sleeping"])


func _soldier_feeding_threshold() -> int:
	return int(_catalog.economy.get("soldier_food_request_threshold", int(_catalog.economy.get("condition_max", 2700)) * 55 / 100))


func _soldier_feeding_percent() -> float:
	return 100.0 * float(_soldier_feeding_threshold()) / float(maxi(1, int(_catalog.economy.get("condition_max", 2700))))


func _can_request_soldier_food(worker: Dictionary) -> bool:
	return _catalog.soldiers.has(String(worker.get("type", ""))) \
		and int(worker.get("hunger", 0)) < _soldier_feeding_threshold() \
		and not bool(worker.get("food_requested", false)) \
		and int(worker.get("meal_ticks_left", 0)) == 0


func _food_summary(world: SimulationWorldClass) -> Dictionary:
	var counts: Dictionary = {"citizens": 0, "soldiers": 0, "hungry": 0, "requested": 0, "arriving": 0, "eligible": 0, "carrier": 0, "gardener": 0, "sleeping": 0}
	var arriving: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if world.fog.enabled and not world.is_local_entity(worker):
			continue
		var role: String = String(worker["type"])
		var soldier: bool = _catalog.soldiers.has(role)
		if world.is_worker_sleeping(worker):
			counts["sleeping"] = int(counts["sleeping"]) + 1
		var group: String = "soldiers" if soldier else "citizens"
		counts[group] = int(counts[group]) + 1
		if role in ["carrier", "gardener"]:
			counts[role] = int(counts[role]) + 1
		var hungry: bool = int(worker.get("hunger", 2700)) <= int(_catalog.economy.get("condition_hungry", 360))
		if hungry:
			counts["hungry"] = int(counts["hungry"]) + 1
		if soldier and bool(worker.get("food_requested", false)):
			counts["requested"] = int(counts["requested"]) + 1
		if _can_request_soldier_food(worker):
			counts["eligible"] = int(counts["eligible"]) + 1
		var delivery: Dictionary = worker.get("ration_delivery", {}) as Dictionary
		if delivery.get("phase", "") == "deliver":
			arriving[int(delivery.get("recipient_id", 0))] = true
	counts["arriving"] = arriving.size()
	return counts


func _unit_inventory_text(worker: Dictionary) -> String:
	var role: String = String(worker["type"])
	var lines: PackedStringArray = ["%s #%d" % [String(_catalog.unit(role).get("display_name", role)), int(worker["id"])]]
	var carrying: String = String(worker.get("carrying", ""))
	if not carrying.is_empty():
		lines.append("Carrying: " + String((_catalog.resources.get(carrying, {}) as Dictionary).get("display_name", carrying)))
	return "\n".join(lines)


func _unit_detail_text(world: SimulationWorldClass, worker: Dictionary) -> String:
	var food_text: String = _unit_food_text(world, worker)
	var schedule_status: String = world.worker_schedule_status(worker)
	return food_text if schedule_status.is_empty() else schedule_status + "\n" + food_text


func _unit_food_text(world: SimulationWorldClass, worker: Dictionary) -> String:
	if _catalog.soldiers.has(String(worker["type"])):
		return world.soldier_food_status(int(worker["id"])) + "\nRequest food below %.0f%% satiety. One delivered ration restores full satiety; the soldier stays at its post." % _soldier_feeding_percent()
	if int(worker.get("meal_ticks_left", 0)) > 0:
		return "Keeps its workplace and returns when the meal is finished."
	if worker.get("action", "") == "eat":
		return "Going to an Inn for food. Keeps its workplace while eating."
	return "Citizens find a supplied Inn automatically when hungry. Carriers deliver Bread, Sausages, Wine and Fish to the Inn."


static func satiety_color(status: String) -> Color:
	match status:
		"Starving": return Color("#ed7665")
		"Weakened": return Color("#e69462")
		"Hungry": return Color("#efa85b")
		"Getting hungry": return Color("#d7c778")
	return Color("#92bd6b")


func _refresh_satiety_panel(world: SimulationWorldClass, worker: Dictionary, simulation_speed: float, tick_seconds: float) -> void:
	_satiety_panel.visible = not worker.is_empty()
	if worker.is_empty():
		return
	var status: Dictionary = world.hunger_status(worker)
	var percent: float = float(status["satiety_percent"])
	var state: String = String(status["state"])
	_satiety_label.text = "Satiety %.0f%% · %s" % [percent, state]
	_satiety_bar.value = percent
	_satiety_fill.bg_color = satiety_color(state)
	var hungry_percent: float = 100.0 * float(status["hungry_at"]) / float(maxi(1, int(_catalog.economy.get("condition_max", 2700))))
	_satiety_bar.tooltip_text = "Satiety: 0%% empty, 100%% full. Empty satiety does not mean death.\nCitizens seek food at %.0f%%. A separate long-term reserve lasts %.0f game days without food.\nMeals restore satiety and gradually rebuild the reserve; one small bite does not reset it.\nWork stays at full efficiency for the first %d days of deficit. Walking is never slowed by hunger." % [hungry_percent, float(status["seven_day_limit"]), int(_catalog.economy.get("nutrition_weakening_start_days", 2))]
	_satiety_timing.tooltip_text = ""
	if not world.economy_enabled:
		_satiety_timing.text = "Food needs are disabled in this scenario."
		return
	_satiety_timing.tooltip_text = _nutrition_timing_tooltip(status, simulation_speed, tick_seconds)
	if int(worker.get("meal_ticks_left", 0)) > 0:
		_satiety_timing.text = _meal_description(worker) + "\n" + _nutrition_summary_text(status)
		if simulation_speed <= 0.0:
			_satiety_timing.text += "\nSimulation paused."
		return
	var until_hungry: int = int(status["remaining_to_hungry_ticks"])
	var soldier: bool = _catalog.soldiers.has(String(worker["type"]))
	if soldier:
		_satiety_timing.text = "Can request food below %.0f%% satiety." % _soldier_feeding_percent()
	elif until_hungry > 0:
		var rate_name: String = "sleeping" if world.is_worker_sleeping(worker) else "awake"
		_satiety_timing.text = "Estimated hunger in %s of game time at the current %s rate." % [_game_duration_text(until_hungry), rate_name]
		if simulation_speed > 0.0:
			_satiety_timing.text += "\n" + _real_time_estimate(until_hungry, simulation_speed, tick_seconds)
	elif until_hungry < 0:
		_satiety_timing.text = "Hunger is not advancing at the current activity rate."
	elif worker.get("action", "") == "eat":
		_satiety_timing.text = "Going to an Inn now."
	elif not String(worker.get("carrying", "")).is_empty():
		_satiety_timing.text = "Hungry; delivers its cargo before seeking an Inn."
	else:
		_satiety_timing.text = "Hungry; seeks a supplied Inn after its current task."
	_satiety_timing.text += "\n" + _nutrition_summary_text(status)
	if state == "Starving":
		var remaining: int = int(status["remaining_to_starve_ticks"])
		if remaining >= 0:
			_satiety_timing.text += "\nDanger: %s of game time until death without food." % _game_duration_text(remaining)
			if simulation_speed > 0.0:
				_satiety_timing.text += "\n" + _real_time_estimate(remaining, simulation_speed, tick_seconds)
	if simulation_speed <= 0.0:
		_satiety_timing.text += "\nSimulation paused."


static func _nutrition_summary_text(status: Dictionary) -> String:
	var limit: float = float(status["seven_day_limit"])
	var remaining_days: float = clampf(limit - float(status["deficit_days"]), 0.0, limit)
	return "Food reserve: %.1f / %.0f game days\nWork %.0f%% · walking 100%%" % [remaining_days, limit, float(status["work_efficiency_percent"])]


static func _nutrition_timing_tooltip(status: Dictionary, simulation_speed: float, tick_seconds: float) -> String:
	var remaining: int = int(status["remaining_to_starve_ticks"])
	var text: String = "Long-term reserve is separate from the satiety bar. Meals rebuild it gradually.\nSleep slows satiety loss, but does not extend the reserve clock. Hunger estimates assume the current activity continues."
	if remaining < 0:
		return text + "\nThe reserve countdown is paused while eating or food needs are inactive."
	text += "\nReserve without further food: %s of game time." % _game_duration_text(remaining)
	return text + "\n" + _real_time_estimate(remaining, simulation_speed, tick_seconds)


static func _real_time_estimate(ticks: int, simulation_speed: float, tick_seconds: float) -> String:
	if simulation_speed <= 0.0:
		return "Simulation paused."
	return "About %s at %.1f× speed." % [_duration_text(int(ceil(float(ticks) * tick_seconds / simulation_speed))), simulation_speed]


static func _game_duration_text(ticks: int) -> String:
	var minutes: int = maxi(0, int(ceil(float(ticks) * 1440.0 / float(DayCycleClass.TICKS_PER_DAY))))
	return "%d h %02d min" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d min" % minutes


static func _duration_text(seconds: int) -> String:
	return "%d min %02d s" % [seconds / 60, seconds % 60] if seconds >= 60 else "%d s" % seconds


func _meal_description(worker: Dictionary) -> String:
	var remaining: float = float(worker.get("meal_ticks_left", 0)) * SimulationWorldClass.TICK_SECONDS
	var course: Dictionary = worker.get("meal_course", {}) as Dictionary
	if course.is_empty():
		return "Finishing a meal at the Inn · %.1f s left at 1× speed" % remaining
	var food: String = String(course.get("food", ""))
	var food_name: String = String((_catalog.resources.get(food, {}) as Dictionary).get("display_name", food))
	return "Eating %s · %.1f s left at 1× speed in this course" % [food_name, remaining]



func blocks_map_point(screen_position: Vector2) -> bool:
	if _root == null:
		return false
	# Test actual visible panels, not the full-screen transparent HUD root.
	# Include passive status panels: a click over their text must not build.
	for child: Node in _root.get_children():
		if child == _sky_clock:
			continue # The small sky illustration deliberately leaves map input open.
		if child is Control:
			var control: Control = child as Control
			if control.is_visible_in_tree() and control.get_global_rect().has_point(screen_position):
				return true
	return false


func set_placement_preview(tool: String, preview: Dictionary) -> void:
	if placement_preview_label == null:
		return
	placement_preview_label.visible = not tool.is_empty()
	var text: String = ""
	var color: Color = MUTED
	if not tool.is_empty():
		if preview.is_empty():
			text = "Move onto the map to preview placement."
		elif bool(preview.get("obscured", false)):
			text = String(preview.get("reason", "Explore this area first."))
			color = Color("#ffb39c")
		else:
			text = "%s\nHeight %.1f · slope %d" % [
				String(preview.get("reason", "")), float(preview.get("height", 0.0)), int(preview.get("slope", 0)),
			]
			color = Color("#9ae3a8") if bool(preview.get("valid", false)) else Color("#ffb39c")
			if bool(preview.get("needs_levelling", false)):
				color = Color("#f4c36a")
				text = "%s\nTarget height %d · materials arrive afterwards" % [String(preview["reason"]), int(preview["foundation_target_height"])]
	# Hovering repeatedly over the same tile never relayouts or restyles the
	# dock. The reserved two-line slot stays stable across valid/invalid sites.
	if placement_preview_label.text != text:
		placement_preview_label.text = text
	if _placement_preview_color != color:
		_placement_preview_color = color
		placement_preview_label.add_theme_color_override("font_color", color)


func set_terrain_rules(enabled: bool) -> void:
	_terrain_button.set_pressed_no_signal(enabled)


func _selected_building_inventory_text(world: SimulationWorldClass, selected_cell: Vector2i) -> String:
	if world.fog.enabled and not world.is_cell_explored(selected_cell):
		return ""
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0:
		var field_id: int = world.field_id_at(selected_cell)
		if field_id != 0:
			var field: Dictionary = world.fields[field_id] as Dictionary
			var is_vine: bool = String(field.get("kind", "wheat")) == "vine"
			var field_name: String = "Vine field" if is_vine else "Wheat field"
			var stage: int = world.field_growth_stage(field)
			var field_status: String = "Prepared soil • waiting for sowing"
			if stage == 1:
				var progress: int = clampi(int(100.0 * float(field["age_ticks"]) / float(_field_growth_ticks(is_vine))), 0, 100)
				field_status = "%s growing • %d%%" % ["Grapes" if is_vine else "Wheat", progress]
			elif stage == 2:
				field_status = "Ripe %s • ready for harvest" % ("grapes" if is_vine else "wheat")
			return "%s\n%s" % [field_name, field_status]
		var deposits: Dictionary = _world_deposits(world)
		for deposit: Dictionary in deposits.values():
			if deposit["position"] as Vector2i == selected_cell:
				var resource_id: String = String(deposit["resource"])
				var resource_name: String = String((_catalog.resources.get(resource_id, {}) as Dictionary).get("display_name", resource_id))
				return "%s deposit\nRemaining: %d" % [resource_name, int(deposit["amount"])]
		if world.grid.contains(selected_cell):
			var material: String = world.grid.base_terrain_at(selected_cell)
			var walking: String = "Walkable" if world.grid.is_walkable(selected_cell) else "Blocked"
			var building_rule: String = "Level, buildable ground" if world.grid.is_buildable(selected_cell) else "Not buildable"
			return "%s terrain\nHeight: %.1f • slope: %d\n%s • %s" % [material.capitalize(), world.grid.cell_height(selected_cell), world.grid.cell_slope(selected_cell), walking, building_rule]
		return ""
	var building: Dictionary = world.buildings[building_id] as Dictionary
	var building_type: String = String(building["type"])
	var definition: Dictionary = world.catalog.building(building_type)
	var building_name: String = String(definition.get("display_name", building_type))
	if world.fog.enabled and not world.is_local_entity(building):
		return building_name + "\nForeign building"
	if building_type == "workers_house":
		return "%s\nResidence for Carriers and Builders" % building_name
	var inventory: Dictionary
	var resource_ids: Array[String] = []
	if building_type == "warehouse":
		inventory = building.get("storage", {}) as Dictionary
		for resource_id_variant: Variant in definition.get("accepts", []) as Array:
			resource_ids.append(String(resource_id_variant))
		var extra_resource_ids: Array[String] = []
		for resource_id_variant: Variant in inventory.keys():
			var resource_id: String = String(resource_id_variant)
			if not resource_ids.has(resource_id):
				extra_resource_ids.append(resource_id)
		extra_resource_ids.sort()
		resource_ids.append_array(extra_resource_ids)
	elif building_type == "inn":
		inventory = building.get("inputs", {}) as Dictionary
		for resource_id_variant: Variant in definition.get("inputs", []) as Array:
			resource_ids.append(String(resource_id_variant))
	else:
		inventory = building.get("outputs", {}) as Dictionary
		for resource_id_variant: Variant in definition.get("outputs", []) as Array:
			resource_ids.append(String(resource_id_variant))

	if resource_ids.is_empty():
		return "%s\nInventory: empty" % building_name
	var inventory_parts: PackedStringArray = []
	for resource_id: String in resource_ids:
		if resource_ids.size() > 8 and int(inventory.get(resource_id, 0)) == 0:
			continue
		var resource_definition: Dictionary = world.catalog.resources.get(resource_id, {}) as Dictionary
		var resource_name: String = String(resource_definition.get(
			"display_name",
			resource_id.replace("_", " ").capitalize()
		))
		inventory_parts.append("%s: %d" % [resource_name, int(inventory.get(resource_id, 0))])
	if inventory_parts.is_empty():
		return "%s\nInventory: empty" % building_name
	if inventory_parts.size() > 3:
		return "%s\nInventory\n%s" % [building_name, "\n".join(inventory_parts)]
	return "%s\nInventory: %s" % [building_name, "  •  ".join(inventory_parts)]


func _selected_production_text(world: SimulationWorldClass, selected_cell: Vector2i) -> String:
	if world.fog.enabled and not world.is_cell_explored(selected_cell):
		return ""
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0:
		var field_id: int = world.field_id_at(selected_cell)
		if field_id != 0:
			if String((world.fields[field_id] as Dictionary).get("kind", "wheat")) == "vine":
				return "Build a Vineyard nearby and train a Farmer.\nGrapes regrow after harvest; the Vineyard makes wine."
			return "A farmer from a Farm within 8 tiles sows and harvests here.\nSow → grow for 20 s → harvest → Grain"
		for deposit: Dictionary in _world_deposits(world).values():
			if deposit["position"] as Vector2i == selected_cell:
				return "Build a Fisherman's Hut beside the water." if String(deposit["resource"]) == "fish" else "Build the matching mine or Quarry near this deposit."
		return ""
	var building: Dictionary = world.buildings[building_id] as Dictionary
	if world.fog.enabled and not world.is_local_entity(building):
		return ""
	var definition: Dictionary = world.catalog.building(String(building["type"]))
	var worker_type: String = WorkplacesClass.profession(world, building_id)
	var recipe: Dictionary = world.catalog.recipe(String(building.get("recipe_id", definition.get("recipe", ""))))
	var lines: PackedStringArray = []
	if int(building.get("foundation_work_remaining", 0)) > 0:
		var remaining: int = int(building["foundation_work_remaining"])
		var total_work: int = maxi(1, int(building.get("foundation_work_total", remaining)))
		var progress: int = clampi(int(100.0 * float(total_work - remaining) / float(total_work)), 0, 100)
		var working: bool = false
		for worker: Dictionary in world.workers.values():
			if worker.get("action", "") == "build_site" and worker.get("state", "") == "working" and int(worker.get("source_id", 0)) == building_id:
				working = world.can_worker_work(worker) and world.BuildingFoundationsClass.waiting_reason(world, building, int(worker["id"])).is_empty()
				break
		lines.append("Levelling foundations: %d%%" % progress if working else "Waiting for Builder — ground preparation")
		lines.append("Earthwork: %d%% · %.1f s left at 1×" % [progress, float(remaining) * world.TICK_SECONDS])
		lines.append("Ground preparation → materials → construction")
		lines.append(world.production_status(building))
		return "\n".join(lines)
	if int(building.get("construction_remaining", 0)) > 0:
		var total: int = maxi(1, int(definition.get("construction_ticks", 1)))
		var progress: int = clampi(int(100.0 * float(total - int(building["construction_remaining"])) / float(total)), 0, 100)
		lines.append("Construction: %d%% • builder required" % progress)
		var delivered: Dictionary = building.get("construction_delivered", {}) as Dictionary
		var material_parts: PackedStringArray = []
		var site_cost: Dictionary = world.construction_cost(building)
		for resource_id: String in site_cost:
			var cost: int = int(site_cost[resource_id])
			material_parts.append("%s %d/%d" % [String(_catalog.resources[resource_id].get("display_name", resource_id)), int(delivered.get(resource_id, 0)), cost])
		lines.append("Delivered: " + "  •  ".join(material_parts))
		if int(building.get("construction_cost_revision", _catalog.CONSTRUCTION_COST_REVISION)) < _catalog.CONSTRUCTION_COST_REVISION:
			lines.append("Legacy site: original price preserved. New sites use current costs.")
		lines.append(world.production_status(building))
		return "\n".join(lines)
	if not worker_type.is_empty():
		var owner: Dictionary = world.workplace_worker(building_id)
		if world.fog.enabled and not owner.is_empty() and not world.is_local_entity(owner):
			owner = {}
		var profession_name: String = String(world.catalog.unit(worker_type).get("display_name", worker_type))
		if owner.is_empty():
			lines.append("Worker: %s • 0/1 • waiting for worker" % profession_name)
		else:
			var location: String = " • inside" if world.is_worker_inside(owner) and int(owner.get("inside_building_id", 0)) == building_id else ""
			lines.append("Worker: %s #%d • 1/1%s" % [profession_name, int(owner["id"]), location])
			var satiety: Dictionary = world.hunger_status(owner)
			lines.append("Satiety %.0f%% · %s" % [float(satiety["satiety_percent"]), String(satiety["state"])])
			if world.economy_enabled:
				lines.append(_nutrition_summary_text(satiety))
			if int(owner.get("meal_ticks_left", 0)) > 0:
				lines.append(_meal_description(owner))
	var indoor_count: int = 0
	var sleeping_count: int = 0
	for worker: Dictionary in world.workers.values():
		if world.fog.enabled and not world.is_local_entity(worker):
			continue
		if world.is_worker_inside(worker) and int(worker.get("inside_building_id", 0)) == building_id:
			indoor_count += 1
			if world.is_worker_sleeping(worker):
				sleeping_count += 1
	if indoor_count > 0:
		lines.append("Inside: %d %s" % [indoor_count, "citizen" if indoor_count == 1 else "citizens"])
	if sleeping_count > 0:
		lines.append("Sleeping: %d • until 05:00" % sleeping_count)
	if String(building["type"]) == "farm":
		lines.append("Wheat fields → Grain  •  build fields with 0")
	elif String(building["type"]) == "forester_hut":
		lines.append("Planting radius: %d tiles from the hut" % int(definition.get("planting_radius", 8)))
		lines.append("Plants saplings on reachable clear ground. Train a Gardener at School.")
	elif String(building["type"]) == "workers_house":
		var occupancy: Dictionary = _residence_occupancy(world, building_id, definition)
		lines.append("Residents: %d/%d occupied" % [int(occupancy["occupied"]), int(occupancy["capacity"])])
		lines.append("Carriers and Builders return here to sleep; their workplace assignment stays separate.")
	elif String(building["type"]) == "fisher_hut":
		lines.append("Fishing radius: %d tiles • reachable fish deposit required" % int(definition.get("extract_radius", 3)))
		lines.append("Fish are stored here; carriers collect them. Train a Fisherman at School.")
	elif String(building["type"]) == "vineyard":
		lines.append("Vine fields → Wine • fields regrow after harvest")
	elif String(building["type"]) == "inn":
		lines.append("Dining seats: %d/%d occupied" % [world.inn_occupied_seats(building_id), int(definition.get("seating_capacity", 6))])
		var diner_ids: Array = world.workers.keys()
		diner_ids.sort()
		for diner_id: int in diner_ids:
			var diner: Dictionary = world.workers[diner_id]
			if world.fog.enabled and not world.is_local_entity(diner):
				continue
			if int(diner.get("inside_building_id", 0)) != building_id or int(diner.get("meal_ticks_left", 0)) <= 0:
				continue
			var satiety: Dictionary = world.hunger_status(diner)
			lines.append("%s #%d · Satiety %.0f%%\n%s" % [String(_catalog.unit(String(diner["type"])).get("display_name", diner["type"])), diner_id, float(satiety["satiety_percent"]), _meal_description(diner)])
			if world.economy_enabled:
				lines.append(_nutrition_summary_text(satiety))
		lines.append("Citizens visit automatically when hungry, eat up to %d different foods, then return to work." % int(_catalog.economy.get("max_meals_per_visit", 3)))
		lines.append("Keep Bread, Sausages, Wine or Fish supplied by carriers. Soldiers receive food at their posts through Supply food.")
	elif not recipe.is_empty():
		var recipe_inputs: Dictionary = recipe.get("inputs", {}) as Dictionary
		var source: String = "Nearby deposit" if recipe_inputs.is_empty() else _resource_amounts_text(recipe_inputs)
		lines.append("Recipe: %s → %s  •  %.0f s" % [
			source,
			_resource_amounts_text(recipe.get("outputs", {}) as Dictionary),
			float(recipe.get("duration_ticks", 0)) / 10.0,
		])
		var inputs: Dictionary = building.get("inputs", {}) as Dictionary
		var input_parts: PackedStringArray = []
		for resource_id_variant: Variant in definition.get("inputs", []) as Array:
			var resource_id: String = String(resource_id_variant)
			var resource_name: String = String(_catalog.resources[resource_id].get("display_name", resource_id))
			var amount: int = int(inputs.get(resource_id, 0))
			if definition.has("input_capacity"):
				input_parts.append("%s: %d/%d" % [resource_name, amount, int(definition["input_capacity"])])
			else:
				input_parts.append("%s: %d" % [resource_name, amount])
		if not input_parts.is_empty():
			lines.append("Inputs: " + "  •  ".join(input_parts))
	if recipe.is_empty() and not (definition.get("inputs", []) as Array).is_empty():
		var supplied: Dictionary = {}
		for resource_id: String in building.get("inputs", {}) as Dictionary:
			var amount: int = int((building["inputs"] as Dictionary)[resource_id])
			if amount > 0:
				supplied[resource_id] = amount
		lines.append("Supplies: " + (_resource_amounts_text(supplied) if not supplied.is_empty() else "waiting for deliveries"))
	var status: String = world.production_status(building)
	if not status.is_empty():
		lines.append(status)
	return "\n".join(lines)


func _world_deposits(world: SimulationWorldClass) -> Dictionary:
	var value: Variant = world.get("deposits")
	return value as Dictionary if value is Dictionary else {}


func _residence_occupancy(world: SimulationWorldClass, building_id: int, definition: Dictionary) -> Dictionary:
	var capacity: int = int(definition.get("residence_capacity", 0))
	if world.has_method("residence_occupancy"):
		var reported: Variant = world.call("residence_occupancy", building_id)
		if reported is Dictionary:
			var details: Dictionary = reported as Dictionary
			return {
				"occupied": maxi(0, int(details.get("occupied", 0))),
				"capacity": maxi(0, int(details.get("capacity", capacity))),
				"residents": details.get("residents", []),
			}
	# Compatibility while a world created by an older embedded client has no
	# public residence helper. Sleeping-place ownership is the source of truth;
	# home_id remains the unit's workplace.
	var resident_types: Array = definition.get("resident_types", []) as Array
	var residents: Array[int] = []
	for worker: Dictionary in world.workers.values():
		if int(worker.get("sleep_home_id", 0)) == building_id \
				and resident_types.has(String(worker.get("type", ""))):
			residents.append(int(worker.get("id", 0)))
	residents.sort()
	return {"occupied": residents.size(), "capacity": capacity, "residents": residents}


func _field_growth_ticks(is_vine: bool) -> int:
	var value: Variant = _catalog.get("economy")
	var economy: Dictionary = value as Dictionary if value is Dictionary else {}
	return int(economy.get("vine_growth_ticks" if is_vine else "wheat_growth_ticks", 160 if is_vine else 200))


func _resource_amounts_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for resource_id: String in amounts:
		var resource_name: String = String(_catalog.resources[resource_id].get("display_name", resource_id))
		parts.append("%d %s" % [int(amounts[resource_id]), resource_name])
	return " + ".join(parts)


func _build_mode_hint(mode: String) -> String:
	match mode:
		"field":
			return "Place on clear grass or dirt within 8 tiles of a Farm."
		"vine_field":
			return "Vine fields need a nearby Vineyard and 1 Plank."
		"quarry":
			return "Place on clear ground within 3 tiles of rock."
		"farm":
			return "Add wheat fields (0) nearby and train a Farmer at School."
		"forester_hut":
			return "Train a Gardener at School. Plants trees on reachable clear ground within %d tiles of this hut." % int(_catalog.building(mode).get("planting_radius", 8))
		"workers_house":
			return "Homes up to %d Carriers or Builders. Residents keep their workplace assignment and return here to sleep." % int(_catalog.building(mode).get("residence_capacity", 2))
		"fisher_hut":
			return "Place near a reachable fish deposit within %d tiles. Train a Fisherman at School; carriers collect fish." % int(_catalog.building(mode).get("extract_radius", 3))
		"mill", "bakery":
			return "Train a Baker at School; carriers deliver ingredients."
		"inn":
			return "Citizens eat here automatically. %d seats; carriers bring Bread, Sausages, Wine and Fish. Build near workplaces with a clear entrance." % int(_catalog.building(mode).get("seating_capacity", 6))
		"road":
			return "Stone roads speed up transport. Keep fields clear."
	if not mode.is_empty():
		return String(_catalog.building(mode).get("description", ""))
	return ""


func _selected_training_text(world: SimulationWorldClass, selected_cell: Vector2i) -> String:
	if world.fog.enabled and not world.is_cell_explored(selected_cell):
		return ""
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0:
		return ""
	var building: Dictionary = world.buildings[building_id] as Dictionary
	if world.fog.enabled and not world.is_local_entity(building):
		return ""
	var definition: Dictionary = world.catalog.building(String(building["type"]))
	if (definition.get("trains", []) as Array).is_empty():
		return ""
	var building_name: String = String(definition.get("display_name", building["type"]))
	var training_queue: Array = building.get("training_queue", []) as Array
	if training_queue.is_empty():
		return "  |  %s idle" % building_name
	var unit_type: String = String(training_queue[0])
	var unit_name: String = String(world.catalog.unit(unit_type).get("display_name", unit_type))
	return "  |  %s: %s %dt (%d queued)" % [
		building_name,
		unit_name,
		int(building.get("training_remaining", 0)),
		training_queue.size(),
	]
