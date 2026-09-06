extends RefCounted

const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const World = preload("res://scripts/simulation/simulation_world.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const TEST_COUNT: int = 11


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [
		_test_unique_ownership_round_trip,
		_test_unassigned_does_not_steal_later_owner,
		_test_legacy_duplicate_claims_preserve_workers_and_cargo,
		_test_legacy_shared_roles_and_unfinished_homes,
		_test_current_invalid_claims_are_atomic,
		_test_legacy_corrupt_references_still_fail,
		_test_active_batch_keeps_its_owner,
		_test_unassigned_cargo_round_trip,
		_test_owned_cargo_matches_the_actual_workplace,
		_test_v9_cost_contract_is_not_migrated_again,
		_test_inspector_shows_one_person_slot,
	]:
		test.call(failures)
	return failures


static func _fixture() -> Dictionary:
	var world := LegacyFixture.create(Vector2i(18, 12))
	var ids: Dictionary = {"world": world}
	for entry: Array in [
		["store", "warehouse", Vector2i(2, 2)],
		["hut", "lumber_hut", Vector2i(6, 2)],
		["other_hut", "lumber_hut", Vector2i(10, 2)],
		["farm", "farm", Vector2i(6, 6)],
		["mill", "mill", Vector2i(10, 6)],
		["tower", "watchtower", Vector2i(14, 2)],
		["barracks", "barracks", Vector2i(14, 6)],
	]:
		ids[entry[0]] = world.place_building(String(entry[1]), entry[2])
	world.buildings[ids["store"]]["storage"]["plank"] = 15
	world.buildings[ids["hut"]]["outputs"]["log"] = 3
	return ids


static func _json(world: Variant) -> Dictionary:
	return JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary


static func _saved_worker(data: Dictionary, id: int) -> Dictionary:
	for worker: Dictionary in data["workers"]:
		if int(worker["id"]) == id:
			return worker
	return {}


static func _saved_building(data: Dictionary, id: int) -> Dictionary:
	for building: Dictionary in data["buildings"]:
		if int(building["id"]) == id:
			return building
	return {}


static func _totals(world: Variant) -> Dictionary:
	var totals: Dictionary = {}
	for resource: String in world.catalog.resources:
		totals[resource] = int(world.resource_stock(resource)["total"])
		for building: Dictionary in world.buildings.values():
			totals[resource] += int(building["construction_delivered"].get(resource, 0))
	return totals


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _until(world: Variant, condition: Callable, ticks: int = 1000) -> bool:
	for _tick: int in range(ticks):
		if condition.call():
			return true
		world.step_tick()
	return condition.call()


static func _test_unique_ownership_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var index: int = 0
	for entry: Array in [
		["lumberjack", fixture["hut"]], ["lumberjack", fixture["other_hut"]],
		["farmer", fixture["farm"]], ["baker", fixture["mill"]],
		["recruit", fixture["tower"]], ["carrier", 0], ["builder", 0], ["gardener", 0],
	]:
		_check(world.spawn_worker(Vector2i(index + 1, 9), String(entry[0]), int(entry[1]), false) != 0,
			"Round-trip fixture must accept each unique compatible owner", failures)
		index += 1
	var data: Dictionary = _json(world)
	var restored := LegacyFixture.create()
	_check(int(data["version"]) == World.SAVE_VERSION and int(data["version"]) >= 10,
		"The current save schema must retain exclusive V10 workplace validation", failures)
	_check(restored.from_data(data) and restored.to_data() == world.to_data(),
		"All specialists and shared professions must retain exact ownership through JSON save/load", failures)


static func _test_unassigned_does_not_steal_later_owner(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var early: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", 0, false)
	var owner: int = world.spawn_worker(Vector2i(4, 9), "lumberjack", fixture["hut"], false)
	var data: Dictionary = _json(world)
	data["workers"].reverse()
	var restored := LegacyFixture.create()
	if not restored.from_data(data):
		failures.append("A later explicit owner must load even when an earlier citizen has no workplace")
		return
	_check(int(restored.workers[early]["home_id"]) == 0
		and int(restored.workplace_worker(fixture["hut"]).get("id", 0)) == owner
		and restored.to_data() == world.to_data(),
		"Loading must restore explicit ownership independently of worker array order and free buildings", failures)


static func _test_legacy_duplicate_claims_preserve_workers_and_cargo(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var first: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", fixture["hut"], false)
	var second: int = world.spawn_worker(Vector2i(4, 9), "lumberjack", 0, false)
	world.workers[first]["carrying"] = "log"
	world.workers[second]["carrying"] = "log"
	var data: Dictionary = _json(world)
	data["version"] = 9
	_saved_worker(data, second)["home_id"] = fixture["hut"]
	data["workers"].reverse()
	var restored := LegacyFixture.create()
	if not restored.from_data(data):
		failures.append("Legacy shared hut owners must migrate without rejecting the entire old save")
		return
	_check(restored.workers.size() == 2 and int(restored.workers[first]["home_id"]) == int(fixture["hut"])
		and int(restored.workers[second]["home_id"]) == 0,
		"Legacy duplicates must retain the lowest-ID compatible owner and leave surplus citizens unassigned", failures)
	_check(String(restored.workers[first]["carrying"]) == "log"
		and String(restored.workers[second]["carrying"]) == "log" and _totals(restored) == _totals(world),
		"Legacy ownership migration must neither destroy citizens' cargo nor create stock", failures)
	var again := LegacyFixture.create()
	_check(again.from_data(_json(restored)) and again.to_data() == restored.to_data(),
		"Migrated ownership and surplus cargo must remain valid when resaved as V10", failures)


static func _test_legacy_shared_roles_and_unfinished_homes(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var carrier: int = world.spawn_worker(Vector2i(2, 9), "carrier", 0, false)
	var recruit: int = world.spawn_worker(Vector2i(4, 9), "recruit", 0, false)
	var lumberjack: int = world.spawn_worker(Vector2i(6, 9), "lumberjack", fixture["other_hut"], false)
	world.workers[carrier]["carrying"] = "plank"
	var data: Dictionary = _json(world)
	data["version"] = 9
	_saved_worker(data, carrier)["home_id"] = fixture["hut"]
	_saved_worker(data, recruit)["home_id"] = fixture["barracks"]
	_saved_building(data, fixture["other_hut"])["construction_remaining"] = 120
	var restored := LegacyFixture.create()
	if not restored.from_data(data):
		failures.append("Old carrier-to-hut, communal barracks and unfinished home references must migrate")
		return
	for id: int in [carrier, recruit, lumberjack]:
		_check(int(restored.workers[id]["home_id"]) == 0,
			"Legacy temporary or invalid exclusive claims must be released, citizen " + str(id), failures)
	_check(restored.workers.size() == 3 and String(restored.workers[carrier]["carrying"]) == "plank"
		and _totals(restored) == _totals(world), "Legacy temporary claims must preserve workers and material totals", failures)


static func _test_current_invalid_claims_are_atomic(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var owner: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", fixture["hut"], false)
	var spare: int = world.spawn_worker(Vector2i(4, 9), "lumberjack", 0, false)
	var baseline: Dictionary = _json(world)
	var cases: Array[Dictionary] = [
		{"name": "duplicate owner", "mutate": func(data: Dictionary): _saved_worker(data, spare)["home_id"] = fixture["hut"]},
		{"name": "wrong profession", "mutate": func(data: Dictionary): _saved_worker(data, owner)["home_id"] = fixture["farm"]},
		{"name": "unfinished home", "mutate": func(data: Dictionary): _saved_building(data, fixture["hut"])["construction_remaining"] = 120},
		{"name": "carrier claiming a hut", "mutate": func(data: Dictionary): _saved_worker(data, owner)["type"] = "carrier"},
		{"name": "gardener claiming a hut", "mutate": func(data: Dictionary): _saved_worker(data, owner)["type"] = "gardener"},
		{"name": "builder claiming a hut", "mutate": func(data: Dictionary): _saved_worker(data, owner)["type"] = "builder"},
		{"name": "communal barracks claim", "mutate": func(data: Dictionary):
			_saved_worker(data, owner)["type"] = "recruit"
			_saved_worker(data, owner)["home_id"] = fixture["barracks"]},
		{"name": "missing home", "mutate": func(data: Dictionary): _saved_worker(data, owner)["home_id"] = 999},
	]
	var target := LegacyFixture.create()
	target.setup_demo()
	target.step_tick()
	var unchanged: Dictionary = target.to_data()
	var grid: Variant = target.grid
	var workers: Dictionary = target.workers.duplicate(true)
	for entry: Dictionary in cases:
		var invalid: Dictionary = baseline.duplicate(true)
		(entry["mutate"] as Callable).call(invalid)
		_check(not target.from_data(invalid) and target.to_data() == unchanged
			and target.grid == grid and target.workers == workers,
			"Current invalid ownership must be rejected without live-world mutation: " + String(entry["name"]), failures)


static func _test_legacy_corrupt_references_still_fail(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var owner: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", fixture["hut"], false)
	var baseline: Dictionary = _json(world)
	var restored := LegacyFixture.create()
	for home: int in [999, fixture["farm"]]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid["version"] = 9
		_saved_worker(invalid, owner)["home_id"] = home
		_check(not restored.from_data(invalid),
			"Legacy migration must not conceal unknown or historically incompatible home references", failures)


static func _test_active_batch_keeps_its_owner(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var mill: int = fixture["mill"]
	var baker: int = world.spawn_worker(world.buildings[mill]["entrance"], "baker", mill, false)
	world.buildings[mill]["inputs"]["grain"] = 1
	if not _until(world, func() -> bool: return int(world.buildings[mill]["process_remaining"]) > 0):
		failures.append("Owned mill fixture must begin its real production batch")
		return
	var restored := LegacyFixture.create()
	if not restored.from_data(_json(world)):
		failures.append("An in-progress production batch must load with its exclusive owner")
		return
	_check(int(restored.workplace_worker(mill).get("id", 0)) == baker
		and restored.to_data() == world.to_data(), "A consumed batch must retain owner, consumed input and remaining timer", failures)
	_check(_until(restored, func() -> bool: return int(restored.buildings[mill]["outputs"]["flour"]) == 1),
		"The same saved baker must finish the already-consumed grain batch", failures)
	_check(int(restored.buildings[mill]["inputs"]["grain"]) == 0,
		"Restoring a worker must not refund or consume production ingredients twice", failures)


static func _test_unassigned_cargo_round_trip(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var worker: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", 0, false)
	world.workers[worker]["carrying"] = "log"
	var restored := LegacyFixture.create()
	_check(restored.from_data(_json(world)) and restored.to_data() == world.to_data()
		and int(restored.workers[worker]["home_id"]) == 0,
		"Current unassigned cargo must not trigger a hidden workplace assignment during snapshot loading", failures)


static func _test_v9_cost_contract_is_not_migrated_again(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	world.economy_enabled = true
	var school: int = world.place_building("school", Vector2i(2, 6))
	world.buildings[school]["construction_delivered"] = {"plank": 6, "stone": 5}
	var data: Dictionary = _json(world)
	data["version"] = 9
	var restored := LegacyFixture.create()
	_check(restored.from_data(data) and int(restored.buildings[school]["construction_cost_revision"]) == 2
		and restored.construction_cost(restored.buildings[school]) == world.construction_cost(world.buildings[school])
		and _totals(restored) == _totals(world),
		"V9 to V10 workplace migration must keep existing explicit construction cost revisions and paid materials", failures)


static func _test_owned_cargo_matches_the_actual_workplace(failures: Array[String]) -> void:
	for entry: Array in [
		["farmer", "vineyard", "farm", "grain"],
		["miner", "coal_mine", "gold_mine", "gold_ore"],
	]:
		var world := LegacyFixture.create(Vector2i(18, 12))
		if entry[0] == "miner":
			world.add_deposit(Vector2i(5, 5), "coal", 5)
			world.grid.set_base_terrain(Vector2i(12, 5), "rock")
			world.add_deposit(Vector2i(12, 5), "gold_ore", 5)
		var wrong_home: int = world.place_building(String(entry[1]), Vector2i(4, 3))
		var matching_home: int = world.place_building(String(entry[2]), Vector2i(11, 3))
		var worker: int = world.spawn_worker(Vector2i(2, 8), String(entry[0]), wrong_home, false)
		if wrong_home == 0 or matching_home == 0 or worker == 0:
			failures.append("Mixed workplace cargo fixture must provide both real buildings for " + String(entry[0]))
			continue
		world.workers[worker]["carrying"] = String(entry[3])
		var data: Dictionary = _json(world)
		var target := LegacyFixture.create()
		target.setup_demo()
		var unchanged: Dictionary = target.to_data()
		var workers: Dictionary = target.workers.duplicate(true)
		_check(not target.from_data(data) and target.to_data() == unchanged and target.workers == workers,
			"V10 must reject profession-valid cargo that the actual owned workplace cannot receive: " + String(entry[0]), failures)
		var valid: Dictionary = data.duplicate(true)
		_saved_worker(valid, worker)["home_id"] = matching_home
		_check(target.from_data(valid) and int(target.workers[worker]["home_id"]) == matching_home
			and String(target.workers[worker]["carrying"]) == String(entry[3]),
			"V10 must still accept that cargo with its matching owned workplace: " + String(entry[0]), failures)
		data["version"] = 9
		var restored := LegacyFixture.create()
		if not restored.from_data(data):
			failures.append("V9 must migrate a historically valid multi-building cargo mismatch: " + String(entry[0]))
			continue
		_check(restored.workers.size() == 1 and int(restored.workers[worker]["home_id"]) == 0
			and String(restored.workers[worker]["carrying"]) == String(entry[3]) and _totals(restored) == _totals(world),
			"Legacy cargo mismatch must release only ownership, preserving the citizen and every material: " + String(entry[0]), failures)
		var again := LegacyFixture.create()
		_check(again.from_data(_json(restored)) and again.to_data() == restored.to_data(),
			"Migrated unmatched cargo must survive another V10 save/load before reassignment", failures)
		_check(restored.ensure_workplace(restored.workers[worker]) == matching_home,
			"A migrated citizen must claim a free workplace matching the carried resource: " + String(entry[0]), failures)
		_check(_until(restored, func() -> bool: return String(restored.workers[worker]["carrying"]).is_empty())
			and int(restored.buildings[matching_home]["outputs"][entry[3]]) == 1,
			"The preserved cargo must subsequently reach the matching workplace: " + String(entry[0]), failures)


static func _test_inspector_shows_one_person_slot(failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: Variant = fixture["world"]
	var hut: int = fixture["hut"]
	var hud := Hud.new()
	hud._catalog = world.catalog
	var vacant: String = hud._selected_production_text(world, world.buildings[hut]["position"])
	_check(vacant.contains("Lumberjack") and vacant.contains("0/1") and vacant.contains("waiting for worker"),
		"Empty hut inspector must clearly show its single vacant lumberjack slot", failures)
	var owner: int = world.spawn_worker(Vector2i(2, 9), "lumberjack", hut, false)
	var occupied: String = hud._selected_production_text(world, world.buildings[hut]["position"])
	_check(occupied.contains("Lumberjack #%d" % owner) and occupied.contains("1/1") and not occupied.contains("0/1"),
		"Staffed hut inspector must identify its persistent owner and one occupied slot", failures)
	var barracks: String = hud._selected_production_text(world, world.buildings[fixture["barracks"]]["position"])
	_check(not barracks.contains("0/1") and not barracks.contains("1/1"),
		"Communal barracks must not advertise a one-person production workplace", failures)
	hud.free()
