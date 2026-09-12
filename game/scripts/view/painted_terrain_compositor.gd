class_name PaintedTerrainCompositor
extends RefCounted

const Data = preload("res://scripts/view/painted_terrain_data.gd")
const SharedShader = preload("res://scripts/view/modern_terrain_shader.gd")
const Library = preload("res://scripts/view/painted_terrain_library.gd")
const UV_TAG: float = 1024.0
const SHADER: String = """
shader_type canvas_item;
render_mode unshaded;
varying float terrain_light;
varying vec2 terrain_grid;
varying vec4 vertex_tint;
varying float is_ground;
uniform sampler2D material_atlas_nearest : source_color, filter_nearest, repeat_disable;
uniform sampler2D material_atlas_linear : source_color, filter_linear, repeat_disable;
uniform sampler2D weights_low : filter_linear, repeat_disable;
uniform sampler2D weights_high : filter_linear, repeat_disable;
uniform sampler2D vertex_light : filter_nearest, repeat_disable;
uniform vec2 atlas_pixels = vec2(1774.0, 887.0);
uniform vec2 weight_dimensions;
uniform vec2 light_dimensions;
uniform vec2 source_origin = vec2(0.0);
uniform float weight_scale = 1.0;
uniform bool linear_filter = false;

void vertex() {
    // Only ground meshes carry this tag. Roads and buildability guides retain
    // their original texture, tint and UVs even on the same retained row.
    is_ground = UV.x >= 1024.0 ? 1.0 : 0.0;
    terrain_grid = UV - vec2(1024.0);
    vertex_tint = COLOR;
    terrain_light = is_ground > 0.5
        ? texture(vertex_light, (terrain_grid + vec2(0.5)) / light_dimensions).r : 0.0;
}
""" + SharedShader.FUNCTIONS + """
void fragment() {
    if (is_ground > 0.5) {
        vec4 texel = modern_texel();
        float highlight = light_gradient(terrain_light);
        float shadow = light_gradient(-terrain_light);
        COLOR = vec4(clamp(texel.rgb * (1.0 + highlight), vec3(0.0), vec3(1.0))
            * (1.0 - shadow), texel.a) * vertex_tint;
    } else {
        COLOR = texture(TEXTURE, UV) * vertex_tint;
    }
}
"""

static var _atlas_nearest: Texture2D
static var _atlas_linear: Texture2D
static var _shader: Shader
var data: Data
var atlas: Texture2D
var shader_material: ShaderMaterial
var _low_texture: ImageTexture
var _high_texture: ImageTexture
var _light_texture: ImageTexture


static func ground_uv(world_position: Vector2) -> Vector2:
	return world_position + Vector2(UV_TAG, UV_TAG)


func configure(grid: RefCounted) -> bool:
	if not ResourceLoader.exists(Library.ATLAS_PATH):
		return false
	if _atlas_nearest == null:
		var authored: Texture2D = load(Library.ATLAS_PATH) as Texture2D
		if authored == null:
			return false
		var pixels: Image = authored.get_image()
		if pixels == null or pixels.is_empty():
			return false
		if pixels.is_compressed() and pixels.decompress() != OK:
			return false
		# Separate RIDs keep OpenGL's nearest and linear sampler state independent.
		_atlas_nearest = ImageTexture.create_from_image(pixels)
		_atlas_linear = ImageTexture.create_from_image(pixels)
	data = Data.new()
	if not data.configure(grid):
		return false
	atlas = _atlas_nearest
	_low_texture = ImageTexture.create_from_image(data.low)
	_high_texture = ImageTexture.create_from_image(data.high)
	_light_texture = ImageTexture.create_from_image(data.light)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	shader_material = ShaderMaterial.new()
	shader_material.shader = _shader
	shader_material.set_shader_parameter("material_atlas_nearest", _atlas_nearest)
	shader_material.set_shader_parameter("material_atlas_linear", _atlas_linear)
	shader_material.set_shader_parameter("atlas_pixels", Vector2(atlas.get_size()))
	shader_material.set_shader_parameter("weights_low", _low_texture)
	shader_material.set_shader_parameter("weights_high", _high_texture)
	shader_material.set_shader_parameter("vertex_light", _light_texture)
	shader_material.set_shader_parameter("weight_dimensions", data.weight_dimensions)
	shader_material.set_shader_parameter("light_dimensions", Vector2(data.light.get_size()))
	shader_material.set_shader_parameter("weight_scale", data.weight_scale)
	return true


func update_terrain(cells: Array[Vector2i]) -> void:
	if cells.is_empty() or data == null:
		return
	data.update_terrain(cells)
	_low_texture.update(data.low)
	_high_texture.update(data.high)
	_light_texture.update(data.light)
