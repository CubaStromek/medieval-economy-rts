class_name UnitThoughts
extends RefCounted

# Explicit Czech cases keep diagnostics readable without leaking catalog slugs.
# The three forms describe a destination, an indoor place and a pickup source.
const PLACES: Dictionary = {
	"warehouse": ["do skladu", "ve skladu", "ze skladu"],
	"lumber_hut": ["do dřevorubecké chatrče", "v dřevorubecké chatrči", "z dřevorubecké chatrče"],
	"forester_hut": ["do lesnické chatrče", "v lesnické chatrči", "z lesnické chatrče"],
	"fisher_hut": ["do rybářské chatrče", "v rybářské chatrči", "z rybářské chatrče"],
	"sawmill": ["do pily", "v pile", "z pily"],
	"inn": ["do hostince", "v hostinci", "z hostince"],
	"school": ["do školy", "ve škole", "ze školy"],
	"quarry": ["do kamenické dílny", "v kamenické dílně", "z kamenické dílny"],
	"farm": ["na statek", "na statku", "ze statku"],
	"mill": ["do mlýna", "ve mlýně", "z mlýna"],
	"bakery": ["do pekárny", "v pekárně", "z pekárny"],
	"coal_mine": ["do uhelného dolu", "v uhelném dole", "z uhelného dolu"],
	"iron_mine": ["do železného dolu", "v železném dole", "ze železného dolu"],
	"gold_mine": ["do zlatého dolu", "ve zlatém dole", "ze zlatého dolu"],
	"iron_smithy": ["do hutě", "v huti", "z hutě"],
	"metallurgist": ["do mincovny", "v mincovně", "z mincovny"],
	"vineyard": ["na vinici", "na vinici", "z vinice"],
	"swine_farm": ["do vepřína", "ve vepříně", "z vepřína"],
	"butcher": ["k řezníkovi", "v řeznictví", "z řeznictví"],
	"tannery": ["do koželužny", "v koželužně", "z koželužny"],
	"stables": ["do stájí", "ve stájích", "ze stájí"],
	"weapon_workshop": ["do zbrojní dílny", "ve zbrojní dílně", "ze zbrojní dílny"],
	"armour_workshop": ["do dílny zbrojíře", "v dílně zbrojíře", "z dílny zbrojíře"],
	"weapon_smithy": ["do kovárny zbraní", "v kovárně zbraní", "z kovárny zbraní"],
	"armour_smithy": ["do kovárny zbroje", "v kovárně zbroje", "z kovárny zbroje"],
	"barracks": ["do kasáren", "v kasárnách", "z kasáren"],
	"marketplace": ["na tržiště", "na tržišti", "z tržiště"],
	"town_hall": ["na radnici", "na radnici", "z radnice"],
	"watchtower": ["do strážní věže", "ve strážní věži", "ze strážní věže"],
}
const WARES: Dictionary = {
	"log": "kládu", "plank": "prkno", "stone": "kámen", "grain": "obilí", "flour": "mouku",
	"bread": "chléb", "iron_ore": "železnou rudu", "gold_ore": "zlatou rudu", "coal": "uhlí",
	"iron": "železo", "gold": "zlato", "wine": "víno", "leather": "kůži", "sausage": "klobásy",
	"pig": "prase", "skin": "surovou kůži", "wooden_shield": "dřevěný štít", "iron_shield": "železný štít",
	"leather_armour": "koženou zbroj", "iron_armour": "železnou zbroj", "axe": "sekeru", "sword": "meč",
	"lance": "kopí", "pike": "píku", "bow": "luk", "crossbow": "kuši", "horse": "koně", "fish": "rybu",
}


