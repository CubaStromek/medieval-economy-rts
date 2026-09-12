extends Node

const Stock = preload("res://tests/resource_stock_tests.gd")
const Transport = preload("res://tests/transport_search_tests.gd")
const Hud = preload("res://tests/hud_layout_tests.gd")
const Food = preload("res://tests/food_ui_tests.gd")
const Hunger = preload("res://tests/hunger_ui_tests.gd")
const Nutrition = preload("res://tests/nutrition_ui_tests.gd")
const Night = preload("res://tests/night_schedule_view_tests.gd")
const Fog = preload("res://tests/fog_view_tests.gd")
const Inspector = preload("res://tests/inspector_activity_tests.gd")
const Terrain = preload("res://tests/terrain_cache_tests.gd")
const Painted = preload("res://tests/painted_terrain_tests.gd")

var failures: Array[String] = []
var count: int = 0


func _ready() -> void:
	for suite in [Stock, Transport, Food, Hunger, Nutrition, Painted]:
		_record(suite.TEST_COUNT, suite.run())
	for suite in [Hud, Night, Fog, Inspector, Terrain]:
		_record(suite.TEST_COUNT, await suite.run(self))
	for failure: String in failures:
		printerr(failure)
	print("REFACTOR RESULT: %d cases, %d failures" % [count, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _record(cases: int, result: Array[String]) -> void:
	count += cases
	failures.append_array(result)
