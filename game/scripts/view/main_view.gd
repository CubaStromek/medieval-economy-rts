extends Node2D

const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const TerrainRendererClass = preload("res://scripts/view/terrain_renderer.gd")
const GameHudClass = preload("res://scripts/view/game_hud.gd")

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
@onready var terrain_renderer: TerrainRendererClass = $TerrainRenderer
var hud: GameHudClass

# Existing view clients can inspect HUD state without owning or rebuilding controls.
var resource_hud_panel: PanelContainer:
	get:
		return hud.resource_hud_panel if hud != null else null
var resource_amount_labels: Dictionary:
	get:
		return hud.resource_amount_labels if hud != null else {}
var resource_pipeline_labels: Dictionary:
	get:
		return hud.resource_pipeline_labels if hud != null else {}
var building_inventory_label: Label:
	get:
		return hud.building_inventory_label if hud != null else null
var mode_label: Label:
	get:
		return hud.mode_label if hud != null else null
var event_label: Label:
	get:
		return hud.event_label if hud != null else null


func _ready() -> void:
	world = SimulationWorldClass.new()
	world.setup_demo()
	terrain_renderer.bind_grid(world.grid)
	_center_camera()
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			# Space is the global pause shortcut. Consume both halves before GUI
			# dispatch so a focused button cannot also activate on key release.
			if key_event.pressed and not key_event.echo:
				_toggle_pause()
			get_viewport().set_input_as_handled()


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
			var clicked_building_id: int = _building_id_at_visual_position(to_local(canvas_position))
			if clicked_building_id != 0:
				selected_cell = (world.buildings[clicked_building_id] as Dictionary)["position"] as Vector2i
			else:
				selected_cell = terrain_renderer.pick_cell(terrain_renderer.to_local(canvas_position))
			_apply_build_mode(selected_cell)
			_update_ui()
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
			KEY_5:
				_set_build_mode("school")
			KEY_ESCAPE:
				_set_build_mode("")
			KEY_F5:
				world._push_event("Game saved." if SaveSystemClass.save_world(world) else "Save failed.")
			KEY_F9:
				_load_game()
			KEY_R:
				_reset_demo()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if world == null:
		return
	_draw_selection()
	_draw_world_objects()


func _draw_selection() -> void:
	if not world.grid.contains(selected_cell):
		return
	draw_rect(terrain_renderer.cell_rect(selected_cell), Color(1.0, 0.86, 0.28), false, 3.0)


func _draw_world_objects() -> void:
	var draw_entries: Array[Dictionary] = []
	for tree_variant: Variant in world.trees.values():
		var tree: Dictionary = tree_variant as Dictionary
		draw_entries.append({
			"id": int(tree["id"]),
			"kind": "tree",
			"kind_order": 0,
			"position": terrain_renderer.cell_center(tree["position"] as Vector2i),
			"state": tree,
		})
	for building_variant: Variant in world.buildings.values():
		var building: Dictionary = building_variant as Dictionary
		draw_entries.append({
			"id": int(building["id"]),
			"kind": "building",
			"kind_order": 1,
			"position": terrain_renderer.cell_center(building["position"] as Vector2i),
			"state": building,
		})
	var frame_alpha: float = clampf(accumulator / FIXED_TICK_SECONDS, 0.0, 1.0)
	for worker_variant: Variant in world.workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		var previous: Vector2 = terrain_renderer.cell_center(worker["previous_position"] as Vector2i)
		var current: Vector2 = terrain_renderer.cell_center(worker["position"] as Vector2i)
		var foot_position: Vector2 = previous.lerp(current, worker_lerp_alpha(worker, frame_alpha))
		draw_entries.append({
			"id": int(worker["id"]),
			"kind": "worker",
			"kind_order": 2,
			"position": foot_position,
			"state": worker,
		})
	draw_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_position: Vector2 = a["position"] as Vector2
		var b_position: Vector2 = b["position"] as Vector2
		if not is_equal_approx(a_position.y, b_position.y):
			return a_position.y < b_position.y
		if not is_equal_approx(a_position.x, b_position.x):
			return a_position.x < b_position.x
		var a_kind_order: int = int(a["kind_order"])
		var b_kind_order: int = int(b["kind_order"])
		return a_kind_order < b_kind_order or (
			a_kind_order == b_kind_order and int(a["id"]) < int(b["id"])
		)
	)
	for draw_entry: Dictionary in draw_entries:
		var state: Dictionary = draw_entry["state"] as Dictionary
		var position: Vector2 = draw_entry["position"] as Vector2
		match String(draw_entry["kind"]):
			"tree":
				_draw_tree(state, position)
			"building":
				_draw_building(state, position)
			"worker":
				_draw_worker(state, position)


