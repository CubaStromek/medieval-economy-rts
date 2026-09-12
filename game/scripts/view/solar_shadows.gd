class_name SolarShadows
extends RefCounted

# Soft silhouettes projected onto the actual heightfield. Splitting by ground
# row keeps a cast shadow above its terrain and below the people/buildings on
# that row, without rebuilding any retained terrain mesh.
const SEGMENTS: int = 24
const GROUND_SAMPLE_STEP: float = 0.20


static func rows_for(terrain: Variant, entry: Dictionary, solar: Dictionary) -> Dictionary:
	var rows: Dictionary = {}
	var opacity: float = float(solar.get("shadow_opacity", 0.0))
	if opacity <= 0.001:
		return rows
	var kind: String = String(entry["kind"])
	var state: Dictionary = entry["state"]
	if kind == "worker" and int(state.get("inside_building_id", 0)) != 0:
		return rows
	var width: float = 0.12
	var height: float = 0.48
	if kind == "tree":
		# The view's existing growth-stage policy is passed with the entry so
		# lighting never needs to infer a second simulation rule from tree age.
		var stage: int = clampi(int(entry.get("growth_stage", 2)), 0, 2)
		width = [0.09, 0.18, 0.30][stage]
		height = [0.30, 0.65, 1.25][stage]
	elif kind == "building":
		width = 0.43
		height = 0.50 if int(state.get("construction_remaining", 0)) > 0 else 1.0
	var offset: Vector2 = (solar.get("shadow_vector", Vector2.ZERO) as Vector2) * height
	if offset.length_squared() < 0.00001:
		return rows
	var axis: Vector2 = offset.normalized()
	var side := Vector2(-axis.y, axis.x)
	var center: Vector2 = (entry.get("shadow_ground_position", entry["ground_position"]) as Vector2) + offset * 0.5
	var base_radius: float = width * 0.35
	if kind == "building" and entry.has("shadow_radius"):
		var footprint: Vector2 = entry["shadow_radius"] as Vector2
		width = absf(side.x) * footprint.x + absf(side.y) * footprint.y
		base_radius = absf(axis.x) * footprint.x + absf(axis.y) * footprint.y
	var radius: float = offset.length() * 0.5 + base_radius
	var outline := PackedVector2Array()
	var low_y: float = INF
	var high_y: float = -INF
	for index: int in range(SEGMENTS):
		var angle: float = TAU * float(index) / float(SEGMENTS)
		var point: Vector2 = center + axis * cos(angle) * radius + side * sin(angle) * width
		outline.append(point)
		low_y = minf(low_y, point.y)
		high_y = maxf(high_y, point.y)
	var first: int = maxi(0, floori(low_y + 0.5))
	var last: int = mini(terrain.grid.size.y - 1, floori(high_y + 0.5))
	for row: int in range(first, last + 1):
		var strip := PackedVector2Array([
			Vector2(-0.5, row - 0.5), Vector2(terrain.grid.size.x - 0.5, row - 0.5),
			Vector2(terrain.grid.size.x - 0.5, row + 0.5), Vector2(-0.5, row + 0.5),
		])
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(outline, strip):
			if clipped.size() < 3:
				continue
			var points: PackedVector2Array = _project_outline(terrain, clipped)
			if not rows.has(row):
				rows[row] = []
			rows[row].append({
				"points": points,
				"draw_origin": points[0], "draw_points": _local_outline(points),
				"color": Color(0.035, 0.045, 0.075, opacity),
				"kind": kind, "state": state,
			})
	return rows


static func _local_outline(points: PackedVector2Array) -> PackedVector2Array:
	# Godot's polygon area/triangulation loses small tangent row clips when
	# absolute map-coordinate products cancel. Keep the exact same geometry
	# near the origin for drawing, then place it with the canvas transform.
	var local := PackedVector2Array()
	for point: Vector2 in points:
		local.append(point - points[0])
	return local


static func _project_outline(terrain: Variant, outline: PackedVector2Array) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for index: int in range(outline.size()):
		var start: Vector2 = outline[index]
		var end: Vector2 = outline[(index + 1) % outline.size()]
		var steps: int = maxi(1, ceili(start.distance_to(end) / GROUND_SAMPLE_STEP))
		for step: int in range(steps):
			projected.append(terrain.project_grid_position(start.lerp(end, float(step) / float(steps))))
	return projected
