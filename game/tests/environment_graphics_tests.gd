extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const MapProjectionClass = preload("res://scripts/view/map_projection.gd")
const Trees = preload("res://scripts/view/tree_sprite_library.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 8


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library := Trees.new()
	_test_tree_atlas_alpha(library, failures)
	_test_tree_growth_species_and_save(library, failures)
	_test_road_masks(failures)
	_test_shared_road_edges(failures)
	_test_textured_cores_and_soft_shoulders(failures)
	_test_surface_triangles_and_world_uvs(failures)
	_test_road_neighbor_cache(failures)
	await _test_actual_environment_drawing(host, failures)
	return failures


static func _species_examples(library: Trees) -> Dictionary:
	var examples: Dictionary = {}
	for id: int in range(1, 200):
		var tree: Dictionary = {"id": id, "position": Vector2i(3, 3), "age_ticks": 0, "amount": 3}
		var species: int = library.species_for(tree)
		if not examples.has(species):
			examples[species] = tree
		if examples.size() == 3:
			break
	return examples


static func _test_tree_atlas_alpha(library: Trees, failures: Array[String]) -> void:
	var examples: Dictionary = _species_examples(library)
	_expect(examples.size() == 3, "Stable tree identities must provide oak, beech and spruce", failures)
	var regions: Array[Rect2] = []
	var fingerprints: Dictionary = {}
	var checked: int = 0
	var covered_alpha: int = 0
	var full_source: Image
	for species: int in range(3):
		if not examples.has(species):
			continue
		for stage: int in range(3):
			var label: String = "species %d stage %d" % [species, stage]
			_expect(library.has_sprite(species, stage), "Every tree species and growth stage requires real artwork: " + label, failures)
			var texture: Texture2D = library.texture_for(examples[species], stage)
			if not texture is AtlasTexture:
				failures.append("Tree artwork must use an actual atlas region: " + label)
				continue
			var atlas_texture := texture as AtlasTexture
			var source: Image = atlas_texture.atlas.get_image()
			var cell: Rect2i = library.atlas_cell_region(species, stage)
			_expect(source != null and not source.is_empty() and Rect2i(Vector2i.ZERO, source.get_size()).encloses(cell),
				"Tree source cell must remain inside the readable PNG: " + label, failures)
			if source == null or source.is_empty() or not Rect2i(Vector2i.ZERO, source.get_size()).encloses(cell):
				continue
			if source.is_compressed():
				source.decompress()
			full_source = source
			var actual: Rect2i = _alpha_bounds(source, cell)
			var region := Rect2i(atlas_texture.region)
			_expect(actual == region and actual.size.x > 8 and actual.size.y > 8,
				"Tree crop must exactly match visible source alpha without clipping or excess padding: " + label, failures)
			for other: Rect2 in regions:
				_expect(not other.intersects(atlas_texture.region), "Tree sprites must not overlap or reuse atlas regions: " + label, failures)
			regions.append(atlas_texture.region)
			var sprite: Image = source.get_region(region)
			var transparent: int = 0
			for y: int in range(sprite.get_height()):
				for x: int in range(sprite.get_width()):
					var alpha: float = sprite.get_pixel(x, y).a
					if alpha < 0.05:
						transparent += 1
					if alpha >= Trees.ALPHA_THRESHOLD:
						covered_alpha += 1
			_expect(transparent >= 10, "Painted tree must retain transparent surroundings: " + label, failures)
			var fingerprint: String = str(sprite.get_size()) + ":" + str(hash(sprite.get_data()))
			_expect(not fingerprints.has(fingerprint), "All nine tree appearances must contain distinct image data: " + label, failures)
			fingerprints[fingerprint] = true
			checked += 1
	_expect(checked == 9, "Alpha and crop assertions must actually inspect all nine loaded tree sprites", failures)
	if full_source != null:
		var source_alpha: int = 0
		for y: int in range(full_source.get_height()):
			for x: int in range(full_source.get_width()):
				if full_source.get_pixel(x, y).a >= Trees.ALPHA_THRESHOLD:
					source_alpha += 1
		_expect(source_alpha > 1000 and covered_alpha == source_alpha,
			"All visible source pixels must survive in the nine nonoverlapping tree crops; no canopy or trunk may be discarded", failures)


static func _alpha_bounds(source: Image, cell: Rect2i) -> Rect2i:
	var left: int = cell.end.x
	var top: int = cell.end.y
	var right: int = -1
	var bottom: int = -1
	for y: int in range(cell.position.y, cell.end.y):
		for x: int in range(cell.position.x, cell.end.x):
			if source.get_pixel(x, y).a < Trees.ALPHA_THRESHOLD:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	return Rect2i() if right < left or bottom < top else Rect2i(left, top, right - left + 1, bottom - top + 1)


static func _test_tree_growth_species_and_save(library: Trees, failures: Array[String]) -> void:
	var examples: Dictionary = _species_examples(library)
	var feet := Vector2(150.25, 300.5)
	for species: int in examples:
		var tree: Dictionary = examples[species]
		var original: Dictionary = tree.duplicate(true)
		var previous_height: float = 0.0
		for stage: int in range(3):
			var size: Vector2 = library.sprite_size(tree, stage)
			var rect: Rect2 = library.sprite_rect(tree, stage, feet)
			_expect(size.y > previous_height + 5.0 and size.y <= 78.0 and size.x > 2.0 and size.x <= 65.0,
				"Each species must grow through three legible, bounded sizes", failures)
			var root_offset: Vector2 = library.root_offset_for(tree, stage)
			_expect(is_equal_approx(rect.end.y, feet.y) and (rect.position + root_offset).is_equal_approx(feet) and rect.size == size,
				"Actual trunk roots must remain anchored while the asymmetric crown grows", failures)
			_expect(root_offset.x > 0.0 and root_offset.x < size.x, "Trunk pivot must lie inside the visible tree footprint", failures)
			previous_height = size.y
		_expect(tree == original, "Looking up tree stages and geometry must not mutate tree identity or age", failures)
		var grown: Dictionary = original.duplicate(true)
		grown["age_ticks"] = World.TREE_MATURE_AGE_TICKS
		grown["amount"] = 1
		_expect(library.species_for(grown) == species, "Growing and harvesting a tree must not switch its visual species", failures)
	var world := World.new(Vector2i(8, 5))
	for x: int in range(1, 7):
		world.add_tree(Vector2i(x, 2), 3)
	var before: Dictionary = world.to_data()
	var restored := World.new()
	_expect(restored.from_data(JSON.parse_string(JSON.stringify(before))), "A real tree snapshot must still load after the graphics change", failures)
	for id: int in world.trees:
		_expect(restored.trees.has(id) and library.species_for(world.trees[id]) == library.species_for(restored.trees[id]),
			"Tree species must remain stable across actual JSON save/load without a new saved species field", failures)
	_expect(world.to_data() == before, "Species selection must leave authoritative save data unchanged", failures)


static func _test_road_masks(failures: Array[String]) -> void:
	var center := Vector2i(1, 1)
	for mask: int in range(16):
		var grid := Grid.new(Vector2i(3, 3))
		grid.add_road(center)
		for direction: int in range(4):
			if (mask & (1 << direction)) != 0:
				var cell: Vector2i = center + Grid.CARDINAL_DIRECTIONS[direction]
				if direction % 2 == 0:
					grid.add_road(cell)
				else:
					grid.add_dirt_trail(cell)
		var renderer := Renderer.new()
		renderer.bind_grid(grid)
		_expect(renderer.surface_connection_mask_for(center) == mask,
			"Road shape mask must handle isolated, end, straight, corner, T and cross including mixed trails: %d" % mask, failures)
		var commands: Array = renderer._cells[center]["draws"]
		_expect(_core_covers(commands, Vector2(0.5, 0.5)), "Every road mask must keep its center connected", failures)
		for direction: int in range(4):
			var edge: Vector2 = Vector2(0.5, 0.5) + Vector2(Grid.CARDINAL_DIRECTIONS[direction]) * 0.5
			_expect(_core_covers(commands, edge) == ((mask & (1 << direction)) != 0),
				"Only connected road branches may reach a cell edge: mask %d direction %d" % [mask, direction], failures)
		renderer.free()


static func _test_shared_road_edges(failures: Array[String]) -> void:
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		for pair: Array in [["stone", "stone"], ["trail", "trail"], ["stone", "trail"]]:
			var grid := Grid.new(Vector2i(4, 4))
			var first := Vector2i(1, 1)
			var second: Vector2i = first + direction
			if pair[0] == "stone":
				grid.add_road(first)
			else:
				grid.add_dirt_trail(first)
			if pair[1] == "stone":
				grid.add_road(second)
			else:
				grid.add_dirt_trail(second)
			var renderer := Renderer.new()
			renderer.bind_grid(grid)
			var width: float = renderer.surface_edge_half_width(first, direction)
			_expect(width > 0.0 and is_equal_approx(width, renderer.surface_edge_half_width(second, -direction)),
				"Both sides of stone/trail joins must agree on their shared edge width", failures)
			var across := Vector2(-direction.y, direction.x)
			for fraction: float in [-0.95, -0.5, 0.0, 0.5, 0.95]:
				var edge_a: Vector2 = Vector2(0.5, 0.5) + Vector2(direction) * 0.5 + across * width * fraction
				var edge_b: Vector2 = edge_a - Vector2(direction)
				_expect(_core_covers(renderer._cells[first]["draws"], edge_a)
					and _core_covers(renderer._cells[second]["draws"], edge_b),
					"Actual road triangles must cover the whole common edge without a grass gap", failures)
			renderer.free()


static func _test_textured_cores_and_soft_shoulders(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(3, 3))
	grid.add_road(Vector2i(1, 1))
	grid.add_road(Vector2i(1, 0))
	grid.add_dirt_trail(Vector2i(2, 1))
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var texture: Texture2D = renderer._textures.get("stone_road") as Texture2D
	_expect(texture != null and texture.resource_path.ends_with("stone-road-basic-v1.png"),
		"Cobblestones must use the real authored PNG rather than the development fallback", failures)
	var core_count: int = 0
	var shoulder_alpha: Dictionary = {}
	for command: Dictionary in renderer._cells[Vector2i(1, 1)]["draws"]:
		var layer: String = String(command.get("layer", ""))
		if layer == "road_core":
			core_count += 1
			_expect(command["texture"] == texture, "Every stone core triangle must submit the cobble texture", failures)
		if layer.begins_with("shoulder_"):
			var colors: PackedColorArray = command["colors"]
			_expect(colors[0].a > 0.0 and colors[0].a < 1.0, "Road shoulders must blend softly into the underlying terrain", failures)
			shoulder_alpha[str(colors[0].a)] = true
	_expect(core_count > 0 and shoulder_alpha.size() >= 2, "Rendering must include a textured stone core plus at least two soft shoulder bands", failures)
	var trail_core: int = 0
	for command: Dictionary in renderer._cells[Vector2i(2, 1)]["draws"]:
		if command.get("layer", "") == "trail_core":
			trail_core += 1
			_expect(command["texture"] != texture, "Worn dirt trails must retain a distinct surface from cobblestones", failures)
	_expect(trail_core > 0, "The mixed edge fixture must actually render its dirt trail", failures)
	renderer.free()


static func _test_surface_triangles_and_world_uvs(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 4))
	var cell := Vector2i(1, 1)
	grid.set_vertex_height(Vector2i(1, 1), 1)
	grid.set_vertex_height(Vector2i(2, 1), 2)
	grid.set_vertex_height(Vector2i(2, 2), 3)
	grid.set_vertex_height(Vector2i(1, 2), 1)
	grid.add_road(cell)
	grid.add_road(cell + Vector2i.RIGHT)
	grid.add_dirt_trail(cell + Vector2i.DOWN)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var tested_triangles: int = 0
	var common_samples: int = 0
	for tile: Vector2i in [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN]:
		for command: Dictionary in renderer._cells[tile]["draws"]:
			var layer: String = String(command.get("layer", ""))
			if not layer.ends_with("_core") and not layer.begins_with("shoulder_"):
				continue
			var uvs: PackedVector2Array = command["uvs"]
			var texture_uvs: PackedVector2Array = command["texture_uvs"]
			var points: PackedVector2Array = command["points"]
			_expect(uvs.size() == 3 and points.size() == 3 and texture_uvs.size() == 3,
				"Textured roads and shoulders must submit explicit triangles with matching UV arrays", failures)
			var upper: bool = true
			var lower: bool = true
			for index: int in range(uvs.size()):
				var uv: Vector2 = uvs[index]
				upper = upper and uv.x >= uv.y - 0.0001
				lower = lower and uv.x <= uv.y + 0.0001
				var position: Vector2 = Vector2(tile) + uv
				var expected: Vector2 = position * MapProjectionClass.CELL_SIZE - Vector2(0, grid.height_at(position) * MapProjectionClass.HEIGHT_STEP_PIXELS)
				_expect(points[index].is_equal_approx(expected), "Textured road vertices must lie on the actual height mesh", failures)
				_expect(texture_uvs[index].is_equal_approx(position / 2.0),
					"Surface texture UVs must use continuous world coordinates across tile borders", failures)
				if is_equal_approx(position.x, 2.0):
					common_samples += 1
			_expect(upper or lower, "Road triangles must not cut across the terrain's folded TL-BR diagonal", failures)
			tested_triangles += 1
	_expect(tested_triangles > 12 and common_samples > 4, "Height and UV assertions must inspect real textured geometry on both sides of a shared edge", failures)
	renderer.free()


