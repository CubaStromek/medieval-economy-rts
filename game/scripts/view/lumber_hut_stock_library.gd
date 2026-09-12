class_name LumberHutStockLibrary
extends RefCounted

# The stock export shares finished.png's existing source canvas. Its rect and
# scale always come from the house presentation, never from inventory/alpha.
const MANIFEST_PATH: String = "res://art/buildings/lumber_hut/v1/stock/manifest.json"
const AUTHORED_CAPACITY: int = 6
const ALPHA_THRESHOLD: float = 0.10

static var _loaded: bool = false
static var _textures: Dictionary = {}
static var _hit_masks: Dictionary = {}
static var _label_anchor := Vector2.ZERO
static var _unknown_anchor := Vector2.ZERO


func _init() -> void:
	_ensure_loaded()


func presentation_for(world: Variant, building: Dictionary, house: Dictionary) -> Dictionary:
	if not _loaded or house.is_empty() or String(building.get("type", "")) != "lumber_hut" \
			or int(building.get("footprint_version", 0)) not in [1, 2] or not world.is_building_complete(building):
		return {}
	var scale: float = float(house["source_to_world"])
	var rect: Rect2 = house["rect"]
	var result: Dictionary = {"rect": rect, "source_to_world": scale,
		"label_position": rect.position + _unknown_anchor * scale,
		"known": false, "amount": -1, "capacity": -1,
		"texture": null, "hit_mask": null, "count_label": "?"}
	# An explored/visible foreign silhouette does not grant live inventory
	# access. Return before reading outputs, including while a foreign worker
	# is visible; local ownership follows the same policy as the current HUD.
	if world.fog.enabled and not world.is_local_entity(building):
		return result
	var amount: int = maxi(0, int((building.get("outputs", {}) as Dictionary).get("log", 0)))
	var capacity: int = int(world.catalog.building("lumber_hut").get("output_capacity", 0))
	result["known"] = true
	result["amount"] = amount
	result["capacity"] = capacity
	result["label_position"] = rect.position + _label_anchor * scale
	result["texture"] = _textures[mini(amount, AUTHORED_CAPACITY)]
	result["hit_mask"] = _hit_masks[mini(amount, AUTHORED_CAPACITY)]
	# Six authored pieces map exactly to today's capacity. A future catalog
	# edit or unexpected higher inventory must show an explicit actual count,
	# rather than silently pretending that six represents every possible value.
	result["count_label"] = "" if capacity == AUTHORED_CAPACITY and amount <= AUTHORED_CAPACITY \
		else "%d/%d" % [amount, capacity]
	return result


static func contains_point(presentation: Dictionary, point: Vector2) -> bool:
	if presentation.is_empty():
		return false
	var rect: Rect2 = presentation["rect"]
	var mask: BitMap = presentation.get("hit_mask") as BitMap
	if mask == null or not rect.has_point(point):
		return false
	var pixel := Vector2i((point - rect.position) / float(presentation["source_to_world"]))
	return mask.get_bitv(pixel)


static func _ensure_loaded() -> void:
	if _loaded or not FileAccess.file_exists(MANIFEST_PATH):
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not value is Dictionary:
		push_warning("Lumber hut stock manifest is invalid.")
		return
	var manifest: Dictionary = value
	var canvas: Array = manifest.get("canvas", []) as Array
	var label: Array = manifest.get("stock_count_label", []) as Array
	var unknown: Array = manifest.get("unknown_label", []) as Array
	var states: Array = manifest.get("states", []) as Array
	if canvas.size() != 2 or int(canvas[0]) != 640 or int(canvas[1]) != 640 \
			or label.size() != 2 or unknown.size() != 2 or states.size() != AUTHORED_CAPACITY + 1 \
			or int(manifest.get("authored_capacity", 0)) != AUTHORED_CAPACITY:
		push_warning("Lumber hut stock registration is invalid.")
		return
	var textures: Dictionary = {}
	var masks: Dictionary = {}
	for amount: int in range(AUTHORED_CAPACITY + 1):
		var state: Dictionary = states[amount] as Dictionary
		var path: String = MANIFEST_PATH.get_base_dir().path_join(String(state.get("image", "")))
		if int(state.get("amount", -1)) != amount or not ResourceLoader.exists(path):
			push_warning("Missing registered lumber hut stock state %d." % amount)
			return
		var imported: Texture2D = load(path) as Texture2D
		var source: Image = imported.get_image() if imported != null else null
		if source == null or source.get_size() != Vector2i(640, 640):
			push_warning("Lumber hut stock must share the unchanged house canvas.")
			return
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		var mask := BitMap.new()
		mask.create_from_image_alpha(source, ALPHA_THRESHOLD)
		if (amount == 0 and mask.get_true_bit_count() != 0) or (amount > 0 and mask.get_true_bit_count() == 0):
			push_warning("Lumber hut stock alpha does not match the inventory state.")
			return
		masks[amount] = mask
		source.generate_mipmaps()
		textures[amount] = ImageTexture.create_from_image(source)
	_textures = textures
	_hit_masks = masks
	_label_anchor = Vector2(float(label[0]), float(label[1]))
	_unknown_anchor = Vector2(float(unknown[0]), float(unknown[1]))
	_loaded = true
