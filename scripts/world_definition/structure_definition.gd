class_name StructureDefinition
extends Definition

var _key: StringName
var _occupied_cells: Array[Vector2i]
var _blocks_movement: bool
var _presentation: Dictionary

var key: StringName:
	get:
		return _key
var occupied_cells: Array[Vector2i]:
	get:
		return _occupied_cells.duplicate()
var blocks_movement: bool:
	get:
		return _blocks_movement
var presentation: Dictionary:
	get:
		return _presentation.duplicate(true)


func _init(
	p_definition_id: StringName,
	p_key: StringName,
	p_occupied_cells: Array[Vector2i],
	p_blocks_movement: bool,
	p_presentation: Dictionary
) -> void:
	super(p_definition_id)
	_key = p_key
	_occupied_cells = p_occupied_cells.duplicate()
	_blocks_movement = p_blocks_movement
	_presentation = p_presentation.duplicate(true)


func get_definition_type() -> StringName:
	return &"structure"
