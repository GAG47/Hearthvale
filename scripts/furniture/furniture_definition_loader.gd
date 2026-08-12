class_name FurnitureDefinitionLoader
extends RefCounted

const SUPPORTED_BEHAVIORS: Array[String] = ["sleepable", "openable", "inspectable"]


static func load_from_file(path: String) -> FurnitureDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error(
			"FurnitureDefinitionLoader failed to open '%s': %s."
			% [path, error_string(open_error)]
		)
		return null

	var json_text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		push_error(
			"FurnitureDefinitionLoader failed to read '%s': %s."
			% [path, error_string(read_error)]
		)
		return null

	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK:
		push_error(
			"FurnitureDefinitionLoader failed to parse '%s' at line %d: %s."
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return null

	var parsed_data: Variant = parser.data
	if not parsed_data is Dictionary:
		push_error("FurnitureDefinitionLoader expected a Dictionary root in '%s'." % path)
		return null
	var data: Dictionary = parsed_data

	var definition_id := _read_non_empty_string(data, "definition_id", path)
	var display_name := _read_non_empty_string(data, "display_name", path)
	var visual_ref := _read_texture_path(data, "visual_ref", path)
	if definition_id.is_empty() or display_name.is_empty() or visual_ref.is_empty():
		return null

	if not data.has("behaviors") or not data["behaviors"] is Dictionary:
		push_error("FurnitureDefinitionLoader '%s' field 'behaviors' must be a Dictionary." % path)
		return null
	var behaviors_data: Dictionary = data["behaviors"]
	var validated_behaviors: Variant = _validate_behaviors(behaviors_data, path)
	if not validated_behaviors is Dictionary:
		return null
	var behaviors: Dictionary = validated_behaviors

	var occupied_cells := _read_occupied_cells(data, path)
	if occupied_cells == Vector2i.ZERO:
		return null
	if not data.has("blocks_movement") or not data["blocks_movement"] is bool:
		push_error("FurnitureDefinitionLoader '%s' field 'blocks_movement' must be a bool." % path)
		return null
	var blocks_movement: bool = data["blocks_movement"]

	return FurnitureDefinition.new(
		StringName(definition_id),
		display_name,
		visual_ref,
		behaviors,
		occupied_cells,
		blocks_movement
	)


static func _validate_behaviors(behaviors_data: Dictionary, path: String) -> Variant:
	var behaviors: Dictionary = {}
	for raw_behavior_id: Variant in behaviors_data.keys():
		if not raw_behavior_id is String:
			push_error("FurnitureDefinitionLoader '%s' behavior IDs must be Strings." % path)
			return null
		var behavior_id: String = raw_behavior_id
		if not SUPPORTED_BEHAVIORS.has(behavior_id):
			push_error(
				"FurnitureDefinitionLoader '%s' has unsupported behavior '%s'."
				% [path, behavior_id]
			)
			return null
		var raw_config: Variant = behaviors_data[behavior_id]
		if not raw_config is Dictionary:
			push_error(
				"FurnitureDefinitionLoader '%s' behavior '%s' config must be a Dictionary."
				% [path, behavior_id]
			)
			return null
		var config: Dictionary = raw_config
		match behavior_id:
			"openable":
				var open_visual_ref := _read_texture_path(
					config, "open_visual_ref", "%s behaviors.openable" % path
				)
				if open_visual_ref.is_empty():
					return null
				behaviors[behavior_id] = {"open_visual_ref": open_visual_ref}
			"inspectable":
				var text := _read_non_empty_string(
					config, "text", "%s behaviors.inspectable" % path
				)
				if text.is_empty():
					return null
				behaviors[behavior_id] = {"text": text}
			_:
				behaviors[behavior_id] = {}
	return behaviors


static func _read_non_empty_string(data: Dictionary, field: String, path: String) -> String:
	if not data.has(field):
		push_error("FurnitureDefinitionLoader '%s' is missing '%s'." % [path, field])
		return ""
	var raw_value: Variant = data[field]
	if not raw_value is String:
		push_error("FurnitureDefinitionLoader '%s' field '%s' must be a String." % [path, field])
		return ""
	var value: String = raw_value
	if value.strip_edges().is_empty():
		push_error("FurnitureDefinitionLoader '%s' field '%s' must not be empty." % [path, field])
		return ""
	return value


static func _read_texture_path(data: Dictionary, field: String, path: String) -> String:
	var resource_path := _read_non_empty_string(data, field, path)
	if resource_path.is_empty():
		return ""
	if not ResourceLoader.exists(resource_path):
		push_error(
			"FurnitureDefinitionLoader '%s' field '%s' points to a missing resource: '%s'."
			% [path, field, resource_path]
		)
		return ""
	var resource := ResourceLoader.load(resource_path)
	if not resource is Texture2D:
		push_error(
			"FurnitureDefinitionLoader '%s' field '%s' must reference a Texture2D: '%s'."
			% [path, field, resource_path]
		)
		return ""
	return resource_path


static func _read_occupied_cells(data: Dictionary, path: String) -> Vector2i:
	if not data.has("occupied_cells") or not data["occupied_cells"] is Array:
		push_error("FurnitureDefinitionLoader '%s' field 'occupied_cells' must be an Array." % path)
		return Vector2i.ZERO
	var raw_cells: Array = data["occupied_cells"]
	if raw_cells.size() != 2:
		push_error("FurnitureDefinitionLoader '%s' field 'occupied_cells' requires two values." % path)
		return Vector2i.ZERO
	var width := _read_positive_integer(raw_cells[0])
	var height := _read_positive_integer(raw_cells[1])
	if width <= 0 or height <= 0:
		push_error("FurnitureDefinitionLoader '%s' field 'occupied_cells' requires positive integers." % path)
		return Vector2i.ZERO
	return Vector2i(width, height)


static func _read_positive_integer(raw_value: Variant) -> int:
	if raw_value is int:
		return raw_value if raw_value > 0 else 0
	if raw_value is float:
		return int(raw_value) if raw_value > 0.0 and is_equal_approx(raw_value, floor(raw_value)) else 0
	return 0
