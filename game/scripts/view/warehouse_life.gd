class_name WarehouseLife
extends RefCounted

## Door state for the painted warehouse. Inventory and indoor figures are
## intentionally not part of this presentation.


func doors_open(world: Variant, building: Dictionary) -> bool:
	return world.is_building_complete(building) \
		and (not world.fog.enabled or world.is_local_entity(building))


func presentation_for(world: Variant, building: Dictionary, house: Dictionary, _tick_fraction: float = 0.0) -> Dictionary:
	var config: Dictionary = house.get("life", {})
	if house.is_empty() or config.is_empty() or not world.is_building_complete(building):
		return {}
	# An explored foreign building is only a silhouette with the neutral
	# closed-door master; its occupants are never queried.
	var known: bool = not world.fog.enabled or world.is_local_entity(building)
	return {"rect": house["rect"], "source_to_world": house["source_to_world"], "config": config,
		"known": known, "door_open": known}
