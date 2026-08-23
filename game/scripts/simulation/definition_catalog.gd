class_name DefinitionCatalog
extends RefCounted

var resources: Dictionary = {}
var buildings: Dictionary = {}
var recipes: Dictionary = {}
var units: Dictionary = {}
var movement: Dictionary = {}


func _init() -> void:
	resources = _load_json("res://data/resources.json")
	buildings = _load_json("res://data/buildings.json")
	recipes = _load_json("res://data/recipes.json")
	units = _load_json("res://data/units.json")
	movement = _load_json("res://data/movement.json")


func building(building_type: String) -> Dictionary:
	return buildings.get(building_type, {}) as Dictionary


func recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {}) as Dictionary


func unit(unit_type: String) -> Dictionary:
	return units.get(unit_type, {}) as Dictionary


static func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Missing data definition: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "Definition must be a JSON object: %s" % path)
	return parsed as Dictionary
