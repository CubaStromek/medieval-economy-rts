extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const MainView = preload("res://scripts/view/main_view.gd")
const MainScene = preload("res://scenes/main.tscn")
const House = preload("res://scripts/view/lumber_hut_sprite_library.gd")
const Stock = preload("res://scripts/view/lumber_hut_stock_library.gd")
const Terrain = preload("res://scripts/view/terrain_renderer.gd")
const TEST_COUNT: int = 8
const CAPS: Array[Vector2] = [Vector2(397,1005), Vector2(447,991), Vector2(497,977),
	Vector2(422,952), Vector2(472,938), Vector2(447,899)]


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var library := Stock.new()
	_test_seven_actual_assets(library, failures)
	_test_truthful_inventory(library, failures)
	_test_private_inventory(library, failures)
	_test_construction_and_capacity(library, failures)
	_test_real_producer_delivery(library, failures)
	_test_real_pickup_and_saves(library, failures)
	await _test_actual_scene(host, failures) # Paused native states and light/privacy.
	return failures


static func _fixture(footprint_version: int = 2) -> Dictionary:
	var world := World.new(Vector2i(24,18))
	world.default_footprint_version = footprint_version
	world.tick = 1750
	var warehouse: int = world.place_building("warehouse", Vector2i(2,5))
	var id: int = world.place_building("lumber_hut", Vector2i(10,8))
	return {"world":world, "id":id, "warehouse":warehouse}


