extends Node2D

const SimulationWorldClass = preload("res://scripts/simulation/simulation_world.gd")
const SaveSystemClass = preload("res://scripts/simulation/save_system.gd")
const TerrainRendererClass = preload("res://scripts/view/terrain_renderer.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const GameHudClass = preload("res://scripts/view/game_hud.gd")
const ReliefDemoClass = preload("res://scripts/simulation/relief_demo.gd")
const TestLevelClass = preload("res://scripts/simulation/test_level.gd")
const ImportedTerrainClass = preload("res://scripts/simulation/imported_terrain.gd")
const UnitSpriteLibraryClass = preload("res://scripts/view/unit_sprite_library.gd")
const TreeSpriteLibraryClass = preload("res://scripts/view/tree_sprite_library.gd")
const PlacementPreviewRulesClass = preload("res://scripts/view/placement_preview_rules.gd")
const SolarCycleClass = preload("res://scripts/view/solar_cycle.gd")
const SolarShadowsClass = preload("res://scripts/view/solar_shadows.gd")
const BuildingFootprintRendererClass = preload("res://scripts/view/building_footprint_renderer.gd")

const FIXED_TICK_SECONDS: float = SimulationWorldClass.TICK_SECONDS
const MAX_TICKS_PER_FRAME: int = 8
const TERRAIN_STUDY_SAVE_PATH: String = "user://medieval_economy_rts_mountainous_region_save.json"
const LARGE_MAP_CULL_CELLS: int = 4096

signal main_menu_requested()

var world: SimulationWorldClass
var honor_launch_arguments: bool = true
var save_path: String = SaveSystemClass.DEFAULT_PATH
var selected_cell := Vector2i(-1, -1)
var selected_unit_id: int = 0
var build_mode: String = ""
var accumulator: float = 0.0
var dragging_camera: bool = false
var simulation_speed: float = 0.5
var speed_before_pause: float = 0.5
# Populated demos and the external terrain study leave the normal test level intact.
@export var demo_kind: String = "test"
@export var terrain_map_path: String = ImportedTerrainClass.DEFAULT_PATH
# Embedded/custom scenes can select an isolated save location as well.
@export var save_path_override: String = ""
var terrain_load_error: String = ""
var show_terrain_rules: bool = false

@onready var camera: Camera2D = $Camera2D
@onready var terrain_renderer: TerrainRendererClass = $TerrainRenderer
var hud: GameHudClass
var unit_sprites := UnitSpriteLibraryClass.new()
var tree_sprites := TreeSpriteLibraryClass.new()
var _dynamic_rows: Dictionary = {}
var _row_entries: Dictionary = {}
var _row_shadows: Dictionary = {}
var solar_state: Dictionary = {}
var _draw_canvas: CanvasItem
var hovered_cell: Vector2i = Vector2i(-1, -1)
var placement_preview: Dictionary = {}
var _placement_canvas: Node2D
var _pointer_screen: Vector2 = Vector2(-1, -1)
var _pointer_inside: bool = false
var _preview_state_key: Array = []
var _camera_auto_fit: bool = true

# Existing view clients can inspect HUD state without owning or rebuilding controls.
var resource_hud_panel: PanelContainer:
	get:
		return hud.resource_hud_panel if hud != null else null
var resource_amount_labels: Dictionary:
	get:
		return hud.resource_amount_labels if hud != null else {}
var resource_breakdown_labels: Dictionary:
	get:
		return hud.resource_breakdown_labels if hud != null else {}
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
	# Small painted sprites are strongly minified at the overview zoom.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if honor_launch_arguments and OS.get_cmdline_user_args().has("--economy-demo"):
		demo_kind = "economy"
	elif honor_launch_arguments and OS.get_cmdline_user_args().has("--relief-demo"):
		demo_kind = "relief"
	elif honor_launch_arguments and OS.get_cmdline_user_args().has("--mountainous-region"):
		demo_kind = "mountainous-region"
	if world == null:
		_create_demo_world()
	_update_window_title()
	if get_viewport() == get_tree().root:
		_configure_game_window()
	terrain_renderer.external_painter = true
	terrain_renderer.bind_grid(world.grid)
	_center_camera()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_placement_canvas = Node2D.new()
	_placement_canvas.name = "PlacementPreview"
	_placement_canvas.z_index = 4095
	_placement_canvas.visible = false
	_placement_canvas.draw.connect(_draw_placement_preview)
	add_child(_placement_canvas)
	_update_ui()
	queue_redraw()


func _update_window_title() -> void:
	if get_viewport() != get_tree().root:
		return
	var level_titles: Dictionary = {
		"test": "Test level · Warehouse + School · Construction supplies ready",
		"relief": "Roads and trees",
		"economy": "Economy demo + environment",
		"mountainous-region": "Mountainous Region · imported terrain study",
	}
	get_tree().root.title = "Medieval Economy RTS · " + String(level_titles.get(demo_kind, level_titles["test"]))


func _configure_game_window() -> void:
	# The editor needs a Windowed override to allow embedded play. Restore the
	# normal maximized start when using the same editor binary without embedding.
	if get_parent() != get_tree().root or Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	var arguments: PackedStringArray = OS.get_cmdline_args()
	if arguments.has("--windowed") or arguments.has("-w") or arguments.has("--resolution"):
		return
	var window: Window = get_tree().root
	if window.mode == Window.MODE_WINDOWED:
		window.mode = ProjectSettings.get_setting("display/window/size/mode", Window.MODE_MAXIMIZED) as Window.Mode


func _process(delta: float) -> void:
	_handle_keyboard_camera(delta)
	accumulator += minf(delta * simulation_speed, FIXED_TICK_SECONDS * float(MAX_TICKS_PER_FRAME))
	var ticks_run: int = 0
	while accumulator >= FIXED_TICK_SECONDS and ticks_run < MAX_TICKS_PER_FRAME:
		world.step_tick()
		accumulator -= FIXED_TICK_SECONDS
		ticks_run += 1
	_update_ui()
	_update_placement_preview()
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Observe motion before GUI dispatch so entering a panel hides map feedback.
	# Keep the dispatched position: native mouse polling would replace injected
	# viewport events and is unnecessary while the camera moves under the cursor.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_update_placement_preview(event.position)
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
			if hud != null and hud.blocks_map_point(mouse_button.position):
				_clear_placement_preview()
				get_viewport().set_input_as_handled()
				return
			var canvas_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * mouse_button.position
			selected_unit_id = _worker_id_at_visual_position(to_local(canvas_position)) if build_mode.is_empty() else 0
			var clicked_building_id: int = _building_id_at_visual_position(to_local(canvas_position)) if selected_unit_id == 0 and build_mode in ["", "road"] else 0
			if selected_unit_id != 0:
				selected_cell = (world.workers[selected_unit_id] as Dictionary)["position"] as Vector2i
			elif clicked_building_id != 0:
				selected_cell = (world.buildings[clicked_building_id] as Dictionary)["position"] as Vector2i
			else:
				selected_cell = terrain_renderer.pick_cell(terrain_renderer.to_local(canvas_position))
			var placement_allowed: bool = clicked_building_id != 0 or build_mode.is_empty() or bool(PlacementPreviewRulesClass.evaluate(world, build_mode, selected_cell).get("valid", false))
			if clicked_building_id == 0:
				_apply_build_mode(selected_cell)
			_update_placement_preview(mouse_button.position)
			_update_ui()
			if placement_allowed:
				hud.inspect_selection()
			else:
				hud.show_build_tool(build_mode)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging_camera:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_auto_fit = false
		camera.position -= motion.relative / camera.zoom.x
		camera.force_update_scroll()
		_update_placement_preview(motion.position)
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
			KEY_6:
				_set_build_mode("quarry")
			KEY_7:
				_set_build_mode("farm")
			KEY_8:
				_set_build_mode("mill")
			KEY_9:
				_set_build_mode("bakery")
			KEY_0:
				_set_build_mode("field")
			KEY_ESCAPE:
				if build_mode.is_empty() and not hud.has_open_overlay() and main_menu_requested.has_connections():
					_request_main_menu()
				else:
					_set_build_mode("")
			KEY_F2:
				_set_terrain_rules(not show_terrain_rules)
			KEY_F5:
				_save_game()
			KEY_F9:
				_load_game()
			KEY_R:
				_reset_demo()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if world == null:
		return
	_update_day_lighting()
	# Terrain owns retained even-Z rows; only these odd-Z object rows redraw
	# with animation. The same ground order preserves foreground occlusion.
	_sync_dynamic_rows()
	_row_entries.clear()
	_row_shadows.clear()
	for entry: Dictionary in _world_draw_entries(true):
		var row: int = clampi(floori((entry["ground_position"] as Vector2).y + 0.5), 0, world.grid.size.y - 1)
		if not _row_entries.has(row):
			_row_entries[row] = []
		_row_entries[row].append(entry)
		if entry["kind"] == "tree":
			entry["growth_stage"] = world.tree_growth_stage(entry["state"])
		# Short survey stakes must not cast the silhouette of a full house.
		if entry["kind"] == "building" and int((entry["state"] as Dictionary).get("foundation_work_remaining", 0)) > 0:
			continue
		var shadows: Dictionary = SolarShadowsClass.rows_for(terrain_renderer, entry, solar_state)
		for shadow_row: int in shadows:
			if not _row_shadows.has(shadow_row):
				_row_shadows[shadow_row] = []
			(_row_shadows[shadow_row] as Array).append_array(shadows[shadow_row])
	for canvas: Node2D in _dynamic_rows.values():
		canvas.queue_redraw()
	if _placement_canvas != null and _placement_canvas.visible:
		_placement_canvas.queue_redraw()



func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pointer_inside = false
		_clear_placement_preview()


func _update_placement_preview(screen_position: Vector2 = Vector2.INF) -> void:
	var new_pointer_event: bool = screen_position != Vector2.INF
	if new_pointer_event:
		_pointer_screen = screen_position
		_pointer_inside = get_viewport_rect().has_point(screen_position)
	if world == null or build_mode.is_empty() or not _pointer_inside:
		_clear_placement_preview()
		return
	if not get_viewport_rect().has_point(_pointer_screen) or (hud != null and hud.blocks_map_point(_pointer_screen)):
		_clear_placement_preview()
		return
	var canvas_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * _pointer_screen
	var cell: Vector2i = terrain_renderer.pick_cell(terrain_renderer.to_local(canvas_position))
	if not world.grid.contains(cell):
		_clear_placement_preview()
		return
	var state_key: Array = [world.get_instance_id(), cell, build_mode, world.tick, world.grid.revision,
		world.trees.size(), world.fields.size(), world.deposits.size(), world.workers.size()]
	# Resource-dependent road/vine checks are inexpensive and should also notice
	# stock edits made between ticks. Deposit path searches are cached per state.
	var cacheable: bool = build_mode not in ["road", "vine_field"]
	if not new_pointer_event and cacheable and state_key == _preview_state_key:
		return
	hovered_cell = cell
	placement_preview = PlacementPreviewRulesClass.evaluate(world, build_mode, cell)
	_preview_state_key = state_key
	if _placement_canvas != null:
		_placement_canvas.visible = true
		_placement_canvas.queue_redraw()
	if hud != null:
		hud.set_placement_preview(build_mode, placement_preview)


func _clear_placement_preview() -> void:
	hovered_cell = Vector2i(-1, -1)
	placement_preview = {}
	_preview_state_key.clear()
	if _placement_canvas != null:
		_placement_canvas.visible = false
	if hud != null:
		hud.set_placement_preview(build_mode, placement_preview)


func _draw_placement_preview() -> void:
	if _placement_canvas == null or placement_preview.is_empty() or not world.grid.contains(hovered_cell):
		return
	var valid: bool = bool(placement_preview["valid"])
	var color: Color = Color("#80df91") if valid else Color("#ff8e79")
	if valid and bool(placement_preview.get("needs_levelling", false)):
		color = Color("#f4c36a")
	for cell: Vector2i in placement_preview.get("cells", [hovered_cell]):
		_draw_preview_cell(cell, color, valid, true)
	var entrance: Vector2i = placement_preview.get("entrance", Vector2i(-1, -1))
	if world.grid.contains(entrance):
		_draw_preview_cell(entrance, Color("#72d5ee"), valid, false)
		var center: Vector2 = terrain_renderer.cell_center(entrance)
		var arrow := PackedVector2Array([center + Vector2(-6, 3), center + Vector2(0, -4), center + Vector2(6, 3)])
		_placement_canvas.draw_polyline(arrow, Color("#c0f2ff"), 2.5 / maxf(0.3, camera.zoom.x), true)


func _draw_preview_cell(cell: Vector2i, color: Color, valid: bool, mark_invalid: bool) -> void:
	var polygon: PackedVector2Array = terrain_renderer.cell_polygon(cell)
	if polygon.size() != 4:
		return
	var fill: Color = color
	fill.a = 0.12 if valid else 0.19
	# A steep heightfield face can project to a line: only fill real triangles.
	for indices: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector2 = polygon[int(indices[0])]
		var b: Vector2 = polygon[int(indices[1])]
		var c: Vector2 = polygon[int(indices[2])]
		if absf((b - a).cross(c - a)) > 0.01:
			_placement_canvas.draw_colored_polygon(PackedVector2Array([a, b, c]), fill)
	var outline: PackedVector2Array = polygon.duplicate()
	outline.append(outline[0])
	var width: float = 2.5 / maxf(0.30, camera.zoom.x)
	_placement_canvas.draw_polyline(outline, Color(0.04, 0.07, 0.04, 0.9), width + 2.0 / camera.zoom.x, true)
	_placement_canvas.draw_polyline(outline, color, width, true)
	if not valid and mark_invalid:
		for endpoints: Array in [[Vector2(0.24, 0.24), Vector2(0.76, 0.76)], [Vector2(0.24, 0.76), Vector2(0.76, 0.24)]]:
			var cross := PackedVector2Array([
				_field_point(cell, endpoints[0]), _field_point(cell, Vector2(0.5, 0.5)), _field_point(cell, endpoints[1]),
			])
			_placement_canvas.draw_polyline(cross, color, width, true)


func _sync_dynamic_rows() -> void:
	for row: int in _dynamic_rows.keys():
		if row >= world.grid.size.y:
			var obsolete: Node2D = _dynamic_rows[row]
			remove_child(obsolete)
			obsolete.free()
			_dynamic_rows.erase(row)
	for row: int in range(world.grid.size.y):
		if _dynamic_rows.has(row):
			continue
		var canvas := Node2D.new()
		canvas.name = "ObjectRow_%d" % row
		canvas.z_index = row * 2 + 1
		canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		canvas.draw.connect(_paint_dynamic_row.bind(canvas, row))
		add_child(canvas)
		_dynamic_rows[row] = canvas


func _paint_dynamic_row(canvas: Node2D, row: int) -> void:
	_draw_canvas = canvas
	_draw_deposits(row)
	_draw_fields(row)
	for shadow: Dictionary in _row_shadows.get(row, []):
		# Indoor state can change between queuing this row and its draw callback.
		if shadow["kind"] == "worker" and world.is_worker_inside(shadow["state"]):
			continue
		canvas.draw_colored_polygon(shadow["points"], shadow["color"])
	_draw_selection(row)
	for entry: Dictionary in _row_entries.get(row, []):
		_draw_world_entry(entry)
	_draw_canvas = null


func _draw_selection(row: int) -> void:
	if selected_unit_id != 0 or not world.grid.contains(selected_cell):
		return
	var building_id: int = world.building_id_at(selected_cell)
	var cells: Array[Vector2i] = [selected_cell]
	if building_id != 0:
		cells = world.building_cells(world.buildings[building_id])
	for cell: Vector2i in cells:
		if cell.y != row:
			continue
		var polygon: PackedVector2Array = terrain_renderer.cell_polygon(cell)
		polygon.append(polygon[0])
		_draw_canvas.draw_polyline(polygon, Color(1.0, 0.86, 0.28), 3.0, true)


func _field_point(cell: Vector2i, uv: Vector2) -> Vector2:
	return terrain_renderer.project_grid_position(Vector2(cell) + uv - Vector2(0.5, 0.5))


func _draw_fields(terrain_row: int) -> void:
	for field: Dictionary in world.fields.values():
		var cell: Vector2i = field["position"] as Vector2i
		if cell.y != terrain_row:
			continue
		var polygon: PackedVector2Array = terrain_renderer.cell_polygon(cell)
		_draw_canvas.draw_colored_polygon(PackedVector2Array([polygon[0], polygon[1], polygon[2]]), Color(0.34, 0.23, 0.12))
		_draw_canvas.draw_colored_polygon(PackedVector2Array([polygon[0], polygon[2], polygon[3]]), Color(0.34, 0.23, 0.12))
		for row: int in range(5):
			var v: float = 0.15 + float(row) * 0.17
			_draw_canvas.draw_line(_field_point(cell, Vector2(0.07, v)), _field_point(cell, Vector2(0.93, v)), Color(0.24, 0.16, 0.09), 2.0)
		var stage: int = world.field_growth_stage(field)
		if String(field.get("kind", "wheat")) == "vine":
			_draw_vine_field(field, cell, stage)
			continue
		if stage == 0:
			continue
		var growth: float = clampf(float(field["age_ticks"]) / float(world.field_mature_age(field)), 0.0, 1.0)
		var stalk_color: Color = Color(0.36, 0.58, 0.21).lerp(Color(0.84, 0.66, 0.24), growth)
		var head_color: Color = Color(0.64, 0.74, 0.26).lerp(Color(0.98, 0.80, 0.32), growth)
		for row: int in range(4):
			for stalk: int in range(5):
				var foot: Vector2 = _field_point(cell, Vector2(0.14 + float(stalk) * 0.17, 0.25 + float(row) * 0.20))
				var tip: Vector2 = foot + Vector2(1.5, -3.0 - growth * 7.0)
				_draw_canvas.draw_line(foot, tip, stalk_color, 1.5, true)
				_draw_canvas.draw_line(foot + Vector2(0.5, -2.5), foot + Vector2(-2.5, -5.0), stalk_color, 1.3, true)
				if growth > 0.45:
					_draw_canvas.draw_line(tip + Vector2(-2.0, 2.0), tip + Vector2(2.0, -1.0), head_color, 2.5, true)
				if stage == 2:
					_draw_canvas.draw_line(tip + Vector2(-1.5, 4.0), tip + Vector2(2.5, 1.0), head_color, 2.0, true)


func _draw_vine_field(field: Dictionary, cell: Vector2i, stage: int) -> void:
	var growth: float = clampf(float(field["age_ticks"]) / float(world.field_mature_age(field)), 0.0, 1.0)
	for row: int in range(3):
		var v: float = 0.28 + float(row) * 0.28
		_draw_canvas.draw_line(_field_point(cell, Vector2(0.10, v)) + Vector2(0, -5), _field_point(cell, Vector2(0.90, v)) + Vector2(0, -5), Color(0.57, 0.46, 0.29), 1.5)
		for vine: int in range(3):
			var root_position: Vector2 = _field_point(cell, Vector2(0.18 + float(vine) * 0.31, v))
			_draw_canvas.draw_line(root_position, root_position + Vector2(0, -10), Color(0.53, 0.37, 0.19), 2.5)
			if stage == 0:
				continue
			_draw_canvas.draw_circle(root_position + Vector2(-3, -7), 3.0 + growth * 2.0, Color(0.27, 0.46, 0.18))
			_draw_canvas.draw_circle(root_position + Vector2(3, -8), 3.0 + growth * 2.0, Color(0.35, 0.55, 0.22))
			if stage == 2:
				for grape: int in range(3):
					_draw_canvas.draw_circle(root_position + Vector2(float(grape % 2) * 3.0, -4.0 + float(grape) * 2.0), 2.0, Color(0.39, 0.22, 0.46))


func _draw_deposits(row: int) -> void:
	var deposit_value: Variant = world.get("deposits")
	if not deposit_value is Dictionary:
		return
	for deposit: Dictionary in (deposit_value as Dictionary).values():
		if (deposit["position"] as Vector2i).y != row:
			continue
		var center: Vector2 = terrain_renderer.cell_center(deposit["position"] as Vector2i)
		var resource_id: String = String(deposit["resource"])
		var amount: int = int(deposit["amount"])
		var definition: Dictionary = world.catalog.resources.get(resource_id, {}) as Dictionary
		var color: Color = Color.from_string("#" + String(definition.get("color", "858b8f")), Color.GRAY)
		if resource_id == "fish":
			if amount <= 0:
				continue
			for fish: int in range(3):
				var point: Vector2 = center + Vector2(-9 + fish * 8, (fish % 2) * 9 - 5)
				_draw_canvas.draw_arc(point, 8.0, 0.1, PI - 0.1, 12, Color(0.68, 0.86, 0.85, 0.7), 1.0, true)
				_draw_canvas.draw_line(point + Vector2(-3, 1), point + Vector2(3, -1), Color(0.80, 0.85, 0.72), 2.5, true)
			continue
		for seam: int in range(5):
			var point: Vector2 = center + Vector2(-14 + (seam % 3) * 13, -10 + (seam / 3) * 17)
			var points := PackedVector2Array([point + Vector2(-5, 3), point + Vector2(-2, -5), point + Vector2(5, -3), point + Vector2(7, 3), point + Vector2(2, 6)])
			_draw_canvas.draw_colored_polygon(points, color.darkened(0.32) if amount <= 0 else color)
			if amount > 0:
				_draw_canvas.draw_line(points[1], points[2], color.lightened(0.4), 2.0, true)
		if amount > 0 and resource_id != "stone":
			var badge: String = "C" if resource_id == "coal" else ("Fe" if resource_id == "iron_ore" else "Au")
			_draw_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-8, 19), badge, HORIZONTAL_ALIGNMENT_CENTER, 16, 10, color.lightened(0.45))


