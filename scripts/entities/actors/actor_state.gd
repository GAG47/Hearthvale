class_name ActorState
extends EntityState

enum Facing {
	NONE = -1,
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

var facing: Facing


func _init(
	p_instance_id: StringName,
	p_current_location_id: StringName,
	p_local_cell: Vector2i,
	p_facing: Facing = Facing.DOWN
) -> void:
	super(p_instance_id, p_current_location_id, p_local_cell)
	facing = p_facing
