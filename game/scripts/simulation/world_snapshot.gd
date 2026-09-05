class_name WorldSnapshot
extends RefCounted

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const WorkplacesClass = preload("res://scripts/simulation/workplaces.gd")

const SAVE_VERSION: int = 15
const MAX_INDOOR_WAIT_TICKS: int = 6
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
	var height_rows: Array[Array] = []
	for y: int in range(world.grid.size.y + 1):
		var row: Array[int] = []
		for x: int in range(world.grid.size.x + 1):
			row.append(world.grid.vertex_height(Vector2i(x, y)))
		height_rows.append(row)
	var roads: Array[Array] = []
	for cell: Vector2i in _sorted_cells(world.grid.roads.keys()):
		roads.append(_vector_to_array(cell))
	var trails: Array[Array] = []
	for cell: Vector2i in _sorted_cells(world.grid.dirt_trails.keys()):
		trails.append(_vector_to_array(cell))
	var wear: Array[Array] = []
	var trail_decay: Array[Array] = []
	for cell: Vector2i in _sorted_cells(world.grid.traffic_wear.keys()):
		wear.append([cell.x, cell.y, int(world.grid.traffic_wear[cell])])
		trail_decay.append([cell.x, cell.y, int(world.grid.trail_last_decay[cell])])
	var trail_links: Array[Array] = []
	for key: Vector4i in _sorted_trail_keys(world.grid.trail_links.keys()):
		var link: Dictionary = world.grid.trail_links[key]
		trail_links.append([key.x, key.y, key.z, key.w, int(link["wear"]), int(link["decay_tick"]), bool(link["established"])])
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
	var fields: Array[Dictionary] = []
	for entity_id: int in _sorted_ids(world.fields):
		var field: Dictionary = world.fields[entity_id]
		fields.append({
			"id": entity_id,
			"position": _vector_to_array(field["position"]),
			"age_ticks": field["age_ticks"],
			"kind": field.get("kind", "wheat"),
		})
	var deposits: Array[Dictionary] = []
	for entity_id: int in _sorted_ids(world.deposits):
		var deposit: Dictionary = world.deposits[entity_id].duplicate(true)
		deposit["position"] = _vector_to_array(deposit["position"])
		deposits.append(deposit)
	var workers: Array[Dictionary] = []
	for entity_id: int in _sorted_ids(world.workers):
		var worker: Dictionary = world.workers[entity_id]
		workers.append({
			"id": entity_id,
			"type": worker["type"],
			"home_id": worker["home_id"],
			"sleep_home_id": worker.get("sleep_home_id", 0),
			"inside_building_id": worker.get("inside_building_id", 0),
			"indoor_wait_ticks": worker.get("indoor_wait_ticks", 0),
			"position": _vector_to_array(worker["position"]),
			"carrying": worker["carrying"],
			"planting_cooldown": worker.get("planting_cooldown", 0),
			"hunger": worker.get("hunger", int(world.catalog.economy.get("condition_initial", 1620))),
			"meal_ticks_left": worker.get("meal_ticks_left", 0),
			"meal_course": (worker.get("meal_course", {}) as Dictionary).duplicate(true),
			"food_requested": worker.get("food_requested", false),
			"ration_delivery": (worker.get("ration_delivery", {}) as Dictionary).duplicate(true),
		})
	return {
		"version": SAVE_VERSION,
		"economy_enabled": world.economy_enabled,
		"tick": world.tick,
		"next_entity_id": world._next_entity_id,
		"map_size": _vector_to_array(world.grid.size),
		"terrain": {"base": terrain_rows, "corner_heights": height_rows},
		"roads": roads,
		"dirt_trails": trails,
		"traffic_wear": wear,
		"trail_last_decay": trail_decay,
		"trail_links": trail_links,
		"buildings": buildings,
		"trees": trees,
		"fields": fields,
		"deposits": deposits,
		"workers": workers,
	}


