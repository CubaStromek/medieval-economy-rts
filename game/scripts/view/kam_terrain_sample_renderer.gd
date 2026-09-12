class_name KamTerrainSampleRenderer
extends Node2D

# Isolated, static reference study. This does not change simulation heights,
# materials, passability, saves, or the production terrain renderer.
const CELL_PIXELS: float = 40.0
const HEIGHT_DIVISOR: float = 33.333
const ATLAS_SIZE: int = 512
const TILE_PIXELS: int = 32
const MAX_SAMPLE_SIDE: int = 64
const MAX_TILE_ID: int = 237
const CORNERS := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
const TRIANGLES := [0, 1, 2, 0, 2, 3]
const SharedModernShader = preload("res://scripts/view/modern_terrain_shader.gd")
const ModernMaterials = preload("res://scripts/view/modern_terrain_materials.gd")
const DEFAULT_VISUAL_OPTIONS := {"textures": true, "lighting": true,
	"light_strength": 1.0, "relief_scale": 1.0, "linear_filter": false, "texture_pack": "classic"}

# ArrayMesh stores COLOR as UNORM8. Instead of rounding signed light to eight
# bits, R/G carry the exact integer stencil (2*h - west - south) + 510 and B
# carries Water, and A carries the exact raw height for visual-only relief.
# The vertex shader reconstructs the original floating light,
# which is interpolated BEFORE the nonlinear lookup in the fragment shader.
# The lookup uses nearest sampling and ties-to-even, the normal Pascal Round
# mode; a changed source FPU rounding mode could differ by 1/255 at half ties.
const LIGHT_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;
varying float terrain_light;
uniform bool use_textures = true;
uniform bool use_lighting = true;
uniform float light_strength = 1.0;
uniform float relief_scale = 1.0;

void vertex() {
    float raw_height = round(COLOR.a * 255.0);
    VERTEX.y += raw_height * 40.0 / 33.333 * (1.0 - relief_scale);
    float stencil = round(COLOR.r * 255.0) * 256.0 + round(COLOR.g * 255.0) - 510.0;
    terrain_light = clamp(stencil * relief_scale / 44.0, -1.0, 1.0);
    if (COLOR.b > 0.5) {
        terrain_light = clamp(terrain_light * 1.3 + 0.1, -1.0, 1.0);
    }
    terrain_light *= use_lighting ? light_strength : 0.0;
}

float light_gradient(float coordinate) {
    float index = min(255.0, floor(clamp(coordinate, 0.0, 1.0) * 256.0));
    float value = max(0.0, index * 1.0625 - 16.0);
    float rounded = floor(value + 0.5);
    if (fract(value) == 0.5) {
        rounded = 2.0 * floor(value * 0.5 + 0.5);
    }
    return clamp(rounded / 255.0, 0.0, 1.0);
}

void fragment() {
    vec4 texel = use_textures ? texture(TEXTURE, UV) : vec4(0.62, 0.64, 0.60, 1.0);
    float highlight = light_gradient(terrain_light);
    float shadow = light_gradient(-terrain_light);
    COLOR = vec4(clamp(texel.rgb * (1.0 + highlight), vec3(0.0), vec3(1.0)) * (1.0 - shadow), texel.a);
}
"""

# Our own continuous material compositor; reference lighting remains identical.
const MODERN_SHADER: String = """
shader_type canvas_item;
render_mode unshaded;
varying float terrain_light;
varying vec2 terrain_grid;
uniform sampler2D material_atlas_nearest : source_color, filter_nearest, repeat_disable;
uniform sampler2D material_atlas_linear : source_color, filter_linear, repeat_disable;
uniform sampler2D weights_low : filter_linear, repeat_disable;
uniform sampler2D weights_high : filter_linear, repeat_disable;
uniform vec2 atlas_pixels = vec2(1774.0, 887.0);
uniform vec2 weight_dimensions = vec2(23.0, 19.0);
uniform float weight_scale = 1.0;
uniform vec2 source_origin = vec2(0.0);
uniform bool linear_filter = false;
uniform bool use_textures = true;
uniform bool use_lighting = true;
uniform float light_strength = 1.0;
uniform float relief_scale = 1.0;

