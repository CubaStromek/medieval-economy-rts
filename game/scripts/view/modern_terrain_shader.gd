class_name ModernTerrainShader
extends RefCounted

# One shared material/lighting formula for the approved sandbox and gameplay.
# Vertex projection deliberately remains owned by the respective renderer.
const FUNCTIONS: String = """
float light_gradient(float coordinate) {
    float index = min(255.0, floor(clamp(coordinate, 0.0, 1.0) * 256.0));
    float value = max(0.0, index * 1.0625 - 16.0);
    float rounded = floor(value + 0.5);
    if (fract(value) == 0.5) {
        rounded = 2.0 * floor(value * 0.5 + 0.5);
    }
    return clamp(rounded / 255.0, 0.0, 1.0);
}

float hash_point(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash_point(cell), hash_point(cell + vec2(1.0, 0.0)), f.x),
        mix(hash_point(cell + vec2(0.0, 1.0)), hash_point(cell + vec2(1.0)), f.x), f.y);
}

vec4 sample_material(float index, vec2 world_grid) {
    // Mirroring makes every repeated edge continuous without copying, editing,
    // or sampling any reference bitmap. Swatches span four ground cells.
    vec2 repeated = 1.0 - abs(mod(world_grid / 4.0, vec2(2.0)) - 1.0);
    vec2 cell = vec2(mod(index, 4.0), floor(index / 4.0));
    vec2 cell_size = vec2(0.25, 0.5);
    // The authored 1774 x 887 atlas has half-pixel cell boundaries; normalized
    // addressing with a two-pixel inset avoids neighbouring swatch bleed.
    vec2 inset = vec2(2.0) / atlas_pixels;
    vec2 coordinate = cell * cell_size + inset + repeated * (cell_size - inset * 2.0);
    return linear_filter ? texture(material_atlas_linear, coordinate) : texture(material_atlas_nearest, coordinate);
}

vec4 modern_texel() {
    vec2 weight_uv = (terrain_grid * weight_scale + vec2(0.5)) / weight_dimensions;
    vec4 low = texture(weights_low, weight_uv);
    vec4 high = texture(weights_high, weight_uv);
    vec2 world_grid = terrain_grid + source_origin;
    // Continuous world-space modulation, shared by both cells at every edge.
    // Multiplication keeps absent kinds absent and pure-kind interiors pure.
    float noise_a = smooth_noise(world_grid * 2.1);
    float noise_b = smooth_noise(world_grid * 6.3 + vec2(17.0, 5.0));
    float n = (noise_a - 0.5) * 0.65 + (noise_b - 0.5) * 0.22;
    low *= max(vec4(0.1), vec4(1.0) + n * vec4(1.0, -0.7, -1.0, 0.6));
    high *= max(vec4(0.1), vec4(1.0) + n * vec4(0.4, -0.8, 0.8, -0.4));
    low = pow(max(low, vec4(0.0)), vec4(3.5));
    high = pow(max(high, vec4(0.0)), vec4(3.5));
    float total = max(dot(low, vec4(1.0)) + dot(high, vec4(1.0)), 0.000001);
    low /= total;
    high /= total;
    return sample_material(0.0, world_grid) * low.r
        + sample_material(1.0, world_grid) * low.g
        + sample_material(2.0, world_grid) * low.b
        + sample_material(3.0, world_grid) * low.a
        + sample_material(4.0, world_grid) * high.r
        + sample_material(5.0, world_grid) * high.g
        + sample_material(6.0, world_grid) * high.b
        + sample_material(7.0, world_grid) * high.a;
}

"""
