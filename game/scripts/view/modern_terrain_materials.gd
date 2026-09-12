class_name ModernTerrainMaterials
extends RefCounted

# Terrain-kind metadata only; no original pixels, alpha masks, or tile images.
# Source corner order is TL, TR, BR, BL. This intentionally covers the 42 IDs
# used by the sandbox crops, not the full KaM terrain catalogue.
const TILE_KINDS := {
	0: "GGGG", 2: "GGGG", 13: "GGGG", 14: "GGGG", 16: "PPPP",
	34: "MMMM", 35: "DDDD", 36: "DDDD", 37: "DDDD",
	66: "GPGG", 67: "PPGG", 68: "PPPG", 84: "GMGG", 85: "MMGG",
	86: "MMMG", 87: "MDMM", 88: "DDMM", 89: "DDDM",
	105: "WDWW", 106: "DDWW", 107: "DDDW", 146: "OOOO", 147: "OOOO",
	152: "CCCC", 153: "CCCC", 154: "CCCC", 155: "CCCC",
	157: "RRRR", 158: "RRRR", 159: "RRRR", 172: "RRGG", 175: "RRDD",
	176: "RRRG", 179: "RRRD", 180: "GRGG", 183: "DRDD",
	192: "WWWW", 193: "WWWW", 194: "WWWW", 196: "WWWW",
	236: "WRWW", 237: "RRRW"
}
const CORNERS := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]


static func world_corner_kinds(tile_id: int, rotation: int) -> Array[String]:
	var result: Array[String] = []
	if not TILE_KINDS.has(tile_id) or rotation < 0 or rotation > 3:
		return result
	var source: String = TILE_KINDS[tile_id]
	for index: int in range(4):
		result.append(source[(index + 4 - rotation) % 4])
	return result


# Atlas order: grass, dry grass, limestone, dirt, gravel, water, coal, ore.
# KaM's dirt category includes olive, vegetated earth, not only bare brown soil.
# Our D/M art mixes retain that appearance. Gravel remains available for future
# art tuning, not invented as a source map kind. These are input weights, not
# final visual percentages: the fragment shader sharpens material boundaries.
static func kind_weights(kind: String) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(8)
	match kind:
		"G": result[0] = 1.0
		"P": result[1] = 1.0
		"R": result[2] = 1.0
		"D":
			result[0] = 0.45
			result[1] = 0.40
			result[3] = 0.15
		"W": result[5] = 1.0
		"C": result[6] = 1.0
		"O": result[7] = 1.0
		"M":
			result[0] = 0.65
			result[1] = 0.25
			result[3] = 0.10
	return result


# Every adjacent tile contributes to the SAME shared-vertex value. Bilinear
# sampling of these two float images stays continuous across every cell edge,
# even when source corner classifications disagree. Input is never mutated.
static func build_weights(patch: Dictionary) -> Dictionary:
	var size_value: Variant = patch.get("size")
	if not size_value is Array or size_value.size() != 2:
		return {"error": "Modern terrain requires two cell dimensions."}
	for component: Variant in size_value:
		if not _whole(component, 1, 64):
			return {"error": "Modern terrain dimensions must be whole numbers in 1..64."}
	var size := Vector2i(int(size_value[0]), int(size_value[1]))
	var tiles: Variant = patch.get("tile_rows")
	if not tiles is Array or tiles.size() != size.y:
		return {"error": "Modern terrain tile rows are missing."}
	for row: Variant in tiles:
		if not row is Array or row.size() != size.x:
			return {"error": "Modern terrain tile rows have inconsistent widths."}
		for tile: Variant in row:
			if not tile is Array or tile.size() != 2 or not _whole(tile[0], 0, 255) or not _whole(tile[1], 0, 3):
				return {"error": "Modern terrain tile ID or rotation is invalid."}
			if not TILE_KINDS.has(int(tile[0])):
				return {"error": "Modern texture pack has no terrain-kind definition for tile %d." % int(tile[0])}
	var weights: Array[PackedFloat32Array] = []
	var contributions := PackedInt32Array()
	contributions.resize((size.x + 1) * (size.y + 1))
	for index: int in range(contributions.size()):
		var empty := PackedFloat32Array()
		empty.resize(8)
		weights.append(empty)
	for y: int in range(size.y):
		for x: int in range(size.x):
			var tile: Array = tiles[y][x]
			var kinds: Array[String] = world_corner_kinds(int(tile[0]), int(tile[1]))
			for corner: int in range(4):
				var point: Vector2i = Vector2i(x, y) + CORNERS[corner]
				var index: int = point.y * (size.x + 1) + point.x
				var incoming: PackedFloat32Array = kind_weights(kinds[corner])
				var accumulated: PackedFloat32Array = weights[index]
				for channel: int in range(8):
					accumulated[channel] += incoming[channel]
				weights[index] = accumulated
				contributions[index] += 1
	var low := Image.create(size.x + 1, size.y + 1, false, Image.FORMAT_RGBAF)
	var high := Image.create(size.x + 1, size.y + 1, false, Image.FORMAT_RGBAF)
	for y: int in range(size.y + 1):
		for x: int in range(size.x + 1):
			var index: int = y * (size.x + 1) + x
			var channels: PackedFloat32Array = weights[index]
			for channel: int in range(8):
				channels[channel] /= float(contributions[index])
			weights[index] = channels
			low.set_pixel(x, y, Color(channels[0], channels[1], channels[2], channels[3]))
			high.set_pixel(x, y, Color(channels[4], channels[5], channels[6], channels[7]))
	return {"error": "", "low": low, "high": high, "weights": weights, "size": size}


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is int and not value is float:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