# Only accepts a fresh staged world. SimulationWorld commits it after success;
# neither malformed input nor a late spatial failure can mutate the live world.
func load_into(staged_world: Variant, data: Dictionary) -> bool:
	_world = staged_world
	return _load(data)


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
	var fields: Array = _read_array(data.get("fields", [] if _version < 6 else null))
	var deposits: Array = _read_array(data.get("deposits", [] if _version < 7 else null))
	var economy_enabled: bool = _read_bool(data.get("economy_enabled", false if _version < 7 else null))
	var workers: Array = _read_array(data.get("workers"))
	if not _valid:
		return false
	_world.grid = GridMapSimClass.new(size)
	_world.grid.configure_movement(_world.catalog.movement)
	if _version >= 4 and not _load_terrain(data.get("terrain")):
		return false
	if not _load_surfaces(data, saved_tick):
		return false
	if not _load_deposits(deposits) or not _load_buildings(buildings) or not _load_trees(trees) or not _load_fields(fields):
		return false
	# Buildings must already block their cells before diagonal flank validation.
	if not _load_trail_links(data, saved_tick):
		return false
	if not _load_workers(workers):
		return false
	if _version >= 4 and next_id <= _highest_id:
		return false
	_world._next_entity_id = maxi(next_id, _highest_id + 1)
	_world.tick = saved_tick
	# A reload must not get an extra decay scan inside the already processed
	# scan interval. Restore its clock without aging trails or creating traffic.
	_world.grid.restore_trail_clock(saved_tick)
	_world.economy_enabled = economy_enabled if _version >= 7 else false
	for worker: Dictionary in _world.workers.values():
		if int(worker["meal_ticks_left"]) > 0:
			# The current serving was already withdrawn. Continue its saved
			# nutrition curve on the next tick, without feeding during loading.
			worker["state"] = "working"
			worker["action"] = "eat"
			worker["destination_id"] = int(worker["inside_building_id"])
		elif _world.is_night_rest_time() and _world.follows_daily_schedule(worker):
			# Keep loading observational: choosing a bedroom, collecting cargo,
			# cancelling food missions and moving home belong to the next tick.
			# In particular, resuming cargo at its warehouse door could otherwise
			# unload a sleeping carrier as a zero-length path side effect.
			if int(worker["sleep_home_id"]) != 0 and int(worker["inside_building_id"]) == int(worker["sleep_home_id"]):
				worker["state"] = "sleeping"
		elif not (worker["ration_delivery"] as Dictionary).is_empty():
			# Resume on the next simulation tick, never consume/hand over a
			# ration as a side effect of loading a zero-length path.
			continue
		elif not String(worker["carrying"]).is_empty():
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
	if _version >= 8:
		return _load_heights(terrain.get("corner_heights"))
	return true


func _load_heights(value: Variant) -> bool:
	var rows: Array = _read_array(value)
	if not _valid or rows.size() != _world.grid.size.y + 1:
		return false
	for y: int in range(rows.size()):
		var row: Array = _read_array(rows[y])
		if not _valid or row.size() != _world.grid.size.x + 1:
			return false
		for x: int in range(row.size()):
			var height: int = _read_integer(row[x], 0, GridMapSimClass.MAX_HEIGHT)
			if not _valid or not _world.grid.set_vertex_height(Vector2i(x, y), height):
				return false
	return true


