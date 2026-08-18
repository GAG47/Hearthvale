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


func get_center_position(arrival_index := 0) -> Vector2:
	if arrival_index < 0 or arrival_index >= arrival_cells.size():
		return Vector2.ZERO
	return GridSpace.cell_to_center_position(arrival_cells[arrival_index])
