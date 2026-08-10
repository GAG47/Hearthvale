class_name InteractionTargetSelector
extends RefCounted

static func select_target(actor: CharacterPresentation) -> WorldObject:
	if not is_instance_valid(actor) or not is_instance_valid(actor.current_location):
		return null

	var query_cells: Array[Vector2i] = [actor.get_front_cell(), actor.current_cell]
	for cell in query_cells:
		var selected := _select_supported_object(
			actor.character,
			actor.current_location.get_world_objects_at(cell)
		)
		if selected != null:
			return selected

	return null


static func _select_supported_object(actor: Character, candidates: Array[WorldObject]) -> WorldObject:
	var selected: WorldObject
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		if candidate.get_supported_actions(actor).is_empty():
			continue
		if selected == null or String(candidate.object_id) < String(selected.object_id):
			selected = candidate
	return selected
