class_name InteractionTargetSelector
extends RefCounted

static func select_target(actor: Actor) -> Entity:
	if actor == null:
		return null
	var location_space := _get_location_space()
	if location_space == null or not location_space.has_location(actor.current_location_id):
		return null
	var location := location_space.get_location(actor.current_location_id)
	var selected: Entity
	for candidate in location.get_entities_in_location():
		if candidate == actor:
			continue
		for action_id in candidate.get_supported_actions(actor):
			if location.is_actor_at_valid_use_slot(actor, candidate, action_id):
				if selected == null or String(candidate.entity_id) < String(selected.entity_id):
					selected = candidate
				break
	return selected


static func _get_location_space() -> LocationSpaceRuntime:
	var tree := Engine.get_main_loop() as SceneTree
	return (
		tree.root.get_node_or_null("LocationSpace") as LocationSpaceRuntime
		if tree != null
		else null
	)