func _visible_tree_bounds() -> Rect2:
	# Culling is presentation-only, and deliberately generous. An offscreen
	# canopy or caster must remain when its sprite/shadow reaches the viewport,
	# including a receiver anywhere in the supported 64-unit height range.
	var shadow_vector: Vector2 = solar_state.get("shadow_vector", Vector2.ZERO) as Vector2
	var shadow_cells: float = maxf(2.0, shadow_vector.length() * 1.25 + 0.5)
	var margin: float = TreeSpriteLibraryClass.MATURE_SPRUCE_HEIGHT
	margin += shadow_cells * MapProjectionClass.CELL_SIZE.length()
	margin += float(world.grid.MAX_HEIGHT) * MapProjectionClass.HEIGHT_STEP_PIXELS
	return (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(margin)


func _world_draw_entries(visible_trees_only: bool = false) -> Array[Dictionary]:
	var draw_entries: Array[Dictionary] = []
	var cull_trees: bool = visible_trees_only and world.grid.size.x * world.grid.size.y > LARGE_MAP_CULL_CELLS
	var tree_bounds: Rect2 = _visible_tree_bounds() if cull_trees else Rect2()
	for tree_variant: Variant in world.trees.values():
		var tree: Dictionary = tree_variant as Dictionary
		var tree_position: Vector2 = terrain_renderer.cell_center(tree["position"] as Vector2i)
		if cull_trees and not tree_bounds.has_point(tree_position):
			continue
		draw_entries.append({
			"id": int(tree["id"]),
			"kind": "tree",
			"kind_order": 0,
			"position": tree_position,
			"ground_position": Vector2(tree["position"] as Vector2i),
			"state": tree,
		})
	for building_variant: Variant in world.buildings.values():
		var building: Dictionary = building_variant as Dictionary
		draw_entries.append({
			"id": int(building["id"]),
			"kind": "building",
			"kind_order": 1,
			"position": terrain_renderer.cell_center(building["position"] as Vector2i),
			"ground_position": Vector2(building["position"] as Vector2i),
			"state": building,
		})
		if int(building.get("footprint_version", 0)) > 0:
			var shape: Dictionary = building_geometry(building)
			draw_entries[-1]["shadow_ground_position"] = shape["ground_center"]
			draw_entries[-1]["shadow_radius"] = (shape["ground_size"] as Vector2) * 0.5
	var frame_alpha: float = clampf(accumulator / FIXED_TICK_SECONDS, 0.0, 1.0)
	for worker_variant: Variant in world.workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		if world.is_worker_inside(worker):
			continue
		var previous: Vector2 = Vector2(worker["previous_position"] as Vector2i)
		var current: Vector2 = Vector2(worker["position"] as Vector2i)
		var ground_position: Vector2 = previous.lerp(current, worker_lerp_alpha(worker, frame_alpha))
		var foot_position: Vector2 = terrain_renderer.project_grid_position(ground_position)
		draw_entries.append({
			"id": int(worker["id"]),
			"kind": "worker",
			"kind_order": 2,
			"position": foot_position,
			"ground_position": ground_position,
			"state": worker,
		})
	draw_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_position: Vector2 = a["ground_position"] as Vector2
		var b_position: Vector2 = b["ground_position"] as Vector2
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
	return draw_entries


func _draw_world_entry(draw_entry: Dictionary) -> void:
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
	var stage: int = world.tree_growth_stage(tree)
	var presentation: Dictionary = tree_sprites.presentation_for(tree, stage, center, show_terrain_rules)
	var sprite: Texture2D = presentation["texture"] as Texture2D
	if sprite == null:
		return
	_draw_tree_ground_shadow(tree["position"] as Vector2i, stage)
	var sprite_bounds: Rect2 = presentation["rect"] as Rect2
	_draw_canvas.draw_texture_rect(sprite, sprite_bounds, false)
	var amount_text: String = String(presentation["amount_text"])
	if not amount_text.is_empty():
		_draw_canvas.draw_string(ThemeDB.fallback_font, sprite_bounds.position + Vector2(sprite_bounds.size.x + 3, 12),
			amount_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.93, 0.86))


