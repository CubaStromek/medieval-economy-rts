class_name SimulationWorld
extends RefCounted

const DefinitionCatalogClass = preload("res://scripts/simulation/definition_catalog.gd")
const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const GridPathfinderClass = preload("res://scripts/simulation/grid_pathfinder.gd")
const TaskBoardClass = preload("res://scripts/simulation/task_board.gd")
const WorldSnapshotClass = preload("res://scripts/simulation/world_snapshot.gd")
const ResourceDepositsClass = preload("res://scripts/simulation/resource_deposits.gd")
const ClassicEconomyClass = preload("res://scripts/simulation/classic_economy.gd")
const WorkplacesClass = preload("res://scripts/simulation/workplaces.gd")
const DayCycleClass = preload("res://scripts/simulation/day_cycle.gd")
const DailyScheduleClass = preload("res://scripts/simulation/daily_schedule.gd")
const IndoorWorkersClass = preload("res://scripts/simulation/indoor_workers.gd")
const InnFeedingClass = preload("res://scripts/simulation/inn_feeding.gd")
const SoldierFoodSupplyClass = preload("res://scripts/simulation/soldier_food_supply.gd")

const DEFAULT_MAP_SIZE := Vector2i(20, 16)
const TICK_SECONDS: float = DayCycleClass.TICK_SECONDS
const LUMBERJACK_TASKS: Array[String] = ["harvest_tree"]
const FIELD_MATURE_AGE_TICKS: int = 200
const FARMER_TASKS: Array[String] = ["sow_field", "harvest_field"]
const BLOCKED_REPLAN_TICKS: int = 6
const YIELD_REST_TICKS: int = 12
const TREE_STAGE_SAPLING: int = 0
const TREE_STAGE_YOUNG: int = 1
const TREE_STAGE_MATURE: int = 2
const TREE_YOUNG_AGE_TICKS: int = 80
const TREE_MATURE_AGE_TICKS: int = 200
const SAVE_VERSION: int = WorldSnapshotClass.SAVE_VERSION
const MAX_MAP_SIZE: Vector2i = WorldSnapshotClass.MAX_MAP_SIZE

var tick: int = 0
var catalog: DefinitionCatalogClass
var grid: GridMapSimClass
var task_board: TaskBoardClass
var buildings: Dictionary = {}
var trees: Dictionary = {}
var fields: Dictionary = {}
var deposits: Dictionary = {}
# Bare worlds remain useful for authoring and historical sandbox saves. The
# playable economy demo enables material costs, paid training and food needs.
var economy_enabled: bool = false
var workers: Dictionary = {}
var tile_reservations: Dictionary = {}
var planting_reservations: Dictionary = {}
var event_log: Array[String] = []

var _next_entity_id: int = 1
var _workers_updated_this_tick: Dictionary = {}
var _workers_moved_this_tick: Dictionary = {}
# A yielding unit reserves its old tile until its visible step has cleared it.
# These short-lived movement reservations are deliberately not save data.
var _yielding_origins: Dictionary = {}


func _init(map_size: Vector2i = DEFAULT_MAP_SIZE) -> void:
	catalog = DefinitionCatalogClass.new()
	grid = GridMapSimClass.new(map_size)
	grid.configure_movement(catalog.movement)
	task_board = TaskBoardClass.new()


func setup_demo() -> void:
	_setup_demo_terrain()
	for tree_cell: Vector2i in [
		Vector2i(7, 3), Vector2i(9, 3), Vector2i(11, 4), Vector2i(13, 3),
		Vector2i(15, 5), Vector2i(16, 7), Vector2i(14, 9), Vector2i(11, 11),
	]:
		add_tree(tree_cell, 3)

	place_building("warehouse", Vector2i(3, 8))
	var lumber_hut_id: int = place_building("lumber_hut", Vector2i(7, 8))
	place_building("sawmill", Vector2i(11, 8))
	var forester_hut_id: int = place_building("forester_hut", Vector2i(13, 8))
	spawn_worker(Vector2i(5, 10), "lumberjack", lumber_hut_id)
	spawn_worker(Vector2i(7, 10), "carrier")
	spawn_worker(Vector2i(9, 10), "gardener", forester_hut_id)
	_push_event("Workers harvest, transport, and autonomously replant the woodland.")


func calendar_time() -> Dictionary:
	return DayCycleClass.at_tick(tick)


func is_night_rest_time() -> bool:
	return DayCycleClass.is_night(tick)


func follows_daily_schedule(worker: Dictionary) -> bool:
	return DailyScheduleClass.follows(self, worker)


func can_worker_work(worker: Dictionary) -> bool:
	return not is_night_rest_time() or not follows_daily_schedule(worker)


func is_worker_sleeping(worker: Dictionary) -> bool:
	return DailyScheduleClass.sleeping(self, worker)


func worker_schedule_status(worker: Dictionary) -> String:
	return DailyScheduleClass.status(self, worker)


func step_tick() -> void:
	tick += 1
	grid.tick_trails(tick)
	_workers_updated_this_tick.clear()
	_workers_moved_this_tick.clear()
	_update_worker_visual_progress()
	DailyScheduleClass.prepare_tick(self)
	_tick_trees()
	_tick_fields()
	ClassicEconomyClass.tick_needs(self)
	SoldierFoodSupplyClass.tick(self)
	_tick_buildings()
	_generate_tasks()
	var worker_ids: Array = workers.keys()
	worker_ids.sort()
	for worker_id_variant: Variant in worker_ids:
		var worker_id: int = int(worker_id_variant)
		if _workers_updated_this_tick.has(worker_id):
			continue
		_workers_updated_this_tick[worker_id] = true
		_tick_worker(worker_id)


func add_tree(cell: Vector2i, amount: int = 3) -> int:
	if not grid.allows_trees(cell) or _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0:
		return 0
	return _create_tree(cell, amount, TREE_MATURE_AGE_TICKS)


func can_plant_sapling(cell: Vector2i) -> bool:
	return _can_plant_sapling(cell, 0)


func tree_growth_stage(tree: Dictionary) -> int:
	var age_ticks: int = int(tree.get("age_ticks", TREE_MATURE_AGE_TICKS))
	if age_ticks < TREE_YOUNG_AGE_TICKS:
		return TREE_STAGE_SAPLING
	if age_ticks < TREE_MATURE_AGE_TICKS:
		return TREE_STAGE_YOUNG
	return TREE_STAGE_MATURE


func is_tree_mature(tree: Dictionary) -> bool:
	return tree_growth_stage(tree) == TREE_STAGE_MATURE


func _create_tree(cell: Vector2i, amount: int, age_ticks: int) -> int:
	var entity_id: int = _take_entity_id()
	trees[entity_id] = {
		"id": entity_id,
		"position": cell,
		"amount": maxi(1, amount),
		"age_ticks": clampi(age_ticks, 0, TREE_MATURE_AGE_TICKS),
	}
	return entity_id


func spawn_worker(cell: Vector2i, unit_type: String = "carrier", home_id: int = 0, assign_home: bool = true, inside_building_id: int = 0) -> int:
	if (
		catalog.unit(unit_type).is_empty()
		or not grid.is_walkable(cell)
		or inside_building_id < 0
		or (inside_building_id == 0 and (tile_reservations.has(cell) or planting_reservations.has(cell)))
		or (inside_building_id != 0 and not IndoorWorkersClass.valid_location(self, cell, inside_building_id))
	):
		return 0
	if home_id != 0 and not WorkplacesClass.can_claim(self,
		{"id": _next_entity_id, "type": unit_type, "home_id": 0, "carrying": ""}, home_id):
		return 0
	var entity_id: int = _take_entity_id()
	workers[entity_id] = {
		"id": entity_id,
		"type": unit_type,
		"home_id": home_id,
		"sleep_home_id": 0,
		"inside_building_id": inside_building_id,
		"indoor_wait_ticks": 0,
		"position": cell,
		"previous_position": cell,
		"state": "idle",
		"action": "",
		"task_id": 0,
		"source_id": 0,
		"destination_id": 0,
		"carrying": "",
		"path": [],
		"path_index": 0,
		"move_cooldown": 0,
		"work_remaining": 0,
		"visual_progress_ticks": 1,
		"visual_duration_ticks": 1,
		"blocked_ticks": 0,
		"target_cell": cell,
		"plant_target": Vector2i(-1, -1),
		"planting_cooldown": 0,
		"hunger": int(catalog.economy.get("condition_initial", 1620)),
		"meal_ticks_left": 0,
		"meal_course": {},
		"food_requested": false,
		"ration_delivery": {},
	}
	if inside_building_id == 0:
		tile_reservations[cell] = entity_id
	if assign_home:
		ensure_workplace(workers[entity_id])
	return entity_id


func is_worker_inside(worker: Dictionary) -> bool:
	return IndoorWorkersClass.is_inside(worker)


func request_soldier_food(unit_id: int) -> bool:
	return SoldierFoodSupplyClass.request_food(self, unit_id)


func request_army_food() -> int:
	var requested: int = 0
	var ids: Array = workers.keys()
	ids.sort()
	for id: int in ids:
		if request_soldier_food(id):
			requested += 1
	if requested > 0:
		_push_event("Food requested for %d soldiers. Carriers will deliver one ration each." % requested)
	return requested


func soldier_food_status(unit_id: int) -> String:
	return SoldierFoodSupplyClass.status(self, unit_id)


func inn_occupied_seats(inn_id: int) -> int:
	return InnFeedingClass.occupied_seats(self, inn_id)


func hunger_loss_per_interval() -> int:
	var maximum: int = maxi(1, int(catalog.economy.get("condition_max", 2700)))
	var hungry: int = clampi(int(catalog.economy.get("condition_hungry", 360)), 0, maximum)
	var interval: int = maxi(1, int(catalog.economy.get("condition_interval_ticks", 10)))
	var day_fraction: float = maxf(0.001, float(catalog.economy.get("condition_daily_hunger_fraction", 0.8)))
	# Hunger shares the saved simulation calendar, so speed and pause change
	# real waiting time without changing how often citizens need food per day.
	return maxi(1, ceili(float((maximum - hungry) * interval) / (float(DayCycleClass.TICKS_PER_DAY) * day_fraction)))


func hunger_status(worker: Dictionary) -> Dictionary:
	var maximum: int = maxi(1, int(catalog.economy.get("condition_max", 2700)))
	var condition: int = clampi(int(worker.get("hunger", 0)), 0, maximum)
	var hungry: int = clampi(int(catalog.economy.get("condition_hungry", 360)), 0, maximum)
	var warning: int = clampi(int(catalog.economy.get("condition_warning", 1350)), hungry, maximum)
	var critical: int = clampi(int(catalog.economy.get("condition_critical", 120)), 0, hungry)
	var state: String = "Fed"
	if condition <= critical:
		state = "Starving"
	elif condition <= hungry:
		state = "Hungry"
	elif condition <= warning:
		state = "Getting hungry"
	var interval: int = maxi(1, int(catalog.economy.get("condition_interval_ticks", 10)))
	var loss: int = hunger_loss_per_interval()
	# tick describes an already completed step. At an exact boundary the next
	# loss is one full interval away, rather than an immediate second loss.
	var next_loss_ticks: int = interval - tick % interval
	var hungry_intervals: int = ceili(float(maxi(0, condition - hungry)) / float(loss))
	var starve_intervals: int = ceili(float(condition) / float(loss))
	var hungry_ticks: int = 0 if hungry_intervals == 0 else next_loss_ticks + (hungry_intervals - 1) * interval
	var starve_ticks: int = 0 if starve_intervals == 0 else next_loss_ticks + (starve_intervals - 1) * interval
	# During a meal the next serving can change condition again. A negative
	# estimate means there is no active countdown to present to the player.
	if not economy_enabled or int(worker.get("meal_ticks_left", 0)) > 0:
		if hungry_ticks > 0:
			hungry_ticks = -1
		if starve_ticks > 0:
			starve_ticks = -1
	return {
		"satiety_percent": 100.0 * float(condition) / float(maximum),
		"state": state,
		"hungry_at": hungry,
		"remaining_to_hungry_ticks": hungry_ticks,
		"remaining_to_starve_ticks": starve_ticks,
	}


