class_name SawmillOperation
extends RefCounted

## Read-only stock and productive-work presentation. The renderer receives a
## life snapshot for this same building; it never needs another worker scan.
## This cache belongs only to the view, not to simulation objects or saves.
var _records: Dictionary = {}
var _world_id: int = 0
var _last_tick: int = -1


func reset() -> void:
	_records.clear()
	_world_id = 0
	_last_tick = -1


func observe_tick(world: Variant) -> void:
	if world == null:
		reset()
		return
	_sync_world(world)
	for building: Dictionary in world.buildings.values():
		if not _supported(world, building):
			continue
		var id: int = int(building["id"])
		# Even observing productive progress is private. Do not read a foreign
		# batch simply because its remembered house is visible through the fog.
		if world.fog.enabled and not world.is_local_entity(building):
			_records.erase(id)
			continue
		var batch: Dictionary = _batch(world, building)
		if int(batch["remaining"]) > 0:
			_record_progress(id, int(world.tick), batch)
		else:
			_records.erase(id)


func presentation_for(world: Variant, building: Dictionary, life: Dictionary,
		tick_fraction: float = 0.0) -> Dictionary:
	if world == null or not _supported(world, building):
		return {}
	_sync_world(world)
	var result: Dictionary = {"known": false, "input_amount": -1, "input_capacity": -1,
		"output_amount": -1, "output_capacity": -1, "in_process": false,
		"in_process_log_count": -1, "active_work": false, "recipe_id": "",
		"total_work_ticks": 0, "completed_work_ticks": 0, "observed_work_ticks": 0.0,
		"progress": 0.0}
	var id: int = int(building["id"])
	if world.fog.enabled and not world.is_local_entity(building):
		_records.erase(id)
		return result
	var definition: Dictionary = world.catalog.building("sawmill")
	result["known"] = true
	# These quantities are already physically delivered. Reservations, carried
	# wares, warehouses and recipe-committed timber cannot fill either rack.
	result["input_amount"] = int((building.get("inputs", {}) as Dictionary).get("log", 0))
	result["output_amount"] = int((building.get("outputs", {}) as Dictionary).get("plank", 0))
	result["input_capacity"] = int(definition.get("input_capacity", 4))
	result["output_capacity"] = int(definition.get("output_capacity", 6))
	var batch: Dictionary = _batch(world, building)
	var in_process: bool = int(batch["remaining"]) > 0
	result["in_process"] = in_process
	result["in_process_log_count"] = int(batch["input_logs"]) if in_process else 0
	result["recipe_id"] = batch["recipe_id"]
	result["total_work_ticks"] = batch["total"]
	# A retained half-finished batch survives personal pause, a missing
	# operator or a full output rack. Only the authoritative life flag animates
	# its operator; an in-progress log alone does not imply anyone is working.
	var active: bool = in_process and bool(life.get("known", false)) \
		and bool(life.get("at_home", false)) and bool(life.get("active_work", false))
	result["active_work"] = active
	if not in_process:
		_records.erase(id)
		return result
	var record: Dictionary = _record_progress(id, int(world.tick), batch)
	var completed: int = int(batch["completed"])
	var fraction: float = clampf(tick_fraction, 0.0, 1.0) if is_finite(tick_fraction) else 0.0
	var observed: float = lerpf(float(record["previous"]), float(completed), fraction) if active else float(completed)
	result["completed_work_ticks"] = completed
	result["observed_work_ticks"] = observed
	result["progress"] = observed / float(batch["total"]) if int(batch["total"]) > 0 else 0.0
	return result


## A neutral helper until individual prepare/saw/finish clips are authored.
## Six loops over today's 60 productive ticks make one loop per second at
## normal work speed; neither loop count nor frame count changes the recipe.
static func pose_index_for(operation: Dictionary, frame_count: int, cycles_per_batch: int = 6) -> int:
	if not bool(operation.get("known", false)) or not bool(operation.get("active_work", false)) \
			or not bool(operation.get("in_process", false)) or frame_count < 1 or cycles_per_batch < 1:
		return -1
	var progress: float = float(operation.get("progress", 0.0))
	if not is_finite(progress):
		return -1
	var scaled: float = clampf(progress, 0.0, 1.0) * float(cycles_per_batch) * float(frame_count)
	# An exact tick/frame boundary must not round down because 59/60 is stored
	# just below its mathematical value. The allowance is far below a subpixel
	# animation interval and does not interpolate unobserved work.
	return posmod(floori(scaled + 0.0000001), frame_count)


static func _supported(world: Variant, building: Dictionary) -> bool:
	return not building.is_empty() and String(building.get("type", "")) == "sawmill" \
		and int(building.get("footprint_version", 0)) == 1 and world.is_building_complete(building)


static func _batch(world: Variant, building: Dictionary) -> Dictionary:
	var recipe_id: String = String(building.get("recipe_id", world.catalog.building("sawmill").get("recipe", "")))
	var recipe: Dictionary = world.catalog.recipe(recipe_id)
	var total: int = maxi(1, int(recipe.get("duration_ticks", 1)))
	var remaining: int = clampi(int(building.get("process_remaining", 0)), 0, total)
	return {"recipe_id": recipe_id, "total": total, "remaining": remaining,
		"completed": total - remaining if remaining > 0 else 0,
		"input_logs": int((recipe.get("inputs", {}) as Dictionary).get("log", 0))}


func _record_progress(id: int, tick: int, batch: Dictionary) -> Dictionary:
	var completed: int = int(batch["completed"])
	var previous: int = completed
	var last: Dictionary = _records.get(id, {})
	if String(last.get("recipe_id", "")) == String(batch["recipe_id"]) and int(last.get("total", 0)) == int(batch["total"]):
		var last_completed: int = int(last.get("completed", completed))
		if tick == int(last.get("tick", -1)) and completed == last_completed:
			# Drawing and alpha picking may ask repeatedly at the same time.
			previous = int(last.get("previous", completed))
		elif tick == int(last.get("tick", -1)) + 1 and completed >= last_completed and completed <= last_completed + 1:
			previous = last_completed
	# A first observation, a new batch or an unseen gap starts from already
	# earned progress. A skipped nutritional work tick holds exactly still.
	var record: Dictionary = {"recipe_id": batch["recipe_id"], "total": batch["total"],
		"tick": tick, "completed": completed, "previous": previous}
	_records[id] = record
	return record


func _sync_world(world: Variant) -> void:
	var identity: int = world.get_instance_id()
	var tick: int = int(world.tick)
	if identity != _world_id or tick < _last_tick:
		reset()
	if tick != _last_tick:
		for id: int in _records.keys():
			if not world.buildings.has(id):
				_records.erase(id)
	_world_id = identity
	_last_tick = tick
