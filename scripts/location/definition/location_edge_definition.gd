@tool
class_name LocationEdgeDefinition
extends Resource

@export var edge_id: StringName
@export var edge_key: StringName
@export var target_location_id: StringName
@export var target_entry_id: StringName


func _init(
	p_edge_id: StringName = &"",
	p_edge_key: StringName = &"",
	p_target_location_id: StringName = &"",
	p_target_entry_id: StringName = &""
) -> void:
	edge_id = p_edge_id
	edge_key = p_edge_key
	target_location_id = p_target_location_id
	target_entry_id = p_target_entry_id
