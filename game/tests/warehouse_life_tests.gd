extends RefCounted

const World = preload("res://scripts/simulation/simulation_world.gd")
const Life = preload("res://scripts/view/warehouse_life.gd")
const TEST_COUNT := 3


static func run() -> Array[String]:
	var failures: Array[String] = []
	for test: Callable in [_test_open_doors, _test_foreign_privacy, _test_unfinished]:
		test.call(failures)
	return failures


static func _fixture() -> Dictionary:
	var world := World.new(Vector2i(24, 18))
	var building_id: int = world.place_building("warehouse", Vector2i(8, 5))
	return {"world": world, "building": world.buildings[building_id], "library": Life.new(),
		"house": {"rect": Rect2(100, 50, 250, 250), "source_to_world": 0.2,
			"life": {"windows": [], "chimney": [400, 80]}}}


static func _life(f: Dictionary) -> Dictionary:
	return f["library"].presentation_for(f["world"], f["building"], f["house"])


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


static func _test_open_doors(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	var before: Dictionary = f["world"].to_data()
	var life: Dictionary = _life(f)
	_check(f["library"].doors_open(f["world"], f["building"]) and bool(life["known"]) and bool(life["door_open"])
		and not life.has("night") and not life.has("light_strength") and not life.has("smoke_strength"),
		"An own completed warehouse keeps its doors open without any night, light or smoke state", failures)
	_check(f["world"].to_data() == before, "Reading warehouse life must not mutate the simulation", failures)
	for tick: int in [0, 3750, 4750]:
		f["world"].tick = tick
		_check(f["library"].doors_open(f["world"], f["building"]) and bool(_life(f)["door_open"]),
			"Warehouse doors must not depend on the simulation tick", failures)


static func _test_foreign_privacy(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	f["world"].enable_fog()
	f["building"]["owner_id"] = 2
	var life: Dictionary = _life(f)
	_check(not f["library"].doors_open(f["world"], f["building"]) and not bool(life["known"]) and not bool(life["door_open"]),
		"An explored foreign warehouse keeps the neutral closed-door silhouette", failures)


static func _test_unfinished(failures: Array[String]) -> void:
	var f: Dictionary = _fixture()
	f["building"]["construction_remaining"] = 1
	_check(not f["library"].doors_open(f["world"], f["building"]) and _life(f).is_empty(),
		"An unfinished warehouse has neither open doors nor a life presentation", failures)
	f["building"]["construction_remaining"] = 0
	f["house"]["life"] = {}
	_check(_life(f).is_empty(), "Unauthored warehouse art cannot acquire generic life geometry", failures)
