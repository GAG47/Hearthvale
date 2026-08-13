@abstract
class_name EntityFactory
extends RefCounted


@abstract func supports(entity_type: StringName) -> bool


@abstract func create(entity_data: Dictionary) -> Entity


func read_non_empty_string(entity_data: Dictionary, field: String) -> String:
	if not entity_data.has(field) or not entity_data[field] is String:
		push_error("Entity creation field '%s' must be a String." % field)
		return ""
	var value: String = entity_data[field]
	if value.strip_edges().is_empty():
		push_error("Entity creation field '%s' must not be empty." % field)
		return ""
	return value


func read_local_position(entity_data: Dictionary) -> Variant:
	if not entity_data.has("local_position") or not entity_data["local_position"] is Array:
		push_error("Entity creation field 'local_position' must be an Array.")
		return null
	var values: Array = entity_data["local_position"]
	if values.size() != 2 or not _is_number(values[0]) or not _is_number(values[1]):
		push_error("Entity creation field 'local_position' requires two finite numbers.")
		return null
	var position := Vector2(float(values[0]), float(values[1]))
	if not is_finite(position.x) or not is_finite(position.y):
		push_error("Entity creation field 'local_position' requires two finite numbers.")
		return null
	return position


func _is_number(value: Variant) -> bool:
	return value is int or value is float
