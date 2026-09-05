class_name TreeSpriteLibrary
extends RefCounted

# Original painted atlas: columns oak / beech / spruce; rows sapling / young /
# mature. Species is presentation-only and derives from saved tree identity.
const ATLAS_PATH: String = "res://art/environment/trees-basic-v1.png"
const SPECIES_COUNT: int = 3
const STAGE_COUNT: int = 3
const SPECIES_NAMES: Array[String] = ["oak", "beech", "spruce"]
const STAGE_HEIGHTS: Array[float] = [18.0, 38.0, 68.0]
const STAGE_MAX_WIDTHS: Array[float] = [18.0, 35.0, 62.0]
const MATURE_SPRUCE_HEIGHT: float = 74.0
const ALPHA_THRESHOLD: float = 0.10

static var _textures: Dictionary = {}
static var _sizes: Dictionary = {}
static var _root_offsets: Dictionary = {}
static var _cell_regions: Dictionary = {}
static var _atlas_loaded: bool = false


func _init() -> void:
	_load_atlas()


static func species_for(tree: Dictionary) -> int:
	var cell: Vector2i = tree.get("position", Vector2i.ZERO) as Vector2i
	var entity_id: int = int(tree.get("id", 0))
	var stable_hash: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (entity_id * 83492791)
	return posmod(stable_hash, SPECIES_COUNT)


func has_sprite(species: int, stage: int) -> bool:
	return _textures.has(Vector2i(species, stage))


func atlas_cell_region(species: int, stage: int) -> Rect2i:
	return _cell_regions.get(Vector2i(species, stage), Rect2i()) as Rect2i


func texture_for(tree: Dictionary, stage: int) -> Texture2D:
	return _textures.get(_sprite_key(tree, stage)) as Texture2D


func sprite_size(tree: Dictionary, stage: int) -> Vector2:
	return _sizes.get(_sprite_key(tree, stage), Vector2.ZERO) as Vector2


func root_offset_for(tree: Dictionary, stage: int) -> Vector2:
	return _root_offsets.get(_sprite_key(tree, stage), Vector2.ZERO) as Vector2


func sprite_rect(tree: Dictionary, stage: int, feet: Vector2) -> Rect2:
	return Rect2(feet - root_offset_for(tree, stage), sprite_size(tree, stage))


func presentation_for(tree: Dictionary, stage: int, feet: Vector2, show_amount: bool = false) -> Dictionary:
	return {
		"texture": texture_for(tree, stage),
		"rect": sprite_rect(tree, stage, feet),
		"species": species_for(tree),
		"stage": clampi(stage, 0, STAGE_COUNT - 1),
		"amount_text": str(int(tree.get("amount", 0))) if show_amount else "",
	}


static func _sprite_key(tree: Dictionary, stage: int) -> Vector2i:
	return Vector2i(species_for(tree), clampi(stage, 0, STAGE_COUNT - 1))


