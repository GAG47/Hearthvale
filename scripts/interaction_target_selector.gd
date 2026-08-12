class_name InteractionTargetSelector
extends RefCounted

static func select_target(actor_presentation: ActorPresentation) -> Entity:
	if not is_instance_valid(actor_presentation) or not is_instance_valid(actor_presentation.current_location):
		return null

	var query_cells: Array[Vector2i] = [
		actor_presentation.get_front_cell(),
		actor_presentation.current_cell,
	]
	for cell in query_cells:
		var selected := _select_supported_entity(
			actor_presentation.actor,
			actor_presentation.current_location.get_furniture_presentations_at(cell)
		)
		if selected != null:
			return selected

	return null


static func _select_supported_entity(
	actor: Actor,
	candidates: Array[FurniturePresentation]
) -> Entity:
	var selected: Furniture
	for presentation in candidates:
		if not is_instance_valid(presentation) or presentation.furniture == null:
			continue
		var candidate := presentation.furniture
		if candidate.get_supported_actions(actor).is_empty():
			continue
		if selected == null or String(candidate.entity_id) < String(selected.entity_id):
			selected = candidate
	return selected
