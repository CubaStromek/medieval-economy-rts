extends RefCounted
const UiTextClass = preload("res://scripts/ui_text.gd")


# Read-only presentation of the simulation's placement rules. Never place a
# trial entity, spend stock, flatten ground, reserve a task or emit events here.
static func evaluate(world: Variant, tool: String, cell: Vector2i) -> Dictionary:
	var result: Dictionary = {"cell": cell, "tool": tool, "valid": false, "reason": "Mimo mapu", "height": 0.0, "slope": 0, "cells": [cell], "entrance": Vector2i(-1, -1)}
	if tool not in ["", "road", "field", "vine_field"]:
		result["cells"] = world.placement_cells(tool, cell)
		result["entrance"] = world.placement_entrance(tool, cell)
	if tool.is_empty() or not world.grid.contains(cell):
		return result
	var required: Array = (result["cells"] as Array).duplicate()
	if world.grid.contains(result["entrance"]):
		required.append(result["entrance"])
	for required_cell: Vector2i in required:
		if world.grid.contains(required_cell) and not world.is_cell_explored(required_cell):
			result["reason"] = "Neprozkoumaná oblast — nejdřív sem pošli jednotku"
			result["obscured"] = true
			result["cells"] = []
			result["entrance"] = Vector2i(-1, -1)
			return result
	result["height"] = world.grid.cell_height(cell)
	result["slope"] = world.grid.cell_slope(cell)
	if tool == "road":
		result["reason"] = _road_reason(world, cell)
		result["valid"] = String(result["reason"]).is_empty()
	elif tool in ["field", "vine_field"]:
		result["valid"] = world.can_place_field(cell, "vine" if tool == "vine_field" else "wheat")
		if result["valid"] and tool == "vine_field" and world.economy_enabled:
			result["reason"] = _stock_shortfall(world, world.catalog.economy.get("vine_field_cost", {"plank": 1}))
			result["valid"] = String(result["reason"]).is_empty()
		else:
			result["reason"] = "" if result["valid"] else _site_reason(world, tool, cell)
	else:
		# Building sites are allowed before all construction materials arrive.
		# Their resource bill is shown by the HUD, not treated as a terrain veto.
		result["valid"] = world.can_place_building(tool, cell)
		result["reason"] = "" if result["valid"] else _site_reason(world, tool, cell)
		if world.default_footprint_version > 0 and world.economy_enabled:
			var plan: Dictionary = world.foundation_plan(tool, cell)
			result["foundation_work_ticks"] = int(plan.get("work_ticks", 0))
			result["foundation_target_height"] = int(plan.get("target_height", 0))
			result["needs_levelling"] = result["valid"] and int(result["foundation_work_ticks"]) > 0
			if not bool(plan.get("valid", false)):
				result["reason"] = String(plan.get("reason", "Toto místo nelze připravit"))
	if result["valid"]:
		if bool(result.get("needs_levelling", false)):
			result["reason"] = "Stavitel místo srovná — %.1f s zemních prací" % (float(result["foundation_work_ticks"]) * world.TICK_SECONDS)
		else:
			result["reason"] = "Průchozí svah — cestu lze položit" if tool == "road" and int(result["slope"]) > 0 else "Rovná zem — lze stavět"
	return result


static func _road_reason(world: Variant, cell: Vector2i) -> String:
	if world.grid.cell_slope(cell) > world.grid.MAX_WALK_SLOPE:
		return "Příliš strmé — cesta potřebuje průchozí svah"
	if not world.grid.is_walkable(cell) or not world.grid.is_roadable(cell):
		return "Neprůchodný terén — cesta sem nevede"
	if world.grid.roads.has(cell):
		return "A stone road is already here"
	var occupied: String = _occupied_reason(world, cell)
	if not occupied.is_empty():
		return occupied
	if world.economy_enabled:
		return _stock_shortfall(world, world.catalog.economy.get("road_cost", {"stone": 1}))
	return ""


