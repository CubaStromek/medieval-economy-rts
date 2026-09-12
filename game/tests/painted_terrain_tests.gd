extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const Library = preload("res://scripts/view/painted_terrain_library.gd")
const GroundCompositor = preload("res://scripts/view/painted_terrain_compositor.gd")
const SharedShader = preload("res://scripts/view/modern_terrain_shader.gd")
const SampleRenderer = preload("res://scripts/view/kam_terrain_sample_renderer.gd")
const Legacy = preload("res://tests/legacy_world_fixture.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 12

static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_real_atlas, _test_scene_and_legacy_defaults,
		_test_geometry_and_rules, _test_world_uvs, _test_surface_preservation,
		_test_incremental_terrain, _test_incremental_surface, _test_height_and_rebind,
		_test_definition_tint, _test_saved_world, _test_shared_compositor, _test_smooth_lighting_and_painter]:
		test.call(failures)
	return failures

static func _renderer(grid: Grid, painted: bool = true) -> Renderer:
	var result := Renderer.new()
	result.use_painted_terrain = painted
	result.bind_grid(grid)
	return result

static func _fixture() -> Grid:
	var grid := Grid.new(Vector2i(12, 10))
	grid.set_base_terrain(Vector2i(5, 4), "water")
	grid.set_base_terrain(Vector2i(6, 4), "rock")
	grid.set_base_terrain(Vector2i(4, 4), "dirt")
	grid.set_vertex_height(Vector2i(2, 2), 2)
	grid.add_road(Vector2i(7, 7))
	grid.add_road(Vector2i(8, 7))
	grid.add_dirt_trail(Vector2i(7, 6))
	grid.set_traffic_wear(Vector2i(3, 7), 12)
	return grid

static func _test_real_atlas(failures: Array[String]) -> void:
	var materials: Dictionary = Library.textures()
	_expect(materials.size() == 4, "V1 must load all four gameplay materials from the shipped atlas", failures)
	_expect(Library.MATERIAL_SLOTS == {"grass": 0, "dirt": 3, "water": 5, "rock": 2},
		"Gameplay material roles must map to the approved V1 swatches", failures)
	var source: Image = (load(Library.ATLAS_PATH) as Texture2D).get_image()
	if source.is_compressed():
		source.decompress()
	var again: Dictionary = Library.textures()
	var seen: Dictionary = {}
	for id: String in materials:
		var texture: Texture2D = materials[id]
		_expect(texture.get_width() > 400 and texture.get_height() > 400,
			"V1 must use high-resolution authored swatches, not old 64px procedural grain", failures)
		_expect(texture == again[id], "V1 swatches must be shared across renderers and maps", failures)
		_expect(not seen.has(texture.get_rid()), "Each terrain kind must have a distinct V1 swatch", failures)
		seen[texture.get_rid()] = true
		var slot: int = Library.MATERIAL_SLOTS[id]
		var left: int = ceili(float(slot % 4) * source.get_width() / 4.0) + 2
		var top: int = ceili(float(slot / 4) * source.get_height() / 2.0) + 2
		_expect(texture.get_image().get_pixel(16,16).is_equal_approx(source.get_pixel(left + 16, top + 16)),
			"V1 material pixels must come from the correct original atlas swatch without recoloring", failures)
		_expect(texture.get_image().has_mipmaps(), "Minified terrain needs mipmaps", failures)
	_expect(Library.textures("res://missing-v1-atlas.png").is_empty(), "A missing atlas must produce an explicit empty fallback set", failures)

static func _test_scene_and_legacy_defaults(failures: Array[String]) -> void:
	var main: Node = MainScene.instantiate()
	_expect(main.get_node("TerrainRenderer").use_painted_terrain, "Every existing gameplay map must opt into V1 through the common main scene", failures)
	main.free()
	var legacy := Renderer.new()
	_expect(not legacy.use_painted_terrain, "Standalone historical sandbox renderer must retain its procedural default", failures)
	legacy.free()

