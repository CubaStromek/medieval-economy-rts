class_name LumberjackWorkPlacement
extends RefCounted

## A worker and its tree share one simulation cell. Place the drawn worker
## beside the trunk inside that cell, and blend the stance along its existing
## last/first movement edge. No path, collision, work or save data is changed.
const Presentation = preload("res://scripts/view/lumberjack_presentation.gd")
const SCALE: float = 33.0 / 163.0
const SOURCE_ANCHOR := Vector2(128.0, 205.0)
const TRUNK_CONTACT_HEIGHT_WORLD_PX: float = 12.0
# Blade centres inspected in selected chop frames: N/07, NE/10, E/18,
# SE/10, S/10, SW/10, W/18, NW/10. These are fixed contact landmarks,
# not live frame bounding boxes; source PNGs and their registration stay intact.
const BLADE_CONTACT_SOURCE := {
	"N": Vector2(80, 119), "NE": Vector2(169, 140),
	"E": Vector2(188, 144), "SE": Vector2(179, 141),
	"S": Vector2(158, 154), "SW": Vector2(157, 137),
	"W": Vector2(77, 146), "NW": Vector2(95, 145),
}

var _stances: Dictionary = {}
var _world_id: int = 0
var _last_tick: int = -1


func reset() -> void:
	_stances.clear()
	_world_id = 0
	_last_tick = -1


func ground_position(world: Variant, worker: Dictionary, logical_ground: Vector2) -> Vector2:
	if world == null or String(worker.get("type", "")) != "lumberjack":
		return logical_ground
	if _world_id != world.get_instance_id() or int(world.tick) < _last_tick:
		reset()
	if int(world.tick) != _last_tick:
		for id: int in _stances.keys():
			if not world.workers.has(id):
				_stances.erase(id)
	_world_id = world.get_instance_id()
	_last_tick = int(world.tick)
	var id: int = int(worker["id"])
	if world.is_worker_inside(worker):
		_stances.erase(id)
		return logical_ground
	var cell: Vector2i = worker["position"]
	var previous: Vector2i = worker.get("previous_position", cell)
	var tree: Dictionary = world.trees.get(int(worker.get("source_id", 0)), {})
	if String(worker.get("action", "")) == "harvest" and not tree.is_empty() \
			and cell == (tree["position"] as Vector2i) and world.is_tree_mature(tree):
		var remembered: Dictionary = _stances.get(id, {})
		var direction: String = Presentation.direction_for_vector(cell - previous,
			String(remembered.get("direction", "S")))
		_stances[id] = {"cell": cell, "direction": direction, "offset": ground_offset(direction)}
	if not _stances.has(id):
		return logical_ground
	var stance: Dictionary = _stances[id]
	var source: Vector2i = stance["cell"]
	# The stored stance survives actual pickup, including depletion of the tree.
	# It vanishes continuously on the first committed departing step.
	if cell != source and previous != source:
		_stances.erase(id)
		return logical_ground
	var progress: float = 1.0
	var edge: Vector2 = Vector2(cell - previous)
	if edge.length_squared() > 0.0:
		progress = clampf((logical_ground - Vector2(previous)).dot(edge) / edge.length_squared(), 0.0, 1.0)
	var weight: float = progress if cell == source else 1.0 - progress
	weight = smoothstep(0.0, 1.0, weight)
	return logical_ground + (stance["offset"] as Vector2) * weight


static func ground_offset(direction: String) -> Vector2:
	var blade: Vector2 = BLADE_CONTACT_SOURCE.get(direction, BLADE_CONTACT_SOURCE["S"])
	var blade_from_foot: Vector2 = (blade - SOURCE_ANCHOR) * SCALE
	var offset: Vector2 = (Vector2(0, -TRUNK_CONTACT_HEIGHT_WORLD_PX) - blade_from_foot) / 40.0
	return offset.clamp(Vector2(-0.45, -0.45), Vector2(0.45, 0.45))
