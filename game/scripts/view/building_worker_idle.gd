class_name BuildingWorkerIdle
extends RefCounted

## Small source-space breathing motion. The head, neck and crossed arms move
## together; only the apron blends back into the fixed legs. Source pixels,
## support contacts, world positions and simulation state remain untouched.
static func valid(config: Variant, texture_size: Vector2) -> bool:
	if not config is Dictionary or not texture_size.is_finite() or texture_size.x <= 0 or texture_size.y <= 0:
		return false
	if config.is_empty():
		return true
	for key: String in ["cycle_seconds", "upper_body_end_y", "fixed_from_y"]:
		if not _number(config.get(key)):
			return false
	var offset: Variant = config.get("offset_px")
	if not offset is Array or offset.size() != 2 or not _number(offset[0]) or not _number(offset[1]):
		return false
	var upper: float = float(config["upper_body_end_y"])
	var fixed: float = float(config["fixed_from_y"])
	return float(config["cycle_seconds"]) > 0 and upper >= 0 and fixed > upper and fixed <= texture_size.y \
		and absf(float(offset[1])) < (fixed - upper) * 0.5


static func sample(config: Dictionary, time: float, worker_id: int) -> Dictionary:
	if config.is_empty() or not is_finite(time):
		return {}
	var period: float = float(config["cycle_seconds"])
	var phase: float = fposmod(time + float(worker_id) * 0.73, period) / period
	var amount: float = (1.0 - cos(phase * TAU)) * 0.5
	return {"source_offset": Vector2(config["offset_px"][0], config["offset_px"][1]) * amount,
		"amount": amount, "cycle_seconds": period, "upper_body_end_y": float(config["upper_body_end_y"]),
		"fixed_from_y": float(config["fixed_from_y"])}


static func quads(rect: Rect2, texture_size: Vector2, motion: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if motion.is_empty() or (motion["source_offset"] as Vector2).is_zero_approx():
		return result
	var rows := PackedFloat32Array([0.0, float(motion["upper_body_end_y"]), float(motion["fixed_from_y"]), texture_size.y])
	for index: int in range(rows.size() - 1):
		var top: float = rows[index]
		var bottom: float = rows[index + 1]
		if bottom <= top:
			continue
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		for source: Vector2 in [Vector2(0, top), Vector2(texture_size.x, top),
			Vector2(texture_size.x, bottom), Vector2(0, bottom)]:
			points.append(rect.position + _deform(source, motion) / texture_size * rect.size)
			uv.append(source / texture_size)
		result.append({"points": points, "uv": uv})
	return result


static func source_at(point: Vector2, _texture_size: Vector2, motion: Dictionary) -> Vector2:
	if motion.is_empty():
		return point
	var offset: Vector2 = motion["source_offset"]
	var upper: float = float(motion["upper_body_end_y"])
	var fixed: float = float(motion["fixed_from_y"])
	var source_y: float = point.y
	if point.y <= upper + offset.y:
		source_y -= offset.y
	elif point.y < fixed:
		var span: float = fixed - upper
		source_y = (point.y - offset.y * fixed / span) / (1.0 - offset.y / span)
	return Vector2(point.x - offset.x * _weight(source_y, motion), source_y)


static func _deform(point: Vector2, motion: Dictionary) -> Vector2:
	return point + (motion["source_offset"] as Vector2) * _weight(point.y, motion)


static func _weight(y: float, motion: Dictionary) -> float:
	return clampf((float(motion["fixed_from_y"]) - y) \
		/ (float(motion["fixed_from_y"]) - float(motion["upper_body_end_y"])), 0.0, 1.0)


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