# A read-only projection of committed state, not a second job planner. Only
# directly referenced entities and the selected building's small recipe are read.
static func describe(world: Variant, worker: Dictionary) -> Dictionary:
	if not _inspectable(world, worker):
		return {}
	var action: String = String(worker.get("action", ""))
	var state: String = String(worker.get("state", "idle"))
	var home: Dictionary = _building(world, worker.get("home_id", 0))
	var source: Dictionary = _building(world, worker.get("source_id", 0))
	var destination: Dictionary = _building(world, worker.get("destination_id", 0))
	var paused: bool = not bool(worker.get("enabled", true)) or (not home.is_empty() and not bool(home.get("enabled", true)))
	var cargo: String = String(worker.get("carrying", ""))
	var after: String = "Pak počkám na obnovení práce." if paused else "Potom se podívám po dalším volném úkolu."
	if int(worker.get("meal_ticks_left", 0)) > 0:
		var course: Dictionary = worker.get("meal_course", {})
		var meal: String = "Jím %s v hostinci." % _ware(String(course.get("food", ""))) if not course.is_empty() else "Dokončuji jídlo v hostinci."
		return _result(meal, _after_meal(world, worker, paused))
	var plan: Dictionary = {}
	if action == "eat":
		if destination.is_empty():
			return _missing_target()
		plan = _result("Jdu se najíst %s." % _place(destination, 0), "Až se dostanu k jídlu, najím se.")
	elif action == "yield":
		plan = _result("Uhýbám, abych uvolnil cestu.", after)
	elif action == "pause_return":
		plan = _result("Vracím se %s odpočívat během přestávky." % _place(destination if not destination.is_empty() else home, 0), "Až dorazím, počkám na obnovení práce.")
	elif action == "leave_building":
		plan = _result("Chystám se vyjít z budovy.", after)
	elif action == "deliver_ration" and not cargo.is_empty():
		plan = _result("Nesu %s %s." % [_ware(cargo), _recipient(world, worker)], "Až se k němu dostanu, předám mu jídlo.")
	elif not cargo.is_empty():
		if action.begins_with("deliver_") and not destination.is_empty():
			plan = _result("Nesu %s %s." % [_ware(cargo), _place(destination, 0)], after)
		else:
			return _result("Držím %s a zatím nemám kam náklad vyložit." % _ware(cargo), "Až najdu dostupné místo, zkusím tam náklad odnést.")
	elif paused:
		if int(worker.get("move_cooldown", 0)) > 0 or int(worker.get("visual_progress_ticks", 0)) < int(worker.get("visual_duration_ticks", 0)):
			return _result("Dokončuji poslední krok, než přeruším práci.", after)
		if _needs_ration(world, worker):
			return _ration_thought(worker, true)
		if _hungry(world, worker):
			return _result("Mám hlad, i když je moje práce pozastavená.", "Pokud najdu dostupný hostinec s jídlem, zkusím se najíst.")
		return _result("Čekám, protože mám pozastavenou práci." if not bool(worker.get("enabled", true)) else "Čekám; moje pracoviště má pozastavený provoz.", "Až práci znovu povolíš, zkusím pokračovat.")
	elif action == "pickup_ration":
		if source.is_empty():
			return _missing_target()
		var mission: Dictionary = worker.get("ration_delivery", {})
		plan = _result("Jdu vyzvednout %s %s." % [_ware(String(mission.get("ware", ""))), _place(source, 2)], "Pokud porci převezmu, odnesu ji %s." % _recipient(world, worker))
	elif action.begins_with("pickup_"):
		if source.is_empty():
			return _missing_target()
		plan = _result("Jdu vyzvednout %s %s." % [_ware(action.trim_prefix("pickup_")), _place(source, 2)], "Po převzetí nákladu vyberu dostupné místo pro doručení.")
	elif action == "harvest":
		if not world.trees.has(int(worker.get("source_id", 0))):
			return _missing_target()
		plan = _result("Kácím strom." if state == "working" else "Jdu ke stromu, který mám vybraný.",
			"Kládu pak zkusím odnést %s." % _place(home, 0) if state == "working" else "Až dojdu ke stromu, začnu kácet.")
	elif action == "harvest_deposit":
		var deposit: Dictionary = world.deposits.get(int(worker.get("source_id", 0)), {})
		if deposit.is_empty() or int(deposit.get("amount", 0)) <= 0:
			return _missing_target()
		var fishing: bool = deposit.get("resource", "") == "fish"
		plan = _result(("Chytám ryby." if fishing else "Těžím %s." % _ware(String(deposit.get("resource", "")))) if state == "working" else ("Jdu na vybrané místo k rybolovu." if fishing else "Jdu k vybranému ložisku."),
			"Získaný náklad pak zkusím odnést %s." % _place(home, 0) if state == "working" else "Až dorazím, zkusím získat další suroviny.")
	elif action == "plant_sapling":
		plan = _result("Sázím nový stromek." if state == "working" else "Jdu na místo vybrané pro nový stromek.", "Až stromek zasadím, po chvíli se podívám po dalším vhodném místě.")
	elif action in ["sow_field", "harvest_field"]:
		var field: Dictionary = world.fields.get(int(worker.get("source_id", 0)), {})
		if field.is_empty():
			return _missing_target()
		var task: String = "Seji obilí." if action == "sow_field" else ("Sklízím hrozny." if field.get("kind", "wheat") == "vine" else "Sklízím obilí.")
		plan = _result(task if state == "working" else "Jdu na pole, které mám přidělené.", "Po zasetí se podívám po další práci." if action == "sow_field" else "Úrodu pak zkusím odnést %s." % _place(home, 0))
	elif action == "operate":
		if source.is_empty():
			return _missing_target()
		plan = _result("Pracuji %s na rozpracované výrobě." % _place(source, 1) if state == "working" else "Jdu pracovat %s." % _place(source, 0), "Až dokončím tuhle várku, podívám se po další práci.")
	elif action == "build_site":
		if source.is_empty():
			return _missing_target()
		if not bool(source.get("enabled", true)):
			return _result("Čekám u pozastavené stavby.", "Po uvolnění úkolu se podívám po jiné dostupné práci.")
		plan = _result(("Připravuji terén pro stavbu." if int(source.get("foundation_work_remaining", 0)) > 0 else "Pracuji na stavbě budovy.") if state == "working" else "Jdu na přidělené staveniště.", "Až bude stavba hotová, podívám se po další práci.")
	elif action == "report_barracks":
		plan = _result("Jdu se hlásit %s." % _place(destination, 0), "Až dorazím, zaujmu přidělené místo.")
	if not plan.is_empty():
		if world.is_worker_inside(worker) and state == "moving" and _door_blocked(world, worker):
			return _result("Čekám uvnitř, až se uvolní dveře.", "Až budu moci vyjít, zkusím pokračovat v naplánované cestě.")
		if state == "moving" and int(worker.get("blocked_ticks", 0)) > 0:
			return _result("Čekám, protože mám zablokovanou cestu.", "Až se cesta uvolní, zkusím pokračovat ve svém úkolu.")
		return plan
	return _idle(world, worker, home)


