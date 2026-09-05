class_name WorldSnapshot
extends RefCounted

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")

const SAVE_VERSION: int = 5
const MAX_MAP_SIZE := Vector2i(256, 256)
# JSON stores numbers as doubles. Keep integer state exact across JSON round trips.
const MAX_SAFE_INTEGER: int = 9007199254740991

var _world: Variant
var _valid: bool = true
var _version: int = 0
var _seen_ids: Dictionary = {}
var _highest_id: int = 0


static func to_data(world: Variant) -> Dictionary:
	var terrain_rows: Array[Array] = []
	for y: int in range(world.grid.size.y):
		var row: Array[String] = []
		for x: int in range(world.grid.size.x):
			row.append(world.grid.base_terrain_at(Vector2i(x, y)))
		terrain_rows.append(row)
	var roads: Array[Array] = []
	for cell: Vector2i in _sorted_cells(world.grid.roads.keys()):
		roads.append(_vector_to_array(cell))
	var trails: Array[Array] = []
	for cell: Vector2i in _sorted_cells(world.grid.dirt_trails.keys()):
		trails.append(_vector_to_array(cell))
	var wear: Array[Array] = []
	for cell: Vector2i in _sorted_cells(world.grid.traffic_wear.keys()):
		wear.append([cell.x, cell.y, int(world.grid.traffic_wear[cell])])
	var buildings: Array[Dictionary] = []
	for entity_id: int in _sorted_ids(world.buildings):
		var building: Dictionary = world.buildings[entity_id].duplicate(true)
		building["position"] = _vector_to_array(building["position"])
		building["entrance"] = _vector_to_array(building["entrance"])
		buildings.append(building)
	var trees: Array[Dictionary] = []
	for entity_id: int in _sorted_ids(world.trees):
		var tree: Dictionary = world.trees[entity_id].duplicate(true)
		tree["position"] = _vector_to_array(tree["position"])
		trees.append(tree)
	var workers: Array[Dictionary] = []
	for entity_id: int in _sorted_ids(world.workers):
		var worker: Dictionary = world.workers[entity_id]
		workers.append({
			"id": entity_id,
			"type": worker["type"],
			"home_id": worker["home_id"],
			"position": _vector_to_array(worker["position"]),
			"carrying": worker["carrying"],
			"planting_cooldown": worker.get("planting_cooldown", 0),
		})
	return {
		"version": SAVE_VERSION,
		"tick": world.tick,
		"next_entity_id": world._next_entity_id,
		"map_size": _vector_to_array(world.grid.size),
		"terrain": {"base": terrain_rows},
		"roads": roads,
		"dirt_trails": trails,
		"traffic_wear": wear,
		"buildings": buildings,
		"trees": trees,
		"workers": workers,
	}


# Only accepts a fresh staged world. SimulationWorld commits it after success;
# neither malformed input nor a late spatial failure can mutate the live world.
static func load_into(staged_world: Variant, data: Dictionary) -> bool:
	var snapshot := WorldSnapshot.new()
	snapshot._world = staged_world
	return snapshot._load(data)


func _load(data: Dictionary) -> bool:
	_version = _read_integer(data.get("version"), 1, SAVE_VERSION)
	var saved_tick: int = _read_integer(data.get("tick"))
	var next_id: int = _read_integer(data.get("next_entity_id"), 1)
	var size_data: Array = _read_array(data.get("map_size"))
	if size_data.size() != 2:
		return false
	var size := Vector2i(
		_read_integer(size_data[0], 1, MAX_MAP_SIZE.x),
		_read_integer(size_data[1], 1, MAX_MAP_SIZE.y)
	)
	var buildings: Array = _read_array(data.get("buildings"))
	var trees: Array = _read_array(data.get("trees"))
	var workers: Array = _read_array(data.get("workers"))
	if not _valid:
		return false
	_world.grid = GridMapSimClass.new(size)
	_world.grid.configure_movement(_world.catalog.movement)
	if _version >= 4 and not _load_terrain(data.get("terrain")):
		return false
	if not _load_surfaces(data):
		return false
	if not _load_buildings(buildings) or not _load_trees(trees) or not _load_workers(workers):
		return false
	if _version >= 4 and next_id <= _highest_id:
		return false
	_world._next_entity_id = maxi(next_id, _highest_id + 1)
	_world.tick = saved_tick
	for worker: Dictionary in _world.workers.values():
		if not String(worker["carrying"]).is_empty():
			_world._resume_carried_ware(worker)
	_world._push_event("Save loaded at tick %d." % saved_tick)
	return true


