extends RefCounted

const Appearance = preload("res://scripts/view/building_worker_appearance.gd")
const TEST_COUNT := 3
const NATIVE_PIXEL_TEST_COUNT := 2


class AppearanceCanvas extends Node2D:

	var texture: Texture2D
	var config: Dictionary = {}
	var paint_floor := false
	var apply_contact := false
	var legacy := false
	var body_rect := Rect2(16, 16, 64, 64)


	func _draw() -> void:
		if paint_floor:
			draw_rect(Rect2(0, 0, 96, 96), Color(0.65, 0.7, 0.55, 1.0))
		if apply_contact:
			Appearance.draw_contact(self, body_rect, texture.get_size(), config)
		if legacy:
			draw_texture_rect(texture, body_rect, false)
		else:
			Appearance.draw_body(self, texture, body_rect, config)


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_validation(failures)
	if DisplayServer.get_name() == "headless":
		print("BUILDING WORKER APPEARANCE: 2 native pixel cases SKIPPED (headless); validation only")
		return failures
	await _test_gradient_and_alpha(host, failures)
	await _test_contact_and_legacy(host, failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _test_validation(failures: Array[String]) -> void:
	for config: Dictionary in [{}, {"shade_top": [0, 0.5, 1]},
		{"shade_bottom": [1, 1, 1], "contact_shadows": []},
		{"contact_shadows": [{"center": [-3, 32], "size": [4, 2], "opacity": 0}]}]:
		_check(Appearance.valid(config), "Worker appearance must accept optional fields and finite boundary values: %s" % [config], failures)
	for config: Variant in [null, [], "appearance",
		{"shade_top": [1, 1]}, {"shade_bottom": [1, 1, 1, 1]},
		{"shade_top": [true, 1, 1]}, {"shade_top": ["1", 1, 1]},
		{"shade_top": [NAN, 1, 1]}, {"shade_bottom": [1, INF, 1]},
		{"shade_top": [-0.01, 1, 1]}, {"shade_bottom": [1, 1.01, 1]},
		{"contact_shadows": {}}, {"contact_shadows": [42]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, 2]}]},
		{"contact_shadows": [{"center": [1], "size": [4, 2], "opacity": 0.5}]},
		{"contact_shadows": [{"center": [INF, 2], "size": [4, 2], "opacity": 0.5}]},
		{"contact_shadows": [{"center": [1, 2], "size": [-4, 2], "opacity": 0.5}]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, 0], "opacity": 0.5}]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, NAN], "opacity": 0.5}]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, 2], "opacity": "0.5"}]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, 2], "opacity": INF}]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, 2], "opacity": -0.1}]},
		{"contact_shadows": [{"center": [1, 2], "size": [4, 2], "opacity": 1.1}]}]:
		_check(not Appearance.valid(config), "Worker appearance must reject malformed or nonfinite data: %s" % [config], failures)


static func _fixture(host: Node) -> Dictionary:
	# Uniform opaque color with clear padding makes the raster assertions
	# independent of authored art, imported mipmaps and the helper's algorithm.
	var source := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.fill_rect(Rect2i(8, 4, 16, 24), Color(0.8, 0.6, 0.4, 1.0))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var canvas := AppearanceCanvas.new()
	canvas.texture = ImageTexture.create_from_image(source)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	return {"viewport": viewport, "canvas": canvas, "source": source.get_data()}


static func _capture(host: Node, fixture: Dictionary) -> Image:
	var canvas: AppearanceCanvas = fixture["canvas"]
	canvas.queue_redraw()
	for _frame: int in range(2):
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport: SubViewport = fixture["viewport"]
	return viewport.get_texture().get_image()


static func _readable(image: Image, failures: Array[String]) -> bool:
	var ok: bool = image != null and not image.is_empty() and image.get_size() == Vector2i(96, 96)
	_check(ok, "Worker appearance pixel checks require a real 96x96 native render", failures)
	return ok