func _draw_tree_ground_shadow(cell: Vector2i, stage: int) -> void:
	# Project every shadow vertex onto the heightfield, including on a slope.
	# A fixed screen-space oval would float above or cut through the terrain.
	var radii: Array[Vector2] = [Vector2(0.10, 0.07), Vector2(0.20, 0.12), Vector2(0.29, 0.17)]
	var radius: Vector2 = radii[clampi(stage, 0, radii.size() - 1)]
	var points := PackedVector2Array()
	for index: int in range(20):
		var angle: float = TAU * float(index) / 20.0
		var uv: Vector2 = Vector2(0.5, 0.52) + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		points.append(terrain_renderer.project_grid_position(Vector2(cell) + uv - Vector2(0.5, 0.5)))
	_draw_canvas.draw_colored_polygon(points, Color(0.04, 0.08, 0.04, 0.19))


func _draw_building(building: Dictionary, center: Vector2) -> void:
	var building_type: String = String(building["type"])
	var definition: Dictionary = world.catalog.building(building_type)
	var base_color: Color = Color.from_string("#" + String(definition.get("color", "888888")), Color.GRAY)
	if int(building.get("footprint_version", 0)) > 0:
		_draw_footprint_building(building, definition, base_color)
		return
	_draw_ellipse_shadow(center)
	if int(building.get("construction_remaining", 0)) > 0:
		_draw_construction_site(center, building, definition)
		return
	var wall: PackedVector2Array = _building_wall_polygon(center)
	_draw_canvas.draw_colored_polygon(wall, base_color.darkened(0.18))
	var roof: PackedVector2Array = _building_roof_polygon(center)
	_draw_canvas.draw_colored_polygon(roof, base_color.lightened(0.08))
	_draw_canvas.draw_line(center + Vector2(0, -12), center + Vector2(0, 7), base_color.darkened(0.35), 1.5)
	_draw_building_details(building, center)
	_draw_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-30, 22), String(definition.get("display_name", building["type"])), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(0.95, 0.95, 0.86))


