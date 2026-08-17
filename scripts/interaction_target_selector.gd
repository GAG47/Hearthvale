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

	var query_cells: Array[Vector2i] = [
		actor.get_front_cell(),
		actor.current_cell,
	]
	for cell in query_cells:
		var selected := _select_supported_entity(actor, location.get_entities_at(cell))
		if selected != null:
			return selected

	return null


static func _select_supported_entity(
	actor: Actor,
	candidates: Array[Entity]
) -> Entity:
	var selected: Entity
	for candidate in candidates:
		if candidate == null or candidate == actor:
			continue
		if candidate.get_supported_actions(actor).is_empty():
			continue
		if selected == null or String(candidate.instance_id) < String(selected.instance_id):
			selected = candidate
	return selected
