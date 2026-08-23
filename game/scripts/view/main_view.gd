extends Node2D

const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")

const TILE_WIDTH: float = 64.0
const TILE_HEIGHT: float = 32.0
const FIXED_TICK_SECONDS: float = 0.1
const MAX_TICKS_PER_FRAME: int = 8

var world: SimulationWorldClass
var selected_cell := Vector2i(-1, -1)
var build_mode: String = ""
var accumulator: float = 0.0
var dragging_camera: bool = false
var simulation_speed: float = 0.5
var speed_before_pause: float = 0.5

@onready var camera: Camera2D = $Camera2D
var stock_label: Label
var mode_label: Label
var event_label: Label


func _ready() -> void:
	world = SimulationWorldClass.new()
	world.setup_demo()
	_build_ui()
	_update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	_handle_keyboard_camera(delta)
	accumulator += minf(delta * simulation_speed, FIXED_TICK_SECONDS * float(MAX_TICKS_PER_FRAME))
	var ticks_run: int = 0
	while accumulator >= FIXED_TICK_SECONDS and ticks_run < MAX_TICKS_PER_FRAME:
		world.step_tick()
		accumulator -= FIXED_TICK_SECONDS
		ticks_run += 1
	_update_ui()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			dragging_camera = mouse_button.pressed
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(camera.zoom.x * 1.12)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(camera.zoom.x / 1.12)
			get_viewport().set_input_as_handled()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			var canvas_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * mouse_button.position
			selected_cell = _world_to_grid(canvas_position)
			_apply_build_mode(selected_cell)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging_camera:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		camera.position -= motion.relative / camera.zoom.x
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_1:
				_set_build_mode("road")
			KEY_2:
				_set_build_mode("warehouse")
			KEY_3:
				_set_build_mode("lumber_hut")
			KEY_4:
				_set_build_mode("sawmill")
			KEY_ESCAPE:
				_set_build_mode("")
			KEY_F5:
				world._push_event("Game saved." if SaveSystemClass.save_world(world) else "Save failed.")
			KEY_F9:
				world._push_event("Game loaded." if SaveSystemClass.load_world(world) else "No valid save found.")
			KEY_R:
				_reset_demo()
			KEY_SPACE:
				_toggle_pause()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if world == null:
		return
	_draw_terrain()
	_draw_selection()
	_draw_trees()
	_draw_buildings()
	_draw_workers()


func _draw_terrain() -> void:
	for y: int in range(world.grid.size.y):
		for x: int in range(world.grid.size.x):
			var cell := Vector2i(x, y)
			var center: Vector2 = _grid_to_world(cell)
			var shade: float = 0.02 if (x + y) % 2 == 0 else -0.01
			var color := Color(0.23 + shade, 0.38 + shade, 0.22 + shade)
			_draw_diamond(center, color, Color(0.12, 0.20, 0.13, 0.7))
			var wear: int = int(world.grid.traffic_wear.get(cell, 0))
			if wear > 0 and not world.grid.dirt_trails.has(cell) and not world.grid.roads.has(cell):
				var wear_ratio: float = clampf(
					float(wear) / float(world.grid.carrier_passes_to_form_trail()),
					0.0,
					1.0
				)
				var half_width: float = lerpf(8.0, 17.0, wear_ratio)
				var half_height: float = lerpf(2.0, 5.0, wear_ratio)
				var wear_points := PackedVector2Array([
					center + Vector2(0, -half_height),
					center + Vector2(half_width, 0),
					center + Vector2(0, half_height),
					center + Vector2(-half_width, 0),
				])
				draw_colored_polygon(wear_points, Color(0.44, 0.31, 0.18, 0.25 + wear_ratio * 0.35))
			if world.grid.dirt_trails.has(cell):
				var dirt_points := PackedVector2Array([
					center + Vector2(0, -7),
					center + Vector2(19, 0),
					center + Vector2(0, 7),
					center + Vector2(-19, 0),
				])
				draw_colored_polygon(dirt_points, Color(0.47, 0.35, 0.22))
			if world.grid.roads.has(cell):
				var stone_points := PackedVector2Array([
					center + Vector2(0, -10),
					center + Vector2(24, 0),
					center + Vector2(0, 10),
					center + Vector2(-24, 0),
				])
				draw_colored_polygon(stone_points, Color(0.47, 0.49, 0.47))
				draw_polyline(
					PackedVector2Array([center + Vector2(-16, 0), center + Vector2(16, 0)]),
					Color(0.66, 0.67, 0.63),
					1.0
				)


