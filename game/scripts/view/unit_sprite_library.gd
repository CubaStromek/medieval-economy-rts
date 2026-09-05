class_name UnitSpriteLibrary
extends RefCounted

# Original, single-pose prototype atlases. Each role owns one grid cell;
# alpha-tight regions keep inconsistent image padding out of world scale.
const CIVILIAN_ATLAS: String = "res://art/units/civilians-basic-v1.png"
const MILITARY_ATLAS: String = "res://art/units/military-basic-v1.png"
const CIVILIAN_ROLES: Array[String] = [
	"lumberjack", "carrier", "gardener", "farmer", "baker",
	"stonemason", "miner", "metallurgist", "smith", "butcher",
	"animal_breeder", "fisherman", "carpenter", "builder", "recruit",
]
const MILITARY_ROLES: Array[String] = [
	"militia", "axe_fighter", "sword_fighter", "bowman", "crossbowman",
	"lance_carrier", "pikeman", "scout", "knight", "rebel",
	"rogue", "vagabond", "barbarian", "warrior",
]
const MOUNTED_ROLES: Array[String] = ["scout", "knight", "vagabond"]
const TALL_TOOL_ROLES: Array[String] = ["lance_carrier", "pikeman", "rebel"]
const HUMAN_HEIGHT: float = 33.0
const ALPHA_THRESHOLD: float = 0.10
const FALLBACK_ROLE: String = "carrier"

# Main scenes used by viewport tests share the immutable atlas regions. The
# source images are inspected only once; no per-worker textures are created.
static var _textures: Dictionary = {}
static var _sizes: Dictionary = {}
static var _loaded_paths: Dictionary = {}
static var _cell_regions: Dictionary = {}


func _init() -> void:
	_load_atlas(CIVILIAN_ATLAS, CIVILIAN_ROLES)
	_load_atlas(MILITARY_ATLAS, MILITARY_ROLES)


func has_role(role: String) -> bool:
	return _textures.has(role)


func texture_for(role: String) -> Texture2D:
	return _textures.get(role, _textures.get(FALLBACK_ROLE)) as Texture2D


func atlas_cell_region(role: String) -> Rect2i:
	return _cell_regions.get(role, Rect2i()) as Rect2i


func sprite_size(role: String) -> Vector2:
	return _sizes.get(role, _sizes.get(FALLBACK_ROLE, Vector2(19, HUMAN_HEIGHT))) as Vector2


func sprite_rect(role: String, feet: Vector2) -> Rect2:
	var dimensions: Vector2 = sprite_size(role)
	return Rect2(feet - Vector2(dimensions.x * 0.5, dimensions.y), dimensions)


# All animation and adornment placement is presentation-only. Pausing freezes
# tick and frame_alpha, and a snapshot can reproduce the same small walk bob.
func presentation_for(worker: Dictionary, feet: Vector2, tick: int, frame_alpha: float) -> Dictionary:
	var role: String = String(worker.get("type", FALLBACK_ROLE))
	var bob: Vector2 = motion_offset(worker, tick, frame_alpha)
	var rect: Rect2 = sprite_rect(role, feet + bob)
	var left: bool = faces_left(worker)
	var hand_side: float = -1.0 if left else 1.0
	var mounted: bool = role in MOUNTED_ROLES
	return {
		"texture": texture_for(role),
		"rect": rect,
		"flip_h": left,
		"cargo_position": feet + bob + Vector2(hand_side * 6.5, -14.0 if not mounted else -24.0),
		"hunger_position": Vector2(feet.x + bob.x, rect.position.y - 5.0),
		"shadow_size": Vector2(22.0, 5.0) if mounted else Vector2(13.0, 3.5),
	}


static func faces_left(worker: Dictionary) -> bool:
	var previous: Vector2i = worker.get("previous_position", Vector2i.ZERO) as Vector2i
	var current: Vector2i = worker.get("position", previous) as Vector2i
	return current.x < previous.x


