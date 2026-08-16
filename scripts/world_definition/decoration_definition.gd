class_name DecorationDefinition
extends Definition

var _key: StringName
var _presentation: Dictionary

var key: StringName:
	get:
		return _key
var presentation: Dictionary:
	get:
		return _presentation.duplicate(true)


func _init(
	p_definition_id: StringName,
	p_key: StringName,
	p_presentation: Dictionary
) -> void:
	super(p_definition_id)
	_key = p_key
	_presentation = p_presentation.duplicate(true)


func get_definition_type() -> StringName:
	return &"decoration"


func to_data() -> Dictionary:
	return {
		"type": String(get_definition_type()),
		"definition_id": String(definition_id),
		"key": String(key),
		"presentation": presentation.duplicate(true),
	}
