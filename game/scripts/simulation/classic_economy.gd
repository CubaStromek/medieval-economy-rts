class_name ClassicEconomy
extends RefCounted

const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const WorkplacesClass = preload("res://scripts/simulation/workplaces.gd")
const InnFeedingClass = preload("res://scripts/simulation/inn_feeding.gd")
const Foundations = preload("res://scripts/simulation/building_foundations.gd")
const NutritionClass = preload("res://scripts/simulation/nutrition.gd")
const QUEUE_CAPACITY: int = 10


static func complete(building: Dictionary) -> bool:
	return int(building.get("construction_remaining", 0)) == 0 and not Foundations.pending(building)


static func has_stock(inventory: Dictionary, cost: Dictionary) -> bool:
	for resource: String in cost:
		if int(inventory.get(resource, 0)) < int(cost[resource]):
			return false
	return true


static func take_stock(inventory: Dictionary, cost: Dictionary) -> void:
	for resource: String in cost:
		inventory[resource] = int(inventory.get(resource, 0)) - int(cost[resource])


static func pay_from_warehouses(world: Variant, cost: Dictionary) -> bool:
	for resource: String in cost:
		if world.stored_amount(resource) < int(cost[resource]):
			return false
	var ids: Array = world.buildings.keys()
	ids.sort()
	for resource: String in cost:
		var remaining: int = int(cost[resource])
		for id: int in ids:
			var building: Dictionary = world.buildings[id]
			if not world.is_local_entity(building) or building["type"] != "warehouse" or not complete(building):
				continue
			var amount: int = mini(remaining, int(building["storage"].get(resource, 0)))
			building["storage"][resource] = int(building["storage"].get(resource, 0)) - amount
			remaining -= amount
	return true


static func recipe_for(world: Variant, building: Dictionary) -> Dictionary:
	return world.catalog.recipe(String(building.get("recipe_id", world.catalog.building(building["type"]).get("recipe", ""))))


static func select_next_recipe(world: Variant, building: Dictionary) -> void:
	if int(building["process_remaining"]) > 0 or bool(building.get("order_active", false)):
		return
	var queue: Array = building.get("production_queue", [])
	if not queue.is_empty():
		building["recipe_id"] = String(queue[0])


static func queue_production(world: Variant, building_id: int, recipe_id: String) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty() or not world.is_local_entity(building):
		return false
	var definition: Dictionary = world.catalog.building(building["type"])
	if not complete(building) or not (definition.get("recipes", []) as Array).has(recipe_id):
		return false
	var queue: Array = building["production_queue"]
	if queue.size() >= QUEUE_CAPACITY:
		return false
	queue.append(recipe_id)
	select_next_recipe(world, building)
	return true


static func needs_material(world: Variant, building: Dictionary, resource: String) -> int:
	if not world.is_building_enabled(building) or Foundations.pending(building):
		return 0
	var definition: Dictionary = world.catalog.building(building["type"])
	if not complete(building):
		return maxi(0, int(world.construction_cost(building).get(resource, 0)) - int(building["construction_delivered"].get(resource, 0)))
	if not (definition.get("inputs", []) as Array).has(resource):
		return 0
	var capacity: int = int(definition.get("input_capacity", 4))
	if building["type"] == "marketplace":
		var needed: int = 0
		for order: Dictionary in building["service_queue"]:
			if order["kind"] == "trade" and order["give"] == resource:
				needed += int(trade_amounts(world, resource, order["receive"]).get("give", 0))
		capacity = mini(capacity, needed)
	elif bool(definition.get("needs_order", false)):
		var needed: int = 0
		for id: String in building["production_queue"]:
			needed += int(world.catalog.recipe(id).get("inputs", {}).get(resource, 0))
		capacity = mini(capacity, needed)
	return maxi(0, capacity - int(building["inputs"].get(resource, 0)))


static func materials_ready(world: Variant, building: Dictionary) -> bool:
	return not Foundations.pending(building) and has_stock(building["construction_delivered"], world.construction_cost(building))


static func generate_tasks(world: Variant) -> void:
	var ids: Array = world.buildings.keys()
	ids.sort()
	for id: int in ids:
		var building: Dictionary = world.buildings[id]
		if world.is_local_entity(building) and world.is_building_enabled(building) and not complete(building) and (Foundations.pending(building) or materials_ready(world, building)):
			world.task_board.create_task("build_site", "construction:%d" % id, building["entrance"], id)