# Public inspection API: these are the exact polygons painted and hit-tested.
func building_geometry(building: Dictionary) -> Dictionary:
	return BuildingFootprintRendererClass.geometry(world, terrain_renderer, building)


func _draw_footprint_building(building: Dictionary, definition: Dictionary, base_color: Color) -> void:
	var shape: Dictionary = building_geometry(building)
	var construction: bool = int(building.get("construction_remaining", 0)) > 0
	BuildingFootprintRendererClass.draw_shell(_draw_canvas, shape, base_color, construction)
	var label: Vector2 = shape["label_position"]
	if construction:
		var total: float = maxf(1.0, float(definition.get("construction_ticks", 120)))
		var progress: float = clampf(1.0 - float(building["construction_remaining"]) / total, 0.0, 1.0)
		if bool(shape["earthwork"]):
			progress = float(shape["earthwork_progress"])
		_draw_canvas.draw_rect(Rect2(label + Vector2(-36, -8), Vector2(72, 5)), Color(0.12, 0.14, 0.10))
		_draw_canvas.draw_rect(Rect2(label + Vector2(-36, -8), Vector2(72 * progress, 5)), Color(0.88, 0.70, 0.30))
		label.y += 11
		if bool(shape["earthwork"]):
			_draw_canvas.draw_string(ThemeDB.fallback_font, label + Vector2(-85, 0), "Ground preparation %d%%" % int(progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 170, 11, Color("#f4c36a"))
			label.y += 13
	else:
		_draw_building_details(building, shape["detail_center"])
		BuildingFootprintRendererClass.draw_door(_draw_canvas, shape)
	var selected: bool = selected_unit_id == 0 and world.building_id_at(selected_cell) == int(building["id"])
	if selected:
		for edge: PackedVector2Array in (shape["boundary"] if construction else shape["roof_edges"]):
			_draw_canvas.draw_polyline(edge, Color(1.0, 0.86, 0.28), 2.5, true)
	_draw_canvas.draw_string(ThemeDB.fallback_font, label + Vector2(-65, 0), String(definition.get("display_name", building["type"])), HORIZONTAL_ALIGNMENT_CENTER, 130, 11, Color(0.97, 0.95, 0.82))


func _draw_building_details(building: Dictionary, center: Vector2) -> void:
	var building_type: String = String(building["type"])
	var definition: Dictionary = world.catalog.building(building_type)
	var base_color: Color = Color.from_string("#" + String(definition.get("color", "888888")), Color.GRAY)
	match building_type:
		"farm":
			_draw_farm_details(center)
		"mill":
			_draw_mill_details(center, building)
		"bakery":
			_draw_bakery_details(center, building)
		"quarry":
			_draw_quarry_details(center)
		"coal_mine", "iron_mine", "gold_mine":
			_draw_mine_details(center, base_color)
		"iron_smithy", "metallurgist", "weapon_smithy", "armour_smithy":
			_draw_forge_details(center, building)
		"swine_farm", "stables":
			_draw_livestock_details(center, building_type == "stables")
		"vineyard":
			_draw_vineyard_details(center)
		"marketplace", "market":
			_draw_market_details(center)
		"inn":
			_draw_inn_details(center)
		"barracks", "town_hall", "watchtower":
			_draw_military_details(center, building_type)
		"school":
			_draw_school_details(center)
		"fisher_hut":
			_draw_fisher_details(center)
		_:
			_draw_workshop_details(center, definition)

func _draw_ellipse_shadow(center: Vector2) -> void:
	var points := PackedVector2Array()
	for index: int in range(20):
		var angle: float = float(index) * TAU / 20.0
		points.append(center + Vector2(cos(angle) * 28.0 + 4.0, sin(angle) * 9.0 + 3.0))
	_draw_canvas.draw_colored_polygon(points, Color(0.035, 0.045, 0.025, 0.26))


func _draw_construction_site(center: Vector2, building: Dictionary, definition: Dictionary) -> void:
	_draw_canvas.draw_colored_polygon(_building_wall_polygon(center), Color(0.33, 0.28, 0.21, 0.65))
	var timber := Color(0.69, 0.48, 0.26)
	for side: int in [-1, 1]:
		for post: int in range(3):
			var foot: Vector2 = center + Vector2(float(side) * float(8 + post * 10), 4 - post * 5)
			_draw_canvas.draw_line(foot, foot + Vector2(0, -37), timber, 2.5)
		_draw_canvas.draw_line(center + Vector2(side * 28, -13), center + Vector2(side * 8, -2), timber, 2.5)
		_draw_canvas.draw_line(center + Vector2(side * 28, -34), center + Vector2(side * 8, -23), timber, 2.5)
		_draw_canvas.draw_line(center + Vector2(side * 28, -13), center + Vector2(side * 8, -23), timber.darkened(0.15), 2.0)
	var total: float = maxf(1.0, float(definition.get("construction_ticks", 120)))
	var progress: float = clampf(1.0 - float(building["construction_remaining"]) / total, 0.0, 1.0)
	_draw_canvas.draw_rect(Rect2(center + Vector2(-22, 11), Vector2(44, 4)), Color(0.12, 0.14, 0.10))
	_draw_canvas.draw_rect(Rect2(center + Vector2(-22, 11), Vector2(44 * progress, 4)), Color(0.88, 0.70, 0.30))
	_draw_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-30, 29), String(definition.get("display_name", building["type"])), HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.96, 0.85, 0.57))


func _draw_mine_details(center: Vector2, base_color: Color) -> void:
	_draw_canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -5), center + Vector2(-15, -26), center + Vector2(0, -32), center + Vector2(15, -26), center + Vector2(15, -5)]), Color(0.13, 0.14, 0.13))
	_draw_canvas.draw_polyline(PackedVector2Array([center + Vector2(-16, -4), center + Vector2(-16, -28), center + Vector2(0, -35), center + Vector2(16, -28), center + Vector2(16, -4)]), Color(0.51, 0.34, 0.19), 4.0)
	for rail: int in [-1, 1]:
		_draw_canvas.draw_line(center + Vector2(rail * 5, -12), center + Vector2(rail * 10, 9), Color(0.60, 0.61, 0.56), 2.0)
	_draw_canvas.draw_rect(Rect2(center + Vector2(-8, -8), Vector2(17, 9)), base_color.lightened(0.18))
	_draw_canvas.draw_circle(center + Vector2(-5, 2), 3.0, Color(0.23, 0.22, 0.18))
	_draw_canvas.draw_circle(center + Vector2(7, 2), 3.0, Color(0.23, 0.22, 0.18))


func _draw_forge_details(center: Vector2, building: Dictionary) -> void:
	_draw_canvas.draw_rect(Rect2(center + Vector2(12, -56), Vector2(9, 31)), Color(0.37, 0.34, 0.30))
	_draw_canvas.draw_rect(Rect2(center + Vector2(10, -57), Vector2(13, 4)), Color(0.62, 0.57, 0.48))
	_draw_canvas.draw_circle(center + Vector2(13, -11), 8.0, Color(0.21, 0.19, 0.17))
	if int(building.get("process_remaining", 0)) > 0:
		_draw_canvas.draw_circle(center + Vector2(13, -11), 5.0, Color(0.94, 0.41, 0.10))
		_draw_canvas.draw_circle(center + Vector2(17, -61), 4.0, Color(0.60, 0.59, 0.54, 0.36))
	_draw_canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-25, -9), center + Vector2(-7, -9), center + Vector2(-13, -4), center + Vector2(-12, 3), center + Vector2(-22, 3), center + Vector2(-20, -4)]), Color(0.42, 0.46, 0.47))
	_draw_workshop_details(center, world.catalog.building(String(building["type"])))