void vertex() {
    float raw_height = round(COLOR.a * 255.0);
    // Recover the original grid before visual-only height displacement.
    terrain_grid = vec2(VERTEX.x, VERTEX.y + raw_height * 40.0 / 33.333) / 40.0;
    VERTEX.y += raw_height * 40.0 / 33.333 * (1.0 - relief_scale);
    float stencil = round(COLOR.r * 255.0) * 256.0 + round(COLOR.g * 255.0) - 510.0;
    terrain_light = clamp(stencil * relief_scale / 44.0, -1.0, 1.0);
    if (COLOR.b > 0.5) {
        terrain_light = clamp(terrain_light * 1.3 + 0.1, -1.0, 1.0);
    }
    terrain_light *= use_lighting ? light_strength : 0.0;
}

""" + SharedModernShader.FUNCTIONS + """

void fragment() {
    vec4 texel = use_textures ? modern_texel() : vec4(0.62, 0.64, 0.60, 1.0);
    float highlight = light_gradient(terrain_light);
    float shadow = light_gradient(-terrain_light);
    COLOR = vec4(clamp(texel.rgb * (1.0 + highlight), vec3(0.0), vec3(1.0)) * (1.0 - shadow), texel.a);
}
"""

var last_error: String = ""
var sample_name: String = ""
var sample_size := Vector2i.ZERO
var geometry_build_count: int = 0
var _bounds := Rect2()
var _batches: Array[Dictionary] = []
var _textures: Dictionary = {}
var _height_halo: Array = []
var _visual_options: Dictionary = DEFAULT_VISUAL_OPTIONS.duplicate()
var _classic_material: ShaderMaterial
var _modern_material: ShaderMaterial
var _configured_patch: Dictionary = {}
var modern_material_build_count: int = 0


func configure(patch: Dictionary, atlas: Image) -> bool:
	last_error = _validate(patch, atlas)
	if not last_error.is_empty():
		return false
	var size := Vector2i(int(patch["size"][0]), int(patch["size"][1]))
	var heights: Array = patch["height_halo"]
	var water: Array = patch["water_halo"]
	var tiles: Array = patch["tile_rows"]
	var textures: Dictionary = {}
	var batches: Array[Dictionary] = []
	var projected_bounds := Rect2(project_vertex(Vector2i.ZERO, float(heights[1][1])), Vector2.ZERO)
	for y: int in range(size.y + 1):
		for x: int in range(size.x + 1):
			projected_bounds = projected_bounds.expand(project_vertex(Vector2i(x, y), float(heights[y + 1][x + 1])))
	for y: int in range(size.y):
		for x: int in range(size.x):
			var tile_id: int = int(tiles[y][x][0])
			var rotation: int = int(tiles[y][x][1])
			if not textures.has(tile_id):
				var tile_rect := Rect2i(Vector2i(tile_id % 16, tile_id / 16) * TILE_PIXELS, Vector2i(TILE_PIXELS, TILE_PIXELS))
				# Separate clamped textures avoid adjacent atlas pixels bleeding into
				# each tile. Original bitmap data stays in RAM, never exported here.
				textures[tile_id] = ImageTexture.create_from_image(atlas.get_region(tile_rect))
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			var uvs := PackedVector2Array()
			for index: int in TRIANGLES:
				var corner: Vector2 = CORNERS[index]
				var vertex := Vector2i(x, y) + Vector2i(corner)
				points.append(project_vertex(vertex, float(heights[vertex.y + 1][vertex.x + 1])))
				colors.append(_encoded_vertex_light(heights, water, vertex.x, vertex.y))
				uvs.append(rotate_uv(corner, rotation))
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
			# Row-major order is intentional: a raised foreground ridge can cover
			# the preceding row. Do not globally regroup these by texture ID.
			batches.append({"mesh": mesh, "texture": textures[tile_id], "tile_id": tile_id})
	var shader := Shader.new()
	shader.code = LIGHT_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	_classic_material = shader_material
	_modern_material = null
	_configured_patch = patch.duplicate(true)
	_visual_options["texture_pack"] = "classic"
	material = _classic_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_textures = textures
	_batches = batches
	_bounds = projected_bounds
	_height_halo = heights.duplicate(true)
	sample_name = patch["name"]
	sample_size = size
	geometry_build_count += 1
	_apply_visual_options()
	queue_redraw()
	return true


func bounds() -> Rect2:
	return _bounds


# Configure once after the classic geometry. All material and weight textures
# are retained; changing the selected pack only swaps ShaderMaterial resources.
# Unsupported data never discards a previously configured, valid modern pack.
func configure_modern_materials(patch: Dictionary, atlas: Image) -> bool:
	if _configured_patch.is_empty() or patch != _configured_patch:
		last_error = "Modern textures must use the same patch as the configured reference geometry."
		return false
	if atlas == null or atlas.is_empty() or atlas.get_width() < 256 or atlas.get_height() < 128 or absf(float(atlas.get_width()) / float(atlas.get_height()) - 2.0) > 0.02:
		last_error = "Modern terrain requires a 4 x 2 material atlas with an approximately 2:1 aspect ratio."
		return false
	var result: Dictionary = ModernMaterials.build_weights(patch)
	last_error = String(result["error"])
	if not last_error.is_empty():
		return false
	var shader := Shader.new()
	shader.code = MODERN_SHADER
	var prepared := ShaderMaterial.new()
	prepared.shader = shader
	# The Compatibility renderer can share GL sampler state for the same RID.
	# Separate cached resources let nearest/linear hints remain independent.
	prepared.set_shader_parameter("material_atlas_nearest", ImageTexture.create_from_image(atlas))
	prepared.set_shader_parameter("material_atlas_linear", ImageTexture.create_from_image(atlas))
	prepared.set_shader_parameter("atlas_pixels", Vector2(atlas.get_size()))
	prepared.set_shader_parameter("weights_low", ImageTexture.create_from_image(result["low"] as Image))
	prepared.set_shader_parameter("weights_high", ImageTexture.create_from_image(result["high"] as Image))
	prepared.set_shader_parameter("weight_dimensions", Vector2(sample_size + Vector2i.ONE))
	prepared.set_shader_parameter("source_origin", Vector2(float(patch["origin"][0]), float(patch["origin"][1])))
	_modern_material = prepared
	modern_material_build_count += 1
	_apply_visual_options()
	return true


func modern_available() -> bool:
	return _modern_material != null



# Partial visual-only updates. Invalid types and nonfinite values are ignored.
# Relief scales both geometry and the slope-light stencil; the source water
# brightness bias is retained. The default settings reproduce the reference.
func set_visual_options(options: Dictionary) -> void:
	if options.get("texture_pack") is String and options["texture_pack"] in ["classic", "modern"]:
		if options["texture_pack"] == "classic" or modern_available():
			_visual_options["texture_pack"] = options["texture_pack"]
	for key: String in ["textures", "lighting", "linear_filter"]:
		if options.get(key) is bool:
			_visual_options[key] = options[key]
	for key: String in ["light_strength", "relief_scale"]:
		var value: Variant = options.get(key)
		if (value is int or value is float) and is_finite(float(value)):
			_visual_options[key] = clampf(float(value), 0.0, 1.5)
	_apply_visual_options()


func visual_options() -> Dictionary:
	return _visual_options.duplicate()


# Local projected position, exactly on the retained TL-BR triangle surface.
# The point is clamped to this patch; this also supports anchors on its edges.
func projected_point(grid_position: Vector2) -> Vector2:
	if _height_halo.is_empty() or not grid_position.is_finite():
		return Vector2.ZERO
	var point := grid_position.clamp(Vector2.ZERO, Vector2(sample_size))
	var cell := Vector2i(mini(floori(point.x), sample_size.x - 1), mini(floori(point.y), sample_size.y - 1))
	var fraction: Vector2 = point - Vector2(cell)
	var tl: float = float(_height_halo[cell.y + 1][cell.x + 1])
	var tr: float = float(_height_halo[cell.y + 1][cell.x + 2])
	var br: float = float(_height_halo[cell.y + 2][cell.x + 2])
	var bl: float = float(_height_halo[cell.y + 2][cell.x + 1])
	var height: float
	if fraction.x >= fraction.y:
		height = tl * (1.0 - fraction.x) + tr * (fraction.x - fraction.y) + br * fraction.y
	else:
		height = tl * (1.0 - fraction.y) + br * fraction.x + bl * (fraction.y - fraction.x)
	return point * CELL_PIXELS - Vector2(0.0, height * CELL_PIXELS / HEIGHT_DIVISOR * float(_visual_options["relief_scale"]))


func _apply_visual_options() -> void:
	material = _modern_material if _visual_options["texture_pack"] == "modern" and modern_available() else _classic_material
	for shader_material: ShaderMaterial in [_classic_material, _modern_material]:
		if shader_material == null:
			continue
		shader_material.set_shader_parameter("use_textures", _visual_options["textures"])
		shader_material.set_shader_parameter("use_lighting", _visual_options["lighting"])
		shader_material.set_shader_parameter("light_strength", _visual_options["light_strength"])
		shader_material.set_shader_parameter("relief_scale", _visual_options["relief_scale"])
	if _modern_material != null:
		_modern_material.set_shader_parameter("linear_filter", _visual_options["linear_filter"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if bool(_visual_options["linear_filter"]) else CanvasItem.TEXTURE_FILTER_NEAREST
	if not _height_halo.is_empty():
		_bounds = Rect2(projected_point(Vector2.ZERO), Vector2.ZERO)
		for y: int in range(sample_size.y + 1):
			for x: int in range(sample_size.x + 1):
				_bounds = _bounds.expand(projected_point(Vector2(x, y)))
		# Shader displacement can leave the original mesh AABB. Keep CanvasItem
		# culling aligned with what is actually visible without rebuilding meshes.
		RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, _bounds)
	queue_redraw()


func tile_count() -> int:
	return _batches.size()


func texture_count() -> int:
	return _textures.size()


func _draw() -> void:
	for batch: Dictionary in _batches:
		draw_mesh(batch["mesh"] as ArrayMesh, batch["texture"] as Texture2D)


static func project_vertex(vertex: Vector2i, raw_height: float) -> Vector2:
	return Vector2(vertex) * CELL_PIXELS - Vector2(0.0, raw_height * CELL_PIXELS / HEIGHT_DIVISOR)


static func rotate_uv(uv: Vector2, rotation: int) -> Vector2:
	match posmod(rotation, 4):
		1: return Vector2(uv.y, 1.0 - uv.x)
		2: return Vector2(1.0 - uv.x, 1.0 - uv.y)
		3: return Vector2(1.0 - uv.y, uv.x)
	return uv


# x/y are patch-local VERTEX coordinates, including the last row/column.
# The one-cell halo is real source data, not a fabricated black crop border.
static func vertex_light(height_halo: Array, water_halo: Array, x: int, y: int) -> float:
	var stencil: int = 2 * int(height_halo[y + 1][x + 1]) - int(height_halo[y + 1][x]) - int(height_halo[y + 2][x + 1])
	var light: float = clampf(float(stencil) / 44.0, -1.0, 1.0)
	return clampf(light * 1.3 + 0.1, -1.0, 1.0) if bool(water_halo[y + 1][x + 1]) else light


static func gradient_value(coordinate: float) -> float:
	var index: int = mini(255, floori(clampf(coordinate, 0.0, 1.0) * 256.0))
	var value: float = maxf(0.0, float(index) * 1.0625 - 16.0)
	var rounded: float = floorf(value + 0.5)
	if value - floorf(value) == 0.5:
		rounded = 2.0 * floorf(value * 0.5 + 0.5)
	return clampf(rounded / 255.0, 0.0, 1.0)


static func light_multiplier(light: float) -> float:
	return (1.0 + gradient_value(light)) * (1.0 - gradient_value(-light))


static func _encoded_vertex_light(heights: Array, water: Array, x: int, y: int) -> Color:
	var stencil: int = 2 * int(heights[y + 1][x + 1]) - int(heights[y + 1][x]) - int(heights[y + 2][x + 1])
	var encoded: int = stencil + 510
	return Color(float(encoded / 256) / 255.0, float(encoded % 256) / 255.0, 1.0 if bool(water[y + 1][x + 1]) else 0.0, float(heights[y + 1][x + 1]) / 255.0)


static func _validate(patch: Dictionary, atlas: Image) -> String:
	if atlas == null or atlas.is_empty() or atlas.get_size() != Vector2i(ATLAS_SIZE, ATLAS_SIZE):
		return "Terrain study requires the external 512 x 512 reference tilesheet."
	if not patch.get("name") is String or String(patch["name"]).strip_edges().is_empty():
		return "Terrain patch name is missing."
	var dimensions: Variant = patch.get("size")
	if not dimensions is Array or dimensions.size() != 2:
		return "Terrain patch size must contain two cell dimensions."
	if not _whole(dimensions[0], 1, MAX_SAMPLE_SIDE) or not _whole(dimensions[1], 1, MAX_SAMPLE_SIDE):
		return "Terrain patch dimensions must be integers in 1..64."
	var origin: Variant = patch.get("origin")
	if not origin is Array or origin.size() != 2 or not _whole(origin[0], 1, 255) or not _whole(origin[1], 1, 255):
		return "Terrain patch must identify an interior source origin."
	var width: int = int(dimensions[0])
	var height: int = int(dimensions[1])
	var heights: Variant = patch.get("height_halo")
	var water: Variant = patch.get("water_halo")
	if not heights is Array or heights.size() != height + 3 or not water is Array or water.size() != height + 3:
		return "Terrain patch must include a complete source height and water halo."
	for y: int in range(height + 3):
		if not heights[y] is Array or heights[y].size() != width + 3 or not water[y] is Array or water[y].size() != width + 3:
			return "Terrain patch halo rows have inconsistent widths."
		for x: int in range(width + 3):
			if not _whole(heights[y][x], 0, 255) or not water[y][x] is bool:
				return "Terrain patch halo contains an invalid raw height or water flag."
	var tiles: Variant = patch.get("tile_rows")
	var prototype: Variant = patch.get("prototype_terrain")
	if not tiles is Array or tiles.size() != height or not prototype is Array or prototype.size() != height:
		return "Terrain patch tile rows are missing."
	for y: int in range(height):
		if not tiles[y] is Array or tiles[y].size() != width or not prototype[y] is String or prototype[y].length() != width:
			return "Terrain patch tile rows have inconsistent widths."
		for x: int in range(width):
			var tile: Variant = tiles[y][x]
			if not tile is Array or tile.size() != 2 or not _whole(tile[0], 0, MAX_TILE_ID) or not _whole(tile[1], 0, 3):
				return "Terrain patch tile ID or rotation is unsupported by this static tilesheet."
			if not prototype[y][x] in ["g", "d", "w", "r"]:
				return "Terrain patch prototype material is invalid."
	return ""


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
