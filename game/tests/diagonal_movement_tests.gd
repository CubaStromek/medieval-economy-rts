extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Grid = preload("res://scripts/simulation/grid_map_sim.gd")
const View = preload("res://scripts/view/main_view.gd")
const TEST_COUNT: int = 9


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_actual_steps_in_all_eight_directions,
		_test_surface_step_timing_and_interpolation,
		_test_carrier_diagonal_traffic_is_step_local,
		_test_cached_diagonal_rechecks_static_corner,
		_test_cached_diagonal_rechecks_occupied_flank,
		_test_diagonal_swap_surface_durations,
		_test_diagonal_swap_waits_for_both_workers,
		_test_diagonal_swap_cannot_cut_occupied_flank,
		_test_crossing_diagonals_make_progress_without_overlap,
	]:
		test.call(failures)
	return failures


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _expect_reservations(world: Variant, failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for worker: Dictionary in world.workers.values():
		var cell: Vector2i = worker["position"]
		_expect(not seen.has(cell), "Moving workers must never share a logical tile", failures)
		seen[cell] = true
		_expect(int(world.tile_reservations.get(cell, 0)) == int(worker["id"]),
			"Each moving worker retains exactly its own tile reservation", failures)
	_expect(world.tile_reservations.size() == world.workers.size(),
		"Movement and swaps must not leak tile reservations", failures)


static func _test_actual_steps_in_all_eight_directions(failures: Array[String]) -> void:
	for direction: Vector2i in Grid.MOVEMENT_DIRECTIONS:
		var world := World.new(Vector2i(7, 7))
		var start := Vector2i(3, 3)
		var goal: Vector2i = start + direction
		var id: int = world.spawn_worker(start, "builder")
		var worker: Dictionary = world.workers[id]
		_expect(world._move_worker_to(worker, goal), "Every compass direction admits a real worker route", failures)
		world.step_tick()
		_expect(worker["position"] == goal and worker["previous_position"] == start,
			"A real simulation step supports direction %s" % direction, failures)
		_expect(int(worker["visual_progress_ticks"]) == 0,
			"Each new direction starts its visible movement at the old tile, not at its destination", failures)
		_expect_reservations(world, failures)


static func _test_surface_step_timing_and_interpolation(failures: Array[String]) -> void:
	for surface: String in ["grass", "trail", "stone_road"]:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.ONE]:
			var world := World.new(Vector2i(6, 6))
			var start := Vector2i.ONE
			var first: Vector2i = start + direction
			var goal: Vector2i = first + direction
			for cell: Vector2i in [first, goal]:
				if surface == "trail":
					world.grid.add_dirt_trail(cell)
				elif surface == "stone_road":
					world.grid.add_road(cell)
			if surface == "trail":
				world.grid.set_trail_link(start, first, world.grid.carrier_passes_to_form_trail(), 0, true)
			var cardinal_duration: int = {"grass": 6, "trail": 4, "stone_road": 2}[surface]
			var duration: int = Grid.diagonal_duration_ticks(cardinal_duration) if direction == Vector2i.ONE else cardinal_duration
			var id: int = world.spawn_worker(start, "builder")
			var worker: Dictionary = world.workers[id]
			world._move_worker_to(worker, goal)
			world.step_tick()
			_expect(worker["position"] == first and int(worker["visual_duration_ticks"]) == duration
				and int(worker["move_cooldown"]) == duration - 1,
				"Real %s movement uses %d ticks for direction %s" % [surface, duration, direction], failures)
			var previous_distance: float = -1.0
			for elapsed: int in range(duration):
				if elapsed > 0:
					world.step_tick()
				_expect(worker["position"] == first and int(worker["visual_progress_ticks"]) == elapsed,
					"The next logical step waits for the full previous surface/distance duration", failures)
				for frame_fraction: float in [0.0, 0.5, 0.99]:
					var alpha: float = View.worker_lerp_alpha(worker, frame_fraction)
					var visual: Vector2 = Vector2(worker["previous_position"]).lerp(Vector2(worker["position"]), alpha)
					var distance: float = visual.distance_to(Vector2(start))
					_expect(distance >= previous_distance and alpha < 1.0,
						"Interpolated cardinal and diagonal movement never rewinds or reaches the next tile early", failures)
					previous_distance = distance
			world.step_tick()
			_expect(worker["position"] == goal and int(worker["visual_progress_ticks"]) == 0,
				"The second step starts exactly at the completed first step's tick boundary", failures)
			var boundary_visual: Vector2 = Vector2(worker["previous_position"]).lerp(
				Vector2(worker["position"]), View.worker_lerp_alpha(worker, 0.0)
			)
			_expect(boundary_visual.is_equal_approx(Vector2(first))
				and boundary_visual.distance_to(Vector2(start)) >= previous_distance,
				"The tick boundary between diagonal segments has no backward position jump", failures)


