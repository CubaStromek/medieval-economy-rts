class_name EconomyActions
extends VBoxContainer

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const UiTextClass = preload("res://scripts/ui_text.gd")

signal unit_training_requested(unit_type: String)
signal production_order_requested(recipe_id: String)
signal recruitment_requested(soldier_type: String)
signal trade_requested(give_resource: String, receive_resource: String)

var training_panel: VBoxContainer
var _catalog: DefinitionCatalogClass
var _orders_panel: VBoxContainer
var _recruitment_panel: VBoxContainer
var _market_panel: VBoxContainer
var _training_status: Label
var _order_status: Label
var _recruitment_status: Label
var _market_rate: Label
var _market_give: OptionButton
var _market_receive: OptionButton
var _market_button: Button
var _selection_key: String = ""


func configure(catalog: DefinitionCatalogClass) -> void:
	_catalog = catalog
	name = "EconomyActions"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	training_panel = _section("SchoolTraining", "VÝCVIK OBYVATEL")
	var school: Dictionary = _catalog.building("school")
	var cost: Dictionary = school.get("training_cost", {}) as Dictionary
	_description(training_panel, "Cena za obyvatele: %s\nSpecialisté potřebují odpovídající pracoviště." % (_amounts(cost) if not cost.is_empty() else "zdarma"))
	_training_status = _status_label(training_panel)
	var grid: GridContainer = _grid(training_panel)
	for unit_type_variant: Variant in school.get("trains", []) as Array:
		var unit_type: String = String(unit_type_variant)
		var definition: Dictionary = _catalog.unit(unit_type)
		var button: Button = _button(grid, UiTextClass.unit_name(_catalog, unit_type))
		button.name = "Train_" + unit_type
		button.tooltip_text = "Vycvičit: %s\n%s\nCena: %s • %.0f s" % [
			UiTextClass.unit_name(_catalog, unit_type),
			_training_description(unit_type, definition),
			_amounts(cost) if not cost.is_empty() else "zdarma",
			float(definition.get("training_ticks", 0)) / 10.0,
		]
		button.pressed.connect(unit_training_requested.emit.bind(unit_type))
	_orders_panel = _section("ProductionOrders", "OBJEDNAT VÝZBROJ")
	_recruitment_panel = _section("Recruitment", "NÁBOR")
	_market_panel = _section("MarketExchange", "SMĚNA ZBOŽÍ")
	_description(_market_panel, "Nosiči doručí platbu a vyzvednou tvé zboží.")
	_market_give = _ware_selector(_market_panel, "Dám")
	_market_receive = _ware_selector(_market_panel, "Dostanu")
	if _market_receive.item_count > 1:
		_market_receive.select(1)
	_market_rate = _status_label(_market_panel)
	_market_button = _button(_market_panel, "Zařadit směnu")
	_market_button.pressed.connect(func() -> void:
		trade_requested.emit(_selected_ware(_market_give), _selected_ware(_market_receive))
	)
	for panel: VBoxContainer in [training_panel, _orders_panel, _recruitment_panel, _market_panel]:
		panel.visible = false


func _training_description(unit_type: String, definition: Dictionary) -> String:
	if unit_type == "gardener":
		var hut: Dictionary = _catalog.building("forester_hut")
		return "Lesník: potřebuje stavbu %s. Sází stromky na dostupnou volnou zem do %s od chaty. Jeden lesník na chatu." % [
			UiTextClass.building_name(_catalog, "forester_hut"), UiTextClass.tiles(int(hut.get("planting_radius", 8))),
		]
	if unit_type == "fisherman":
		var hut: Dictionary = _catalog.building("fisher_hut")
		return "Rybář: potřebuje stavbu %s u dostupného ložiska ryb do %s. Jeden rybář na chatu, ryby odvážejí nosiči." % [
			UiTextClass.building_name(_catalog, "fisher_hut"), UiTextClass.tiles(int(hut.get("extract_radius", 3))),
		]
	return String(definition.get("description", "Vycvičí profesi " + UiTextClass.unit_name(_catalog, unit_type) + "."))


func refresh(world: SimulationWorldClass, building: Dictionary) -> void:
	var definition: Dictionary = _catalog.building(String(building.get("type", "")))
	var key: String = "%d:%s" % [int(building.get("id", 0)), String(building.get("type", ""))]
	if key != _selection_key:
		_selection_key = key
		_rebuild_orders(definition)
		_rebuild_recruitment(definition)
	training_panel.visible = not (definition.get("trains", []) as Array).is_empty()
	_orders_panel.visible = bool(definition.get("needs_order", false))
	_recruitment_panel.visible = not (definition.get("recruits", []) as Array).is_empty()
	_market_panel.visible = String(building.get("type", "")) in ["marketplace", "market"]
	var construction: bool = int(building.get("construction_remaining", 0)) > 0
	for button_node: Node in find_children("*", "Button", true, false):
		(button_node as Button).disabled = construction
	if training_panel.visible:
		var queue: Array = building.get("training_queue", []) as Array
		_training_status.text = "Fronta výcviku: %d / %d" % [queue.size(), int(definition.get("queue_capacity", 5))]
		if not queue.is_empty():
			_training_status.text += "\n%s • zbývá %.1f s" % [
				UiTextClass.unit_name(_catalog, String(queue[0])),
				float(building.get("training_remaining", 0)) / 10.0,
			]
		if construction:
			_training_status.text = "Výcvik se otevře po dokončení stavby."
	if _orders_panel.visible and _order_status != null:
		_order_status.text = "Objednávek ve frontě: %d" % (building.get("production_queue", []) as Array).size()
	if _recruitment_panel.visible and _recruitment_status != null:
		var service_queue: Array = building.get("service_queue", []) as Array
		_recruitment_status.text = "Fronta náboru: %d" % service_queue.size()
		if not service_queue.is_empty():
			var next_unit: String = String((service_queue[0] as Dictionary).get("unit", ""))
			_recruitment_status.text += " • další: " + UiTextClass.unit_name(_catalog, next_unit)
	if _market_panel.visible:
		var give: String = _selected_ware(_market_give)
		var receive: String = _selected_ware(_market_receive)
		var amounts: Dictionary = {}
		if give != receive and world.has_method("trade_amounts"):
			amounts = world.call("trade_amounts", give, receive) as Dictionary
		_market_button.disabled = construction or amounts.is_empty()
		_market_rate.text = "%d %s → %d %s" % [int(amounts.get("give", 0)), _ware_name(give), int(amounts.get("receive", 0)), _ware_name(receive)] if not amounts.is_empty() else "Vyber dvě různá zboží."
		_market_rate.text += "\nSměn ve frontě: %d" % (building.get("service_queue", []) as Array).size()