func _load_surfaces(data: Dictionary, saved_tick: int) -> bool:
	# Trails were introduced in v2; v1 legitimately has neither trail field.
	var roads: Array = _read_array(data.get("roads"))
	var trails: Array = _read_array(data.get("dirt_trails", [] if _version == 1 else null))
	var wear: Array = _read_array(data.get("traffic_wear", [] if _version == 1 else null))
	if not _valid:
		return false
	var seen: Dictionary = {}
	var mature: Dictionary = {}
	for raw_cell: Variant in roads:
		var cell: Vector2i = _read_cell(raw_cell)
		if not _valid or seen.has(cell) or not _world.grid.add_road(cell):
			return false
		seen[cell] = true
	for raw_cell: Variant in trails:
		var cell: Vector2i = _read_cell(raw_cell)
		if not _valid or seen.has(cell) or not _world.grid.is_walkable(cell) or not _world.grid.is_roadable(cell):
			return false
		seen[cell] = true
		mature[cell] = true
	var seen_wear: Dictionary = {}
	var wear_limit: int = _world.grid.carrier_passes_to_form_trail()
	for raw_wear: Variant in wear:
		var entry: Array = _read_array(raw_wear)
		if not _valid or entry.size() != 3:
			return false
		var cell: Vector2i = _read_cell([entry[0], entry[1]])
		var passes: int = _read_integer(entry[2], 1 if _version >= 11 else 0, wear_limit if _version >= 11 else MAX_SAFE_INTEGER)
		if (
			not _valid or seen_wear.has(cell) or _world.grid.roads.has(cell)
			or not _world.grid.is_walkable(cell) or not _world.grid.is_roadable(cell)
		):
			return false
		seen_wear[cell] = passes
	if _version < 11:
		# Old snapshots know mature tiles, not travel directions or aging. Keep
		# their existing trails mature; retain weak tracks without free promotion.
		# The new decay clock starts at the saved tick, never at process startup.
		for cell: Vector2i in mature:
			if not _world.grid.set_trail_state(cell, wear_limit, saved_tick, true):
				return false
		for cell: Vector2i in seen_wear:
			if not mature.has(cell) and int(seen_wear[cell]) > 0:
				if not _world.grid.set_trail_state(cell, mini(int(seen_wear[cell]), wear_limit - 1), saved_tick, false):
					return false
		return true
	var ages: Array = _read_array(data.get("trail_last_decay"))
	var seen_age: Dictionary = {}
	for raw_age: Variant in ages:
		var entry: Array = _read_array(raw_age)
		if not _valid or entry.size() != 3:
			return false
		var cell: Vector2i = _read_cell([entry[0], entry[1]])
		var decay_tick: int = _read_integer(entry[2], 0, saved_tick)
		if not _valid or seen_age.has(cell) or not seen_wear.has(cell):
			return false
		seen_age[cell] = decay_tick
	if not _valid or seen_age.size() != seen_wear.size():
		return false
	for cell: Vector2i in mature:
		if not seen_wear.has(cell):
			return false
	for cell: Vector2i in seen_wear:
		# This strict setter restores exactly the recorded state. Authoring
		# add_dirt_trail would fabricate adjacent links and reset its decay clock.
		if not _world.grid.set_trail_state(cell, int(seen_wear[cell]), int(seen_age[cell]), mature.has(cell)):
			return false
	return true


func _load_trail_links(data: Dictionary, saved_tick: int) -> bool:
	if _version < 11:
		# Historical saves contain no direction evidence. Reconstruct only their
		# already-visible legal mature-trail/stone joins; this cannot recover which
		# exact routes were walked. Unused reconstructed joins subsequently decay.
		var established_cells: Dictionary = _world.grid.roads.duplicate()
		established_cells.merge(_world.grid.dirt_trails)
		for from: Vector2i in _sorted_cells(established_cells.keys()):
			for to: Vector2i in _world.grid.neighbors8(from):
				if not established_cells.has(to) or (_world.grid.roads.has(from) and _world.grid.roads.has(to)):
					continue
				var key: Vector4i = _world.grid.trail_link_key(from, to)
				if key != Vector4i(from.x, from.y, to.x, to.y):
					continue
				if not _world.grid.set_trail_link(from, to, _world.grid.carrier_passes_to_form_trail(), saved_tick, true):
					return false
		return true
	var links: Array = _read_array(data.get("trail_links"))
	var seen: Dictionary = {}
	for raw_link: Variant in links:
		var entry: Array = _read_array(raw_link)
		if not _valid or entry.size() != 7:
			return false
		var from: Vector2i = _read_cell([entry[0], entry[1]])
		var to: Vector2i = _read_cell([entry[2], entry[3]])
		var wear: int = _read_integer(entry[4], 1, _world.grid.carrier_passes_to_form_trail())
		var decay_tick: int = _read_integer(entry[5], 0, saved_tick)
		var established: bool = _read_bool(entry[6])
		var key: Vector4i = _world.grid.trail_link_key(from, to)
		if not _valid or key != Vector4i(from.x, from.y, to.x, to.y) or seen.has(key):
			return false
		if _deposit_at(from) or _deposit_at(to) or _world.field_id_at(from) != 0 or _world.field_id_at(to) != 0:
			return false
		if not _world.grid.set_trail_link(from, to, wear, decay_tick, established):
			return false
		seen[key] = true
	return _valid


