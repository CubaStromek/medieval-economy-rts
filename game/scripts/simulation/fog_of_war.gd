class_name FogOfWar
extends RefCounted

const UNEXPLORED: int = 0
const EXPLORED: int = 1
const VISIBLE: int = 2
const MAX_PLAYERS: int = 16
const HISTORY_LIMIT: int = 8
const DEFAULT_SIGHT: int = 6
const TOWER_SIGHT: int = 9

var enabled: bool = false
var local_player_id: int = 1
var legacy_reveal_pending: bool = false
var map_size: Vector2i
var explored: Dictionary = {}
var visible: Dictionary = {}
var revision: int = 0
var changed_cells: Array[Vector2i] = []
var rebuild_count: int = 0
var _signature: Dictionary = {}
var _last_enabled: bool = false
var _history: Dictionary = {}


func _init(size: Vector2i = Vector2i.ZERO) -> void:
	map_size = size


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y


func state_at(cell: Vector2i) -> int:
	if not contains(cell):
		return UNEXPLORED
	if not enabled or visible.has(cell):
		return VISIBLE
	return EXPLORED if explored.has(cell) else UNEXPLORED


func is_explored(cell: Vector2i) -> bool:
	return state_at(cell) != UNEXPLORED


func is_visible(cell: Vector2i) -> bool:
	return state_at(cell) == VISIBLE


func restore_explored(cells: Array[Vector2i]) -> bool:
	var restored: Dictionary = {}
	for cell: Vector2i in cells:
		if not contains(cell) or restored.has(cell):
			return false
		restored[cell] = true
	var changed: Dictionary = {}
	if enabled:
		for cell: Vector2i in explored:
			if not restored.has(cell) and not visible.has(cell):
				changed[cell] = true
		for cell: Vector2i in restored:
			if not explored.has(cell) and not visible.has(cell):
				changed[cell] = true
	explored = restored
	_signature.clear()
	_publish(changed)
	return true


# Called once after simulation updates / at a view refresh, never per tile.
# Observer signatures avoid repainting the circles while units stand still.
func update(world: Variant) -> bool:
	var old_size: Vector2i = map_size
	var old_enabled: bool = _last_enabled
	var old_visible: Dictionary = visible
	var old_explored: Dictionary = explored
	if map_size != world.grid.size:
		map_size = world.grid.size
		explored = {}
		_signature.clear()
	var next_visible: Dictionary = {}
	if enabled:
		var sources: Dictionary = _sources(world)
		var signature: Dictionary = {"grid": world.grid.get_instance_id(), "size": map_size,
			"player": local_player_id, "sources": sources}
		if old_enabled and signature == _signature:
			return false
		_signature = signature
		rebuild_count += 1
		for source: Dictionary in sources.values():
			_reveal_circle(next_visible, source["center"], int(source["radius"]))
	else:
		_signature.clear()
		if not old_enabled and old_size == map_size:
			return false
	var changed: Dictionary = {}
	if old_enabled != enabled or old_size != map_size:
		for y: int in range(map_size.y):
			for x: int in range(map_size.x):
				var cell := Vector2i(x, y)
				var old_state: int = VISIBLE if not old_enabled else (VISIBLE if old_visible.has(cell) else (EXPLORED if old_explored.has(cell) else UNEXPLORED))
				var next_state: int = VISIBLE if not enabled else (VISIBLE if next_visible.has(cell) else (EXPLORED if explored.has(cell) else UNEXPLORED))
				if old_size != map_size or old_state != next_state:
					changed[cell] = true
	else:
		for cell: Vector2i in old_visible:
			if not next_visible.has(cell):
				changed[cell] = true
		for cell: Vector2i in next_visible:
			if not old_visible.has(cell):
				changed[cell] = true
	visible = next_visible
	for cell: Vector2i in visible:
		explored[cell] = true
	_last_enabled = enabled
	return _publish(changed)


func changes_since(previous_revision: int) -> Dictionary:
	var cells: Array[Vector2i] = []
	if previous_revision == revision:
		return {"full": false, "cells": cells}
	if previous_revision < 0 or previous_revision > revision or revision - previous_revision > HISTORY_LIMIT:
		return {"full": true, "cells": cells}
	var merged: Dictionary = {}
	for change_revision: int in range(previous_revision + 1, revision + 1):
		for cell: Vector2i in _history.get(change_revision, []):
			merged[cell] = true
	for cell: Vector2i in merged:
		cells.append(cell)
	return {"full": false, "cells": cells}


func _publish(changed: Dictionary) -> bool:
	if changed.is_empty():
		return false
	revision += 1
	changed_cells = []
	for cell: Vector2i in changed:
		changed_cells.append(cell)
	_history[revision] = changed_cells.duplicate()
	_history.erase(revision - HISTORY_LIMIT)
	return true


func _sources(world: Variant) -> Dictionary:
	var result: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		if int(worker.get("owner_id", 1)) != local_player_id or world.is_worker_inside(worker):
			continue
		var position: Vector2i = worker["position"]
		if contains(position):
			result[int(worker["id"])] = {"center": Vector2(position), "radius": DEFAULT_SIGHT}
	for building: Dictionary in world.buildings.values():
		if int(building.get("owner_id", 1)) != local_player_id or not world.is_building_complete(building):
			continue
		var cells: Array[Vector2i] = world.building_cells(building)
		if cells.is_empty():
			continue
		var low: Vector2i = cells[0]
		var high: Vector2i = cells[0]
		for cell: Vector2i in cells:
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		result[int(building["id"])] = {"center": Vector2(low + high) * 0.5,
			"radius": TOWER_SIGHT if building["type"] == "watchtower" else DEFAULT_SIGHT}
	return result


func _reveal_circle(mask: Dictionary, center: Vector2, radius: int) -> void:
	var radius_squared: float = float(radius * radius)
	for y: int in range(maxi(0, ceili(center.y - radius)), mini(map_size.y - 1, floori(center.y + radius)) + 1):
		for x: int in range(maxi(0, ceili(center.x - radius)), mini(map_size.x - 1, floori(center.x + radius)) + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_squared_to(center) <= radius_squared:
				mask[cell] = true