func _enter_worker_building(worker: Dictionary, building_id: int, dwell_ticks: int = 0) -> bool:
	return IndoorWorkersClass.enter(self, worker, building_id, dwell_ticks)


func _try_exit_worker_building(worker: Dictionary) -> bool:
	return IndoorWorkersClass.leave(self, worker)


func _release_worker_tile(worker: Dictionary) -> void:
	var cell: Vector2i = worker["position"]
	if int(tile_reservations.get(cell, 0)) == int(worker["id"]):
		tile_reservations.erase(cell)


func workplace_worker(building_id: int) -> Dictionary:
	return WorkplacesClass.occupant(self, building_id)


func ensure_workplace(worker: Dictionary) -> int:
	return WorkplacesClass.ensure(self, worker)


func owns_workplace(worker: Dictionary, building_id: int) -> bool:
	if building_id == 0 or int(worker.get("home_id", 0)) != building_id:
		return false
	var owner: Dictionary = workplace_worker(building_id)
	return not owner.is_empty() and int(owner["id"]) == int(worker["id"])


func can_place_building(building_type: String, cell: Vector2i) -> bool:
	if catalog.building(building_type).is_empty() or not grid.is_buildable(cell) or not _building_terrain_valid(building_type, cell):
		return false
	if _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	for building_variant: Variant in buildings.values():
		var existing_building: Dictionary = building_variant as Dictionary
		if existing_building["entrance"] as Vector2i == cell:
			return false
	return _find_entrance(cell) != Vector2i(-1, -1) and ResourceDepositsClass.placement_valid(self, building_type, cell)


func place_building(building_type: String, cell: Vector2i) -> int:
	if not can_place_building(building_type, cell):
		return 0
	var entrance: Vector2i = _find_entrance(cell)
	var entity_id: int = _take_entity_id()
	buildings[entity_id] = {
		"id": entity_id,
		"type": building_type,
		"position": cell,
		"entrance": entrance,
		"storage": _empty_inventory(),
		"inputs": _empty_inventory(),
		"outputs": _empty_inventory(),
		"process_remaining": 0,
		"training_queue": [],
		"training_remaining": 0,
		"training_paid": false,
		"construction_remaining": int(catalog.building(building_type).get("construction_ticks", 120)) if economy_enabled else 0,
		"construction_delivered": {},
		"construction_cost_revision": DefinitionCatalogClass.CONSTRUCTION_COST_REVISION,
		"recipe_id": String(catalog.building(building_type).get("recipe", "")),
		"production_queue": [],
		"order_active": false,
		"service_queue": [],
	}
	grid.block(cell, entity_id)
	_push_event("Built %s." % String(catalog.building(building_type).get("display_name", building_type)))
	return entity_id


func construction_cost(building: Dictionary) -> Dictionary:
	return catalog.construction_cost(String(building["type"]), int(building.get("construction_cost_revision", DefinitionCatalogClass.CONSTRUCTION_COST_REVISION)))


func cancel_construction(building_id: int) -> bool:
	var building: Dictionary = buildings.get(building_id, {})
	if building.is_empty() or is_building_complete(building):
		return false
	var refund: Dictionary = {}
	for inventory_key: String in ["construction_delivered", "storage", "inputs", "outputs"]:
		var inventory: Dictionary = building.get(inventory_key, {})
		for resource: String in inventory:
			if int(inventory[resource]) > 0:
				refund[resource] = int(refund.get(resource, 0)) + int(inventory[resource])
	# Plan every transfer before touching the site or its workers. A full or
	# disconnected warehouse must never turn cancellation into lost materials.
	var transfers: Array[Dictionary] = _construction_refund_plan(refund, building["entrance"])
	if not refund.is_empty() and transfers.is_empty():
		_push_event("Cannot cancel construction: reachable completed warehouses need room for the returned materials.")
		return false
	for transfer: Dictionary in transfers:
		var storage: Dictionary = buildings[int(transfer["warehouse_id"])]["storage"]
		var resource: String = String(transfer["resource"])
		storage[resource] = int(storage.get(resource, 0)) + int(transfer["amount"])
	var cancelled_tasks: Array[int] = task_board.cancel_tasks_for_source(building_id)
	var reroute_workers: Array[Dictionary] = []
	for worker: Dictionary in workers.values():
		if int(worker["home_id"]) == building_id:
			worker["home_id"] = 0
		if int(worker.get("sleep_home_id", 0)) == building_id:
			worker["sleep_home_id"] = 0
		if int(worker["source_id"]) == building_id or int(worker["destination_id"]) == building_id or cancelled_tasks.has(int(worker["task_id"])):
			_release_worker_task(worker)
			if not String(worker["carrying"]).is_empty():
				reroute_workers.append(worker)
	buildings.erase(building_id)
	grid.unblock(building["position"])
	# Reset all former destinations first so incoming-ware reservations cannot
	# point at the removed site while carriers choose their replacement routes.
	for worker: Dictionary in reroute_workers:
		_resume_carried_ware(worker)
	_push_event("Construction cancelled: %s. Materials returned; carriers redirected." % String(catalog.building(building["type"]).get("display_name", building["type"])))
	return true


func _construction_refund_plan(refund: Dictionary, from_cell: Vector2i) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for id: int in buildings:
		var warehouse: Dictionary = buildings[id]
		if warehouse["type"] != "warehouse" or not is_building_complete(warehouse):
			continue
		var entrance: Vector2i = warehouse["entrance"]
		var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, from_cell, entrance)
		if from_cell != entrance and path.is_empty():
			continue
		candidates.append({"id": id, "cost": GridPathfinderClass.path_cost(grid, path, from_cell)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["cost"]) < int(b["cost"]) or (int(a["cost"]) == int(b["cost"]) and int(a["id"]) < int(b["id"]))
	)
	var transfers: Array[Dictionary] = []
	for resource: String in refund:
		var remaining: int = int(refund[resource])
		for candidate: Dictionary in candidates:
			var warehouse_id: int = int(candidate["id"])
			var amount: int = mini(remaining, _warehouse_room(buildings[warehouse_id], resource))
			if amount <= 0:
				continue
			transfers.append({"warehouse_id": warehouse_id, "resource": resource, "amount": amount})
			remaining -= amount
			if remaining == 0:
				break
		if remaining > 0:
			return []
	return transfers


func place_road(cell: Vector2i) -> bool:
	if _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	if not grid.is_roadable(cell) or not grid.is_walkable(cell) or grid.roads.has(cell):
		return false
	if economy_enabled and not ClassicEconomyClass.pay_from_warehouses(self, catalog.economy.get("road_cost", {"stone": 1})):
		return false
	return grid.add_road(cell)


func set_base_terrain(cell: Vector2i, terrain_id: String) -> bool:
	# Authoring commands must guard entity layers that GridMapSim intentionally
	# does not own. Loading and initial map setup may use the grid setter before
	# entities exist.
	if _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	for building_variant: Variant in buildings.values():
		var building: Dictionary = building_variant as Dictionary
		if (building["entrance"] as Vector2i) == cell:
			return false
		if not _building_terrain_valid(String(building["type"]), building["position"], cell, terrain_id):
			return false
	return grid.set_base_terrain(cell, terrain_id)


func set_vertex_height(vertex: Vector2i, height: int) -> bool:
	# Live editing must not move foundations, workers, crop sites or reserved
	# interactions beneath existing entities. Initial terrain uses the grid API.
	if not grid.contains_vertex(vertex) or height < 0 or height > GridMapSimClass.MAX_HEIGHT:
		return false
	if grid.vertex_height(vertex) == height:
		return true
	var affected: Array[Vector2i] = grid.cells_touching_vertex(vertex)
	for cell: Vector2i in affected:
		if grid.blocked_by.has(cell) or tile_reservations.has(cell) or planting_reservations.has(cell):
			return false
		if _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0:
			return false
	for building: Dictionary in buildings.values():
		if affected.has(building["entrance"]):
			return false
	for worker: Dictionary in workers.values():
		if int(worker.get("visual_progress_ticks", 1)) < int(worker.get("visual_duration_ticks", 1)):
			if affected.has(worker["previous_position"]):
				return false
	return grid.set_vertex_height(vertex, height)


func stored_amount(resource_id: String) -> int:
	var total: int = 0
	for building_variant: Variant in buildings.values():
		var building: Dictionary = building_variant as Dictionary
		if String(building["type"]) == "warehouse" and is_building_complete(building):
			var storage: Dictionary = building["storage"] as Dictionary
			total += int(storage.get(resource_id, 0))
	return total


func pipeline_amount(resource_id: String) -> int:
	var total: int = 0
	for worker_variant: Variant in workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		if String(worker["carrying"]) == resource_id:
			total += 1
	for building_variant: Variant in buildings.values():
		var building: Dictionary = building_variant as Dictionary
		var inputs: Dictionary = building["inputs"] as Dictionary
		var outputs: Dictionary = building["outputs"] as Dictionary
		total += int(inputs.get(resource_id, 0)) + int(outputs.get(resource_id, 0))
	return total


func resource_stock(resource_id: String) -> Dictionary:
	# Existing wares across the settlement. Construction deliveries and recipe
	# inputs already consumed by production are committed, not stock on hand.
	var warehouse: int = stored_amount(resource_id)
	var building_stock: int = 0
	var carried: int = 0
	for building: Dictionary in buildings.values():
		building_stock += int(building["inputs"].get(resource_id, 0))
		building_stock += int(building["outputs"].get(resource_id, 0))
	for worker: Dictionary in workers.values():
		if String(worker["carrying"]) == resource_id:
			carried += 1
	return {
		"warehouse": warehouse,
		"buildings": building_stock,
		"carried": carried,
		"total": warehouse + building_stock + carried,
	}


func has_building(building_type: String) -> bool:
	return _first_building(building_type) != 0


func building_id_at(cell: Vector2i) -> int:
	var building_ids: Array = buildings.keys()
	building_ids.sort()
	for building_id_variant: Variant in building_ids:
		var building_id: int = int(building_id_variant)
		var building: Dictionary = buildings[building_id] as Dictionary
		if building["position"] as Vector2i == cell:
			return building_id
	return 0


