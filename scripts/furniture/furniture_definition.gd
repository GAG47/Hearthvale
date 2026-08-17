class_name FurnitureDefinition
extends Definition

var _display_name: String
var _visual_ref: String
var _behaviors: Dictionary
var _occupied_cells: Vector2i
var _blocks_movement: bool

var display_name: String:
	get:
		return _display_name
var visual_ref: String:
	get:
		return _visual_ref
var behaviors: Dictionary:
	get:
		return _behaviors.duplicate(true)
var occupied_cells: Vector2i:
	get:
		return _occupied_cells
var blocks_movement: bool:
	get:
		return _blocks_movement


func _init(
	p_definition_id: StringName,
	p_display_name: String,
	p_visual_ref: String,
	p_behaviors: Dictionary,
	p_occupied_cells: Vector2i,
	p_blocks_movement: bool
) -> void:
	super(p_definition_id)
	_display_name = p_display_name
	_visual_ref = p_visual_ref
	_behaviors = p_behaviors.duplicate(true)
	_occupied_cells = p_occupied_cells
	_blocks_movement = p_blocks_movement


func get_definition_type() -> StringName:
	return &"furniture"
