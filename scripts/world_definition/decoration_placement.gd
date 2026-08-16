class_name DecorationPlacement
extends RefCounted

var _placement_id: StringName
var _definition_id: StringName
var _cell: Vector2i
var _local_offset: Vector2

var placement_id: StringName:
	get:
		return _placement_id
var definition_id: StringName:
	get:
		return _definition_id
var cell: Vector2i:
	get:
		return _cell
var local_offset: Vector2:
	get:
		return _local_offset


func _init(
	p_placement_id: StringName,
	p_definition_id: StringName,
	p_cell: Vector2i,
	p_local_offset: Vector2 = Vector2.ZERO
) -> void:
	_placement_id = p_placement_id
	_definition_id = p_definition_id
	_cell = p_cell
	_local_offset = p_local_offset


func to_data() -> Dictionary:
	return {
		"placement_id": String(placement_id),
		"definition_id": String(definition_id),
		"cell": [cell.x, cell.y],
		"local_offset": [local_offset.x, local_offset.y],
	}
