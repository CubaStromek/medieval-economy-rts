class_name SoldierFoodSupply
extends RefCounted

const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const NutritionClass = preload("res://scripts/simulation/nutrition.gd")
const FOOD: Array[String] = ["bread", "sausage", "wine", "fish"]
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]


static func request_food(world: Variant, unit_id: int) -> bool:
	var soldier: Dictionary = world.workers.get(unit_id, {})
	if not world.economy_enabled or not _is_soldier(world, soldier) \
		or bool(soldier.get("food_requested", false)) \
		or int(soldier.get("hunger", 0)) >= _request_threshold(world):
		return false
	soldier["food_requested"] = true
	return true


static func source_reserved(world: Variant, building_id: int, ware: String, except_worker: int = 0) -> int:
	var result: int = 0
	for carrier: Dictionary in world.workers.values():
		if int(carrier["id"]) == except_worker:
			continue
		var mission: Dictionary = carrier.get("ration_delivery", {})
		if mission.get("phase", "") == "pickup" and int(mission.get("source_id", 0)) == building_id \
			and mission.get("ware", "") == ware:
			result += 1
	return result


static func handle_idle(world: Variant, worker: Dictionary) -> bool:
	if not (worker.get("ration_delivery", {}) as Dictionary).is_empty():
		return resume(world, worker)
	if not world.economy_enabled or worker["type"] != "carrier" or not String(worker["carrying"]).is_empty():
		return false
	var ids: Array = world.workers.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var hunger_a: int = int(world.workers[a]["hunger"])
		var hunger_b: int = int(world.workers[b]["hunger"])
		return hunger_a < hunger_b or (hunger_a == hunger_b and a < b)
	)
	for id: int in ids:
		var soldier: Dictionary = world.workers[id]
		if not _requested(world, soldier) or _assigned_carrier(world, id) != 0:
			continue
		var offer: Dictionary = _find_offer(world, worker, soldier)
		if offer.is_empty():
			continue
		worker["ration_delivery"] = {
			"recipient_id": id, "source_id": int(offer["source_id"]),
			"ware": String(offer["ware"]), "phase": "pickup",
		}
		if _route_pickup(world, worker):
			return true
		_cancel(world, worker)
	return false


static func arrive(world: Variant, worker: Dictionary) -> bool:
	if not ["pickup_ration", "deliver_ration"].has(String(worker["action"])):
		return false
	var mission: Dictionary = worker.get("ration_delivery", {})
	if not _valid_recipient(world, mission):
		_cancel(world, worker)
		return true
	if worker["action"] == "pickup_ration":
		var source: Dictionary = world.buildings.get(int(mission.get("source_id", 0)), {})
		var ware: String = String(mission.get("ware", ""))
		var stock: Dictionary = _source_stock(world, source, ware)
		if mission.get("phase", "") != "pickup" or not String(worker["carrying"]).is_empty() \
			or stock.is_empty() or int(stock.get(ware, 0)) - source_reserved(world, int(source.get("id", 0)), ware, int(worker["id"])) <= 0:
			_cancel(world, worker)
			return true
		# The generic movement layer permits a carrier to hand off next to an
		# occupied doorway, but never collect from a remote source.
		if not _near_cell(world, worker, source["entrance"]):
			if not _route_pickup(world, worker):
				_cancel(world, worker)
			return true
		stock[ware] = int(stock[ware]) - 1
		worker["carrying"] = ware
		mission["phase"] = "deliver"
		if not _route_deliver(world, worker):
			_cancel(world, worker)
		return true
	var soldier: Dictionary = world.workers[int(mission["recipient_id"])]
	if mission.get("phase", "") != "deliver" or worker["carrying"] != mission.get("ware", ""):
		_cancel(world, worker)
		return true
	if not _near_soldier(world, worker, soldier):
		if not _route_deliver(world, worker):
			_cancel(world, worker)
		return true
	NutritionClass.restore_food(world, soldier, maxi(0, int(world.catalog.economy.get("condition_max", 2700)) - int(soldier["hunger"])))
	soldier["food_requested"] = false
	worker["carrying"] = ""
	worker["ration_delivery"] = {}
	world._reset_worker(worker)
	return true


static func resume(world: Variant, worker: Dictionary) -> bool:
	var mission: Dictionary = worker.get("ration_delivery", {})
	if mission.is_empty():
		return false
	if worker["type"] != "carrier" or not _valid_recipient(world, mission):
		_cancel(world, worker)
		return true
	if mission.get("phase", "") == "pickup" and String(worker["carrying"]).is_empty():
		if not _route_pickup(world, worker):
			_cancel(world, worker)
	elif mission.get("phase", "") == "deliver" and worker["carrying"] == mission.get("ware", ""):
		if not _route_deliver(world, worker):
			_cancel(world, worker)
	else:
		_cancel(world, worker)
	return true