func _draw_selection() -> void:
	if not world.grid.contains(selected_cell):
		return
	var center: Vector2 = _grid_to_world(selected_cell)
	var points := PackedVector2Array([
		center + Vector2(0, -TILE_HEIGHT * 0.5),
		center + Vector2(TILE_WIDTH * 0.5, 0),
		center + Vector2(0, TILE_HEIGHT * 0.5),
		center + Vector2(-TILE_WIDTH * 0.5, 0),
		center + Vector2(0, -TILE_HEIGHT * 0.5),
	])
	draw_polyline(points, Color(1.0, 0.86, 0.28), 3.0, true)


func _draw_trees() -> void:
	var tree_entries: Array = world.trees.values()
	tree_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap: Vector2i = a["position"] as Vector2i
		var bp: Vector2i = b["position"] as Vector2i
		return ap.x + ap.y < bp.x + bp.y
	)
	for tree_variant: Variant in tree_entries:
		var tree: Dictionary = tree_variant as Dictionary
		var center: Vector2 = _grid_to_world(tree["position"] as Vector2i)
		draw_rect(Rect2(center + Vector2(-3, -19), Vector2(6, 20)), Color(0.31, 0.18, 0.08))
		draw_circle(center + Vector2(0, -24), 13.0, Color(0.10, 0.33, 0.15))
		draw_circle(center + Vector2(-7, -19), 9.0, Color(0.13, 0.42, 0.18))
		draw_string(ThemeDB.fallback_font, center + Vector2(9, -23), str(tree["amount"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_buildings() -> void:
	var building_entries: Array = world.buildings.values()
	building_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap: Vector2i = a["position"] as Vector2i
		var bp: Vector2i = b["position"] as Vector2i
		return ap.x + ap.y < bp.x + bp.y
	)
	for building_variant: Variant in building_entries:
		var building: Dictionary = building_variant as Dictionary
		var center: Vector2 = _grid_to_world(building["position"] as Vector2i)
		var definition: Dictionary = world.catalog.building(String(building["type"]))
		var base_color: Color = Color.from_string("#" + String(definition.get("color", "888888")), Color.GRAY)
		var wall := PackedVector2Array([
			center + Vector2(-23, -5), center + Vector2(0, 7),
			center + Vector2(23, -5), center + Vector2(23, -31),
			center + Vector2(0, -18), center + Vector2(-23, -31),
		])
		draw_colored_polygon(wall, base_color.darkened(0.18))
		var roof := PackedVector2Array([
			center + Vector2(-27, -29), center + Vector2(0, -47),
			center + Vector2(27, -29), center + Vector2(0, -12),
		])
		draw_colored_polygon(roof, base_color.lightened(0.08))
		draw_string(ThemeDB.fallback_font, center + Vector2(-30, 22), String(definition.get("display_name", building["type"])), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(0.95, 0.95, 0.86))


func _draw_workers() -> void:
	var frame_alpha: float = clampf(accumulator / FIXED_TICK_SECONDS, 0.0, 1.0)
	for worker_variant: Variant in world.workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		var previous: Vector2 = _grid_to_world(worker["previous_position"] as Vector2i)
		var current: Vector2 = _grid_to_world(worker["position"] as Vector2i)
		var movement_alpha: float = worker_lerp_alpha(worker, frame_alpha)
		var center: Vector2 = previous.lerp(current, movement_alpha) + Vector2(0, -10)
		var unit_type: String = String(worker.get("type", "carrier"))
		var unit_definition: Dictionary = world.catalog.unit(unit_type)
		var unit_color: Color = Color.from_string(
			"#" + String(unit_definition.get("color", "d7a13f")),
			Color(0.94, 0.81, 0.42)
		)
		draw_circle(center, 7.0, unit_color)
		draw_circle(center + Vector2(0, -8), 4.0, Color(0.84, 0.68, 0.51))
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-3, 4),
			"L" if unit_type == "lumberjack" else "C",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color(0.12, 0.12, 0.10)
		)
		var carrying: String = String(worker["carrying"])
		if not carrying.is_empty():
			draw_rect(Rect2(center + Vector2(7, -4), Vector2(8, 8)), Color(0.55, 0.34, 0.17) if carrying == "log" else Color(0.82, 0.66, 0.40))