static func _test_gradient_and_alpha(host: Node, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(host)
	var canvas: AppearanceCanvas = fixture["canvas"]
	canvas.legacy = true
	var plain: Image = await _capture(host, fixture)
	canvas.legacy = false
	canvas.config = {"shade_top": [0.35, 0.35, 0.35], "shade_bottom": [0.95, 0.95, 0.95]}
	var shaded: Image = await _capture(host, fixture)
	if _readable(plain, failures) and _readable(shaded, failures):
		var top: Color = shaded.get_pixel(48, 29)
		var bottom: Color = shaded.get_pixel(48, 67)
		var reference: Color = plain.get_pixel(48, 29)
		_check(reference.a > 0.99 and reference.r > reference.g and reference.g > reference.b
			and reference.r > 0.75,
			"Gradient positive control must render the known opaque warm source color", failures)
		_check(top.r + 0.15 < bottom.r and top.g + 0.1 < bottom.g and top.b + 0.06 < bottom.b,
			"The actual worker raster must shade its top more strongly than its bottom in every channel", failures)
		_check(top.r < reference.r - 0.15 and bottom.r < reference.r - 0.01,
			"Configured shading must visibly affect the opaque body rather than only exposing metadata", failures)
		var alpha_changes := 0
		var outside_tint := 0
		for y: int in range(96):
			for x: int in range(96):
				var before: Color = plain.get_pixel(x, y)
				var after: Color = shaded.get_pixel(x, y)
				if absf(before.a - after.a) > 0.004:
					alpha_changes += 1
				if before.a < 0.001 and (after.a > 0.001 or after.r > 0.004 or after.g > 0.004 or after.b > 0.004):
					outside_tint += 1
		_check(alpha_changes == 0 and outside_tint == 0,
			"Body gradient must preserve every alpha pixel and leave transparent padding unpainted", failures)
		_check(canvas.texture.get_image().get_data() == fixture["source"],
			"Presentation shading must leave the shared source texture unchanged", failures)
	(fixture["viewport"] as SubViewport).free()


static func _test_contact_and_legacy(host: Node, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture(host)
	var canvas: AppearanceCanvas = fixture["canvas"]
	canvas.paint_floor = true
	canvas.legacy = true
	var legacy: Image = await _capture(host, fixture)
	canvas.legacy = false
	canvas.apply_contact = true
	var empty: Image = await _capture(host, fixture)
	canvas.config = {"contact_shadows": [{"center": [16, 28], "size": [28, 10], "opacity": 0.6}]}
	canvas.apply_contact = false
	var disabled: Image = await _capture(host, fixture)
	canvas.apply_contact = true
	var contact: Image = await _capture(host, fixture)
	if _readable(legacy, failures) and _readable(empty, failures) and _readable(disabled, failures) and _readable(contact, failures):
		_check(legacy.get_data() == empty.get_data(),
			"Empty appearance, including an invoked empty contact draw, must match the legacy raster exactly", failures)
		_check(legacy.get_data() == disabled.get_data(),
			"Contact metadata must not tint the body or floor until the separate contact draw is invoked", failures)
		# Source (16, 30) maps to screen (48, 76): below the opaque body's
		# source y=28 edge but inside the authored ellipse. This also catches
		# accidentally treating source-space contact geometry as screen pixels.
		var floor_before: Color = disabled.get_pixel(48, 76)
		var floor_after: Color = contact.get_pixel(48, 76)
		_check(floor_before.get_luminance() - floor_after.get_luminance() > 0.025
			and floor_after.a > 0.99,
			"Invoked contact shadow must darken real floor pixels outside the opaque body at the registered source-space location", failures)
		_check(contact.get_pixel(48, 68) == disabled.get_pixel(48, 68),
			"The opaque body must cover its contact shadow without receiving a second dark tint", failures)
		_check(contact.get_pixel(8, 88) == disabled.get_pixel(8, 88),
			"Contact shadow must leave floor outside its local bounds unchanged", failures)
	(fixture["viewport"] as SubViewport).free()
