class_name GameHud
extends CanvasLayer

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const ResourceIconClass = preload("res://scripts/view/resource_icon.gd")
const EconomyActionsClass = preload("res://scripts/view/economy_actions.gd")
const WorkplacesClass = preload("res://scripts/simulation/workplaces.gd")
const NutritionClass = preload("res://scripts/simulation/nutrition.gd")
const UiTextClass = preload("res://scripts/ui_text.gd")

const CATEGORIES: Array[String] = ["infrastructure", "food", "mining", "military"]
const CATEGORY_NAMES: Array[String] = ["Obec", "Jídlo", "Těžba", "Armáda"]
const STOCK_CATEGORIES: Array[String] = ["materials", "food", "military"]
const STOCK_CATEGORY_NAMES: Array[String] = ["Materiál", "Jídlo", "Výzbroj"]
const SUMMARY_RESOURCES: Array[String] = ["log", "plank", "stone", "bread", "gold"]

# One derivation for the whole frame. The map keeps everything these leave over,
# and the camera fit reads MAP_LEFT/MAP_TOP/MAP_BOTTOM directly.
const EDGE: float = 12.0
const DOCK_WIDTH: float = 280.0
const OVERVIEW_HEIGHT: float = 56.0
const STATUS_HEIGHT: float = 40.0
const MAP_LEFT: float = EDGE + DOCK_WIDTH + EDGE
const MAP_TOP: float = EDGE + OVERVIEW_HEIGHT + 10.0
## Distance from the bottom window edge to the top of the status bar.
const STATUS_TOP: float = STATUS_HEIGHT + EDGE
## Distance from the bottom window edge to the bottom of the sidebar.
const DOCK_BOTTOM: float = STATUS_TOP + 10.0
const MAP_BOTTOM: float = DOCK_BOTTOM
## The build list must not resize when a tool is picked, so its footer always
## reserves the same height whether or not a placement is in progress.
const BUILD_FOOTER_HEIGHT: float = 104.0

const INK := Color("#e9e9dc")
const MUTED := Color("#a0aba4")
const ACCENT := Color("#d9bd77")
const WARN := Color("#edb27d")
const BAD := Color("#ffb39c")
const GOOD := Color("#9ae3a8")

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
var _stock_column: VBoxContainer
var _stock_items: GridContainer
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
var _detail_title: Label
var _progress_panel: VBoxContainer
var _progress_label: Label
var _progress_bar: ProgressBar
var _progress_fill: StyleBoxFlat
var _build_footer_box: VBoxContainer
var _selected_unit_id: int = 0
var _last_unit_selection: int = 0
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
	_build_resource_hud()
	_build_help()
	# A resized window changes how much height the stock panel may claim.
	_root.resized.connect(_apply_stock_height)