static func tick_construction(world: Variant, building: Dictionary) -> void:
	if not world.is_building_enabled(building) or complete(building) or (not Foundations.pending(building) and not materials_ready(world, building)):
		return
	for worker: Dictionary in world.workers.values():
		if worker["action"] != "build_site" or worker["state"] != "working" or int(worker["source_id"]) != int(building["id"]):
			continue
		if not world.can_worker_work(worker):
			continue
		if Foundations.pending(building):
			Foundations.tick(world, building, worker)
			return
		if not world.allow_worker_work_tick(worker):
			return
		building["construction_remaining"] = int(building["construction_remaining"]) - 1
		if complete(building):
			world.task_board.complete(int(worker["task_id"]), int(worker["id"]))
			world._reset_worker(worker)
			world._push_event("Construction completed: %s." % world.catalog.building(building["type"])["display_name"])
		return


static func trade_amounts(world: Variant, give: String, receive: String) -> Dictionary:
	if give == receive or not world.catalog.resources.has(give) or not world.catalog.resources.has(receive):
		return {}
	for special: Dictionary in world.catalog.economy.get("market_special_rates", []):
		if special["from"] == give and special["to"] == receive:
			return {"give": int(special["give"]), "receive": int(special["receive"])}
	var source_price: float = float(world.catalog.resources[give].get("market_price", 1))
	var target_price: float = float(world.catalog.resources[receive].get("market_price", 1)) * float(world.catalog.economy.get("market_tradeoff_factor", 2.2))
	var base: float = minf(source_price, target_price)
	if base <= 0.0:
		return {}
	return {"give": maxi(1, roundi(target_price / base)), "receive": maxi(1, roundi(source_price / base))}


static func queue_trade(world: Variant, building_id: int, give: String, receive: String) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	if building.is_empty() or not world.is_local_entity(building) or building["type"] != "marketplace" or not complete(building) or trade_amounts(world, give, receive).is_empty():
		return false
	if (building["service_queue"] as Array).size() >= QUEUE_CAPACITY:
		return false
	building["service_queue"].append({"kind": "trade", "give": give, "receive": receive})
	return true


static func queue_recruitment(world: Variant, building_id: int, unit: String) -> bool:
	var building: Dictionary = world.buildings.get(building_id, {})
	var definition: Dictionary = world.catalog.soldiers.get(unit, {})
	if building.is_empty() or not world.is_local_entity(building) or not complete(building) or definition.is_empty() or definition.get("building", "") != building["type"]:
		return false
	if (building["service_queue"] as Array).size() >= QUEUE_CAPACITY:
		return false
	building["service_queue"].append({"kind": "recruit", "unit": unit})
	return true


static func tick_service(world: Variant, building: Dictionary) -> void:
	var queue: Array = building.get("service_queue", [])
	if queue.is_empty() or not world.is_building_enabled(building) or not complete(building):
		return
	var order: Dictionary = queue[0]
	if order["kind"] == "trade":
		var amounts: Dictionary = trade_amounts(world, order["give"], order["receive"])
		if int(building["inputs"].get(order["give"], 0)) < int(amounts["give"]):
			return
		var capacity: int = int(world.catalog.building("marketplace").get("output_capacity", 100))
		if int(building["outputs"].get(order["receive"], 0)) + int(amounts["receive"]) > capacity:
			return
		building["inputs"][order["give"]] = int(building["inputs"].get(order["give"], 0)) - int(amounts["give"])
		building["outputs"][order["receive"]] = int(building["outputs"].get(order["receive"], 0)) + int(amounts["receive"])
		queue.pop_front()
		world._push_event("Marketplace completed a trade.")
	elif order["kind"] == "recruit":
		var definition: Dictionary = world.catalog.soldiers[order["unit"]]
		if not has_stock(building["inputs"], definition["equipment"]):
			return
		if bool(definition.get("requires_recruit", false)):
			# Recruits physically report to the barracks; equipment is consumed
			# only when a recruit has arrived, preserving identity and hunger.
			for worker: Dictionary in world.workers.values():
				if world.is_local_entity(worker) and not world.is_worker_work_paused(worker) and worker["type"] == "recruit" and worker["state"] == "idle" and int(worker["home_id"]) == 0 and _at_entrance(worker, building) \
						and (not world.is_worker_inside(worker) or int(worker["inside_building_id"]) == int(building["id"])):
					take_stock(building["inputs"], definition["equipment"])
					worker["type"] = order["unit"]
					worker["home_id"] = 0
					if world.is_worker_inside(worker):
						worker["action"] = "leave_building"
						var exit_path: Array[Vector2i] = []
						world._begin_worker_move(worker, exit_path, worker["position"])
					queue.pop_front()
					world._push_event("Equipped %s." % definition["display_name"])
					return
		else:
			var spawn: Vector2i = world._find_unit_spawn_cell(building)
			if spawn == Vector2i(-1, -1) or world.spawn_worker(spawn, order["unit"], 0, true, 0, int(building.get("owner_id", 1))) == 0:
				return
			take_stock(building["inputs"], definition["equipment"])
			queue.pop_front()