func _draw_livestock_details(center: Vector2, horse: bool) -> void:
	var fence := Color(0.65, 0.48, 0.29)
	for post: int in range(4):
		_draw_canvas.draw_line(center + Vector2(-28 + post * 17, 10), center + Vector2(-28 + post * 17, -4), fence, 2.0)
	_draw_canvas.draw_line(center + Vector2(-29, 3), center + Vector2(24, 3), fence, 2.0)
	var animal: Vector2 = center + Vector2(10, -3)
	var color: Color = Color(0.59, 0.38, 0.22) if horse else Color(0.79, 0.57, 0.48)
	_draw_canvas.draw_circle(animal, 6.0, color)
	_draw_canvas.draw_circle(animal + Vector2(6, -3 if horse else 0), 4.0, color.lightened(0.1))
	for leg: int in [-1, 1]:
		_draw_canvas.draw_line(animal + Vector2(leg * 3, 3), animal + Vector2(leg * 3, 8), color.darkened(0.2), 2.0)
	if horse:
		_draw_canvas.draw_line(animal + Vector2(4, -1), animal + Vector2(6, -9), color, 4.0)
		_draw_canvas.draw_circle(animal + Vector2(8, -10), 3.5, color)


func _draw_vineyard_details(center: Vector2) -> void:
	for barrel: int in range(2):
		var point: Vector2 = center + Vector2(-21 + barrel * 11, -3 + barrel * 3)
		_draw_canvas.draw_rect(Rect2(point + Vector2(-4, -7), Vector2(9, 13)), Color(0.50, 0.31, 0.16))
		_draw_canvas.draw_line(point + Vector2(-4, -4), point + Vector2(5, -4), Color(0.73, 0.67, 0.49), 1.5)
		_draw_canvas.draw_line(point + Vector2(-4, 3), point + Vector2(5, 3), Color(0.73, 0.67, 0.49), 1.5)
	for leaf: int in range(5):
		_draw_canvas.draw_circle(center + Vector2(5 + leaf * 4, -28 + leaf % 2 * 5), 4.0, Color(0.29, 0.47, 0.18))
	for grape: int in range(4):
		_draw_canvas.draw_circle(center + Vector2(10 + grape % 2 * 3, -21 + grape * 2), 2.2, Color(0.43, 0.25, 0.49))


func _draw_market_details(center: Vector2) -> void:
	for stripe: int in range(6):
		var x: float = -26 + float(stripe) * 9
		_draw_canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(x, -21), center + Vector2(x + 8, -21), center + Vector2(x + 8, -8), center + Vector2(x, -8)]), Color(0.79, 0.36, 0.22) if stripe % 2 == 0 else Color(0.88, 0.81, 0.59))
	_draw_canvas.draw_line(center + Vector2(-26, -21), center + Vector2(-26, 4), Color(0.45, 0.29, 0.16), 2.5)
	_draw_canvas.draw_line(center + Vector2(27, -21), center + Vector2(27, 4), Color(0.45, 0.29, 0.16), 2.5)
	_draw_canvas.draw_line(center + Vector2(-26, 1), center + Vector2(27, 1), Color(0.45, 0.29, 0.16), 4.0)
	for ware: int in range(5):
		_draw_canvas.draw_circle(center + Vector2(-19 + ware * 9, -3), 3.0, Color(0.78, 0.60, 0.30).lightened(float(ware % 3) * 0.08))


func _draw_inn_details(center: Vector2) -> void:
	_draw_canvas.draw_line(center + Vector2(-24, -28), center + Vector2(-35, -28), Color(0.38, 0.27, 0.16), 2.0)
	_draw_canvas.draw_rect(Rect2(center + Vector2(-37, -27), Vector2(12, 12)), Color(0.82, 0.65, 0.35))
	_draw_canvas.draw_rect(Rect2(center + Vector2(-34, -24), Vector2(5, 7)), Color(0.42, 0.27, 0.14))
	_draw_canvas.draw_arc(center + Vector2(-29, -20), 2.5, -PI * 0.5, PI * 0.5, 10, Color(0.42, 0.27, 0.14), 1.0)
	_draw_canvas.draw_rect(Rect2(center + Vector2(5, -18), Vector2(9, 8)), Color(0.98, 0.77, 0.36))
	_draw_canvas.draw_line(center + Vector2(9.5, -18), center + Vector2(9.5, -10), Color(0.43, 0.29, 0.16), 1.5)


func _draw_military_details(center: Vector2, building_type: String) -> void:
	if building_type == "watchtower":
		_draw_canvas.draw_rect(Rect2(center + Vector2(-15, -59), Vector2(30, 47)), Color(0.48, 0.50, 0.47))
		for merlon: int in range(3):
			_draw_canvas.draw_rect(Rect2(center + Vector2(-17 + merlon * 13, -65), Vector2(8, 11)), Color(0.62, 0.64, 0.57))
		_draw_canvas.draw_rect(Rect2(center + Vector2(-3, -42), Vector2(6, 13)), Color(0.19, 0.22, 0.20))
	_draw_canvas.draw_line(center + Vector2(14, -34), center + Vector2(14, -63), Color(0.53, 0.42, 0.26), 2.0)
	_draw_canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(15, -62), center + Vector2(30, -58), center + Vector2(15, -51)]), Color(0.36, 0.50, 0.76))
	if building_type == "barracks":
		_draw_canvas.draw_line(center + Vector2(-15, -18), center + Vector2(-3, -2), Color(0.84, 0.85, 0.75), 2.0)
		_draw_canvas.draw_line(center + Vector2(-3, -18), center + Vector2(-15, -2), Color(0.84, 0.85, 0.75), 2.0)


func _draw_school_details(center: Vector2) -> void:
	var book: Vector2 = center + Vector2(4, -26)
	_draw_canvas.draw_colored_polygon(PackedVector2Array([book + Vector2(-10, -2), book + Vector2(0, 1), book + Vector2(10, -2), book + Vector2(10, 8), book + Vector2(0, 11), book + Vector2(-10, 8)]), Color(0.91, 0.86, 0.66))
	_draw_canvas.draw_line(book + Vector2(0, 1), book + Vector2(0, 11), Color(0.41, 0.31, 0.18), 1.5)
	# A sapling beside the school makes the tree-planting profession discoverable.
	_draw_canvas.draw_line(center + Vector2(-24, 3), center + Vector2(-24, -8), Color(0.47, 0.30, 0.13), 2.0)
	_draw_canvas.draw_circle(center + Vector2(-27, -8), 4.0, Color(0.35, 0.61, 0.24))
	_draw_canvas.draw_circle(center + Vector2(-21, -10), 4.0, Color(0.43, 0.68, 0.28))


func _draw_fisher_details(center: Vector2) -> void:
	_draw_canvas.draw_line(center + Vector2(-19, 2), center + Vector2(-29, -34), Color(0.58, 0.40, 0.23), 2.0)
	_draw_canvas.draw_line(center + Vector2(-29, -34), center + Vector2(-34, -3), Color(0.76, 0.76, 0.65), 1.0)
	for net: int in range(4):
		_draw_canvas.draw_line(center + Vector2(2 + net * 6, -16), center + Vector2(6 + net * 4, 2), Color(0.73, 0.72, 0.54), 1.0)
		_draw_canvas.draw_line(center + Vector2(2, -14 + net * 5), center + Vector2(23, -14 + net * 5), Color(0.73, 0.72, 0.54), 1.0)


func _draw_workshop_details(center: Vector2, definition: Dictionary) -> void:
	var outputs: Array = definition.get("outputs", []) as Array
	if outputs.is_empty():
		return
	var resource_id: String = String(outputs[0])
	var resource: Dictionary = world.catalog.resources.get(resource_id, {}) as Dictionary
	var color: Color = Color.from_string("#" + String(resource.get("color", "b88851")), Color.TAN)
	var sign: Vector2 = center + Vector2(-12, -16)
	if resource_id in ["axe", "sword", "lance", "pike", "bow", "crossbow"]:
		_draw_canvas.draw_line(sign + Vector2(-5, 8), sign + Vector2(5, -8), Color(0.76, 0.65, 0.40), 2.5)
		_draw_canvas.draw_colored_polygon(PackedVector2Array([sign + Vector2(0, -6), sign + Vector2(8, -10), sign + Vector2(9, -2), sign + Vector2(3, -1)]), color)
	elif "shield" in resource_id or "armour" in resource_id or resource_id in ["skin", "leather"]:
		_draw_canvas.draw_colored_polygon(PackedVector2Array([sign + Vector2(-6, -7), sign + Vector2(6, -7), sign + Vector2(5, 3), sign + Vector2(0, 8), sign + Vector2(-5, 3)]), color)
		_draw_canvas.draw_line(sign + Vector2(0, -6), sign + Vector2(0, 6), color.lightened(0.25), 1.5)
	elif resource_id == "sausage":
		for link: int in range(3):
			_draw_canvas.draw_line(sign + Vector2(-7 + link * 6, -6), sign + Vector2(-6 + link * 6, 5), color, 4.0, true)
	else:
		for crate: int in range(2):
			_draw_canvas.draw_rect(Rect2(center + Vector2(-23 + crate * 10, -6 + crate * 3), Vector2(9, 7)), color)
			_draw_canvas.draw_line(center + Vector2(-23 + crate * 10, -3 + crate * 3), center + Vector2(-14 + crate * 10, -3 + crate * 3), color.lightened(0.22), 1.0)


