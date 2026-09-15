class_name UiText
extends RefCounted

## Czech presentation names for the HUD.
##
## The data catalog keeps its original English `display_name` values: they are
## save-, test- and document-facing identifiers. This layer translates only what
## the player reads, so renaming a label never touches simulation data.
## Unknown ids fall back to the catalog name, which keeps a newly added building
## or ware visible instead of blank.

const RESOURCES: Dictionary = {
	"log": "Klády", "plank": "Prkna", "stone": "Kámen",
	"grain": "Obilí", "flour": "Mouka", "bread": "Chléb",
	"iron_ore": "Železná ruda", "gold_ore": "Zlatá ruda", "coal": "Uhlí",
	"iron": "Železo", "gold": "Zlato", "wine": "Víno",
	"leather": "Vydělaná kůže", "sausage": "Klobásy", "pig": "Prasata",
	"skin": "Surové kůže", "wooden_shield": "Dřevěné štíty", "iron_shield": "Železné štíty",
	"leather_armour": "Kožená zbroj", "iron_armour": "Železná zbroj",
	"axe": "Sekery", "sword": "Meče", "lance": "Kopí", "pike": "Piky",
	"bow": "Luky", "crossbow": "Kuše", "horse": "Koně", "fish": "Ryby",
}

const BUILDINGS: Dictionary = {
	"warehouse": "Sklad", "lumber_hut": "Chata dřevorubce", "forester_hut": "Chata lesníka",
	"sawmill": "Pila", "school": "Škola",
	"quarry": "Lom", "farm": "Statek", "mill": "Mlýn", "bakery": "Pekárna",
	"coal_mine": "Uhelný důl", "iron_mine": "Železný důl", "gold_mine": "Zlatý důl",
	"iron_smithy": "Železná huť", "metallurgist": "Zlatá huť",
	"vineyard": "Vinice", "fisher_hut": "Rybářská chata", "swine_farm": "Prasečí farma",
	"butcher": "Řeznictví", "tannery": "Koželužna", "stables": "Stáje",
	"weapon_workshop": "Dílna zbraní", "armour_workshop": "Dílna zbroje",
	"weapon_smithy": "Kovárna zbraní", "armour_smithy": "Kovárna zbroje",
	"inn": "Hostinec", "barracks": "Kasárna", "marketplace": "Tržiště",
	"town_hall": "Radnice", "watchtower": "Strážní věž",
}

## Shorter labels for the two-column build list, where the full name wraps to
## three lines. Everything else keeps the full name.
const BUILDING_SHORT: Dictionary = {
	"lumber_hut": "Dřevorubec", "forester_hut": "Lesník",
	"fisher_hut": "Rybář", "weapon_workshop": "Dílna zbraní", "armour_workshop": "Dílna zbroje",
	"weapon_smithy": "Kovárna zbraní", "armour_smithy": "Kovárna zbroje",
}

const UNITS: Dictionary = {
	"lumberjack": "Dřevorubec", "carrier": "Nosič", "gardener": "Lesník",
	"farmer": "Sedlák", "baker": "Pekař", "stonemason": "Kameník",
	"miner": "Horník", "metallurgist": "Hutník", "smith": "Kovář",
	"butcher": "Řezník", "animal_breeder": "Chovatel", "fisherman": "Rybář",
	"carpenter": "Truhlář", "builder": "Stavitel", "recruit": "Rekrut",
}

const SOLDIERS: Dictionary = {
	"militia": "Domobranec", "axe_fighter": "Sekerník", "sword_fighter": "Mečník",
	"bowman": "Lučištník", "crossbowman": "Střelec z kuše", "lance_carrier": "Kopiník",
	"pikeman": "Pikenýr", "scout": "Zvěd", "knight": "Rytíř",
	"rebel": "Povstalec", "rogue": "Lapka", "vagabond": "Tulák",
	"barbarian": "Barbar", "warrior": "Válečník",
}