static func _test_road_neighbor_cache(failures: Array[String]) -> void:
	var grid := Grid.new(Vector2i(4, 3))
	var cell := Vector2i(1, 1)
	grid.add_road(cell)
	var renderer := Renderer.new()
	renderer.bind_grid(grid)
	var first_count: int = renderer.geometry_build_count
	_expect(not _core_covers(renderer._cells[cell]["draws"], Vector2(1.0, 0.5)), "Cache fixture must begin without an east road branch", failures)
	grid.add_dirt_trail(cell + Vector2i.RIGHT)
	renderer.cell_polygon(cell)
	_expect(renderer.geometry_build_count == first_count + 1 and _core_covers(renderer._cells[cell]["draws"], Vector2(1.0, 0.5)),
		"Adding a neighboring trail must rebuild the cached stone branch once", failures)
	var stable_draws: Array = renderer._cells[cell]["draws"].duplicate(true)
	for repeat: int in range(5):
		renderer.cell_polygon(cell)
		renderer.surface_connection_mask_for(cell)
	_expect(renderer.geometry_build_count == first_count + 1 and renderer._cells[cell]["draws"] == stable_draws,
		"Frame queries must reuse the same road geometry without per-frame rebuilding", failures)
	grid.set_vertex_height(Vector2i(1, 1), 1)
	renderer.cell_polygon(cell)
	_expect(renderer.geometry_build_count == first_count + 2 and renderer._cells[cell]["draws"] != stable_draws,
		"A changed shared height must rebuild and move road geometry", failures)
	grid.set_base_terrain(cell + Vector2i.RIGHT, "water")
	renderer.cell_polygon(cell)
	_expect(renderer.geometry_build_count == first_count + 3 and not _core_covers(renderer._cells[cell]["draws"], Vector2(1.0, 0.5)),
		"Removing a now-invalid neighboring trail must remove its cached connecting branch", failures)
	renderer.free()


