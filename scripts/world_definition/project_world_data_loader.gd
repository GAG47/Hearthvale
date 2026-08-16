class_name ProjectWorldDataLoader
extends RefCounted


static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ProjectWorldDataLoader failed to open '%s'." % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		push_error(
			"ProjectWorldDataLoader failed to parse '%s' at line %d: %s."
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return {}
	if not parser.data is Dictionary:
		push_error("ProjectWorldDataLoader expected a Dictionary root in '%s'." % path)
		return {}
	var data: Dictionary = parser.data
	if not data.get("definitions", null) is Array or not data.get("instances", null) is Array:
		push_error("ProjectWorldDataLoader '%s' requires definitions and instances Arrays." % path)
		return {}
	var definitions: Array[Definition] = []
	for raw_definition in data["definitions"]:
		if not raw_definition is Dictionary:
			push_error("ProjectWorldDataLoader '%s' contains a non-Dictionary Definition." % path)
			return {}
		var definition := DefinitionCodec.from_data(raw_definition)
		if definition == null:
			return {}
		definitions.append(definition)
	var instances: Array[Dictionary] = []
	for raw_instance in data["instances"]:
		if not raw_instance is Dictionary:
			push_error("ProjectWorldDataLoader '%s' contains a non-Dictionary instance." % path)
			return {}
		var instance: Dictionary = raw_instance
		instances.append({
			"key": StringName(instance.get("key", "")),
			"instance_id": StringName(instance.get("instance_id", "")),
			"definition_id": StringName(instance.get("definition_id", "")),
		})
	return {"definitions": definitions, "instances": instances}
