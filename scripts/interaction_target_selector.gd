class_name InteractionTargetSelector
extends RefCounted

static func select_target(actor_representation: ActorRepresentation) -> Entity:
	if not is_instance_valid(actor_representation) or not is_instance_valid(actor_representation.current_location):
		return null

	var query_cells: Array[Vector2i] = [
		actor_representation.get_front_cell(),
		actor_representation.current_cell,
	]
	for cell in query_cells:
		var selected := _select_supported_entity(
			actor_representation.get_entity() as Actor,
			actor_representation.current_location.get_furniture_representations_at(cell)
		)
		if selected != null:
			return selected

	return null


static func _select_supported_entity(
	actor: Actor,
	candidates: Array[FurnitureRepresentation]
) -> Entity:
	var selected: Furniture
	for representation in candidates:
		if not is_instance_valid(representation):
			continue
		var candidate_entity := representation.get_entity()
		if not candidate_entity is Furniture:
			continue
		var candidate := candidate_entity as Furniture
		if candidate.get_supported_actions(actor).is_empty():
			continue
		if selected == null or String(candidate.instance_id) < String(selected.instance_id):
			selected = candidate
	return selected