static func motion_offset(worker: Dictionary, tick: int, frame_alpha: float) -> Vector2:
	var previous: Vector2i = worker.get("previous_position", Vector2i.ZERO) as Vector2i
	var current: Vector2i = worker.get("position", previous) as Vector2i
	var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
	var progress: int = int(worker.get("visual_progress_ticks", duration))
	if previous == current or progress >= duration:
		return Vector2.ZERO
	var phase: float = (float(tick) + clampf(frame_alpha, 0.0, 1.0)) * 1.9 + float(int(worker.get("id", 0)) % 13) * 0.71
	return Vector2(sin(phase) * 0.25, -absf(sin(phase)) * 0.65)


static func _load_atlas(path: String, roles: Array[String]) -> void:
	if _loaded_paths.has(path) or not ResourceLoader.exists(path):
		return
	var atlas: Texture2D = load(path) as Texture2D
	if atlas == null:
		return
	var source: Image = atlas.get_image()
	if source == null or source.is_empty():
		return
	if source.is_compressed():
		source.decompress()
	var row_seams: Dictionary = {}
	for column: int in range(5):
		var left: int = roundi(float(column) * source.get_width() / 5.0)
		var right: int = roundi(float(column + 1) * source.get_width() / 5.0)
		row_seams[column] = [0,
			_find_horizontal_seam(source, left, right, roundi(source.get_height() / 3.0)),
			_find_horizontal_seam(source, left, right, roundi(source.get_height() * 2.0 / 3.0)),
			source.get_height()]
	for index: int in range(roles.size()):
		var column: int = index % 5
		var row: int = index / 5
		var left: int = roundi(float(column) * source.get_width() / 5.0)
		var right: int = roundi(float(column + 1) * source.get_width() / 5.0)
		var top: int = int((row_seams[column] as Array)[row])
		var bottom: int = int((row_seams[column] as Array)[row + 1])
		var cell_region := Rect2i(left, top, right - left, bottom - top)
		_cell_regions[roles[index]] = cell_region
		var cell: Image = source.get_region(cell_region)
		var used: Rect2i = _visible_bounds(cell)
		if used.size.x <= 0 or used.size.y <= 0:
			push_warning("Unit sprite atlas has an empty role: " + roles[index])
			continue
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(Vector2(left + used.position.x, top + used.position.y), Vector2(used.size))
		texture.filter_clip = true
		var role: String = roles[index]
		_textures[role] = texture
		var target_height: float = 40.0 if role in MOUNTED_ROLES or role in TALL_TOOL_ROLES else HUMAN_HEIGHT
		var max_width: float = 40.0 if role in MOUNTED_ROLES else 31.0
		var scale_factor: float = minf(target_height / float(used.size.y), max_width / float(used.size.x))
		_sizes[role] = Vector2(used.size) * scale_factor
	_loaded_paths[path] = true


# Long spear tips can extend slightly beyond the nominal 5×3 layout. Find
# the transparent gutter independently in each column so neighbouring roles
# never inherit a clipped weapon fragment. The PNG itself stays untouched.
static func _find_horizontal_seam(image: Image, left: int, right: int, nominal: int) -> int:
	var best: int = nominal
	var minimum_opaque: int = right - left + 1
	for y: int in range(maxi(1, nominal - 50), mini(image.get_height() - 1, nominal + 50) + 1):
		var opaque: int = 0
		for x: int in range(left, right):
			if image.get_pixel(x, y).a >= ALPHA_THRESHOLD:
				opaque += 1
			if opaque > minimum_opaque:
				break
		if opaque < minimum_opaque or (opaque == minimum_opaque and absi(y - nominal) < absi(best - nominal)):
			minimum_opaque = opaque
			best = y
	return best


# get_used_rect supplies the initial alpha extent. Trim only nearly invisible
# antialiasing at its outer edges; genuine tools and weapon tips remain intact.
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