func _rebuild_orders(definition: Dictionary) -> void:
	_clear_section(_orders_panel)
	_order_status = _status_label(_orders_panel)
	for recipe_id_variant: Variant in definition.get("recipes", []) as Array:
		var recipe_id: String = String(recipe_id_variant)
		var recipe: Dictionary = _catalog.recipe(recipe_id)
		var outputs: String = _amounts(recipe.get("outputs", {}) as Dictionary)
		var inputs: String = _amounts(recipe.get("inputs", {}) as Dictionary)
		var row: VBoxContainer = _action_row(_orders_panel)
		var button: Button = _button(row, "Objednat " + outputs)
		button.name = "Order_" + recipe_id
		button.tooltip_text = "%s → %s • %.0f s" % [inputs, outputs, float(recipe.get("duration_ticks", 0)) / 10.0]
		button.pressed.connect(production_order_requested.emit.bind(recipe_id))
		var requirement: Label = _description(row, "Potřebuje %s • %.0f s" % [inputs, float(recipe.get("duration_ticks", 0)) / 10.0])
		requirement.tooltip_text = "Suroviny na jednu objednávku"


func _rebuild_recruitment(definition: Dictionary) -> void:
	_clear_section(_recruitment_panel)
	_recruitment_status = _status_label(_recruitment_panel)
	var soldiers_value: Variant = _catalog.get("soldiers")
	var soldiers: Dictionary = soldiers_value as Dictionary if soldiers_value is Dictionary else {}
	for soldier_id_variant: Variant in definition.get("recruits", []) as Array:
		var soldier_id: String = String(soldier_id_variant)
		var soldier: Dictionary = soldiers.get(soldier_id, {}) as Dictionary
		var cost: String = _amounts(soldier.get("equipment", {}) as Dictionary)
		if bool(soldier.get("requires_recruit", false)):
			cost += " + 1 rekrut"
		var row: VBoxContainer = _action_row(_recruitment_panel)
		var button: Button = _button(row, UiTextClass.unit_name(_catalog, soldier_id))
		button.name = "Recruit_" + soldier_id
		button.tooltip_text = "Vystrojí se, jakmile do Kasáren dorazí rekrut a potřebné zboží; žádná další prodleva výcviku." if bool(soldier.get("requires_recruit", false)) else "Naverbuje se, jakmile dorazí platba a je volný východ; žádná další prodleva výcviku."
		button.pressed.connect(recruitment_requested.emit.bind(soldier_id))
		_description(row, "Potřebuje " + cost)


func _action_row(parent: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


func _clear_section(panel: VBoxContainer) -> void:
	for child: Node in panel.get_children():
		if child.get_index() == 0:
			continue
		panel.remove_child(child)
		child.queue_free()


func _section(node_name: String, heading: String) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 9)
	add_child(panel)
	var title: Label = _label(panel, heading)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.82, 0.86))
	return panel


func _label(parent: Control, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	return label


func _description(parent: Control, value: String) -> Label:
	var label: Label = _label(parent, value)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.70, 0.77, 0.81))
	return label


func _status_label(parent: Control) -> Label:
	var label: Label = _label(parent, "")
	label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.57))
	return label


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


func _button(parent: Control, value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.tooltip_text = value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.clip_text = true
	button.custom_minimum_size.y = 34.0
	parent.add_child(button)
	return button


func _ware_selector(parent: Control, title: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label: Label = _label(row, title)
	label.custom_minimum_size.x = 55.0
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_theme_font_size_override("font_size", 13)
	row.add_child(selector)
	for resource_id: String in _catalog.resources:
		selector.add_item(_ware_name(resource_id))
		selector.set_item_metadata(selector.item_count - 1, resource_id)
	return selector


func _selected_ware(selector: OptionButton) -> String:
	return String(selector.get_selected_metadata()) if selector.selected >= 0 else ""


func _ware_name(resource_id: String) -> String:
	return UiTextClass.resource_name(_catalog, resource_id)


func _amounts(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for resource_id: String in amounts:
		parts.append(UiTextClass.resource_amount(resource_id, int(amounts[resource_id])))
	return " + ".join(parts)