static func _idle(world: Variant, worker: Dictionary, home: Dictionary) -> Dictionary:
	if _needs_ration(world, worker):
		return _ration_thought(worker)
	if _hungry(world, worker):
		if world.tick < int(worker.get("_meal_retry_until", 0)):
			return _result("Zatím se mi nepodařilo dostat k jídlu.", "Za chvíli zkusím najít dostupný hostinec znovu.")
		return _result("Mám hlad a potřebuji se najíst.", "Pokud najdu dostupný hostinec s jídlem, zkusím tam dojít.")
	if not home.is_empty():
		if worker.get("type", "") == "recruit" and home.get("type", "") == "watchtower" and int(worker.get("inside_building_id", 0)) == int(home["id"]):
			return _result("Hlídám ze strážní věže.", "Zůstanu na svém přiděleném místě.")
		var definition: Dictionary = world.catalog.building(String(home["type"]))
		for ware: String in definition.get("outputs", []):
			if int(home.get("outputs", {}).get(ware, 0)) >= int(definition.get("output_capacity", 6)):
				return _result("Na pracovišti už mám plné zásoby.", "Až nosič odveze část zásob, zkusím pokračovat v práci.")
		var recipe: Dictionary = world.catalog.recipe(String(home.get("recipe_id", "")))
		if int(home.get("process_remaining", 0)) == 0:
			for ware: String in recipe.get("inputs", {}):
				if int(home.get("inputs", {}).get(ware, 0)) < int(recipe["inputs"][ware]):
					return _result("Čekám na suroviny pro výrobu.", "Až budu mít potřebné zásoby, zkusím zahájit další várku.")
	elif worker.get("type", "") != "recruit" and not (world.catalog.unit(String(worker.get("type", ""))).get("home_buildings", []) as Array).is_empty():
		return _result("Zatím nemám vlastní pracoviště.", "Až bude vhodná budova volná a dostupná, zkusím se k ní přidělit.")
	if int(worker.get("planting_cooldown", 0)) > 0:
		return _result("Chvíli odpočívám mezi sázením stromků.", "Až si odpočinu, zkusím najít další vhodné místo.")
	if int(worker.get("move_cooldown", 0)) > 0 or int(worker.get("visual_progress_ticks", 0)) < int(worker.get("visual_duration_ticks", 0)):
		return _result("Dokončuji poslední krok.", "Pak se podívám po dalším volném úkolu.")
	if worker.get("state", "") == "moving":
		return _result("Jdu k určenému místu.", "Až dorazím, zařídím se podle dalšího úkolu.")
	return _result("Právě nemám přidělený úkol.", "Až najdu vhodnou dostupnou práci, pustím se do ní.")


