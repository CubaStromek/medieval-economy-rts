extends RefCounted

const Library = preload("res://scripts/view/lumberjack_animation_library.gd")
const TEST_COUNT: int = 6


static func run(_host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library: Library = Library.shared()
	_test_shared_default(library, failures)
	if not library.is_ready():
		return failures
	var source_images: Dictionary = {}
	_test_actual_alpha(library, source_images, failures)
	_test_current_frame(library, source_images, failures)
	_test_rect_mapping(library, source_images, failures)
	_test_lookup_keeps_resources(library, failures)
	_test_custom_load_isolation(library, failures)
	return failures


static func _test_shared_default(library: Library, failures: Array[String]) -> void:
	_expect(library.is_ready() and library.is_complete(), "Shared reader must load the actual complete 3×8 delivery: " + str(library.errors), failures)
	_expect(library == Library.shared(), "Repeated default requests must share the same reader instance", failures)
	var total: int = 0
	for clip: String in Library.CLIPS:
		for direction: String in Library.DIRECTIONS:
			total += library.frame_count(clip, direction)
	_expect(total == 439, "The reviewed delivery must expose all 439 selected frames", failures)
	var masks: int = 0
	for clip: Dictionary in library._hit_masks.values():
		for frames: Array in clip.values():
			masks += frames.size()
	_expect(masks == total, "Every loaded frame must have a prepared alpha mask", failures)


static func _test_actual_alpha(library: Library, source_images: Dictionary, failures: Array[String]) -> void:
	for clip: String in Library.CLIPS:
		for direction: String in Library.DIRECTIONS:
			var key: String = clip + "/" + direction
			var presentation: Dictionary = library.presentation_frame(clip, direction, Vector2(77.5, 91.25), 0)
			_expect(presentation.get("clip") == clip and presentation.get("direction") == direction,
				key + " must identify the actual clip and direction for hit testing", failures)
			var source: Image = _source_cell(presentation, source_images)
			var samples: Dictionary = _alpha_samples(source)
			_expect(samples.has("opaque") and samples.has("clear"), key + " needs real painted and transparent source pixels", failures)
			if samples.has("opaque"):
				_expect(library.contains_point(presentation, _world_point(library, presentation, samples["opaque"])),
					key + " visible source pixel must be selectable", failures)
			if samples.has("clear"):
				_expect(not library.contains_point(presentation, _world_point(library, presentation, samples["clear"])),
					key + " transparent padding must not capture selection", failures)


static func _test_current_frame(library: Library, source_images: Dictionary, failures: Array[String]) -> void:
	var first: Dictionary = library.presentation_frame("walk_axe", "S", Vector2.ZERO, 0)
	var second: Dictionary = library.presentation_frame("walk_axe", "S", Vector2.ZERO, 1)
	var a: Image = _source_cell(first, source_images)
	var b: Image = _source_cell(second, source_images)
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var first_visible: bool = a.get_pixel(x, y).a >= 0.10
			var second_visible: bool = b.get_pixel(x, y).a >= 0.10
			if first_visible != second_visible:
				var point: Vector2 = _world_point(library, first, Vector2i(x, y))
				_expect(library.contains_point(first, point) == first_visible
					and library.contains_point(second, point) == second_visible,
					"Hit shape must change with the actual animation frame, not reuse a fixed or first-frame mask", failures)
				return
	_expect(false, "The actual first two S walk frames need an alpha difference to exercise changing hit masks", failures)


static func _test_rect_mapping(library: Library, source_images: Dictionary, failures: Array[String]) -> void:
	var presentation: Dictionary = library.presentation_frame("walk_log", "NW", Vector2(301.75, -41.5), 0)
	var source: Image = _source_cell(presentation, source_images)
	var samples: Dictionary = _alpha_samples(source)
	var rect: Rect2 = presentation["rect"]
	_expect(not library.contains_point(presentation, rect.end)
		and not library.contains_point(presentation, rect.position - Vector2.ONE),
		"Hit testing must reject the exclusive bottom/right edge and points outside the sprite canvas", failures)
	if samples.has("opaque"):
		var moved: Dictionary = presentation.duplicate()
		moved["rect"] = Rect2(rect.position + Vector2(119, -53), rect.size * 1.75)
		_expect(library.contains_point(moved, _world_point(library, moved, samples["opaque"])),
			"The supplied presentation rectangle must control translated and scaled source-pixel mapping", failures)
	_expect(not library.contains_point({}, Vector2.ZERO), "Missing presentation metadata must not be selectable", failures)
	var invalid: Dictionary = presentation.duplicate()
	invalid["frame_index"] = library.frame_count("walk_log", "NW")
	_expect(not library.contains_point(invalid, rect.get_center()), "An out-of-range frame index must not select another frame", failures)


static func _test_lookup_keeps_resources(library: Library, failures: Array[String]) -> void:
	var before: Dictionary = library.manifest.duplicate(true)
	var presentation: Dictionary = library.presentation_frame("walk_axe", "S", Vector2.ZERO, 0)
	var texture: Texture2D = presentation["texture"]
	var mask: BitMap = library._hit_masks["walk_axe"]["S"][0]
	for index: int in range(16):
		library.contains_point(presentation, Vector2(float(index) - 8, -20))
		library.presentation_frame("walk_axe", "S", Vector2.ZERO, 0)
	_expect(library.texture_for("walk_axe", "S", 0) == texture
		and library._hit_masks["walk_axe"]["S"][0] == mask and Library.shared() == library,
		"Presentation and hit lookups must reuse loaded textures, masks and shared default instance", failures)
	_expect(library.manifest == before, "Read-only lookups must not mutate the delivery manifest", failures)


static func _test_custom_load_isolation(library: Library, failures: Array[String]) -> void:
	var custom := Library.new()
	_expect(custom != library and custom.load_manifest(), "Manual custom reader instances must remain independent from shared default", failures)
	_expect(not custom.load_manifest("res://missing-lumberjack-reader-test-manifest.json"),
		"An invalid manual reload must fail", failures)
	_expect(custom._hit_masks.is_empty() and not custom.is_ready(),
		"A failed manual load must clear stale masks and textures", failures)
	_expect(library.is_ready() and library.is_complete() and Library.shared() == library,
		"Failure in an independent reader must leave the shared default ready and unchanged", failures)


static func _source_cell(presentation: Dictionary, source_images: Dictionary) -> Image:
	var texture: AtlasTexture = presentation["texture"] as AtlasTexture
	var key: int = texture.atlas.get_instance_id()
	if not source_images.has(key):
		var image: Image = texture.atlas.get_image()
		if image.is_compressed():
			image.decompress()
		source_images[key] = image
	return (source_images[key] as Image).get_region(Rect2i(texture.region))


static func _alpha_samples(source: Image) -> Dictionary:
	var result: Dictionary = {}
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var alpha: float = source.get_pixel(x, y).a
			if not result.has("opaque") and alpha >= 0.10:
				result["opaque"] = Vector2i(x, y)
			if not result.has("clear") and alpha == 0.0:
				result["clear"] = Vector2i(x, y)
		if result.size() == 2:
			return result
	return result


static func _world_point(library: Library, presentation: Dictionary, pixel: Vector2i) -> Vector2:
	var rect: Rect2 = presentation["rect"]
	return rect.position + (Vector2(pixel) + Vector2(0.5, 0.5)) * rect.size / Vector2(library.source_canvas_px)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
