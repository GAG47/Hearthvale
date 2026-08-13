class_name ActorBaker
extends EntityBaker


func supports(placement: EntityPlacement) -> bool:
	return placement is ActorPlacement


func bake(placement: EntityPlacement, location_id: StringName) -> Dictionary:
	if not placement is ActorPlacement:
		push_error("ActorBaker requires an ActorPlacement.")
		return {}
	var actor_placement := placement as ActorPlacement
	if actor_placement.definition_path.strip_edges().is_empty():
		push_error("ActorPlacement '%s' requires a non-empty definition_path." % placement.name)
		return {}
	if location_id.is_empty():
		push_error("ActorPlacement '%s' requires a valid Location ID." % placement.name)
		return {}
	if not _is_valid_position(actor_placement.position):
		push_error("ActorPlacement '%s' has an invalid local position." % placement.name)
		return {}
	var facing_name := _facing_to_string(actor_placement.initial_facing)
	if facing_name.is_empty():
		push_error("ActorPlacement '%s' has an invalid initial_facing." % placement.name)
		return {}
	if ActorDefinitionLoader.load_from_file(actor_placement.definition_path) == null:
		push_error(
			"ActorPlacement '%s' could not load ActorDefinition '%s'."
			% [placement.name, actor_placement.definition_path]
		)
		return {}

	return {
		"entity_type": "actor",
		"definition_path": actor_placement.definition_path,
		"location_id": String(location_id),
		"local_position": [actor_placement.position.x, actor_placement.position.y],
		"initial_facing": facing_name,
	}


static func _facing_to_string(facing: ActorState.Facing) -> String:
	match facing:
		ActorState.Facing.UP:
			return "up"
		ActorState.Facing.DOWN:
			return "down"
		ActorState.Facing.LEFT:
			return "left"
		ActorState.Facing.RIGHT:
			return "right"
		_:
			return ""


static func _is_valid_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