func _load_terrain(value: Variant) -> bool:
	var terrain: Dictionary = _read_dictionary(value)
	var rows: Array = _read_array(terrain.get("base"))
	if not _valid or rows.size() != _world.grid.size.y:
		return false
	for y: int in range(rows.size()):
		var row: Array = _read_array(rows[y])
		if not _valid or row.size() != _world.grid.size.x:
			return false
		for x: int in range(row.size()):
			var terrain_id: String = _read_string(row[x])
			if not _valid or not _world.grid.set_base_terrain(Vector2i(x, y), terrain_id):
				return false
	return true


func _load_surfaces(data: Dictionary) -> bool:
	# Trails were introduced in v2; v1 legitimately has neither trail field.
	var roads: Array = _read_array(data.get("roads"))
	var trails: Array = _read_array(data.get("dirt_trails", [] if _version == 1 else null))
	var wear: Array = _read_array(data.get("traffic_wear", [] if _version == 1 else null))
	if not _valid:
		return false
	var seen: Dictionary = {}
	for raw_cell: Variant in roads:
		var cell: Vector2i = _read_cell(raw_cell)
		if not _valid or seen.has(cell) or not _world.grid.add_road(cell):
			return false
		seen[cell] = true
	for raw_cell: Variant in trails:
		var cell: Vector2i = _read_cell(raw_cell)
		if not _valid or seen.has(cell) or not _world.grid.add_dirt_trail(cell):
			return false
		seen[cell] = true
	var seen_wear: Dictionary = {}
	for raw_wear: Variant in wear:
		var entry: Array = _read_array(raw_wear)
		if not _valid or entry.size() != 3:
			return false
		var cell: Vector2i = _read_cell([entry[0], entry[1]])
		var passes: int = _read_integer(entry[2])
		if (
			not _valid or seen_wear.has(cell) or _world.grid.roads.has(cell)
			or not _world.grid.is_walkable(cell) or not _world.grid.is_roadable(cell)
		):
			return false
		seen_wear[cell] = true
		_world.grid.set_traffic_wear(cell, passes)
	return true


func _load_buildings(saved_buildings: Array) -> bool:
	var entrances: Dictionary = {}
	for value: Variant in saved_buildings:
		var saved: Dictionary = _read_dictionary(value)
		var entity_id: int = _read_entity_id(saved.get("id"))
		var type: String = _read_string(saved.get("type"))
		var position: Vector2i = _read_cell(saved.get("position"))
		var entrance: Vector2i = _read_cell(saved.get("entrance"))
		var definition: Dictionary = _world.catalog.building(type)
		var inputs: Dictionary = _read_inventory(saved.get("inputs", {} if _version < 4 else null))
		var outputs: Dictionary = _read_inventory(saved.get("outputs", {} if _version < 4 else null))
		var storage: Dictionary = _read_inventory(saved.get("storage", {} if _version < 4 else null))
		var recipe: Dictionary = _world.catalog.recipe(String(definition.get("recipe", "")))
		var process_limit: int = maxi(0, int(recipe.get("duration_ticks", 0)))
		var process_remaining: int = _read_integer(saved.get("process_remaining"), 0, process_limit)
		if (
			not _valid or definition.is_empty() or not _world.grid.is_buildable(position)
			or entrances.has(position) or not _world.grid.is_walkable(entrance)
			or absi(position.x - entrance.x) + absi(position.y - entrance.y) != 1
			or not _world.grid.overlay_at(position).is_empty()
			or _world.grid.traffic_wear_at(position) != 0
		):
			return false
		var queue: Array = _read_array(saved.get("training_queue", [] if _version < 3 else null))
		var trainable: Array = definition.get("trains", [])
		if not _valid or queue.size() > maxi(1, int(definition.get("queue_capacity", 1))):
			return false
		var training_queue: Array[String] = []
		for queued_value: Variant in queue:
			var queued_type: String = _read_string(queued_value)
			if not _valid or not trainable.has(queued_type) or _world.catalog.unit(queued_type).is_empty():
				return false
			training_queue.append(queued_type)
		var training_limit: int = 0 if training_queue.is_empty() else _world._training_ticks_for(training_queue[0])
		var training_remaining: int = _read_integer(
			saved.get("training_remaining", training_limit if _version < 3 else null), 0, training_limit
		)
		if not _valid:
			return false
		inputs["log"] = inputs.get("log", 0)
		outputs["log"] = outputs.get("log", 0)
		outputs["plank"] = outputs.get("plank", 0)
		for resource: String in ["log", "plank", "stone"]:
			storage[resource] = storage.get(resource, 0)
		_world.buildings[entity_id] = {
			"id": entity_id, "type": type, "position": position, "entrance": entrance,
			"storage": storage, "inputs": inputs, "outputs": outputs,
			"process_remaining": process_remaining,
			"training_queue": training_queue, "training_remaining": training_remaining,
		}
		entrances[entrance] = true
		_world.grid.block(position, entity_id)
	return true


