extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const Sprites = preload("res://scripts/view/warehouse_sprite_library.gd")
const TEST_COUNT: int = 7
const SITE := Vector2i(10, 8)
# These witnesses are independent of the loader default: a revision switch
# must prove which delivered pixels the normal view uses after v1 was cached.
const EXPECTED_PRODUCTION_MANIFEST := "res://art/buildings/warehouse/v2/manifest.json"
const LEGACY_ART_MANIFEST := "res://art/buildings/warehouse/v1/manifest.json"


static func run(_host: Node) -> Array[String]:
	var failures: Array[String] = []
	var legacy_art := Sprites.new(LEGACY_ART_MANIFEST)
	var library := Sprites.new()
	_test_actual_import_and_cache(library, legacy_art, failures)
	_test_invalid_metadata(failures)
	_test_unfinished_legacy_and_missing(library, failures)
	_test_footprint_and_registration(library, failures)
	_test_real_alpha_selection(failures)
	_test_real_paid_construction(library, failures)
	_test_fog_and_immutable_save(failures)
	return failures


static func _fixture(height: int = 0) -> Dictionary:
	var world := World.new(Vector2i(24, 18))
	world.tick = 1750
	if height > 0:
		for y: int in range(world.grid.size.y + 1):
			for x: int in range(world.grid.size.x + 1):
				world.grid.set_vertex_height(Vector2i(x, y), height)
	var id: int = world.place_building("warehouse", SITE)
	return {"world": world, "id": id, "building": world.buildings[id]}


static func _view(world: World) -> MainView:
	var view := MainView.new()
	view.world = world
	view.terrain_renderer = Terrain.new()
	view.add_child(view.terrain_renderer)
	view.terrain_renderer.bind_grid(world.grid)
	return view


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_actual_import_and_cache(library: Sprites, legacy_art: Sprites, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	_check(library.supports(f["building"]), "The actual completed current warehouse must load its own measured RGBA asset", failures)
	if not library.supports(f["building"]):
		return
	var world: World = f["world"]
	var door := Vector2(400, 300)
	var shown: Dictionary = library.presentation_for(f["building"], world.catalog.building("warehouse"), door)
	var another := Sprites.new()
	var shared: Dictionary = another.presentation_for(f["building"], world.catalog.building("warehouse"), door)
	_check(shown.get("texture") is Texture2D and shown.get("hit_mask") is BitMap
		and shown.get("texture") == shared.get("texture") and shown.get("hit_mask") == shared.get("hit_mask"),
		"Completed warehouses must share the genuinely imported texture and matching alpha mask", failures)
	var image: Image = (shown["texture"] as Texture2D).get_image()
	_check(image.has_mipmaps() and (shown["hit_mask"] as BitMap).get_true_bit_count() > 100,
		"The actual warehouse must retain mipmaps and substantial opaque artwork after import", failures)
	var open: Dictionary = library.presentation_for(f["building"], world.catalog.building("warehouse"), door, true)
	var open_again: Dictionary = another.presentation_for(f["building"], world.catalog.building("warehouse"), door, true)
	_check(open["texture"] == open_again["texture"] and open["hit_mask"] == open_again["hit_mask"]
		and open["texture"] != shown["texture"] and open["rect"] == shown["rect"]
		and open["sort_foot"] == shown["sort_foot"] and open["door_threshold"] == shown["door_threshold"]
		and bool(open["door_open"]) and not bool(shown["door_open"]),
		"Both real door images must share registration and cache their own texture and alpha mask", failures)
	_check((open["texture"] as Texture2D).get_image().get_data() != image.get_data(),
		"The delivered open-door state must contain distinct imported pixels", failures)
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_PRODUCTION_MANIFEST))
	_check(shown.get("asset_version") == expected.get("asset_version")
		and _rgba_hash(image) == expected.get("finished_rgba_sha256")
		and _rgba_hash((open["texture"] as Texture2D).get_image()) == expected.get("day_open_rgba_sha256"),
		"Default production must use both independently identified delivered images even when v1 was loaded first", failures)
	var view: MainView = _view(world)
	var current: Dictionary = view.building_sprite_presentation(f["building"])
	_check(current.get("texture") == open["texture"] and current.get("asset_version") == expected.get("asset_version"),
		"The normal view must use the identified current production revision, not just an explicitly loaded preview", failures)
	view.free()
	_check(legacy_art.supports(f["building"]), "Preserved v1 artwork must remain explicitly loadable for historical comparisons", failures)
	var archived: Dictionary = legacy_art.presentation_for(f["building"], world.catalog.building("warehouse"), door)
	if not archived.is_empty():
		_check(archived.get("asset_version") == "v1", "Explicit legacy artwork must retain its own revision identity", failures)
		if EXPECTED_PRODUCTION_MANIFEST != LEGACY_ART_MANIFEST:
			_check(shown["texture"] != archived["texture"] and _rgba_hash(image) != _rgba_hash((archived["texture"] as Texture2D).get_image()),
				"A new production revision must not silently reuse cached legacy pixels", failures)