static func reconsider_blocked(world: Variant, worker: Dictionary) -> bool:
	return resume(world, worker)


static func tick(world: Variant) -> void:
	var ids: Array = world.workers.keys()
	ids.sort()
	var assigned: Dictionary = {}
	for id: int in ids:
		var worker: Dictionary = world.workers[id]
		if not world.is_local_entity(worker):
			continue
		var mission: Dictionary = worker.get("ration_delivery", {})
		if mission.is_empty():
			continue
		var recipient: int = int(mission.get("recipient_id", 0))
		if worker["type"] != "carrier" or not _valid_recipient(world, mission) or assigned.has(recipient):
			_cancel(world, worker)
			continue
		assigned[recipient] = id
		if mission.get("phase", "") == "pickup":
			var source: Dictionary = world.buildings.get(int(mission.get("source_id", 0)), {})
			var stock: Dictionary = _source_stock(world, source, String(mission.get("ware", "")))
			if not String(worker["carrying"]).is_empty() or stock.is_empty() \
				or int(stock.get(mission.get("ware", ""), 0)) <= 0:
				_cancel(world, worker)
		elif mission.get("phase", "") == "deliver" and worker["carrying"] == mission.get("ware", ""):
			var soldier: Dictionary = world.workers[recipient]
			var target: Vector2i = worker["target_cell"]
			var position: Vector2i = soldier["position"]
			# Finish the visible step before changing the route to a moving unit.
			if not _adjacent(target, position) and int(worker["move_cooldown"]) == 0 \
				and int(worker["visual_progress_ticks"]) >= int(worker["visual_duration_ticks"]):
				if not _route_deliver(world, worker):
					_cancel(world, worker)
		else:
			_cancel(world, worker)


static func status(world: Variant, soldier_id: int) -> String:
	var soldier: Dictionary = world.workers.get(soldier_id, {})
	if not _is_soldier(world, soldier):
		return ""
	if bool(soldier.get("food_requested", false)):
		var carrier_id: int = _assigned_carrier(world, soldier_id)
		if carrier_id == 0:
			return "Jídlo vyžádáno — čeká na zásoby a nosiče"
		var mission: Dictionary = world.workers[carrier_id]["ration_delivery"]
		return "Jídlo je na cestě" if mission["phase"] == "deliver" else "Nosič vyzvedává jídlo"
	if int(soldier["hunger"]) < _request_threshold(world):
		return "Lze vyžádat jídlo"
	return "Dostatečně najedený"


static func _is_soldier(world: Variant, worker: Dictionary) -> bool:
	return world.is_local_entity(worker) and world.catalog.soldiers.has(String(worker.get("type", "")))


static func _request_threshold(world: Variant) -> int:
	return int(world.catalog.economy.get("soldier_food_request_threshold", ceili(float(world.catalog.economy.get("condition_max", 2700)) * 0.55)))


static func _requested(world: Variant, soldier: Dictionary) -> bool:
	return _is_soldier(world, soldier) and bool(soldier.get("food_requested", false))


static func _valid_recipient(world: Variant, mission: Dictionary) -> bool:
	return FOOD.has(String(mission.get("ware", ""))) \
		and _requested(world, world.workers.get(int(mission.get("recipient_id", 0)), {}))


static func _assigned_carrier(world: Variant, recipient_id: int) -> int:
	for worker: Dictionary in world.workers.values():
		if int((worker.get("ration_delivery", {}) as Dictionary).get("recipient_id", 0)) == recipient_id:
			return int(worker["id"])
	return 0


static func _source_stock(world: Variant, source: Dictionary, ware: String) -> Dictionary:
	if source.is_empty() or not world.is_local_entity(source) or not FOOD.has(ware) or not world.is_building_complete(source) or source["type"] == "inn":
		return {}
	return source["storage"] if source["type"] == "warehouse" else source["outputs"]


static func _generic_reserved(world: Variant, source_id: int, ware: String) -> int:
	var result: int = 0
	for worker: Dictionary in world.workers.values():
		if worker["type"] == "carrier" and worker["action"] == "pickup_" + ware \
			and int(worker["source_id"]) == source_id and String(worker["carrying"]).is_empty():
			result += 1
	return result


