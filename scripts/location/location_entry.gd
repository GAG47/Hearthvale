class_name LocationEntry
extends RefCounted

var _entry_id: StringName
var _cell: Vector2i
var _facing: ActorState.Facing

var entry_id: StringName:
	get:
		return _entry_id
var cell: Vector2i:
	get:
		return _cell
var facing: ActorState.Facing:
	get:
		return _facing


func _init(
	p_entry_id: StringName,
	p_cell: Vector2i,
	p_facing: ActorState.Facing
) -> void:
	_entry_id = p_entry_id
	_cell = p_cell
	_facing = p_facing


func get_local_position() -> Vector2:
	return GridSpace.cell_to_local_position(cell)
