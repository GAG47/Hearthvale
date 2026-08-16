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
	p_local_offset: Vector2 = Vector2.ONE * GridScene.CELL_SIZE * 0.5
) -> void:
	_entry_id = p_entry_id
	_cell = p_cell
	_facing = p_facing
	_local_offset = p_local_offset


func get_local_position() -> Vector2:
	return Vector2(cell * GridScene.CELL_SIZE) + local_offset


func get_anchor_type() -> StringName:
	return &"entry"


func to_data() -> Dictionary:
	return {
		"type": String(get_anchor_type()),
		"entry_id": String(entry_id),
		"cell": [cell.x, cell.y],
		"facing": facing,
		"local_offset": [local_offset.x, local_offset.y],
	}