static func _inspectable(world: Variant, worker: Dictionary) -> bool:
	if worker.is_empty() or not world.workers.has(int(worker.get("id", 0))) or not world.is_local_entity(worker):
		return false
	if not world.fog.enabled:
		return true
	if world.is_worker_inside(worker):
		var inside: Dictionary = _building(world, worker.get("inside_building_id", 0))
		return not inside.is_empty() and world.is_local_entity(inside) and world.is_entity_visible(inside)
	return world.is_entity_visible(worker)


static func _after_meal(world: Variant, worker: Dictionary, paused: bool) -> String:
	if not String(worker.get("carrying", "")).is_empty():
		return "Po jídle zkusím doručit náklad, který stále nesu."
	if paused:
		return "Po jídle počkám na obnovení práce."
	if worker.get("type", "") == "recruit":
		var home: Dictionary = _building(world, worker.get("home_id", 0))
		return "Po jídle se zkusím vrátit %s." % _place(home, 0) if not home.is_empty() else "Po jídle se podívám po svém dalším úkolu."
	return "Po jídle se podívám po své práci."


static func _door_blocked(world: Variant, worker: Dictionary) -> bool:
	var cell: Vector2i = worker["position"]
	return int(world.tile_reservations.get(cell, 0)) != 0 or world._yielding_origins.has(cell) or world.planting_reservations.has(cell)


static func _hungry(world: Variant, worker: Dictionary) -> bool:
	return world.economy_enabled and int(worker.get("hunger", 2700)) <= int(world.catalog.economy.get("condition_hungry", 360))


static func _needs_ration(world: Variant, worker: Dictionary) -> bool:
	return world.economy_enabled and world.catalog.soldiers.has(String(worker.get("type", ""))) \
		and (bool(worker.get("food_requested", false)) or _hungry(world, worker))


static func _ration_thought(worker: Dictionary, paused: bool = false) -> Dictionary:
	var requested: bool = bool(worker.get("food_requested", false))
	var current: String = "Čekám na objednané jídlo." if requested else "Mám hlad a čekám na rozkaz k zásobování."
	if paused:
		current += " Práci mám pozastavenou."
	return _result(current, "Až mi nosič přinese příděl, najím se." if requested else "Po rozkazu k zásobování počkám na přinesený příděl.")


static func _recipient(world: Variant, worker: Dictionary) -> String:
	var mission: Dictionary = worker.get("ration_delivery", {})
	var recipient: Dictionary = world.workers.get(int(mission.get("recipient_id", 0)), {})
	return "vojákovi č. %d" % int(recipient["id"]) if not recipient.is_empty() and world.is_local_entity(recipient) else "vojákovi"


static func _building(world: Variant, id: Variant) -> Dictionary:
	return world.buildings.get(int(id), {})


static func _ware(id: String) -> String:
	return String(WARES.get(id, "náklad"))


static func _place(building: Dictionary, form: int) -> String:
	return String(PLACES.get(String(building.get("type", "")), ["do budovy", "v budově", "z budovy"])[form])


static func _result(current: String, next: String) -> Dictionary:
	return {"current": current, "next": next}


static func _missing_target() -> Dictionary:
	return _result("Můj původní cíl už není dostupný.", "Nejdřív budu muset znovu vybrat vhodnou práci.")