static func _test_invalid_metadata(failures: Array[String]) -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(Sprites.MANIFEST_PATH))
	if not value is Dictionary:
		failures.append("Metadata regression requires the delivered warehouse manifest")
		return
	var data: Dictionary = value
	_check(Sprites.validate_manifest(data), "The delivered manifest must satisfy the production schema", failures)
	for revision: String in ["v1", "v2"]:
		var supported: Dictionary = data.duplicate(true)
		supported["asset_version"] = revision
		_check(Sprites.validate_manifest(supported), "Both known artwork revisions share the measured schema without changing footprint versions", failures)
	for sample: Array in [["schema_version", 2], ["building_id", "lumber_hut"], ["asset_version", "v999"],
		["canvas", [1024, 0]], ["canvas", [1024.5, 1024]], ["door_threshold", [1, INF]],
		["sort_foot", [NAN, 1]], ["label_anchor", ["4", 12]], ["source_to_world", 0],
		["source_to_world", INF], ["source_to_world", true], ["alpha_bbox", [0, 0, 999999, 4]],
		["finished_image", "../foreign.png"], ["finished_rgba_sha256", "not-a-sha"], ["life", []],
		["day_open_image", "../foreign.png"], ["day_open_sha256", ""], ["day_open_rgba_sha256", "not-a-sha"],
		["day_open_alpha_bbox", [0, 0, 999999, 4]]]:
		var malformed: Dictionary = data.duplicate(true)
		malformed[sample[0]] = sample[1]
		_check(not Sprites.validate_manifest(malformed), "Malformed %s must be rejected before reading resources" % sample[0], failures)