static func _test_carrier_diagonal_traffic_is_step_local(failures: Array[String]) -> void:
	var world := World.new(Vector2i(7, 7))
	world.grid.configure_movement({"trail": {"carrier_passes_to_form": 2}})
	var start := Vector2i.ONE
	var goal := Vector2i(5, 5)
	var id: int = world.spawn_worker(start, "carrier")
	var worker: Dictionary = world.workers[id]
	world._move_worker_to(worker, goal)
	_expect(world.grid.traffic_wear.is_empty(), "Planning a route never paints traffic in advance", failures)
	var visits: Dictionary = {}
	var previous: Vector2i = start
	for destination: Vector2i in [goal, start]:
		if destination == start:
			world._move_worker_to(worker, destination)
		for _elapsed: int in range(160):
			var path: Array = worker["path"]
			var path_index: int = int(worker["path_index"])
			var planned_duration: int = world.grid.step_duration_ticks(previous, path[path_index]) if path_index < path.size() else 0
			world.step_tick()
			var cell: Vector2i = worker["position"]
			if cell != previous:
				_expect((cell - previous).abs() == Vector2i.ONE,
					"The carrier takes adjacent diagonal steps along the open route", failures)
				visits[cell] = int(visits.get(cell, 0)) + 1
				_expect(worker["previous_position"] == previous and int(worker["visual_progress_ticks"]) == 0,
					"A trail-producing carrier step remains visibly interpolated", failures)
				_expect(int(worker["visual_duration_ticks"]) == planned_duration,
					"The pass that first forms mud still takes the ground's pre-step travel duration", failures)
				previous = cell
			_expect(world.grid.traffic_wear == visits,
				"Only cells actually entered by the carrier accumulate exactly one pass per step", failures)
			if worker["state"] == "idle" and cell == destination:
				break
		_expect(worker["position"] == destination and worker["state"] == "idle",
			"The carrier completes each diagonal journey", failures)
	for coordinate: int in range(2, 5):
		_expect(world.grid.overlay_at(Vector2i(coordinate, coordinate)) == "trail",
			"Two actual diagonal passes form mud on each shared route cell", failures)
	_expect(world.grid.overlay_at(goal).is_empty() and world.grid.overlay_at(start).is_empty()
		and world.grid.traffic_wear_at(Vector2i(2, 1)) == 0,
		"Single-pass endpoints and untouched diagonal flank cells are not painted into a trail", failures)


static func _test_cached_diagonal_rechecks_static_corner(failures: Array[String]) -> void:
	var world := World.new(Vector2i(5, 5))
	var start := Vector2i.ONE
	var goal := Vector2i(2, 2)
	var id: int = world.spawn_worker(start, "builder")
	var worker: Dictionary = world.workers[id]
	world._move_worker_to(worker, goal)
	world.grid.block(Vector2i(2, 1), 99)
	world.step_tick()
	_expect(worker["position"] == start, "A newly blocked flank invalidates the cached diagonal before committing it", failures)
	var previous: Vector2i = start
	for _elapsed: int in range(60):
		world.step_tick()
		var cell: Vector2i = worker["position"]
		if cell != previous:
			_expect(world.grid.can_traverse(previous, cell), "Replanned real movement never clips the new corner", failures)
			previous = cell
		if cell == goal:
			break
	_expect(worker["position"] == goal, "The worker reaches its target by the clear side of the new obstacle", failures)


static func _test_cached_diagonal_rechecks_occupied_flank(failures: Array[String]) -> void:
	var world := World.new(Vector2i(5, 5))
	var start := Vector2i.ONE
	var goal := Vector2i(2, 2)
	var id: int = world.spawn_worker(start, "builder")
	var worker: Dictionary = world.workers[id]
	world._move_worker_to(worker, goal)
	var flank := Vector2i(2, 1)
	var blocker: int = world.spawn_worker(flank, "builder")
	world.workers[blocker]["state"] = "working"
	world.workers[blocker]["action"] = "test_blocker"
	world.workers[blocker]["work_remaining"] = 1000
	world.step_tick()
	_expect(worker["position"] == start, "A busy unit that enters a cached diagonal flank blocks the next step", failures)
	var previous: Vector2i = start
	for _elapsed: int in range(90):
		world.step_tick()
		var cell: Vector2i = worker["position"]
		if cell != previous:
			_expect(world.grid.can_step(previous, cell, {flank: blocker}),
				"Replanned movement cannot squeeze past a busy worker's corner", failures)
			previous = cell
		_expect_reservations(world, failures)
		if cell == goal:
			break
	_expect(worker["position"] == goal and world.workers[blocker]["position"] == flank,
		"The requester finds the open side without displacing a working unit", failures)


