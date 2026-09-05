class_name TestLevel
extends RefCounted

const ReliefDemoClass = preload("res://scripts/simulation/relief_demo.gd")

const MAP_SIZE: Vector2i = ReliefDemoClass.MAP_SIZE
const BUILDING_CELLS: Dictionary = {
	"warehouse": Vector2i(7, 16),
	"school": Vector2i(3, 16),
}
const STARTING_GOLD: int = 50
const STARTING_LOGS: int = 20
const STARTING_PLANKS: int = 20
const STARTING_STONE: int = 20
const STONE_DEPOSIT_CELLS: Array[Vector2i] = [Vector2i(20, 16), Vector2i(20, 17)]
const STONE_PER_DEPOSIT: int = 90
const FISH_DEPOSIT_CELLS: Array[Vector2i] = [Vector2i(3, 18), Vector2i(3, 20)]
const FISH_PER_DEPOSIT: int = 40
const FISHER_HUT_SITE: Vector2i = Vector2i(5, 19)


static func setup(world: Variant) -> void:
	assert(world.grid.size == MAP_SIZE and world.buildings.is_empty()
		and world.workers.is_empty() and not world.economy_enabled,
		"Test level requires a fresh world with MAP_SIZE")
	ReliefDemoClass.setup_terrain(world)
	var ids: Dictionary = {}
	# Author completed buildings before enabling normal construction costs.
	for type: String in BUILDING_CELLS:
		ids[type] = world.place_building(type, BUILDING_CELLS[type])
		assert(int(ids[type]) != 0, "Invalid test level building: " + type)
	ReliefDemoClass.plant_trees(world)
	# Accessible deposits on the western foot of the ridge let a quarry replace
	# the finite starter stone. Painted rock alone is not an extractable resource.
	for cell: Vector2i in STONE_DEPOSIT_CELLS:
		var deposit_id: int = int(world.add_deposit(cell, "stone", STONE_PER_DEPOSIT))
		assert(deposit_id != 0, "Invalid starter stone deposit")
	# Stock the existing pond without changing its terrain or granting a free
	# producer. A player-built hut on the eastern bank can reach both shoals.
	for cell: Vector2i in FISH_DEPOSIT_CELLS:
		var deposit_id: int = int(world.add_deposit(cell, "fish", FISH_PER_DEPOSIT))
		assert(deposit_id != 0, "Invalid starter fish deposit")
	# One of the starter gold is already in school so the player can train the first
	# carrier from a unit-free start. That carrier delivers the remaining gold.
	world.buildings[int(ids["warehouse"])]["storage"]["gold"] = STARTING_GOLD - 1
	world.buildings[int(ids["warehouse"])]["storage"]["log"] = STARTING_LOGS
	# Logs must be sawn before construction. Seed the wood/stone cycle with
	# finished materials without making the first production buildings free.
	world.buildings[int(ids["warehouse"])]["storage"]["plank"] = STARTING_PLANKS
	world.buildings[int(ids["warehouse"])]["storage"]["stone"] = STARTING_STONE
	world.buildings[int(ids["school"])]["inputs"]["gold"] = 1
	world.economy_enabled = true
	world._push_event("Start: 20 planks + 20 stone for construction; 20 logs need a Sawmill. Train a Carrier, then a Builder at the School. Stone lies at the western foot of the ridge; fish inhabit the southwestern pond.")
