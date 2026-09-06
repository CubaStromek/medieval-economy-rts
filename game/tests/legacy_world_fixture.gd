extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")

# Historical economy/movement scenarios deliberately retain their compact,
# one-cell building layouts. They exercise the same geometry supported for
# migrated saves; production worlds and new footprint suites use revision 1.
static func create(map_size: Vector2i = World.DEFAULT_MAP_SIZE) -> World:
	var world := World.new(map_size)
	world.default_footprint_version = 0
	return world