func _load_trees(saved_trees: Array) -> bool:
	var cells: Dictionary = {}
	for value: Variant in saved_trees:
		var saved: Dictionary = _read_dictionary(value)
		var entity_id: int = _read_entity_id(saved.get("id"))
		var position: Vector2i = _read_cell(saved.get("position"))
		var amount: int = _read_integer(saved.get("amount"), 1)
		var age: int = _world.TREE_MATURE_AGE_TICKS
		if _version >= 5:
			age = _read_integer(saved.get("age_ticks"), 0, _world.TREE_MATURE_AGE_TICKS)
		elif saved.has("age_ticks"):
			_read_integer(saved["age_ticks"], 0, _world.TREE_MATURE_AGE_TICKS)
		if not _valid or cells.has(position) or not _world.grid.allows_trees(position):
			return false
		cells[position] = true
		_world.trees[entity_id] = {"id": entity_id, "position": position, "amount": amount, "age_ticks": age}
	return true


func _load_workers(saved_workers: Array) -> bool:
	var normalized: Array[Dictionary] = []
	for value: Variant in saved_workers:
		var saved: Dictionary = _read_dictionary(value)
		var entity_id: int = _read_entity_id(saved.get("id"))
		if not _valid:
			return false
		normalized.append({"id": entity_id, "data": saved})
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	for index: int in range(normalized.size()):
		var saved: Dictionary = normalized[index]["data"]
		var entity_id: int = normalized[index]["id"]
		var fallback: String = "lumberjack" if index == 0 else "carrier"
		var type: String = _read_string(saved.get("type", fallback if _version == 1 else null))
		var position: Vector2i = _read_cell(saved.get("position"))
		var home_id: int = _read_integer(saved.get("home_id", 0 if _version == 1 else null))
		var carrying: String = _read_string(saved.get("carrying"))
		var cooldown: int = _read_integer(saved.get("planting_cooldown", 0 if _version < 5 else null))
		if not _valid or _world.catalog.unit(type).is_empty() or not ["", "log", "plank"].has(carrying):
			return false
		if type == "gardener" and not carrying.is_empty():
			return false
		if home_id != 0 and (
			not _world.buildings.has(home_id)
			or String(_world.buildings[home_id]["type"]) != "lumber_hut"
		):
			return false
		if type == "lumberjack" and home_id == 0:
			home_id = _world._first_building("lumber_hut")
		# Reuse worker construction so runtime defaults have one authority.
		_world._next_entity_id = entity_id
		if _world.spawn_worker(position, type, home_id) == 0:
			return false
		_world.workers[entity_id]["carrying"] = carrying
		_world.workers[entity_id]["planting_cooldown"] = cooldown
	return true


func _read_integer(value: Variant, minimum: int = 0, maximum: int = MAX_SAFE_INTEGER) -> int:
	if not (value is int or value is float):
		_valid = false
		return 0
	if value is float and (not is_finite(value) or floor(value) != value):
		_valid = false
		return 0
	if value < minimum or value > maximum:
		_valid = false
		return 0
	return int(value)


func _read_entity_id(value: Variant) -> int:
	var entity_id: int = _read_integer(value, 1, MAX_SAFE_INTEGER - 1)
	if _seen_ids.has(entity_id):
		_valid = false
	_seen_ids[entity_id] = true
	_highest_id = maxi(_highest_id, entity_id)
	return entity_id


func _read_array(value: Variant) -> Array:
	if value is Array:
		return value
	_valid = false
	return []


func _read_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	_valid = false
	return {}


func _read_string(value: Variant) -> String:
	if value is String:
		return value
	_valid = false
	return ""


func _read_cell(value: Variant) -> Vector2i:
	var coordinates: Array = _read_array(value)
	if coordinates.size() != 2:
		_valid = false
		return Vector2i(-1, -1)
	return Vector2i(
		_read_integer(coordinates[0], 0, _world.grid.size.x - 1),
		_read_integer(coordinates[1], 0, _world.grid.size.y - 1)
	)


func _read_inventory(value: Variant) -> Dictionary:
	var source: Dictionary = _read_dictionary(value)
	var result: Dictionary = {}
	for key: Variant in source:
		if not key is String or not _world.catalog.resources.has(key):
			_valid = false
			return {}
		result[key] = _read_integer(source[key])
	return result


static func _sorted_ids(entities: Dictionary) -> Array:
	var ids: Array = entities.keys()
	ids.sort()
	return ids


static func _sorted_cells(values: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for value: Vector2i in values:
		cells.append(value)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return cells


static func _vector_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]
