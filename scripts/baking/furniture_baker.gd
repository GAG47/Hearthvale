class_name FurnitureBaker
extends EntityBaker


func supports(placement: EntityPlacement) -> bool:
	return placement is FurniturePlacement


func bake(placement: EntityPlacement, location_id: StringName) -> Dictionary:
	if not placement is FurniturePlacement:
		push_error("FurnitureBaker requires a FurniturePlacement.")
		return {}
	var furniture_placement := placement as FurniturePlacement
	if furniture_placement.definition_path.strip_edges().is_empty():
		push_error(
			"FurniturePlacement '%s' requires a non-empty definition_path."
			% placement.name
		)
		return {}
	if location_id.is_empty():
		push_error("FurniturePlacement '%s' requires a valid Location ID." % placement.name)
		return {}
	if not _is_valid_position(furniture_placement.position):
		push_error("FurniturePlacement '%s' has an invalid local position." % placement.name)
		return {}
	if FurnitureDefinitionLoader.load_from_file(furniture_placement.definition_path) == null:
		push_error(
			"FurniturePlacement '%s' could not load FurnitureDefinition '%s'."
			% [placement.name, furniture_placement.definition_path]
		)
		return {}

	return {
		"entity_type": "furniture",
		"definition_path": furniture_placement.definition_path,
		"location_id": String(location_id),
		"local_position": [
			furniture_placement.position.x,
			furniture_placement.position.y,
		],
	}


static func _is_valid_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