func queue_unit_training(building_id: int, unit_type: String) -> bool:
	if not buildings.has(building_id) or not is_building_complete(buildings[building_id]):
		return false
	var unit_definition: Dictionary = catalog.unit(unit_type)
	if unit_definition.is_empty():
		return false
	var building: Dictionary = buildings[building_id] as Dictionary
	var building_definition: Dictionary = catalog.building(String(building["type"]))
	var trainable_units: Array = building_definition.get("trains", []) as Array
	if not trainable_units.has(unit_type):
		return false
	var training_queue: Array = building.get("training_queue", []) as Array
	var queue_capacity: int = maxi(1, int(building_definition.get("queue_capacity", 1)))
	if training_queue.size() >= queue_capacity:
		return false
	training_queue.append(unit_type)
	building["training_queue"] = training_queue
	if training_queue.size() == 1:
		building["training_remaining"] = _training_ticks_for(unit_type)
	_push_event(
		"Queued %s at %s." % [
			String(unit_definition.get("display_name", unit_type)),
			String(building_definition.get("display_name", building["type"])),
		]
	)
	return true


func to_data() -> Dictionary:
	return WorldSnapshotClass.to_data(self)


func from_data(data: Dictionary) -> bool:
	var staged_world: Variant = (get_script() as Script).new()
	staged_world.catalog = catalog
	var snapshot: Variant = WorldSnapshotClass.new()
	if not snapshot.load_into(staged_world, data):
		return false
	tick = staged_world.tick
	catalog = staged_world.catalog
	grid = staged_world.grid
	task_board = staged_world.task_board
	buildings = staged_world.buildings
	trees = staged_world.trees
	fields = staged_world.fields
	deposits = staged_world.deposits
	economy_enabled = staged_world.economy_enabled
	workers = staged_world.workers
	tile_reservations = staged_world.tile_reservations
	planting_reservations = staged_world.planting_reservations
	event_log = staged_world.event_log
	_next_entity_id = staged_world._next_entity_id
	_yielding_origins.clear()
	_workers_moved_this_tick.clear()
	return true


func _tick_trees() -> void:
	var tree_ids: Array = trees.keys()
	tree_ids.sort()
	for tree_id_variant: Variant in tree_ids:
		var tree_id: int = int(tree_id_variant)
		var tree: Dictionary = trees[tree_id] as Dictionary
		if is_tree_mature(tree):
			continue
		var previous_stage: int = tree_growth_stage(tree)
		tree["age_ticks"] = mini(
			TREE_MATURE_AGE_TICKS,
			int(tree.get("age_ticks", 0)) + 1
		)
		var current_stage: int = tree_growth_stage(tree)
		if current_stage == previous_stage:
			continue
		if current_stage == TREE_STAGE_YOUNG:
			_push_event("Sapling #%d grew into a young tree." % tree_id)
		elif current_stage == TREE_STAGE_MATURE:
			_push_event("Tree #%d matured and can now be harvested." % tree_id)


func _tick_buildings() -> void:
	var ids: Array = buildings.keys()
	ids.sort()
	for id: int in ids:
		var building: Dictionary = buildings[id]
		if not is_building_complete(building):
			ClassicEconomyClass.tick_construction(self, building)
			continue
		ClassicEconomyClass.select_next_recipe(self, building)
		var definition: Dictionary = catalog.building(String(building["type"]))
		var recipe: Dictionary = ClassicEconomyClass.recipe_for(self, building)
		if not recipe.is_empty() and not (is_night_rest_time() and String(definition.get("worker", "")) != "recruit" \
				and catalog.units.has(String(definition.get("worker", "")))):
			var operator: Dictionary = _building_operator(id)
			if String(definition.get("worker", "")).is_empty() or not operator.is_empty() or (not economy_enabled and building["type"] == "sawmill"):
				var remaining: int = int(building["process_remaining"])
				if remaining > 0:
					building["process_remaining"] = remaining - 1
					if remaining == 1:
						for resource: String in recipe["outputs"]:
							building["outputs"][resource] = int(building["outputs"].get(resource, 0)) + int(recipe["outputs"][resource])
						if bool(building["order_active"]):
							(building["production_queue"] as Array).pop_front()
							building["order_active"] = false
						if not operator.is_empty():
							task_board.complete(int(operator["task_id"]), int(operator["id"]))
							_reset_worker(operator)
				elif _recipe_ready(building):
					for resource: String in recipe["inputs"]:
						building["inputs"][resource] = int(building["inputs"].get(resource, 0)) - int(recipe["inputs"][resource])
					building["process_remaining"] = int(recipe["duration_ticks"])
					building["order_active"] = not (building["production_queue"] as Array).is_empty()
		_tick_unit_training(building)
		ClassicEconomyClass.tick_service(self, building)


func _tick_unit_training(building: Dictionary) -> void:
	var building_definition: Dictionary = catalog.building(String(building["type"]))
	if (building_definition.get("trains", []) as Array).is_empty():
		return
	var training_queue: Array = building.get("training_queue", []) as Array
	if training_queue.is_empty():
		building["training_remaining"] = 0
		return
	if economy_enabled and not bool(building["training_paid"]):
		var cost: Dictionary = building_definition.get("training_cost", {"gold": 1})
		if not ClassicEconomyClass.has_stock(building["inputs"], cost):
			return
		ClassicEconomyClass.take_stock(building["inputs"], cost)
		building["training_paid"] = true
	var remaining: int = maxi(0, int(building.get("training_remaining", 0)))
	if remaining > 0:
		remaining -= 1
		building["training_remaining"] = remaining
	if remaining > 0:
		return

	var spawn_cell: Vector2i = _find_unit_spawn_cell(building)
	if spawn_cell == Vector2i(-1, -1):
		return
	var unit_type: String = String(training_queue[0])
	if spawn_worker(spawn_cell, unit_type) == 0:
		return
	training_queue.pop_front()
	building["training_paid"] = false
	building["training_queue"] = training_queue
	building["training_remaining"] = (
		0 if training_queue.is_empty() else _training_ticks_for(String(training_queue[0]))
	)
	_push_event(
		"%s trained a %s." % [
			String(building_definition.get("display_name", building["type"])),
			String(catalog.unit(unit_type).get("display_name", unit_type)),
		]
	)


func _generate_tasks() -> void:
	if has_building("lumber_hut"):
		var tree_ids: Array = trees.keys()
		tree_ids.sort()
		for tree_id_variant: Variant in tree_ids:
			var tree_id: int = int(tree_id_variant)
			var tree: Dictionary = trees[tree_id] as Dictionary
			if int(tree["amount"]) > 0 and is_tree_mature(tree):
				task_board.create_task("harvest_tree", "tree:%d" % tree_id, tree["position"] as Vector2i, tree_id)

	_generate_economy_tasks()
	ResourceDepositsClass.generate_tasks(self)
	ClassicEconomyClass.generate_tasks(self)


func _tick_worker(worker_id: int) -> void:
	var worker: Dictionary = workers[worker_id] as Dictionary
	if InnFeedingClass.tick_worker(self, worker):
		return
	if DailyScheduleClass.handle_worker(self, worker):
		return
	if is_worker_inside(worker) and int(worker.get("indoor_wait_ticks", 0)) > 0:
		worker["indoor_wait_ticks"] = int(worker["indoor_wait_ticks"]) - 1
		return
	var state: String = String(worker["state"])
	if state == "idle":
		# A finished meal always ends with a physical exit, even if no job is
		# available. Soldiers also leave visits restored from historical saves.
		if is_worker_inside(worker) and (catalog.soldiers.has(String(worker["type"])) \
				or buildings[int(worker["inside_building_id"])]["type"] == "inn"):
			_try_exit_worker_building(worker)
			return
		if tick < int(worker.get("yield_rest_until", 0)):
			return
		# A saved committed pickup resumes before choosing a new personal visit;
		# otherwise it would retain a stock reservation while sitting at the inn.
		if not (worker.get("ration_delivery", {}) as Dictionary).is_empty() \
				and SoldierFoodSupplyClass.handle_idle(self, worker):
			return
		if WorkplacesClass.requires_home(self, worker):
			ensure_workplace(worker)
		if IndoorWorkersClass.enter_waiting_home(self, worker) and int(worker["indoor_wait_ticks"]) > 0:
			return
		if ClassicEconomyClass.handle_idle(self, worker):
			return
		if SoldierFoodSupplyClass.handle_idle(self, worker):
			return
		if String(worker["type"]) == "gardener":
			_tick_idle_gardener(worker)
		elif String(worker["carrying"]).is_empty():
			_assign_task(worker)
		else:
			if int(worker["blocked_ticks"]) > 0:
				worker["blocked_ticks"] = int(worker["blocked_ticks"]) - 1
			else:
				_resume_carried_ware(worker)
	elif state == "moving":
		_advance_worker(worker)
	elif state == "working":
		if ["operate", "build_site"].has(String(worker["action"])):
			return
		var remaining: int = int(worker["work_remaining"]) - 1
		worker["work_remaining"] = remaining
		if remaining <= 0:
			_finish_work(worker)


func _tick_idle_gardener(worker: Dictionary) -> void:
	# Planting is the forester hut's work, not a global task for every trained
	# gardener. The existing workplace system keeps this claim exclusive.
	if not owns_workplace(worker, int(worker["home_id"])):
		return
	var cooldown: int = maxi(0, int(worker.get("planting_cooldown", 0)))
	if cooldown > 0:
		cooldown -= 1
		worker["planting_cooldown"] = cooldown
		if cooldown > 0:
			return
	var worker_id: int = int(worker["id"])
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	for reserved_cell_variant: Variant in planting_reservations.keys():
		var reserved_cell: Vector2i = reserved_cell_variant as Vector2i
		if int(planting_reservations[reserved_cell]) != worker_id:
			blockers[reserved_cell] = true
	var goal_test: Callable = Callable(self, "_is_available_planting_goal").bind(worker_id)
	var path: Array[Vector2i] = GridPathfinderClass.find_path_to_nearest(
		grid,
		worker["position"] as Vector2i,
		goal_test,
		blockers
	)
	if path.is_empty():
		worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
		return
	var target: Vector2i = path[path.size() - 1]
	planting_reservations[target] = worker_id
	worker["plant_target"] = target
	worker["action"] = "plant_sapling"
	_begin_worker_move(worker, path, target)


func _is_available_planting_goal(cell: Vector2i, worker_id: int) -> bool:
	return workers.has(worker_id) and gardener_can_plant(workers[worker_id], cell)


func gardener_can_plant(worker: Dictionary, cell: Vector2i) -> bool:
	if String(worker.get("type", "")) != "gardener":
		return false
	var home_id: int = int(worker.get("home_id", 0))
	var home: Dictionary = buildings.get(home_id, {})
	if home.is_empty() or home["type"] != "forester_hut" or not owns_workplace(worker, home_id):
		return false
	var center: Vector2i = home["position"]
	var radius: int = maxi(0, int(catalog.building("forester_hut").get("planting_radius", 8)))
	if absi(cell.x - center.x) + absi(cell.y - center.y) > radius:
		return false
	return _can_plant_sapling(cell, int(worker["id"]))


func _gardener_timing(worker: Dictionary, field: String, fallback: int) -> int:
	var definition: Dictionary = catalog.unit(String(worker["type"]))
	return maxi(1, int(definition.get(field, fallback)))


