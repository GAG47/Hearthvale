@tool
class_name LocationEntry
extends Resource

@export var entry_id: StringName
@export var arrival_cells: Array[Vector2i] = [Vector2i.ZERO]
@export var facing: ActorState.Facing = ActorState.Facing.DOWN


func _init(
	p_entry_id: StringName = &"",
	p_arrival_cells: Array[Vector2i] = [Vector2i.ZERO],
	p_facing: ActorState.Facing = ActorState.Facing.DOWN
) -> void:
	entry_id = p_entry_id
	arrival_cells = p_arrival_cells.duplicate()
	facing = p_facing
