extends RefCounted

const UiText = preload("res://scripts/ui_text.gd")
const Catalog = preload("res://scripts/simulation/definition_catalog.gd")
const TEST_COUNT: int = 5


# The presentation layer must name every catalog entry and decline Czech counts
# correctly; a number never takes the plain nominative plural.
static func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := Catalog.new()
	_check_catalog_coverage(catalog, failures)
	_check_plurals(failures)
	_check_counted_resources(failures)
	_check_unknown_ids(catalog, failures)
	_check_data_untouched(catalog, failures)
	return failures


static func _check_catalog_coverage(catalog: Catalog, failures: Array[String]) -> void:
	for resource_id: String in catalog.resources:
		_expect(UiText.RESOURCES.has(resource_id) and UiText.RESOURCE_COUNTS.has(resource_id),
			"Every ware needs a Czech name and counted forms: " + resource_id, failures)
	for building_type: String in catalog.buildings:
		_expect(UiText.BUILDINGS.has(building_type),
			"Every building needs a Czech name: " + building_type, failures)
	for unit_type: String in catalog.units:
		_expect(UiText.UNITS.has(unit_type), "Every profession needs a Czech name: " + unit_type, failures)
	for soldier_id: String in catalog.soldiers:
		_expect(UiText.SOLDIERS.has(soldier_id), "Every soldier needs a Czech name: " + soldier_id, failures)


static func _check_plurals(failures: Array[String]) -> void:
	# Czech, unlike Polish or Russian, keeps the genitive above twenty:
	# "dvacet dva obyvatel", not "dvacet dva obyvatelé".
	for expectation: Array in [[0, "obyvatel"], [1, "obyvatel"], [2, "obyvatelé"], [4, "obyvatelé"],
			[5, "obyvatel"], [11, "obyvatel"], [22, "obyvatel"]]:
		_expect(UiText.citizens(int(expectation[0])) == "%d %s" % [int(expectation[0]), String(expectation[1])],
			"Citizen count must use the 1 / 2-4 / 5+ form for %d" % int(expectation[0]), failures)
	_expect(UiText.soldiers(1) == "1 voják" and UiText.soldiers(3) == "3 vojáci" and UiText.soldiers(7) == "7 vojáků",
		"Soldier counts must decline the same way", failures)
	_expect(UiText.tiles(1) == "1 pole" and UiText.tiles(3) == "3 pole" and UiText.tiles(8) == "8 polí",
		"Tile counts must decline the same way", failures)


static func _check_counted_resources(failures: Array[String]) -> void:
	for expectation: Array in [["plank", 1, "1 prkno"], ["plank", 3, "3 prkna"], ["plank", 9, "9 prken"],
			["stone", 1, "1 kámen"], ["stone", 2, "2 kameny"], ["stone", 5, "5 kamenů"],
			["log", 1, "1 kláda"], ["log", 6, "6 klád"]]:
		_expect(UiText.resource_amount(String(expectation[0]), int(expectation[1])) == String(expectation[2]),
			"Counted ware text must be declined: %s x%d" % [expectation[0], int(expectation[1])], failures)


static func _check_unknown_ids(catalog: Catalog, failures: Array[String]) -> void:
	# An id added to the data before this table must stay visible, not blank.
	_expect(not UiText.resource_name(catalog, "unmapped_ware").is_empty(),
		"An unmapped ware must still render a readable name", failures)
	_expect(not UiText.building_name(catalog, "unmapped_building").is_empty(),
		"An unmapped building must still render a readable name", failures)
	_expect(not UiText.resource_amount("unmapped_ware", 3).is_empty(),
		"An unmapped ware must still render a counted amount", failures)
	_expect(UiText.building_hint(catalog, "unmapped_building").is_empty(),
		"An unmapped building has no invented hint", failures)


static func _check_data_untouched(catalog: Catalog, failures: Array[String]) -> void:
	# Translating is a view concern: the catalog keeps the identifiers that
	# saves, documents and other tests rely on.
	_expect(String((catalog.resources["log"] as Dictionary)["display_name"]) == "Logs"
			and String((catalog.buildings["sawmill"] as Dictionary)["display_name"]) == "Sawmill",
		"The data catalog must keep its original display names", failures)
	_expect(UiText.resource_name(catalog, "log") == "Klády" and UiText.building_name(catalog, "sawmill") == "Pila",
		"The HUD must read its names from the presentation table, not the catalog", failures)


static func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
