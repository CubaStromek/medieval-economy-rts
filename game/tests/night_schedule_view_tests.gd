extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 5


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	_test_actual_sleepers_and_cargo(failures)
	_test_sleeping_building_identity(failures)
	_test_unit_schedule_details(failures)
	_test_military_stays_active(failures)
	await _test_compact_status_bar(host, failures)
	return failures


static func _world() -> World:
	var world := World.new(Vector2i(16, 10))
	world.tick = 3750 # 20:00 on the first day.
	return world


static func _hud(world: World) -> Hud:
	var hud := Hud.new()
	hud.configure(world.catalog)
	return hud


static func _put_to_sleep(world: World, worker_id: int, building_id: int, failures: Array[String]) -> void:
	var worker: Dictionary = world.workers[worker_id]
	worker["sleep_home_id"] = building_id
	_expect(world._enter_worker_building(worker, building_id),
		"The sleeping HUD fixture must enter the actual completed building", failures)
	worker["state"] = "sleeping"


static func _test_actual_sleepers_and_cargo(failures: Array[String]) -> void:
	var world: World = _world()
	var store: int = world.place_building("warehouse", Vector2i(3, 3))
	var door: Vector2i = world.buildings[store]["entrance"]
	var sleeper: int = world.spawn_worker(door, "carrier")
	world.workers[sleeper]["carrying"] = "log"
	_put_to_sleep(world, sleeper, store, failures)
	var awake: int = world.spawn_worker(door, "builder")
	world.workers[awake]["sleep_home_id"] = store
	var hud: Hud = _hud(world)
	var stock_before: Dictionary = world.resource_stock("log")
	var workers_before: Dictionary = world.workers.duplicate(true)
	hud.refresh(world, Vector2i(3, 3), "", 0.0, World.TICK_SECONDS)
	_expect(hud.production_detail_label.text.contains("Inside: 1 citizen")
		and hud.production_detail_label.text.contains("Sleeping: 1 • until 05:00"),
		"The warehouse must count its real sleeper without counting the awake person at its door", failures)
	_expect(hud._citizens_label.text.contains("2 citizens") and hud._citizens_label.text.contains("1 sleeping")
		and hud._worker_summary_text(world).contains("Sleeping 1"),
		"Sleeping citizens must remain in the population, with sleep counted separately", failures)
	_expect(world.resource_stock("log") == stock_before and int(stock_before["carried"]) == 1
		and (hud.resource_amount_labels["log"] as Label).text == str(stock_before["total"])
		and world.workers == workers_before,
		"Refreshing sleeping details must retain carried resources and preserve simulation state", failures)
	hud.free()


static func _test_sleeping_building_identity(failures: Array[String]) -> void:
	var world: World = _world()
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	var store: int = world.place_building("warehouse", Vector2i(10, 3))
	var lumberjack: int = world.spawn_worker(world.buildings[hut]["entrance"], "lumberjack", hut)
	var carrier: int = world.spawn_worker(world.buildings[store]["entrance"], "carrier")
	_put_to_sleep(world, lumberjack, hut, failures)
	_put_to_sleep(world, carrier, store, failures)
	var hud: Hud = _hud(world)
	hud.refresh(world, Vector2i(3, 3), "", 0.0, World.TICK_SECONDS)
	_expect(hud.production_detail_label.text.contains("Worker: Lumberjack #%d • 1/1 • inside" % lumberjack)
		and hud.production_detail_label.text.contains("Sleeping: 1 • until 05:00")
		and not hud.production_detail_label.text.contains("Sleeping: 2"),
		"A specialist's hut must show its own sleeping employee and preserve the workplace assignment", failures)
	hud.refresh(world, Vector2i(10, 3), "", 0.0, World.TICK_SECONDS)
	_expect(hud.production_detail_label.text.contains("Inside: 1 citizen")
		and hud.production_detail_label.text.contains("Sleeping: 1 • until 05:00")
		and hud._citizens_label.text.contains("2 sleeping"),
		"Warehouse sleep occupancy must be local while the settlement summary totals all sleeping places", failures)
	hud.free()


