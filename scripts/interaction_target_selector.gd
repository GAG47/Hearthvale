class_name InteractionTargetSelector
extends RefCounted

static func select_target(actor: Actor) -> Entity:
	if actor == null or actor.current_location_id.is_empty():
		return null
	var world_definition := Engine.get_main_loop().root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	if world_definition == null:
		return null
	var location := world_definition.get_location(actor.current_location_id)
	if location == null:
		return null

	return _select_supported_entity(actor, location)


static func _select_supported_entity(
	actor: Actor,
	location: LocationRuntime
) -> Entity:
	var selected: Entity
	for candidate in location.get_entities():
		if candidate == null or candidate == actor:
			continue
		var has_matching_slot := false
		for action_id in candidate.get_supported_actions(actor):
			if candidate.has_facing_use_slot_at(action_id, actor.current_cell, actor.facing):
				has_matching_slot = true
				break
			if has_matching_slot:
				break
		if not has_matching_slot:
			continue
		if selected == null or String(candidate.instance_id) < String(selected.instance_id):
			selected = candidate
	return selected
