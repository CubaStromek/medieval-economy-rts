class_name PaintedTerrainLibrary
extends RefCounted

# Reuse our authored V1 atlas without rewriting it or requiring original game
# data. Each material is extracted once per atlas and shared by every renderer.
const ATLAS_PATH: String = "res://art/terrain/modern-materials-v1.png"
const MATERIAL_SLOTS: Dictionary = {"grass": 0, "dirt": 3, "water": 5, "rock": 2}
const ATLAS_COLUMNS: int = 4
const ATLAS_ROWS: int = 2
const ATLAS_INSET_PIXELS: int = 2
const TEXTURE_SPAN: float = 4.0
# Keep sampling inside extracted edge texels. This also leaves a small guard
# for linear minification while road canvases retain their repeat setting.
const UV_GUARD_PIXELS: float = 4.5

static var _atlases: Dictionary = {}


static func textures(atlas_path: String = ATLAS_PATH) -> Dictionary:
	if _atlases.has(atlas_path):
		return (_atlases[atlas_path] as Dictionary).duplicate()
	if not ResourceLoader.exists(atlas_path):
		return {}
	var resource: Texture2D = load(atlas_path) as Texture2D
	if resource == null:
		return {}
	var atlas: Image = resource.get_image()
	if atlas == null or atlas.is_empty():
		return {}
	if atlas.is_compressed() and atlas.decompress() != OK:
		return {}
	if atlas.get_width() < ATLAS_COLUMNS * 16 or atlas.get_height() < ATLAS_ROWS * 16:
		return {}
	var result: Dictionary = {}
	for terrain_id: String in MATERIAL_SLOTS:
		var slot: int = int(MATERIAL_SLOTS[terrain_id])
		var column: int = slot % ATLAS_COLUMNS
		var row: int = slot / ATLAS_COLUMNS
		# The authored atlas is 1774 × 887: do not assume integer cell sizes.
		# Inward rounding + inset excludes every neighboring swatch's pixels.
		var left: int = ceili(float(column) * atlas.get_width() / ATLAS_COLUMNS) + ATLAS_INSET_PIXELS
		var top: int = ceili(float(row) * atlas.get_height() / ATLAS_ROWS) + ATLAS_INSET_PIXELS
		var right: int = floori(float(column + 1) * atlas.get_width() / ATLAS_COLUMNS) - ATLAS_INSET_PIXELS
		var bottom: int = floori(float(row + 1) * atlas.get_height() / ATLAS_ROWS) - ATLAS_INSET_PIXELS
		if right <= left or bottom <= top:
			return {}
		var swatch: Image = atlas.get_region(Rect2i(left, top, right - left, bottom - top))
		if swatch.is_empty() or swatch.generate_mipmaps() != OK:
			return {}
		result[terrain_id] = ImageTexture.create_from_image(swatch)
	if result.size() != MATERIAL_SLOTS.size():
		return {}
	_atlases[atlas_path] = result
	return result.duplicate()


static func available() -> bool:
	return textures().size() == MATERIAL_SLOTS.size()


# A triangle wave mirrors every four-cell swatch. Adjacent polygons receive
# the same UV at a shared world position; the direction reverses at integer
# cell boundaries, never inside one of the existing terrain triangles.
static func world_uv(world_position: Vector2, texture_size: Vector2i) -> Vector2:
	if texture_size.x <= 0 or texture_size.y <= 0:
		return Vector2.ZERO
	var wave := Vector2(
		1.0 - absf(fposmod(world_position.x / TEXTURE_SPAN, 2.0) - 1.0),
		1.0 - absf(fposmod(world_position.y / TEXTURE_SPAN, 2.0) - 1.0))
	var inset := Vector2(
		minf(UV_GUARD_PIXELS, float(texture_size.x - 1) * 0.5) / float(texture_size.x),
		minf(UV_GUARD_PIXELS, float(texture_size.y - 1) * 0.5) / float(texture_size.y))
	return inset + wave * (Vector2.ONE - inset * 2.0)
