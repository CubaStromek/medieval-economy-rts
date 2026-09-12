class_name ReliefDemo
extends RefCounted

# Authored proof map: logistics climb the meadow, while the eastern ridge can
# only be crossed through the wide low pass. Heights are shared grid corners.
const MAP_SIZE: Vector2i = Vector2i(28, 22)
const PLATEAU_HEIGHT: int = 4
const LOWLAND: Vector2i = Vector2i(9, 17)
const PLATEAU: Vector2i = Vector2i(9, 6)
const RAMP: Vector2i = Vector2i(9, 10)
const RIDGE: Vector2i = Vector2i(23, 5)
const PASS_CELL: Vector2i = Vector2i(23, 12)
const PASS_WEST: Vector2i = Vector2i(19, 12)
const PASS_EAST: Vector2i = Vector2i(27, 12)
const LOWLAND_BUILD_SITE: Vector2i = Vector2i(15, 14)
const PLATEAU_BUILD_SITE: Vector2i = Vector2i(8, 3)
const BUILDING_CELLS: Dictionary = {
	"warehouse": Vector2i(7, 16),
	# The v2 notched foundation keeps the former threshold at (13,14).
	"lumber_hut": Vector2i(10, 15),
	"forester_hut": Vector2i(10, 19),
	"sawmill": Vector2i(10, 5),
	"school": Vector2i(3, 16),
	"inn": Vector2i(13, 19),
}
const STARTING_STOCK: Dictionary = {
	"plank": 20, "stone": 40, "gold": 12,
	"bread": 48, "sausage": 24, "wine": 24, "fish": 24,
}


static func setup(world: Variant) -> void:
	assert(world.grid.size == MAP_SIZE and world.buildings.is_empty() and world.workers.is_empty(),
		"Relief demo requires a fresh world with MAP_SIZE")
	setup_terrain(world)
	setup_village(world)


# Shared natural terrain for the populated demo and the minimal test level.
static func setup_terrain(world: Variant) -> void:
	for y: int in range(MAP_SIZE.y + 1):
		for x: int in range(MAP_SIZE.x + 1):
			world.grid.set_vertex_height(Vector2i(x, y), _height(x, y))
	for y: int in range(MAP_SIZE.y):
		for x: int in range(MAP_SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			if x >= 20 and x <= 25 and (y < 11 or y > 12):
				world.grid.set_base_terrain(cell, "rock")
			elif x >= 19 and y >= 11 and y <= 12:
				world.grid.set_base_terrain(cell, "dirt")
	# A small lowland pond leaves both building reserves and the pass accessible.
	for y: int in range(18, 21):
		for x: int in range(1, 4):
			world.grid.set_base_terrain(Vector2i(x, y), "water")


static func setup_village(world: Variant) -> void:
	var ids: Dictionary = {}
	for type: String in BUILDING_CELLS:
		ids[type] = world.place_building(type, BUILDING_CELLS[type])
		assert(int(ids[type]) != 0, "Invalid relief demo building: " + type)
	# Keep one-cell road gutters outside every authored footprint and doorway.
	for y: int in range(4, 14):
		world.grid.add_road(Vector2i(9, y))
	for x: int in range(9, 12):
		world.grid.add_road(Vector2i(x, 6))
	for y: int in [13, 14, 16, 17]:
		world.grid.add_road(Vector2i(10, y))
	world.grid.add_road(Vector2i(9, 13))
	for x: int in range(3, 18):
		world.grid.add_road(Vector2i(x, 17))
	# The new front shed/rack occupies (10..12,15). Approach the unchanged
	# doorway from the east, keeping the lowland-to-meadow road connected.
	for x: int in range(13, 15):
		assert(world.grid.add_road(Vector2i(x, 15)), "Invalid expanded-hut entrance road")
	for y: int in range(12, 17):
		assert(world.grid.add_road(Vector2i(14, y)), "Invalid expanded-hut eastern road")
	for x: int in range(10, 18):
		assert(world.grid.add_road(Vector2i(x, 16)), "Invalid expanded-hut lowland connector")
	for x: int in range(9, 15):
		assert(world.grid.add_road(Vector2i(x, 12)), "Invalid expanded-hut uphill connector")
	for y: int in range(17, 21):
		world.grid.add_road(Vector2i(17, y))
	for x: int in range(10, 18):
		world.grid.add_road(Vector2i(x, 20))
	for x: int in range(10, 28):
		world.grid.add_dirt_trail(Vector2i(x, 12))
	plant_trees(world)

	var warehouse: Dictionary = world.buildings[int(ids["warehouse"])]
	for resource: String in STARTING_STOCK:
		warehouse["storage"][resource] = int(STARTING_STOCK[resource])
	_spawn(world, Vector2i(4, 13), "lumberjack", int(ids["lumber_hut"]))
	_spawn(world, Vector2i(11, 6), "carpenter", int(ids["sawmill"]))
	_spawn(world, Vector2i(12, 20), "gardener", int(ids["forester_hut"]))
	_spawn(world, Vector2i(6, 17), "builder")
	for cell: Vector2i in [Vector2i(6, 15), Vector2i(10, 16), Vector2i(11, 16), Vector2i(12, 16)]:
		_spawn(world, cell, "carrier")
	# Starter buildings/roads are authored complete. Expansion retains the same
	# delivered construction materials, paid training and hunger rules as economy.
	world.economy_enabled = true
	world._push_event("Relief demo: logs climb the meadow to the sawmill; planks return to the lowland warehouse.")


static func plant_trees(world: Variant) -> void:
	for tree_cell: Vector2i in [
		Vector2i(1, 8), Vector2i(2, 8), Vector2i(2, 10), Vector2i(3, 10),
		Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 13), Vector2i(2, 14),
		Vector2i(5, 3), Vector2i(6, 3), Vector2i(5, 5), Vector2i(6, 6),
	]:
		var tree_id: int = int(world.add_tree(tree_cell, 5))
		assert(tree_id != 0, "Invalid relief demo tree")


static func _height(x: int, y: int) -> int:
	var meadow_x: int = clampi(mini(x - 2, 17 - x) * 2, 0, PLATEAU_HEIGHT)
	var meadow_y: int = clampi(mini(y * 2, 12 - y), 0, PLATEAU_HEIGHT)
	var meadow: int = mini(meadow_x, meadow_y)
	var ridge_profile: Array[int] = [0, 6, 11, 14, 10, 5, 0]
	var ridge: int = 0
	if x >= 20 and x <= 26:
		# Three zero-height vertex rows make a two-cell passage, not a painted
		# opening whose hidden slope would still block movement.
		var distance_from_pass: int = maxi(0, absi(y - 12) - 1)
		ridge = mini(ridge_profile[x - 20], distance_from_pass * 5)
		if distance_from_pass > 2 and x == 23:
			ridge += 1 if y % 5 <= 1 else 0
	return maxi(meadow, ridge)


static func _spawn(world: Variant, cell: Vector2i, role: String, home_id: int = 0) -> void:
	var worker_id: int = int(world.spawn_worker(cell, role, home_id))
	assert(worker_id != 0, "Invalid relief demo worker: " + role)
