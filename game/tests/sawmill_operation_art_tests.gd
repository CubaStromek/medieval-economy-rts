extends RefCounted

const StateSuite = preload("res://tests/sawmill_operation_tests.gd")
const Art = preload("res://scripts/view/sawmill_operation_art.gd")
const Sprites = preload("res://scripts/view/sawmill_sprite_library.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT := 10


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_import_and_cache, _test_visible_stock_increments,
		_test_unknown_neutral_architecture, _test_optional_backplate, _test_capacity_fallback,
		_test_workpiece_and_registered_worker, _test_worker_space, _test_missing_and_malformed_resources,
		_test_main_art_and_hit]:
		test.call(failures)
	await _test_native_main_draw(host, failures)
	return failures


static func _check(ok: bool, message: String, failures: Array[String]) -> void:
	if not ok:
		failures.append(message)


static func _house(failures: Array[String]) -> Dictionary:
	var f: Dictionary = StateSuite._fixture()
	var house: Dictionary = Sprites.new().presentation_for(f["building"], f["world"].catalog.building("sawmill"), Vector2(400, 300))
	_check(not house.is_empty() and not (house.get("operation", {}) as Dictionary).is_empty(),
		"Art checks require the actual delivered house and its operation manifest reference", failures)
	return house


static func _op(logs: int = 0, planks: int = 0, active: bool = false) -> Dictionary:
	return {"known": true, "input_amount": logs, "input_capacity": 4, "output_amount": planks,
		"output_capacity": 6, "in_process": active, "in_process_log_count": 1 if active else 0,
		"active_work": active, "total_work_ticks": 60, "completed_work_ticks": 5,
		"observed_work_ticks": 5.0, "progress": 5.0 / 60.0}


static func _positive(house: Dictionary, operation: Dictionary, failures: Array[String]) -> Dictionary:
	# A correct empty base may require zero overlays. Prove the delivered set
	# with real full stocks and a worker before testing that empty state.
	var control: Dictionary = Art.new().presentation_for(house, _op(4, 6, true))
	_check(not control.is_empty() and not (control.get("layers", []) as Array).is_empty()
		and int(control.get("frame_index", -1)) >= 0,
		"Art regression requires actual imported stock/work assets in an active positive control", failures)
	var art: Dictionary = Art.new().presentation_for(house, operation)
	_check(not art.is_empty(), "The tested state must resolve the delivered operation metadata", failures)
	return art


static func _count_path(art: Dictionary, path: String) -> int:
	var amount: int = 0
	for layer: Dictionary in art["layers"]:
		if layer["path"] == path:
			amount += 1
	return amount


static func _image(texture: Texture2D) -> Image:
	var pixels: Image = texture.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	pixels.clear_mipmaps()
	return pixels


static func _test_import_and_cache(failures: Array[String]) -> void:
	Art.clear_cache()
	var house: Dictionary = _house(failures)
	var first: Dictionary = _positive(house, _op(4, 6, true), failures)
	if first.is_empty():
		return
	var second: Dictionary = Art.new().presentation_for(house, _op(4, 6, true))
	_check(first["layers"].size() == second["layers"].size(), "A second building must reuse the same complete authored layer set", failures)
	for index: int in range(first["layers"].size()):
		var a: Dictionary = first["layers"][index]
		var b: Dictionary = second["layers"][index]
		var mask: BitMap = a["mask"]
		_check(a["texture"] == b["texture"] and a["mask"] == b["mask"]
			and mask.get_true_bit_count() > 0 and mask.get_true_bit_count() < mask.get_size().x * mask.get_size().y
			and (a["texture"] as Texture2D).get_image().has_mipmaps(),
			"Every actual layer must share an imported texture, genuine transparent alpha and cached hit mask", failures)
	var frames: Array = first["data"]["work"]["frames"]
	var pixels_seen: Dictionary = {}
	for frame: String in frames:
		pixels_seen[hash(_image(load(frame) as Texture2D).get_data())] = true
	_check(frames.size() == 6 and pixels_seen.size() == 6,
		"The delivered work animation must contain six real, visually distinct imported poses", failures)


