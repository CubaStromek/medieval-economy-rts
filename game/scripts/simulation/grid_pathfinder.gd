class_name GridPathfinder
extends RefCounted

const GridMapSimClass = preload("res://scripts/simulation/grid_map_sim.gd")
const UNSPECIFIED_START: Vector2i = Vector2i(-2147483648, -2147483648)


## Binary min-heap of packed `priority * cell_count + cell_index` keys. The key
## order is exactly the historical (priority, row, column) tie-breaking.
class KeyHeap:
	extends RefCounted

	var keys := PackedInt64Array()

	func push(key: int) -> void:
		keys.append(key)
		var index: int = keys.size() - 1
		while index > 0:
			var parent: int = (index - 1) >> 1
			if keys[parent] <= key:
				break
			keys[index] = keys[parent]
			index = parent
		keys[index] = key

	func pop() -> int:
		var top: int = keys[0]
		var last: int = keys[keys.size() - 1]
		keys.resize(keys.size() - 1)
		var count: int = keys.size()
		if count == 0:
			return top
		var index: int = 0
		while true:
			var left: int = index * 2 + 1
			if left >= count:
				break
			var child: int = left + 1 if left + 1 < count and keys[left + 1] < keys[left] else left
			if keys[child] >= last:
				break
			keys[index] = keys[child]
			index = child
		keys[index] = last
		return top


