class_name CharacterDefinition
extends RefCounted

var character_id: StringName
var display_name: String
var presentation_ref: String


func _init(p_character_id: StringName, p_display_name: String, p_presentation_ref: String) -> void:
	character_id = p_character_id
	display_name = p_display_name
	presentation_ref = p_presentation_ref