static func _load_atlas() -> void:
	if _atlas_loaded or not ResourceLoader.exists(ATLAS_PATH):
		return
	var atlas: Texture2D = load(ATLAS_PATH) as Texture2D
	if atlas == null:
		return
	var source: Image = atlas.get_image()
	if source == null or source.is_empty():
		return
	if source.is_compressed():
		source.decompress()
	# Generous transparent gutters are part of the authored atlas. Adjust a
	# nominal seam slightly only when alpha coverage reveals a better gutter.
	var columns: Array[int] = [0]
	var rows: Array[int] = [0]
	for seam: int in range(1, 3):
		columns.append(_find_seam(source, roundi(source.get_width() * float(seam) / 3.0), true))
		rows.append(_find_seam(source, roundi(source.get_height() * float(seam) / 3.0), false))
	columns.append(source.get_width())
	rows.append(source.get_height())
	for stage: int in range(STAGE_COUNT):
		for species: int in range(SPECIES_COUNT):
			var key := Vector2i(species, stage)
			var region := Rect2i(columns[species], rows[stage], columns[species + 1] - columns[species], rows[stage + 1] - rows[stage])
			_cell_regions[key] = region
			var cell: Image = source.get_region(region)
			var visible: Rect2i = _visible_bounds(cell)
			if visible.size.x <= 0 or visible.size.y <= 0:
				push_warning("Tree atlas has an empty sprite: %s stage %d" % [SPECIES_NAMES[species], stage])
				continue
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(Vector2(region.position + visible.position), Vector2(visible.size))
			texture.filter_clip = true
			_textures[key] = texture
			var target_height: float = MATURE_SPRUCE_HEIGHT if species == 2 and stage == 2 else STAGE_HEIGHTS[stage]
			var scale_factor: float = minf(target_height / float(visible.size.y), STAGE_MAX_WIDTHS[stage] / float(visible.size.x))
			_sizes[key] = Vector2(visible.size) * scale_factor
			_root_offsets[key] = _root_position(cell, visible) * scale_factor
	_atlas_loaded = true


static func _find_seam(image: Image, nominal: int, vertical: bool) -> int:
	var extent: int = image.get_width() if vertical else image.get_height()
	var span: int = image.get_height() if vertical else image.get_width()
	var radius: int = maxi(2, roundi(float(extent) / (12.0 if vertical else 8.0)))
	var best: int = nominal
	var minimum_opaque: int = span + 1
	for location: int in range(maxi(1, nominal - radius), mini(extent - 1, nominal + radius) + 1):
		var opaque: int = 0
		for cross: int in range(span):
			var alpha: float = image.get_pixel(location, cross).a if vertical else image.get_pixel(cross, location).a
			if alpha >= ALPHA_THRESHOLD:
				opaque += 1
			if opaque > minimum_opaque:
				break
		if opaque < minimum_opaque or (opaque == minimum_opaque and absi(location - nominal) < absi(best - nominal)):
			minimum_opaque = opaque
			best = location
	return best


# The canopy can be asymmetric. Use the alpha-weighted bottom trunk band as
# the horizontal pivot, not the midpoint of the trimmed foliage bounds.
static func _root_position(image: Image, visible: Rect2i) -> Vector2:
	var band_height: int = maxi(2, ceili(float(visible.size.y) * 0.06))
	var first_row: int = maxi(visible.position.y, visible.end.y - band_height)
	var weighted_x: float = 0.0
	var weight: float = 0.0
	for y: int in range(first_row, visible.end.y):
		for x: int in range(visible.position.x, visible.end.x):
			var alpha: float = image.get_pixel(x, y).a
			if alpha >= ALPHA_THRESHOLD:
				weighted_x += (float(x - visible.position.x) + 0.5) * alpha
				weight += alpha
	var root_x: float = weighted_x / weight if weight > 0.0 else float(visible.size.x) * 0.5
	return Vector2(root_x, float(visible.size.y))


static func _visible_bounds(image: Image) -> Rect2i:
	var used: Rect2i = image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return used
	var left: int = used.position.x
	var right: int = used.end.x - 1
	var top: int = used.position.y
	var bottom: int = used.end.y - 1
	while top <= bottom and not _row_has_alpha(image, top, left, right):
		top += 1
	while bottom >= top and not _row_has_alpha(image, bottom, left, right):
		bottom -= 1
	while left <= right and not _column_has_alpha(image, left, top, bottom):
		left += 1
	while right >= left and not _column_has_alpha(image, right, top, bottom):
		right -= 1
	return Rect2i(left, top, maxi(0, right - left + 1), maxi(0, bottom - top + 1))


static func _row_has_alpha(image: Image, y: int, left: int, right: int) -> bool:
	for x: int in range(left, right + 1):
		if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
			return true
	return false


static func _column_has_alpha(image: Image, x: int, top: int, bottom: int) -> bool:
	for y: int in range(top, bottom + 1):
		if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
			return true
	return false