static func _presentation(library: Stock, world: World, building: Dictionary) -> Dictionary:
	var house := House.new()
	return library.presentation_for(world, building, house.presentation_for(building,
		world.catalog.building("lumber_hut"), Vector2(500,360)))


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_seven_actual_assets(library: Stock, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	var hashes: Dictionary = {}
	var rect := Rect2()
	for amount: int in range(7):
		building["outputs"]["log"] = amount
		var stock: Dictionary = _presentation(library, world, building)
		var texture: Texture2D = stock.get("texture") as Texture2D
		_check(texture != null and int(stock.get("amount",-1)) == amount,
			"Every actual output count 0–6 must select a loaded stock texture", failures)
		if texture == null:
			continue
		var pixels: Image = texture.get_image()
		hashes[hash(pixels.get_data())] = true
		if amount == 0:
			rect = stock["rect"]
		_check(stock["rect"] == rect and String(stock["count_label"]).is_empty(),
			"Every current-capacity state must retain the house rect without a fake numeric overlay", failures)
		var mask: BitMap = stock["hit_mask"]
		_check((mask.get_true_bit_count() == 0) == (amount == 0),
			"Zero logs must be genuinely transparent and positive stocks must have real alpha", failures)
		for slot: int in range(6):
			var cap: Vector2 = CAPS[slot] * (640.0 / 1254.0)
			var pixel: Color = pixels.get_pixelv(Vector2i(cap))
			var painted_end: bool = pixel.a > 0.9 and pixel.r > 0.65 and pixel.g > 0.45
			_check(painted_end == (slot < amount),
				"Authored end-grain slots must visibly count exactly %d logs (slot %d)" % [amount,slot+1], failures)
		_check(not Stock.contains_point(stock, rect.position + Vector2.ONE),
			"Transparent canvas padding must not extend the stock picking area", failures)
	_check(hashes.size() == 7, "All seven actual imported inventory textures must be distinct", failures)


static func _test_truthful_inventory(library: Stock, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	building["inputs"]["log"] = 4
	building["storage"]["log"] = 5
	building["reserved_incoming"] = {"log":6}
	world.buildings[fixture["warehouse"]]["storage"]["log"] = 20
	var worker_id: int = world.spawn_worker(Vector2i(14,10), "lumberjack", int(building["id"]))
	var worker: Dictionary = world.workers[worker_id]
	worker["carrying"] = "log"
	_check(int(_presentation(library,world,building)["amount"]) == 0,
		"Warehouse stock, inputs, reservations and carried logs must not fill the hut rack", failures)
	building["outputs"]["log"] = 3
	for inside: int in [0,int(building["id"])]:
		worker["inside_building_id"] = inside
		for enabled: bool in [false,true]:
			building["enabled"] = enabled
			worker["enabled"] = enabled
			_check(int(_presentation(library,world,building)["amount"]) == 3,
				"Stock must persist independently of assignment, indoor presence and stopped work", failures)


static func _test_private_inventory(library: Stock, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	building["owner_id"] = 2
	world.fog.enabled = true
	# A deliberately unreadable private bucket proves the privacy return comes
	# before the cast/read, rather than merely clearing a value after reading it.
	building["outputs"] = "private bucket must not be read"
	for visible: bool in [false,true]:
		world.fog.explored[building["position"]] = true
		if visible:
			world.fog.visible[building["position"]] = true
		var stock: Dictionary = _presentation(library,world,building)
		_check(not bool(stock.get("known",true)) and int(stock.get("amount",0)) == -1
			and stock.get("texture") == null and stock.get("hit_mask") == null and stock.get("count_label") == "?",
			"Foreign inventory must stay neutral unknown in explored and visible fog, without reading the private bucket", failures)
	building["outputs"] = {"log":4}
	world.fog.enabled = false
	_check(int(_presentation(library,world,building)["amount"]) == 4,
		"Fog disabled must follow the existing HUD inventory disclosure policy", failures)
	world.fog.enabled = true
	building["owner_id"] = 1
	_check(int(_presentation(library,world,building)["amount"]) == 4,
		"The local player may see their own inventory through the normal building draw path", failures)


static func _test_construction_and_capacity(library: Stock, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	building["outputs"]["log"] = 3
	for remaining: int in [120,35,1]:
		building["construction_remaining"] = remaining
		_check(_presentation(library,world,building).is_empty(), "Unfinished structures must never show operating stock", failures)
	building["construction_remaining"] = 0
	building["foundation_work_remaining"] = 1
	_check(_presentation(library,world,building).is_empty(), "Ground preparation must not show stock", failures)
	building["foundation_work_remaining"] = 0
	building["footprint_version"] = 0
	_check(_presentation(library,world,building).is_empty(), "Legacy one-cell huts must keep their existing renderer", failures)
	building["footprint_version"] = 1
	world.catalog.buildings["lumber_hut"]["output_capacity"] = 9
	building["outputs"]["log"] = 8
	var stock: Dictionary = _presentation(library,world,building)
	_check(int(stock["amount"]) == 8 and int(stock["capacity"]) == 9 and stock["count_label"] == "8/9",
		"Changed capacity must explicitly show the actual amount instead of silently truncating to six", failures)
	world.catalog.buildings["lumber_hut"]["output_capacity"] = 6


static func _test_real_producer_delivery(library: Stock, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	world.add_tree(Vector2i(15,9),2)
	var id: int = world.spawn_worker(Vector2i(14,9),"lumberjack",int(building["id"]))
	var carried: bool = false
	var delivered: bool = false
	for _tick: int in range(900):
		world.step_tick()
		var amount: int = int(_presentation(library,world,building)["amount"])
		if world.workers[id]["carrying"] == "log":
			carried = true
			_check(amount == 0, "The first physically carried log must not appear in storage before handover", failures)
		if amount == 1:
			delivered = true
			_check(world.workers[id]["carrying"] == "", "A rendered stored log must follow real cargo handover", failures)
			break
	_check(carried and delivered, "Real harvesting fixture must observe both the carried log and completed deposit", failures)


static func _test_real_pickup_and_saves(library: Stock, failures: Array[String]) -> void:
	var fixture: Dictionary = _fixture()
	var world: World = fixture["world"]
	var building: Dictionary = world.buildings[fixture["id"]]
	for amount: int in range(7):
		building["outputs"]["log"] = amount
		var restored := World.new()
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(world.to_data())) as Dictionary
		var loaded: bool = restored.from_data(snapshot)
		_check(loaded, "Each stock amount must round-trip through real JSON save data", failures)
		if loaded:
			_check(int(_presentation(library,restored,restored.buildings[fixture["id"]])["amount"]) == amount,
				"Loading must restore the visible stock immediately from physical inventory", failures)
	var carrier: int = world.spawn_worker(Vector2i(7,10),"carrier")
	var saw_reservation: bool = false
	var saw_cargo: bool = false
	var previous: int = 6
	for _tick: int in range(1800):
		var before: Dictionary = world.workers[carrier].duplicate(true)
		world.step_tick()
		var amount: int = int(_presentation(library,world,building)["amount"])
		var worker: Dictionary = world.workers[carrier]
		if worker["action"] == "pickup_log" and amount == 6:
			saw_reservation = true
		if amount < previous:
			saw_cargo = true
			_check(amount == previous-1 and worker["carrying"] == "log" and before["action"] == "pickup_log",
				"Each visible decrement must coincide with actual carrier pickup, not a reservation", failures)
		previous = amount
		if int(world.buildings[fixture["warehouse"]]["storage"].get("log",0)) == 6:
			break
	_check(saw_reservation and saw_cargo and previous == 0
		and int(world.buildings[fixture["warehouse"]]["storage"].get("log",0)) == 6,
		"Real carrier must reserve, collect and deliver every displayed log until the rack is truly empty", failures)


static func _settle(host: Node, main: MainView) -> void:
	main.queue_redraw()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


static func _test_actual_scene(host: Node, failures: Array[String]) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000,720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var main: MainView = MainScene.instantiate() as MainView
	main.honor_launch_arguments = false
	var fixture: Dictionary = _fixture()
	main.world = fixture["world"]
	main.simulation_speed = 0.0
	viewport.add_child(main)
	main.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.hud.visible = false
	var building: Dictionary = main.world.buildings[fixture["id"]]
	main.camera.zoom = Vector2.ONE * 2.4
	main.camera.position = main.building_geometry(building)["door"] - Vector2(60,10)
	main.camera.force_update_scroll()
	var rect: Rect2 = main.building_sprite_presentation(building)["rect"]
	var native: Array[Image] = []
	for amount: int in range(7):
		building["outputs"]["log"] = amount
		var before: Dictionary = main.world.to_data()
		main._update_ui()
		await _settle(host,main)
		var stock: Dictionary = main.building_stock_presentation(building)
		_check(int(stock.get("amount",-1)) == amount and stock.get("rect") == rect and main.world.to_data() == before,
			"The paused actual main scene must redraw direct inventory changes without moving the house or changing simulation state", failures)
		if DisplayServer.get_name() != "headless":
			native.append(viewport.get_texture().get_image())
	if DisplayServer.get_name() != "headless":
		for amount: int in range(1,7):
			var point: Vector2 = rect.position + CAPS[amount-1] * (640.0/1254.0) * 0.225
			var screen := Vector2i(main.get_global_transform_with_canvas() * point)
			var empty: Color = native[0].get_pixelv(screen)
			var full: Color = native[amount].get_pixelv(screen)
			_check(absf(full.r-empty.r)+absf(full.g-empty.g)+absf(full.b-empty.b) > 0.08,
				"Native positive control must visibly add each new painted log end in the actual main-scene renderer", failures)
	# Current geometry reserves the rack ground even when empty. Also retain
	# the original v1 regression where only actual stock alpha can claim it.
	_test_new_stock_alpha_picking(main,building,failures)
	var historical: Dictionary = _fixture(1)
	var historical_view := MainView.new()
	historical_view.world = historical["world"]
	historical_view.terrain_renderer = Terrain.new()
	historical_view.add_child(historical_view.terrain_renderer)
	historical_view.terrain_renderer.bind_grid(historical_view.world.grid)
	var historical_building: Dictionary = historical_view.world.buildings[historical["id"]]
	historical_building["outputs"]["log"] = 6
	_test_new_stock_alpha_picking(historical_view,historical_building,failures)
	historical_view.free()
	# A private state cannot change the rendered result when only its hidden
	# inventory changes; the same flag hides numbers and stock hit masks.
	building["owner_id"] = 2
	main.world.fog.enabled = true
	main.world.fog.explored[building["position"]] = true
	building["outputs"]["log"] = 0
	var hidden_empty: Dictionary = main.building_stock_presentation(building)
	building["outputs"]["log"] = 6
	_check(main.building_stock_presentation(building) == hidden_empty and hidden_empty.get("count_label") == "?",
		"Actual main-scene private presentation must be independent of hidden stock changes", failures)
	building["owner_id"] = 1
	main.world.fog.enabled = false
	main.world.tick = 4750
	main._update_ui()
	await _settle(host,main)
	_check(main.building_stock_presentation(building)["amount"] == 6 and main.modulate == main.solar_state["ambient"],
		"Night lighting must apply to stock through the same parent canvas while preserving quantity", failures)
	if DisplayServer.get_name() != "headless":
		var point: Vector2 = rect.position + CAPS[5] * (640.0/1254.0) * 0.225
		var screen := Vector2i(main.get_global_transform_with_canvas() * point)
		_check(native[6].get_pixelv(screen).get_luminance() > viewport.get_texture().get_image().get_pixelv(screen).get_luminance() + 0.05,
			"Actual native log pixels must darken with the house at night", failures)
	viewport.free()


static func _test_new_stock_alpha_picking(main: MainView, building: Dictionary, failures: Array[String]) -> void:
	var house: Dictionary = main.building_sprite_presentation(building)
	var stock: Dictionary = main.building_stock_presentation(building)
	var source: Image = (stock["texture"] as Texture2D).get_image()
	var rect: Rect2 = stock["rect"]
	var point := Vector2.INF
	# Search actual imported opacity below the unchanged doorway, outside the
	# empty-house alpha. V1 leaves this ground free; v2 reserves it for the rack.
	for y: int in range(414,525,2):
		for x: int in range(150,265,2):
			if source.get_pixel(x,y).a < 0.99:
				continue
			var candidate: Vector2 = rect.position + Vector2(x+0.5,y+0.5) * float(stock["source_to_world"])
			if not House.contains_point(house,candidate):
				point = candidate
				break
		if point.is_finite():
			break
	_check(point.is_finite(), "Stock picking regression requires a real log pixel outside the original empty-house alpha", failures)
	if not point.is_finite():
		return
	_check(main._building_id_at_visual_position(point) == int(building["id"]),
		"The normal painter-order picker must include a newly visible stock pixel", failures)
	building["outputs"]["log"] = 0
	var empty: Dictionary = main.building_stock_presentation(building)
	_check(not Stock.contains_point(empty, point),
		"Empty stock must contribute no invisible selection pixels", failures)
	var expected: int = int(building["id"]) if int(building["footprint_version"]) == 2 else 0
	_check(main._building_id_at_visual_position(point) == expected,
		"Empty rack selection must respect the exact saved footprint revision", failures)
	building["outputs"]["log"] = 6