func _draw_farm_details(center: Vector2) -> void:
	# Barn doors and a bundled sheaf identify the farm; growing crops occupy real fields.
	_draw_canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(5, -17), center + Vector2(18, -24),
		center + Vector2(18, -3), center + Vector2(5, 4),
	]), Color(0.36, 0.22, 0.10))
	_draw_canvas.draw_line(center + Vector2(11, -20), center + Vector2(11, 1), Color(0.71, 0.48, 0.20), 1.5)
	_draw_canvas.draw_line(center + Vector2(6, -12), center + Vector2(17, -6), Color(0.77, 0.54, 0.25), 1.5)
	for stalk: int in range(6):
		var x: float = float(stalk) * 2.0
		_draw_canvas.draw_line(center + Vector2(-25.0 + x, 3), center + Vector2(-22.0 + x, -12), Color(0.89, 0.71, 0.29), 2.0)
	_draw_canvas.draw_line(center + Vector2(-24, -2), center + Vector2(-12, -2), Color(0.39, 0.26, 0.11), 2.0)
	_draw_canvas.draw_line(center + Vector2(-19, -33), center + Vector2(0, -45), Color(0.88, 0.72, 0.35), 2.0)


func _draw_mill_details(center: Vector2, building: Dictionary) -> void:
	var hub: Vector2 = center + Vector2(0, -35)
	# Read simulation progress for the sails, so pause and save/load remain visually coherent.
	var angle: float = 0.24
	if int(building.get("process_remaining", 0)) > 0:
		angle += float(world.tick % 160) * TAU / 160.0
	for blade: int in range(4):
		var direction: Vector2 = Vector2.from_angle(angle + float(blade) * PI * 0.5)
		var side: Vector2 = direction.orthogonal()
		var corners := PackedVector2Array([
			hub + direction * 5.0 - side * 2.0,
			hub + direction * 25.0 - side * 4.0,
			hub + direction * 25.0 + side * 4.0,
			hub + direction * 5.0 + side * 2.0,
		])
		_draw_canvas.draw_colored_polygon(corners, Color(0.92, 0.85, 0.65))
		_draw_canvas.draw_line(hub, hub + direction * 27.0, Color(0.36, 0.26, 0.14), 2.0, true)
		for rib: int in range(3):
			var point: Vector2 = hub + direction * (10.0 + float(rib) * 6.0)
			_draw_canvas.draw_line(point - side * 3.0, point + side * 3.0, Color(0.63, 0.48, 0.28), 1.0, true)
	_draw_canvas.draw_circle(hub, 4.0, Color(0.39, 0.28, 0.15))
	_draw_canvas.draw_rect(Rect2(center + Vector2(7, -12), Vector2(7, 12)), Color(0.30, 0.24, 0.16))


func _draw_bakery_details(center: Vector2, building: Dictionary) -> void:
	var brick := Color(0.52, 0.29, 0.19)
	_draw_canvas.draw_rect(Rect2(center + Vector2(13, -54), Vector2(8, 23)), brick)
	_draw_canvas.draw_rect(Rect2(center + Vector2(11, -55), Vector2(12, 4)), brick.lightened(0.18))
	for row: int in range(3):
		_draw_canvas.draw_line(center + Vector2(13, -49 + row * 6), center + Vector2(21, -49 + row * 6), brick.lightened(0.12), 1.0)
	var oven: Vector2 = center + Vector2(11, -10)
	_draw_canvas.draw_circle(oven, 7.5, Color(0.68, 0.58, 0.44))
	_draw_canvas.draw_rect(Rect2(oven + Vector2(-7.5, 0), Vector2(15, 7)), Color(0.68, 0.58, 0.44))
	_draw_canvas.draw_circle(oven + Vector2(0, 1), 4.5, Color(0.22, 0.15, 0.09))
	_draw_canvas.draw_rect(Rect2(oven + Vector2(-4.5, 1), Vector2(9, 6)), Color(0.22, 0.15, 0.09))
	if int(building.get("process_remaining", 0)) > 0:
		_draw_canvas.draw_circle(oven + Vector2(0, 3), 3.0, Color(0.96, 0.44, 0.12))
		_draw_canvas.draw_circle(center + Vector2(17, -59), 3.5, Color(0.69, 0.69, 0.64, 0.44))
		_draw_canvas.draw_circle(center + Vector2(20, -66), 4.5, Color(0.69, 0.69, 0.64, 0.27))
	_draw_canvas.draw_line(center + Vector2(-21, -3), center + Vector2(-5, 5), Color(0.38, 0.23, 0.12), 3.0)
	for loaf: int in range(3):
		_draw_canvas.draw_circle(center + Vector2(-18 + loaf * 5, -5 + loaf * 2), 3.0, Color(0.85, 0.62, 0.29))


func _draw_quarry_details(center: Vector2) -> void:
	# Stone blocks and a pick mark the workshop beside a natural rock deposit.
	for block: int in range(3):
		var offset: Vector2 = Vector2(-24 + block * 10, block % 2 * 4)
		_draw_canvas.draw_colored_polygon(PackedVector2Array([
			center + offset + Vector2(0, -3), center + offset + Vector2(3, -10),
			center + offset + Vector2(10, -11), center + offset + Vector2(13, -5),
			center + offset + Vector2(10, 2), center + offset + Vector2(1, 3),
		]), Color(0.66, 0.69, 0.66).lightened(float(block) * 0.05))
		_draw_canvas.draw_line(center + offset + Vector2(3, -10), center + offset + Vector2(10, -11), Color(0.88, 0.87, 0.77), 1.5)
	_draw_canvas.draw_line(center + Vector2(8, 1), center + Vector2(19, -24), Color(0.44, 0.28, 0.13), 3.0)
	_draw_canvas.draw_polyline(PackedVector2Array([
		center + Vector2(10, -28), center + Vector2(20, -25), center + Vector2(25, -18),
	]), Color(0.78, 0.81, 0.79), 3.0, true)


func _worker_id_at_visual_position(position: Vector2) -> int:
	# Follow the same back-to-front order as drawing, including moving sprites.
	var entries: Array[Dictionary] = _world_draw_entries()
	entries.reverse()
	for entry: Dictionary in entries:
		if terrain_renderer.point_occluded(position, entry["ground_position"] as Vector2):
			continue
		if entry["kind"] == "worker":
			var presentation: Dictionary = worker_presentation(entry["state"] as Dictionary, entry["position"] as Vector2)
			if (presentation["rect"] as Rect2).grow(2.0).has_point(position):
				return int(entry["id"])
		elif entry["kind"] == "building":
			if _building_contains_visual_point(entry["state"], position):
				return 0
	return 0


func _building_id_at_visual_position(position: Vector2) -> int:
	var entries: Array[Dictionary] = _world_draw_entries()
	entries.reverse()
	for entry: Dictionary in entries:
		if entry["kind"] != "building" or terrain_renderer.point_occluded(position, entry["ground_position"] as Vector2):
			continue
		if _building_contains_visual_point(entry["state"], position):
			return int(entry["id"])
	return 0


func _building_contains_visual_point(building: Dictionary, position: Vector2) -> bool:
	var center: Vector2 = terrain_renderer.cell_center(building["position"] as Vector2i)
	if int(building.get("footprint_version", 0)) > 0:
		var shape: Dictionary = building_geometry(building)
		if BuildingFootprintRendererClass.contains_point(shape, position, int(building.get("construction_remaining", 0)) > 0):
			return true
		center = shape["detail_center"]
	else:
		if Geometry2D.is_point_in_polygon(position, _building_roof_polygon(center)) or Geometry2D.is_point_in_polygon(position, _building_wall_polygon(center)):
			return true
	if int(building.get("construction_remaining", 0)) > 0:
		return false
	if String(building["type"]) == "mill" and position.distance_to(center + Vector2(0, -35)) <= 27.0:
		return true
	if String(building["type"]) == "bakery" and Rect2(center + Vector2(11, -55), Vector2(12, 25)).has_point(position):
		return true
	return false


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


# Exposes the exact presentation used by drawing without altering the worker.
func worker_presentation(worker: Dictionary, foot_position: Vector2) -> Dictionary:
	var frame_alpha: float = clampf(accumulator / FIXED_TICK_SECONDS, 0.0, 1.0)
	return unit_sprites.presentation_for(worker, foot_position, world.tick, frame_alpha)


