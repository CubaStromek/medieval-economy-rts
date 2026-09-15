extends RefCounted

const UiText = preload("res://scripts/ui_text.gd")
const LegacyFixture = preload("res://tests/legacy_world_fixture.gd")

const Catalog = preload("res://scripts/simulation/definition_catalog.gd")
const Hud = preload("res://scripts/view/game_hud.gd")
const World = preload("res://scripts/simulation/simulation_world.gd")
const TEST_COUNT: int = 4


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_both_huts_in_dynamic_menu(failures)
	_test_training_requirements_and_signals(failures)
	_test_hut_details_and_occupancy(failures)
	_test_catalog_driven_guidance(failures)
	return failures


static func _test_both_huts_in_dynamic_menu(failures: Array[String]) -> void:
	var catalog := Catalog.new()
	var hud := Hud.new()
	hud.configure(catalog)
	var emitted: Array[String] = []
	hud.build_mode_requested.connect(func(mode: String) -> void: emitted.append(mode))
	for hut_type: String in ["forester_hut", "fisher_hut"]:
		var definition: Dictionary = catalog.building(hut_type)
		var button: Button = hud.find_child("Build_" + hut_type, true, false) as Button
		if definition.is_empty() or button == null:
			failures.append("The actual building catalog and generated menu must expose " + hut_type)
			continue
		var category: String = "infrastructure" if hut_type == "forester_hut" else "food"
		_expect(button.get_parent() == hud._build_groups[category],
			"Forester and fisher huts must be reachable in Infrastructure and Food respectively", failures)
		_expect(button.text == UiText.building_label(catalog, hut_type)
			and hud.find_children("Build_" + hut_type, "Button", true, false).size() == 1,
			"Each hut must have exactly one clearly named menu entry, not a duplicate hut type", failures)
		var category_index: int = Hud.CATEGORIES.find(category)
		hud._category_buttons[category_index].pressed.emit()
		_expect((hud._build_groups[category] as Control).visible,
			"The real category button must reveal its hut group", failures)
		for resource_id: String in definition["construction_cost"]:
			var requirement: String = UiText.resource_amount(
				resource_id, int(definition["construction_cost"][resource_id]))
			_expect(button.tooltip_text.contains(requirement),
				"Hut build tooltips must show their actual catalog construction costs", failures)
		button.pressed.emit()
	_expect(emitted == ["forester_hut", "fisher_hut"],
		"Both generated hut buttons must emit their actual existing placement mode IDs", failures)
	hud.free()


static func _test_training_requirements_and_signals(failures: Array[String]) -> void:
	var hud := Hud.new()
	hud.configure(Catalog.new())
	var gardener: Button = hud.find_child("Train_gardener", true, false) as Button
	var fisherman: Button = hud.find_child("Train_fisherman", true, false) as Button
	if gardener == null or fisherman == null:
		failures.append("School actions must expose the actual gardener and fisherman training buttons")
		hud.free()
		return
	_expect(gardener.tooltip_text.contains("potřebuje stavbu Chata lesníka")
		and gardener.tooltip_text.contains("dostupnou volnou zem")
		and gardener.tooltip_text.contains("Jeden lesník na chatu"),
		"Gardener training must explain its required exclusive Forester Hut workplace", failures)
	_expect(fisherman.tooltip_text.contains("potřebuje stavbu Rybářská chata")
		and fisherman.tooltip_text.contains("dostupného ložiska ryb")
		and fisherman.tooltip_text.contains("odvážejí nosiči"),
		"Fisherman training must explain its hut, reachable fish source and separate carrier transport", failures)
	_expect(gardener.tooltip_text.contains("Cena:") and fisherman.tooltip_text.contains("Cena:"),
		"Workplace guidance must preserve existing training price and duration information", failures)
	var emitted: Array[String] = []
	hud.unit_training_requested.connect(func(role: String) -> void: emitted.append(role))
	gardener.pressed.emit()
	fisherman.pressed.emit()
	_expect(emitted == ["gardener", "fisherman"],
		"Accessible training buttons must preserve the real unit IDs and forwarded school action signals", failures)
	hud.free()


static func _test_hut_details_and_occupancy(failures: Array[String]) -> void:
	var world := LegacyFixture.create(Vector2i(14, 10))
	var hud := Hud.new()
	hud.configure(world.catalog)
	for index: int in range(2):
		var hut_type: String = "forester_hut" if index == 0 else "fisher_hut"
		var role: String = "gardener" if index == 0 else "fisherman"
		var cell := Vector2i(3 + index * 6, 3)
		if hut_type == "fisher_hut":
			world.set_base_terrain(cell + Vector2i(2, 0), "water")
			world.add_deposit(cell + Vector2i(2, 0), "fish", 30)
		var hut_id: int = world.place_building(hut_type, cell)
		if hut_id == 0:
			failures.append("Hut detail fixture must place a real completed " + hut_type)
			continue
		var details: String = hud._selected_production_text(world, cell)
		_expect(details.contains("0/1") and details.contains("čeká na obsazení"),
			"An empty completed hut must visibly advertise its one specialist vacancy", failures)
		if hut_type == "forester_hut":
			_expect(details.contains("Dosah sázení: 8 polí od chaty")
				and details.contains("dostupnou volnou zem") and details.contains("Lesníka"),
				"Selected forester huts must show the planting range and required specialist", failures)
		else:
			_expect(details.contains("Dosah rybolovu: 3 pole")
				and details.contains("ložisko ryb") and details.contains("odvážejí"),
				"Selected fisher huts must explain the extraction range, source and stored-output transport", failures)
		var worker_id: int = world.spawn_worker(cell + Vector2i.DOWN, role, hut_id)
		_expect(worker_id != 0, "The hut detail fixture must hire the correct real specialist", failures)
		if worker_id != 0:
			details = hud._selected_production_text(world, cell)
			_expect(details.contains("#%d" % worker_id) and details.contains("1/1")
				and not details.contains("0/1"),
				"Hut details must expose its real single occupant rather than only static help text", failures)
	hud.free()


static func _test_catalog_driven_guidance(failures: Array[String]) -> void:
	var catalog := Catalog.new()
	if catalog.building("forester_hut").is_empty():
		failures.append("Catalog-driven hut guidance requires the new actual forester definition")
		return
	# Player-facing names come from the presentation table now, so this checks
	# that the configured ranges - the part the catalog still owns - flow through.
	catalog.buildings["forester_hut"]["planting_radius"] = 6
	catalog.buildings["fisher_hut"]["extract_radius"] = 2
	var hud := Hud.new()
	hud.configure(catalog)
	var gardener: Button = hud.find_child("Train_gardener", true, false) as Button
	var fisherman: Button = hud.find_child("Train_fisherman", true, false) as Button
	var forester: Button = hud.find_child("Build_forester_hut", true, false) as Button
	_expect(gardener != null and gardener.tooltip_text.contains(UiText.building_name(catalog, "forester_hut"))
		and gardener.tooltip_text.contains("do 6 polí"),
		"Forester training guidance must follow authored names and planting range, not fixed prototype values", failures)
	_expect(fisherman != null and fisherman.tooltip_text.contains("do 2 pole"),
		"Fish-source training guidance must follow the hut's actual configured extraction range", failures)
	_expect(forester != null and forester.text == UiText.building_label(catalog, "forester_hut")
		and forester.tooltip_text.contains("do 6 polí")
		and hud._build_mode_hint("fisher_hut").contains("do 2 pole"),
		"Generated build labels and placement hints must stay synchronized with catalog changes", failures)
	hud.free()


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
