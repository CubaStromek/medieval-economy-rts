class_name MountainousRegionStart
extends RefCounted

# The settlement coordinates belong to the verified Mountainous Region source
# below. Other imported landscapes remain terrain-only.
const MAP_NAME: String = "Mountainous Region"
const MAP_SIZE: Vector2i = Vector2i(143, 127)
const SOURCE_SHA256: String = "cf70c8b222632e7281a10935125b325a0367b36a68f29aae3c4792777b397bb4"

const WAREHOUSE_CELL: Vector2i = Vector2i(94, 19)
const SCHOOL_CELL: Vector2i = Vector2i(100, 19)
const FOCUS_CELL: Vector2i = Vector2i(98, 19)

const STARTING_GOLD: int = 50
const STARTING_LOGS: int = 20
const STARTING_PLANKS: int = 20
const STARTING_STONE: int = 20


static func matches_import(world: Variant, imported: Dictionary) -> bool:
	if world == null or world.grid.size != MAP_SIZE or String(imported.get("name", "")) != MAP_NAME:
		return false
	var source_value: Variant = imported.get("source")
	return source_value is Dictionary and String((source_value as Dictionary).get("sha256", "")) == SOURCE_SHA256


static func apply_if_supported(world: Variant, imported: Dictionary) -> bool:
	if not matches_import(world, imported):
		return false
	setup(world)
	return true


static func setup(world: Variant) -> void:
	assert(world.grid.size == MAP_SIZE and world.buildings.is_empty() and world.workers.is_empty(),
		"Mountainous Region start requires the fresh canonical landscape")
	# The imported landscape enables normal economy rules. Temporarily disable
	# their construction costs so these two authored starter buildings are ready.
	world.economy_enabled = false
	assert(world.can_place_building("warehouse", WAREHOUSE_CELL)
		and world.can_place_building("school", SCHOOL_CELL),
		"Mountainous Region starter plateau no longer accepts its authored buildings")
	var warehouse_id: int = int(world.place_building("warehouse", WAREHOUSE_CELL))
	var school_id: int = int(world.place_building("school", SCHOOL_CELL))
	assert(warehouse_id != 0 and school_id != 0,
		"Mountainous Region starter buildings must be placed completely")

	var warehouse: Dictionary = world.buildings[warehouse_id]
	warehouse["storage"]["gold"] = STARTING_GOLD - 1
	warehouse["storage"]["log"] = STARTING_LOGS
	warehouse["storage"]["plank"] = STARTING_PLANKS
	warehouse["storage"]["stone"] = STARTING_STONE
	# With no starting citizens, one Gold must already be inside the School so
	# the first Carrier can be trained and deliver the remaining stock himself.
	world.buildings[school_id]["inputs"]["gold"] = 1
	world.economy_enabled = true
	world.event_log.clear()
	world._push_event("Mountainous Region start: Warehouse and School ready; 50 Gold, 20 Logs, 20 Planks and 20 Stone. Train a Carrier first.")


static func is_ready(world: Variant) -> bool:
	if world == null or world.grid.size != MAP_SIZE or not world.economy_enabled:
		return false
	var warehouse_id: int = int(world.building_id_at(WAREHOUSE_CELL))
	var school_id: int = int(world.building_id_at(SCHOOL_CELL))
	return warehouse_id != 0 and school_id != 0 \
		and String(world.buildings[warehouse_id]["type"]) == "warehouse" \
		and String(world.buildings[school_id]["type"]) == "school" \
		and world.is_building_complete(world.buildings[warehouse_id]) \
		and world.is_building_complete(world.buildings[school_id])