func _draw_worker(worker: Dictionary, foot_position: Vector2) -> void:
	# A retained row may still reference the worker when a tick moves them
	# indoors. Stop before submitting any sprite, shadow, cargo or hunger mark.
	if world.is_worker_inside(worker):
		return
	var presentation: Dictionary = worker_presentation(worker, foot_position)
	_draw_unit_shadow(foot_position, presentation["shadow_size"] as Vector2)
	if int(worker["id"]) == selected_unit_id:
		_draw_canvas.draw_arc(foot_position, 10.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.28), 1.5, true)
	var texture: Texture2D = presentation["texture"] as Texture2D
	var rect: Rect2 = presentation["rect"] as Rect2
	if texture != null:
		# Mirroring is around the foot's vertical axis, never around an atlas
		# corner. Terrain-row ordering still uses the unmodified ground point.
		var flip: float = -1.0 if bool(presentation["flip_h"]) else 1.0
		_draw_canvas.draw_set_transform(rect.position + Vector2(rect.size.x * 0.5, 0), 0.0, Vector2(flip, 1.0))
		_draw_canvas.draw_texture_rect(texture, Rect2(Vector2(-rect.size.x * 0.5, 0), rect.size), false)
		_draw_canvas.draw_set_transform(Vector2.ZERO)
	else:
		_draw_missing_unit(foot_position)
	var carrying: String = String(worker.get("carrying", ""))
	if not carrying.is_empty():
		var definition: Dictionary = world.catalog.resources.get(carrying, {}) as Dictionary
		var color: Color = Color.from_string("#" + String(definition.get("color", "d0a966")), Color.TAN)
		unit_sprites.paint_cargo(_draw_canvas, carrying, presentation["cargo_position"] as Vector2, color)
	_draw_worker_earthwork(worker_earthwork_presentation(worker, foot_position))
	_draw_worker_satiety(worker_satiety_presentation(worker, foot_position))


# Read-only working cue; its phase comes only from simulation ticks, so pausing
# freezes the shovel and loading the same tick reproduces the same pose.
func worker_earthwork_presentation(worker: Dictionary, foot_position: Vector2) -> Dictionary:
	var site: Dictionary = world.buildings.get(int(worker.get("source_id", 0)), {})
	if world.is_worker_inside(worker) or worker.get("action", "") != "build_site" \
			or worker.get("state", "") != "working" or int(site.get("foundation_work_remaining", 0)) <= 0:
		return {"visible": false}
	if not world.can_worker_work(worker) or int(worker.get("visual_progress_ticks", 0)) < int(worker.get("visual_duration_ticks", 0)) \
			or not world.BuildingFoundationsClass.waiting_reason(world, site, int(worker["id"])).is_empty():
		return {"visible": false}
	var phase: float = float(world.tick % 12) / 12.0
	var lift: float = sin(phase * PI)
	var hand: Vector2 = foot_position + Vector2(5, -12)
	var shovel: Vector2 = foot_position + Vector2(15 - 5 * lift, 2 - 10 * lift)
	return {"visible": true, "hand": hand, "shovel": shovel,
		"soil": foot_position + Vector2(18, -4 - 6 * lift), "phase": phase}


func _draw_worker_earthwork(presentation: Dictionary) -> void:
	if not bool(presentation.get("visible", false)):
		return
	var shovel: Vector2 = presentation["shovel"]
	_draw_canvas.draw_line(presentation["hand"], shovel, Color(0.69, 0.48, 0.24), 2.0, true)
	_draw_canvas.draw_colored_polygon(PackedVector2Array([shovel + Vector2(-3, -2), shovel + Vector2(3, -2),
		shovel + Vector2(3, 2), shovel + Vector2(0, 5), shovel + Vector2(-3, 2)]), Color(0.69, 0.73, 0.70))
	_draw_canvas.draw_circle(presentation["soil"], 2.0, Color(0.44, 0.31, 0.16))


