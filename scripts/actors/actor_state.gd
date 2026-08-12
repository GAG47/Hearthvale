class_name ActorState
extends EntityState

enum Facing {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

var facing: Facing


func _init(
	p_entity_id: StringName,
	p_current_location_id: StringName,
	p_local_position: Vector2,
	p_facing: Facing = Facing.DOWN
) -> void:
	super(p_entity_id, p_current_location_id, p_local_position)
	facing = p_facing