static func _test_geometry_and_rules(failures: Array[String]) -> void:
	var grid: Grid = _fixture()
	var revision: int = grid.revision
	var heights := grid._vertex_heights.duplicate()
	var terrain := grid._base_terrain.duplicate()
	var legacy := _renderer(grid, false)
	var painted := _renderer(grid)
	_expect(painted.painted_available() and painted.painted_mode_active(), "Gameplay V1 must actually be active, not just requested", failures)
	_expect(painted.map_bounds() == legacy.map_bounds(), "V1 must retain exact camera bounds", failures)
	for y: int in range(grid.size.y):
		for x: int in range(grid.size.x):
			var cell := Vector2i(x, y)
			_expect(painted.cell_polygon(cell) == legacy.cell_polygon(cell), "V1 must not change terrain geometry", failures)
			_expect(painted.pick_cell(painted.cell_center(cell)) == legacy.pick_cell(legacy.cell_center(cell)),
				"V1 must retain picking on raised terrain", failures)
			_expect(painted.buildability_guidance(cell) == legacy.buildability_guidance(cell),
				"V1 must retain slope/construction guidance", failures)
	for id: String in ["water", "rock"]:
		var cell := Vector2i(5, 4) if id == "water" else Vector2i(6, 4)
		var first: Dictionary = painted._cells[cell]["base_draws"][0]
		_expect(first["texture"] == painted._painted_compositor.atlas,
			"Production ground must use the whole V1 atlas through its compositor", failures)
		var data = painted._painted_compositor.data
		var core := Vector2i((Vector2(cell) + Vector2(0.5, 0.5)) * data.weight_scale)
		var low: Color = data.low.get_pixelv(core)
		var high: Color = data.high.get_pixelv(core)
		_expect(low.is_equal_approx(Color(0, 0, 0, 0)) and high.is_equal_approx(Color(0, 1, 0, 0)) if id == "water"
			else low.is_equal_approx(Color(0, 0, 1, 0)) and high.is_equal_approx(Color(0, 0, 0, 0)),
			"Isolated water/rock must retain a pure center after continuous material blending", failures)
		_expect(first["colors"][0].a == 1.0, "Impassable single-cell terrain may not disappear through blending", failures)
	_expect(grid.revision == revision and grid._vertex_heights == heights and grid._base_terrain == terrain,
		"Loading/drawing V1 must not mutate simulation state", failures)
	legacy.free()
	painted.free()

static func _test_world_uvs(failures: Array[String]) -> void:
	var renderer := _renderer(_fixture())
	var checked: int = 0
	for cell: Vector2i in renderer._cells:
		for command: Dictionary in renderer._cells[cell]["base_draws"]:
			var texture: Texture2D = command["texture"]
			_expect(texture == renderer._painted_compositor.atlas,
				"Every V1 ground command must sample the complete authored atlas", failures)
			for index: int in range(command["uvs"].size()):
				var world: Vector2 = Vector2(cell) + command["uvs"][index]
				var uv: Vector2 = command["texture_uvs"][index]
				_expect(uv.is_equal_approx(GroundCompositor.ground_uv(world)),
					"Ground geometry must submit continuous world coordinates to the shared V1 shader", failures)
				_expect(uv.x >= GroundCompositor.UV_TAG and uv.y >= GroundCompositor.UV_TAG,
					"Only V1 ground coordinates carry the compositor tag", failures)
				checked += 1
		for command: Dictionary in renderer._cells[cell]["surface_draws"]:
			for index: int in range(command["uvs"].size()):
				var world: Vector2 = Vector2(cell) + command["uvs"][index]
				var uv: Vector2 = command["texture_uvs"][index]
				_expect(uv.is_equal_approx(world / Renderer.ROAD_TEXTURE_SPAN) and uv.x < GroundCompositor.UV_TAG,
					"Roads, trails and wear must keep their untagged original UV sampling", failures)
	_expect(checked > 200, "World-UV test must inspect real submitted geometry", failures)
	renderer.free()

static func _surface_snapshot(renderer: Renderer) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in renderer._cells:
		var commands: Array = []
		for draw: Dictionary in renderer._cells[cell]["surface_draws"]:
			commands.append([draw["points"], draw["colors"], draw["uvs"], draw["texture_uvs"],
				draw["layer"], renderer._textures.find_key(draw["texture"])])
		result[cell] = commands
	return result

static func _test_surface_preservation(failures: Array[String]) -> void:
	var grid: Grid = _fixture()
	var legacy := _renderer(grid, false)
	var painted := _renderer(grid)
	_expect(_surface_snapshot(painted) == _surface_snapshot(legacy),
		"V1 must preserve every road/trail/wear/shoulder vertex, UV, tint and texture role", failures)
	var road: Texture2D = painted._textures[Grid.OVERLAY_STONE_ROAD]
	_expect(road.resource_path.ends_with("stone-road-basic-v1.png"),
		"Authored cobblestones must not be replaced by terrain material", failures)
	var builds: int = painted.base_cell_build_count
	var surface: int = painted.surface_cell_build_count
	var meshes: Dictionary = _mesh_ids(painted)
	var uploads: int = painted._painted_compositor.data.update_count
	for frame: int in range(12):
		painted.position += Vector2(3, -2)
		painted.scale *= 1.01
		painted._process(0.016)
	_expect(painted.base_cell_build_count == builds and painted.surface_cell_build_count == surface and _mesh_ids(painted) == meshes,
		"Camera-only changes must retain all V1 meshes", failures)
	_expect(painted._painted_compositor.data.update_count == uploads,
		"Camera-only changes must not refresh V1 weight/light data", failures)
	legacy.free()
	painted.free()

