extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")

# Historical economy/movement scenarios deliberately retain their compact,
# one-cell building layouts. They exercise the same geometry supported for
# migrated saves; production worlds and new footprint suites use revision 1.
static func create(map_size: Vector2i = World.DEFAULT_MAP_SIZE) -> World:
	var world := World.new(map_size)
	world.default_footprint_version = 0
	return world


# Pre-v18 players had already seen the whole map. Keep migration tests strict
# about every original gameplay field while explicitly expecting that known
# terrain, instead of comparing it to a fresh unplayed world's empty history.
static func expected_pre_fog_migration(snapshot: Dictionary) -> Dictionary:
	var expected: Dictionary = expected_pre_nutrition_migration(snapshot)
	var explored: Array[Array] = []
	for y: int in range(int(snapshot["map_size"][1])):
		for x: int in range(int(snapshot["map_size"][0])):
			explored.append([x, y])
	expected["fog"] = {"enabled": false, "local_player_id": 1, "explored": explored}
	return expected


# Historical saves retain their real satiety, meals, goods and clock, but had
# no record of multi-day deprivation or fractional metabolic/work progress.
static func expected_pre_nutrition_migration(snapshot: Dictionary) -> Dictionary:
	var expected: Dictionary = expected_pre_pause_migration(snapshot)
	for worker: Dictionary in expected["workers"]:
		for field: String in ["nutrition_deficit_ticks", "condition_decay_remainder", "nutrition_recovery_remainder", "work_effort_remainder"]:
			worker[field] = 0
	return expected


# V19 already records exact nutritional history. Its only v20 migration is
# the newly explicit default that existing citizens and buildings are active.
static func expected_pre_pause_migration(snapshot: Dictionary) -> Dictionary:
	var expected: Dictionary = snapshot.duplicate(true)
	for entities: String in ["workers", "buildings"]:
		for entity: Dictionary in expected[entities]:
			entity["enabled"] = true
	return expected
