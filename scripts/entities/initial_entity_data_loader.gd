class_name InitialEntityDataLoader
extends RefCounted

const SCHEMA_VERSION := 1


static func load_from_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error(
			"InitialEntityDataLoader failed to open '%s': %s."
			% [path, error_string(FileAccess.get_open_error())]
		)
		return null
	var json_text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		push_error(
			"InitialEntityDataLoader failed to read '%s': %s."
			% [path, error_string(read_error)]
		)
		return null

	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK:
		push_error(
			"InitialEntityDataLoader failed to parse '%s' at line %d: %s."
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return null
	var parsed_data: Variant = parser.data
	if not parsed_data is Dictionary:
		push_error("Initial Entity Data '%s' requires a Dictionary root." % path)
		return null
	var root_data: Dictionary = parsed_data
	if root_data.get("schema_version") != SCHEMA_VERSION:
		push_error(
			"Initial Entity Data '%s' requires schema_version %d."
			% [path, SCHEMA_VERSION]
		)
		return null
	if not root_data.has("entities") or not root_data["entities"] is Array:
		push_error("Initial Entity Data '%s' field 'entities' must be an Array." % path)
		return null

	var entities: Array[Dictionary] = []
	var raw_entities: Array = root_data["entities"]
	for index in range(raw_entities.size()):
		var raw_entity: Variant = raw_entities[index]
		if not raw_entity is Dictionary:
			push_error("Initial Entity Data '%s' entities[%d] must be a Dictionary." % [path, index])
			return null
		var entity_data: Dictionary = raw_entity
		if not _validate_common_fields(entity_data, path, index):
			return null
		entities.append(entity_data.duplicate(true))
	return entities


static func _validate_common_fields(
	entity_data: Dictionary,
	path: String,
	index: int
) -> bool:
	for field in ["entity_type", "definition_path", "location_id"]:
		if not entity_data.has(field) or not entity_data[field] is String:
			push_error(
				"Initial Entity Data '%s' entities[%d].%s must be a String."
				% [path, index, field]
			)
			return false
		var value: String = entity_data[field]
		if value.strip_edges().is_empty():
			push_error(
				"Initial Entity Data '%s' entities[%d].%s must not be empty."
				% [path, index, field]
			)
			return false
	if not entity_data.has("local_position") or not entity_data["local_position"] is Array:
		push_error(
			"Initial Entity Data '%s' entities[%d].local_position must be an Array."
			% [path, index]
		)
		return false
	var position_values: Array = entity_data["local_position"]
	if (
		position_values.size() != 2
		or not _is_number(position_values[0])
		or not _is_number(position_values[1])
		or not is_finite(float(position_values[0]))
		or not is_finite(float(position_values[1]))
	):
		push_error(
			"Initial Entity Data '%s' entities[%d].local_position requires two finite numbers."
			% [path, index]
		)
		return false
	return true


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
