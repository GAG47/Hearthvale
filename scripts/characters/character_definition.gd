class_name CharacterDefinition
extends RefCounted

var character_id: StringName
var display_name: String
var visuals: Dictionary[String, String]


func _init(
	p_character_id: StringName,
	p_display_name: String,
	p_visuals: Dictionary[String, String]
) -> void:
	character_id = p_character_id
	display_name = p_display_name
	visuals = p_visuals.duplicate()