static func _test_unfinished_legacy_and_missing(library: Sprites, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var building: Dictionary = f["building"].duplicate(true)
	for sample: Array in [["foundation_work_remaining", 1], ["construction_remaining", 1],
		["footprint_version", 0], ["footprint_version", 2], ["type", "lumber_hut"]]:
		var state: Dictionary = building.duplicate(true)
		state[sample[0]] = sample[1]
		_check(not library.supports(state) and library.presentation_for(state, world.catalog.building("warehouse"), Vector2.ZERO).is_empty()
			and library.visual_ground_position(state, world.building_door_cell(building), 40) == Vector2(SITE),
			"%s=%s must retain existing placeholder, earthwork or construction geometry" % sample, failures)
	var missing := Sprites.new(Sprites.MANIFEST_PATH.get_base_dir().path_join("not-delivered.json"))
	_check(not missing.supports(building) and missing.presentation_for(building, {}, Vector2.ZERO).is_empty(),
		"A missing warehouse resource must gracefully retain the existing renderer", failures)


static func _test_footprint_and_registration(library: Sprites, failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var building: Dictionary = f["building"]
	_check(world.building_cells(building).size() == 9 and world.building_door_cell(building) == SITE + Vector2i(1, 0)
		and building["entrance"] == SITE + Vector2i(1, 1) and world.building_id_at(SITE + Vector2i(1, 1)) == 0,
		"The real 3x3 warehouse mask must retain nine occupied cells and the free south doorway approach", failures)
	var view: MainView = _view(world)
	var flat: Dictionary = view.building_sprite_presentation(building)
	if flat.is_empty():
		failures.append("Registration checks need the loaded warehouse bitmap")
		view.free()
		return
	var shape: Dictionary = view.building_geometry(building)
	_check(((flat["rect"] as Rect2).position + (flat["door_threshold"] as Vector2) * float(flat["source_to_world"])).is_equal_approx(shape["door"]),
		"The measured image threshold must exactly register to the physical terrain threshold", failures)
	world.tick = 4750
	var later: Dictionary = view.building_sprite_presentation(building)
	_check(bool(flat["door_open"]) and later == flat,
		"The ordinary view must keep the own warehouse doors open at any tick without moving the house", failures)
	var raised: Dictionary = _fixture(3)
	var high: MainView = _view(raised["world"])
	var high_sprite: Dictionary = high.building_sprite_presentation(raised["building"])
	_check(not high_sprite.is_empty() and (high_sprite["rect"] as Rect2).position == (flat["rect"] as Rect2).position - Vector2(0, 24),
		"Three terrain levels must lift the actual bitmap exactly 24 world pixels without altering scale", failures)
	var depth: Vector2 = library.visual_ground_position(building, shape["door_cell"], 40)
	_check(depth == library.visual_ground_position(raised["building"], high.building_geometry(raised["building"])["door_cell"], 40),
		"Visual depth must use ground ordering independent from true terrain projection height", failures)
	view.free()
	high.free()


static func _test_real_alpha_selection(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var view: MainView = _view(f["world"])
	var sprite: Dictionary = view.building_sprite_presentation(f["building"])
	if sprite.is_empty():
		failures.append("Alpha selection must test the actual warehouse bitmap")
		view.free()
		return
	var shape: Dictionary = view.building_geometry(f["building"])
	var opaque: Vector2 = _probe(sprite, shape, true)
	var clear: Vector2 = _probe(sprite, shape, false)
	_check(opaque.is_finite() and view._building_id_at_visual_position(opaque) == int(f["id"]),
		"A genuinely opaque warehouse pixel outside occupied ground must be pickable through the real view", failures)
	_check(clear.is_finite() and view._building_id_at_visual_position(clear) == 0,
		"A transparent warehouse canvas pixel outside occupied ground must remain click-through", failures)
	for cell: Vector2i in (f["world"] as World).building_cells(f["building"]):
		_check(view._building_id_at_visual_position(view.terrain_renderer.cell_center(cell)) == int(f["id"]),
			"Every real occupied warehouse cell must remain selectable, including the open entrance", failures)
	view.free()


static func _test_real_paid_construction(library: Sprites, failures: Array[String]) -> void:
	var world := World.new(Vector2i(24, 18))
	world.tick = 1750
	var source_warehouse: int = world.place_building("warehouse", Vector2i(2, 5))
	world.buildings[source_warehouse]["storage"]["plank"] = 20
	world.buildings[source_warehouse]["storage"]["stone"] = 20
	world.economy_enabled = true
	var id: int = world.place_building("warehouse", SITE)
	var building: Dictionary = world.buildings[id]
	var cost: Dictionary = world.construction_cost(building).duplicate(true)
	var work: int = int(world.catalog.building("warehouse")["construction_ticks"])
	world.spawn_worker(Vector2i(6, 10), "carrier")
	world.spawn_worker(Vector2i(7, 11), "carrier")
	world.spawn_worker(Vector2i(12, 11), "builder")
	var worked: int = 0
	var previous: int = int(building["construction_remaining"])
	for _tick: int in range(2400):
		if world.is_building_complete(building):
			break
		_check(not library.supports(building), "Actual paid construction must never show the finished warehouse early", failures)
		world.step_tick()
		worked += previous - int(building["construction_remaining"])
		previous = int(building["construction_remaining"])
	_check(worked == work and world.is_building_complete(building) and library.supports(building),
		"Only completion by real carriers and Builder work may activate the finished warehouse bitmap", failures)
	_check(world.stored_amount("plank") == 20 - int(cost.get("plank", 0)) and world.stored_amount("stone") == 20 - int(cost.get("stone", 0)),
		"Artwork must preserve the real construction price and physical resource delivery", failures)
	var restored := World.new()
	var saved: Dictionary = world.to_data()
	_check(restored.from_data(JSON.parse_string(JSON.stringify(saved))) and restored.to_data() == saved
		and library.supports(restored.buildings.get(id, {})), "The actual completed warehouse must restore from unchanged game save data", failures)


static func _test_fog_and_immutable_save(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var world: World = f["world"]
	var view: MainView = _view(world)
	var saved: Dictionary = world.to_data()
	view.building_sprite_presentation(f["building"])
	view.building_life_presentation(f["building"])
	view._world_draw_entries()
	_check(world.to_data() == saved, "Sprite registration, life and draw ordering must be read-only over saved state", failures)
	_check(view.building_stock_presentation(f["building"]).is_empty()
		and view.building_operation_art_presentation(f["building"]).is_empty(),
		"Warehouses must never expose a stock overlay or a production worker in the ordinary view", failures)
	world.fog.enabled = true
	f["building"]["owner_id"] = 2
	world.update_visibility()
	var found: bool = false
	for entry: Dictionary in view._world_draw_entries():
		found = found or (entry["kind"] == "building" and entry["id"] == f["id"])
	_check(not found and not bool(view.building_life_presentation(f["building"]).get("known", false)),
		"Unknown foreign warehouses must be absent from normal drawing and must disclose no resident state", failures)
	var hidden_sprite: Dictionary = view.building_sprite_presentation(f["building"])
	_check(not hidden_sprite.is_empty() and not bool(hidden_sprite.get("door_open", true)),
		"A foreign warehouse with private state uses neutral closed doors", failures)
	view.free()


static func _probe(sprite: Dictionary, shape: Dictionary, opaque: bool) -> Vector2:
	var image: Image = (sprite["texture"] as Texture2D).get_image()
	var scale: float = float(sprite["source_to_world"])
	var rect: Rect2 = sprite["rect"]
	for y: int in range(6, image.get_height() - 6, 6):
		for x: int in range(6, image.get_width() - 6, 6):
			var alpha: float = image.get_pixel(x, y).a
			if (opaque and alpha < 0.99) or (not opaque and alpha > 0.01):
				continue
			var point: Vector2 = rect.position + Vector2(x + 0.5, y + 0.5) * scale
			var occupied: bool = false
			for polygon: PackedVector2Array in shape["foundations"]:
				occupied = occupied or Geometry2D.is_point_in_polygon(point, polygon)
			if not occupied:
				return point
	return Vector2.INF


static func _rgba_hash(image: Image) -> String:
	var pixels: Image = image.duplicate()
	pixels.convert(Image.FORMAT_RGBA8)
	pixels.clear_mipmaps()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(pixels.get_data())
	return hashing.finish().hex_encode()