## Packed walkability, traversable edges and connected regions for one grid.
## Temporary blockers and route costs (roads, trails and their links) are read
## live for every search, so only connectivity changes update this index.
class PathIndex:
	extends RefCounted

	# Same order as GridMapSim.MOVEMENT_DIRECTIONS; odd indices are diagonals.
	const DX: Array[int] = [0, 1, 1, 1, 0, -1, -1, -1]
	const DY: Array[int] = [-1, -1, 0, 1, 1, 1, 0, -1]

	var size := Vector2i.ZERO
	var cell_count: int = 0
	var walk := PackedByteArray()
	var twice_height := PackedInt32Array()
	var edges := PackedByteArray()
	var components := PackedInt32Array()
	var components_valid: bool = false
	var rebuild_count: int = 0
	var update_count: int = 0

	func sync(grid: GridMapSimClass) -> void:
		if grid.size != size or grid._path_dirty_full or grid.connectivity_revision != grid._path_tracked_revision:
			rebuild(grid)
		elif not grid._path_dirty_cells.is_empty():
			_update(grid, grid._path_dirty_cells.keys())
		else:
			return
		grid._path_dirty_cells.clear()
		grid._path_dirty_full = false
		grid._path_tracked_revision = grid.connectivity_revision
		components_valid = false

	func rebuild(grid: GridMapSimClass) -> void:
		rebuild_count += 1
		size = grid.size
		cell_count = size.x * size.y
		walk.resize(cell_count)
		twice_height.resize(cell_count)
		edges.resize(cell_count * 8)
		var walkable: PackedByteArray = _walkable_codes(grid)
		var heights: PackedInt32Array = grid._vertex_heights
		var terrain: PackedByteArray = grid._base_terrain
		for index: int in range(cell_count):
			_update_cell(grid, index, walkable, heights, terrain)
		for index: int in range(cell_count):
			_update_edges(index)
		components_valid = false

	func same_component(start: Vector2i, goal: Vector2i) -> bool:
		if not components_valid:
			_build_components()
		return components[start.y * size.x + start.x] == components[goal.y * size.x + goal.x]

	func find_path(grid: GridMapSimClass, start: Vector2i, goal: Vector2i, blockers: Dictionary) -> Array[Vector2i]:
		var width: int = size.x
		var minimum_cost: int = grid.minimum_movement_cost()
		var diagonal_minimum: int = GridMapSimClass.diagonal_duration_ticks(minimum_cost)
		var blocked: PackedByteArray = _blocked_cells(blockers)
		var move_ticks: PackedInt32Array = _terrain_move_ticks(grid)
		var road_ticks: int = maxi(1, int(grid.overlay_definition(GridMapSimClass.OVERLAY_STONE_ROAD).get("move_ticks", 6)))
		var trail_ticks: int = maxi(1, int(grid.overlay_definition(GridMapSimClass.OVERLAY_TRAIL).get("move_ticks", 6)))
		var terrain: PackedByteArray = grid._base_terrain
		var roads: Dictionary = grid.roads
		var trails: Dictionary = grid.dirt_trails
		var links: Dictionary = grid.trail_links
		var costs := PackedInt32Array()
		costs.resize(cell_count)
		costs.fill(-1)
		var came := PackedInt32Array()
		came.resize(cell_count)
		var start_index: int = start.y * width + start.x
		var goal_index: int = goal.y * width + goal.x
		costs[start_index] = 0
		came[start_index] = start_index
		var heap := KeyHeap.new()
		heap.push(_heuristic(start.x, start.y, goal, minimum_cost, diagonal_minimum) * cell_count + start_index)
		while not heap.keys.is_empty():
			var key: int = heap.pop()
			var index: int = key % cell_count
			var x: int = index % width
			var y: int = index / width
			var cost: int = key / cell_count - _heuristic(x, y, goal, minimum_cost, diagonal_minimum)
			# Improved routes insert a new key; obsolete keys are discarded.
			if cost != costs[index]:
				continue
			if index == goal_index:
				return _reconstruct(came, start_index, goal_index)
			var base: int = index * 8
			for direction: int in range(8):
				if edges[base + direction] == 0:
					continue
				var next_x: int = x + DX[direction]
				var next_y: int = y + DY[direction]
				var next: int = next_y * width + next_x
				if blocked[next] == 1:
					continue
				var diagonal: bool = (direction & 1) == 1
				if diagonal and (blocked[y * width + next_x] == 1 or blocked[next_y * width + x] == 1):
					continue
				var to := Vector2i(next_x, next_y)
				var duration: int
				if roads.has(to):
					duration = road_ticks
				elif trails.has(to):
					var link: Dictionary = links.get(GridMapSimClass.trail_link_key(Vector2i(x, y), to), {})
					duration = trail_ticks if bool(link.get("established", false)) else move_ticks[terrain[next]]
				else:
					duration = move_ticks[terrain[next]]
				if diagonal:
					duration = ceili(float(duration) * sqrt(2.0))
				var next_cost: int = cost + duration
				if costs[next] == -1 or next_cost < costs[next]:
					costs[next] = next_cost
					came[next] = index
					heap.push((next_cost + _heuristic(next_x, next_y, goal, minimum_cost, diagonal_minimum)) * cell_count + next)
		return []

	func find_nearest(grid: GridMapSimClass, start: Vector2i, goal_test: Callable, blockers: Dictionary) -> Array[Vector2i]:
		var width: int = size.x
		var blocked: PackedByteArray = _blocked_cells(blockers)
		var move_ticks: PackedInt32Array = _terrain_move_ticks(grid)
		var road_ticks: int = maxi(1, int(grid.overlay_definition(GridMapSimClass.OVERLAY_STONE_ROAD).get("move_ticks", 6)))
		var trail_ticks: int = maxi(1, int(grid.overlay_definition(GridMapSimClass.OVERLAY_TRAIL).get("move_ticks", 6)))
		var terrain: PackedByteArray = grid._base_terrain
		var roads: Dictionary = grid.roads
		var trails: Dictionary = grid.dirt_trails
		var links: Dictionary = grid.trail_links
		var costs := PackedInt32Array()
		costs.resize(cell_count)
		costs.fill(-1)
		var came := PackedInt32Array()
		came.resize(cell_count)
		var start_index: int = start.y * width + start.x
		costs[start_index] = 0
		came[start_index] = start_index
		# Dijkstra search finds the nearest valid cell by the same weighted travel
		# time used by ordinary workers; cost/cell ordering keeps it deterministic.
		var heap := KeyHeap.new()
		heap.push(start_index)
		while not heap.keys.is_empty():
			var key: int = heap.pop()
			var index: int = key % cell_count
			var cost: int = key / cell_count
			if cost != costs[index]:
				continue
			var x: int = index % width
			var y: int = index / width
			if index != start_index and bool(goal_test.call(Vector2i(x, y))):
				return _reconstruct(came, start_index, index)
			var base: int = index * 8
			for direction: int in range(8):
				if edges[base + direction] == 0:
					continue
				var next_x: int = x + DX[direction]
				var next_y: int = y + DY[direction]
				var next: int = next_y * width + next_x
				if blocked[next] == 1:
					continue
				var diagonal: bool = (direction & 1) == 1
				if diagonal and (blocked[y * width + next_x] == 1 or blocked[next_y * width + x] == 1):
					continue
				var to := Vector2i(next_x, next_y)
				var duration: int
				if roads.has(to):
					duration = road_ticks
				elif trails.has(to):
					var link: Dictionary = links.get(GridMapSimClass.trail_link_key(Vector2i(x, y), to), {})
					duration = trail_ticks if bool(link.get("established", false)) else move_ticks[terrain[next]]
				else:
					duration = move_ticks[terrain[next]]
				if diagonal:
					duration = ceili(float(duration) * sqrt(2.0))
				var next_cost: int = cost + duration
				if costs[next] == -1 or next_cost < costs[next]:
					costs[next] = next_cost
					came[next] = index
					heap.push(next_cost * cell_count + next)
		return []

	func _update(grid: GridMapSimClass, cells: Array) -> void:
		update_count += 1
		var walkable: PackedByteArray = _walkable_codes(grid)
		var heights: PackedInt32Array = grid._vertex_heights
		var terrain: PackedByteArray = grid._base_terrain
		# An edge depends on its two cells and, diagonally, on both flanks. All
		# of those are within one cell of the edge's origin.
		var origins: Dictionary = {}
		for cell: Vector2i in cells:
			if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
				continue
			_update_cell(grid, cell.y * size.x + cell.x, walkable, heights, terrain)
			for y: int in range(maxi(0, cell.y - 1), mini(size.y, cell.y + 2)):
				for x: int in range(maxi(0, cell.x - 1), mini(size.x, cell.x + 2)):
					origins[y * size.x + x] = true
		for index: int in origins:
			_update_edges(index)

	func _update_cell(grid: GridMapSimClass, index: int, walkable: PackedByteArray,
			heights: PackedInt32Array, terrain: PackedByteArray) -> void:
		var x: int = index % size.x
		var y: int = index / size.x
		var stride: int = size.x + 1
		var top_left: int = heights[y * stride + x]
		var top_right: int = heights[y * stride + x + 1]
		var bottom_right: int = heights[(y + 1) * stride + x + 1]
		var bottom_left: int = heights[(y + 1) * stride + x]
		twice_height[index] = top_left + bottom_right
		var slope: int = maxi(maxi(top_left, top_right), maxi(bottom_right, bottom_left)) \
			- mini(mini(top_left, top_right), mini(bottom_right, bottom_left))
		walk[index] = 1 if slope <= GridMapSimClass.MAX_WALK_SLOPE and walkable[terrain[index]] == 1 \
			and not grid.blocked_by.has(Vector2i(x, y)) else 0

	func _update_edges(index: int) -> void:
		var x: int = index % size.x
		var y: int = index / size.x
		var limit: int = GridMapSimClass.MAX_WALK_SLOPE * 2
		var here: int = twice_height[index]
		for direction: int in range(8):
			var next_x: int = x + DX[direction]
			var next_y: int = y + DY[direction]
			var open: bool = walk[index] == 1 and next_x >= 0 and next_y >= 0 and next_x < size.x and next_y < size.y
			if open:
				var next: int = next_y * size.x + next_x
				open = walk[next] == 1 and absi(here - twice_height[next]) <= limit
				if open and (direction & 1) == 1:
					var flank_x: int = y * size.x + next_x
					var flank_y: int = next_y * size.x + x
					open = walk[flank_x] == 1 and walk[flank_y] == 1 \
						and absi(here - twice_height[flank_x]) <= limit and absi(twice_height[flank_x] - twice_height[next]) <= limit \
						and absi(here - twice_height[flank_y]) <= limit and absi(twice_height[flank_y] - twice_height[next]) <= limit
			edges[index * 8 + direction] = 1 if open else 0

	func _build_components() -> void:
		components.resize(cell_count)
		components.fill(-1)
		var queue := PackedInt32Array()
		var label: int = 0
		for first: int in range(cell_count):
			if walk[first] == 0 or components[first] != -1:
				continue
			queue.clear()
			queue.append(first)
			components[first] = label
			var head: int = 0
			while head < queue.size():
				var index: int = queue[head]
				head += 1
				var x: int = index % size.x
				var y: int = index / size.x
				for direction: int in range(8):
					if edges[index * 8 + direction] == 0:
						continue
					var next: int = (y + DY[direction]) * size.x + x + DX[direction]
					if components[next] == -1:
						components[next] = label
						queue.append(next)
			label += 1
		components_valid = true

	func _blocked_cells(blockers: Dictionary) -> PackedByteArray:
		var blocked := PackedByteArray()
		blocked.resize(cell_count)
		blocked.fill(0)
		for cell: Vector2i in blockers:
			if cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y:
				blocked[cell.y * size.x + cell.x] = 1
		return blocked

	func _reconstruct(came: PackedInt32Array, start_index: int, goal_index: int) -> Array[Vector2i]:
		var reversed_path: Array[Vector2i] = []
		var current: int = goal_index
		while current != start_index:
			reversed_path.append(Vector2i(current % size.x, current / size.x))
			current = came[current]
		reversed_path.reverse()
		return reversed_path

	static func _heuristic(x: int, y: int, goal: Vector2i, minimum_cost: int, diagonal_minimum: int) -> int:
		var dx: int = absi(x - goal.x)
		var dy: int = absi(y - goal.y)
		var diagonal_steps: int = mini(dx, dy)
		return diagonal_steps * diagonal_minimum + (maxi(dx, dy) - diagonal_steps) * minimum_cost

	static func _walkable_codes(grid: GridMapSimClass) -> PackedByteArray:
		var codes := PackedByteArray()
		for terrain_id: String in GridMapSimClass.BASE_TERRAIN_IDS:
			codes.append(1 if bool(grid.terrain_definition(terrain_id).get("walkable", false)) else 0)
		return codes

	static func _terrain_move_ticks(grid: GridMapSimClass) -> PackedInt32Array:
		var ticks := PackedInt32Array()
		for terrain_id: String in GridMapSimClass.BASE_TERRAIN_IDS:
			ticks.append(maxi(1, int(grid.terrain_definition(terrain_id).get("move_ticks", 6))))
		return ticks