func _build_overview() -> void:
	# No in-game branding block: the window title already names the game, and
	# those 158 px were the widest permanently dead area of the old bar.
	var panel: PanelContainer = _panel("OverviewBar", Control.PRESET_TOP_WIDE, Rect2(EDGE, EDGE, -2.0 * EDGE, OVERVIEW_HEIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_margin(panel, 12, 4).add_child(row)
	for resource_id: String in SUMMARY_RESOURCES:
		_resource_tile(row, resource_id, true)
	row.add_child(VSeparator.new())
	# Population belongs with the other settlement totals, not squeezed between
	# the clock and the speed buttons.
	_citizens_label = _text_label(row, "", 12, MUTED)
	_citizens_label.name = "CitizenSummaryLabel"
	_citizens_label.custom_minimum_size.x = 150
	_citizens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_citizens_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_citizens_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_stock_toggle = _button(row, "Vše", "StockpileToggle")
	_stock_toggle.custom_minimum_size = Vector2(84, 32)
	_stock_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	_stock_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stock_toggle.toggle_mode = true
	_stock_toggle.tooltip_text = "Zobrazit všechny zásoby materiálu, jídla a výzbroje."
	_stock_toggle.toggled.connect(func(opened: bool) -> void:
		resource_hud_panel.visible = opened
		if opened:
			_close_help()
			_fit_stock_panel()
	)


func _build_dock() -> void:
	var panel: PanelContainer = _panel("VillagePanel", Control.PRESET_LEFT_WIDE,
		Rect2(EDGE, MAP_TOP, DOCK_WIDTH, -MAP_TOP - DOCK_BOTTOM))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_margin(panel, 10, 10).add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	_build_tab = _button(tabs, "Stavět", "BuildTab")
	_inspect_tab = _button(tabs, "Detail", "InspectTab")
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
	_build_body = VBoxContainer.new()
	_build_body.name = "BuildBody"
	_build_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_body.add_theme_constant_override("separation", 8)
	column.add_child(_build_body)
	# Four short categories fit one row; the old 2x2 grid spent a second row of
	# sidebar height on four words.
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 4)
	_build_body.add_child(categories)
	for index: int in range(CATEGORIES.size()):
		var button: Button = _button(categories, CATEGORY_NAMES[index], "BuildCategory_" + CATEGORIES[index])
		button.toggle_mode = true
		button.custom_minimum_size.y = 26
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 11)
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
	_add_tool_button(_build_groups["infrastructure"] as Control, "Kamenná cesta", "road", "1")
	_add_tool_button(_build_groups["food"] as Control, "Obilné pole", "field", "0")
	_add_tool_button(_build_groups["food"] as Control, "Vinné pole", "vine_field")
	var shortcuts: Dictionary = {
		"warehouse": "2", "lumber_hut": "3", "sawmill": "4", "school": "5",
		"quarry": "6", "farm": "7", "mill": "8", "bakery": "9",
	}
	for building_type: String in _catalog.buildings:
		var definition: Dictionary = _catalog.building(building_type)
		var category: String = String(definition.get("category", "infrastructure"))
		if not _build_groups.has(category):
			category = "infrastructure"
		_add_tool_button(_build_groups[category] as Control,
			UiTextClass.building_label(_catalog, building_type), building_type,
			String(shortcuts.get(building_type, "")))
	_supply_army_button = _button(_build_groups["military"] as Control, "Zásobit armádu", "SupplyArmy")
	_supply_army_button.custom_minimum_size.y = 38
	_supply_army_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_supply_army_button.tooltip_text = "Vyžádá donášku jídla pro každého vojáka pod hranicí sytosti. Jednotlivého vojáka zásobíš jeho výběrem na mapě."
	_supply_army_button.pressed.connect(army_food_requested.emit)
	_add_build_footer(_build_body)
	_show_build_category(0)

	_inspector_scroll = ScrollContainer.new()
	_inspector_scroll.name = "BuildingInspectorScroll"
	_inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_inspector_scroll)
	var inspector := VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 10)
	_inspector_scroll.add_child(inspector)
	_selection_hint = _text_label(inspector, "VÝBĚR", 10, MUTED)
	# The selected thing gets a real heading instead of being the first line of
	# an undifferentiated text block.
	_detail_title = _text_label(inspector, "", 17, ACCENT)
	_detail_title.name = "DetailTitleLabel"
	_detail_title.visible = false
	_empty_selection = VBoxContainer.new()
	_empty_selection.add_theme_constant_override("separation", 10)
	inspector.add_child(_empty_selection)
	_text_label(_empty_selection, "Vyber něco na mapě", 17)
	_text_label(_empty_selection, "Klikni na budovu a uvidíš její zásoby, pracovníka a dostupné akce.\n\nPruh nad člověkem ukazuje sytost. Klikni na člověka pro detail, u vojáka můžeš vyžádat jídlo.\n\nPole ukazují růst plodiny, ložiska zbývající surovinu.", 12, MUTED)
	_text_label(_empty_selection, "Potřebuješ víc lidí? Vyber Školu a vycvič je.", 12, ACCENT)
	_progress_panel = VBoxContainer.new()
	_progress_panel.name = "DetailProgressPanel"
	_progress_panel.add_theme_constant_override("separation", 4)
	inspector.add_child(_progress_panel)
	_progress_label = _text_label(_progress_panel, "", 12, INK)
	_progress_label.name = "DetailProgressLabel"
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "DetailProgressBar"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.step = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.add_theme_stylebox_override("background", _surface(Color("#101917"), Color("#435449")))
	_progress_fill = StyleBoxFlat.new()
	_progress_fill.bg_color = ACCENT
	_progress_fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", _progress_fill)
	_progress_panel.add_child(_progress_bar)
	_progress_panel.visible = false
	building_inventory_label = _text_label(inspector, "", 13)
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
	_text_label(_satiety_panel, "0 % prázdno · 100 % plno", 10, MUTED)
	_satiety_timing = _text_label(_satiety_panel, "", 12, MUTED)
	_satiety_timing.name = "UnitSatietyTiming"
	_satiety_timing.mouse_filter = Control.MOUSE_FILTER_PASS
	_satiety_panel.visible = false
	_construction_panel = VBoxContainer.new()
	_construction_panel.name = "ConstructionActions"
	_construction_panel.add_theme_constant_override("separation", 6)
	inspector.add_child(_construction_panel)
	var cancel_site: Button = _button(_construction_panel, "Zrušit stavbu", "CancelConstruction")
	cancel_site.custom_minimum_size.y = 38
	cancel_site.add_theme_color_override("font_color", Color("#f0b49b"))
	cancel_site.tooltip_text = "Odstraní tuto nedokončenou budovu. Dovezený materiál se vrátí do dostupného skladu, nosiči si náklad ponechají a přesměrují ho."
	cancel_site.pressed.connect(construction_cancel_requested.emit)
	_text_label(_construction_panel, "Zruší staveniště a vrátí dovezený materiál do skladu. Již srovnaná zem zůstane změněná.", 11, MUTED)
	_construction_panel.visible = false
	production_detail_label = _text_label(inspector, "", 12, MUTED)
	production_detail_label.name = "ProductionDetailLabel"
	_soldier_food_panel = VBoxContainer.new()
	_soldier_food_panel.name = "SoldierFoodActions"
	inspector.add_child(_soldier_food_panel)
	_soldier_food_button = _button(_soldier_food_panel, "Přinést jídlo", "SupplySoldierFood")
	_soldier_food_button.custom_minimum_size.y = 36
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
	_show_dock(false)


## One reserved block for everything about the active tool: its name, the
## placement feedback and the way out. Its height never changes, so picking a
## tool no longer shrinks the building list under the cursor.
func _add_build_footer(parent: Control) -> void:
	_build_footer_box = VBoxContainer.new()
	_build_footer_box.name = "BuildFooter"
	_build_footer_box.size_flags_vertical = Control.SIZE_SHRINK_END
	_build_footer_box.add_theme_constant_override("separation", 4)
	parent.add_child(_build_footer_box)
	_build_footer_box.add_child(HSeparator.new())
	# Every part below has a height that does not depend on its text, so a long
	# hint or a newly shown Cancel button can never push the list around.
	mode_label = _text_label(_build_footer_box, "Výběr / průzkum", 12, ACCENT)
	mode_label.name = "ActiveToolLabel"
	mode_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	mode_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mode_label.custom_minimum_size.y = 17
	var hint_scroll := ScrollContainer.new()
	hint_scroll.name = "BuildHintScroll"
	hint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hint_scroll.custom_minimum_size.y = BUILD_FOOTER_HEIGHT - 53.0
	hint_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_footer_box.add_child(hint_scroll)
	var hint_column := VBoxContainer.new()
	hint_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_column.add_theme_constant_override("separation", 2)
	hint_scroll.add_child(hint_column)
	placement_preview_label = _text_label(hint_column, "", 11)
	placement_preview_label.name = "PlacementPreviewLabel"
	placement_preview_label.visible = false
	_build_hint = _text_label(hint_column, "", 11, MUTED)
	# A slot that keeps its height whether or not the button inside is shown.
	var cancel_slot := Control.new()
	cancel_slot.name = "CancelBuildSlot"
	cancel_slot.custom_minimum_size.y = 28
	cancel_slot.size_flags_vertical = Control.SIZE_SHRINK_END
	_build_footer_box.add_child(cancel_slot)
	_cancel_build = Button.new()
	_cancel_build.name = "CancelBuild"
	_cancel_build.text = "Přestat umísťovat · Esc"
	_cancel_build.tooltip_text = "Opustí režim umísťování. Rozestavěnou budovu odstraníš jejím výběrem a volbou Zrušit stavbu v Detailu."
	cancel_slot.add_child(_cancel_build)
	_cancel_build.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cancel_build.pressed.connect(build_mode_requested.emit.bind(""))
	_cancel_build.visible = false


