class_name TaskBoard
extends RefCounted

var _next_id: int = 1
var _tasks: Dictionary = {}
var _task_by_source: Dictionary = {}


func create_task(kind: String, source_key: String, target: Vector2i, source_id: int) -> int:
	if _task_by_source.has(source_key):
		return int(_task_by_source[source_key])
	var task_id: int = _next_id
	_next_id += 1
	_tasks[task_id] = {
		"id": task_id,
		"kind": kind,
		"source_key": source_key,
		"source_id": source_id,
		"target": target,
		"reserved_by": 0,
	}
	_task_by_source[source_key] = task_id
	return task_id


func reserve_next(worker_id: int, accepted_kinds: Array[String]) -> Dictionary:
	for task: Dictionary in available_tasks(accepted_kinds):
		var reserved: Dictionary = reserve_task(int(task["id"]), worker_id)
		if not reserved.is_empty():
			return reserved
	return {}


func available_tasks(accepted_kinds: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = _tasks.keys()
	ids.sort()
	for task_id_variant: Variant in ids:
		var task: Dictionary = _tasks[int(task_id_variant)] as Dictionary
		if int(task["reserved_by"]) == 0 and accepted_kinds.has(String(task["kind"])):
			result.append(task)
	return result


func reserve_task(task_id: int, worker_id: int) -> Dictionary:
	if not _tasks.has(task_id):
		return {}
	var task: Dictionary = _tasks[task_id] as Dictionary
	if int(task["reserved_by"]) != 0:
		return {}
	task["reserved_by"] = worker_id
	return task


func complete(task_id: int, worker_id: int) -> bool:
	if not _tasks.has(task_id):
		return false
	var task: Dictionary = _tasks[task_id] as Dictionary
	if int(task["reserved_by"]) != worker_id:
		return false
	_task_by_source.erase(String(task["source_key"]))
	_tasks.erase(task_id)
	return true


func release(task_id: int, worker_id: int) -> void:
	if not _tasks.has(task_id):
		return
	var task: Dictionary = _tasks[task_id] as Dictionary
	if int(task["reserved_by"]) == worker_id:
		task["reserved_by"] = 0


func active_count() -> int:
	return _tasks.size()


func reservation_count_for_source(source_key: String) -> int:
	if not _task_by_source.has(source_key):
		return 0
	var task_id: int = int(_task_by_source[source_key])
	var task: Dictionary = _tasks[task_id] as Dictionary
	return 1 if int(task["reserved_by"]) != 0 else 0


func to_data() -> Dictionary:
	var serialized: Array[Dictionary] = []
	var ids: Array = _tasks.keys()
	ids.sort()
	for task_id_variant: Variant in ids:
		var task: Dictionary = (_tasks[int(task_id_variant)] as Dictionary).duplicate(true)
		var target: Vector2i = task["target"] as Vector2i
		task["target"] = [target.x, target.y]
		serialized.append(task)
	return {"next_id": _next_id, "tasks": serialized}


func from_data(data: Dictionary) -> void:
	_next_id = int(data.get("next_id", 1))
	_tasks.clear()
	_task_by_source.clear()
	for task_variant: Variant in data.get("tasks", []):
		var task: Dictionary = (task_variant as Dictionary).duplicate(true)
		var target: Array = task["target"] as Array
		task["target"] = Vector2i(int(target[0]), int(target[1]))
		var task_id: int = int(task["id"])
		_tasks[task_id] = task
		_task_by_source[String(task["source_key"])] = task_id
