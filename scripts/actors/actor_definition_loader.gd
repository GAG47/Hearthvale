class_name ActorDefinitionLoader
extends RefCounted

const VISUAL_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]


static func load_from_file(path: String) -> ActorDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error(
			"ActorDefinitionLoader failed to open '%s': %s."
			% [path, error_string(open_error)]
		)
		return null

	var json_text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		push_error(
			"ActorDefinitionLoader failed to read '%s': %s."
			% [path, error_string(read_error)]
		)
		return null

	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK:
		push_error(
			"ActorDefinitionLoader failed to parse '%s' at line %d: %s."
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return null

	var parsed_data: Variant = parser.data
	if not parsed_data is Dictionary:
		push_error("ActorDefinitionLoader expected a Dictionary root in '%s'." % path)
		return null
	var data: Dictionary = parsed_data

	if not data.has("definition_id"):
		push_error("ActorDefinitionLoader '%s' is missing 'definition_id'." % path)
		return null
	var raw_definition_id: Variant = data["definition_id"]
	if not raw_definition_id is String:
		push_error("ActorDefinitionLoader '%s' field 'definition_id' must be a String." % path)
		return null
	var definition_id_text: String = raw_definition_id
	var definition_id := StringName(definition_id_text)
	if not UuidValidator.is_valid_v4(definition_id):
		push_error(
			"ActorDefinitionLoader '%s' field 'definition_id' is not a valid UUID v4: '%s'."
			% [path, definition_id_text]
		)
		return null

	if not data.has("display_name"):
		push_error("ActorDefinitionLoader '%s' is missing 'display_name'." % path)
		return null
	var raw_display_name: Variant = data["display_name"]
	if not raw_display_name is String:
		push_error("ActorDefinitionLoader '%s' field 'display_name' must be a String." % path)
		return null
	var display_name: String = raw_display_name
	if display_name.strip_edges().is_empty():
		push_error("ActorDefinitionLoader '%s' field 'display_name' must not be empty." % path)
		return null

	if not data.has("visuals"):
		push_error("ActorDefinitionLoader '%s' is missing 'visuals'." % path)
		return null
	var raw_visuals: Variant = data["visuals"]
	if not raw_visuals is Dictionary:
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals' must be a Dictionary." % path
		)
		return null
	var visuals_data: Dictionary = raw_visuals
	var visuals: Dictionary[String, String] = {}
	for direction: String in VISUAL_DIRECTIONS:
		var visual_path := _validate_visual_path(visuals_data, direction, path)
		if visual_path.is_empty():
			return null
		visuals[direction] = visual_path

	return ActorDefinition.new(definition_id, display_name, visuals)


static func _validate_visual_path(
	visuals_data: Dictionary,
	direction: String,
	definition_path: String
) -> String:
	if not visuals_data.has(direction):
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals' is missing '%s'."
			% [definition_path, direction]
		)
		return ""
	var raw_visual_path: Variant = visuals_data[direction]
	if not raw_visual_path is String:
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals.%s' must be a String."
			% [definition_path, direction]
		)
		return ""
	var visual_path: String = raw_visual_path
	if visual_path.strip_edges().is_empty():
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals.%s' must not be empty."
			% [definition_path, direction]
		)
		return ""
	if not ResourceLoader.exists(visual_path):
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals.%s' points to a missing resource: '%s'."
			% [definition_path, direction, visual_path]
		)
		return ""
	var visual_resource := ResourceLoader.load(visual_path)
	if visual_resource == null:
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals.%s' could not be loaded: '%s'."
			% [definition_path, direction, visual_path]
		)
		return ""
	if not visual_resource is Texture2D:
		push_error(
			"ActorDefinitionLoader '%s' field 'visuals.%s' must reference a Texture2D: '%s'."
			% [definition_path, direction, visual_path]
		)
		return ""
	return visual_path
