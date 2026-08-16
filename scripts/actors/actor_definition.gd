class_name ActorDefinition
extends Definition

var _display_name: String
var _visuals: Dictionary[String, String]

var display_name: String:
	get:
		return _display_name

var visuals: Dictionary[String, String]:
	get:
		return _visuals.duplicate()


func _init(
	p_definition_id: StringName,
	p_display_name: String,
	p_visuals: Dictionary[String, String]
) -> void:
	super(p_definition_id)
	_display_name = p_display_name
	_visuals = p_visuals.duplicate()


func get_definition_type() -> StringName:
	return &"actor"


func to_data() -> Dictionary:
	return {
		"type": String(get_definition_type()),
		"definition_id": String(definition_id),
		"display_name": display_name,
		"visuals": visuals.duplicate(),
	}