func _assign_task(worker: Dictionary) -> void:
	if not can_worker_work(worker):
		return
	if WorkplacesClass.requires_home(self, worker) and not owns_workplace(worker, int(worker["home_id"])):
		return
	var worker_id: int = int(worker["id"])
	var start: Vector2i = worker["position"] as Vector2i
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	var accepted_tasks: Array[String] = _accepted_tasks_for_worker(worker)
	if accepted_tasks.is_empty():
		return
	var best_task: Dictionary = {}
	var best_path: Array[Vector2i] = []
	var best_cost: int = 2147483647
	var best_target: Vector2i = start
	for candidate: Dictionary in task_board.available_tasks(accepted_tasks):
		if not _task_is_useful(candidate, worker):
			continue
		var target: Vector2i = candidate["target"] as Vector2i
		if candidate["kind"] == "harvest_deposit":
			target = ResourceDepositsClass.candidate_work_cell(self, deposits[int(candidate["source_id"])], start, blockers)
			if target == Vector2i(-1, -1):
				continue
		var candidate_blockers: Dictionary = blockers.duplicate()
		if String(candidate["kind"]).begins_with("transport_") or String(candidate["kind"]).begins_with("operate_") or candidate["kind"] == "build_site":
			candidate_blockers.erase(target)
		var candidate_path: Array[Vector2i] = _path_with_yielding(start, target, candidate_blockers, worker_id)
		if start != target and candidate_path.is_empty():
			continue
		var route_cost: int = GridPathfinderClass.path_cost(grid, candidate_path, start)
		if route_cost < best_cost or (
			route_cost == best_cost
			and (best_task.is_empty() or int(candidate["id"]) < int(best_task["id"]))
		):
			best_task = candidate
			best_target = target
			best_path = candidate_path
			best_cost = route_cost
	if best_task.is_empty():
		return
	var task: Dictionary = task_board.reserve_task(int(best_task["id"]), worker_id)
	if task.is_empty():
		return
	worker["task_id"] = int(task["id"])
	worker["source_id"] = int(task["source_id"])
	var kind: String = String(task["kind"])
	if kind == "harvest_tree":
		worker["action"] = "harvest"
	elif kind == "harvest_deposit":
		if not ResourceDepositsClass.assign(self, worker, task):
			_release_worker_task(worker)
			return
	elif kind.begins_with("transport_"):
		worker["action"] = "pickup_" + kind.trim_prefix("transport_")
	elif kind.begins_with("operate_"):
		worker["action"] = "operate"
	else:
		worker["action"] = kind
	_begin_worker_move(worker, best_path, best_target)


func _advance_worker(worker: Dictionary) -> void:
	if is_worker_inside(worker):
		if int(worker["path_index"]) >= (worker["path"] as Array).size() and IndoorWorkersClass.can_resolve_here(worker):
			_on_worker_arrived(worker)
		else:
			_try_exit_worker_building(worker)
		# Exiting consumes this update; the first outdoor edge starts next tick.
		return
	var cooldown: int = int(worker["move_cooldown"])
	if cooldown > 0:
		worker["move_cooldown"] = cooldown - 1
		return
	var path: Array = worker["path"] as Array
	var path_index: int = int(worker["path_index"])
	if path_index >= path.size():
		_on_worker_arrived(worker)
		return

	var next_cell: Vector2i = path[path_index] as Vector2i
	var worker_id: int = int(worker["id"])
	if not grid.can_traverse(worker["position"] as Vector2i, next_cell):
		worker["blocked_ticks"] = BLOCKED_REPLAN_TICKS
		_reconsider_blocked_worker(worker)
		return
	if tile_reservations.has(next_cell) and int(tile_reservations[next_cell]) != worker_id:
		if _can_interact_from_adjacent(worker, next_cell):
			worker["blocked_ticks"] = 0
			worker["path_index"] = path.size()
			_on_worker_arrived(worker)
		elif _try_swap_workers(worker, int(tile_reservations[next_cell]), next_cell):
			worker["blocked_ticks"] = 0
		elif _try_yield_idle_worker(worker, int(tile_reservations[next_cell])):
			worker["blocked_ticks"] = 0
		else:
			worker["blocked_ticks"] = int(worker.get("blocked_ticks", 0)) + 1
			if int(worker["blocked_ticks"]) >= BLOCKED_REPLAN_TICKS:
				_reconsider_blocked_worker(worker)
		return
	var step_blockers: Dictionary = _temporary_blockers_for(worker_id)
	if not grid.can_step(worker["position"], next_cell, step_blockers):
		# Diagonal flank occupants must step aside too; do not squeeze through
		# their corners, nor enter a tile whose yielding animation is unfinished.
		var from: Vector2i = worker["position"]
		for flank: Vector2i in [Vector2i(from.x, next_cell.y), Vector2i(next_cell.x, from.y)]:
			if tile_reservations.has(flank) and _try_yield_idle_worker(worker, int(tile_reservations[flank])):
				return
		worker["blocked_ticks"] = int(worker["blocked_ticks"]) + 1
		if int(worker["blocked_ticks"]) >= BLOCKED_REPLAN_TICKS:
			_reconsider_blocked_worker(worker)
		return
	_commit_worker_step(worker, next_cell)


func _commit_worker_step(worker: Dictionary, next_cell: Vector2i) -> void:
	var worker_id: int = int(worker["id"])
	if is_worker_inside(worker) or (tile_reservations.has(next_cell) and int(tile_reservations[next_cell]) != worker_id):
		return
	var current: Vector2i = worker["position"] as Vector2i
	var move_duration: int = grid.step_duration_ticks(current, next_cell)
	_release_worker_tile(worker)
	tile_reservations[next_cell] = worker_id
	worker["previous_position"] = current
	worker["position"] = next_cell
	worker["blocked_ticks"] = 0
	worker["path_index"] = int(worker["path_index"]) + 1
	_workers_moved_this_tick[worker_id] = true
	_record_worker_traffic(worker, next_cell)
	worker["move_cooldown"] = move_duration - 1
	worker["visual_progress_ticks"] = 0
	worker["visual_duration_ticks"] = move_duration


func _idle_can_yield(worker: Dictionary) -> bool:
	return not is_worker_inside(worker) and worker["state"] == "idle" and String(worker["action"]).is_empty() \
		and int(worker["task_id"]) == 0 and String(worker["carrying"]).is_empty() \
		and int(worker["move_cooldown"]) == 0 \
		and int(worker["visual_progress_ticks"]) >= int(worker["visual_duration_ticks"]) \
		and tick >= int(worker.get("yield_rest_until", 0)) \
		and not (worker["type"] == "recruit" and owns_workplace(worker, int(worker["home_id"])))


func _try_yield_idle_worker(requester: Dictionary, other_id: int) -> bool:
	if int(requester["id"]) == other_id or not workers.has(other_id) or _workers_moved_this_tick.has(other_id):
		return false
	var other: Dictionary = workers[other_id]
	var path: Array = requester["path"]
	var path_index: int = int(requester["path_index"])
	if requester["state"] != "moving" or path_index >= path.size() or not _idle_can_yield(other):
		return false
	var start: Vector2i = requester["position"]
	var next: Vector2i = path[path_index]
	var from: Vector2i = other["position"]
	var diagonal: bool = start.x != next.x and start.y != next.y
	if from != next and not (diagonal and from in [Vector2i(start.x, next.y), Vector2i(next.x, start.y)]):
		return false
	var best: Vector2i = _idle_yield_destination(other, start, path, path_index)
	if best == Vector2i(-1, -1):
		return false
	_start_worker_yield(other, best)
	return true


func _try_yield_building_exit(worker: Dictionary, other_id: int) -> bool:
	if not is_worker_inside(worker) or not workers.has(other_id) or _workers_moved_this_tick.has(other_id):
		return false
	var other: Dictionary = workers[other_id]
	if not _idle_can_yield(other) or other["position"] != worker["position"]:
		return false
	var best: Vector2i = _idle_yield_destination(other, worker["position"], worker["path"], int(worker["path_index"]))
	if best == Vector2i(-1, -1):
		return false
	_start_worker_yield(other, best)
	return true


func _start_worker_yield(other: Dictionary, best: Vector2i) -> void:
	var from: Vector2i = other["position"]
	var other_id: int = int(other["id"])
	# This is one normal interpolated movement step, never a teleport or a swap
	# that pushes an idle person backwards into the requester's occupied cell.
	other["state"] = "moving"
	other["action"] = "yield"
	other["path"] = [best]
	other["path_index"] = 0
	other["target_cell"] = best
	_commit_worker_step(other, best)
	_yielding_origins[from] = other_id
	other["yield_rest_until"] = tick + int(other["visual_duration_ticks"]) + YIELD_REST_TICKS
	_workers_updated_this_tick[other_id] = true


func _idle_yield_destination(other: Dictionary, requester_start: Vector2i, path: Array, path_index: int = 0) -> Vector2i:
	var avoided: Dictionary = {requester_start: true}
	for index: int in range(path_index, path.size()):
		avoided[path[index]] = true
	for building: Dictionary in buildings.values():
		avoided[building["entrance"]] = true
	var blockers: Dictionary = _temporary_blockers_for(int(other["id"]))
	var from: Vector2i = other["position"]
	var best := Vector2i(-1, -1)
	var best_cost: int = 2147483647
	for cell: Vector2i in grid.neighbors8(from, blockers):
		if avoided.has(cell) or planting_reservations.has(cell) or _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0:
			continue
		var cost: int = grid.step_duration_ticks(from, cell) + (100 if not grid.overlay_at(cell).is_empty() else 0)
		if cost < best_cost:
			best = cell
			best_cost = cost
	return best


func _try_swap_workers(worker: Dictionary, other_worker_id: int, next_cell: Vector2i) -> bool:
	# A swap consumes both updates. In particular, a worker whose cooldown was
	# decremented earlier this tick must wait until the next tick to move.
	if is_worker_inside(worker) or not workers.has(other_worker_id) or _workers_updated_this_tick.has(other_worker_id):
		return false
	var other: Dictionary = workers[other_worker_id] as Dictionary
	if is_worker_inside(other) or String(other["state"]) != "moving" or int(other["move_cooldown"]) > 0:
		return false
	var other_path: Array = other["path"] as Array
	var other_index: int = int(other["path_index"])
	if other_index >= other_path.size():
		return false
	var current: Vector2i = worker["position"] as Vector2i
	if other_path[other_index] as Vector2i != current:
		return false
	if other["position"] as Vector2i != next_cell or not grid.can_traverse(current, next_cell) or not grid.can_traverse(next_cell, current):
		return false
	var blockers: Dictionary = _temporary_blockers_for(int(worker["id"]))
	blockers.erase(next_cell)
	if not grid.can_step(current, next_cell, blockers):
		return false
	var worker_move_duration: int = grid.step_duration_ticks(current, next_cell)
	var other_move_duration: int = grid.step_duration_ticks(next_cell, current)

	_workers_updated_this_tick[other_worker_id] = true
	var worker_id: int = int(worker["id"])
	worker["previous_position"] = current
	worker["position"] = next_cell
	worker["path_index"] = int(worker["path_index"]) + 1
	other["previous_position"] = next_cell
	other["position"] = current
	other["path_index"] = other_index + 1
	tile_reservations[current] = other_worker_id
	tile_reservations[next_cell] = worker_id
	_workers_moved_this_tick[worker_id] = true
	_workers_moved_this_tick[other_worker_id] = true
	_record_worker_traffic(worker, next_cell)
	_record_worker_traffic(other, current)
	worker["move_cooldown"] = worker_move_duration - 1
	other["move_cooldown"] = other_move_duration - 1
	worker["blocked_ticks"] = 0
	other["blocked_ticks"] = 0
	worker["visual_progress_ticks"] = 0
	worker["visual_duration_ticks"] = worker_move_duration
	other["visual_progress_ticks"] = 0
	other["visual_duration_ticks"] = other_move_duration
	return true


