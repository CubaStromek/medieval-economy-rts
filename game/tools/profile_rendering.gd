extends SceneTree

# Native, reproducible smoke profile; no saves, gameplay settings or files are
# changed. Run with --audio-driver Dummy; -- --economy-demo selects the big map.
const MainScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	for _frame: int in range(60):
		await process_frame
	var intervals: Array[float] = []
	var calls: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var initial_draws: int = main.terrain_renderer.row_draw_count
	for _frame: int in range(900):
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append(float(now - last) / 1000.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		last = now
	print("RENDER_PROFILE ", JSON.stringify({
		"demo": main.demo_kind, "window": str(root.size), "speed": main.simulation_speed,
		"frame_ms": _stats(intervals), "draw_calls": _stats(calls),
		"terrain_row_redraws": main.terrain_renderer.row_draw_count - initial_draws,
	}))
	main.set_process(false)
	main.terrain_renderer.set_process(false)
	var rebuilds: Array[float] = []
	var base_cells: int = main.terrain_renderer.base_cell_build_count
	var surface_cells: int = main.terrain_renderer.surface_cell_build_count
	for _tick: int in range(240):
		main.world.step_tick()
		var before: int = main.terrain_renderer.geometry_build_count
		var start: int = Time.get_ticks_usec()
		main.terrain_renderer._ensure_cache()
		if main.terrain_renderer.geometry_build_count != before:
			rebuilds.append(float(Time.get_ticks_usec() - start) / 1000.0)
	print("CACHE_PROFILE ", JSON.stringify({"updates_ms": _stats(rebuilds),
		"base_cells_rebuilt": main.terrain_renderer.base_cell_build_count - base_cells,
		"surface_cells_rebuilt": main.terrain_renderer.surface_cell_build_count - surface_cells,
		"ticks": 240}))
	main.free()
	quit()


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count": 0}
	values.sort()
	var total: float = 0.0
	for value: float in values:
		total += value
	return {"count": values.size(), "mean": total / float(values.size()),
		"p95": values[mini(values.size() - 1, int(values.size() * 0.95))], "max": values.back()}