func _draw_diamond(center: Vector2, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -TILE_HEIGHT * 0.5),
		center + Vector2(TILE_WIDTH * 0.5, 0),
		center + Vector2(0, TILE_HEIGHT * 0.5),
		center + Vector2(-TILE_WIDTH * 0.5, 0),
	])
	draw_colored_polygon(points, fill)
	var closed := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	draw_polyline(closed, outline, 1.0, true)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(365, 0)
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

	stock_label = Label.new()
	stock_label.add_theme_font_size_override("font_size", 16)
	column.add_child(stock_label)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 5)
	column.add_child(toolbar)
	_add_tool_button(toolbar, "1  Stone road", "road")
	_add_tool_button(toolbar, "2  Store", "warehouse")
	_add_tool_button(toolbar, "3  Hut", "lumber_hut")
	_add_tool_button(toolbar, "4  Sawmill", "sawmill")

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
	help.text = "L lumberjack  •  C carrier  •  grass 6t  •  dirt 4t  •  stone 2t\nLMB build/select  •  MMB drag  •  wheel zoom\nWASD pan  •  Space pause  •  F5/F9 save/load  •  R reset"
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


func _add_tool_button(parent: Control, text_value: String, mode: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(_set_build_mode.bind(mode))
	parent.add_child(button)


func _add_speed_button(parent: Control, text_value: String, speed: float) -> void:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(_set_simulation_speed.bind(speed))
	parent.add_child(button)


func _set_build_mode(mode: String) -> void:
	build_mode = mode
	_update_ui()


func _set_simulation_speed(speed: float) -> void:
	simulation_speed = speed
	if speed > 0.0:
		speed_before_pause = speed
	_update_ui()


func _toggle_pause() -> void:
	_set_simulation_speed(speed_before_pause if is_zero_approx(simulation_speed) else 0.0)


func _apply_build_mode(cell: Vector2i) -> void:
	if not world.grid.contains(cell) or build_mode.is_empty():
		return
	var success: bool
	if build_mode == "road":
		success = world.place_road(cell)
	else:
		success = world.place_building(build_mode, cell) != 0
	if not success:
		world._push_event("Cannot build there.")


func _update_ui() -> void:
	if stock_label == null:
		return
	stock_label.text = "Logs  %d (+%d in pipeline)    Planks  %d (+%d)" % [
		world.stored_amount("log"), world.pipeline_amount("log"),
		world.stored_amount("plank"), world.pipeline_amount("plank"),
	]
	var readable_mode: String = "Selection only"
	if not build_mode.is_empty():
		readable_mode = "Build: Stone road" if build_mode == "road" else "Build: " + build_mode.replace("_", " ").capitalize()
	var speed_text: String = "paused" if is_zero_approx(simulation_speed) else "%.1f×" % simulation_speed
	mode_label.text = "%s  |  time %.1fs  |  %s  |  tasks %d\nDirt trail %d tiles  •  stone road %d tiles" % [
		readable_mode,
		float(world.tick) * FIXED_TICK_SECONDS,
		speed_text,
		world.task_board.active_count(),
		world.grid.dirt_trails.size(),
		world.grid.roads.size(),
	]
	event_label.text = "\n".join(world.event_log)


func _handle_keyboard_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction != Vector2.ZERO:
		camera.position += direction.normalized() * 430.0 * delta / camera.zoom.x


func _set_zoom(value: float) -> void:
	var clamped: float = clampf(value, 0.55, 2.4)
	camera.zoom = Vector2(clamped, clamped)


func _reset_demo() -> void:
	world = SimulationWorldClass.new()
	world.setup_demo()
	accumulator = 0.0
	selected_cell = Vector2i(-1, -1)


static func _grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * TILE_WIDTH * 0.5,
		float(cell.x + cell.y) * TILE_HEIGHT * 0.5
	)


static func _world_to_grid(position: Vector2) -> Vector2i:
	var column: float = (position.x / (TILE_WIDTH * 0.5) + position.y / (TILE_HEIGHT * 0.5)) * 0.5
	var row: float = (position.y / (TILE_HEIGHT * 0.5) - position.x / (TILE_WIDTH * 0.5)) * 0.5
	return Vector2i(roundi(column), roundi(row))


static func worker_lerp_alpha(worker: Dictionary, frame_alpha: float) -> float:
	var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
	var progress: int = clampi(int(worker.get("visual_progress_ticks", duration)), 0, duration)
	return clampf((float(progress) + frame_alpha) / float(duration), 0.0, 1.0)