func _update_worker_visual_progress() -> void:
	for worker_variant: Variant in workers.values():
		var worker: Dictionary = worker_variant as Dictionary
		var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
		worker["visual_duration_ticks"] = duration
		worker["visual_progress_ticks"] = mini(
			duration,
			int(worker.get("visual_progress_ticks", duration)) + 1
		)
	for cell: Vector2i in _yielding_origins.keys():
		var owner: Dictionary = workers.get(int(_yielding_origins[cell]), {})
		if owner.is_empty() or int(owner["visual_progress_ticks"]) >= int(owner["visual_duration_ticks"]):
			_yielding_origins.erase(cell)


func _reconsider_blocked_worker(worker: Dictionary) -> void:
	if DailyScheduleClass.reconsider_blocked(self, worker):
		return
	if SoldierFoodSupplyClass.reconsider_blocked(self, worker):
		return
	var worker_id: int = int(worker["id"])
	var current: Vector2i = worker["position"] as Vector2i
	var target: Vector2i = worker.get("target_cell", current) as Vector2i
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	if String(worker["action"]) == "plant_sapling":
		if not gardener_can_plant(worker, target):
			_reset_worker(worker)
			worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
			return
		for reserved_cell_variant: Variant in planting_reservations.keys():
			var reserved_cell: Vector2i = reserved_cell_variant as Vector2i
			if int(planting_reservations[reserved_cell]) != worker_id:
				blockers[reserved_cell] = true
	if _worker_allows_occupied_target(worker):
		blockers.erase(target)
	var alternate_path: Array[Vector2i] = _path_with_yielding(current, target, blockers, worker_id)
	if current == target or not alternate_path.is_empty():
		_begin_worker_move(worker, alternate_path, target)
		return

	if String(worker["action"]) == "plant_sapling":
		_reset_worker(worker)
		worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
		return
	if String(worker["action"]) == "eat":
		InnFeedingClass.retry_after_blocked(self, worker)
		return

	if int(worker["task_id"]) != 0 and String(worker["carrying"]).is_empty():
		task_board.release(int(worker["task_id"]), worker_id)
		_reset_worker(worker)
	elif not String(worker["carrying"]).is_empty():
		# Keep the ware, but discard the unreachable destination. Selection must
		# consider current occupancy as well as permanent terrain/building blocks.
		_reset_worker(worker)
		_resume_carried_ware(worker)
	else:
		worker["blocked_ticks"] = 0


func _temporary_blockers_for(worker_id: int) -> Dictionary:
	var blockers: Dictionary = {}
	for cell_variant: Variant in tile_reservations.keys():
		var cell: Vector2i = cell_variant as Vector2i
		if int(tile_reservations[cell]) != worker_id:
			blockers[cell] = true
	for cell: Vector2i in _yielding_origins:
		if int(_yielding_origins[cell]) != worker_id:
			blockers[cell] = true
	return blockers


func _yieldable_path_blockers(blockers: Dictionary, worker_id: int) -> Dictionary:
	var result: Dictionary = blockers.duplicate()
	for cell: Vector2i in blockers:
		var id: int = int(tile_reservations.get(cell, 0))
		if id != 0 and id != worker_id and workers.has(id) and _idle_can_yield(workers[id]) and not _yielding_origins.has(cell):
			result.erase(cell)
	return result