static func _site_reason(world: Variant, tool: String, cell: Vector2i) -> String:
	if tool in ["field", "vine_field"]:
		var ground_reason: String = _ground_reason(world, cell)
		if not ground_reason.is_empty():
			return ground_reason
		if not world.grid.overlay_at(cell).is_empty():
			return "Pole potřebují zem bez cesty a bez pěšiny"
		return "Pole potřebují volnou rovnou trávu nebo hlínu"
	var definition: Dictionary = world.catalog.building(tool)
	if definition.is_empty():
		return "Vyber stavební nástroj"
	var cells: Array[Vector2i] = world.placement_cells(tool, cell)
	var allowed: Array = definition.get("allowed_terrain", [])
	var site_height: float = world.grid.cell_height(cell)
	for occupied_cell: Vector2i in cells:
		if not world.grid.contains(occupied_cell):
			return "Část budovy přesahuje mimo mapu"
		var ground_reason: String = _building_ground_reason(world, occupied_cell) if world.default_footprint_version > 0 and world.economy_enabled else _ground_reason(world, occupied_cell)
		if not ground_reason.is_empty():
			return ground_reason
		if (world.default_footprint_version == 0 or not world.economy_enabled) and cells.size() > 1 and not is_equal_approx(world.grid.cell_height(occupied_cell), site_height):
			return "Nerovné místo — celá budova potřebuje rovnou zem"
		if not allowed.is_empty() and not allowed.has(world.grid.base_terrain_at(occupied_cell)):
			return "Část budovy potřebuje jiný typ terénu"
	var entrance: Vector2i = world.placement_entrance(tool, cell)
	if not world.grid.contains(entrance) or not world.grid.is_walkable(entrance):
		return "Vstup je zablokovaný — modré pole před vchodem musí být dostupné"
	if world.building_id_at(entrance) != 0 or world._tree_at(entrance) != 0 or world.field_id_at(entrance) != 0 or world.deposit_id_at(entrance) != 0:
		return "Vstup je zablokovaný — modré pole před vchodem musí být volné"
	var nearby: String = String(definition.get("nearby_terrain", ""))
	if not world._building_terrain_valid(tool, cell) and not nearby.is_empty():
		return "Potřebuje v okolí %s do %s" % [UiTextClass.terrain_name(nearby).to_lower(), UiTextClass.tiles(int(definition.get("terrain_radius", 0)))]
	var resource: String = String(definition.get("extract_resource", ""))
	if not resource.is_empty():
		return "Potřebuje poblíž dostupné ložisko: %s" % UiTextClass.resource_name(world.catalog, resource)
	return "Toto místo není k dispozici — vyber volnou zem s dostupným vstupem"


static func _building_ground_reason(world: Variant, cell: Vector2i) -> String:
	if world.building_id_at(cell) != 0:
		return "Obsazeno budovou"
	if not bool(world.grid.terrain_definition(world.grid.base_terrain_at(cell)).get("buildable", false)):
		return "Neprůchodný terén — zde stavět nelze"
	var occupied: String = _occupied_reason(world, cell)
	if not occupied.is_empty():
		return occupied
	for building: Dictionary in world.buildings.values():
		if building["entrance"] == cell:
			return "Vstup do této budovy musí zůstat volný"
	return ""


static func _ground_reason(world: Variant, cell: Vector2i) -> String:
	if world.grid.cell_slope(cell) > world.grid.MAX_BUILD_SLOPE:
		return "Svah — celá budova potřebuje rovnou zem"
	if not world.grid.is_buildable(cell):
		return "Occupied by a building" if world.building_id_at(cell) != 0 else "Blocked terrain — cannot build here"
	var occupied: String = _occupied_reason(world, cell)
	if not occupied.is_empty():
		return occupied
	for building: Dictionary in world.buildings.values():
		if building["entrance"] == cell:
			return "Keep this building entrance clear"
	return ""


static func _occupied_reason(world: Variant, cell: Vector2i) -> String:
	if world._tree_at(cell) != 0:
		return "Na tomto poli stojí strom"
	if world.field_id_at(cell) != 0:
		return "Na tomto poli je políčko"
	if world.deposit_id_at(cell) != 0:
		return "Na tomto poli je ložisko suroviny"
	if world.tile_reservations.has(cell):
		return "Na tomto poli stojí člověk — počkej, až se uvolní"
	if world.planting_reservations.has(cell):
		return "Toto pole si rezervoval lesník"
	return ""


static func _stock_shortfall(world: Variant, cost: Dictionary) -> String:
	for resource: String in cost:
		var required: int = int(cost[resource])
		if world.stored_amount(resource) < required:
			return "Ve skladu chybí %s" % UiTextClass.resource_amount(resource, required)
	return ""