static func find_path(
	grid: GridMapSimClass,
	start: Vector2i,
	goal: Vector2i,
	temporary_blockers: Dictionary = {}
) -> Array[Vector2i]:
	if start == goal:
		return []
	if not grid.is_walkable(start) or not grid.is_walkable(goal) or temporary_blockers.has(goal):
		return []
	var index: PathIndex = path_index(grid)
	# Temporary blockers only remove edges, so a goal in another static region
	# stays unreachable; skip exploring the whole start region to prove it.
	if not index.same_component(start, goal):
		return []
	return index.find_path(grid, start, goal, temporary_blockers)


static func find_path_to_nearest(
	grid: GridMapSimClass,
	start: Vector2i,
	goal_test: Callable,
	temporary_blockers: Dictionary = {}
) -> Array[Vector2i]:
	if not grid.is_walkable(start):
		return []
	return path_index(grid).find_nearest(grid, start, goal_test, temporary_blockers)


## True exactly when find_path(grid, start, goal) without blockers finds a route.
static func is_reachable(grid: GridMapSimClass, start: Vector2i, goal: Vector2i) -> bool:
	if start == goal or not grid.is_walkable(start) or not grid.is_walkable(goal):
		return false
	return path_index(grid).same_component(start, goal)


## The grid's current index, updated from its tracked connectivity changes.
static func path_index(grid: GridMapSimClass) -> PathIndex:
	var index: PathIndex = grid.path_index as PathIndex
	if index == null:
		index = PathIndex.new()
		grid.path_index = index
	index.sync(grid)
	return index


