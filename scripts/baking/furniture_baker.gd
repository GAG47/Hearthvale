class_name FurnitureBaker
extends EntityBaker


func supports(placement: EntityPlacement) -> bool:
	return placement is FurniturePlacement


func bake(placement: EntityPlacement, location_id: StringName) -> Dictionary:
	if not placement is FurniturePlacement:
		push_error("FurnitureBaker requires a FurniturePlacement.")
		return {}
	var furniture_placement := placement as FurniturePlacement
	if furniture_placement.definition == null:
		push_error("FurniturePlacement '%s' requires a FurnitureDefinition Resource." % placement.name)
		return {}
	var definition_warnings := furniture_placement.definition.get_validation_warnings()
	if not definition_warnings.is_empty():
		push_error(
			"FurniturePlacement '%s' has an invalid Definition: %s"
			% [placement.name, definition_warnings[0]]
		)
		return {}
	if location_id.is_empty():
		push_error("FurniturePlacement '%s' requires a valid Location ID." % placement.name)
		return {}
	if not _is_valid_position(furniture_placement.position):
		push_error("FurniturePlacement '%s' has an invalid local position." % placement.name)
		return {}
	var definition_uid := _get_resource_uid(furniture_placement.definition)
	if definition_uid.is_empty():
		push_error("FurniturePlacement '%s' Definition requires a stable ResourceUID." % placement.name)
		return {}

	return {
		"entity_type": "furniture",
		"definition_uid": definition_uid,
		"location_id": String(location_id),
		"local_position": [
			furniture_placement.position.x,
			furniture_placement.position.y,
		],
	}


static func _get_resource_uid(resource: Resource) -> String:
	if resource == null or resource.resource_path.is_empty():
		return ""
	var resource_id := ResourceLoader.get_resource_uid(resource.resource_path)
	if resource_id == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(resource_id)


static func _is_valid_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
