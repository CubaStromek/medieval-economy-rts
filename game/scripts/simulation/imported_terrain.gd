extends RefCounted

# Local, data-only map import. Proprietary source maps and converted landscapes
# remain external; this loader never reads scripts, downloads URLs or modifies
# an existing world. Invalid input yields no partially usable world.
const World = preload("res://scripts/simulation/simulation_world.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const DEFAULT_PATH: String = "res://external_assets/maps/mountainous-region.json"
const FORMAT: String = "medieval-terrain-v1"
const MAX_BYTES: int = 8 * 1024 * 1024
const TERRAIN_CODES: Dictionary = {"g": 0, "d": 1, "w": 2, "r": 3}

static func load_world(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("Local terrain data is missing. Import the map before opening this landscape.")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _failure("Terrain file cannot be read or exceeds the 8 MB limit.")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _failure("Terrain file is not valid JSON.")
	return from_data(parser.data)

static func from_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _failure("Terrain must be a data object.")
	var data: Dictionary = value
	if data.get("format") != FORMAT or not data.get("name") is String:
		return _failure("Unsupported terrain format or missing map name.")
	var title: String = String(data["name"]).strip_edges()
	if title.is_empty() or title.length() > 100:
		return _failure("Invalid terrain name.")
	var dimensions: Variant = data.get("map_size")
	if not dimensions is Array or dimensions.size() != 2:
		return _failure("Terrain dimensions must contain width and height.")
	if not _integer(dimensions[0], 1, 255) or not _integer(dimensions[1], 1, 255):
		return _failure("Terrain dimensions exceed the supported 1–255 cells.")
	var size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	if not _valid_source(data.get("source"), size):
		return _failure("Missing or invalid terrain provenance.")
	var raw_heights: Variant = data.get("heights")
	if not raw_heights is Array or raw_heights.size() != size.y + 1:
		return _failure("Terrain needs one more row of corner heights than cells.")
	var heights := PackedInt32Array()
	for row: Variant in raw_heights:
		if not row is Array or row.size() != size.x + 1:
			return _failure("Terrain corner-height row has the wrong width.")
		for height: Variant in row:
			if not _integer(height, 0, Grid.MAX_HEIGHT):
				return _failure("Terrain height is not an integer in the supported range.")
			heights.append(int(height))
	var raw_terrain: Variant = data.get("terrain")
	if not raw_terrain is Array or raw_terrain.size() != size.y:
		return _failure("Terrain material rows do not match its dimensions.")
	var terrain := PackedByteArray()
	for row: Variant in raw_terrain:
		if not row is String or row.length() != size.x:
			return _failure("Terrain material row has the wrong width.")
		for code: String in row:
			if not TERRAIN_CODES.has(code):
				return _failure("Terrain contains an unsupported material.")
			terrain.append(int(TERRAIN_CODES[code]))
	var raw_trees: Variant = data.get("trees")
	if not raw_trees is Array or raw_trees.size() > size.x * size.y:
		return _failure("Terrain contains an invalid tree list.")
	# Populate a private fresh grid only after all dense terrain is validated.
	# Bulk assignment avoids thousands of incremental path/trail updates before
	# any paths, surfaces, entities or rendering readers exist.
	var world := World.new(size)
	world.grid._vertex_heights = heights
	world.grid._base_terrain = terrain
	world.grid.invalidate_connectivity()
	world.grid._record_full_render_change()
	var occupied: Dictionary = {}
	var ages: Array[int] = [0, World.TREE_YOUNG_AGE_TICKS, World.TREE_MATURE_AGE_TICKS]
	for entry: Variant in raw_trees:
		if not entry is Array or entry.size() != 3:
			return _failure("Tree data must contain x, y and growth stage.")
		if not _integer(entry[0], 0, size.x - 1) or not _integer(entry[1], 0, size.y - 1) or not _integer(entry[2], 0, 2):
			return _failure("Tree position or growth stage is invalid.")
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if occupied.has(cell) or not world.grid.allows_trees(cell):
			return _failure("A tree overlaps another tree or unsuitable ground.")
		occupied[cell] = true
		world._create_tree(cell, 5, ages[int(entry[2])])
	world.tick = 1000 # 09:00, readable daylight for the imported landscape.
	world.grid.restore_trail_clock(world.tick)
	world.economy_enabled = true
	world._push_event("%s · importovaná krajina připravena. Kolečko myši: přiblížení, šipky nebo tažení prostředním tlačítkem: průzkum." % title)
	return {"world": world, "error": "", "name": title, "source": (data["source"] as Dictionary).duplicate(true)}

static func _valid_source(value: Variant, size: Vector2i) -> bool:
	if not value is Dictionary:
		return false
	var source: Dictionary = value
	if not source.get("url") is String or not source.get("sha256") is String:
		return false
	var digest: String = source["sha256"]
	if digest.length() != 64 or String(source["url"]).length() > 2048:
		return false
	for character: String in digest:
		if not "0123456789abcdef".contains(character):
			return false
	var vertices: Variant = source.get("vertex_size")
	if not vertices is Array or vertices.size() != 2:
		return false
	if not _integer(vertices[0], 2, 256) or not _integer(vertices[1], 2, 256):
		return false
	if int(vertices[0]) != size.x + 1 or int(vertices[1]) != size.y + 1:
		return false
	if not _integer(source.get("revision"), 0, 2147483647) or not _integer(source.get("height_offset"), 0, 255):
		return false
	var scale: Variant = source.get("height_scale")
	return (scale is int or scale is float) and is_finite(float(scale)) and float(scale) > 0.0 and float(scale) <= 1.0

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _failure(message: String) -> Dictionary:
	return {"world": null, "error": message}
