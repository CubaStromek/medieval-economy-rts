extends RefCounted

const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const POSITIONS: Dictionary = {
	"warehouse": Vector2i(1, 3), "school": Vector2i(6, 3), "town_hall": Vector2i(11, 3),
	"marketplace": Vector2i(16, 3), "watchtower": Vector2i(21, 3), "quarry": Vector2i(26, 3),
	# Preserve the original hut threshold at (8,8) with its expanded v2 anchor.
	"inn": Vector2i(1, 8), "lumber_hut": Vector2i(5, 9), "forester_hut": Vector2i(11, 8),
	"sawmill": Vector2i(16, 8), "armour_workshop": Vector2i(21, 8), "iron_mine": Vector2i(26, 8),
	"bakery": Vector2i(1, 13), "mill": Vector2i(6, 13), "weapon_workshop": Vector2i(11, 13),
	"weapon_smithy": Vector2i(16, 13), "iron_smithy": Vector2i(21, 13), "gold_mine": Vector2i(26, 13),
	"butcher": Vector2i(1, 18), "tannery": Vector2i(6, 18), "armour_smithy": Vector2i(11, 18),
	"barracks": Vector2i(16, 18), "metallurgist": Vector2i(21, 18), "coal_mine": Vector2i(26, 18),
	"fisher_hut": Vector2i(1, 23), "farm": Vector2i(6, 23), "vineyard": Vector2i(11, 23),
	"swine_farm": Vector2i(16, 23), "stables": Vector2i(21, 23),
}
const WORKERS_HOUSE_POSITIONS: Array[Vector2i] = [
	Vector2i(1, 28), Vector2i(6, 28), Vector2i(11, 28),
	Vector2i(16, 28), Vector2i(21, 28), Vector2i(26, 28),
]


static func setup(world: Variant) -> void:
	world.grid = Grid.new(Vector2i(34, 30))
	world.grid.configure_movement(world.catalog.movement)
	for row: Array in [[3, "stone"], [8, "iron_ore"], [13, "gold_ore"]]:
		for x: int in [29, 30]:
			var cell := Vector2i(x, int(row[0]))
			world.grid.set_base_terrain(cell, "rock")
			world.add_deposit(cell, String(row[1]), 90)
	world.add_deposit(Vector2i(29, 18), "coal", 160)
	world.add_deposit(Vector2i(29, 19), "coal", 160)
	for y: int in range(21, 28):
		world.grid.set_base_terrain(Vector2i(0, y), "water")
	world.add_deposit(Vector2i(0, 23), "fish", 60)
	world.add_deposit(Vector2i(0, 24), "fish", 60)
	var ids: Dictionary = {}
	for type: String in POSITIONS:
		ids[type] = world.place_building(type, POSITIONS[type])
		assert(int(ids[type]) != 0, "Invalid full-footprint demo building: " + type)
	for cell: Vector2i in WORKERS_HOUSE_POSITIONS:
		assert(world.place_building("workers_house", cell) != 0,
			"Invalid full-footprint demo Workers' Cottage")
	for y: int in [4, 9, 14, 19, 24, 29]:
		for x: int in range(1, 31):
			world.place_road(Vector2i(x, y))
	for x: int in [5, 10, 15, 20, 25, 30]:
		for y: int in range(4, 30):
			world.place_road(Vector2i(x, y))
	# The three new front contacts interrupt row 9. Join its western inn road
	# to the southern avenue via the clear verge; the hut door stays at (8,9).
	assert(world.grid.roads.has(Vector2i(4, 9)) and world.grid.roads.has(Vector2i(5, 10)),
		"Expanded-hut detour must join the existing roads")
	assert(world.place_road(Vector2i(4, 10)), "Invalid expanded-hut western road")
	for cell: Vector2i in [Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10), Vector2i(6, 11), Vector2i(7, 11)]:
		world.add_tree(cell, 5)
	for y: int in range(25, 27):
		for x: int in range(6, 10):
			world.place_field(Vector2i(x, y))
		for x: int in range(11, 15):
			world.place_field(Vector2i(x, y), "vine")
	var stock: Dictionary = {"plank": 60, "stone": 50, "gold": 30, "bread": 24, "sausage": 12, "wine": 12, "fish": 12}
	for resource: String in stock:
		world.buildings[int(ids["warehouse"])]["storage"][resource] = stock[resource]
	for type: String in POSITIONS:
		var role: String = String(world.catalog.building(type).get("worker", ""))
		if role.is_empty():
			continue
		var building: Dictionary = world.buildings[int(ids[type])]
		var worker_id: int = world.spawn_worker(building["entrance"], role, int(building["id"]))
		assert(worker_id > 0, "Invalid full-footprint demo worker: " + role)
	for cell: Vector2i in [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4)]:
		assert(world.spawn_worker(cell, "carrier") > 0)
	assert(world.spawn_worker(Vector2i(12, 4), "builder") > 0)
	assert(world.spawn_worker(Vector2i(13, 4), "builder") > 0)
	assert(world.spawn_worker(Vector2i(14, 4), "recruit") > 0)
	for type: String in ["weapon_workshop", "armour_workshop", "weapon_smithy", "armour_smithy"]:
		for recipe: String in world.catalog.building(type)["recipes"]:
			world.queue_production(int(ids[type]), recipe)
	world.queue_recruitment(int(ids["barracks"]), "axe_fighter")
	world.economy_enabled = true
	world._push_event("Full economy settlement: all workshops, six two-person Workers' Cottages and connected roads.")
