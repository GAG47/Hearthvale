class_name CharacterState
extends RefCounted

enum Facing {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

var character_id: StringName
var current_location_id: StringName
var local_position: Vector2
var facing: Facing


func _init(
	p_character_id: StringName,
	p_current_location_id: StringName,
	p_local_position: Vector2,
	p_facing: Facing = Facing.DOWN
) -> void:
	character_id = p_character_id
	current_location_id = p_current_location_id
	local_position = p_local_position
	facing = p_facing