func _build_status_bar() -> void:
	var panel: PanelContainer = _panel("StatusBar", Control.PRESET_BOTTOM_WIDE,
		Rect2(EDGE, -STATUS_TOP, -2.0 * EDGE, STATUS_HEIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_margin(panel, 12, 4).add_child(row)
	# The event log used to be a separate floating strip that the Controls panel
	# covered and truncated. It is a status line, so it lives in the status bar.
	event_label = _text_label(row, "", 11, MUTED)
	event_label.name = "EventLabel"
	event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	event_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(VSeparator.new())
	_add_speed_button(row, "Pauza", 0.0)
	_add_speed_button(row, "0,5×", 0.5)
	_add_speed_button(row, "1×", 1.0)
	_add_speed_button(row, "2×", 2.0)
	_terrain_button = _button(row, "Terén", "TerrainOverlayToggle")
	_terrain_button.toggle_mode = true
	_terrain_button.custom_minimum_size.x = 58
	_terrain_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_terrain_button.tooltip_text = "Zobrazit pravidla terénu (F2): zelená rovina, jantarová svah, červená neprůchodné"
	_terrain_button.toggled.connect(func(enabled: bool) -> void: terrain_rules_requested.emit(enabled))
	_help_button = _button(row, "Ovládání", "HelpToggle")
	_help_button.toggle_mode = true
	_help_button.custom_minimum_size.x = 72
	_help_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_help_button.toggled.connect(func(opened: bool) -> void:
		_help_panel.visible = opened
		if opened:
			_close_stocks()
	)
	if _include_main_menu:
		var menu_button: Button = _button(row, "Menu", "MenuButton")
		menu_button.custom_minimum_size.x = 56
		menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		menu_button.tooltip_text = "Hlavní menu (Esc)"
		menu_button.pressed.connect(func() -> void: main_menu_requested.emit())


func _build_resource_hud() -> void:
	resource_hud_panel = _panel("ResourceStatusBar", Control.PRESET_TOP_WIDE,
		Rect2(MAP_LEFT, MAP_TOP, -MAP_LEFT - EDGE, 420))
	_stock_column = VBoxContainer.new()
	_stock_column.add_theme_constant_override("separation", 10)
	_margin(resource_hud_panel, 14, 12).add_child(_stock_column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_stock_column.add_child(header)
	var title: Label = _text_label(header, "Zásoby osady", 17, ACCENT)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tabs)
	for index: int in range(STOCK_CATEGORIES.size()):
		var button: Button = _button(tabs, STOCK_CATEGORY_NAMES[index], "StockCategory_" + STOCK_CATEGORIES[index])
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(88, 28)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.pressed.connect(_show_resource_category.bind(index))
		_stock_buttons.append(button)
	var close_button: Button = _button(header, "Zavřít", "CloseStockpile")
	close_button.custom_minimum_size.x = 64
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_close_stocks)
	_text_label(_stock_column, "Celkem = sklady + budovy + nesené zboží. Cesty a vinná pole se platí ze skladu.", 10, MUTED)
	_stock_scroll = ScrollContainer.new()
	_stock_scroll.name = "StockpileScroll"
	_stock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stock_column.add_child(_stock_scroll)
	_stock_items = GridContainer.new()
	_stock_items.name = "ResourceItems"
	# Four columns keep the one-line location breakdown readable; the panel now
	# shrinks to the open category instead of always reserving the tallest one.
	_stock_items.columns = 4
	_stock_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_items.add_theme_constant_override("h_separation", 10)
	_stock_items.add_theme_constant_override("v_separation", 10)
	_stock_scroll.add_child(_stock_items)
	for resource_id: String in _hud_resource_ids():
		_resource_tile(_stock_items, resource_id, false)
	_show_resource_category(0)
	resource_hud_panel.visible = false


## Height follows the open category. Materials no longer leaves a third of the
## panel empty just because Equipment needs more rows.
##
## The scroll container reports no minimum of its own, so the tile grid is what
## has to be measured, and only after the visibility change has been laid out.
func _fit_stock_panel() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_apply_stock_height()


const STOCK_PANEL_CHROME: float = 92.0


func _apply_stock_height() -> void:
	if resource_hud_panel == null or _stock_items == null or _root == null:
		return
	var content: float = _stock_items.get_combined_minimum_size().y + STOCK_PANEL_CHROME
	var available: float = maxf(180.0, _root.size.y - MAP_TOP - DOCK_BOTTOM)
	var target: float = MAP_TOP + clampf(content, 150.0, available)
	if not is_equal_approx(resource_hud_panel.offset_bottom, target):
		resource_hud_panel.offset_bottom = target


func _build_help() -> void:
	_help_panel = _panel("ControlsPanel", Control.PRESET_BOTTOM_RIGHT,
		Rect2(-396, -(STATUS_TOP + 268.0), 384, 260))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_margin(_help_panel, 16, 12).add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title: Label = _text_label(header, "Ovládání", 17, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button: Button = _button(header, "Zavřít", "CloseHelp")
	close_button.custom_minimum_size.x = 64
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.pressed.connect(_close_help)
	var shortcuts := GridContainer.new()
	shortcuts.columns = 2
	shortcuts.add_theme_constant_override("h_separation", 14)
	shortcuts.add_theme_constant_override("v_separation", 6)
	column.add_child(shortcuts)
	var entries: Array[Array] = [
		["Levé tlačítko", "Vybrat jednotku či budovu / umístit"],
		["Esc", "Zrušit nástroj / zavřít panel / menu"],
		["Prostřední tl. / WASD / šipky", "Posun kamery"],
		["Kolečko myši", "Přiblížení"], ["Mezerník", "Pauza / pokračovat"],
		["1–9, 0", "Zkratky staveb"], ["F5 / F9", "Uložit / načíst"],
		["F2 / R", "Pravidla terénu / reset ukázky"],
	]
	for entry: Array in entries:
		var key_label: Label = _text_label(shortcuts, String(entry[0]), 11, ACCENT)
		key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		key_label.custom_minimum_size.x = 132
		var action_label: Label = _text_label(shortcuts, String(entry[1]), 11)
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
	if building_inventory_label.visible or _detail_title.visible:
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
	_fit_stock_panel()


func _close_stocks() -> void:
	resource_hud_panel.visible = false
	_stock_toggle.set_pressed_no_signal(false)


func _close_help() -> void:
	_help_panel.visible = false
	_help_button.set_pressed_no_signal(false)


func _resource_tile(parent: Control, resource_id: String, summary: bool) -> void:
	var definition: Dictionary = _catalog.resources.get(resource_id, {}) as Dictionary
	var display_name: String = UiTextClass.resource_name(_catalog, resource_id)
	var icon_color := Color.from_string("#" + String(definition.get("color", "888888")), Color.GRAY)
	var item := HBoxContainer.new()
	item.name = ("Summary_" if summary else "Stock_") + resource_id
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not summary else Control.SIZE_SHRINK_BEGIN
	item.add_theme_constant_override("separation", 6)
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.tooltip_text = "%s: celková zásoba v osadě." % display_name
	parent.add_child(item)
	var icon: ResourceIconClass = ResourceIconClass.new()
	icon.configure(resource_id, icon_color)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(icon)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	item.add_child(column)
	# The repeated "total" caption next to every number was pure noise; the
	# meaning lives in the tooltip and the panel's own subtitle.
	var title: Label = _text_label(column, display_name, 10, MUTED)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 62 if summary else 84
	var amount: Label = _text_label(column, "0", 17 if summary else 15)
	amount.name = _node_token(resource_id) + "TotalAmount"
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	if summary:
		_summary_amounts[resource_id] = amount
		_summary_items[resource_id] = item
	else:
		var breakdown: Label = _text_label(column, _stock_breakdown_text(0, 0, 0), 10, MUTED)
		breakdown.name = _node_token(resource_id) + "StockBreakdown"
		breakdown.autowrap_mode = TextServer.AUTOWRAP_OFF
		breakdown.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_resource_items[resource_id] = item
		resource_amount_labels[resource_id] = amount
		resource_breakdown_labels[resource_id] = breakdown


## Node names stay ASCII and stable even though the visible names are Czech.
static func _node_token(resource_id: String) -> String:
	return resource_id.replace("_", " ").capitalize().replace(" ", "")


static func _stock_breakdown_text(warehouse: int, buildings: int, carried: int) -> String:
	return "Sklad %d · Budovy %d · Neseno %d" % [warehouse, buildings, carried]


func _hud_resource_ids() -> Array[String]:
	var ids: Array[String] = []
	for resource_id: String in _catalog.resources:
		ids.append(resource_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(_catalog.resources[a].get("hud_order", 1000)) < int(_catalog.resources[b].get("hud_order", 1000))
	)
	return ids


func _add_tool_button(parent: Control, text_value: String, mode: String, shortcut: String = "") -> void:
	# The shortcut digit goes into a leading badge instead of the label, so a
	# long Czech name keeps the whole button width for itself.
	var button: Button = _button(parent, ("%s  %s" % [shortcut, text_value]) if not shortcut.is_empty() else text_value, "Build_" + mode)
	button.custom_minimum_size.y = 38
	button.toggle_mode = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 11)
	var display_name: String = UiTextClass.building_name(_catalog, mode) if _catalog.buildings.has(mode) else text_value
	button.tooltip_text = display_name + "\n" + _build_mode_hint(mode)
	if not shortcut.is_empty():
		button.tooltip_text += "\nKlávesa: " + shortcut
	var cost: Dictionary = _build_cost(mode)
	if not cost.is_empty():
		button.tooltip_text += "\nStavba: " + _resource_amounts_text(cost)
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
	var stocks: Dictionary = world.resource_stocks()
	for resource_id: String in resource_amount_labels:
		var stock: Dictionary = stocks[resource_id]
		var total: String = str(stock["total"])
		var breakdown: String = _stock_breakdown_text(
			int(stock["warehouse"]), int(stock["buildings"]), int(stock["carried"]))
		var display_name: String = UiTextClass.resource_name(_catalog, resource_id)
		var tooltip: String = "%s — celkem %s\n%s\nCesty a vinná pole se platí ze skladu.\nSpotřebovaný materiál se už nezapočítává." % [display_name, total, breakdown]
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
	# A selected unit carrying nothing still counts as a selection, so the
	# "select something" placeholder must not key off the inventory line alone.
	var has_detail: bool = not selected_unit.is_empty() or not inventory_text.is_empty()
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
	_soldier_food_button.tooltip_text = "Pod %.0f %% sytosti lze vyžádat chléb, klobásu, víno nebo rybu. Nosič ji přinese ze skladu či od výrobce a obnoví plnou sytost. Voják zůstane na svém místě." % _soldier_feeding_percent()
	_selection_hint.text = "DETAIL JEDNOTKY" if not selected_unit.is_empty() else ("DETAIL BUDOVY" if building_id != 0 else "DETAIL POZEMKU")
	_refresh_detail_header(world, selected_cell, selected_unit, selected_building)
	_empty_selection.visible = not has_detail
	if (_selected_unit_id == 0 and selected_cell != _last_selection) or _last_unit_selection != _selected_unit_id:
		_last_selection = selected_cell
		_last_unit_selection = _selected_unit_id
		_inspector_scroll.scroll_vertical = 0
		if has_detail:
			_show_dock(true)
	if build_mode != _last_build_mode:
		_last_build_mode = build_mode
		show_build_tool(build_mode)
	for mode: String in _build_buttons:
		(_build_buttons[mode] as Button).set_pressed_no_signal(mode == build_mode)
	for speed: float in _speed_buttons:
		(_speed_buttons[speed] as Button).set_pressed_no_signal(is_equal_approx(speed, simulation_speed))
	mode_label.text = "Výběr / průzkum" if build_mode.is_empty() else "Umísťuješ: " + _tool_name(build_mode)
	_cancel_build.visible = not build_mode.is_empty()
	var cost: Dictionary = _build_cost(build_mode)
	_build_hint.text = "Stav na rovné zemi včetně plošin.\nTerén (F2) ukáže svahy a neprůchodné hory." if build_mode.is_empty() else _build_mode_hint(build_mode)
	if not cost.is_empty():
		_build_hint.text = "Cena: " + _resource_amounts_text(cost) + "\n" + _build_hint.text
	var counts: Dictionary = _food_summary(world)
	_citizens_label.text = "%s · %s" % [
		UiTextClass.citizens(int(counts["citizens"])), UiTextClass.soldiers(int(counts["soldiers"])),
	]
	_citizens_label.tooltip_text = _worker_summary_text(world, counts)
	var hungry: int = int(counts["hungry"])
	if hungry > 0:
		_citizens_label.text += " · %d hladoví" % hungry
	if int(counts["arriving"]) > 0:
		_citizens_label.text += " · %d jídlo na cestě" % int(counts["arriving"])
	_citizens_label.add_theme_color_override("font_color", WARN if hungry > 0 else MUTED)
	_supply_army_button.disabled = not world.economy_enabled or int(counts["eligible"]) == 0
	event_label.text = "" if world.event_log.is_empty() else String(world.event_log.front())
	event_label.tooltip_text = "\n".join(world.event_log)


## Placement tools cover buildings plus the two field kinds, which have no
## catalog entry of their own.
func _tool_name(mode: String) -> String:
	if mode == "field":
		return String(UiTextClass.FIELDS["wheat"])
	if mode == "vine_field":
		return String(UiTextClass.FIELDS["vine"])
	if mode == "road":
		return "Kamenná cesta"
	return UiTextClass.building_name(_catalog, mode)


## The name of the selected thing is a heading, not the first line of a text
## blob. Construction and production progress get a real bar next to it.
func _refresh_detail_header(world: SimulationWorldClass, selected_cell: Vector2i,
		worker: Dictionary, building: Dictionary) -> void:
	var title: String = ""
	if not worker.is_empty():
		title = "%s #%d" % [UiTextClass.unit_name(_catalog, String(worker["type"])), int(worker["id"])]
	elif not building.is_empty():
		title = UiTextClass.building_name(_catalog, String(building["type"]))
	elif world.field_id_at(selected_cell) != 0:
		var field: Dictionary = world.fields[world.field_id_at(selected_cell)] as Dictionary
		title = String(UiTextClass.FIELDS.get(String(field.get("kind", "wheat")), "Pole"))
	_detail_title.text = title
	_detail_title.visible = not title.is_empty()
	_refresh_progress(world, building)


func _refresh_progress(world: SimulationWorldClass, building: Dictionary) -> void:
	_progress_panel.visible = false
	if building.is_empty():
		return
	var foundation: int = int(building.get("foundation_work_remaining", 0))
	if foundation > 0:
		var total_work: int = maxi(1, int(building.get("foundation_work_total", foundation)))
		_set_progress("Srovnávání terénu", 100.0 * float(total_work - foundation) / float(total_work), ACCENT)
		return
	var remaining: int = int(building.get("construction_remaining", 0))
	if remaining > 0:
		var definition: Dictionary = _catalog.building(String(building["type"]))
		var total: int = maxi(1, int(definition.get("construction_ticks", 1)))
		_set_progress("Stavba", 100.0 * float(total - remaining) / float(total), ACCENT)
		return
	# Production runs on the building's process timer, which only exists while a
	# recipe is actually being worked; an idle workshop shows no bar at all.
	var process_remaining: int = int(building.get("process_remaining", 0))
	if process_remaining <= 0:
		return
	var recipe: Dictionary = _catalog.recipe(String(building.get("recipe_id",
		_catalog.building(String(building["type"])).get("recipe", ""))))
	var duration: int = int(recipe.get("duration_ticks", 0))
	if duration > 0:
		_set_progress("Výroba", 100.0 * float(duration - process_remaining) / float(duration), GOOD)


func _set_progress(label: String, percent: float, color: Color) -> void:
	var value: float = clampf(percent, 0.0, 100.0)
	_progress_panel.visible = true
	_progress_label.text = "%s · %d %%" % [label, int(round(value))]
	_progress_bar.value = value
	_progress_fill.bg_color = color


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
	var summary: String = "Obyvatelé %d • Nosiči %d • Lesníci %d\nVojáci %d • Hladoví %d\nVyžádané jídlo pro armádu %d • Na cestě %d\nPruhy ukazují sytost: 0 %% prázdno, 100 %% plno. Prázdná sytost neznamená okamžitou smrt. Samostatná rezerva vydrží bez jídla %.0f min při 1× a jídlo ji obnovuje postupně. Civilisté chodí do hostince sami, vojáky zásobuj ručně pod %.0f %% sytosti." % [
		counts["citizens"], counts["carrier"], counts["gardener"], counts["soldiers"], counts["hungry"],
		counts["requested"], counts["arriving"], _balance_days_minutes(float(_catalog.economy.get("nutrition_survival_days", 7))), _soldier_feeding_percent(),
	]
	return summary + "\nHlad nikdy nezpomalí chůzi."


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
	var counts: Dictionary = {"citizens": 0, "soldiers": 0, "hungry": 0, "requested": 0, "arriving": 0, "eligible": 0, "carrier": 0, "gardener": 0}
	var arriving: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if world.fog.enabled and not world.is_local_entity(worker):
			continue
		var role: String = String(worker["type"])
		var soldier: bool = _catalog.soldiers.has(role)
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
	var carrying: String = String(worker.get("carrying", ""))
	return "" if carrying.is_empty() else "Nese: " + UiTextClass.resource_name(_catalog, carrying)


func _unit_detail_text(world: SimulationWorldClass, worker: Dictionary) -> String:
	return _unit_food_text(world, worker)


func _unit_food_text(world: SimulationWorldClass, worker: Dictionary) -> String:
	if _catalog.soldiers.has(String(worker["type"])):
		return world.soldier_food_status(int(worker["id"])) + "\nJídlo lze vyžádat pod %.0f %% sytosti. Jedna donesená dávka obnoví plnou sytost a voják zůstane na svém místě." % _soldier_feeding_percent()
	if int(worker.get("meal_ticks_left", 0)) > 0:
		return "Pracoviště si drží a po dojedení se vrátí."
	if worker.get("action", "") == "eat":
		return "Jde se najíst do hostince. Pracoviště si během jídla drží."
	return "Civilisté si zásobený hostinec najdou sami, jakmile vyhladoví. Nosiči do něj vozí chléb, klobásy, víno a ryby."


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
	_satiety_label.text = "Sytost %.0f %% · %s" % [percent, UiTextClass.satiety_state(state)]
	_satiety_bar.value = percent
	_satiety_fill.bg_color = satiety_color(state)
	var hungry_percent: float = 100.0 * float(status["hungry_at"]) / float(maxi(1, int(_catalog.economy.get("condition_max", 2700))))
	_satiety_bar.tooltip_text = "Sytost: 0 %% prázdno, 100 %% plno. Prázdná sytost neznamená smrt.\nCivilisté si jdou pro jídlo při %.0f %%. Samostatná dlouhodobá rezerva vydrží %.0f herních dnů bez jídla.\nJídlo obnovuje sytost a postupně i rezervu; jedno sousto ji nevynuluje.\nPrvní %d dny nedostatku zůstává práce na plné účinnosti. Hlad nikdy nezpomalí chůzi." % [hungry_percent, float(status["seven_day_limit"]), int(_catalog.economy.get("nutrition_weakening_start_days", 2))]
	_satiety_timing.tooltip_text = ""
	if not world.economy_enabled:
		_satiety_timing.text = "V tomto scénáři je potřeba jídla vypnutá."
		return
	_satiety_timing.tooltip_text = _nutrition_timing_tooltip(status, simulation_speed, tick_seconds)
	if int(worker.get("meal_ticks_left", 0)) > 0:
		_satiety_timing.text = _meal_description(worker) + "\n" + _nutrition_summary_text(status)
		if simulation_speed <= 0.0:
			_satiety_timing.text += "\nSimulace je pozastavená."
		return
	var until_hungry: int = int(status["remaining_to_hungry_ticks"])
	var soldier: bool = _catalog.soldiers.has(String(worker["type"]))
	if soldier:
		_satiety_timing.text = "Jídlo lze vyžádat pod %.0f %% sytosti." % _soldier_feeding_percent()
	elif until_hungry > 0:
		_satiety_timing.text = "Hlad odhadem za %s." % _game_duration_text(until_hungry)
		if simulation_speed > 0.0:
			_satiety_timing.text += "\n" + _real_time_estimate(until_hungry, simulation_speed, tick_seconds)
	elif until_hungry < 0:
		_satiety_timing.text = "Při současné činnosti hlad nepostupuje."
	elif worker.get("action", "") == "eat":
		_satiety_timing.text = "Právě jde do hostince."
	elif not String(worker.get("carrying", "")).is_empty():
		_satiety_timing.text = "Hladoví; nejdřív doručí náklad, pak vyrazí do hostince."
	else:
		_satiety_timing.text = "Hladoví; po dokončení úkolu vyhledá zásobený hostinec."
	_satiety_timing.text += "\n" + _nutrition_summary_text(status)
	if state == "Starving":
		var remaining: int = int(status["remaining_to_starve_ticks"])
		if remaining >= 0:
			_satiety_timing.text += "\nPozor: bez jídla zbývá %s do smrti." % _game_duration_text(remaining)
			if simulation_speed > 0.0:
				_satiety_timing.text += "\n" + _real_time_estimate(remaining, simulation_speed, tick_seconds)
	if simulation_speed <= 0.0:
		_satiety_timing.text += "\nSimulace je pozastavená."


static func _nutrition_summary_text(status: Dictionary) -> String:
	var limit: float = float(status["seven_day_limit"])
	var remaining_days: float = clampf(limit - float(status["deficit_days"]), 0.0, limit)
	return "Rezerva jídla: %.0f / %.0f min při 1×\nPráce %.0f %% · chůze 100 %%" % [_balance_days_minutes(remaining_days), _balance_days_minutes(limit), float(status["work_efficiency_percent"])]


static func _nutrition_timing_tooltip(status: Dictionary, simulation_speed: float, tick_seconds: float) -> String:
	var remaining: int = int(status["remaining_to_starve_ticks"])
	var text: String = "Dlouhodobá rezerva je nezávislá na pruhu sytosti a jídlo ji obnovuje postupně.\nSytost ubývá stálým tempem."
	if remaining < 0:
		return text + "\nOdpočet rezervy je zastavený během jídla nebo když je potřeba jídla vypnutá."
	text += "\nRezerva bez dalšího jídla: %s." % _game_duration_text(remaining)
	return text + "\n" + _real_time_estimate(remaining, simulation_speed, tick_seconds)


static func _real_time_estimate(ticks: int, simulation_speed: float, tick_seconds: float) -> String:
	if simulation_speed <= 0.0:
		return "Simulace je pozastavená."
	return "Přibližně %s při rychlosti %.1f×." % [_duration_text(int(ceil(float(ticks) * tick_seconds / simulation_speed))), simulation_speed]


## Simulation time as it passes at 1x speed; the game has no calendar.
static func _game_duration_text(ticks: int) -> String:
	return _duration_text(maxi(0, int(ceil(float(ticks) * SimulationWorldClass.TICK_SECONDS)))) + " při 1×"


## Nutrition balance keeps historical 6,000-tick "days"; show them as minutes at 1x.
static func _balance_days_minutes(days: float) -> float:
	return days * float(NutritionClass.BALANCE_DAY_TICKS) * SimulationWorldClass.TICK_SECONDS / 60.0


static func _duration_text(seconds: int) -> String:
	return "%d min %02d s" % [seconds / 60, seconds % 60] if seconds >= 60 else "%d s" % seconds


func _meal_description(worker: Dictionary) -> String:
	var remaining: float = float(worker.get("meal_ticks_left", 0)) * SimulationWorldClass.TICK_SECONDS
	var course: Dictionary = worker.get("meal_course", {}) as Dictionary
	if course.is_empty():
		return "Dojídá v hostinci · zbývá %.1f s při 1×" % remaining
	var food: String = String(course.get("food", ""))
	var food_name: String = UiTextClass.resource_name(_catalog, food)
	return "Jí %s · v tomto chodu zbývá %.1f s při 1×" % [food_name, remaining]


func blocks_map_point(screen_position: Vector2) -> bool:
	if _root == null:
		return false
	# Test actual visible panels, not the full-screen transparent HUD root.
	# Include passive status panels: a click over their text must not build.
	for child: Node in _root.get_children():
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
			text = "Najeď na mapu pro náhled umístění."
		elif bool(preview.get("obscured", false)):
			text = String(preview.get("reason", "Nejdřív tuto oblast prozkoumej."))
			color = BAD
		else:
			text = "%s\nVýška %.1f · sklon %d" % [
				String(preview.get("reason", "")), float(preview.get("height", 0.0)), int(preview.get("slope", 0)),
			]
			color = GOOD if bool(preview.get("valid", false)) else BAD
			if bool(preview.get("needs_levelling", false)):
				color = Color("#f4c36a")
				text = "%s\nCílová výška %d · materiál dorazí potom" % [String(preview["reason"]), int(preview["foundation_target_height"])]
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
			var stage: int = world.field_growth_stage(field)
			var field_status: String = "Připravená půda • čeká na zasetí"
			if stage == 1:
				var progress: int = clampi(int(100.0 * float(field["age_ticks"]) / float(_field_growth_ticks(is_vine))), 0, 100)
				field_status = "%s roste • %d %%" % ["Réva" if is_vine else "Obilí", progress]
			elif stage == 2:
				field_status = "Zralá %s • připraveno ke sklizni" % ("réva" if is_vine else "úroda")
			return field_status
		var deposits: Dictionary = _world_deposits(world)
		for deposit: Dictionary in deposits.values():
			if deposit["position"] as Vector2i == selected_cell:
				var resource_id: String = String(deposit["resource"])
				return "Ložisko: %s\nZbývá: %d" % [UiTextClass.resource_name(_catalog, resource_id), int(deposit["amount"])]
		if world.grid.contains(selected_cell):
			var material: String = world.grid.base_terrain_at(selected_cell)
			var walking: String = "průchozí" if world.grid.is_walkable(selected_cell) else "neprůchozí"
			var building_rule: String = "rovná, zastavitelná zem" if world.grid.is_buildable(selected_cell) else "nelze stavět"
			return "%s\nVýška %.1f • sklon %d\n%s • %s" % [UiTextClass.terrain_name(material), world.grid.cell_height(selected_cell), world.grid.cell_slope(selected_cell), walking, building_rule]
		return ""
	var building: Dictionary = world.buildings[building_id] as Dictionary
	var building_type: String = String(building["type"])
	var definition: Dictionary = world.catalog.building(building_type)
	if world.fog.enabled and not world.is_local_entity(building):
		return "Cizí budova"
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
		return "Zásoby: prázdné"
	var inventory_parts: PackedStringArray = []
	for resource_id: String in resource_ids:
		if resource_ids.size() > 8 and int(inventory.get(resource_id, 0)) == 0:
			continue
		inventory_parts.append("%s %d" % [UiTextClass.resource_name(world.catalog, resource_id), int(inventory.get(resource_id, 0))])
	if inventory_parts.is_empty():
		return "Zásoby: prázdné"
	if inventory_parts.size() > 3:
		return "Zásoby\n%s" % "\n".join(inventory_parts)
	return "Zásoby: %s" % "  •  ".join(inventory_parts)


func _selected_production_text(world: SimulationWorldClass, selected_cell: Vector2i) -> String:
	if world.fog.enabled and not world.is_cell_explored(selected_cell):
		return ""
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0:
		var field_id: int = world.field_id_at(selected_cell)
		if field_id != 0:
			if String((world.fields[field_id] as Dictionary).get("kind", "wheat")) == "vine":
				return "Postav poblíž Vinici a vycvič Sedláka.\nRéva po sklizni doroste, Vinice z ní dělá víno."
			return "Sedlák ze Statku do 8 polí sem seje a sklízí.\nSetí → růst 20 s → sklizeň → obilí"
		for deposit: Dictionary in _world_deposits(world).values():
			if deposit["position"] as Vector2i == selected_cell:
				return "Postav u vody Rybářskou chatu." if String(deposit["resource"]) == "fish" else "Postav u tohoto ložiska odpovídající důl nebo Lom."
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
		lines.append("Srovnávání základů: %d %%" % progress if working else "Čeká na Stavitele — příprava terénu")
		lines.append("Zemní práce: %d %% · zbývá %.1f s při 1×" % [progress, float(remaining) * world.TICK_SECONDS])
		lines.append("Příprava terénu → materiál → stavba")
		lines.append(world.production_status(building))
		return "\n".join(lines)
	if int(building.get("construction_remaining", 0)) > 0:
		var total: int = maxi(1, int(definition.get("construction_ticks", 1)))
		var progress: int = clampi(int(100.0 * float(total - int(building["construction_remaining"])) / float(total)), 0, 100)
		lines.append("Stavba: %d %% • je potřeba Stavitel" % progress)
		var delivered: Dictionary = building.get("construction_delivered", {}) as Dictionary
		var material_parts: PackedStringArray = []
		var site_cost: Dictionary = world.construction_cost(building)
		for resource_id: String in site_cost:
			var cost: int = int(site_cost[resource_id])
			material_parts.append("%s %d/%d" % [UiTextClass.resource_name(_catalog, resource_id), int(delivered.get(resource_id, 0)), cost])
		lines.append("Dovezeno: " + "  •  ".join(material_parts))
		if int(building.get("construction_cost_revision", _catalog.CONSTRUCTION_COST_REVISION)) < _catalog.CONSTRUCTION_COST_REVISION:
			lines.append("Starší staveniště: původní cena zůstává. Nová staveniště používají současné ceny.")
		lines.append(world.production_status(building))
		return "\n".join(lines)
	if not worker_type.is_empty():
		var owner: Dictionary = world.workplace_worker(building_id)
		if world.fog.enabled and not owner.is_empty() and not world.is_local_entity(owner):
			owner = {}
		var profession_name: String = UiTextClass.unit_name(world.catalog, worker_type)
		if owner.is_empty():
			lines.append("Pracovník: %s • 0/1 • čeká na obsazení" % profession_name)
		else:
			var location: String = " • uvnitř" if world.is_worker_inside(owner) and int(owner.get("inside_building_id", 0)) == building_id else ""
			lines.append("Pracovník: %s #%d • 1/1%s" % [profession_name, int(owner["id"]), location])
			var satiety: Dictionary = world.hunger_status(owner)
			lines.append("Sytost %.0f %% · %s" % [float(satiety["satiety_percent"]), UiTextClass.satiety_state(String(satiety["state"]))])
			if world.economy_enabled:
				lines.append(_nutrition_summary_text(satiety))
			if int(owner.get("meal_ticks_left", 0)) > 0:
				lines.append(_meal_description(owner))
	var indoor_count: int = 0
	for worker: Dictionary in world.workers.values():
		if world.fog.enabled and not world.is_local_entity(worker):
			continue
		if world.is_worker_inside(worker) and int(worker.get("inside_building_id", 0)) == building_id:
			indoor_count += 1
	if indoor_count > 0:
		lines.append("Uvnitř: " + UiTextClass.citizens(indoor_count))
	if String(building["type"]) == "farm":
		lines.append("Obilná pole → obilí  •  pole stavíš klávesou 0")
	elif String(building["type"]) == "forester_hut":
		lines.append("Dosah sázení: %s od chaty" % UiTextClass.tiles(int(definition.get("planting_radius", 8))))
		lines.append("Sází stromky na dostupnou volnou zem. Lesníka vycvičíš ve Škole.")
	elif String(building["type"]) == "fisher_hut":
		lines.append("Dosah rybolovu: %s • je potřeba dostupné ložisko ryb" % UiTextClass.tiles(int(definition.get("extract_radius", 3))))
		lines.append("Ryby se skladují zde a nosiči je odvážejí. Rybáře vycvičíš ve Škole.")
	elif String(building["type"]) == "vineyard":
		lines.append("Vinná pole → víno • pole po sklizni dorostou")
	elif String(building["type"]) == "inn":
		lines.append("Místa u stolu: %d/%d obsazeno" % [world.inn_occupied_seats(building_id), int(definition.get("seating_capacity", 6))])
		var diner_ids: Array = world.workers.keys()
		diner_ids.sort()
		for diner_id: int in diner_ids:
			var diner: Dictionary = world.workers[diner_id]
			if world.fog.enabled and not world.is_local_entity(diner):
				continue
			if int(diner.get("inside_building_id", 0)) != building_id or int(diner.get("meal_ticks_left", 0)) <= 0:
				continue
			var satiety: Dictionary = world.hunger_status(diner)
			lines.append("%s #%d · Sytost %.0f %%\n%s" % [UiTextClass.unit_name(_catalog, String(diner["type"])), diner_id, float(satiety["satiety_percent"]), _meal_description(diner)])
			if world.economy_enabled:
				lines.append(_nutrition_summary_text(satiety))
		lines.append("Civilisté sem chodí sami, když vyhladoví, snědí až %d různé chody a vrátí se do práce." % int(_catalog.economy.get("max_meals_per_visit", 3)))
		lines.append("Nech sem nosiči vozit chléb, klobásy, víno nebo ryby. Vojáci dostávají jídlo na svá místa přes Přinést jídlo.")
	elif not recipe.is_empty():
		var recipe_inputs: Dictionary = recipe.get("inputs", {}) as Dictionary
		var source: String = "Blízké ložisko" if recipe_inputs.is_empty() else _resource_amounts_text(recipe_inputs)
		lines.append("Recept: %s → %s  •  %.0f s" % [
			source,
			_resource_amounts_text(recipe.get("outputs", {}) as Dictionary),
			float(recipe.get("duration_ticks", 0)) / 10.0,
		])
		var inputs: Dictionary = building.get("inputs", {}) as Dictionary
		var input_parts: PackedStringArray = []
		for resource_id_variant: Variant in definition.get("inputs", []) as Array:
			var resource_id: String = String(resource_id_variant)
			var resource_name: String = UiTextClass.resource_name(_catalog, resource_id)
			var amount: int = int(inputs.get(resource_id, 0))
			if definition.has("input_capacity"):
				input_parts.append("%s %d/%d" % [resource_name, amount, int(definition["input_capacity"])])
			else:
				input_parts.append("%s %d" % [resource_name, amount])
		if not input_parts.is_empty():
			lines.append("Vstupy: " + "  •  ".join(input_parts))
	if recipe.is_empty() and not (definition.get("inputs", []) as Array).is_empty():
		var supplied: Dictionary = {}
		for resource_id: String in building.get("inputs", {}) as Dictionary:
			var amount: int = int((building["inputs"] as Dictionary)[resource_id])
			if amount > 0:
				supplied[resource_id] = amount
		lines.append("Dodávky: " + (_resource_amounts_text(supplied) if not supplied.is_empty() else "čeká na dovoz"))
	var status: String = world.production_status(building)
	if not status.is_empty():
		lines.append(status)
	return "\n".join(lines)


func _world_deposits(world: SimulationWorldClass) -> Dictionary:
	var value: Variant = world.get("deposits")
	return value as Dictionary if value is Dictionary else {}


func _field_growth_ticks(is_vine: bool) -> int:
	var value: Variant = _catalog.get("economy")
	var economy: Dictionary = value as Dictionary if value is Dictionary else {}
	return int(economy.get("vine_growth_ticks" if is_vine else "wheat_growth_ticks", 160 if is_vine else 200))


func _resource_amounts_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for resource_id: String in amounts:
		parts.append(UiTextClass.resource_amount(resource_id, int(amounts[resource_id])))
	return " + ".join(parts)


func _build_mode_hint(mode: String) -> String:
	match mode:
		"field":
			return "Umísti na volnou trávu nebo hlínu do 8 polí od Statku."
		"vine_field":
			return "Vinná pole potřebují blízkou Vinici a 1 prkno."
		"quarry":
			return "Umísti na volnou zem do 3 polí od skály."
		"farm":
			return "Přidej poblíž obilná pole (0) a vycvič ve Škole Sedláka."
		"forester_hut":
			return "Vycvič ve Škole Lesníka. Sází stromy na dostupnou volnou zem do %s od chaty." % UiTextClass.tiles(int(_catalog.building(mode).get("planting_radius", 8)))
		"fisher_hut":
			return "Umísti k dostupnému ložisku ryb do %s. Rybáře vycvič ve Škole, ryby odvážejí nosiči." % UiTextClass.tiles(int(_catalog.building(mode).get("extract_radius", 3)))
		"mill", "bakery":
			return "Vycvič ve Škole Pekaře, suroviny dovezou nosiči."
		"inn":
			return "Civilisté se sem chodí najíst sami. %d míst; nosiči vozí chléb, klobásy, víno a ryby. Stav blízko pracovišť s volným vstupem." % int(_catalog.building(mode).get("seating_capacity", 6))
		"road":
			return "Kamenné cesty zrychlují dopravu. Nech pole volná."
	if not mode.is_empty():
		return UiTextClass.building_hint(_catalog, mode)
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
	var building_name: String = UiTextClass.building_name(world.catalog, String(building["type"]))
	var training_queue: Array = building.get("training_queue", []) as Array
	if training_queue.is_empty():
		return "  |  %s nečinná" % building_name
	var unit_type: String = String(training_queue[0])
	var unit_name: String = UiTextClass.unit_name(world.catalog, unit_type)
	return "  |  %s: %s %dt (%d ve frontě)" % [
		building_name,
		unit_name,
		int(building.get("training_remaining", 0)),
		training_queue.size(),
	]