static func _diagonal_swap_world(reverse_ids: bool = false, grass_source: bool = false) -> Dictionary:
	var world := World.new(Vector2i(5, 5))
	var cells: Array[Vector2i] = [Vector2i.ONE, Vector2i(2, 2)]
	if not grass_source:
		world.grid.add_dirt_trail(cells[0])
	world.grid.add_road(cells[1])
	if not grass_source:
		world.grid.set_trail_link(cells[0], cells[1], world.grid.carrier_passes_to_form_trail(), 0, true)
	else:
		# The entering carrier will form both the grass endpoint and its route.
		var threshold: int = world.grid.carrier_passes_to_form_trail()
		world.grid.set_traffic_wear(cells[0], threshold - 1)
		world.grid.set_trail_link(cells[0], cells[1], threshold - 1, 0, false)
	if reverse_ids:
		cells.reverse()
	var ids: Array[int] = []
	for cell: Vector2i in cells:
		ids.append(world.spawn_worker(cell, "carrier" if grass_source else "builder"))
	for index: int in range(2):
		world._move_worker_to(world.workers[ids[index]], cells[1 - index])
	return {"world": world, "ids": ids, "cells": cells}


static func _test_diagonal_swap_surface_durations(failures: Array[String]) -> void:
	for options: Array in [[false, false], [true, false], [false, true], [true, true]]:
		var grass_source: bool = options[1]
		var fixture: Dictionary = _diagonal_swap_world(options[0], grass_source)
		var world = fixture["world"]
		var ids: Array[int] = fixture["ids"]
		var cells: Array[Vector2i] = fixture["cells"]
		world.step_tick()
		if grass_source:
			_expect(world.grid.overlay_at(Vector2i.ONE) == "trail" \
				and world.grid.trail_connection_active(Vector2i.ONE, Vector2i(2, 2)),
				"The threshold-crossing swap must actually form mud after capturing both movement durations", failures)
		for index: int in range(2):
			var worker: Dictionary = world.workers[ids[index]]
			var duration: int = 3 if cells[1 - index] == Vector2i(2, 2) else (9 if grass_source else 6)
			_expect(worker["position"] == cells[1 - index] and worker["previous_position"] == cells[index]
				and int(worker["move_cooldown"]) == duration - 1 and int(worker["visual_duration_ticks"]) == duration,
				"Diagonal swapping uses each destination's complete stone/mud/grass duration before forming new mud, independently of worker ID order", failures)
		for elapsed: int in range(1, 10):
			world.step_tick()
			for id: int in ids:
				var worker: Dictionary = world.workers[id]
				_expect(int(worker["visual_progress_ticks"]) == mini(elapsed, int(worker["visual_duration_ticks"])),
					"Both diagonal swap participants keep their own uninterrupted visual progress", failures)
			_expect_reservations(world, failures)


static func _test_diagonal_swap_waits_for_both_workers(failures: Array[String]) -> void:
	for waiting_index: int in range(2):
		var fixture: Dictionary = _diagonal_swap_world()
		var world = fixture["world"]
		var ids: Array[int] = fixture["ids"]
		var cells: Array[Vector2i] = fixture["cells"]
		world.workers[ids[waiting_index]]["move_cooldown"] = 1
		world.step_tick()
		_expect(world.workers[ids[0]]["position"] == cells[0] and world.workers[ids[1]]["position"] == cells[1],
			"Consuming either worker's last cooldown tick cannot start a diagonal swap early", failures)
		world.step_tick()
		_expect(world.workers[ids[0]]["position"] == cells[1] and world.workers[ids[1]]["position"] == cells[0],
			"A diagonal swap starts once both workers were ready at the tick's beginning", failures)
		_expect_reservations(world, failures)


static func _test_diagonal_swap_cannot_cut_occupied_flank(failures: Array[String]) -> void:
	var fixture: Dictionary = _diagonal_swap_world()
	var world = fixture["world"]
	var ids: Array[int] = fixture["ids"]
	var cells: Array[Vector2i] = fixture["cells"]
	var blocker: int = world.spawn_worker(Vector2i(2, 1), "builder")
	world.workers[blocker]["state"] = "working"
	world.workers[blocker]["action"] = "test_blocker"
	world.workers[blocker]["work_remaining"] = 1000
	world.step_tick()
	_expect(world.workers[ids[0]]["position"] == cells[0] and world.workers[ids[1]]["position"] == cells[1],
		"Swapping cannot bypass a third worker occupying a diagonal flank", failures)
	_expect_reservations(world, failures)


static func _test_crossing_diagonals_make_progress_without_overlap(failures: Array[String]) -> void:
	for reverse_ids: bool in [false, true]:
		var world := World.new(Vector2i(5, 5))
		var starts: Array[Vector2i] = [Vector2i.ONE, Vector2i(2, 1)]
		var goals: Array[Vector2i] = [Vector2i(2, 2), Vector2i(1, 2)]
		if reverse_ids:
			starts.reverse()
			goals.reverse()
		var ids: Array[int] = []
		for index: int in range(2):
			ids.append(world.spawn_worker(starts[index], "builder"))
			world._move_worker_to(world.workers[ids[index]], goals[index])
		for _elapsed: int in range(160):
			world.step_tick()
			_expect_reservations(world, failures)
			if world.workers[ids[0]]["position"] == goals[0] and world.workers[ids[1]]["position"] == goals[1]:
				break
		_expect(world.workers[ids[0]]["position"] == goals[0] and world.workers[ids[1]]["position"] == goals[1],
			"Two initially crossing diagonal routes detour and both reach their goals without deadlock", failures)
