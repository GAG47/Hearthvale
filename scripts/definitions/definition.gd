@abstract
class_name Definition
extends RefCounted

var _definition_id: StringName

var definition_id: StringName:
	get:
		return _definition_id


func _init(p_definition_id: StringName) -> void:
	_definition_id = p_definition_id


@abstract func get_definition_type() -> StringName
