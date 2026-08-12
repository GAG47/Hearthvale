class_name CharacterDefinitionLoader
extends RefCounted


static func load_from_file(path: String) -> CharacterDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error(
			"CharacterDefinitionLoader failed to open '%s': %s."
			% [path, error_string(open_error)]
		)
		return null

	var json_text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		push_error(
			"CharacterDefinitionLoader failed to read '%s': %s."
			% [path, error_string(read_error)]
		)
		return null

	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK:
		push_error(
			"CharacterDefinitionLoader failed to parse '%s' at line %d: %s."
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return null

	var parsed_data: Variant = parser.data
	if not parsed_data is Dictionary:
		push_error("CharacterDefinitionLoader expected a Dictionary root in '%s'." % path)
		return null
	var data: Dictionary = parsed_data

	if not data.has("character_id"):
		push_error("CharacterDefinitionLoader '%s' is missing 'character_id'." % path)
		return null
	var raw_character_id: Variant = data["character_id"]
	if not raw_character_id is String:
		push_error("CharacterDefinitionLoader '%s' field 'character_id' must be a String." % path)
		return null
	var character_id_text: String = raw_character_id
	var character_id := StringName(character_id_text)
	if not UuidValidator.is_valid_v4(character_id):
		push_error(
			"CharacterDefinitionLoader '%s' field 'character_id' is not a valid UUID v4: '%s'."
			% [path, character_id_text]
		)
		return null

	if not data.has("display_name"):
		push_error("CharacterDefinitionLoader '%s' is missing 'display_name'." % path)
		return null
	var raw_display_name: Variant = data["display_name"]
	if not raw_display_name is String:
		push_error("CharacterDefinitionLoader '%s' field 'display_name' must be a String." % path)
		return null
	var display_name: String = raw_display_name
	if display_name.strip_edges().is_empty():
		push_error("CharacterDefinitionLoader '%s' field 'display_name' must not be empty." % path)
		return null

	if not data.has("presentation_ref"):
		push_error("CharacterDefinitionLoader '%s' is missing 'presentation_ref'." % path)
		return null
	var raw_presentation_ref: Variant = data["presentation_ref"]
	if not raw_presentation_ref is String:
		push_error(
			"CharacterDefinitionLoader '%s' field 'presentation_ref' must be a String." % path
		)
		return null
	var presentation_ref: String = raw_presentation_ref
	if presentation_ref.is_empty():
		push_error(
			"CharacterDefinitionLoader '%s' field 'presentation_ref' must not be empty." % path
		)
		return null
	if not ResourceLoader.exists(presentation_ref):
		push_error(
			"CharacterDefinitionLoader '%s' field 'presentation_ref' points to a missing resource: '%s'."
			% [path, presentation_ref]
		)
		return null

	return CharacterDefinition.new(character_id, display_name, presentation_ref)