static func _flatten(art: Dictionary) -> Image:
	var pixels := Image.create(800, 800, false, Image.FORMAT_RGBA8)
	for layer: Dictionary in art["layers"]:
		var source: Image = _image(layer["texture"])
		var rect: Rect2 = layer["rect"]
		var size := Vector2i(rect.size.round())
		if source.get_size() != size:
			source.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
		pixels.blend_rect(source, Rect2i(Vector2i.ZERO, size), Vector2i(rect.position.round()))
	return pixels


static func _different_pixels(a: Image, b: Image) -> int:
	var count: int = 0
	# Revision-specific rack positions must not hide a valid new stock location
	# outside the previous artwork's region of interest.
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count


static func _test_visible_stock_increments(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var empty: Dictionary = _positive(house, _op(), failures)
	if empty.is_empty():
		return
	for kind: String in ["log", "plank"]:
		var previous: Image = _flatten(empty)
		var capacity: int = 4 if kind == "log" else 6
		var path: String = empty["data"]["stock"][kind]["texture"]
		_check(_count_path(empty, path) == 0, "Zero physical stock must not draw a commodity", failures)
		for amount: int in range(1, capacity + 1):
			var sample: Dictionary = Art.new().presentation_for(house, _op(amount if kind == "log" else 0, amount if kind == "plank" else 0))
			var current: Image = _flatten(sample)
			_check(_count_path(sample, path) == amount and _different_pixels(previous, current) > 40
				and int(sample["frame_index"]) == -1 and sample["fallback_labels"].is_empty(),
				"Every real %s increment 1–%d must add visibly distinct ware after foreground occlusion" % [kind, capacity], failures)
			previous = current
	for logs: int in range(5):
		for planks: int in range(7):
			var sample: Dictionary = Art.new().presentation_for(house, _op(logs, planks))
			_check(_count_path(sample, sample["data"]["stock"]["log"]["texture"]) == logs
				and _count_path(sample, sample["data"]["stock"]["plank"]["texture"]) == planks,
				"The 35 combined rack states must keep input logs and output planks independent", failures)


static func _test_unknown_neutral_architecture(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var positive: Dictionary = _positive(house, _op(4, 6, true), failures)
	if positive.is_empty():
		return
	var hidden: Dictionary = Art.new().presentation_for(house, {"known": false,
		"input_amount": Vector2.INF, "output_amount": Vector2.INF, "active_work": true,
		"in_process": true, "observed_work_ticks": Vector2.INF})
	var backplate: String = String(positive["data"]["work"].get("backplate", ""))
	var neutral_only: bool = hidden["layers"].is_empty() if backplate.is_empty() \
		else hidden["layers"].size() == 1 and hidden["layers"][0]["path"] == backplate
	_check(neutral_only and hidden["fallback_labels"].is_empty() and int(hidden["frame_index"]) == -1,
		"Unknown foreign state must keep only the neutral architecture before any private amount or work clock is read", failures)


static func _test_capacity_fallback(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var positive: Dictionary = _positive(house, _op(), failures)
	if positive.is_empty():
		return
	for sample: Array in [["input_amount", 7, "Klády 7/4", "log"], ["input_capacity", 5, "Klády 2/5", "log"],
		["output_amount", 9, "Prkna 9/6", "plank"], ["output_capacity", 8, "Prkna 2/8", "plank"]]:
		var operation: Dictionary = _op(2, 2)
		operation[sample[0]] = sample[1]
		var art: Dictionary = Art.new().presentation_for(house, operation)
		_check(art["fallback_labels"].size() == 1 and art["fallback_labels"][0]["text"] == sample[2]
			and _count_path(art, art["data"]["stock"][sample[3]]["texture"]) == 0,
			"An unsupported count/capacity must display its truthful count without a misleading capped stock pile", failures)


static func _test_optional_backplate(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var positive: Dictionary = _positive(house, _op(4, 6, true), failures)
	if positive.is_empty():
		return
	var original_path: String = positive["data"]["work"].get("backplate", "")
	var original_layer_count: int = _count_path(positive, original_path) if not original_path.is_empty() else 0
	for empty_string: bool in [false, true]:
		var data: Dictionary = positive["data"].duplicate(true)
		if empty_string:
			data["work"]["backplate"] = ""
		else:
			data["work"].erase("backplate")
		var path: String = _write_manifest(data, "optional-backplate-%s" % str(empty_string))
		var clone: Dictionary = house.duplicate(true)
		clone["operation"] = {"manifest": path}
		var active: Dictionary = Art.new().presentation_for(clone, _op(4, 6, true))
		_check(not active.is_empty() and active["layers"].size() == positive["layers"].size() - original_layer_count
			and active["frame_index"] == positive["frame_index"] and active["fallback_labels"].is_empty(),
			"An omitted or empty optional backplate must retain all real stock, workpiece and worker layers", failures)
		var unknown: Dictionary = Art.new().presentation_for(clone, {"known": false, "input_amount": Vector2.INF,
			"output_amount": Vector2.INF, "active_work": true, "observed_work_ticks": Vector2.INF})
		_check(not unknown.is_empty() and unknown["layers"].is_empty() and unknown["fallback_labels"].is_empty()
			and int(unknown["frame_index"]) == -1 and not Art.new().contains_point(unknown, (house["rect"] as Rect2).get_center()),
			"A correct empty static base needs no foreign overlay or hit target and must still guard private state", failures)
		DirAccess.remove_absolute(path)
	for value: Variant in [17, "res://no-such-sawmill-backplate.png", positive["data"]["stock"]["log"]["texture"]]:
		var data: Dictionary = positive["data"].duplicate(true)
		data["work"]["backplate"] = value
		var path: String = _write_manifest(data, "invalid-backplate-%d" % hash(value))
		var clone: Dictionary = house.duplicate(true)
		clone["operation"] = {"manifest": path}
		_check(Art.new().presentation_for(clone, _op(4, 6, true)).is_empty(),
			"An explicitly configured invalid, missing or wrong-size backplate must still reject incomplete artwork", failures)
		DirAccess.remove_absolute(path)
	Art.clear_cache()


static func _test_workpiece_and_registered_worker(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var active: Dictionary = _positive(house, _op(0, 0, true), failures)
	if active.is_empty():
		return
	var work: Dictionary = active["data"]["work"]
	var paused: Dictionary = _op(0, 0, true)
	paused["active_work"] = false
	var retained: Dictionary = Art.new().presentation_for(house, paused)
	_check(_count_path(retained, work["log"]["texture"]) == 1 and int(retained["frame_index"]) == -1,
		"A paused paid batch must retain its own log without a working carpenter", failures)
	var common_rect := Rect2()
	var seen: Dictionary = {}
	var expected_height: float = 31.0
	for productive: float in [0.0, 2.0, 4.0, 5.0, 7.0, 9.0]:
		var operation: Dictionary = _op(0, 0, true)
		operation["observed_work_ticks"] = productive
		operation["progress"] = productive / 60.0
		var art: Dictionary = Art.new().presentation_for(house, operation)
		var index: int = int(art["frame_index"])
		seen[index] = true
		_check(index >= 0 and index < 6, "Each productive clip sample must resolve a real work pose", failures)
		if index < 0:
			continue
		for layer: Dictionary in art["layers"]:
			if layer["path"] != work["frames"][index]:
				continue
			var rect: Rect2 = layer["rect"]
			if not common_rect.has_area():
				common_rect = rect
			var body_scale: float = rect.size.y / float((layer["texture"] as Texture2D).get_height())
			var foot: Vector2 = rect.position + Vector2(work["ground_contact"][0], work["ground_contact"][1]) * body_scale
			_check(rect == common_rect and foot.distance_to(Vector2(work["foot"][0], work["foot"][1])) < 0.001
				and is_equal_approx(float(work["body_height_px"]) * body_scale * float(house["source_to_world"]), expected_height),
				"All poses must share a planted foot and the calibrated projected height of their work posture", failures)
	_check(seen.size() == 6, "One productive second must reach all six authored work poses", failures)


static func _test_worker_space(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var active: Dictionary = _positive(house, _op(0, 0, true), failures)
	if active.is_empty():
		return
	var work: Dictionary = active["data"]["work"]
	# This regression targets the authored v2 workshop, not every possible house.
	_check(work.has("appearance") and is_equal_approx(float(work.get("body_height_world", 0)), 31.0),
		"The active workshop must load its revised worker height and local floor/roof appearance", failures)
	for layer: Dictionary in active["layers"]:
		if layer["path"] != work["frames"][active["frame_index"]]:
			_check((layer.get("appearance", {}) as Dictionary).is_empty(),
				"Roof shade must affect only the worker, not recolor the stock or architectural foreground", failures)
			continue
		var rect: Rect2 = layer["rect"]
		var support: Vector2 = rect.position + Vector2(160, 246) / Vector2(512, 512) * rect.size
		_check(support.distance_to(Vector2(529.6506563487234, 463.8754393545156)) < 0.001,
			"Shrinking the bent posture must preserve the measured support-palm contact on the existing log", failures)
		var appearance: Dictionary = layer.get("appearance", {})
		_check((appearance.get("contact_shadows", []) as Array).size() == 3,
			"Working feet require their two fixed sole contacts plus broad local occlusion", failures)
		# A contact shadow beneath the boot must not extend the person's hit mask.
		var shadow_only: Vector2 = rect.position + Vector2(300, 495) / Vector2(512, 512) * rect.size
		var point: Vector2 = (active["rect"] as Rect2).position + shadow_only * float(active["scale"])
		_check(not Art.new().contains_point(active, point),
			"Contact shading outside opaque feet must not become selectable worker artwork", failures)


static func _write_manifest(data: Dictionary, suffix: String) -> String:
	var temporary_root: String = OS.get_environment("TMPDIR")
	if temporary_root.is_empty():
		temporary_root = "/tmp"
	var path: String = temporary_root.path_join("sawmill-operation-art-%d-%s.json" % [OS.get_process_id(), suffix])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
	return path


static func _test_missing_and_malformed_resources(failures: Array[String]) -> void:
	var house: Dictionary = _house(failures)
	var positive: Dictionary = _positive(house, _op(0, 0, true), failures)
	if positive.is_empty():
		return
	var data: Dictionary = positive["data"]
	var clone: Dictionary = house.duplicate(true)
	# Prove the temp-manifest path itself works before any negative assertion.
	var valid_path: String = _write_manifest(data, "positive")
	clone["operation"] = {"manifest": valid_path}
	_check(not Art.new().presentation_for(clone, _op(0, 0, true)).is_empty(),
		"Malformed-resource checks require the same actual assets through a working independent manifest", failures)
	DirAccess.remove_absolute(valid_path)
	for index: int in range(data["work"]["frames"].size()):
		var missing: Dictionary = data.duplicate(true)
		missing["work"]["frames"][index] = Sprites.MANIFEST_PATH.get_base_dir().path_join("operation/no-such-frame.png")
		var path: String = _write_manifest(missing, "missing-%d" % index)
		clone["operation"] = {"manifest": path}
		_check(Art.new().presentation_for(clone, _op(0, 0, true)).is_empty(),
			"Every individual missing frame must reject the incomplete delivered animation", failures)
		DirAccess.remove_absolute(path)
	for index: int in range(5):
		var malformed: Dictionary = data.duplicate(true)
		if index == 0:
			malformed["stock"]["log"] = []
		elif index == 1:
			malformed["work"]["log"] = []
		elif index == 2:
			malformed["work"]["ground_contact"] = [-1, -1]
		elif index == 3:
			malformed["work"]["body_height_world"] = -31
		else:
			malformed["work"]["appearance"] = {"contact_shadows": [{"center": [300, 488], "size": [-80, 20], "opacity": 0.5}]}
		var path: String = _write_manifest(malformed, "malformed-%d" % index)
		clone["operation"] = {"manifest": path}
		_check(Art.new().presentation_for(clone, _op()).is_empty(), "Malformed nested operation geometry must fail safely", failures)
		DirAccess.remove_absolute(path)
	Art.clear_cache()


static func _test_main_art_and_hit(failures: Array[String]) -> void:
	var f: Dictionary = StateSuite._fixture()
	_check(StateSuite._start(f), "Main art/hit positive control must start a real carpenter", failures)
	var main: MainView = StateSuite.MainView.new()
	main.world = f["world"]
	main.terrain_renderer = StateSuite.MainView.TerrainRendererClass.new()
	main.add_child(main.terrain_renderer)
	main.terrain_renderer.bind_grid(main.world.grid)
	var art: Dictionary = main.building_operation_art_presentation(f["building"])
	_check(not art.is_empty() and int(art.get("frame_index", -1)) >= 0,
		"Normal MainView must expose actual imported operation layers for a real working resident", failures)
	if not art.is_empty():
		var points: Array[Vector2] = _worker_samples(art)
		_check(points.size() >= 3, "Real imported worker must provide several uncovered opaque selection samples", failures)
		for point: Vector2 in points:
			_check(main.sawmill_operation_art.contains_point(art, point) and main._building_id_at_visual_position(point) == int(f["building"]["id"]),
				"Opaque working-carpenter pixels must select their actual sawmill through the normal map hit path", failures)
		var outside: Vector2 = (art["rect"] as Rect2).position - Vector2.ONE * 5.0
		_check(not main.sawmill_operation_art.contains_point(art, outside), "Transparent padding cannot become an operation hit target", failures)
	main.free()


static func _worker_samples(art: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var index: int = int(art.get("frame_index", -1))
	if index < 0:
		return points
	var path: String = art["data"]["work"]["frames"][index]
	var layers: Array = art["layers"]
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		if layer["path"] != path:
			continue
		var image: Image = _image(layer["texture"])
		var rect: Rect2 = layer["rect"]
		for y: int in range(4, image.get_height() - 4, 7):
			for x: int in range(4, image.get_width() - 4, 7):
				if image.get_pixel(x, y).a < 0.99 or image.get_pixel(x - 3, y).a < 0.99 or image.get_pixel(x + 3, y).a < 0.99 \
						or image.get_pixel(x, y - 3).a < 0.99 or image.get_pixel(x, y + 3).a < 0.99:
					continue
				var local: Vector2 = rect.position + Vector2(x + 0.5, y + 0.5) / Vector2(image.get_size()) * rect.size
				var covered: bool = false
				for later: Dictionary in layers.slice(layer_index + 1):
					var front_rect: Rect2 = later["rect"]
					if front_rect.has_point(local):
						var mask: BitMap = later["mask"]
						var pixel := Vector2i((local - front_rect.position) / front_rect.size * Vector2(mask.get_size()))
						covered = covered or mask.get_bitv(pixel)
				if not covered:
					points.append((art["rect"] as Rect2).position + local * float(art["scale"]))
					if points.size() >= 15:
						return points
	return points


static func _settle(host: Node, main: MainView) -> void:
	for _frame: int in range(3):
		main.queue_redraw()
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw


static func _test_native_main_draw(host: Node, failures: Array[String]) -> void:
	var f: Dictionary = StateSuite._fixture()
	_check(StateSuite._start(f), "Native draw positive control must start actual sawmill production", failures)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	main.world = f["world"]
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.hud.visible = false
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2.ONE * 2.4
	main.camera.position = main.building_geometry(f["building"])["door"] - Vector2(0, 60)
	main.camera.force_update_scroll()
	var art: Dictionary = main.building_operation_art_presentation(f["building"])
	_check(not art.is_empty() and int(art.get("frame_index", -1)) >= 0,
		"Native draw check requires a real resolved animation frame, even when run headless", failures)
	if art.is_empty() or DisplayServer.get_name() == "headless":
		viewport.free()
		return
	var points: Array[Vector2] = _worker_samples(art)
	_check(points.size() >= 3, "Native pixel proof must use several real visible carpenter pixels", failures)
	await _settle(host, main)
	var actual: Image = viewport.get_texture().get_image()
	var reference := Node2D.new()
	reference.z_index = 2000
	main.add_child(reference)
	reference.draw.connect(func() -> void: main.sawmill_operation_art.draw(reference, art, main.building_sprite_presentation(f["building"])))
	reference.queue_redraw()
	await _settle(host, main)
	var expected: Image = viewport.get_texture().get_image()
	for point: Vector2 in points:
		var screen := Vector2i(main.get_global_transform_with_canvas() * point)
		var a: Color = actual.get_pixelv(screen)
		var b: Color = expected.get_pixelv(screen)
		_check(absf(a.r - b.r) < 0.025 and absf(a.g - b.g) < 0.025 and absf(a.b - b.b) < 0.025,
			"Real painter-row carpenter pixels must match an independently unobstructed layer drawn at the same registration", failures)
	viewport.free()
