class_name GameHud
extends CanvasLayer

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const ResourceIconClass = preload("res://scripts/view/resource_icon.gd")

signal build_mode_requested(mode: String)
signal simulation_speed_requested(speed: float)
signal unit_training_requested(unit_type: String)

var resource_hud_panel: PanelContainer
var resource_amount_labels: Dictionary = {}
var resource_pipeline_labels: Dictionary = {}
var building_inventory_label: Label
var mode_label: Label
var event_label: Label

var _catalog: DefinitionCatalogClass


func configure(catalog: DefinitionCatalogClass) -> void:
	_catalog = catalog
	name = "HudLayer"
	_build_ui()


func _build_ui() -> void:
	var layer: CanvasLayer = self
	_build_resource_hud(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(455, 0)
	layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var title := Label.new()
	title.text = "MEDIEVAL ECONOMY RTS"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	building_inventory_label = Label.new()
	building_inventory_label.name = "BuildingInventoryLabel"
	building_inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	building_inventory_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
	building_inventory_label.add_theme_font_size_override("font_size", 15)
	column.add_child(building_inventory_label)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	column.add_child(toolbar)
	_add_tool_button(toolbar, "1  Stone road", "road")
	_add_tool_button(toolbar, "2  Store", "warehouse")
	_add_tool_button(toolbar, "3  Hut", "lumber_hut")
	_add_tool_button(toolbar, "4  Sawmill", "sawmill")

	var training_toolbar := HBoxContainer.new()
	training_toolbar.add_theme_constant_override("separation", 5)
	column.add_child(training_toolbar)
	_add_tool_button(training_toolbar, "5  School", "school")
	_add_training_button(training_toolbar, "Train Carrier", "carrier")
	_add_training_button(training_toolbar, "Train Lumberjack", "lumberjack")
	_add_training_button(training_toolbar, "Train Gardener", "gardener")

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 5)
	column.add_child(speed_row)
	var speed_title := Label.new()
	speed_title.text = "Speed"
	speed_title.custom_minimum_size.x = 58.0
	speed_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_row.add_child(speed_title)
	_add_speed_button(speed_row, "Pause", 0.0)
	_add_speed_button(speed_row, "0.5×", 0.5)
	_add_speed_button(speed_row, "1×", 1.0)
	_add_speed_button(speed_row, "2×", 2.0)

	mode_label = Label.new()
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(mode_label)

	var help := Label.new()
	help.text = "L lumberjack  •  C carrier  •  G autonomous gardener\nground 6t  •  trail 4t  •  stone 2t\nLMB build/select  •  select a School to train units\nMMB drag  •  wheel zoom  •  WASD pan\nSpace pause  •  F5/F9 save/load  •  R reset"
	help.modulate = Color(0.76, 0.79, 0.75)
	help.add_theme_font_size_override("font_size", 12)
	column.add_child(help)

	event_label = Label.new()
	event_label.position = Vector2(18, 580)
	event_label.size = Vector2(520, 110)
	event_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.67))
	event_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	event_label.add_theme_constant_override("shadow_offset_x", 1)
	event_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(event_label)


func _build_resource_hud(layer: CanvasLayer) -> void:
	resource_hud_panel = PanelContainer.new()
	resource_hud_panel.name = "ResourceStatusBar"
	resource_hud_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	resource_hud_panel.offset_left = -550.0
	resource_hud_panel.offset_right = -18.0
	resource_hud_panel.offset_top = 18.0
	resource_hud_panel.offset_bottom = 82.0
	resource_hud_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	resource_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.065, 0.055, 0.94)
	panel_style.border_color = Color(0.39, 0.37, 0.27, 0.96)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	resource_hud_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(resource_hud_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_hud_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "ResourceItems"
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var heading := VBoxContainer.new()
	heading.custom_minimum_size.x = 72.0
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 0)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(heading)

	var heading_label := Label.new()
	heading_label.text = "STOCKPILE"
	heading_label.add_theme_font_size_override("font_size", 12)
	heading_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.63))
	heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(heading_label)

	var heading_hint := Label.new()
	heading_hint.text = "stored  + flow"
	heading_hint.add_theme_font_size_override("font_size", 9)
	heading_hint.add_theme_color_override("font_color", Color(0.54, 0.58, 0.52))
	heading_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(heading_hint)

	var resource_ids: Array[String] = _hud_resource_ids()
	for resource_index: int in range(resource_ids.size()):
		var separator := VSeparator.new()
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(separator)
		_add_resource_hud_item(row, resource_ids[resource_index])


func _add_resource_hud_item(parent: HBoxContainer, resource_id: String) -> void:
	var definition: Dictionary = _catalog.resources.get(resource_id, {}) as Dictionary
	var display_name: String = String(definition.get(
		"display_name",
		resource_id.replace("_", " ").capitalize()
	))
	var icon_color := Color.from_string(
		"#" + String(definition.get("color", "888888")),
		Color(0.55, 0.55, 0.55)
	)

	var item := HBoxContainer.new()
	item.name = "%sResourceItem" % display_name.replace(" ", "")
	item.custom_minimum_size.x = 116.0
	item.add_theme_constant_override("separation", 7)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.tooltip_text = "%s: stored stockpile; + value is carried or waiting in production." % display_name
	parent.add_child(item)

	var icon: ResourceIconClass = ResourceIconClass.new()
	icon.name = "%sIcon" % display_name.replace(" ", "")
	icon.configure(resource_id, icon_color)
	item.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", -2)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(text_column)

	var name_label := Label.new()
	name_label.text = display_name.to_upper()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.68, 0.71, 0.64))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(name_label)

	var values := HBoxContainer.new()
	values.add_theme_constant_override("separation", 5)
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(values)

	var amount_label := Label.new()
	amount_label.name = "%sStoredAmount" % display_name.replace(" ", "")
	amount_label.text = "0"
	amount_label.add_theme_font_size_override("font_size", 20)
	amount_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.84))
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_child(amount_label)
	resource_amount_labels[resource_id] = amount_label

	var pipeline_label := Label.new()
	pipeline_label.name = "%sPipelineAmount" % display_name.replace(" ", "")
	pipeline_label.text = "+0"
	pipeline_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	pipeline_label.add_theme_font_size_override("font_size", 11)
	pipeline_label.add_theme_color_override("font_color", icon_color.lightened(0.28))
	pipeline_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_child(pipeline_label)
	resource_pipeline_labels[resource_id] = pipeline_label