func _load_deposits(saved_deposits: Array) -> bool:
	var cells: Dictionary = {}
	for value: Variant in saved_deposits:
		var saved: Dictionary = _read_dictionary(value)
		var entity_id: int = _read_entity_id(saved.get("id"))
		var position: Vector2i = _read_cell(saved.get("position"))
		var resource: String = _read_string(saved.get("resource"))
		var amount: int = _read_integer(saved.get("amount"))
		if not _valid or cells.has(position) or not ["stone", "iron_ore", "coal", "gold_ore", "fish"].has(resource) or not _world.catalog.resources.has(resource):
			return false
		if not _world.grid.overlay_at(position).is_empty():
			return false
		cells[position] = true
		# Authoring validates natural terrain. Saves retain authored deposits and
		# exhausted sites even if future map tools change their surrounding ground.
		if _version >= 7:
			_world.deposits[entity_id] = {"id": entity_id, "position": position, "resource": resource, "amount": amount}
	return true


func _deposit_at(cell: Vector2i) -> bool:
	for deposit: Dictionary in _world.deposits.values():
		if deposit["position"] == cell:
			return true
	return false


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
		var recipes: Array[String] = _building_recipes(definition)
		var default_recipe: String = String(definition.get("recipe", recipes[0] if not recipes.is_empty() else ""))
		var recipe_id: String = _read_string(saved.get("recipe_id", default_recipe if _version < 7 else null))
		if not recipe_id.is_empty() and not recipes.has(recipe_id):
			return false
		var recipe: Dictionary = _world.catalog.recipe(recipe_id)
		var process_limit: int = maxi(0, int(recipe.get("duration_ticks", 0)))
		if _version < 7 and type == "quarry":
			process_limit = 100
		var process_remaining: int = _read_integer(saved.get("process_remaining"), 0, process_limit)
		var construction_limit: int = maxi(0, int(definition.get("construction_ticks", 120)))
		var construction_remaining: int = _read_integer(saved.get("construction_remaining", 0 if _version < 7 else null), 0, construction_limit)
		# Costs are versioned independently from the live catalog. Old completed
		# buildings also retain delivered material records, so migrate all of them.
		var construction_revision: int = 1 if _version < 9 else _read_integer(saved.get("construction_cost_revision"), 1, _world.catalog.CONSTRUCTION_COST_REVISION)
		var construction_cost: Dictionary = _world.catalog.construction_cost(type, construction_revision)
		var construction_delivered: Dictionary = _read_construction_inventory(saved.get("construction_delivered", {} if _version < 7 else null), construction_cost)
		var production_queue: Array[String] = _read_production_queue(saved.get("production_queue", [] if _version < 7 else null), recipes)
		var order_active: bool = _read_bool(saved.get("order_active", false if _version < 7 else null))
		var service_queue: Array[Dictionary] = _read_service_queue(saved.get("service_queue", [] if _version < 7 else null), type)
		if order_active and (production_queue.is_empty() or production_queue[0] != recipe_id or process_remaining == 0):
			return false
		var extraction: bool = not String(definition.get("extract_resource", "")).is_empty()
		if (
			not _valid or definition.is_empty() or not _world.grid.is_buildable(position)
			or (not extraction and not _world._building_terrain_valid(type, position))
			or _deposit_at(position) or _deposit_at(entrance)
			or entrances.has(position) or not _world.grid.can_use_building_exit(position, entrance)
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
		var training_paid: bool = _read_bool(saved.get("training_paid", false if _version < 7 else null))
		if not _valid or (training_paid and training_queue.is_empty()):
			return false
		if _version < 7 and type == "quarry" and process_remaining > 0:
			# Old quarries had already started an automatic one-stone batch. Finish
			# that single batch once while migrating to finite physical extraction.
			outputs["stone"] = int(outputs.get("stone", 0)) + 1
			process_remaining = 0
		_world.buildings[entity_id] = {
			"id": entity_id, "type": type, "position": position, "entrance": entrance,
			"storage": storage, "inputs": inputs, "outputs": outputs,
			"process_remaining": process_remaining,
			"training_queue": training_queue, "training_remaining": training_remaining,
			"training_paid": training_paid,
			"recipe_id": recipe_id, "construction_remaining": construction_remaining,
			"construction_cost_revision": construction_revision,
			"construction_delivered": construction_delivered, "production_queue": production_queue,
			"order_active": order_active, "service_queue": service_queue,
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
		if not _valid or cells.has(position) or _deposit_at(position) or not _world.grid.allows_trees(position):
			return false
		cells[position] = true
		_world.trees[entity_id] = {"id": entity_id, "position": position, "amount": amount, "age_ticks": age}
	return true


func _load_fields(saved_fields: Array) -> bool:
	var cells: Dictionary = {}
	var entrances: Dictionary = {}
	for building: Dictionary in _world.buildings.values():
		entrances[building["entrance"]] = true
	var tree_cells: Dictionary = {}
	for tree: Dictionary in _world.trees.values():
		tree_cells[tree["position"]] = true
	for value: Variant in saved_fields:
		var saved: Dictionary = _read_dictionary(value)
		var entity_id: int = _read_entity_id(saved.get("id"))
		var position: Vector2i = _read_cell(saved.get("position"))
		var kind: String = _read_string(saved.get("kind", "wheat" if _version < 7 else null))
		var growth_limit: int = int(_world.catalog.economy.get("vine_growth_ticks", 160)) if kind == "vine" and _version >= 7 else int(_world.catalog.economy.get("wheat_growth_ticks", _world.FIELD_MATURE_AGE_TICKS))
		var age: int = _read_integer(saved.get("age_ticks"), -1, growth_limit)
		if (
			not _valid or not ["wheat", "vine"].has(kind) or cells.has(position) or entrances.has(position) or tree_cells.has(position)
			or _deposit_at(position)
			or not _world.grid.is_buildable(position)
			or not ["grass", "dirt"].has(_world.grid.base_terrain_at(position))
			or not _world.grid.overlay_at(position).is_empty()
			or _world.grid.traffic_wear_at(position) != 0
		):
			return false
		cells[position] = true
		# Earlier schemas did not contain fields. Validate any supplied extension,
		# but migrate their field state to empty instead of inventing legacy crops.
		if _version >= 6:
			_world.fields[entity_id] = {"id": entity_id, "position": position, "age_ticks": age, "kind": kind if _version >= 7 else "wheat"}
	return true


func _load_workers(saved_workers: Array) -> bool:
	var normalized: Array[Dictionary] = []
	var claimed_homes: Dictionary = {}
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
		var sleep_home_id: int = _read_integer(saved.get("sleep_home_id") if _version >= 15 else 0)
		# Older schemas place everyone outdoors. V12 persists an actual visit,
		# independently from the worker's permanent workplace ownership.
		var inside_id: int = _read_integer(saved.get("inside_building_id") if _version >= 12 else 0)
		var indoor_wait: int = _read_integer(saved.get("indoor_wait_ticks") if _version >= 12 else 0, 0, MAX_INDOOR_WAIT_TICKS)
		var carrying: String = _read_string(saved.get("carrying"))
		var cooldown: int = _read_integer(saved.get("planting_cooldown", 0 if _version < 5 else null))
		var hunger: int = _read_integer(saved.get("hunger", int(_world.catalog.economy.get("condition_initial", 1620)) if _version < 7 else null), 0, int(_world.catalog.economy.get("condition_max", 2700)))
		var meal_limit: int = maxi(1, int(_world.catalog.building("inn").get("meal_duration_ticks", 116))) \
			* maxi(1, int(_world.catalog.economy.get("max_meals_per_visit", 2)))
		var meal_ticks: int = _read_integer(saved.get("meal_ticks_left") if _version >= 13 else 0, 0, meal_limit)
		var meal_course: Dictionary = _read_dictionary(saved.get("meal_course") if _version >= 14 else {})
		var food_requested: bool = _read_bool(saved.get("food_requested") if _version >= 13 else false)
		var ration: Dictionary = _read_dictionary(saved.get("ration_delivery") if _version >= 13 else {})
		var unit_definition: Dictionary = _unit_definition(type)
		if (
			not _valid or unit_definition.is_empty()
			or (not carrying.is_empty() and not _world.catalog.resources.has(carrying))
		):
			return false
		if not carrying.is_empty() and not _can_carry(type, unit_definition, carrying):
			return false
		if inside_id == 0:
			if indoor_wait != 0:
				return false
		else:
			var inside: Dictionary = _world.buildings.get(inside_id, {})
			if inside.is_empty() or not _world.is_building_complete(inside) or position != inside["entrance"]:
				return false
		if home_id != 0:
			# Validate old references before migration: an unknown or wrong-type
			# building is corruption, not an invitation to silently lose a claim.
			var home_types: Array = unit_definition.get("home_buildings", [])
			if _version < 10 and type == "carrier":
				home_types = home_types.duplicate()
				home_types.append("lumber_hut")
			if (
				not _world.buildings.has(home_id)
				or not home_types.has(String(_world.buildings[home_id]["type"]))
			):
				return false
			var valid_claim: bool = (
				WorkplacesClass.profession(_world, home_id) == type
				and _world.is_building_complete(_world.buildings[home_id])
				and not claimed_homes.has(home_id)
				and (carrying.is_empty() or (
					_world.catalog.building(String(_world.buildings[home_id]["type"])).get("outputs", []) as Array
				).has(carrying))
			)
			if not valid_claim:
				if _version >= 10:
					return false
				# Older games allowed shared homes and temporary work sites. Keep
				# the first compatible owner by ID; surplus citizens and all their
				# wares survive and can seek a free workplace on the next tick.
				# A multi-building profession may also be carrying a different
				# home's output; release that old temporary claim, not the cargo.
				home_id = 0
			else:
				claimed_homes[home_id] = entity_id
		# Reuse defaults, but suppress auto-assignment while restoring. An early
		# unassigned citizen must never steal a later saved owner's workplace.
		_world._next_entity_id = entity_id
		if _world.spawn_worker(position, type, home_id, false, inside_id) == 0:
			return false
		_world.workers[entity_id]["sleep_home_id"] = sleep_home_id
		_world.workers[entity_id]["indoor_wait_ticks"] = indoor_wait
		_world.workers[entity_id]["carrying"] = carrying
		_world.workers[entity_id]["planting_cooldown"] = cooldown
		_world.workers[entity_id]["hunger"] = hunger
		_world.workers[entity_id]["meal_ticks_left"] = meal_ticks
		_world.workers[entity_id]["meal_course"] = meal_course.duplicate(true)
		_world.workers[entity_id]["food_requested"] = food_requested
		_world.workers[entity_id]["ration_delivery"] = ration.duplicate(true)
	return _validate_sleep_homes() and _validate_feeding()


func _validate_sleep_homes() -> bool:
	for worker: Dictionary in _world.workers.values():
		var sleep_home_id: int = int(worker["sleep_home_id"])
		if sleep_home_id == 0:
			continue
		var bedroom: Dictionary = _world.buildings.get(sleep_home_id, {})
		if not _world.follows_daily_schedule(worker) or bedroom.is_empty() or not _world.is_building_complete(bedroom):
			return false
		var workplace: int = int(worker["home_id"])
		if _world.owns_workplace(worker, workplace):
			if sleep_home_id != workplace:
				return false
		elif bedroom["type"] != "warehouse":
			return false
	return true


func _validate_feeding() -> bool:
	var recipients: Dictionary = {}
	var source_reservations: Dictionary = {}
	var seats: Dictionary = {}
	for worker: Dictionary in _world.workers.values():
		var soldier: bool = _world.catalog.soldiers.has(String(worker["type"]))
		if bool(worker["food_requested"]) and not soldier:
			return false
		if not _validate_meal_course(worker):
			return false
		if int(worker["meal_ticks_left"]) > 0:
			var inside: int = int(worker["inside_building_id"])
			if soldier or inside == 0 or _world.buildings[inside]["type"] != "inn" \
					or int(worker["indoor_wait_ticks"]) != 0:
				return false
			# Off-duty civilians keep their physical cargo through a meal. The
			# meal may legitimately remain in progress after the clock hits dawn.
			if not String(worker["carrying"]).is_empty() and (_version < 15 or not _world.follows_daily_schedule(worker)):
				return false
			seats[inside] = int(seats.get(inside, 0)) + 1
			if int(seats[inside]) > int(_world.catalog.building("inn").get("seating_capacity", 6)):
				return false
		var ration: Dictionary = worker["ration_delivery"]
		if ration.is_empty():
			continue
		if worker["type"] != "carrier" or int(worker["meal_ticks_left"]) > 0:
			return false
		var recipient_id: int = _read_integer(ration.get("recipient_id"), 1)
		var source_id: int = _read_integer(ration.get("source_id"), 1)
		var ware: String = _read_string(ration.get("ware"))
		var phase: String = _read_string(ration.get("phase"))
		if not _valid or not ["pickup", "deliver"].has(phase) \
				or not (_world.catalog.economy.get("food_order", []) as Array).has(ware):
			return false
		var recipient: Dictionary = _world.workers.get(recipient_id, {})
		if recipient.is_empty() or not _world.catalog.soldiers.has(String(recipient["type"])) \
				or not bool(recipient["food_requested"]) or recipients.has(recipient_id):
			return false
		recipients[recipient_id] = true
		if phase == "deliver":
			if worker["carrying"] != ware:
				return false
		else:
			if not String(worker["carrying"]).is_empty():
				return false
			var source: Dictionary = _world.buildings.get(source_id, {})
			if source.is_empty() or not _world.is_building_complete(source):
				return false
			var warehouse: bool = source["type"] == "warehouse"
			if not warehouse and not (_world.catalog.building(source["type"]).get("outputs", []) as Array).has(ware):
				return false
			var inventory: Dictionary = source["storage"] if warehouse else source["outputs"]
			var key: String = "%d:%s" % [source_id, ware]
			source_reservations[key] = int(source_reservations.get(key, 0)) + 1
			if int(source_reservations[key]) > int(inventory.get(ware, 0)):
				return false
		# Normalize integer JSON numbers without preserving arbitrary payloads.
		worker["ration_delivery"] = {"recipient_id": recipient_id, "source_id": source_id, "ware": ware, "phase": phase}
	return _valid


func _validate_meal_course(worker: Dictionary) -> bool:
	var remaining: int = int(worker["meal_ticks_left"])
	var course: Dictionary = worker["meal_course"]
	if course.is_empty():
		# V13 applied all food immediately and saved up to two waiting
		# periods. Preserve that paid countdown, including a v14 re-save.
		return remaining <= 232
	if remaining <= 0 or course.size() != 5:
		return false
	var food: String = _read_string(course.get("food"))
	var duration: int = _read_integer(course.get("duration_ticks"), 1)
	var restore: int = _read_integer(course.get("restore"), 1)
	var applied: int = _read_integer(course.get("applied"))
	var eaten: Array = _read_array(course.get("foods_eaten"))
	var menu: Array = _world.catalog.economy["food_order"]
	if not _valid or not menu.has(food) or eaten.is_empty() \
			or eaten.size() > int(_world.catalog.economy["max_meals_per_visit"]):
		return false
	if duration != int(_world.catalog.building("inn").get("meal_duration_ticks", 116)) \
			or remaining > duration or restore != int(_world.catalog.resources[food]["food_restore"]):
		return false
	@warning_ignore("integer_division")
	var expected: int = restore * (duration - remaining) / duration
	if applied != expected:
		return false
	var normalized: Array[String] = []
	for value: Variant in eaten:
		var previous_food: String = _read_string(value)
		if not _valid or not menu.has(previous_food) or normalized.has(previous_food):
			return false
		normalized.append(previous_food)
	if normalized.back() != food:
		return false
	worker["meal_course"] = {"food": food, "duration_ticks": duration,
		"restore": restore, "applied": applied, "foods_eaten": normalized}
	return true


func _unit_definition(type: String) -> Dictionary:
	var definition: Dictionary = _world.catalog.unit(type)
	return definition if not definition.is_empty() else _world.catalog.soldiers.get(type, {})


func _can_carry(type: String, definition: Dictionary, resource: String) -> bool:
	if type == "carrier":
		return true
	for building_type: String in definition.get("home_buildings", []):
		if (_world.catalog.building(building_type).get("outputs", []) as Array).has(resource):
			return true
	return false


func _building_recipes(definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var default_recipe: String = String(definition.get("recipe", ""))
	if not default_recipe.is_empty():
		result.append(default_recipe)
	for recipe_id: String in definition.get("recipes", []):
		if not result.has(recipe_id):
			result.append(recipe_id)
	return result


func _read_construction_inventory(value: Variant, cost: Dictionary) -> Dictionary:
	var raw: Dictionary = _read_dictionary(value)
	var result: Dictionary = {}
	for key: Variant in raw:
		if not key is String or not _world.catalog.resources.has(key) or not cost.has(key):
			_valid = false
			return {}
		result[key] = _read_integer(raw[key], 0, int(cost[key]))
	return result


func _read_production_queue(value: Variant, recipes: Array[String]) -> Array[String]:
	var raw: Array = _read_array(value)
	var result: Array[String] = []
	if raw.size() > 10:
		_valid = false
	for entry: Variant in raw:
		var recipe: String = _read_string(entry)
		if not recipes.has(recipe) or _world.catalog.recipe(recipe).is_empty():
			_valid = false
		result.append(recipe)
	return result


func _read_service_queue(value: Variant, building_type: String) -> Array[Dictionary]:
	var raw: Array = _read_array(value)
	var result: Array[Dictionary] = []
	if raw.size() > 10:
		_valid = false
	for entry: Variant in raw:
		var order: Dictionary = _read_dictionary(entry)
		var kind: String = _read_string(order.get("kind"))
		if kind == "recruit":
			var unit: String = _read_string(order.get("unit"))
			var soldier: Dictionary = _world.catalog.soldiers.get(unit, {})
			if soldier.is_empty() or String(soldier.get("building", "")) != building_type or order.size() != 2:
				_valid = false
			result.append({"kind": kind, "unit": unit})
		elif kind == "trade":
			var give: String = _read_string(order.get("give"))
			var receive: String = _read_string(order.get("receive"))
			if building_type != "marketplace" or not _world.catalog.resources.has(give) or not _world.catalog.resources.has(receive) or give == receive or order.size() != 3:
				_valid = false
			result.append({"kind": kind, "give": give, "receive": receive})
		else:
			_valid = false
	return result


func _read_bool(value: Variant) -> bool:
	if value is bool:
		return value
	_valid = false
	return false


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
	for resource: String in _world.catalog.resources:
		result[resource] = 0
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


static func _sorted_trail_keys(values: Array) -> Array[Vector4i]:
	var keys: Array[Vector4i] = []
	for value: Vector4i in values:
		keys.append(value)
	keys.sort_custom(func(a: Vector4i, b: Vector4i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.x != b.x:
			return a.x < b.x
		if a.w != b.w:
			return a.w < b.w
		return a.z < b.z
	)
	return keys
