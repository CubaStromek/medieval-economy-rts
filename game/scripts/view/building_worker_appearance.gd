class_name BuildingWorkerAppearance
extends RefCounted

## Local support contact and sheltered light for a registered building worker.
## Coordinates are source pixels, independent of the building's canvas scale.
## These draw-only shadows never become worker silhouettes or selection masks.
static var _contact_texture: GradientTexture2D


static func valid(config: Variant) -> bool:
	if not config is Dictionary:
		return false
	for key: String in ["shade_top", "shade_bottom"]:
		if config.has(key) and not _numbers(config[key], 3, 0.0, 1.0):
			return false
	var contacts: Variant = config.get("contact_shadows", [])
	if not contacts is Array:
		return false
	for contact: Variant in contacts:
		if not contact is Dictionary or not _numbers(contact.get("center"), 2) \
			or not _numbers(contact.get("size"), 2) or not _number(contact.get("opacity")):
			return false
		if float(contact["size"][0]) <= 0.0 or float(contact["size"][1]) <= 0.0 \
			or float(contact["opacity"]) < 0.0 or float(contact["opacity"]) > 1.0:
			return false
	return true


static func draw_contact(canvas: CanvasItem, rect: Rect2, texture_size: Vector2, config: Dictionary) -> void:
	if not valid(config) or not rect.has_area() or not texture_size.is_finite() \
		or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var source_scale: Vector2 = rect.size / texture_size
	for contact: Dictionary in config.get("contact_shadows", []):
		var center: Vector2 = rect.position + _point(contact["center"]) * source_scale
		var size: Vector2 = _point(contact["size"]) * source_scale
		# The ellipse may extend beyond the sprite canvas. Its source anchor
		# is a measured support contact, never a changing frame alpha bound.
		canvas.draw_texture_rect(_soft_contact(), Rect2(center - size * 0.5, size), false,
			Color(0.04, 0.035, 0.025, float(contact["opacity"])))


static func draw_body(canvas: CanvasItem, texture: Texture2D, rect: Rect2, config: Dictionary,
		quads: Array[Dictionary] = []) -> void:
	if texture == null or not rect.has_area():
		return
	if not valid(config) or (quads.is_empty() and config.is_empty()):
		canvas.draw_texture_rect(texture, rect, false)
		return
	var top: Color = _shade(config.get("shade_top", [1.0, 1.0, 1.0]))
	var bottom: Color = _shade(config.get("shade_bottom", [1.0, 1.0, 1.0]))
	if not quads.is_empty():
		for quad: Dictionary in quads:
			var colors := PackedColorArray()
			for coordinate: Vector2 in quad["uv"]:
				colors.append(top.lerp(bottom, coordinate.y))
			# Breathing changes geometry only. Light remains tied to the same
			# source UV rows, so adjacent strips have identical seam colors.
			canvas.draw_polygon(quad["points"], colors, quad["uv"], texture)
		return
	var points := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.end, rect.position + Vector2(0, rect.size.y)])
	var uv := PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)])
	# Vertex alpha remains one, preserving the sprite's own cutout. The parent
	# CanvasItem already supplies the time-of-day tint; do not multiply it twice.
	canvas.draw_polygon(points, PackedColorArray([top, top, bottom, bottom]), uv, texture)


static func _soft_contact() -> Texture2D:
	if _contact_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.68, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.64),
			Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
		_contact_texture = GradientTexture2D.new()
		_contact_texture.width = 64
		_contact_texture.height = 64
		_contact_texture.gradient = gradient
		_contact_texture.fill = GradientTexture2D.FILL_RADIAL
		_contact_texture.fill_from = Vector2(0.5, 0.5)
		_contact_texture.fill_to = Vector2(1.0, 0.5)
	return _contact_texture


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _numbers(value: Variant, count: int, minimum: float = -INF, maximum: float = INF) -> bool:
	if not value is Array or value.size() != count:
		return false
	for component: Variant in value:
		if not _number(component) or float(component) < minimum or float(component) > maximum:
			return false
	return true


static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _shade(value: Array) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2]), 1.0)