static func path_cost(
	grid: GridMapSimClass,
	path: Array[Vector2i],
	start: Vector2i = UNSPECIFIED_START
) -> int:
	var result: int = 0
	var previous: Vector2i = start
	for cell: Vector2i in path:
		# Legacy callers without a start retain a cardinal first step. New route
		# comparisons must supply start because that first step can be diagonal.
		result += grid.movement_cost(cell) if previous == UNSPECIFIED_START else grid.step_cost(previous, cell)
		previous = cell
	return result


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


# Dictionary heap retained for Workplaces' bounded multi-target search.
static func _heap_push(heap: Array[Dictionary], entry: Dictionary) -> void:
	heap.append(entry)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _heap_entry_before(heap[index], heap[parent]):
			break
		var swap: Dictionary = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent


static func _heap_pop(heap: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = heap[0]
	var tail: Dictionary = heap.pop_back()
	if heap.is_empty():
		return result
	heap[0] = tail
	var index: int = 0
	while true:
		var left: int = index * 2 + 1
		if left >= heap.size():
			break
		var right: int = left + 1
		var best_child: int = left
		if right < heap.size() and _heap_entry_before(heap[right], heap[left]):
			best_child = right
		if not _heap_entry_before(heap[best_child], heap[index]):
			break
		var swap: Dictionary = heap[index]
		heap[index] = heap[best_child]
		heap[best_child] = swap
		index = best_child
	return result


static func _heap_entry_before(a: Dictionary, b: Dictionary) -> bool:
	var a_priority: int = int(a["priority"])
	var b_priority: int = int(b["priority"])
	if a_priority != b_priority:
		return a_priority < b_priority
	return _cell_before(a["cell"] as Vector2i, b["cell"] as Vector2i)
