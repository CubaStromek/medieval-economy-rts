extends RefCounted

const Catalog = preload("res://scripts/simulation/definition_catalog.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const SpriteLibrary = preload("res://scripts/view/unit_sprite_library.gd")
const TEST_COUNT: int = 6


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library := SpriteLibrary.new()
	var roles: Array[String] = _catalog_roles()
	_test_catalog_mapping(library, roles, failures)
	_test_real_atlas_pixels(library, roles, failures)
	_test_geometry_and_unknown_role(library, roles, failures)
	_test_motion_is_read_only(library, failures)
	await _test_actual_view_and_pause(host, roles, failures)
	return failures


static func _catalog_roles() -> Array[String]:
	var catalog := Catalog.new()
	var roles: Array[String] = []
	for role: String in catalog.units:
		roles.append(role)
	for role: String in catalog.soldiers:
		roles.append(role)
	return roles


static func _test_catalog_mapping(library: SpriteLibrary, roles: Array[String], failures: Array[String]) -> void:
	_expect(roles.size() == 29, "Sprite coverage must include all 15 civilians and 14 military roles from the real catalog", failures)
	var mapped: Array[AtlasTexture] = []
	for role: String in roles:
		_expect(library.has_role(role), "A real loaded sprite must exist for catalog role " + role, failures)
		var texture: Texture2D = library.texture_for(role)
		_expect(texture != null and texture is AtlasTexture, "Role " + role + " must resolve to an actual atlas texture", failures)
		if not texture is AtlasTexture:
			continue
		var atlas_texture := texture as AtlasTexture
		var region: Rect2 = atlas_texture.region
		_expect(atlas_texture.atlas != null and region.size.x >= 16.0 and region.size.y >= 16.0,
			"Role " + role + " must have a nontrivial source region and loaded sheet", failures)
		if atlas_texture.atlas == null:
			continue
		_expect(Rect2(Vector2.ZERO, atlas_texture.atlas.get_size()).encloses(region),
			"Sprite region for " + role + " must stay inside its source sheet", failures)
		for other: AtlasTexture in mapped:
			if other.atlas == atlas_texture.atlas:
				_expect(not other.region.intersects(region), "Distinct roles must never reuse or overlap source atlas regions: " + role, failures)
		mapped.append(atlas_texture)
	_expect(mapped.size() == roles.size(), "No catalog role may silently fall through to the generic fallback", failures)


static func _test_real_atlas_pixels(library: SpriteLibrary, roles: Array[String], failures: Array[String]) -> void:
	var images: Dictionary = {}
	var signatures: Dictionary = {}
	for role: String in roles:
		var texture: Texture2D = library.texture_for(role)
		if not texture is AtlasTexture:
			continue
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			continue
		var key: int = atlas_texture.atlas.get_instance_id()
		if not images.has(key):
			images[key] = atlas_texture.atlas.get_image()
		var source: Image = images[key]
		_expect(source != null and not source.is_empty(), "The actual PNG for " + role + " must be readable", failures)
		if source == null or source.is_empty():
			continue
		if source.is_compressed():
			source.decompress()
		var bounds := Rect2i(atlas_texture.region)
		if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(bounds):
			continue
		var sprite: Image = source.get_region(bounds)
		var opaque: int = 0
		var transparent: int = 0
		for y: int in range(0, sprite.get_height(), 2):
			for x: int in range(0, sprite.get_width(), 2):
				var alpha: float = sprite.get_pixel(x, y).a
				if alpha >= 0.5:
					opaque += 1
				elif alpha <= 0.05:
					transparent += 1
		_expect(opaque >= 25, "Role " + role + " must contain visible painted pixels, not an empty slot", failures)
		_expect(transparent >= 25, "Role " + role + " must retain transparent surroundings rather than a rectangular background", failures)
		var signature: String = str(sprite.get_size()) + ":" + str(hash(sprite.get_data()))
		_expect(not signatures.has(signature), "Every role must have its own artwork rather than a duplicate image: " + role, failures)
		signatures[signature] = role


static func _test_geometry_and_unknown_role(library: SpriteLibrary, roles: Array[String], failures: Array[String]) -> void:
	var feet := Vector2(123.5, 456.25)
	for role: String in roles:
		var size: Vector2 = library.sprite_size(role)
		var rect: Rect2 = library.sprite_rect(role, feet)
		_expect(size.x >= 8.0 and size.x <= 40.01 and size.y >= 24.0 and size.y <= 40.01,
			"Role " + role + " must stay legible at the agreed human/mounted map scale", failures)
		_expect(rect.size.is_equal_approx(size)
			and is_equal_approx(rect.get_center().x, feet.x)
			and is_equal_approx(rect.end.y, feet.y),
			"Role " + role + " must keep its exact bottom-center foot anchor", failures)
	_expect(not library.has_role("unknown_test_role"), "Unknown roles must not pretend to have authored artwork", failures)
	_expect(library.texture_for("unknown_test_role") == library.texture_for("carrier")
		and library.sprite_size("unknown_test_role") == library.sprite_size("carrier"),
		"An unknown role must have a stable visible carrier fallback", failures)


static func _test_motion_is_read_only(library: SpriteLibrary, failures: Array[String]) -> void:
	var worker: Dictionary = {
		"id": 19, "type": "carrier", "state": "moving", "carrying": "log", "hunger": 300,
		"previous_position": Vector2i(1, 2), "position": Vector2i(2, 2),
		"visual_duration_ticks": 4, "visual_progress_ticks": 1,
	}
	var before: Dictionary = worker.duplicate(true)
	var feet := Vector2(320, 260)
	var first: Dictionary = library.presentation_for(worker, feet, 20, 0.25)
	_expect(first == library.presentation_for(worker, feet, 20, 0.25),
		"Identical simulation tick and fraction must produce identical sprite presentation", failures)
	var offsets: Dictionary = {}
	for tick: int in range(20, 32):
		var offset: Vector2 = SpriteLibrary.motion_offset(worker, tick, 0.25)
		_expect(offset.is_finite() and absf(offset.x) <= 2.0 and absf(offset.y) <= 2.0,
			"Walking bob must stay small and finite so feet remain grounded", failures)
		offsets[str(offset)] = true
	_expect(offsets.size() > 1, "A moving worker must receive visible lightweight motion from simulation time", failures)
	_expect(not SpriteLibrary.faces_left(worker), "Eastward travel must use the unmirrored sprite", failures)
	_expect(worker == before, "Sprite lookup and animation sampling must not mutate worker state", failures)
	worker["state"] = "idle"
	worker["visual_progress_ticks"] = worker["visual_duration_ticks"]
	_expect(SpriteLibrary.motion_offset(worker, 25, 0.5).is_zero_approx(), "A stationary worker with a completed step must stand still", failures)
	worker["previous_position"] = Vector2i(2, 2)
	worker["position"] = Vector2i(1, 2)
	_expect(SpriteLibrary.faces_left(worker), "Westward travel must mirror the sprite", failures)


# Cases 5 and 6 execute the actual scene's presentation path at raised ground,
# then repaint/process paused frames while comparing authoritative state.
static func _test_actual_view_and_pause(host: Node, roles: Array[String], failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	main.world = World.new(Vector2i(12, 8))
	for y: int in range(9):
		for x: int in range(13):
			main.world.grid.set_vertex_height(Vector2i(x, y), 4)
	for index: int in range(roles.size()):
		var cell := Vector2i(1 + index % 10, 1 + index / 10)
		_expect(main.world.spawn_worker(cell, roles[index]) != 0, "Actual sprite view fixture must spawn " + roles[index], failures)
	main.terrain_renderer.bind_grid(main.world.grid)
	main._center_camera()
	main.world.tick = 20
	main.accumulator = MainView.FIXED_TICK_SECONDS * 0.25
	main.simulation_speed = 0.0
	var carrier_id: int = 0
	for id: int in main.world.workers:
		if String(main.world.workers[id]["type"]) == "carrier":
			carrier_id = id
			break
	_expect(carrier_id != 0, "The real scene fixture must contain a carrier", failures)
	if carrier_id == 0:
		viewport.free()
		return
	var carrier: Dictionary = main.world.workers[carrier_id]
	carrier["carrying"] = "log"
	carrier["hunger"] = 300
	carrier["state"] = "moving"
	carrier["previous_position"] = Vector2i(1, 0)
	carrier["visual_duration_ticks"] = 4
	carrier["visual_progress_ticks"] = 1
	var state_before: Dictionary = main.world.to_data()
	var workers_before: Dictionary = main.world.workers.duplicate(true)
	var entries_before: Array[Dictionary] = main._world_draw_entries()
	var seen: Dictionary = {}
	var carrier_feet := Vector2.ZERO
	for entry: Dictionary in entries_before:
		if entry["kind"] != "worker":
			continue
		var worker: Dictionary = entry["state"]
		var role: String = worker["type"]
		var feet: Vector2 = entry["position"]
		var presentation: Dictionary = main.worker_presentation(worker, feet)
		seen[role] = true
		_expect(presentation.get("texture") == main.unit_sprites.texture_for(role),
			"The real draw path must use the mapped sprite for " + role, failures)
		var rect: Rect2 = presentation["rect"]
		var bob: Vector2 = SpriteLibrary.motion_offset(worker, main.world.tick, 0.25)
		_expect(is_equal_approx(rect.end.y, feet.y + bob.y),
			"Actual drawn sprite must remain anchored to its relief-sampled feet", failures)
		if int(worker["id"]) == carrier_id:
			carrier_feet = feet
			var cargo: Vector2 = presentation["cargo_position"]
			var hunger: Vector2 = presentation["hunger_position"]
			_expect(cargo.is_finite() and feet.distance_to(cargo) < 40.0 and cargo.y < feet.y,
				"A carried ware must retain a nearby visible hand anchor", failures)
			_expect(hunger.is_finite() and hunger.y < rect.position.y,
				"A hunger indicator must sit above the full sprite instead of behind it", failures)
	_expect(seen.size() == roles.size(), "The real scene must retain a sprite draw entry for every catalog role", failures)
	_expect(main.world.to_data() == state_before and main.world.workers == workers_before,
		"Sprite presentation for all units must leave saves and transient worker state untouched", failures)
	var presentation_before: Dictionary = main.worker_presentation(carrier, carrier_feet)
	var draw_count: Array[int] = [0]
	main.draw.connect(func() -> void: draw_count[0] += 1)
	for frame: int in range(4):
		main._process(1.0 / 30.0)
		main.queue_redraw()
		await host.get_tree().process_frame
	_expect(draw_count[0] > 0, "The isolated viewport must execute the real unit drawing code", failures)
	_expect(main.world.to_data() == state_before and main.world.workers == workers_before,
		"Rendering and paused frame processing must not advance or mutate simulation state", failures)
	_expect(main._world_draw_entries() == entries_before
		and main.worker_presentation(carrier, carrier_feet) == presentation_before,
		"Paused unit positions, walking bob, cargo and hunger anchors must remain stable across redraws", failures)
	viewport.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
