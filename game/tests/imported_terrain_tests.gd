extends RefCounted

const Import = preload("res://scripts/simulation/imported_terrain.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const Renderer = preload("res://scripts/view/terrain_renderer.gd")
const Pathfinder = preload("res://scripts/simulation/grid_pathfinder.gd")
const TEST_COUNT: int = 7

static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_orientation_and_empty_scenario, _test_shared_heights_and_tree_stages,
		_test_routes_and_building_rules, _test_save_roundtrip, _test_invalid_dense_data,
		_test_invalid_tree_data, _test_load_missing_file]:
		test.call(failures)
	return failures

static func fixture() -> Dictionary:
	var heights: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(11):
			row.append(1 if x < 5 else 2)
		heights.append(row)
	return {"format": "medieval-terrain-v1", "name": "Synthetic terrain",
		"source": {"url": "https://example.test/synthetic", "sha256": "a".repeat(64), "revision": 11222,
			"vertex_size": [11, 9], "height_scale": 0.15, "height_offset": 0},
		"map_size": [10, 8], "heights": heights,
		"terrain": ["gggggwgggr", "gggggwgggr", "gggggwgggr", "gggggdgggr",
			"gggggwgggr", "gggggwgggr", "gggggwgggr", "gggggwgggr"],
		"trees": [[0, 0, 0], [1, 0, 1], [2, 0, 2]]}

static func _world(failures: Array[String]) -> Variant:
	var result: Dictionary = Import.from_data(fixture())
	_check(result["world"] != null, "Synthetic terrain must produce a real fresh world: " + String(result["error"]), failures)
	return result["world"]

static func _test_orientation_and_empty_scenario(failures: Array[String]) -> void:
	var source: Dictionary = fixture()
	var before: Dictionary = source.duplicate(true)
	var result: Dictionary = Import.from_data(source)
	var world: Variant = result["world"]
	if world == null:
		failures.append("Valid source must import")
		return
	_check(source == before and world.grid.size == Vector2i(10, 8),
		"Import must preserve source data and use cell dimensions, without padding an extra map border", failures)
	_check(world.grid.base_terrain_at(Vector2i(9, 0)) == "rock"
		and world.grid.base_terrain_at(Vector2i(5, 3)) == "dirt" and world.grid.base_terrain_at(Vector2i(5, 4)) == "water",
		"Terrain must retain exact north/south orientation and the source gap in its river", failures)
	_check(world.buildings.is_empty() and world.workers.is_empty() and world.deposits.is_empty()
		and world.fields.is_empty() and world.grid.roads.is_empty() and world.grid.dirt_trails.is_empty()
		and world.grid.blocked_by.is_empty() and world.economy_enabled,
		"Terrain study must not invent campaign units, buildings, roads, resources or a free economy", failures)

static func _test_shared_heights_and_tree_stages(failures: Array[String]) -> void:
	var world: Variant = _world(failures)
	if world == null: return
	_check(world.grid.vertex_height(Vector2i(10, 8)) == 2 and world.grid.vertex_height(Vector2i(0, 0)) == 1
		and world.grid._vertex_heights.size() == 99 and world.grid.cell_slope(Vector2i(4, 4)) == 1,
		"All four map edges and interior shared-corner slopes must survive without flattening", failures)
	for index: int in range(3):
		_check(world.tree_growth_stage(world.trees[index + 1]) == index
			and world.trees[index + 1]["position"] == Vector2i(index, 0),
			"Imported living trees must retain their position and mapped growth stage", failures)
	var renderer := Renderer.new()
	renderer.bind_grid(world.grid)
	var polygon: PackedVector2Array = renderer.cell_polygon(Vector2i(4, 4))
	_check(polygon == PackedVector2Array([Vector2(160, 152), Vector2(200, 144), Vector2(200, 184), Vector2(160, 192)]),
		"Rendered slope must use exact converted heights and existing 40x40 projection", failures)
	renderer.free()

