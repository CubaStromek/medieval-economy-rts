class_name DefinitionCatalog
extends RefCounted

static var _movement_defaults: Dictionary = {}

const CONSTRUCTION_COST_REVISION: int = 2
# Revision 1 was shipped before the source-backed construction catalog. Keep
# its material contracts immutable so an old building/site can still load and
# cancel without losing delivered wares or charging a different price.
const LEGACY_CONSTRUCTION_COSTS: Dictionary = {
	"warehouse": {"plank": 5, "stone": 4},
	"lumber_hut": {"plank": 3, "stone": 2},
	"sawmill": {"plank": 4, "stone": 3},
	"school": {"plank": 5, "stone": 4},
	"quarry": {"plank": 3, "stone": 2},
	"farm": {"plank": 5, "stone": 4},
	"mill": {"plank": 4, "stone": 3},
	"bakery": {"plank": 4, "stone": 3},
	"coal_mine": {"plank": 4, "stone": 3},
	"iron_mine": {"plank": 4, "stone": 2},
	"gold_mine": {"plank": 4, "stone": 2},
	"iron_smithy": {"plank": 4, "stone": 3},
	"metallurgist": {"plank": 4, "stone": 3},
	"vineyard": {"plank": 4, "stone": 3},
	"fisher_hut": {"plank": 3, "stone": 2},
	"swine_farm": {"plank": 5, "stone": 4},
	"butcher": {"plank": 4, "stone": 3},
	"tannery": {"plank": 4, "stone": 3},
	"stables": {"plank": 5, "stone": 4},
	"weapon_workshop": {"plank": 4, "stone": 3},
	"armour_workshop": {"plank": 4, "stone": 3},
	"weapon_smithy": {"plank": 4, "stone": 3},
	"armour_smithy": {"plank": 4, "stone": 3},
	"inn": {"plank": 5, "stone": 4},
	"barracks": {"plank": 5, "stone": 4},
	"marketplace": {"plank": 5, "stone": 6},
	"town_hall": {"plank": 5, "stone": 4},
	"watchtower": {"plank": 4, "stone": 3},
}

var resources: Dictionary = {}
var buildings: Dictionary = {}
var recipes: Dictionary = {}
var units: Dictionary = {}
var movement: Dictionary = {}
var economy: Dictionary = {}
var soldiers: Dictionary = {}


func _init() -> void:
	resources = _load_json("res://data/resources.json")
	buildings = _load_json("res://data/buildings.json")
	recipes = _load_json("res://data/recipes.json")
	units = _load_json("res://data/units.json")
	economy = _load_json("res://data/economy.json")
	soldiers = _load_json("res://data/soldiers.json")
	movement = movement_defaults()


func building(building_type: String) -> Dictionary:
	return buildings.get(building_type, {}) as Dictionary


func construction_cost(building_type: String, revision: int = CONSTRUCTION_COST_REVISION) -> Dictionary:
	if revision == 1:
		return (LEGACY_CONSTRUCTION_COSTS.get(building_type, {}) as Dictionary).duplicate(true)
	if revision == CONSTRUCTION_COST_REVISION:
		return (building(building_type).get("construction_cost", {}) as Dictionary).duplicate(true)
	return {}


func recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {}) as Dictionary


func unit(unit_type: String) -> Dictionary:
	return units.get(unit_type, soldiers.get(unit_type, {})) as Dictionary


static func movement_defaults() -> Dictionary:
	# Both standalone grids and worlds start from the same authored definitions.
	# Each caller owns its copy so runtime tuning cannot change another world.
	if _movement_defaults.is_empty():
		_movement_defaults = _load_json("res://data/movement.json")
	return _movement_defaults.duplicate(true)


static func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Missing data definition: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "Definition must be a JSON object: %s" % path)
	return parsed as Dictionary