## Counted forms: "1 prkno", "3 prkna", "7 prken". A number never takes the
## nominative plural used on the stock tiles, so amounts get their own table.
const RESOURCE_COUNTS: Dictionary = {
	"log": ["kláda", "klády", "klád"],
	"plank": ["prkno", "prkna", "prken"],
	"stone": ["kámen", "kameny", "kamenů"],
	"grain": ["obilí", "obilí", "obilí"],
	"flour": ["mouka", "mouky", "mouky"],
	"bread": ["chléb", "chleby", "chlebů"],
	"iron_ore": ["železná ruda", "železné rudy", "železné rudy"],
	"gold_ore": ["zlatá ruda", "zlaté rudy", "zlaté rudy"],
	"coal": ["uhlí", "uhlí", "uhlí"],
	"iron": ["železo", "železa", "železa"],
	"gold": ["zlato", "zlata", "zlata"],
	"wine": ["víno", "vína", "vín"],
	"leather": ["vydělaná kůže", "vydělané kůže", "vydělaných kůží"],
	"sausage": ["klobása", "klobásy", "klobás"],
	"pig": ["prase", "prasata", "prasat"],
	"skin": ["surová kůže", "surové kůže", "surových kůží"],
	"wooden_shield": ["dřevěný štít", "dřevěné štíty", "dřevěných štítů"],
	"iron_shield": ["železný štít", "železné štíty", "železných štítů"],
	"leather_armour": ["kožená zbroj", "kožené zbroje", "kožených zbrojí"],
	"iron_armour": ["železná zbroj", "železné zbroje", "železných zbrojí"],
	"axe": ["sekera", "sekery", "seker"],
	"sword": ["meč", "meče", "mečů"],
	"lance": ["kopí", "kopí", "kopí"],
	"pike": ["pika", "piky", "pik"],
	"bow": ["luk", "luky", "luků"],
	"crossbow": ["kuše", "kuše", "kuší"],
	"horse": ["kůň", "koně", "koní"],
	"fish": ["ryba", "ryby", "ryb"],
}

## Short in-game explanation shown under the build list and in tooltips, for
## buildings without a more specific placement hint.
const BUILDING_HINTS: Dictionary = {
	"warehouse": "Ústřední sklad osady. Nosiči sem svážejí a odsud rozvážejí zboží.",
	"lumber_hut": "Dřevorubec zde kácí okolní stromy a skládá klády na výstup.",
	"forester_hut": "Lesník odsud sází stromky, aby les nedošel.",
	"sawmill": "Truhlář řeže klády na prkna: 1 kláda → 2 prkna.",
	"school": "Cvičí nové obyvatele. Každý výcvik stojí zlato.",
	"quarry": "Kameník láme kámen z blízké skály.",
	"farm": "Sedlák obdělává okolní obilná pole a sváží obilí.",
	"mill": "Mlýn mele obilí na mouku.",
	"bakery": "Pekař peče z mouky chléb.",
	"coal_mine": "Horník těží uhlí z ložiska pod sebou.",
	"iron_mine": "Horník těží železnou rudu.",
	"gold_mine": "Horník těží zlatou rudu.",
	"iron_smithy": "Hutník taví z rudy a uhlí železo.",
	"metallurgist": "Hutník taví z rudy a uhlí zlaté mince.",
	"vineyard": "Sedlák sklízí okolní vinná pole a vyrábí víno.",
	"swine_farm": "Chovatel krmí obilím prasata a získává i surové kůže.",
	"butcher": "Řezník zpracovává prasata na klobásy.",
	"tannery": "Koželuh vydělává surové kůže.",
	"stables": "Chovatel odchovává z obilí koně.",
	"weapon_workshop": "Truhlář vyrábí z prken sekery, kopí a luky.",
	"armour_workshop": "Vyrábí dřevěné štíty a koženou zbroj.",
	"weapon_smithy": "Kovář kuje ze železa a uhlí meče, piky a kuše.",
	"armour_smithy": "Kovář kuje železné štíty a železnou zbroj.",
	"barracks": "Zde se z rekrutů a výzbroje stávají vojáci.",
	"marketplace": "Smění jedno zboží za jiné. Nosiči vyřídí dopravu.",
	"town_hall": "Najímá žoldnéře za zlato.",
	"watchtower": "Rekrut hlídkuje a rozšiřuje výhled do okolí.",
}

const FIELDS: Dictionary = {"wheat": "Obilné pole", "vine": "Vinné pole"}