static func _mesh_ids(renderer: Renderer) -> Dictionary:
	var result: Dictionary = {}
	for row: int in renderer._row_batches:
		var ids: Array = []
		for batch: Dictionary in renderer._row_batches[row]["base"]:
			ids.append(batch["mesh"].get_instance_id())
		result[row] = ids
	return result

static func _snapshot(renderer: Renderer) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in renderer._cells:
		var commands: Array = []
		for draw: Dictionary in renderer._cells[cell]["draws"]:
			var kind: Variant = "v1_atlas" if renderer.painted_mode_active() and draw["texture"] == renderer._painted_compositor.atlas else null
			if kind == null:
				kind = renderer._textures.find_key(draw["texture"])
			commands.append([draw["points"],draw["colors"],draw["uvs"],draw["texture_uvs"],draw["layer"],kind])
		result[cell] = commands
	return result

static func _expect_fresh(renderer: Renderer, failures: Array[String]) -> void:
	renderer.map_bounds()
	var fresh := _renderer(renderer.grid)
	_expect(_snapshot(renderer) == _snapshot(fresh), "Incremental V1 cache must match a full fresh build", failures)
	_expect(renderer.map_bounds() == fresh.map_bounds(), "V1 incremental bounds must match a fresh build", failures)
	for field: String in ["low", "high", "light"]:
		var incremental: Image = renderer._painted_compositor.data.get(field)
		var rebuilt: Image = fresh._painted_compositor.data.get(field)
		_expect(incremental.get_data() == rebuilt.get_data(),
			"Incremental V1 %s data must match a complete fresh rebuild" % field, failures)
	fresh.free()

static func _test_incremental_terrain(failures: Array[String]) -> void:
	var grid: Grid = _fixture()
	var renderer := _renderer(grid)
	var builds: int = renderer.base_cell_build_count
	grid.set_base_terrain(Vector2i(6,6), "water")
	_expect_fresh(renderer, failures)
	_expect(renderer.base_cell_build_count - builds <= 9, "A single material edit must refresh at most nine base cells in V1", failures)
	grid.set_base_terrain(Vector2i(6,6), "grass")
	_expect_fresh(renderer, failures)
	renderer.free()

static func _test_incremental_surface(failures: Array[String]) -> void:
	var grid: Grid = _fixture()
	var renderer := _renderer(grid)
	var builds: int = renderer.base_cell_build_count
	var surface: int = renderer.surface_cell_build_count
	var ids: Dictionary = _mesh_ids(renderer)
	var uploads: int = renderer._painted_compositor.data.update_count
	grid.record_carrier_traffic(Vector2i(8,6))
	_expect_fresh(renderer, failures)
	_expect(renderer.base_cell_build_count == builds and _mesh_ids(renderer) == ids,
		"Foot traffic must not regenerate any V1 base mesh", failures)
	_expect(renderer._painted_compositor.data.update_count == uploads,
		"Foot traffic must not update V1 ground weight/light textures", failures)
	_expect(renderer.surface_cell_build_count - surface <= 9,
		"Foot traffic must keep bounded surface invalidation under V1", failures)
	renderer.free()

static func _test_height_and_rebind(failures: Array[String]) -> void:
	var renderer := _renderer(_fixture())
	var builds: int = renderer.base_cell_build_count
	renderer.grid.set_vertex_height(Vector2i(5,5), 4)
	_expect_fresh(renderer, failures)
	_expect(renderer.base_cell_build_count - builds <= 16, "Earthwork height changes must remain local under V1", failures)
	renderer.bind_grid(Grid.new(Vector2i(3,2)))
	_expect(renderer._cells.size() == 6 and renderer.painted_mode_active(), "Loaded/rebound maps must retain V1 without stale cells", failures)
	var polygon: PackedVector2Array = renderer.cell_polygon(Vector2i(1,1))
	renderer.use_painted_terrain = false
	renderer.map_bounds()
	_expect(not renderer.painted_mode_active() and renderer.cell_polygon(Vector2i(1,1)) == polygon,
		"Disabling V1 must restore legacy visuals without changing map geometry", failures)
	renderer.use_painted_terrain = true
	renderer.map_bounds()
	_expect(renderer.painted_mode_active(), "Reenabling V1 must invalidate old texture commands", failures)
	renderer.bind_grid(null)
	_expect(not renderer.painted_mode_active() and renderer.material == null,
		"Unbinding a map must clear the compositor and its stale shader material", failures)
	renderer.free()

