extends Node

# Read-only CPU profile of the current economy demo. No saves or frame timing.
const MainScene = preload("res://scenes/main.tscn")


func _ready() -> void:
	var main = MainScene.instantiate()
	main.honor_launch_arguments = false
	main.demo_kind = "economy"
	add_child(main)
	main.set_process(false)
	var world = main.world
	var batched: bool = world.has_method("resource_stocks")
	var stock_samples: Array[float] = []
	var single_samples: Array[float] = []
	var hud_samples: Array[float] = []
	for sample: int in range(6):
		var start: int = Time.get_ticks_usec()
		for _iteration: int in range(300):
			for resource: String in world.catalog.resources:
				world.resource_stock(resource)
		var singles: float = float(Time.get_ticks_usec() - start) / 300.0
		start = Time.get_ticks_usec()
		for _iteration: int in range(300):
			if batched:
				world.call("resource_stocks")
			else:
				for resource: String in world.catalog.resources:
					world.resource_stock(resource)
		var stocks: float = float(Time.get_ticks_usec() - start) / 300.0
		start = Time.get_ticks_usec()
		for _iteration: int in range(100):
			main.hud.refresh(world, Vector2i(-1, -1), "", 1.0, 0.1)
		if sample > 0: # Discard cold font/style/property setup.
			single_samples.append(singles)
			stock_samples.append(stocks)
			hud_samples.append(float(Time.get_ticks_usec() - start) / 100.0)
	print("STOCK_HUD_PROFILE ", JSON.stringify({
		"map": "economy", "buildings": world.buildings.size(), "workers": world.workers.size(),
		"resources": world.catalog.resources.size(), "batched": batched,
		"single_queries_us": _median(single_samples), "stock_summary_us": _median(stock_samples),
		"hud_refresh_us": _median(hud_samples), "samples": hud_samples.size(),
	}))
	main.free()
	get_tree().quit()


func _median(values: Array[float]) -> float:
	values.sort()
	return values[values.size() / 2]