static func _test_routes_and_building_rules(failures: Array[String]) -> void:
	var world: Variant = _world(failures)
	if world == null: return
	var route: Array[Vector2i] = Pathfinder.find_path(world.grid, Vector2i(3, 3), Vector2i(7, 3))
	_check(not route.is_empty() and route.has(Vector2i(5, 3)),
		"The source land passage must be truly traversable across its water barrier", failures)
	_check(not world.grid.is_walkable(Vector2i(5, 4)) and not world.grid.is_walkable(Vector2i(9, 4)),
		"Imported water and mountain material must remain actual movement obstacles", failures)
	var before: Dictionary = world.to_data()
	_check(world.foundation_plan("lumber_hut", Vector2i(1, 5)).get("valid", false)
		and not world.can_place_building("lumber_hut", Vector2i(4, 5)),
		"Existing Builder ground preparation remains authoritative on imported terrain and rejects water", failures)
	_check(world.to_data() == before, "Placement previews on an imported map cannot alter its terrain", failures)

static func _test_save_roundtrip(failures: Array[String]) -> void:
	var world: Variant = _world(failures)
	if world == null: return
	var before: Dictionary = world.to_data()
	var restored := World.new()
	_check(restored.from_data(JSON.parse_string(JSON.stringify(before))) and restored.to_data() == before,
		"Imported terrain and living trees must round-trip through the normal save format without the source file", failures)
	for index: int in range(12): restored.step_tick()
	_check(restored.grid.vertex_height(Vector2i(10, 8)) == 2 and restored.grid.roads.is_empty(),
		"Continuing a loaded empty landscape must not flatten it or fabricate a village", failures)

static func _test_invalid_dense_data(failures: Array[String]) -> void:
	for entry: Dictionary in [{"format": "other"}, {"name": 3}, {"map_size": [256, 8]},
		{"map_size": [true, 8]}, {"map_size": [1.5, 8]}, {"map_size": [10]}, {"source": {}},
		{"terrain": []}, {"heights": []}]:
		var data: Dictionary = fixture()
		data.merge(entry, true)
		_reject(data, "invalid dimensions, header or missing grid rows", failures)
	for value: Variant in [-1, 65, true, "2", 1.5, INF, NAN, null]:
		var data: Dictionary = fixture()
		data["heights"][3][3] = value
		_reject(data, "invalid exact vertex height", failures)
	for row: Variant in ["gg", "gggggxgggr", ["g"]]:
		var data: Dictionary = fixture()
		data["terrain"][2] = row
		_reject(data, "invalid terrain material row", failures)

static func _test_invalid_tree_data(failures: Array[String]) -> void:
	for tree: Variant in [[0, 0, 1], [5, 4, 2], [9, 3, 2], [10, 0, 2], [2, 3, 3],
		[2, 3, true], [2, 3], null]:
		var data: Dictionary = fixture()
		data["trees"].append(tree)
		_reject(data, "overlapping, blocked, outside or malformed tree", failures)

static func _test_load_missing_file(failures: Array[String]) -> void:
	var result: Dictionary = Import.load_world("res://external_assets/maps/nonexistent-test-fixture.json")
	_check(result["world"] == null and not String(result["error"]).is_empty(),
		"Missing external map must produce an actionable failure, never a fake Mountainous Region", failures)

static func _reject(data: Dictionary, reason: String, failures: Array[String]) -> void:
	var before: Dictionary = data.duplicate(true)
	var result: Dictionary = Import.from_data(data)
	_check(result["world"] == null and not String(result["error"]).is_empty(),
		"Importer must reject " + reason + " without exposing a partial world", failures)
	# NaN is unequal to itself, so identity-sensitive tree/grid guarantees are
	# tested by the valid case; malformed data still never gets rewritten here.
	if not str(data).contains("nan"):
		_check(data == before, "Rejected terrain must not mutate its source", failures)

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
