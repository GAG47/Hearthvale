class_name ActorBaker
extends EntityBaker


func supports(placement: EntityPlacement) -> bool:
	return placement is ActorPlacement


func bake(placement: EntityPlacement, location_id: StringName) -> Dictionary:
	if not placement is ActorPlacement:
		push_error("ActorBaker requires an ActorPlacement.")
		return {}
	var actor_placement := placement as ActorPlacement
	if actor_placement.definition == null:
		push_error("ActorPlacement '%s' requires an ActorDefinition Resource." % placement.name)
		return {}
	var definition_warnings := actor_placement.definition.get_validation_warnings()
	if not definition_warnings.is_empty():
		push_error("ActorPlacement '%s' has an invalid Definition: %s" % [placement.name, definition_warnings[0]])
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
	var definition_uid := _get_resource_uid(actor_placement.definition)
	if definition_uid.is_empty():
		push_error("ActorPlacement '%s' Definition requires a stable ResourceUID." % placement.name)
		return {}

	return {
		"entity_type": "actor",
		"definition_uid": definition_uid,
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


static func _get_resource_uid(resource: Resource) -> String:
	if resource == null or resource.resource_path.is_empty():
		return ""
	var resource_id := ResourceLoader.get_resource_uid(resource.resource_path)
	if resource_id == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(resource_id)


static func _is_valid_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