func _path_with_yielding(from: Vector2i, to: Vector2i, blockers: Dictionary, worker_id: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = GridPathfinderClass.find_path(grid, from, to, blockers)
	if from == to or not path.is_empty():
		return path
	var relaxed: Dictionary = _yieldable_path_blockers(blockers, worker_id)
	if relaxed.size() == blockers.size():
		return path
	# Only rely on an idle person yielding if an off-route pocket is actually
	# available. Otherwise keep that person blocked and consider another route
	# or resource, rather than repeatedly choosing an impossible chokepoint.
	while relaxed.size() < blockers.size():
		path = GridPathfinderClass.find_path(grid, from, to, relaxed)
		if path.is_empty():
			return path
		var rejected: bool = false
		var previous: Vector2i = from
		for cell: Vector2i in path:
			var crossing: Array[Vector2i] = [cell]
			if previous.x != cell.x and previous.y != cell.y:
				crossing.append_array([Vector2i(previous.x, cell.y), Vector2i(cell.x, previous.y)])
			for occupied: Vector2i in crossing:
				if blockers.has(occupied) and not relaxed.has(occupied):
					var other: Dictionary = workers.get(int(tile_reservations.get(occupied, 0)), {})
					if other.is_empty() or _idle_yield_destination(other, from, path) == Vector2i(-1, -1):
						relaxed[occupied] = true
						rejected = true
			previous = cell
		if not rejected:
			return path
	return []


func _can_interact_from_adjacent(worker: Dictionary, blocked_cell: Vector2i) -> bool:
	var action: String = String(worker["action"])
	# Operators, diners, reporting recruits and returning specialists must
	# reach the actual doorway. Carrier handoffs and building-site work remain
	# outdoor interactions and may use their existing adjacent-cell behavior.
	if is_worker_inside(worker) or (action != "build_site" and not (
		worker["type"] == "carrier" and (action.begins_with("pickup_") or action.begins_with("deliver_"))
	)):
		return false
	var target_cell: Vector2i = worker.get("target_cell", Vector2i(-1, -1)) as Vector2i
	if blocked_cell != target_cell:
		return false
	if not _worker_allows_occupied_target(worker):
		return false
	var current: Vector2i = worker["position"] as Vector2i
	var blockers: Dictionary = _temporary_blockers_for(int(worker["id"]))
	blockers.erase(blocked_cell)
	return grid.can_step(current, blocked_cell, blockers)


func _worker_allows_occupied_target(worker: Dictionary) -> bool:
	var action: String = String(worker["action"])
	return action.begins_with("pickup_") or action.begins_with("deliver_") or ["operate", "build_site", "eat", "report_barracks", "go_sleep"].has(action)


func _resume_carried_ware(worker: Dictionary) -> void:
	if not can_worker_work(worker):
		return
	if SoldierFoodSupplyClass.resume(self, worker):
		return
	var carrying: String = String(worker["carrying"])
	var blockers: Dictionary = _temporary_blockers_for(int(worker["id"]))
	var destination_id: int = 0
	if String(worker["type"]) != "carrier":
		destination_id = _specialist_home(worker, blockers)
	elif catalog.resources.has(carrying):
		destination_id = _ware_destination(carrying, worker["position"], blockers, int(worker["id"]))
	else:
		return
	worker["action"] = "deliver_" + carrying
	worker["destination_id"] = destination_id
	if destination_id != 0:
		var entrance: Vector2i = _building_entrance(destination_id)
		blockers.erase(entrance)
		if _move_worker_to(worker, entrance, blockers):
			return
	_reset_worker(worker)
	worker["blocked_ticks"] = BLOCKED_REPLAN_TICKS


func _on_worker_arrived(worker: Dictionary) -> void:
	if DailyScheduleClass.arrive(self, worker):
		return
	if SoldierFoodSupplyClass.arrive(self, worker):
		return
	if worker["action"] == "yield":
		_reset_worker(worker)
		return
	if ClassicEconomyClass.arrive(self, worker):
		return
	if worker["action"] == "harvest_deposit":
		ResourceDepositsClass.arrived(self, worker)
		return
	var action: String = String(worker["action"])
	if action.begins_with("pickup_"):
		_pickup_ware(worker, action.trim_prefix("pickup_"))
		return
	if action.begins_with("deliver_"):
		_deliver_ware(worker)
		return
	if action == "operate":
		var building: Dictionary = buildings.get(int(worker["source_id"]), {})
		if building.is_empty() or not owns_workplace(worker, int(building["id"])):
			_release_worker_task(worker)
		elif not _enter_worker_building(worker, int(building["id"])):
			worker["state"] = "moving"
		elif int(building["process_remaining"]) == 0 and not _recipe_ready(building):
			_release_worker_task(worker)
		else:
			worker["state"] = "working"
		return
	if action == "sow_field" or action == "harvest_field":
		var field: Dictionary = fields.get(int(worker["source_id"]), {})
		if field.is_empty() or _farm_for_field(field, worker, action == "harvest_field") == 0:
			_release_worker_task(worker)
			return
		worker["state"] = "working"
		worker["work_remaining"] = int(catalog.unit("farmer").get("sow_ticks" if action == "sow_field" else "harvest_ticks", 20))
		return
	match String(worker["action"]):
		"harvest":
			if not owns_workplace(worker, int(worker["home_id"])):
				_release_worker_task(worker)
				return
			worker["state"] = "working"
			var unit_definition: Dictionary = catalog.unit(String(worker["type"]))
			worker["work_remaining"] = int(unit_definition.get("harvest_ticks", 30))
		"plant_sapling":
			var plant_target: Vector2i = worker.get("plant_target", Vector2i(-1, -1)) as Vector2i
			if worker["position"] != plant_target or not gardener_can_plant(worker, plant_target):
				_reset_worker(worker)
				worker["planting_cooldown"] = _gardener_timing(worker, "search_retry_ticks", 20)
				return
			worker["state"] = "working"
			worker["work_remaining"] = _gardener_timing(worker, "plant_ticks", 20)
		_:
			_reset_worker(worker)


func _finish_work(worker: Dictionary) -> void:
	if worker["action"] == "harvest_deposit":
		ResourceDepositsClass.finish(self, worker)
		return
	if ["sow_field", "harvest_field"].has(String(worker["action"])):
		_finish_field_work(worker)
		return
	if String(worker["action"]) == "plant_sapling":
		_finish_planting(worker)
		return
	if String(worker["action"]) != "harvest":
		_reset_worker(worker)
		return
	if not owns_workplace(worker, int(worker["home_id"])):
		_release_worker_task(worker)
		return
	var tree_id: int = int(worker["source_id"])
	if not trees.has(tree_id):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	var tree: Dictionary = trees[tree_id] as Dictionary
	if not is_tree_mature(tree):
		task_board.release(int(worker["task_id"]), int(worker["id"]))
		_reset_worker(worker)
		return
	tree["amount"] = int(tree["amount"]) - 1
	if int(tree["amount"]) <= 0:
		trees.erase(tree_id)
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	worker["task_id"] = 0
	worker["carrying"] = "log"
	_resume_carried_ware(worker)


func _finish_planting(worker: Dictionary) -> void:
	var target: Vector2i = worker.get("plant_target", Vector2i(-1, -1)) as Vector2i
	var planted: bool = false
	if worker["position"] == target and gardener_can_plant(worker, target):
		var tree_id: int = _create_tree(target, 3, 0)
		planted = tree_id != 0
		if planted:
			_push_event("Gardener planted sapling #%d." % tree_id)
	_reset_worker(worker)
	worker["planting_cooldown"] = _gardener_timing(
		worker,
		"plant_cooldown_ticks" if planted else "search_retry_ticks",
		80 if planted else 20
	)


func _move_worker_to(worker: Dictionary, target: Vector2i, blockers: Dictionary = {}) -> bool:
	var start: Vector2i = worker["position"] as Vector2i
	var path: Array[Vector2i] = _path_with_yielding(start, target, blockers, int(worker["id"]))
	if start != target and path.is_empty():
		return false
	_begin_worker_move(worker, path, target)
	return true


func _begin_worker_move(worker: Dictionary, path: Array[Vector2i], target: Vector2i) -> void:
	worker["path"] = path
	worker["path_index"] = 0
	worker["move_cooldown"] = 0
	worker["blocked_ticks"] = 0
	worker["target_cell"] = target
	worker["state"] = "moving"
	if path.is_empty() and (not is_worker_inside(worker) or IndoorWorkersClass.can_resolve_here(worker)):
		_on_worker_arrived(worker)


func _reset_worker(worker: Dictionary) -> void:
	_release_planting_reservation(worker)
	worker["state"] = "idle"
	worker["action"] = ""
	worker["task_id"] = 0
	worker["source_id"] = 0
	worker["destination_id"] = 0
	worker["path"] = []
	worker["path_index"] = 0
	worker["work_remaining"] = 0
	worker["blocked_ticks"] = 0
	worker["target_cell"] = worker["position"] as Vector2i
	worker["plant_target"] = Vector2i(-1, -1)


func _release_planting_reservation(worker: Dictionary) -> void:
	var target: Vector2i = worker.get("plant_target", Vector2i(-1, -1)) as Vector2i
	var worker_id: int = int(worker["id"])
	if int(planting_reservations.get(target, 0)) == worker_id:
		planting_reservations.erase(target)


func _accepted_tasks_for_worker(worker: Dictionary) -> Array[String]:
	var type: String = String(worker["type"])
	if type == "carrier":
		var tasks: Array[String] = []
		for resource: String in catalog.resources:
			tasks.append("transport_" + resource)
		return tasks
	if type == "lumberjack":
		return LUMBERJACK_TASKS
	if type == "farmer":
		return FARMER_TASKS
	if type == "builder":
		return ["build_site"]
	if ["stonemason", "miner", "fisherman"].has(type):
		return ["harvest_deposit"]
	return ["operate_" + type]


func _movement_duration_for(worker: Dictionary, destination: Vector2i) -> int:
	return grid.step_duration_ticks(worker["position"], destination)


func _record_worker_traffic(worker: Dictionary, destination: Vector2i) -> void:
	if String(worker["type"]) == "carrier" and String(worker.get("action", "")) != "yield" \
		and field_id_at(destination) == 0 and deposit_id_at(destination) == 0:
		var from: Vector2i = worker.get("previous_position", GridMapSimClass.NO_CELL)
		if field_id_at(from) != 0 or deposit_id_at(from) != 0:
			from = GridMapSimClass.NO_CELL
		grid.record_carrier_traffic(destination, from, tick)


func _preferred_log_destination(worker: Dictionary, blockers: Dictionary = {}) -> int:
	var position: Vector2i = worker["position"] as Vector2i
	if String(worker["type"]) == "lumberjack":
		return _lumberjack_home(worker, blockers)
	var destination_id: int = _nearest_building("sawmill", position, blockers)
	if destination_id == 0:
		destination_id = _nearest_building("warehouse", position, blockers)
	return destination_id


func _lumberjack_home(worker: Dictionary, blockers: Dictionary = {}) -> int:
	return _reachable_workplace(worker, blockers)


func _nearest_building(building_type: String, from_cell: Vector2i, blockers: Dictionary = {}) -> int:
	var best_id: int = 0
	var best_cost: int = 2147483647
	var ids: Array = buildings.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var building_id: int = int(id_variant)
		var building: Dictionary = buildings[building_id] as Dictionary
		if String(building["type"]) != building_type or not is_building_complete(building):
			continue
		var target: Vector2i = building["entrance"] as Vector2i
		var route_blockers: Dictionary = blockers.duplicate()
		route_blockers.erase(target)
		var path: Array[Vector2i] = _path_with_yielding(from_cell, target, route_blockers, 0)
		if from_cell != target and path.is_empty():
			continue
		var route_cost: int = GridPathfinderClass.path_cost(grid, path, from_cell)
		if route_cost < best_cost or (route_cost == best_cost and (best_id == 0 or building_id < best_id)):
			best_id = building_id
			best_cost = route_cost
	return best_id


func _first_building(building_type: String) -> int:
	var ids: Array = buildings.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var building_id: int = int(id_variant)
		if String((buildings[building_id] as Dictionary)["type"]) == building_type and is_building_complete(buildings[building_id]):
			return building_id
	return 0


func _building_entrance(building_id: int) -> Vector2i:
	return (buildings[building_id] as Dictionary)["entrance"] as Vector2i


func _setup_demo_terrain() -> void:
	# Keep the economy corridor open while exposing every base material for
	# projection, scale and transition-mask evaluation.
	for y: int in range(12, 16):
		for x: int in range(0, 6):
			grid.set_base_terrain(Vector2i(x, y), "dirt")
	for y: int in range(12, 16):
		for x: int in range(16, 20):
			grid.set_base_terrain(Vector2i(x, y), "water")
	for y: int in range(0, 3):
		for x: int in range(17, 20):
			grid.set_base_terrain(Vector2i(x, y), "rock")


func _training_ticks_for(unit_type: String) -> int:
	return maxi(1, int(catalog.unit(unit_type).get("training_ticks", 1)))


func _find_unit_spawn_cell(building: Dictionary) -> Vector2i:
	# Unit producers currently have a one-cell footprint. Prefer the authored
	# entrance, then use the remaining sides in the grid's canonical order.
	var position: Vector2i = building["position"] as Vector2i
	var entrance: Vector2i = building["entrance"] as Vector2i
	var candidates: Array[Vector2i] = [entrance]
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		var candidate: Vector2i = position + direction
		if candidate != entrance:
			candidates.append(candidate)
	for candidate: Vector2i in candidates:
		if (
			grid.can_use_building_exit(position, candidate)
			and not tile_reservations.has(candidate)
			and not planting_reservations.has(candidate)
			and _tree_at(candidate) == 0
		):
			return candidate
	return Vector2i(-1, -1)


func _find_entrance(cell: Vector2i) -> Vector2i:
	for direction: Vector2i in GridMapSimClass.CARDINAL_DIRECTIONS:
		var candidate: Vector2i = cell + direction
		if grid.can_traverse(cell, candidate) and not planting_reservations.has(candidate) and field_id_at(candidate) == 0 and deposit_id_at(candidate) == 0:
			return candidate
	return Vector2i(-1, -1)


func _can_plant_sapling(cell: Vector2i, allowed_worker_id: int) -> bool:
	if field_id_at(cell) != 0:
		return false
	if not grid.allows_trees(cell) or _tree_at(cell) != 0 or field_id_at(cell) != 0 or deposit_id_at(cell) != 0:
		return false
	if not grid.overlay_at(cell).is_empty():
		return false
	var occupying_worker_id: int = int(tile_reservations.get(cell, 0))
	if occupying_worker_id != 0 and occupying_worker_id != allowed_worker_id:
		return false
	var reserving_worker_id: int = int(planting_reservations.get(cell, 0))
	if reserving_worker_id != 0 and reserving_worker_id != allowed_worker_id:
		return false
	for building_variant: Variant in buildings.values():
		if (building_variant as Dictionary)["entrance"] as Vector2i == cell:
			return false
	return true


func _tree_at(cell: Vector2i) -> int:
	for tree_id_variant: Variant in trees.keys():
		var tree_id: int = int(tree_id_variant)
		if (trees[tree_id] as Dictionary)["position"] as Vector2i == cell:
			return tree_id
	return 0


func _take_entity_id() -> int:
	var result: int = _next_entity_id
	_next_entity_id += 1
	return result


func _push_event(message: String) -> void:
	event_log.push_front("[%d] %s" % [tick, message])
	if event_log.size() > 5:
		event_log.resize(5)


func _empty_inventory() -> Dictionary:
	var inventory: Dictionary = {}
	for resource: String in catalog.resources:
		inventory[resource] = 0
	return inventory


func _building_terrain_valid(type: String, cell: Vector2i, changed_cell: Vector2i = Vector2i(-1, -1), changed_terrain: String = "") -> bool:
	var definition: Dictionary = catalog.building(type)
	var allowed: Array = definition.get("allowed_terrain", [])
	if not allowed.is_empty() and not allowed.has(grid.base_terrain_at(cell)):
		return false
	var nearby: String = String(definition.get("nearby_terrain", ""))
	if nearby.is_empty():
		return true
	var radius: int = int(definition.get("terrain_radius", 0))
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var candidate: Vector2i = cell + Vector2i(x, y)
			var terrain: String = changed_terrain if candidate == changed_cell else grid.base_terrain_at(candidate)
			if absi(x) + absi(y) <= radius and terrain == nearby:
				return true
	return false


func can_place_field(cell: Vector2i, kind: String = "wheat") -> bool:
	if not ["wheat", "vine"].has(kind):
		return false
	if not grid.is_buildable(cell) or not ["grass", "dirt"].has(grid.base_terrain_at(cell)):
		return false
	if field_id_at(cell) != 0 or deposit_id_at(cell) != 0 or _tree_at(cell) != 0 or tile_reservations.has(cell) or planting_reservations.has(cell):
		return false
	if not grid.overlay_at(cell).is_empty():
		return false
	for building: Dictionary in buildings.values():
		if building["entrance"] == cell:
			return false
	return true


func place_field(cell: Vector2i, kind: String = "wheat") -> int:
	if not can_place_field(cell, kind):
		return 0
	if economy_enabled and kind == "vine" and not ClassicEconomyClass.pay_from_warehouses(self, catalog.economy.get("vine_field_cost", {"plank": 1})):
		return 0
	var id: int = _take_entity_id()
	fields[id] = {"id": id, "position": cell, "kind": kind, "age_ticks": 0 if kind == "vine" else -1}
	grid.clear_trail(cell)
	_push_event("Prepared a wheat field. A farmer will sow it.")
	return id


func field_id_at(cell: Vector2i) -> int:
	for id: int in fields:
		if fields[id]["position"] == cell:
			return id
	return 0


func field_growth_stage(field: Dictionary) -> int:
	var age: int = int(field["age_ticks"])
	return 0 if age < 0 else (2 if age >= field_mature_age(field) else 1)


func _tick_fields() -> void:
	for field: Dictionary in fields.values():
		var age: int = int(field["age_ticks"])
		if age >= 0 and age < field_mature_age(field):
			field["age_ticks"] = age + 1


func _farmer_home(worker: Dictionary, blockers: Dictionary = {}) -> int:
	return _reachable_workplace(worker, blockers)


func _field_in_farm_range(field: Dictionary, farm_id: int) -> bool:
	if not buildings.has(farm_id):
		return false
	var home: Vector2i = buildings[farm_id]["position"]
	var cell: Vector2i = field["position"]
	return absi(home.x - cell.x) + absi(home.y - cell.y) <= int(catalog.building("farm").get("field_radius", 8))


func _farm_for_field(field: Dictionary, worker: Dictionary, needs_output_room: bool) -> int:
	# Fields may overlap two farms' ranges, but a farmer only serves the one
	# workplace they own. No-work/full-output conditions never reassign them.
	var id: int = int(worker["home_id"])
	if not owns_workplace(worker, id):
		return 0
	var farm: Dictionary = buildings[id]
	if farm["type"] != ("vineyard" if field.get("kind", "wheat") == "vine" else "farm") or not _field_in_farm_range(field, id):
		return 0
	var worker_id: int = int(worker["id"])
	var ware: String = "wine" if field.get("kind", "wheat") == "vine" else "grain"
	if needs_output_room and int(farm["outputs"].get(ware, 0)) + _incoming_amount(id, ware, worker_id) >= int(catalog.building(String(farm["type"]))["output_capacity"]):
		return 0
	var entrance: Vector2i = farm["entrance"]
	var blockers: Dictionary = _temporary_blockers_for(worker_id)
	blockers.erase(entrance)
	if field["position"] != entrance and _path_with_yielding(field["position"], entrance, blockers, worker_id).is_empty():
		return 0
	return id


func _finish_field_work(worker: Dictionary) -> void:
	var field: Dictionary = fields.get(int(worker["source_id"]), {})
	if field.is_empty() or _farm_for_field(field, worker, worker["action"] == "harvest_field") == 0:
		_release_worker_task(worker)
		return
	var harvested: bool = false
	if String(worker["action"]) == "sow_field" and field_growth_stage(field) == 0:
		field["age_ticks"] = 0
	elif String(worker["action"]) == "harvest_field" and field_growth_stage(field) == 2:
		var is_vine: bool = field.get("kind", "wheat") == "vine"
		field["age_ticks"] = 0 if is_vine else -1
		worker["carrying"] = "wine" if is_vine else "grain"
		harvested = true
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	_reset_worker(worker)
	if harvested:
		_resume_carried_ware(worker)


func _building_operator(building_id: int) -> Dictionary:
	var worker: Dictionary = workplace_worker(building_id)
	if not worker.is_empty() and int(worker["source_id"]) == building_id and worker["action"] == "operate" and worker["state"] == "working":
		return worker
	return {}


func _recipe_ready(building: Dictionary) -> bool:
	var definition: Dictionary = catalog.building(String(building["type"]))
	var recipe: Dictionary = ClassicEconomyClass.recipe_for(self, building)
	if recipe.is_empty() or not is_building_complete(building) or not _building_terrain_valid(String(building["type"]), building["position"]):
		return false
	if bool(definition.get("needs_order", false)) and (building["production_queue"] as Array).is_empty():
		return false
	for resource: String in recipe["inputs"]:
		if int(building["inputs"].get(resource, 0)) < int(recipe["inputs"][resource]):
			return false
	for resource: String in recipe["outputs"]:
		if int(building["outputs"].get(resource, 0)) + int(recipe["outputs"][resource]) > int(definition.get("output_capacity", 2147483647)):
			return false
	return true


func production_status(building: Dictionary) -> String:
	var type: String = String(building["type"])
	var definition: Dictionary = catalog.building(type)
	if not is_building_complete(building):
		if not ClassicEconomyClass.materials_ready(self, building):
			return "Carriers are bringing construction materials."
		for worker: Dictionary in workers.values():
			if worker["action"] == "build_site" and worker["state"] == "working" and int(worker["source_id"]) == int(building["id"]):
				return "Building — %.1f s remaining" % (float(building["construction_remaining"]) / 10.0)
		return "Materials ready — waiting for a Builder."
	var assigned_worker: Dictionary = workplace_worker(int(building["id"]))
	if not assigned_worker.is_empty() and (int(assigned_worker.get("meal_ticks_left", 0)) > 0 \
			or assigned_worker["action"] == "eat"):
		return "Worker is eating at the Inn; this workplace remains assigned."
	if type in ["farm", "vineyard"]:
		var has_farmer: bool = false
		for worker: Dictionary in workers.values():
			if worker["type"] == "farmer" and int(worker["home_id"]) == int(building["id"]):
				has_farmer = true
		if not has_farmer:
			return "Waiting for a Farmer — train one at a school."
		for field: Dictionary in fields.values():
			if _field_in_farm_range(field, int(building["id"])) and String(field.get("kind", "wheat")) == String(definition.get("field_kind", "wheat")):
				return "Farmers tend and harvest fields within 8 tiles."
		return "Build %s fields within 8 tiles." % ("vine" if type == "vineyard" else "wheat")
	if definition.has("extract_resource"):
		var remaining: int = 0
		for deposit: Dictionary in deposits.values():
			if deposit["resource"] == definition["extract_resource"] and ResourceDepositsClass._in_range(definition, building["position"], deposit["position"]):
				remaining += int(deposit["amount"])
		if remaining == 0:
			return "Nearby deposits are exhausted. Build beside a new deposit."
		return "Nearby reserves: %d %s. A %s gathers them." % [remaining, catalog.resources[definition["extract_resource"]]["display_name"], catalog.unit(definition["worker"])["display_name"]]
	if type == "school":
		if (building["training_queue"] as Array).is_empty():
			return "Choose a profession below. Each citizen costs 1 Gold."
		if economy_enabled and not bool(building["training_paid"]):
			return "Waiting for Gold from a carrier."
		return "Training paid — %.1f s remaining" % (float(building["training_remaining"]) / 10.0)
	if type == "inn":
		return "Hungry citizens come here for delivered food."
	if type in ["barracks", "town_hall", "marketplace"]:
		var orders: Array = building["service_queue"]
		if orders.is_empty():
			return "Choose an order below."
		var order: Dictionary = orders[0]
		if order["kind"] == "trade":
			return "Carriers deliver the payment and collect traded wares."
		var soldier: Dictionary = catalog.soldiers[order["unit"]]
		for resource: String in soldier["equipment"]:
			if int(building["inputs"].get(resource, 0)) < int(soldier["equipment"][resource]):
				return "Waiting for %s" % catalog.resources[resource]["display_name"]
		return "Equipment ready — waiting for a Recruit from the school." if bool(soldier.get("requires_recruit", false)) else "Gold ready — waiting for a free exit."
	if type == "watchtower":
		return "A Recruit guards the tower; carriers bring stone ammunition."
	if bool(definition.get("needs_order", false)) and (building["production_queue"] as Array).is_empty():
		return "Choose equipment to produce below."
	var recipe: Dictionary = ClassicEconomyClass.recipe_for(self, building)
	if recipe.is_empty():
		return ""
	var staff: String = String(definition.get("worker", ""))
	var staffed: bool = staff.is_empty() or not _building_operator(int(building["id"])).is_empty() or (not economy_enabled and type == "sawmill")
	if int(building["process_remaining"]) > 0:
		return "Producing — %.1f s remaining" % (float(building["process_remaining"]) / 10.0) if staffed else "Production paused — waiting for %s" % String(catalog.unit(staff).get("display_name", staff))
	for resource: String in recipe["inputs"]:
		if int(building["inputs"].get(resource, 0)) < int(recipe["inputs"][resource]):
			return "Waiting for %s" % String(catalog.resources[resource]["display_name"])
	if not _recipe_ready(building):
		return "Output full — waiting for a carrier"
	if not staffed:
		return "Waiting for %s — train one at a school." % String(catalog.unit(staff).get("display_name", staff))
	return "Ready"



func _generate_economy_tasks() -> void:
	var ids: Array = buildings.keys()
	ids.sort()
	for id: int in ids:
		var building: Dictionary = buildings[id]
		var type: String = String(building["type"])
		if not is_building_complete(building):
			continue
		ClassicEconomyClass.select_next_recipe(self, building)
		var definition: Dictionary = catalog.building(type)
		var staff: String = String(definition.get("worker", ""))
		if not staff.is_empty() and definition.has("recipe") and (int(building["process_remaining"]) > 0 or _recipe_ready(building)):
			task_board.create_task("operate_" + staff, "operate:%d" % id, building["entrance"], id)
		var inventory: Dictionary = building["storage"] if type == "warehouse" else building["outputs"]
		var resources: Array = inventory.keys()
		resources.sort()
		for resource: String in resources:
			if int(inventory[resource]) <= 0:
				continue
			var source_key: String = "%s:%d:%s" % [type, id, resource]
			# Existing tasks are revalidated when claimed and at pickup. Avoid
			# repeating all consumer route searches while their carrier travels.
			if task_board.has_source(source_key):
				continue
			if _ware_destination(resource, building["entrance"], {}, 0, id, type == "warehouse") == 0:
				continue
			task_board.create_task("transport_" + resource, source_key, building["entrance"], id)
	if has_building("farm") or has_building("vineyard"):
		var field_ids: Array = fields.keys()
		field_ids.sort()
		for id: int in field_ids:
			var field: Dictionary = fields[id]
			var stage: int = field_growth_stage(field)
			if stage != 1:
				task_board.create_task("sow_field" if stage == 0 else "harvest_field", "field:%d" % id, field["position"], id)


func _task_is_useful(task: Dictionary, worker: Dictionary) -> bool:
	var kind: String = String(task["kind"])
	var id: int = int(task["source_id"])
	if kind == "harvest_tree":
		var home: int = int(worker["home_id"])
		return owns_workplace(worker, home) and trees.has(id) and is_tree_mature(trees[id]) and int(trees[id]["amount"]) > 0 and int(buildings[home]["outputs"].get("log", 0)) < int(catalog.building("lumber_hut").get("output_capacity", 6))
	if kind == "harvest_deposit":
		return ResourceDepositsClass.task_available(self, task, worker)
	if kind == "build_site":
		return buildings.has(id) and not is_building_complete(buildings[id]) and ClassicEconomyClass.materials_ready(self, buildings[id])
	if kind == "sow_field" or kind == "harvest_field":
		var field: Dictionary = fields.get(id, {})
		if field.is_empty() or field_growth_stage(field) != (0 if kind == "sow_field" else 2):
			return false
		return _farm_for_field(field, worker, kind == "harvest_field") != 0
	if kind.begins_with("operate_"):
		return owns_workplace(worker, id) and kind == "operate_" + String(worker["type"]) and (int(buildings[id]["process_remaining"]) > 0 or _recipe_ready(buildings[id]))
	if kind.begins_with("transport_"):
		if not buildings.has(id):
			return false
		var source: Dictionary = buildings[id]
		var from_storage: bool = source["type"] == "warehouse"
		var inventory: Dictionary = source["storage"] if from_storage else source["outputs"]
		var resource: String = kind.trim_prefix("transport_")
		return int(inventory.get(resource, 0)) > SoldierFoodSupplyClass.source_reserved(self, id, resource) \
			and _ware_destination(resource, source["entrance"], {}, int(worker["id"]), id, from_storage) != 0
	return true


func _incoming_amount(building_id: int, resource: String, except_worker: int = 0) -> int:
	var amount: int = 0
	for id: int in workers:
		var worker: Dictionary = workers[id]
		if id == except_worker:
			continue
		if int(worker["destination_id"]) == building_id and worker["carrying"] == resource \
				and String(worker["action"]).begins_with("deliver_"):
			amount += 1
		elif int(worker["home_id"]) == building_id and worker["action"] == "harvest_field":
			var field: Dictionary = fields.get(int(worker["source_id"]), {})
			if resource == ("wine" if field.get("kind", "wheat") == "vine" else "grain"):
				amount += 1
	return amount


func _input_room(building: Dictionary, resource: String, worker_id: int) -> bool:
	return ClassicEconomyClass.needs_material(self, building, resource) > _incoming_amount(int(building["id"]), resource, worker_id)


func _warehouse_room(building: Dictionary, resource: String, worker_id: int = 0) -> int:
	if building["type"] != "warehouse" or not is_building_complete(building) or not (catalog.building("warehouse").get("accepts", []) as Array).has(resource):
		return 0
	var capacity: int = int(catalog.economy.get("stock_capacity_per_ware", 99999))
	return maxi(0, capacity - int(building["storage"].get(resource, 0)) - _incoming_amount(int(building["id"]), resource, worker_id))


func _ware_destination(resource: String, from: Vector2i, blockers: Dictionary = {}, worker_id: int = 0, source_id: int = 0, consumers_only: bool = false) -> int:
	var ids: Array = buildings.keys()
	ids.sort()
	for consumer: bool in [true, false]:
		if not consumer and consumers_only:
			break
		var best: int = 0
		var best_cost: int = 2147483647
		for id: int in ids:
			if id == source_id:
				continue
			var building: Dictionary = buildings[id]
			if consumer:
				if not _input_room(building, resource, worker_id):
					continue
			elif _warehouse_room(building, resource, worker_id) <= 0:
				continue
			var target: Vector2i = building["entrance"]
			var route_blockers: Dictionary = blockers.duplicate()
			route_blockers.erase(target)
			var path: Array[Vector2i] = _path_with_yielding(from, target, route_blockers, worker_id)
			if from != target and path.is_empty():
				continue
			var cost: int = GridPathfinderClass.path_cost(grid, path, from)
			if consumer and economy_enabled:
				cost += (int(building["inputs"].get(resource, 0)) + _incoming_amount(id, resource, worker_id)) * 40
			if cost < best_cost:
				best = id
				best_cost = cost
		if best != 0:
			return best
	return 0


func _pickup_ware(worker: Dictionary, resource: String) -> void:
	var source: Dictionary = buildings.get(int(worker["source_id"]), {})
	if source.is_empty():
		_release_worker_task(worker)
		return
	var from_storage: bool = source["type"] == "warehouse"
	var inventory: Dictionary = source["storage"] if from_storage else source["outputs"]
	var blockers: Dictionary = _temporary_blockers_for(int(worker["id"]))
	var destination: int = _ware_destination(resource, worker["position"], blockers, int(worker["id"]), int(source["id"]), from_storage)
	if int(inventory.get(resource, 0)) <= SoldierFoodSupplyClass.source_reserved(self, int(source["id"]), resource) or destination == 0:
		_release_worker_task(worker)
		return
	inventory[resource] = int(inventory[resource]) - 1
	task_board.complete(int(worker["task_id"]), int(worker["id"]))
	worker["task_id"] = 0
	worker["carrying"] = resource
	worker["destination_id"] = destination
	worker["action"] = "deliver_" + resource
	var entrance: Vector2i = buildings[destination]["entrance"]
	blockers.erase(entrance)
	if not _move_worker_to(worker, entrance, blockers):
		_reset_worker(worker)


func _deliver_ware(worker: Dictionary) -> void:
	var destination: Dictionary = buildings.get(int(worker["destination_id"]), {})
	var resource: String = String(worker["carrying"])
	var delivered: bool = false
	if WorkplacesClass.requires_home(self, worker) and not owns_workplace(worker, int(worker["destination_id"])):
		# Preserve cargo while waiting for this worker's own workplace. A stale
		# route must not deposit it at another producer or construction site.
		_reset_worker(worker)
		return
	if worker["type"] != "carrier" and not destination.is_empty() and owns_workplace(worker, int(destination["id"])):
		if not _enter_worker_building(worker, int(destination["id"]), IndoorWorkersClass.DWELL_TICKS):
			worker["state"] = "moving"
			return
	if not destination.is_empty():
		var type: String = String(destination["type"])
		if not is_building_complete(destination):
			if _input_room(destination, resource, int(worker["id"])):
				destination["construction_delivered"][resource] = int(destination["construction_delivered"].get(resource, 0)) + 1
				delivered = true
		elif worker["type"] != "carrier" and (catalog.unit(String(worker["type"])).get("home_buildings", []) as Array).has(type) and (catalog.building(type).get("outputs", []) as Array).has(resource):
			var amount: int = int(destination["outputs"].get(resource, 0))
			if amount < int(catalog.building(type).get("output_capacity", 2147483647)):
				destination["outputs"][resource] = amount + 1
				delivered = true
		elif type == "warehouse":
			if _warehouse_room(destination, resource, int(worker["id"])) > 0:
				destination["storage"][resource] = int(destination["storage"].get(resource, 0)) + 1
				delivered = true
		elif _input_room(destination, resource, int(worker["id"])):
			destination["inputs"][resource] = int(destination["inputs"].get(resource, 0)) + 1
			delivered = true
	if delivered:
		worker["carrying"] = ""
	_reset_worker(worker)


func _release_worker_task(worker: Dictionary) -> void:
	task_board.release(int(worker["task_id"]), int(worker["id"]))
	_reset_worker(worker)


func setup_economy_demo() -> void:
	# Authored starter village: buildings are complete before rules are enabled.
	# Later player construction always requires delivered materials and builders.
	grid = GridMapSimClass.new(Vector2i(34, 24))
	grid.configure_movement(catalog.movement)
	for cell: Vector2i in [Vector2i(29, 3), Vector2i(30, 3), Vector2i(29, 8), Vector2i(30, 8), Vector2i(29, 12), Vector2i(30, 12)]:
		grid.set_base_terrain(cell, "rock")
	for x: int in range(3, 7):
		for y: int in range(17, 23):
			grid.set_base_terrain(Vector2i(x, y), "water")
	for row: Array in [[Vector2i(29, 3), "stone", 90], [Vector2i(30, 3), "stone", 90], [Vector2i(29, 8), "iron_ore", 80], [Vector2i(30, 8), "iron_ore", 80], [Vector2i(29, 12), "gold_ore", 70], [Vector2i(30, 12), "gold_ore", 70], [Vector2i(25, 4), "coal", 160], [Vector2i(25, 5), "coal", 160], [Vector2i(6, 19), "fish", 60], [Vector2i(6, 21), "fish", 60]]:
		add_deposit(row[0], row[1], row[2])
	for cell: Vector2i in [Vector2i(8, 2), Vector2i(10, 2), Vector2i(12, 2), Vector2i(8, 4), Vector2i(10, 4), Vector2i(8, 6), Vector2i(10, 6), Vector2i(12, 6)]:
		add_tree(cell, 3)
	var positions: Dictionary = {
		"warehouse": Vector2i(5, 10), "school": Vector2i(5, 6), "lumber_hut": Vector2i(9, 8),
		"forester_hut": Vector2i(7, 4),
		"sawmill": Vector2i(13, 8), "quarry": Vector2i(27, 3), "farm": Vector2i(9, 14),
		"mill": Vector2i(15, 14), "bakery": Vector2i(19, 14), "coal_mine": Vector2i(23, 4),
		"iron_mine": Vector2i(27, 8), "gold_mine": Vector2i(27, 12), "iron_smithy": Vector2i(21, 8),
		"metallurgist": Vector2i(21, 12), "vineyard": Vector2i(9, 19), "fisher_hut": Vector2i(7, 19),
		"swine_farm": Vector2i(15, 19), "butcher": Vector2i(19, 19), "tannery": Vector2i(23, 19),
		"stables": Vector2i(27, 19), "weapon_workshop": Vector2i(13, 4), "armour_workshop": Vector2i(17, 4),
		"weapon_smithy": Vector2i(17, 8), "armour_smithy": Vector2i(17, 12), "inn": Vector2i(5, 14),
		"barracks": Vector2i(23, 15), "marketplace": Vector2i(13, 11), "town_hall": Vector2i(5, 3),
		"watchtower": Vector2i(30, 19),
	}
	var ids: Dictionary = {}
	for type: String in positions:
		ids[type] = place_building(type, positions[type])
		assert(int(ids[type]) != 0, "Invalid demo building: " + type)
	for x: int in range(10, 14):
		for y: int in range(14, 17):
			place_field(Vector2i(x, y))
		for y: int in range(19, 21):
			place_field(Vector2i(x, y), "vine")
	var warehouse: Dictionary = buildings[int(ids["warehouse"])]
	for resource: String in {"plank": 60, "stone": 50, "gold": 30, "bread": 24, "sausage": 12, "wine": 12, "fish": 12}:
		warehouse["storage"][resource] = int({"plank": 60, "stone": 50, "gold": 30, "bread": 24, "sausage": 12, "wine": 12, "fish": 12}[resource])
	for type: String in positions:
		var definition: Dictionary = catalog.building(type)
		var role: String = String(definition.get("worker", ""))
		if type == "lumber_hut":
			role = "lumberjack"
		if role.is_empty():
			continue
		var building: Dictionary = buildings[int(ids[type])]
		spawn_worker(_find_unit_spawn_cell(building), role, int(building["id"]))
	for cell: Vector2i in [Vector2i(6, 8), Vector2i(7, 8), Vector2i(6, 10), Vector2i(7, 10), Vector2i(6, 12), Vector2i(7, 12), Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12), Vector2i(11, 12)]:
		spawn_worker(cell, "carrier")
	spawn_worker(Vector2i(4, 12), "builder")
	spawn_worker(Vector2i(4, 11), "builder")
	spawn_worker(Vector2i(10, 17), "farmer")
	spawn_worker(Vector2i(11, 17), "farmer")
	spawn_worker(Vector2i(23, 13), "recruit")
	for type: String in ["weapon_workshop", "armour_workshop", "weapon_smithy", "armour_smithy"]:
		for recipe: String in catalog.building(type)["recipes"]:
			queue_production(int(ids[type]), recipe)
	queue_recruitment(int(ids["barracks"]), "axe_fighter")
	economy_enabled = true
	_push_event("KaM economy ready: finite deposits, food, construction, gold and equipment.")