static func _core_covers(commands: Array, uv: Vector2) -> bool:
	for command: Dictionary in commands:
		if command.get("layer", "") not in ["road_core", "trail_core"]:
			continue
		var triangle: PackedVector2Array = command["uvs"]
		if triangle.size() == 3 and Renderer._point_in_triangle(uv, triangle[0], triangle[1], triangle[2]):
			return true
	return false


static func _test_actual_environment_drawing(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	viewport.add_child(main)
	main.set_process(false)
	main.world = World.new(Vector2i(9, 7))
	for y: int in range(8):
		for x: int in range(10):
			main.world.grid.set_vertex_height(Vector2i(x, y), 4)
	var ages: Array[int] = [0, World.TREE_YOUNG_AGE_TICKS, World.TREE_MATURE_AGE_TICKS]
	for index: int in range(3):
		main.world._create_tree(Vector2i(2 + index * 2, 2), 3, ages[index])
	for x: int in range(1, 8):
		main.world.grid.add_road(Vector2i(x, 4))
	main.terrain_renderer.bind_grid(main.world.grid)
	main._center_camera()
	main.simulation_speed = 0.0
	var before: Dictionary = main.world.to_data()
	var trees_before: Dictionary = main.world.trees.duplicate(true)
	var seen: int = 0
	for entry: Dictionary in main._world_draw_entries():
		if entry["kind"] != "tree":
			continue
		var tree: Dictionary = entry["state"]
		var stage: int = main.world.tree_growth_stage(tree)
		var feet: Vector2 = entry["position"]
		var expected: Vector2 = MapProjectionClass.cell_center(tree["position"]) - Vector2(0, 32)
		_expect(feet == expected, "Actual tree draw entries must be rooted on the raised terrain", failures)
		var presentation: Dictionary = main.tree_sprites.presentation_for(tree, stage, feet, false)
		var rect: Rect2 = presentation["rect"]
		_expect(presentation["texture"] != null and is_equal_approx(rect.end.y, feet.y)
			and (rect.position + main.tree_sprites.root_offset_for(tree, stage)).is_equal_approx(feet),
			"The real tree appearance must retain a visible texture and exact raised root anchor", failures)
		_expect(presentation["amount_text"] == "" and main.tree_sprites.presentation_for(tree, stage, feet, true)["amount_text"] == "3",
			"Tree resource counts should appear only in the optional terrain debug view", failures)
		seen += 1
	_expect(seen == 3, "The real render fixture must include all three growth stages", failures)
	var draws: Array[int] = [0]
	main.draw.connect(func() -> void: draws[0] += 1)
	for debug: bool in [false, true]:
		main.show_terrain_rules = debug
		main.queue_redraw()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
	_expect(draws[0] >= 2, "Both normal and debug environment drawing must actually execute", failures)
	_expect(main.world.to_data() == before and main.world.trees == trees_before,
		"Tree sprites, road painting and debug labels must not mutate the simulation or saves", failures)
	viewport.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