func worker_satiety_presentation(worker: Dictionary, foot_position: Vector2) -> Dictionary:
	if world.is_worker_inside(worker):
		return {"visible": false}
	var status: Dictionary = world.hunger_status(worker)
	var unit: Dictionary = worker_presentation(worker, foot_position)
	var anchor: Vector2 = unit["hunger_position"] as Vector2
	var zoom_scale: float = maxf(0.3, camera.zoom.x) if camera != null else 1.0
	var width: float = maxf(24.0, 12.0 / zoom_scale)
	var height: float = maxf(3.0, 2.0 / zoom_scale)
	var percent: float = float(status["satiety_percent"])
	var rect := Rect2(anchor - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
	return {
		"visible": true, "rect": rect,
		"fill_rect": Rect2(rect.position, Vector2(width * clampf(percent / 100.0, 0.0, 1.0), height)),
		"color": GameHudClass.satiety_color(String(status["state"])),
		"percent": percent,
		"caption": "Satiety %.0f%%" % percent if int(worker["id"]) == selected_unit_id else "",
		"caption_scale": 1.0 / zoom_scale,
		"food_requested": bool(worker.get("food_requested", false)),
		"request_color": _worker_food_marker_color(worker),
	}


func _draw_worker_satiety(presentation: Dictionary) -> void:
	if not bool(presentation.get("visible", false)):
		return
	var rect: Rect2 = presentation["rect"] as Rect2
	_draw_canvas.draw_rect(rect.grow(1.0), Color(0.045, 0.065, 0.05, 0.90))
	_draw_canvas.draw_rect(rect, Color("#344139"))
	var fill_rect: Rect2 = presentation["fill_rect"] as Rect2
	if fill_rect.size.x > 0.0:
		_draw_canvas.draw_rect(fill_rect, presentation["color"] as Color)
	if bool(presentation["food_requested"]):
		_draw_canvas.draw_circle(Vector2(rect.end.x + 4.0, rect.get_center().y), 2.0, presentation["request_color"] as Color)
	var caption: String = String(presentation["caption"])
	if not caption.is_empty():
		var scale: float = float(presentation["caption_scale"])
		var caption_width: float = 80.0 * scale
		var position: Vector2 = Vector2(rect.get_center().x - caption_width * 0.5, rect.position.y - 4.0 * scale)
		var font_size: int = maxi(10, int(round(10.0 * scale)))
		_draw_canvas.draw_string_outline(ThemeDB.fallback_font, position, caption, HORIZONTAL_ALIGNMENT_CENTER, caption_width, font_size, 3, Color("#102017"))
		_draw_canvas.draw_string(ThemeDB.fallback_font, position, caption, HORIZONTAL_ALIGNMENT_CENTER, caption_width, font_size, Color("#e9e9dc"))


func _worker_food_marker_color(worker: Dictionary) -> Color:
	return Color("#77c5e8") if bool(worker.get("food_requested", false)) else Color.TRANSPARENT


func _draw_unit_shadow(feet: Vector2, dimensions: Vector2) -> void:
	var points := PackedVector2Array()
	for index: int in range(16):
		var angle: float = float(index) / 16.0 * TAU
		points.append(feet + Vector2(cos(angle), sin(angle)) * dimensions * 0.5)
	_draw_canvas.draw_colored_polygon(points, Color(0.04, 0.055, 0.045, 0.23))


func _draw_missing_unit(feet: Vector2) -> void:
	# Graceful development fallback only if an atlas is missing or unreadable.
	# Unknown future roles normally reuse the carrier sprite in the library.
	_draw_canvas.draw_line(feet + Vector2(-3, 0), feet + Vector2(-2, -12), Color(0.22, 0.20, 0.16), 3.0)
	_draw_canvas.draw_line(feet + Vector2(3, 0), feet + Vector2(2, -12), Color(0.22, 0.20, 0.16), 3.0)
	_draw_canvas.draw_colored_polygon(PackedVector2Array([feet + Vector2(-6, -11), feet + Vector2(-4, -23), feet + Vector2(4, -23), feet + Vector2(6, -11)]), Color(0.49, 0.51, 0.41))
	_draw_canvas.draw_rect(Rect2(feet + Vector2(-3, -29), Vector2(6, 7)), Color(0.83, 0.69, 0.51))


func _build_ui() -> void:
	hud = GameHudClass.new()
	hud.build_mode_requested.connect(_set_build_mode)
	hud.simulation_speed_requested.connect(_set_simulation_speed)
	hud.unit_training_requested.connect(_queue_selected_unit)
	hud.production_order_requested.connect(_queue_selected_production)
	hud.recruitment_requested.connect(_queue_selected_recruitment)
	hud.trade_requested.connect(_queue_selected_trade)
	hud.terrain_rules_requested.connect(_set_terrain_rules)
	hud.construction_cancel_requested.connect(_cancel_selected_construction)
	hud.soldier_food_requested.connect(_request_soldier_food)
	hud.army_food_requested.connect(_request_army_food)
	hud.main_menu_requested.connect(_request_main_menu)
	add_child(hud)
	hud.configure(world.catalog, main_menu_requested.has_connections())


func _request_main_menu() -> void:
	dragging_camera = false
	_set_build_mode("")
	_pointer_inside = false
	_clear_placement_preview()
	main_menu_requested.emit()


func _save_game() -> bool:
	var saved: bool = SaveSystemClass.save_world(world, _save_game_path(), demo_kind)
	world._push_event("Game saved." if saved else "Save failed.")
	_update_ui()
	return saved


func _set_build_mode(mode: String) -> void:
	build_mode = mode
	if not mode.is_empty():
		selected_unit_id = 0
	terrain_renderer.allow_ground_preparation = mode not in ["", "road", "field", "vine_field"]
	terrain_renderer.show_buildability = not mode.is_empty() and mode != "road"
	_preview_state_key.clear()
	_update_ui()
	_update_placement_preview()
	if hud != null:
		hud.show_build_tool(mode)


func _set_simulation_speed(speed: float) -> void:
	simulation_speed = speed
	if speed > 0.0:
		speed_before_pause = speed
	_update_ui()


func _set_terrain_rules(enabled: bool) -> void:
	show_terrain_rules = enabled
	terrain_renderer.show_passability = enabled
	if hud != null:
		hud.set_terrain_rules(enabled)
	if enabled:
		world._push_event("Terrain: green = level ground; amber = walkable slope; red = blocked. Occupied tiles still apply.")
	queue_redraw()


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
	elif build_mode == "field":
		success = world.place_field(cell) != 0
	elif build_mode == "vine_field":
		success = int(world.call("place_field", cell, "vine")) != 0
	else:
		success = world.place_building(build_mode, cell) != 0
	if not success:
		if world.grid.cell_slope(cell) > world.grid.MAX_WALK_SLOPE:
			world._push_event("This slope is too steep: use a gentler route or a mountain pass.")
		elif build_mode != "road" and world.grid.cell_slope(cell) > world.grid.MAX_BUILD_SLOPE:
			world._push_event("Buildings and fields need level ground, including on raised plateaus.")
		elif build_mode in ["field", "vine_field"]:
			world._push_event("Fields need clear grass or dirt: no trees, roads or buildings.")
		elif build_mode == "quarry":
			world._push_event("Quarry needs clear ground within 3 tiles of rock.")
		elif world.field_id_at(cell) != 0:
			world._push_event("This wheat field is reserved for farming.")
		else:
			world._push_event("Cannot build there: choose clear, buildable ground.")


func _cancel_selected_construction() -> void:
	var building_id: int = world.building_id_at(selected_cell)
	if world.cancel_construction(building_id):
		# Clear placement too, so the next click cannot recreate the cancelled site.
		_set_build_mode("")
		selected_cell = Vector2i(-1, -1)
	_update_ui()
	queue_redraw()


func _queue_selected_unit(unit_type: String) -> void:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0 or not world.queue_unit_training(building_id, unit_type):
		world._push_event("Select a School with room in its training queue.")
	_update_ui()


func _queue_selected_production(recipe_id: String) -> void:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0 or not bool(world.call("queue_production", building_id, recipe_id)):
		world._push_event("Select a completed workshop with room for another order.")
	_update_ui()


func _queue_selected_recruitment(soldier_type: String) -> void:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0 or not bool(world.call("queue_recruitment", building_id, soldier_type)):
		world._push_event("Select completed Barracks or Town Hall with room in its queue.")
	_update_ui()


func _queue_selected_trade(give_resource: String, receive_resource: String) -> void:
	var building_id: int = world.building_id_at(selected_cell)
	if building_id == 0 or not bool(world.call("queue_trade", building_id, give_resource, receive_resource)):
		world._push_event("Select a completed Marketplace and two different wares.")
	_update_ui()


func _update_ui() -> void:
	if selected_unit_id != 0:
		if world.workers.has(selected_unit_id):
			selected_cell = (world.workers[selected_unit_id] as Dictionary)["position"] as Vector2i
		else:
			selected_unit_id = 0
	if hud != null:
		hud.refresh(world, selected_cell, build_mode, simulation_speed, FIXED_TICK_SECONDS, selected_unit_id)
	_update_day_lighting()


func _update_day_lighting() -> void:
	if world == null:
		return
	# Fractional simulation time makes the sun glide at any game speed. The
	# accumulator stays fixed during pause; load/reset supplies a new saved tick.
	var fraction: float = clampf(accumulator / FIXED_TICK_SECONDS, 0.0, 1.0)
	solar_state = SolarCycleClass.sample(world.tick, fraction)
	# Modulate this world's CanvasItems only. The HUD has its own CanvasLayer,
	# and multiple viewports/worlds can each have an independent time of day.
	modulate = solar_state["ambient"] as Color
	if hud != null:
		hud.update_sky_time(world.tick, fraction)


func _request_soldier_food(unit_id: int) -> void:
	if world.request_soldier_food(unit_id):
		world._push_event("Food requested. A carrier will bring one ration to the soldier.")
	else:
		world._push_event(world.soldier_food_status(unit_id))
	_update_ui()


func _request_army_food() -> void:
	var requested: int = world.request_army_food()
	if requested == 0:
		world._push_event("No soldiers need another food request.")
	_update_ui()


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
		_camera_auto_fit = false
		camera.position += direction.normalized() * 430.0 * delta / camera.zoom.x


func _set_zoom(value: float) -> void:
	_camera_auto_fit = false
	var clamped: float = clampf(value, _minimum_zoom(), 2.4)
	camera.zoom = Vector2(clamped, clamped)
	camera.force_update_scroll()
	_update_placement_preview()


func _create_demo_world() -> void:
	terrain_load_error = ""
	if demo_kind == "mountainous-region":
		var imported: Dictionary = ImportedTerrainClass.load_world(terrain_map_path)
		world = imported.get("world") as SimulationWorldClass
		if world != null:
			return
		terrain_load_error = String(imported.get("error", "Unknown map error"))
		# Never label fallback terrain as a successful replica of the source map.
		demo_kind = "test"
	if demo_kind == "economy":
		world = SimulationWorldClass.new()
		world.setup_economy_demo()
	elif demo_kind == "relief":
		world = SimulationWorldClass.new(ReliefDemoClass.MAP_SIZE)
		ReliefDemoClass.setup(world)
	else:
		world = SimulationWorldClass.new(TestLevelClass.MAP_SIZE)
		TestLevelClass.setup(world)
	if not terrain_load_error.is_empty():
		world._push_event("Mountainous Region could not be loaded: %s. Showing the test level." % terrain_load_error)


func _reset_demo() -> void:
	_set_build_mode("")
	_pointer_inside = false
	_clear_placement_preview()
	_create_demo_world()
	_update_window_title()
	terrain_renderer.bind_grid(world.grid)
	_center_camera()
	accumulator = 0.0
	selected_cell = Vector2i(-1, -1)
	selected_unit_id = 0
	_update_ui()
	queue_redraw()


func _save_game_path() -> String:
	if not save_path_override.is_empty():
		return save_path_override
	if save_path != SaveSystemClass.DEFAULT_PATH:
		return save_path
	return TERRAIN_STUDY_SAVE_PATH if demo_kind == "mountainous-region" else SaveSystemClass.DEFAULT_PATH


func _load_game() -> void:
	_set_build_mode("")
	_pointer_inside = false
	_clear_placement_preview()
	var path: String = _save_game_path()
	var loaded: bool = SaveSystemClass.load_world(world, path)
	if loaded:
		demo_kind = SaveSystemClass.saved_map_id(path)
		_update_window_title()
		selected_unit_id = 0
		terrain_renderer.bind_grid(world.grid)
		_center_camera()
		accumulator = 0.0
		if not world.grid.contains(selected_cell):
			selected_cell = Vector2i(-1, -1)
	world._push_event("Game loaded." if loaded else "No valid save found.")
	_update_ui()
	queue_redraw()


func _camera_map_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Rect2(Vector2(GameHudClass.MAP_LEFT, GameHudClass.MAP_TOP),
		Vector2(maxf(1.0, viewport_size.x - GameHudClass.MAP_LEFT - 12.0),
			maxf(1.0, viewport_size.y - GameHudClass.MAP_TOP - GameHudClass.MAP_BOTTOM)))


func _camera_fit_zoom() -> float:
	var bounds: Rect2 = terrain_renderer.map_bounds().grow(44.0)
	var available: Vector2 = _camera_map_rect().size
	return clampf(minf(available.x / maxf(1.0, bounds.size.x),
		available.y / maxf(1.0, bounds.size.y)), 0.001, 1.0)


func _minimum_zoom() -> float:
	# Keep the familiar close-map range, but let a large imported region fit.
	return minf(0.30, _camera_fit_zoom())


func _center_camera() -> void:
	_camera_auto_fit = true
	var bounds: Rect2 = terrain_renderer.map_bounds().grow(44.0)
	var fit_zoom: float = _camera_fit_zoom()
	camera.zoom = Vector2(fit_zoom, fit_zoom)
	camera.position = bounds.get_center() - (_camera_map_rect().get_center() - get_viewport_rect().size * 0.5) / fit_zoom


func _on_viewport_size_changed() -> void:
	# Fit the initial overview to the space around the HUD. Once the player
	# moves the camera, resizing must not discard their chosen view.
	if _camera_auto_fit:
		_center_camera()
		camera.force_update_scroll()
	_update_placement_preview()
	queue_redraw()


static func worker_lerp_alpha(worker: Dictionary, frame_alpha: float) -> float:
	var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
	var progress: int = clampi(int(worker.get("visual_progress_ticks", duration)), 0, duration)
	return clampf((float(progress) + frame_alpha) / float(duration), 0.0, 1.0)
