@abstract
class_name EntityState
extends RefCounted

var entity_id: StringName
var current_location_id: StringName
var local_position: Vector2


func _init(
	p_entity_id: StringName,
	p_current_location_id: StringName,
	p_local_position: Vector2
) -> void:
	entity_id = p_entity_id
	current_location_id = p_current_location_id
	local_position = p_local_position