func _draw_tree(tree: Dictionary, center: Vector2) -> void:
	match world.tree_growth_stage(tree):
		SimulationWorldClass.TREE_STAGE_SAPLING:
			draw_rect(Rect2(center + Vector2(-1, -8), Vector2(2, 9)), Color(0.38, 0.24, 0.10))
			draw_circle(center + Vector2(-3, -9), 4.0, Color(0.36, 0.66, 0.25))
			draw_circle(center + Vector2(3, -11), 4.0, Color(0.43, 0.73, 0.29))
		SimulationWorldClass.TREE_STAGE_YOUNG:
			draw_rect(Rect2(center + Vector2(-2, -14), Vector2(4, 15)), Color(0.35, 0.21, 0.09))
			draw_circle(center + Vector2(0, -18), 9.0, Color(0.19, 0.49, 0.20))
			draw_circle(center + Vector2(-5, -14), 6.0, Color(0.24, 0.57, 0.23))
		_:
			draw_rect(Rect2(center + Vector2(-3, -19), Vector2(6, 20)), Color(0.31, 0.18, 0.08))
			draw_circle(center + Vector2(0, -24), 13.0, Color(0.10, 0.33, 0.15))
			draw_circle(center + Vector2(-7, -19), 9.0, Color(0.13, 0.42, 0.18))
			draw_string(ThemeDB.fallback_font, center + Vector2(9, -23), str(tree["amount"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_building(building: Dictionary, center: Vector2) -> void:
	var definition: Dictionary = world.catalog.building(String(building["type"]))
	var base_color: Color = Color.from_string("#" + String(definition.get("color", "888888")), Color.GRAY)
	var wall: PackedVector2Array = _building_wall_polygon(center)
	draw_colored_polygon(wall, base_color.darkened(0.18))
	var roof: PackedVector2Array = _building_roof_polygon(center)
	draw_colored_polygon(roof, base_color.lightened(0.08))
	draw_string(ThemeDB.fallback_font, center + Vector2(-30, 22), String(definition.get("display_name", building["type"])), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(0.95, 0.95, 0.86))


func _building_id_at_visual_position(position: Vector2) -> int:
	var building_entries: Array[Dictionary] = []
	for building_variant: Variant in world.buildings.values():
		var building: Dictionary = building_variant as Dictionary
		building_entries.append({
			"id": int(building["id"]),
			"position": terrain_renderer.cell_center(building["position"] as Vector2i),
		})
	building_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_position: Vector2 = a["position"] as Vector2
		var b_position: Vector2 = b["position"] as Vector2
		if not is_equal_approx(a_position.y, b_position.y):
			return a_position.y < b_position.y
		if not is_equal_approx(a_position.x, b_position.x):
			return a_position.x < b_position.x
		return int(a["id"]) < int(b["id"])
	)
	building_entries.reverse()
	for entry: Dictionary in building_entries:
		var center: Vector2 = entry["position"] as Vector2
		if (
			Geometry2D.is_point_in_polygon(position, _building_roof_polygon(center))
			or Geometry2D.is_point_in_polygon(position, _building_wall_polygon(center))
		):
			return int(entry["id"])
	return 0


static func _building_wall_polygon(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-23, -5), center + Vector2(0, 7),
		center + Vector2(23, -5), center + Vector2(23, -31),
		center + Vector2(0, -18), center + Vector2(-23, -31),
	])


static func _building_roof_polygon(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-27, -29), center + Vector2(0, -47),
		center + Vector2(27, -29), center + Vector2(0, -12),
	])


func _draw_worker(worker: Dictionary, foot_position: Vector2) -> void:
	var center: Vector2 = foot_position + Vector2(0, -10)
	var unit_type: String = String(worker.get("type", "carrier"))
	var unit_definition: Dictionary = world.catalog.unit(unit_type)
	var unit_color: Color = Color.from_string(
		"#" + String(unit_definition.get("color", "d7a13f")),
		Color(0.94, 0.81, 0.42)
	)
	draw_circle(center, 7.0, unit_color)
	draw_circle(center + Vector2(0, -8), 4.0, Color(0.84, 0.68, 0.51))
	var unit_symbol: String = "?"
	match unit_type:
		"lumberjack":
			unit_symbol = "L"
		"carrier":
			unit_symbol = "C"
		"gardener":
			unit_symbol = "G"
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-3, 4),
		unit_symbol,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		Color(0.12, 0.12, 0.10)
	)
	var carrying: String = String(worker["carrying"])
	if not carrying.is_empty():
		draw_rect(Rect2(center + Vector2(7, -4), Vector2(8, 8)), Color(0.55, 0.34, 0.17) if carrying == "log" else Color(0.82, 0.66, 0.40))


func _build_ui() -> void:
	hud = GameHudClass.new()
	hud.build_mode_requested.connect(_set_build_mode)
	hud.simulation_speed_requested.connect(_set_simulation_speed)
	hud.unit_training_requested.connect(_queue_selected_unit)
	add_child(hud)
	hud.configure(world.catalog)


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
	if world.building_id_at(cell) != 0:
		return
	var success: bool
	if build_mode == "road":
		success = world.place_road(cell)
	else:
		success = world.place_building(build_mode, cell) != 0
	if not success:
		world._push_event("Cannot build there.")


func _queue_selected_unit(unit_type: String) -> void:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0 or not world.queue_unit_training(building_id, unit_type):
		world._push_event("Select a School with room in its training queue.")
	_update_ui()


func _update_ui() -> void:
	if hud != null:
		hud.refresh(world, selected_cell, build_mode, simulation_speed, FIXED_TICK_SECONDS)


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
	terrain_renderer.bind_grid(world.grid)
	_center_camera()
	accumulator = 0.0
	selected_cell = Vector2i(-1, -1)


func _load_game() -> void:
	var loaded: bool = SaveSystemClass.load_world(world)
	if loaded:
		terrain_renderer.bind_grid(world.grid)
		_center_camera()
		accumulator = 0.0
		if not world.grid.contains(selected_cell):
			selected_cell = Vector2i(-1, -1)
	world._push_event("Game loaded." if loaded else "No valid save found.")


func _center_camera() -> void:
	camera.position = terrain_renderer.map_bounds().get_center()


static func worker_lerp_alpha(worker: Dictionary, frame_alpha: float) -> float:
	var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
	var progress: int = clampi(int(worker.get("visual_progress_ticks", duration)), 0, duration)
	return clampf((float(progress) + frame_alpha) / float(duration), 0.0, 1.0)