static func _find_offer(world: Variant, worker: Dictionary, soldier: Dictionary) -> Dictionary:
	var ids: Array = world.buildings.keys()
	ids.sort()
	var best: Dictionary = {}
	var best_cost: int = 2147483647
	var start: Vector2i = worker["position"]
	for source_id: int in ids:
		var source: Dictionary = world.buildings[source_id]
		for ware: String in FOOD:
			var stock: Dictionary = _source_stock(world, source, ware)
			if int(stock.get(ware, 0)) - source_reserved(world, source_id, ware) - _generic_reserved(world, source_id, ware) <= 0:
				continue
			var entrance: Vector2i = source["entrance"]
			var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
			blockers.erase(entrance)
			var path: Array[Vector2i] = world._path_with_yielding(start, entrance, blockers, int(worker["id"]))
			if start != entrance and path.is_empty():
				continue
			var handoff: Dictionary = _handoff_route(world, worker, soldier, entrance)
			if handoff.is_empty():
				continue
			var cost: int = Pathfinder.path_cost(world.grid, path, start) + int(handoff["cost"])
			if cost < best_cost:
				best = {"source_id": source_id, "ware": ware}
				best_cost = cost
	return best


static func _route_pickup(world: Variant, worker: Dictionary) -> bool:
	var mission: Dictionary = worker["ration_delivery"]
	var source: Dictionary = world.buildings.get(int(mission.get("source_id", 0)), {})
	var ware: String = String(mission.get("ware", ""))
	var stock: Dictionary = _source_stock(world, source, ware)
	if int(stock.get(ware, 0)) - source_reserved(world, int(source.get("id", 0)), ware, int(worker["id"])) <= 0:
		return false
	worker["action"] = "pickup_ration"
	worker["source_id"] = int(source["id"])
	worker["destination_id"] = 0
	var entrance: Vector2i = source["entrance"]
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	blockers.erase(entrance)
	return world._move_worker_to(worker, entrance, blockers)


static func _route_deliver(world: Variant, worker: Dictionary) -> bool:
	var mission: Dictionary = worker["ration_delivery"]
	var soldier: Dictionary = world.workers.get(int(mission.get("recipient_id", 0)), {})
	if not _requested(world, soldier):
		return false
	var route: Dictionary = _handoff_route(world, worker, soldier, worker["position"])
	if route.is_empty():
		return false
	worker["action"] = "deliver_ration"
	worker["destination_id"] = 0
	return world._move_worker_to(worker, route["target"], world._temporary_blockers_for(int(worker["id"])))


static func _handoff_route(world: Variant, worker: Dictionary, soldier: Dictionary, from: Vector2i) -> Dictionary:
	if world.is_worker_inside(soldier):
		return {}
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	var position: Vector2i = soldier["position"]
	var best: Dictionary = {}
	var best_cost: int = 2147483647
	for offset: Vector2i in NEIGHBORS:
		var target: Vector2i = position + offset
		if not world.grid.is_walkable(target) or blockers.has(target):
			continue
		var handoff_blockers: Dictionary = blockers.duplicate()
		handoff_blockers.erase(position)
		if not world.grid.can_step(target, position, handoff_blockers):
			continue
		var path: Array[Vector2i] = world._path_with_yielding(from, target, blockers, int(worker["id"]))
		if from != target and path.is_empty():
			continue
		var cost: int = Pathfinder.path_cost(world.grid, path, from)
		if cost < best_cost:
			best = {"target": target, "cost": cost}
			best_cost = cost
	return best


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and maxi(absi(a.x - b.x), absi(a.y - b.y)) == 1


static func _near_cell(world: Variant, worker: Dictionary, cell: Vector2i) -> bool:
	var current: Vector2i = worker["position"]
	if current == cell:
		return true
	if not _adjacent(current, cell):
		return false
	var blockers: Dictionary = world._temporary_blockers_for(int(worker["id"]))
	blockers.erase(cell)
	return world.grid.can_step(current, cell, blockers)


static func _near_soldier(world: Variant, worker: Dictionary, soldier: Dictionary) -> bool:
	return not world.is_worker_inside(worker) and not world.is_worker_inside(soldier) \
		and _adjacent(worker["position"], soldier["position"]) and _near_cell(world, worker, soldier["position"])


static func _cancel(world: Variant, worker: Dictionary) -> void:
	# Cancellation releases the reservation, never returns an in-flight ware
	# to its source. Ordinary logistics must physically carry that ware onward.
	worker["ration_delivery"] = {}
	world._reset_worker(worker)
	if not String(worker["carrying"]).is_empty():
		world._resume_carried_ware(worker)
