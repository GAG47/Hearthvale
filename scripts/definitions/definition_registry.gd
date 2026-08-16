class_name DefinitionRegistryRuntime
extends Node

enum Source {
	PROJECT,
	GENERATED,
}

var _definitions: Dictionary[StringName, Definition] = {}
var _sources: Dictionary[StringName, Source] = {}


func register_project_definition(definition: Definition) -> bool:
	return _register_definition(definition, Source.PROJECT)


func register_generated_definition(definition: Definition) -> bool:
	return _register_definition(definition, Source.GENERATED)


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


func is_generated(definition_id: StringName) -> bool:
	return _sources.get(definition_id, Source.PROJECT) == Source.GENERATED


func get_generated_definitions() -> Array[Definition]:
	var definitions: Array[Definition] = []
	for definition in get_definitions():
		if is_generated(definition.definition_id):
			definitions.append(definition)
	return definitions


func serialize_generated_definitions() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for definition in get_generated_definitions():
		serialized.append(definition.to_data())
	return serialized


func restore_generated_definitions(serialized: Array[Dictionary]) -> bool:
	var restored: Array[Definition] = []
	var restored_ids: Dictionary[StringName, bool] = {}
	for data in serialized:
		var definition := DefinitionCodec.from_data(data)
		if definition == null or not UuidValidator.is_valid_v4(definition.definition_id):
			return false
		if _definitions.has(definition.definition_id) or restored_ids.has(definition.definition_id):
			push_error(
				"Cannot restore duplicate generated definition_id '%s'."
				% definition.definition_id
			)
			return false
		restored.append(definition)
		restored_ids[definition.definition_id] = true
	for definition in restored:
		if not register_generated_definition(definition):
			return false
	return true


func _register_definition(definition: Definition, source: Source) -> bool:
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
	_sources[definition.definition_id] = source
	return true
