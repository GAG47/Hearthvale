@tool
class_name LocationEntry
extends Resource

@export var entry_id: StringName
@export var cell: Vector2i
@export var facing: ActorState.Facing = ActorState.Facing.DOWN


func _init(
	p_entry_id: StringName = &"",
	p_cell: Vector2i = Vector2i.ZERO,
	p_facing: ActorState.Facing = ActorState.Facing.DOWN
) -> void:
	entry_id = p_entry_id
	cell = p_cell
	facing = p_facing


func get_local_position() -> Vector2:
	return GridSpace.cell_to_local_position(cell)