func _hud_resource_ids() -> Array[String]:
	var resource_ids: Array[String] = []
	for resource_id_variant: Variant in _catalog.resources.keys():
		resource_ids.append(String(resource_id_variant))
	resource_ids.sort_custom(func(a: String, b: String) -> bool:
		var a_definition: Dictionary = _catalog.resources.get(a, {}) as Dictionary
		var b_definition: Dictionary = _catalog.resources.get(b, {}) as Dictionary
		var a_order: int = int(a_definition.get("hud_order", 1000))
		var b_order: int = int(b_definition.get("hud_order", 1000))
		return a_order < b_order or (a_order == b_order and a < b)
	)
	return resource_ids


func _add_tool_button(parent: Control, text_value: String, mode: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(build_mode_requested.emit.bind(mode))
	parent.add_child(button)


func _add_speed_button(parent: Control, text_value: String, speed: float) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(simulation_speed_requested.emit.bind(speed))
	parent.add_child(button)


func _add_training_button(parent: Control, text_value: String, unit_type: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(unit_training_requested.emit.bind(unit_type))
	parent.add_child(button)


func refresh(
	world: SimulationWorldClass,
	selected_cell: Vector2i,
	build_mode: String,
	simulation_speed: float,
	tick_seconds: float
) -> void:
	if resource_hud_panel == null:
		return
	for resource_id_variant: Variant in resource_amount_labels.keys():
		var resource_id: String = String(resource_id_variant)
		var amount_label: Label = resource_amount_labels[resource_id] as Label
		var pipeline_label: Label = resource_pipeline_labels[resource_id] as Label
		amount_label.text = str(world.stored_amount(resource_id))
		pipeline_label.text = "+%d" % world.pipeline_amount(resource_id)
	var inventory_text: String = _selected_building_inventory_text(world, selected_cell)
	building_inventory_label.text = inventory_text
	building_inventory_label.visible = not inventory_text.is_empty()
	var readable_mode: String = "Selection only"
	if not build_mode.is_empty():
		readable_mode = "Build: Stone road" if build_mode == "road" else "Build: " + build_mode.replace("_", " ").capitalize()
	var speed_text: String = "paused" if is_zero_approx(simulation_speed) else "%.1f×" % simulation_speed
	var training_text: String = _selected_training_text(world, selected_cell)
	mode_label.text = "%s  |  time %.1fs  |  %s  |  tasks %d%s\n%s\nDirt trail %d tiles  •  stone road %d tiles" % [
		readable_mode,
		float(world.tick) * tick_seconds,
		speed_text,
		world.task_board.active_count(),
		training_text,
		_worker_summary_text(world),
		world.grid.dirt_trails.size(),
		world.grid.roads.size(),
	]
	event_label.text = "\n".join(world.event_log)


func _worker_summary_text(world: SimulationWorldClass) -> String:
	var counts: Dictionary = {"lumberjack": 0, "carrier": 0, "gardener": 0}
	var gardeners_planting: int = 0
	var gardeners_moving: int = 0
	for worker_variant: Variant in world.workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		var unit_type: String = String(worker["type"])
		counts[unit_type] = int(counts.get(unit_type, 0)) + 1
		if unit_type != "gardener" or String(worker["action"]) != "plant_sapling":
			continue
		if String(worker["state"]) == "working":
			gardeners_planting += 1
		elif String(worker["state"]) == "moving":
			gardeners_moving += 1
	return "Units L%d  C%d  G%d  •  gardeners moving %d / planting %d" % [
		int(counts["lumberjack"]),
		int(counts["carrier"]),
		int(counts["gardener"]),
		gardeners_moving,
		gardeners_planting,
	]


func _selected_building_inventory_text(world: SimulationWorldClass, selected_cell: Vector2i) -> String:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0:
		return ""
	var building: Dictionary = world.buildings[building_id] as Dictionary
	var building_type: String = String(building["type"])
	var definition: Dictionary = world.catalog.building(building_type)
	var building_name: String = String(definition.get("display_name", building_type))
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
	else:
		inventory = building.get("outputs", {}) as Dictionary
		for resource_id_variant: Variant in definition.get("outputs", []) as Array:
			resource_ids.append(String(resource_id_variant))

	if resource_ids.is_empty():
		return "%s\nInventory: empty" % building_name
	var inventory_parts: PackedStringArray = []
	for resource_id: String in resource_ids:
		var resource_definition: Dictionary = world.catalog.resources.get(resource_id, {}) as Dictionary
		var resource_name: String = String(resource_definition.get(
			"display_name",
			resource_id.replace("_", " ").capitalize()
		))
		inventory_parts.append("%s: %d" % [resource_name, int(inventory.get(resource_id, 0))])
	return "%s\nInventory: %s" % [building_name, "  •  ".join(inventory_parts)]


func _selected_training_text(world: SimulationWorldClass, selected_cell: Vector2i) -> String:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0:
		return ""
	var building: Dictionary = world.buildings[building_id] as Dictionary
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
