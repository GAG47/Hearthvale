class_name StructurePlacement
extends RefCounted

const VALID_ORIENTATIONS: Array[int] = [0, 90, 180, 270]

var _placement_id: StringName
var _definition_id: StringName
var _origin_cell: Vector2i
var _orientation: int

var placement_id: StringName:
	get:
		return _placement_id
var definition_id: StringName:
	get:
		return _definition_id
var origin_cell: Vector2i:
	get:
		return _origin_cell
var orientation: int:
	get:
		return _orientation


func _init(
	p_placement_id: StringName,
	p_definition_id: StringName,
	p_origin_cell: Vector2i,
	p_orientation: int = 0
) -> void:
	_placement_id = p_placement_id
	_definition_id = p_definition_id
	_origin_cell = p_origin_cell
	_orientation = p_orientation


func get_world_cells(definition: StructureDefinition) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if definition == null:
		return cells
	for occupied_cell in definition.occupied_cells:
		cells.append(origin_cell + transform_cell(occupied_cell, orientation))
	return cells


static func transform_cell(cell: Vector2i, p_orientation: int) -> Vector2i:
	match p_orientation:
		90:
			return Vector2i(-cell.y, cell.x)
		180:
			return Vector2i(-cell.x, -cell.y)
		270:
			return Vector2i(cell.y, -cell.x)
		_:
			return cell


func to_data() -> Dictionary:
	return {
		"placement_id": String(placement_id),
		"definition_id": String(definition_id),
		"origin_cell": [origin_cell.x, origin_cell.y],
		"orientation": orientation,
	}
