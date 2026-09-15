class_name LumberjackPresentation
extends RefCounted

## Selects authored animation from observed simulation data. The small cache is
## local to the view; it never writes worker fields, performs work or enters saves.
const TICK_SECONDS: float = 0.1
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const WALK_STRIDE_WORLD_PX: float = 16.0
const WALK_CYCLE_SECONDS: float = 0.8
const CHOP_CYCLE_SECONDS: float = 4.0 / 3.0
const DEFAULT_DIRECTION := "S"
const DIRECTIONS := {
	Vector2i(0, -1): "N", Vector2i(1, -1): "NE", Vector2i(1, 0): "E",
	Vector2i(1, 1): "SE", Vector2i(0, 1): "S", Vector2i(-1, 1): "SW",
	Vector2i(-1, 0): "W", Vector2i(-1, -1): "NW",
}

var _workers: Dictionary = {}
var _world_id: int = 0
var _last_tick: int = -1


func reset() -> void:
	_workers.clear()
	_world_id = 0
	_last_tick = -1


func sample(world: Variant, worker: Dictionary, frame_alpha: float) -> Dictionary:
	if world == null or String(worker.get("type", "")) != "lumberjack":
		return {"visible": false, "handled": false}
	_sync_world(world)
	if world.is_worker_inside(worker) or not world.is_entity_visible(worker):
		var hidden: Dictionary = _workers.get(int(worker.get("id", 0)), {})
		hidden.erase("walk_position")
		hidden.erase("work_token")
		return {"visible": false, "handled": true}
	var alpha: float = clampf(frame_alpha, 0.0, 1.0) if is_finite(frame_alpha) else 0.0
	var worker_id: int = int(worker.get("id", 0))
	var record: Dictionary = _workers.get(worker_id, {})
	var position: Vector2i = worker.get("position", Vector2i.ZERO)
	var previous: Vector2i = worker.get("previous_position", position)
	var arrival: Vector2i = position - previous
	var direction: String = direction_for_vector(arrival, String(record.get("direction", DEFAULT_DIRECTION)))
	var duration: int = maxi(1, int(worker.get("visual_duration_ticks", 1)))
	var moving: bool = arrival != Vector2i.ZERO and int(worker.get("visual_progress_ticks", duration)) < duration
	var cargo: String = String(worker.get("carrying", ""))
	var tree: Dictionary = world.trees.get(int(worker.get("source_id", 0)), {})
	var chopping: bool = not moving and cargo.is_empty() \
		and String(worker.get("state", "")) == "working" \
		and String(worker.get("action", "")) == "harvest" \
		and int(worker.get("work_remaining", 0)) > 0 \
		and not tree.is_empty() and int(tree.get("amount", 0)) > 0 \
		and world.is_tree_mature(tree) and world.can_worker_work(worker)
	var clip: String = "walk_log" if cargo == "log" else "walk_axe"
	var progress: float = clampf((float(clampi(int(worker.get("visual_progress_ticks", duration)), 0, duration)) + alpha) / float(duration), 0.0, 1.0)
	var distance: float = _observed_walk_distance(world, record, previous, position, progress, moving, float(world.tick) + alpha)
	var seconds: float = distance / WALK_STRIDE_WORLD_PX * WALK_CYCLE_SECONDS
	var work_progress: float = 0.0
	var work_cycles: int = 0
	if chopping:
		clip = "chop"
		# Harvest currently arrives in the tree's own cell. Its zero vector must
		# preserve the committed arrival direction, not invent an adjacent cell.
		direction = direction_for_vector((tree["position"] as Vector2i) - position, direction)
		var total: int = maxi(1, int(world.catalog.unit("lumberjack").get("harvest_ticks", 30)))
		var completed: int = clampi(total - int(worker["work_remaining"]), 0, total)
		var token := Vector3i(int(worker.get("task_id", 0)), int(worker.get("source_id", 0)), total)
		var elapsed_ticks: float = _observed_work_ticks(record, token, int(world.tick), completed, alpha)
		work_progress = elapsed_ticks / float(total)
		work_cycles = maxi(1, roundi(float(total) * TICK_SECONDS / CHOP_CYCLE_SECONDS))
		seconds = work_progress * float(work_cycles) * CHOP_CYCLE_SECONDS
	else:
		record.erase("work_token")
	record["direction"] = direction
	_workers[worker_id] = record
	return {
		"visible": true, "handled": true, "clip": clip, "direction": direction,
		"elapsed_seconds": seconds, "at_rest": not moving and not chopping,
		"moving": moving, "chopping": chopping, "work_progress": work_progress,
		"work_cycles": work_cycles, "distance_world_px": distance,
	}


static func direction_for_vector(vector: Vector2i, fallback: String = DEFAULT_DIRECTION) -> String:
	return String(DIRECTIONS.get(Vector2i(signi(vector.x), signi(vector.y)),
		fallback if fallback in DIRECTIONS.values() else DEFAULT_DIRECTION))


func _sync_world(world: Variant) -> void:
	var identity: int = world.get_instance_id()
	var tick: int = int(world.tick)
	if identity != _world_id or tick < _last_tick:
		reset()
	if tick != _last_tick:
		for id: int in _workers.keys():
			if not world.workers.has(id):
				_workers.erase(id)
	_world_id = identity
	_last_tick = tick


static func _project(world: Variant, ground: Vector2) -> Vector2:
	return MapProjectionClass.project_grid_position(ground, world.grid.height_at(ground + Vector2(0.5, 0.5)))


static func _observed_walk_distance(world: Variant, record: Dictionary, previous: Vector2i, position: Vector2i, progress: float, moving: bool, clock: float) -> float:
	var distance: float = float(record.get("walk_distance", 0.0))
	if record.has("walk_position") and clock <= float(record["walk_clock"]):
		return distance
	var current: Vector2 = _project(world, Vector2(previous).lerp(Vector2(position), progress))
	if not record.has("walk_position"):
		if moving:
			distance += _project(world, Vector2(previous)).distance_to(current)
	elif moving or bool(record["walk_moving"]):
		var last: Vector2 = record["walk_position"]
		if previous == record["walk_from"] and position == record["walk_to"]:
			distance += last.distance_to(current)
		elif previous == record["walk_to"]:
			# Split at the shared corner, not a chord across a direction change.
			var corner: Vector2 = _project(world, Vector2(previous))
			distance += last.distance_to(corner) + corner.distance_to(current)
		elif moving:
			# An unseen route/reset has no reliable history. Keep the accumulated
			# phase and account only for this observed edge, never a teleport.
			distance += _project(world, Vector2(previous)).distance_to(current)
	record["walk_distance"] = distance
	record["walk_position"] = current
	record["walk_from"] = previous
	record["walk_to"] = position
	record["walk_moving"] = moving
	record["walk_clock"] = clock
	return distance


static func _observed_work_ticks(record: Dictionary, token: Vector3i, tick: int, completed: int, alpha: float) -> float:
	var previous: int = completed
	if record.get("work_token") == token:
		var last_tick: int = int(record["work_tick"])
		var last_completed: int = int(record["work_completed"])
		if tick == last_tick and completed == last_completed:
			previous = int(record["work_previous"])
		elif tick == last_tick + 1 and completed >= last_completed:
			previous = last_completed
	# First observation, a newly assigned job or a gap in visibility starts at
	# observed progress. A skipped productive tick holds; no future work is guessed.
	record["work_token"] = token
	record["work_tick"] = tick
	record["work_completed"] = completed
	record["work_previous"] = previous
	return lerpf(float(previous), float(completed), alpha)