## Nutrition states stay English in the simulation, where they are compared and
## saved. Only the label the player reads is translated.
const SATIETY_STATES: Dictionary = {
	"Fed": "Najedený", "Getting hungry": "Dostává hlad", "Hungry": "Hladový",
	"Weakened": "Zesláblý", "Starving": "Hladoví",
}

const TERRAIN: Dictionary = {
	"grass": "Tráva", "dirt": "Hlína", "sand": "Písek", "rock": "Skála",
	"water": "Voda", "snow": "Sníh", "mud": "Bláto", "gravel": "Štěrk",
}


static func resource_name(catalog: Variant, resource_id: String) -> String:
	return _name(RESOURCES, catalog, "resources", resource_id)


static func building_name(catalog: Variant, building_type: String) -> String:
	return _name(BUILDINGS, catalog, "buildings", building_type)


## Build-list label: the short form when one exists, otherwise the full name.
static func building_label(catalog: Variant, building_type: String) -> String:
	if BUILDING_SHORT.has(building_type):
		return String(BUILDING_SHORT[building_type])
	return building_name(catalog, building_type)


static func unit_name(catalog: Variant, unit_type: String) -> String:
	if SOLDIERS.has(unit_type):
		return String(SOLDIERS[unit_type])
	if UNITS.has(unit_type):
		return String(UNITS[unit_type])
	return _catalog_name(catalog, "soldiers", unit_type, _catalog_name(catalog, "units", unit_type, _humanise(unit_type)))


## "%d %s" with the right Czech form for the count.
static func resource_amount(resource_id: String, count: int) -> String:
	if not RESOURCE_COUNTS.has(resource_id):
		return "%d %s" % [count, _humanise(resource_id).to_lower()]
	var forms: Array = RESOURCE_COUNTS[resource_id] as Array
	return counted(count, String(forms[0]), String(forms[1]), String(forms[2]))


## Falls back to the catalog description, which is still English, rather than
## silently showing nothing for a building added after this table.
static func building_hint(catalog: Variant, building_type: String) -> String:
	if BUILDING_HINTS.has(building_type):
		return String(BUILDING_HINTS[building_type])
	if catalog == null:
		return ""
	var table: Variant = catalog.get("buildings")
	if table is Dictionary and (table as Dictionary).has(building_type):
		return String(((table as Dictionary)[building_type] as Dictionary).get("description", ""))
	return ""


static func satiety_state(state: String) -> String:
	return String(SATIETY_STATES.get(state, state))


static func terrain_name(material: String) -> String:
	return String(TERRAIN.get(material, _humanise(material)))


## Czech counts need the 1 / 2-4 / 5+ forms; "1 obyvatel", "3 obyvatelé",
## "8 obyvatel". Never build these by appending a suffix to a singular.
static func plural(count: int, one: String, few: String, many: String) -> String:
	var absolute: int = absi(count)
	if absolute == 1:
		return one
	if absolute >= 2 and absolute <= 4:
		return few
	return many


static func counted(count: int, one: String, few: String, many: String) -> String:
	return "%d %s" % [count, plural(count, one, few, many)]


static func citizens(count: int) -> String:
	return counted(count, "obyvatel", "obyvatelé", "obyvatel")


static func soldiers(count: int) -> String:
	return counted(count, "voják", "vojáci", "vojáků")


static func days(count: int) -> String:
	return counted(count, "den", "dny", "dnů")


static func tiles(count: int) -> String:
	return counted(count, "pole", "pole", "polí")


static func _name(table: Dictionary, catalog: Variant, section: String, id: String) -> String:
	if table.has(id):
		return String(table[id])
	return _catalog_name(catalog, section, id, _humanise(id))


static func _catalog_name(catalog: Variant, section: String, id: String, fallback: String) -> String:
	if catalog == null:
		return fallback
	var table: Variant = catalog.get(section)
	if table is Dictionary and (table as Dictionary).has(id):
		var definition: Dictionary = (table as Dictionary)[id] as Dictionary
		return String(definition.get("display_name", fallback))
	return fallback


static func _humanise(id: String) -> String:
	return id.replace("_", " ").capitalize()
