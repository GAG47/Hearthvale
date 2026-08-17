class_name DefinitionRegistryRuntime
extends Node

var _definitions: Dictionary[StringName, Definition] = {}


func register_project_definition(definition: Definition) -> bool:
	return _register_definition(definition)


func has_definition(definition_id: StringName) -> bool:
	return _definitions.has(definition_id)


func get_definition(definition_id: StringName) -> Definition:
	if not _definitions.has(definition_id):
		push_error("DefinitionRegistry has no Definition with definition_id '%s'." % definition_id)
		return null
	return _definitions[definition_id]


func get_definitions() -> Array[Definition]:
	var definitions: Array[Definition] = []
	var definition_ids := _definitions.keys()
	definition_ids.sort()
	for definition_id in definition_ids:
		definitions.append(_definitions[definition_id])
	return definitions


func _register_definition(definition: Definition) -> bool:
	if definition == null:
		push_error("DefinitionRegistry cannot register a null Definition.")
		return false
	if not UuidValidator.is_valid_v4(definition.definition_id):
		push_error(
			"Definition definition_id '%s' is not a valid UUID v4."
			% definition.definition_id
		)
		return false
	if _definitions.has(definition.definition_id):
		push_error(
			"DefinitionRegistry already contains definition_id '%s'."
			% definition.definition_id
		)
		return false
	_definitions[definition.definition_id] = definition
	return true
