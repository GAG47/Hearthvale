class_name LocationEntryAnchor
extends LocationAnchor

var _entry_id: StringName
var _cell: Vector2i
var _facing: ActorState.Facing
var _local_offset: Vector2

var entry_id: StringName:
	get:
		return _entry_id
var cell: Vector2i:
	get:
		return _cell
var facing: ActorState.Facing:
	get:
		return _facing
var local_offset: Vector2:
	get:
		return _local_offset


func _init(
	p_entry_id: StringName,
	p_cell: Vector2i,
	p_facing: ActorState.Facing,
	p_local_offset: Vector2 = Vector2.ONE * GridSpace.CELL_SIZE * 0.5
) -> void:
	_entry_id = p_entry_id
	_cell = p_cell
	_facing = p_facing
	_local_offset = p_local_offset


func get_local_position() -> Vector2:
	return GridSpace.cell_to_local_position(cell, local_offset)


func get_anchor_type() -> StringName:
	return &"entry"