static func _test_definition_tint(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3,3))
	var renderer := _renderer(grid)
	var before: Color = renderer._cells[Vector2i.ONE]["base_draws"][0]["colors"][0]
	grid.configure_movement({"terrain":{"grass":{"color":"a03050"}}})
	_expect_fresh(renderer, failures)
	var after: Color = renderer._cells[Vector2i.ONE]["base_draws"][0]["colors"][0]
	_expect(after != before and after.r > before.r and after.g < before.g,
		"Custom terrain palette must visibly tint V1 while preserving its texture detail", failures)
	renderer.free()

static func _test_saved_world(failures: Array[String]) -> void:
	var source := Legacy.create(Vector2i(10,8))
	source.grid.set_base_terrain(Vector2i(6,5), "water")
	source.grid.set_vertex_height(Vector2i(1,1),2)
	var serialized: Dictionary = source.to_data()
	var loaded := Legacy.create()
	_expect(loaded.from_data(JSON.parse_string(JSON.stringify(serialized))), "Existing save format must load without a V1 migration", failures)
	var before: Dictionary = loaded.to_data()
	var renderer := _renderer(loaded.grid)
	_expect(renderer.painted_mode_active() and before == loaded.to_data(), "Old saved worlds must render V1 without altering save data", failures)
	renderer.free()

static func _test_shared_compositor(failures: Array[String]) -> void:
	_expect(GroundCompositor.SHADER.contains(SharedShader.FUNCTIONS)
		and SampleRenderer.MODERN_SHADER.contains(SharedShader.FUNCTIONS),
		"Production and approved sandbox must compile the same material blending and light-gradient functions", failures)
	_expect(GroundCompositor.SHADER.contains("varying float terrain_light")
		and GroundCompositor.SHADER.contains("texture(vertex_light")
		and GroundCompositor.SHADER.contains("light_gradient(terrain_light)"),
		"V1 must interpolate shared corner light before its nonlinear per-fragment light ramp", failures)
	_expect(GroundCompositor.SHADER.contains("texture(TEXTURE, UV) * vertex_tint"),
		"Untagged road and placement-guide draws must retain ordinary CanvasItem sampling", failures)

static func _test_smooth_lighting_and_painter(failures: Array[String]) -> void:
	var grid: Grid = _fixture()
	var renderer := _renderer(grid)
	var legacy := _renderer(grid, false)
	var legacy_contours: int = 0
	for cell: Vector2i in renderer._cells:
		for command: Dictionary in renderer._cells[cell]["base_draws"]:
			_expect(command["layer"] == "terrain" and command["colors"][0].is_equal_approx(Color.WHITE),
				"Default V1 ground must not retain random cell tints, flat triangle shading or overpainted contour bands", failures)
		for command: Dictionary in legacy._cells[cell]["base_draws"]:
			if String(command["layer"]).begins_with("slope_contour"):
				legacy_contours += 1
	_expect(legacy_contours > 0, "Smooth-light fixture must actually exercise the legacy contour path", failures)
	var light: Image = renderer._painted_compositor.data.light
	_expect(is_equal_approx(light.get_pixel(2, 2).r, 4.0 / (0.15 * 44.0))
		and is_equal_approx(light.get_pixel(3, 2).r, -2.0 / (0.15 * 44.0)),
		"V1 vertex lighting must use the same signed directional height stencil as the sandbox", failures)
	_expect(renderer.material == renderer._painted_compositor.shader_material,
		"Standalone gameplay terrain must own its V1 shader material", failures)
	renderer.external_painter = true
	_expect(renderer._row_canvases.size() == grid.size.y,
		"V1 must retain one terrain canvas per painter row", failures)
	for row: int in renderer._row_canvases:
		var canvas: Node2D = renderer._row_canvases[row]
		_expect(canvas.material == renderer._painted_compositor.shader_material and canvas.z_index == row * 2,
			"All retained rows must use the V1 compositor without changing object/terrain depth order", failures)
	renderer.use_painted_terrain = false
	for canvas: Node2D in renderer._row_canvases.values():
		_expect(canvas.material == null, "Switching back to legacy must clear every retained row shader", failures)
	renderer.use_painted_terrain = true
	for canvas: Node2D in renderer._row_canvases.values():
		_expect(canvas.material == renderer._painted_compositor.shader_material,
			"Reenabling V1 must refresh existing row shader materials", failures)
	renderer.free()
	legacy.free()

static func _expect(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)