# Cargo stays attached to the worker's forward hand and reflects the live ware.
# These tiny marks remain readable when the atlas characters are zoomed out.
static func paint_cargo(canvas: CanvasItem, resource: String, center: Vector2, color: Color) -> void:
	var outline: Color = color.darkened(0.45)
	match resource:
		"log":
			canvas.draw_line(center + Vector2(-5, 1), center + Vector2(4, -2), outline, 5.0, true)
			canvas.draw_line(center + Vector2(-5, 0), center + Vector2(4, -3), color, 3.5, true)
			canvas.draw_circle(center + Vector2(4, -2), 2.0, color.lightened(0.35))
		"plank":
			for row: int in range(2):
				canvas.draw_line(center + Vector2(-5, row * 3 - 2), center + Vector2(5, row * 3 - 4), outline, 3.0, true)
				canvas.draw_line(center + Vector2(-5, row * 3 - 2), center + Vector2(5, row * 3 - 4), color.lightened(row * 0.12), 1.8, true)
		"stone", "coal", "iron_ore", "gold_ore":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 2), center + Vector2(-3, -4), center + Vector2(2, -5), center + Vector2(5, 0), center + Vector2(3, 3)]), color)
			canvas.draw_line(center + Vector2(-3, -4), center + Vector2(2, -5), color.lightened(0.4), 1.0, true)
		"grain", "flour":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-2, -5), center + Vector2(2, -5), center + Vector2(2, -2), center + Vector2(5, 3), center + Vector2(-4, 3), center + Vector2(-2, -2)]), color)
			canvas.draw_line(center + Vector2(-2, -2), center + Vector2(2, -2), outline, 1.5, true)
		"bread", "sausage":
			canvas.draw_line(center + Vector2(-3, 0), center + Vector2(3, -1), color, 5.0, true)
			canvas.draw_line(center + Vector2(-1, -2), center + Vector2(0, 0), color.lightened(0.3), 1.0, true)
		"wine":
			canvas.draw_rect(Rect2(center + Vector2(-3, -3), Vector2(6, 7)), color)
			canvas.draw_rect(Rect2(center + Vector2(-1, -6), Vector2(2, 3)), outline)
			canvas.draw_line(center + Vector2(-3, 0), center + Vector2(3, 0), Color(0.81, 0.71, 0.47), 2.0)
		"fish":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -3), center + Vector2(-5, 3), center + Vector2(-2, 1), center + Vector2(1, 3), center + Vector2(6, 0), center + Vector2(1, -3), center + Vector2(-2, -1)]), color)
		"iron", "gold":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 2), center + Vector2(-3, -3), center + Vector2(3, -3), center + Vector2(5, 2)]), color)
			canvas.draw_line(center + Vector2(-3, -3), center + Vector2(3, -3), color.lightened(0.35), 1.2)
		"axe", "sword", "lance", "pike":
			canvas.draw_line(center + Vector2(-4, 4), center + Vector2(4, -5), Color(0.54, 0.36, 0.20), 1.8, true)
			canvas.draw_line(center + Vector2(0, -1), center + Vector2(4, -5), color.lightened(0.3), 2.5, true)
		"bow", "crossbow":
			canvas.draw_arc(center, 5, -PI * 0.5, PI * 0.5, 10, color, 1.8, true)
			canvas.draw_line(center + Vector2(0, -5), center + Vector2(0, 5), Color(0.82, 0.78, 0.64), 1.0, true)
		"wooden_shield", "iron_shield", "leather_armour", "iron_armour", "skin", "leather":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -4), center + Vector2(4, -4), center + Vector2(3, 2), center + Vector2(0, 5), center + Vector2(-3, 2)]), color)
			canvas.draw_line(center + Vector2(0, -3), center + Vector2(0, 3), color.lightened(0.25), 1.0)
		_:
			canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), color)
			canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), outline, false, 1.0)
			canvas.draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), outline, 1.0)