func is_building_complete(building: Dictionary) -> bool:
	return ClassicEconomyClass.complete(building)


func add_deposit(cell: Vector2i, resource: String, amount: int = 40) -> int:
	return ResourceDepositsClass.add(self, cell, resource, amount)


func deposit_id_at(cell: Vector2i) -> int:
	return ResourceDepositsClass.id_at(self, cell)


func field_mature_age(field: Dictionary) -> int:
	return int(catalog.economy.get("vine_growth_ticks" if field.get("kind", "wheat") == "vine" else "wheat_growth_ticks", FIELD_MATURE_AGE_TICKS))


func queue_production(building_id: int, recipe_id: String) -> bool:
	return ClassicEconomyClass.queue_production(self, building_id, recipe_id)


func queue_recruitment(building_id: int, soldier_type: String) -> bool:
	return ClassicEconomyClass.queue_recruitment(self, building_id, soldier_type)


func queue_trade(building_id: int, give_resource: String, receive_resource: String) -> bool:
	return ClassicEconomyClass.queue_trade(self, building_id, give_resource, receive_resource)


func trade_amounts(give_resource: String, receive_resource: String) -> Dictionary:
	return ClassicEconomyClass.trade_amounts(self, give_resource, receive_resource)


func _specialist_home(worker: Dictionary, blockers: Dictionary = {}) -> int:
	var resource: String = String(worker["carrying"])
	var id: int = _reachable_workplace(worker, blockers)
	if id == 0 or not (catalog.building(String(buildings[id]["type"])).get("outputs", []) as Array).has(resource):
		return 0
	return id


func _reachable_workplace(worker: Dictionary, blockers: Dictionary = {}) -> int:
	# Route availability is not ownership. In particular load/resume must not
	# assign an unemployed saved worker or abandon a temporarily blocked home.
	var id: int = int(worker["home_id"])
	if not owns_workplace(worker, id):
		return 0
	var entrance: Vector2i = buildings[id]["entrance"]
	var route_blockers: Dictionary = blockers.duplicate()
	route_blockers.erase(entrance)
	if worker["position"] != entrance and _path_with_yielding(worker["position"], entrance, route_blockers, int(worker["id"])).is_empty():
		return 0
	return id
