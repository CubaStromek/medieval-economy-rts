extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Legacy = preload("res://tests/legacy_world_fixture.gd")
const Thoughts = preload("res://scripts/simulation/unit_thoughts.gd")
const TEST_COUNT: int = 10


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_real_tree_walk_and_work, _test_actual_pickup_and_delivery,
		_test_extraction_field_and_planting, _test_production_and_construction,
		_test_actual_military_delivery, _test_actual_sleep_and_meal,
		_test_pause_respects_real_needs_and_cargo, _test_yield_blocked_and_indoor_exit,
		_test_idle_reasons_without_invented_plans, _test_visibility_and_read_only]:
		test.call(failures)
	return failures


static func _test_real_tree_walk_and_work(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	world.add_tree(Vector2i(10, 7), 3)
	var id: int = world.spawn_worker(Vector2i(5, 7), "lumberjack", hut)
	world.step_tick()
	var worker: Dictionary = world.workers[id]
	_check(worker["state"] == "moving" and worker["action"] == "harvest", "Thought fixture must genuinely select its tree and walk there", failures)
	var thought: Dictionary = Thoughts.describe(world, worker)
	_check(thought["current"].contains("Jdu ke stromu") and thought["next"].contains("začnu kácet"), "A selected harvest route must distinguish walking from later chopping", failures)
	if not _until(world, func() -> bool: return worker["state"] == "working"):
		failures.append("Lumberjack must reach actual work for thought verification")
		return
	thought = Thoughts.describe(world, worker)
	_check(thought["current"] == "Kácím strom." and thought["next"].contains("do dřevorubecké chatrče"), "Real chopping must explain its known own-hut follow-up", failures)
	world.trees.erase(int(worker["source_id"]))
	_check(Thoughts.describe(world, worker)["current"].contains("už není dostupný"), "A removed target must not still be described as an existing tree", failures)


static func _test_actual_pickup_and_delivery(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	world.place_building("sawmill", Vector2i(14, 3))
	world.buildings[store]["storage"]["log"] = 1
	var id: int = world.spawn_worker(Vector2i(7, 8), "carrier")
	world.economy_enabled = true
	world.step_tick()
	var worker: Dictionary = world.workers[id]
	_check(worker["action"] == "pickup_log" and int(worker["destination_id"]) == 0, "Pickup fixture must reserve stock before choosing its actual delivery destination", failures)
	var thought: Dictionary = Thoughts.describe(world, worker)
	_check(thought["current"].contains("kládu ze skladu") and thought["next"].contains("vyberu dostupné místo") and not thought["next"].contains("pily"), "A pickup must not invent the still-unselected delivery destination", failures)
	if not _until(world, func() -> bool: return worker["action"] == "deliver_log"):
		failures.append("Carrier must actually collect a log and select its destination")
		return
	thought = Thoughts.describe(world, worker)
	_check(thought["current"] == "Nesu kládu do pily." and thought["next"].contains("podívám"), "A committed log delivery must name the actual destination in Czech", failures)


static func _test_extraction_field_and_planting(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(24, 18))
	world.grid.set_base_terrain(Vector2i(6, 5), "water")
	var deposit: int = world.add_deposit(Vector2i(6, 5), "fish", 20)
	var hut: int = world.place_building("fisher_hut", Vector2i(5, 3))
	var fisher: int = world.spawn_worker(Vector2i(4, 6), "fisherman", hut)
	if not _until(world, func() -> bool: return world.workers[fisher]["state"] == "working"):
		failures.append("Fisher thought fixture must begin actual extraction")
		return
	var thought: Dictionary = Thoughts.describe(world, world.workers[fisher])
	_check(deposit != 0 and thought["current"] == "Chytám ryby." and thought["next"].contains("rybářské chatrče"), "Fishing must name its actual resource and permanent return home", failures)
	var farm: int = world.place_building("farm", Vector2i(15, 3))
	var field: int = world.place_field(Vector2i(16, 6))
	var farmer: int = world.spawn_worker(Vector2i(14, 6), "farmer", farm)
	if not _until(world, func() -> bool: return world.workers[farmer]["state"] == "working"):
		failures.append("Farmer thought fixture must begin actual field work")
		return
	_check(field != 0 and Thoughts.describe(world, world.workers[farmer])["current"] == "Seji obilí.", "Actual field sowing must be described in first person", failures)
	var forester: int = world.place_building("forester_hut", Vector2i(3, 12))
	var gardener: int = world.spawn_worker(Vector2i(4, 11), "gardener", forester)
	if not _until(world, func() -> bool: return world.workers[gardener]["state"] == "working"):
		failures.append("Gardener thought fixture must begin actual planting")
		return
	_check(Thoughts.describe(world, world.workers[gardener])["current"] == "Sázím nový stromek.", "A real planting reservation must have a planting thought", failures)


static func _test_production_and_construction(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var saw: int = world.place_building("sawmill", Vector2i(4, 3))
	world.buildings[saw]["inputs"]["log"] = 2
	var carpenter: int = world.spawn_worker(Vector2i(5, 7), "carpenter", saw)
	world.economy_enabled = true
	if not _until(world, func() -> bool: return world.workers[carpenter]["state"] == "working"):
		failures.append("Thought fixture must begin actual indoor production")
		return
	_check(Thoughts.describe(world, world.workers[carpenter])["current"].contains("Pracuji v pile"), "An indoor operator must retain a truthful production description", failures)
	var site: int = world.place_building("lumber_hut", Vector2i(14, 3))
	world.buildings[site]["construction_delivered"] = world.construction_cost(world.buildings[site]).duplicate()
	var builder: int = world.spawn_worker(Vector2i(13, 7), "builder")
	if not _until(world, func() -> bool: return world.workers[builder]["state"] == "working"):
		failures.append("Thought fixture must begin actual supplied construction")
		return
	_check(Thoughts.describe(world, world.workers[builder])["current"] == "Pracuji na stavbě budovy.", "A builder must describe its construction action", failures)
	world.set_building_enabled(site, false)
	_check(Thoughts.describe(world, world.workers[builder])["current"].contains("pozastavené stavby"), "Stopping a site must not keep pretending its builder is making progress before the next tick", failures)


static func _test_actual_military_delivery(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var store: int = world.place_building("warehouse", Vector2i(2, 3))
	world.buildings[store]["storage"]["bread"] = 1
	var carrier: int = world.spawn_worker(Vector2i(6, 8), "carrier")
	var soldier: int = world.spawn_worker(Vector2i(15, 8), "militia")
	world.workers[soldier]["hunger"] = 100
	world.economy_enabled = true
	if not world.request_soldier_food(soldier):
		failures.append("Military thought fixture must request actual food")
		return
	world.step_tick()
	var thought: Dictionary = Thoughts.describe(world, world.workers[carrier])
	_check(world.workers[carrier]["action"] == "pickup_ration" and thought["current"].contains("chléb ze skladu") and thought["next"].contains("vojákovi č. %d" % soldier), "Ration pickup must use its saved specific recipient rather than invent another task", failures)
	if not _until(world, func() -> bool: return world.workers[carrier]["action"] == "deliver_ration"):
		failures.append("Military carrier must actually collect its ration")
		return
	_check(Thoughts.describe(world, world.workers[carrier])["current"] == "Nesu chléb vojákovi č. %d." % soldier, "Ration delivery must retain actual food and recipient", failures)


static func _test_actual_sleep_and_meal(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	world.place_building("warehouse", Vector2i(3, 3))
	var inn: int = world.place_building("inn", Vector2i(13, 3))
	world.buildings[inn]["inputs"]["bread"] = 2
	var id: int = world.spawn_worker(Vector2i(5, 7), "carrier")
	world.tick = 3750
	world.economy_enabled = true
	world.enable_fog()
	if not _until(world, func() -> bool: return world.is_worker_sleeping(world.workers[id])):
		failures.append("Sleep thoughts require a genuinely sleeping citizen")
		return
	var thought: Dictionary = Thoughts.describe(world, world.workers[id])
	_check(thought["current"] == "Spím ve skladu." and thought["next"].contains("pět ráno"), "An owned hidden indoor sleeper must still be inspectable through its known building", failures)
	world.workers[id]["hunger"] = 100
	if not _until(world, func() -> bool: return int(world.workers[id]["meal_ticks_left"]) > 0):
		failures.append("Hungry sleeper must reach an actual meal for thought verification")
		return
	thought = Thoughts.describe(world, world.workers[id])
	_check(thought["current"] == "Jím chléb v hostinci." and thought["next"].contains("ke spánku"), "Nighttime dining must describe the current paid food and conditional return to sleep", failures)
	world.economy_enabled = false
	var tower: int = world.place_building("watchtower", Vector2i(5, 11))
	world.economy_enabled = true
	var recruit: int = world.spawn_worker(world.buildings[inn]["entrance"], "recruit", tower)
	if recruit == 0:
		failures.append("Nighttime guard meal fixture requires a real assigned recruit")
		return
	world.workers[recruit]["hunger"] = 100
	world.set_worker_enabled(recruit, false)
	if not _until(world, func() -> bool: return int(world.workers[recruit]["meal_ticks_left"]) > 0):
		failures.append("A paused recruit must begin an actual nighttime meal")
		return
	thought = Thoughts.describe(world, world.workers[recruit])
	_check(thought["current"].contains("Jím") and not thought["next"].contains("spán") and thought["next"].contains("obnovení práce"), "A paused recruit's night meal must not invent civilian sleep afterward", failures)
	world.set_worker_enabled(recruit, true)
	thought = Thoughts.describe(world, world.workers[recruit])
	_check(not thought["next"].contains("spán") and thought["next"].contains("strážní věže"), "An active recruit must plan to return to its known tower after eating, even at night", failures)


static func _test_pause_respects_real_needs_and_cargo(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	var saw: int = world.place_building("sawmill", Vector2i(13, 3))
	var inn: int = world.place_building("inn", Vector2i(13, 11))
	var id: int = world.spawn_worker(Vector2i(6, 8), "lumberjack", hut)
	var worker: Dictionary = world.workers[id]
	worker["enabled"] = false
	_check(Thoughts.describe(world, worker)["current"].contains("pozastavenou práci"), "A manually paused idle citizen must explain why it is waiting", failures)
	worker["enabled"] = true
	world.buildings[hut]["enabled"] = false
	_check(Thoughts.describe(world, worker)["current"].contains("pracoviště"), "Disabled workplace must be distinguishable from a personal stop", failures)
	worker["carrying"] = "log"
	worker["destination_id"] = saw
	worker["action"] = "deliver_log"
	worker["state"] = "moving"
	_check(Thoughts.describe(world, worker)["current"] == "Nesu kládu do pily.", "An already carried delivery must take priority over the paused workplace", failures)
	worker["carrying"] = ""
	worker["action"] = "eat"
	worker["destination_id"] = inn
	_check(Thoughts.describe(world, worker)["current"].contains("Jdu se najíst"), "A paused citizen's real food route must not be described as stopped", failures)
	worker["action"] = "go_sleep"
	worker["sleep_home_id"] = hut
	_check(Thoughts.describe(world, worker)["current"].contains("Jdu spát"), "A paused citizen's real night route must retain priority", failures)
	worker["action"] = ""
	worker["state"] = "idle"
	worker["destination_id"] = 0
	world.step_tick()
	_check(worker["action"] == "pause_return" and Thoughts.describe(world, worker)["current"].contains("Vracím se do dřevorubecké chatrče"), "A real paused return route must explain the known home and its purpose", failures)
	var soldier: int = world.spawn_worker(Vector2i(17, 8), "militia")
	world.workers[soldier]["hunger"] = 100
	world.economy_enabled = true
	world.set_worker_enabled(soldier, false)
	var thought: Dictionary = Thoughts.describe(world, world.workers[soldier])
	_check(thought["current"].contains("zásobování") and not thought["next"].contains("hostin") and thought["next"].contains("příděl"), "A hungry paused soldier must ask for physical rations, never plan an inn visit", failures)
	if not world.request_soldier_food(soldier):
		failures.append("Paused soldier thought fixture must place an actual food order")
		return
	world.workers[soldier]["hunger"] = 1000
	thought = Thoughts.describe(world, world.workers[soldier])
	_check(thought["current"].contains("objednané jídlo") and not thought["next"].contains("hostin"), "A paused soldier's existing ration order must remain visible above civilian hungry threshold", failures)
	world.set_worker_enabled(soldier, true)
	_check(Thoughts.describe(world, world.workers[soldier])["current"].contains("objednané jídlo"), "An active soldier must also describe its actual pending food order rather than generic idleness", failures)


static func _test_yield_blocked_and_indoor_exit(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var id: int = world.spawn_worker(Vector2i(5, 8), "carrier")
	var worker: Dictionary = world.workers[id]
	worker["action"] = "yield"
	if not world._move_worker_to(worker, Vector2i(6, 8)):
		failures.append("Yield thought fixture requires a real planned side step")
		return
	_check(Thoughts.describe(world, worker)["current"].contains("Uhýbám"), "A yield action must not look like ordinary work or an idle unit", failures)
	worker["blocked_ticks"] = 3
	_check(Thoughts.describe(world, worker)["current"].contains("zablokovanou cestu"), "An actually blocked moving state must explain its wait", failures)
	var store: int = world.place_building("warehouse", Vector2i(12, 3))
	var visitor: int = world.spawn_worker(world.buildings[store]["entrance"], "carrier", 0, true, store)
	world.spawn_worker(world.buildings[store]["entrance"], "recruit")
	var inside: Dictionary = world.workers[visitor]
	inside["action"] = "leave_building"
	inside["state"] = "moving"
	inside["enabled"] = false
	_check(Thoughts.describe(world, inside)["current"].contains("uvolní dveře"), "A blocked virtual indoor exit must be distinguished from walking outdoors", failures)


static func _test_idle_reasons_without_invented_plans(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(20, 14))
	var id: int = world.spawn_worker(Vector2i(5, 8), "lumberjack", 0, false)
	var worker: Dictionary = world.workers[id]
	_check(Thoughts.describe(world, worker)["current"].contains("nemám vlastní pracoviště"), "An unassigned specialist must not pretend to have a hut or target tree", failures)
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	world.ensure_workplace(worker)
	world.buildings[hut]["outputs"]["log"] = int(world.catalog.building("lumber_hut")["output_capacity"])
	_check(Thoughts.describe(world, worker)["current"].contains("plné zásoby"), "A full home must explain why no additional harvest starts", failures)
	var saw: int = world.place_building("sawmill", Vector2i(13, 3))
	var carpenter: int = world.spawn_worker(Vector2i(13, 7), "carpenter", saw)
	_check(Thoughts.describe(world, world.workers[carpenter])["current"].contains("Čekám na suroviny"), "Idle manufacturing must report missing recipe input without selecting a new job", failures)
	var carrier: int = world.spawn_worker(Vector2i(8, 9), "carrier")
	var thought: Dictionary = Thoughts.describe(world, world.workers[carrier])
	_check(thought["current"].contains("nemám přidělený úkol") and thought["next"].begins_with("Až "), "Idle carriers must express an unselected future task conditionally", failures)


static func _test_visibility_and_read_only(failures: Array[String]) -> void:
	var world = Legacy.create(Vector2i(30, 18))
	var hut: int = world.place_building("lumber_hut", Vector2i(3, 3))
	world.add_tree(Vector2i(8, 7), 3)
	var own: int = world.spawn_worker(Vector2i(5, 8), "lumberjack", hut)
	var enemy: int = world.spawn_worker(Vector2i(24, 8), "carrier", 0, true, 0, 2)
	world.step_tick()
	world.enable_fog()
	var before: Dictionary = {"save": world.to_data(), "workers": world.workers.duplicate(true),
		"tasks": world.task_board.to_data(), "tiles": world.tile_reservations.duplicate(),
		"plants": world.planting_reservations.duplicate(), "visible": world.fog.visible.duplicate(), "revision": world.fog.revision}
	for _read: int in range(50):
		Thoughts.describe(world, world.workers[own])
		Thoughts.describe(world, world.workers[enemy])
	_check(before == {"save": world.to_data(), "workers": world.workers.duplicate(true),
		"tasks": world.task_board.to_data(), "tiles": world.tile_reservations.duplicate(),
		"plants": world.planting_reservations.duplicate(), "visible": world.fog.visible.duplicate(), "revision": world.fog.revision}, "Repeated thought reads must not advance the world, reserve jobs, reroute units or refresh visibility", failures)
	_check(Thoughts.describe(world, world.workers[enemy]).is_empty(), "Foreign thoughts must never be exposed", failures)
	world.fog.enabled = false
	_check(Thoughts.describe(world, world.workers[enemy]).is_empty(), "Disabling map fog must not expose foreign minds", failures)
	world.fog.enabled = true
	world.fog.visible.clear()
	_check(Thoughts.describe(world, world.workers[own]).is_empty(), "An outdoor worker hidden by the current mask must not be inspected", failures)


static func _until(world: Variant, condition: Callable, ticks: int = 1000) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
