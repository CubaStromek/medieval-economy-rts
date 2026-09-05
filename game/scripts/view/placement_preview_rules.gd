extends RefCounted

# Read-only presentation of the simulation's placement rules. Never place a
# trial entity, spend stock, flatten ground, reserve a task or emit events here.
static func evaluate(world: Variant, tool: String, cell: Vector2i) -> Dictionary:
	var result: Dictionary = {"cell": cell, "tool": tool, "valid": false, "reason": "Outside the map", "height": 0.0, "slope": 0}
	if tool.is_empty() or not world.grid.contains(cell):
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
	if result["valid"]:
		result["reason"] = "Walkable slope — road can be placed" if tool == "road" and int(result["slope"]) > 0 else "Level ground — ready to place"
	return result


static func _road_reason(world: Variant, cell: Vector2i) -> String:
	if world.grid.cell_slope(cell) > world.grid.MAX_WALK_SLOPE:
		return "Too steep — roads need a walkable slope"
	if not world.grid.is_walkable(cell) or not world.grid.is_roadable(cell):
		return "Blocked terrain — a road cannot go here"
	if world.grid.roads.has(cell):
		return "A stone road is already here"
	var occupied: String = _occupied_reason(world, cell)
	if not occupied.is_empty():
		return occupied
	if world.economy_enabled:
		return _stock_shortfall(world, world.catalog.economy.get("road_cost", {"stone": 1}))
	return ""


static func _site_reason(world: Variant, tool: String, cell: Vector2i) -> String:
	if world.grid.cell_slope(cell) > world.grid.MAX_BUILD_SLOPE:
		return "Slope — requires level ground"
	if not world.grid.is_buildable(cell):
		return "Occupied by a building" if world.building_id_at(cell) != 0 else "Blocked terrain — cannot build here"
	var occupied: String = _occupied_reason(world, cell)
	if not occupied.is_empty():
		return occupied
	for building: Dictionary in world.buildings.values():
		if building["entrance"] == cell:
			return "Keep this building entrance clear"
	if tool in ["field", "vine_field"]:
		if not world.grid.overlay_at(cell).is_empty():
			return "Fields need ground without a road or trail"
		return "Fields need clear, level grass or dirt"
	var definition: Dictionary = world.catalog.building(tool)
	if definition.is_empty():
		return "Choose a building tool"
	var allowed: Array = definition.get("allowed_terrain", [])
	if not allowed.is_empty() and not allowed.has(world.grid.base_terrain_at(cell)):
		return "This building needs a different terrain type"
	if world._find_entrance(cell) == Vector2i(-1, -1):
		return "No accessible entrance beside this site"
	var nearby: String = String(definition.get("nearby_terrain", ""))
	if not world._building_terrain_valid(tool, cell) and not nearby.is_empty():
		return "Requires %s within %d tiles" % [nearby, int(definition.get("terrain_radius", 0))]
	var resource: String = String(definition.get("extract_resource", ""))
	if not resource.is_empty():
		var resource_name: String = String(world.catalog.resources.get(resource, {}).get("display_name", resource))
		return "Needs a nearby reachable %s deposit" % resource_name
	return "This site is unavailable — choose clear, level ground"


static func _occupied_reason(world: Variant, cell: Vector2i) -> String:
	if world._tree_at(cell) != 0:
		return "A tree occupies this tile"
	if world.field_id_at(cell) != 0:
		return "A field occupies this tile"
	if world.deposit_id_at(cell) != 0:
		return "A resource deposit occupies this tile"
	if world.tile_reservations.has(cell):
		return "A citizen is on this tile — wait until it is clear"
	if world.planting_reservations.has(cell):
		return "A gardener has reserved this tile"
	return ""


static func _stock_shortfall(world: Variant, cost: Dictionary) -> String:
	for resource: String in cost:
		var required: int = int(cost[resource])
		if world.stored_amount(resource) < required:
			var display_name: String = String(world.catalog.resources.get(resource, {}).get("display_name", resource))
			return "Needs %d %s in warehouse stock" % [required, display_name]
	return ""