static func _test_unit_schedule_details(failures: Array[String]) -> void:
	var world: World = _world()
	var carrier: int = world.spawn_worker(Vector2i(8, 6), "carrier")
	var hud: Hud = _hud(world)
	hud.refresh(world, Vector2i(-1, -1), "", 0.0, World.TICK_SECONDS, carrier)
	_expect(hud.production_detail_label.text.contains("No sleeping place available"),
		"A selected civilian without accommodation must explain why it cannot go to sleep", failures)
	var store: int = world.place_building("warehouse", Vector2i(3, 3))
	var worker: Dictionary = world.workers[carrier]
	worker["sleep_home_id"] = store
	worker["action"] = "go_sleep"
	hud.refresh(world, Vector2i(-1, -1), "", 0.0, World.TICK_SECONDS, carrier)
	_expect(hud.production_detail_label.text.contains("Going to sleep")
		and not hud._citizens_label.text.contains("sleeping"),
		"An outdoor civilian walking home must show its intent without being counted as asleep", failures)
	var sleeper: int = world.spawn_worker(world.buildings[store]["entrance"], "builder")
	worker = world.workers[sleeper]
	worker["carrying"] = "log"
	_put_to_sleep(world, sleeper, store, failures)
	hud.refresh(world, Vector2i(-1, -1), "", 0.0, World.TICK_SECONDS, sleeper)
	_expect(hud.production_detail_label.text.contains("Sleeping until 05:00")
		and hud.production_detail_label.text.contains("Inn")
		and hud.building_inventory_label.text.contains("Carrying:")
		and hud._satiety_panel.visible,
		"Selected sleepers must show their schedule alongside the existing cargo and food details", failures)
	worker["state"] = "idle"
	worker["action"] = ""
	world.tick = 6000 # 05:00 on the next day.
	hud.refresh(world, Vector2i(-1, -1), "", 0.0, World.TICK_SECONDS, sleeper)
	_expect(not hud.production_detail_label.text.contains("sleep") and not hud._citizens_label.text.contains("sleeping"),
		"The next morning's refreshed details must drop the night schedule status", failures)
	hud.free()


static func _test_military_stays_active(failures: Array[String]) -> void:
	var world: World = _world()
	var hud: Hud = _hud(world)
	for role: String in ["militia", "recruit"]:
		var worker: int = world.spawn_worker(Vector2i(8, 5) if role == "militia" else Vector2i(9, 5), role)
		hud.refresh(world, Vector2i(-1, -1), "", 0.0, World.TICK_SECONDS, worker)
		_expect(world.worker_schedule_status(world.workers[worker]).is_empty()
			and not hud.production_detail_label.text.contains("sleep")
			and not hud._citizens_label.text.contains("sleeping"),
			"Nighttime HUD must keep the active %s out of the civilian sleep schedule" % role, failures)
		if role == "militia":
			_expect(hud._soldier_food_panel.visible and hud.production_detail_label.text.contains("Request food"),
				"Nighttime soldier details must preserve the existing manual food supply controls", failures)
	hud.free()


static func _test_compact_status_bar(host: Node, failures: Array[String]) -> void:
	var world: World = _world()
	var store: int = world.place_building("warehouse", Vector2i(3, 3))
	var sleeper: int = world.spawn_worker(world.buildings[store]["entrance"], "builder")
	_put_to_sleep(world, sleeper, store, failures)
	world.workers[sleeper]["hunger"] = 100
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 720)
	host.add_child(viewport)
	var hud: Hud = _hud(world)
	viewport.add_child(hud)
	hud.refresh(world, Vector2i(-1, -1), "", 0.0, World.TICK_SECONDS)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var status: Control = hud.find_child("StatusBar", true, false) as Control
	var window_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	_expect(status != null and window_rect.encloses(status.get_global_rect())
		and status.get_global_rect().encloses(hud._citizens_label.get_global_rect()),
		"The status bar must fit a 900-pixel window with simultaneous hunger and sleep counts", failures)
	_expect(hud._citizens_label.text.contains("sleeping")
		and hud._citizens_label.tooltip_text.contains("Sleeping 1")
		and hud._citizens_label.tooltip_text.contains("Hungry 1")
		and hud._citizens_label.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"A shortened settlement label must retain both complete counts in its reachable hover tooltip", failures)
	_expect(hud._clock_label.tooltip_text.contains("Civilian work: 05:00–20:00")
		and hud._clock_label.tooltip_text.contains("Sleep: 20:00–05:00")
		and hud._clock_label.tooltip_text.contains("carriers and builders sleep in a warehouse")
		and hud._clock_label.tooltip_text.contains("Full day/night cycle: 10 minutes at 1×."),
		"The clock tooltip must explain civilian hours and temporary warehouse accommodation while retaining the ten-minute cycle", failures)
	viewport.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
