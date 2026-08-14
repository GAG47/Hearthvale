class_name ActorDefinition
extends RefCounted

var definition_id: StringName
var display_name: String
var visuals: Dictionary[String, String]


func _init(
	p_definition_id: StringName,
	p_display_name: String,
	p_visuals: Dictionary[String, String]
) -> void:
	definition_id = p_definition_id
	display_name = p_display_name
	visuals = p_visuals.duplicate()