static func _at_entrance(worker: Dictionary, building: Dictionary) -> bool:
	var current: Vector2i = worker["position"]
	var target: Vector2i = building["entrance"]
	return absi(current.x - target.x) + absi(current.y - target.y) <= 1


static func tick_needs(world: Variant) -> void:
	if not world.economy_enabled:
		return
	var ids: Array = world.workers.keys()
	ids.sort()
	for id: int in ids:
		var worker: Dictionary = world.workers[id]
		if NutritionClass.tick_needs(world, worker):
			world.task_board.release(int(worker["task_id"]), id)
			world._release_planting_reservation(worker)
			world._release_worker_tile(worker)
			world.workers.erase(id)
			var advice: String = "Order food supplies for your soldiers." if world.catalog.soldiers.has(String(worker["type"])) else "Keep an inn supplied."
			world._push_event("A %s starved. %s" % [world.catalog.unit(worker["type"])["display_name"], advice])


static func handle_idle(world: Variant, worker: Dictionary) -> bool:
	if not String(worker["carrying"]).is_empty():
		return false
	if InnFeedingClass.handle_idle(world, worker):
		return true
	if world.is_worker_work_paused(worker):
		return false
	if worker["type"] == "recruit":
		var station: int = int(worker["home_id"])
		if station != 0 and not world.owns_workplace(worker, station):
			station = 0
			worker["home_id"] = 0
		var barracks: int = world._nearest_building("barracks", worker["position"], {}, true)
		# Existing tower guards keep their posts. New recruits fill an empty
		# tower only when no barracks is waiting for equipment recruitment.
		if station == 0 and (barracks == 0 or (world.buildings[barracks]["service_queue"] as Array).is_empty()):
			var ids: Array = world.buildings.keys()
			ids.sort()
			for id: int in ids:
				var tower: Dictionary = world.buildings[id]
				if tower["type"] != "watchtower" or not world.is_building_enabled(tower) or not complete(tower):
					continue
				if WorkplacesClass.can_claim(world, worker, id):
					var route: Array[Vector2i] = Pathfinder.find_path(world.grid, worker["position"], tower["entrance"])
					if worker["position"] == tower["entrance"] or not route.is_empty():
						station = id
						WorkplacesClass.claim(world, worker, id)
						break
		if station == 0:
			station = barracks
		if station != 0 and int(worker.get("inside_building_id", 0)) != station:
			worker["action"] = "report_barracks"
			worker["destination_id"] = station
			var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
			blockers.erase(world.buildings[station]["entrance"])
			if world._move_worker_to(worker, world.buildings[station]["entrance"], blockers):
				return true
			world._reset_worker(worker)
	return false


static func arrive(world: Variant, worker: Dictionary) -> bool:
	if worker["action"] == "build_site":
		worker["state"] = "working"
		return true
	if worker["action"] == "report_barracks":
		var station: int = int(worker["destination_id"])
		if world.buildings.has(station) and complete(world.buildings[station]) \
				and not world._enter_worker_building(worker, station):
			worker["state"] = "moving"
			return true
		world._reset_worker(worker)
		return true
	return InnFeedingClass.arrive(world, worker)
