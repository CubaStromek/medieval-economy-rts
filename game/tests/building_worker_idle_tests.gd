extends RefCounted

const Idle = preload("res://scripts/view/building_worker_idle.gd")
const Appearance = preload("res://scripts/view/building_worker_appearance.gd")
const RestTexture = preload("res://art/buildings/sawmill/v1/life/look/center.png")
const TEST_COUNT := 3
const NATIVE_PIXEL_TEST_COUNT := 1
const SOURCE_SIZE := Vector2(256, 256)


class IdleCanvas extends Node2D:

	var texture: Texture2D = RestTexture
	var motion: Dictionary = {}
	var use_idle := true
	var show_contact := true
	var body_rect := Rect2(16, 16, 256, 256)
	var appearance := {
		"shade_top": [0.75, 0.72, 0.65], "shade_bottom": [1.0, 1.0, 1.0],
		"contact_shadows": [{"center": [133.02734375, 205.1171875], "size": [44, 10], "opacity": 0.55}],
	}


	func _draw() -> void:
		draw_rect(Rect2(0, 0, 288, 288), Color(0.65, 0.7, 0.55, 1.0))
		if show_contact:
			Appearance.draw_contact(self, body_rect, texture.get_size(), appearance)
		if use_idle:
			Appearance.draw_body(self, texture, body_rect, appearance,
				Idle.quads(body_rect, texture.get_size(), motion))
		else:
			Appearance.draw_body(self, texture, body_rect, appearance)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_validation(failures)
	_test_registration_and_inverse(failures)
	if DisplayServer.get_name() == "headless":
		print("BUILDING WORKER IDLE: native pixel case SKIPPED (headless); validation and geometry only")
	else:
		await _test_native_fixed_body(host, failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _config() -> Dictionary:
	return {"cycle_seconds": 4.8, "upper_body_end_y": 108.0,
		"fixed_from_y": 142.0, "offset_px": [0.6, -1.5]}


static func _forced_sample(offset: Vector2) -> Dictionary:
	return {"source_offset": offset, "amount": 0.0 if offset == Vector2.ZERO else 1.0,
		"cycle_seconds": 4.8, "upper_body_end_y": 108.0, "fixed_from_y": 142.0}


static func _test_validation(failures: Array[String]) -> void:
	_check(Idle.valid({}, SOURCE_SIZE) and Idle.valid(_config(), SOURCE_SIZE),
		"Idle motion must support both disabled legacy data and the measured resting-carpenter bands", failures)
	var boundary: Dictionary = _config()
	boundary["upper_body_end_y"] = 0
	boundary["fixed_from_y"] = 256
	boundary["offset_px"] = [0, 0]
	_check(Idle.valid(boundary, SOURCE_SIZE), "Finite zero displacement and texture-edge bands must be valid", failures)
	for malformed: Variant in [null, [], "idle"]:
		_check(not Idle.valid(malformed, SOURCE_SIZE), "Idle motion must reject a non-dictionary configuration", failures)
	for change: Dictionary in [
		{"cycle_seconds": 0}, {"cycle_seconds": -1}, {"cycle_seconds": INF}, {"cycle_seconds": "4.8"},
		{"upper_body_end_y": -1}, {"upper_body_end_y": NAN}, {"upper_body_end_y": true},
		{"fixed_from_y": 108}, {"fixed_from_y": 107}, {"fixed_from_y": 257},
		{"offset_px": [0.6]}, {"offset_px": [0.6, -1.5, 0]},
		{"offset_px": [false, -1.5]}, {"offset_px": [0.6, NAN]},
		{"offset_px": [0.6, 17]}, {"offset_px": [0.6, -17]},
	]:
		var invalid: Dictionary = _config()
		invalid.merge(change, true)
		_check(not Idle.valid(invalid, SOURCE_SIZE),
			"Idle motion must reject malformed, nonfinite or folding geometry: %s" % [change], failures)
	for size: Vector2 in [Vector2.ZERO, Vector2(-1, 256), Vector2(256, INF)]:
		_check(not Idle.valid(_config(), size), "Enabled idle motion requires a finite positive source canvas", failures)


static func _test_registration_and_inverse(failures: Array[String]) -> void:
	var config: Dictionary = _config()
	var rect := Rect2(13, 29, 512, 384)
	var peak: Dictionary = _forced_sample(Vector2(0.6, -1.5))
	_check(Idle.sample({}, 12.0, 7).is_empty() and Idle.quads(rect, SOURCE_SIZE, {}).is_empty(),
		"Empty idle metadata must retain the legacy drawing path", failures)
	var outside := Vector2(-3, 260)
	_check(Idle.source_at(outside, SOURCE_SIZE, {}) == outside,
		"Disabled idle picking must preserve even coordinates outside the source canvas", failures)
	var first: Dictionary = Idle.sample(config, 0.73, 29)
	var repeated: Dictionary = Idle.sample(config, 0.73, 29)
	var cycle: Dictionary = Idle.sample(config, 0.73 + 4.8, 29)
	_check(not first.is_empty() and first == repeated,
		"A paused worker sampled at the same time and ID must retain exactly the same geometry", failures)
	if not first.is_empty() and not cycle.is_empty():
		_check((first["source_offset"] as Vector2).distance_to(cycle["source_offset"]) < 0.00001
			and absf(float(first["amount"]) - float(cycle["amount"])) < 0.00001,
			"Idle displacement must repeat after its declared cycle", failures)
	var minimum := 1.0
	var maximum := 0.0
	for tick: int in range(32):
		var value: Dictionary = Idle.sample(config, float(tick) * 4.8 / 32.0, 29)
		_check(not value.is_empty(), "Enabled idle motion must yield a complete sample", failures)
		if value.is_empty():
			continue
		var amount: float = float(value["amount"])
		minimum = minf(minimum, amount)
		maximum = maxf(maximum, amount)
		_check(amount >= 0.0 and amount <= 1.0
			and (value["source_offset"] as Vector2).distance_to(Vector2(0.6, -1.5) * amount) < 0.00001,
			"The quiet cycle must remain within its measured displacement instead of scaling the complete body", failures)
	_check(maximum - minimum > 0.98, "A full sampled cycle needs real motion, including near-neutral and near-peak phases", failures)
	# Explicit source/deformed pairs cover both moving canvas edges, both band
	# boundaries, the blend midpoint and the independently measured foot anchor.
	for pair: Array in [
		[Vector2(100, 40), Vector2(100.6, 38.5)],
		[Vector2(60, 108), Vector2(60.6, 106.5)],
		[Vector2(140, 125), Vector2(140.3, 124.25)],
		[Vector2(0.1, 0.1), Vector2(0.7, -1.4)],
		[Vector2(255.9, 60), Vector2(256.5, 58.5)],
		[Vector2(90, 142), Vector2(90, 142)],
		[Vector2(133.02734375, 205.1171875), Vector2(133.02734375, 205.1171875)],
	]:
		_check(Idle.source_at(pair[1], SOURCE_SIZE, peak).distance_to(pair[0]) < 0.0001,
			"Inverse idle picking must recover the original source coordinate, including translated edges and fixed feet: %s" % [pair], failures)
	var falling: Dictionary = _forced_sample(Vector2(-0.6, 1.5))
	_check(Idle.source_at(Vector2(139.7, 125.75), SOURCE_SIZE, falling).distance_to(Vector2(140, 125)) < 0.0001,
		"Inverse blending must also recover a valid downward displacement", failures)
	var quads: Array[Dictionary] = Idle.quads(rect, SOURCE_SIZE, peak)
	_check(not quads.is_empty(), "A peak displacement must create actual deformed drawing geometry", failures)
	var saw_top := false
	var saw_fixed_boundary := false
	var saw_bottom := false
	for quad: Dictionary in quads:
		var points: PackedVector2Array = quad["points"]
		var uv: PackedVector2Array = quad["uv"]
		_check(points.size() == 4 and uv.size() == 4, "Each idle band must expose four matched texture and world vertices", failures)
		if points.size() != 4 or uv.size() != 4:
			continue
		for index: int in range(4):
			var source: Vector2 = uv[index] * SOURCE_SIZE
			var original: Vector2 = rect.position + source * Vector2(2.0, 1.5)
			if is_equal_approx(source.y, 0.0):
				saw_top = true
				_check(points[index].distance_to(original + Vector2(1.2, -2.25)) < 0.0001,
					"The upper silhouette must translate using source-to-world scale without shrinking", failures)
			if source.y >= 142.0:
				saw_fixed_boundary = saw_fixed_boundary or is_equal_approx(source.y, 142.0)
				saw_bottom = saw_bottom or is_equal_approx(source.y, 256.0)
				_check(points[index].distance_to(original) < 0.0001,
					"Every lower-band vertex must retain its original world registration", failures)
	_check(saw_top and saw_fixed_boundary and saw_bottom,
		"The delivered mesh must cover both the moving silhouette and the complete fixed lower band", failures)


static func _capture(host: Node, viewport: SubViewport, canvas: IdleCanvas) -> Image:
	canvas.queue_redraw()
	for _frame: int in range(2):
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


static func _difference(first: Image, second: Image, region: Rect2i) -> int:
	var count := 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				count += 1
	return count


static func _test_native_fixed_body(host: Node, failures: Array[String]) -> void:
	_check(RestTexture.get_size() == SOURCE_SIZE,
		"Idle raster proof must load the real own 256x256 center resting carpenter", failures)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(288, 288)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var canvas := IdleCanvas.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	var original_source: PackedByteArray = canvas.texture.get_image().get_data()
	canvas.use_idle = false
	var legacy: Image = await _capture(host, viewport, canvas)
	canvas.use_idle = true
	canvas.motion = {}
	var empty: Image = await _capture(host, viewport, canvas)
	canvas.motion = _forced_sample(Vector2.ZERO)
	var neutral: Image = await _capture(host, viewport, canvas)
	canvas.motion = _forced_sample(Vector2(0.6, -1.5))
	var peak: Image = await _capture(host, viewport, canvas)
	canvas.show_contact = false
	var no_contact: Image = await _capture(host, viewport, canvas)
	for image: Image in [legacy, empty, neutral, peak, no_contact]:
		if image == null or image.is_empty() or image.get_size() != Vector2i(288, 288):
			_check(false, "Idle pixel assertions require all five actual native captures", failures)
			viewport.free()
			return
	_check(legacy.get_data() == empty.get_data() and legacy.get_data() == neutral.get_data(),
		"Disabled and neutral idle geometry must match the existing appearance helper raster exactly", failures)
	var shoulder_region := Rect2i(16 + 96, 16 + 90, 60, 18)
	var shoulder_changes: int = _difference(neutral, peak, shoulder_region)
	_check(shoulder_changes > 12,
		"The actual same-texture resting carpenter must visibly move its shoulder pixels at peak breathing", failures)
	var lower_region := Rect2i(0, 16 + 142, 288, 288 - (16 + 142))
	_check(neutral.get_region(lower_region).get_data() == peak.get_region(lower_region).get_data(),
		"All rendered pixels from fixed source y=142 downward, including legs, boots and contact shadows, must remain byte-identical", failures)
	_check(_difference(peak, no_contact, lower_region) > 12,
		"Unchanged contact-shadow proof needs a visible positive control against the same body with no contact draw", failures)
	_check(canvas.texture == RestTexture and canvas.texture.get_image().get_data() == original_source,
		"Breathing must deform the same center texture without changing its identity, head-look frame or shared source pixels", failures)
	print("BUILDING WORKER IDLE NATIVE: shoulder changed pixels=%d; fixed lower pixels changed=%d; contact positive pixels=%d" % [
		shoulder_changes, _difference(neutral, peak, lower_region), _difference(peak, no_contact, lower_region)])
	viewport.free()
