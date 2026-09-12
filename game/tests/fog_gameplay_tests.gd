extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Scene = preload("res://scenes/main.tscn")
const TEST_COUNT: int = 4


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	for map_id: String in ["test", "economy", "relief"]:
		var main = Scene.instantiate()
		main.honor_launch_arguments = false
		main.demo_kind = map_id
		host.add_child(main)
		main.set_process(false)
		_check(main.world.fog.enabled and not main.world.fog.visible.is_empty(),
			"Every new playable %s map must actually start with local fog and useful settlement sight" % map_id, failures)
		main.free()
	var main = Scene.instantiate()
	main.honor_launch_arguments = false
	host.add_child(main)
	main.set_process(false)
	var original: Dictionary = main.world.fog.explored.duplicate()
	var all: Array[Vector2i] = []
	for y: int in range(main.world.grid.size.y):
		for x: int in range(main.world.grid.size.x):
			all.append(Vector2i(x, y))
	_check(original.size() < all.size(), "The starter must contain genuinely unexplored black terrain", failures)
	main.world.fog.restore_explored(all)
	main._reset_demo()
	_check(main.world.fog.enabled and main.world.fog.explored == original,
		"Starting over must discard the previous game's discoveries and restore only initial settlement sight", failures)
	main.free()
	for legacy: bool in [true, false]:
		var source = World.new(Vector2i(30, 18))
		source.spawn_worker(Vector2i(3, 3), "builder", 0, false)
		var data: Dictionary = JSON.parse_string(JSON.stringify(source.to_data()))
		if legacy:
			data["version"] = 17
			data.erase("fog")
			for worker: Dictionary in data["workers"]:
				worker.erase("owner_id")
		var restored = World.new()
		_check(restored.from_data(data), "The gameplay migration fixture must be a valid saved world", failures)
		var view = Scene.instantiate()
		view.honor_launch_arguments = false
		view.world = restored
		host.add_child(view)
		view.set_process(false)
		if legacy:
			_check(view.world.fog.enabled and not view.world.fog.legacy_reveal_pending
				and view.world.is_cell_explored(Vector2i(29, 17)) and not view.world.is_cell_visible(Vector2i(29, 17)),
				"Opening an actual old-save game activates fog without erasing previously visible map knowledge", failures)
		else:
			_check(not view.world.fog.enabled and view.world.is_cell_visible(Vector2i(29, 17)),
				"A deliberately fog-disabled v18 authoring save must not be mistaken for an old game", failures)
		view.free()
	return failures


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
