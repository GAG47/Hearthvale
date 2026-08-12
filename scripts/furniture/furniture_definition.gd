class_name FurnitureDefinition
extends RefCounted

var definition_id: StringName
var display_name: String
var visual_ref: String
var behaviors: Dictionary
var occupied_cells: Vector2i
var blocks_movement: bool


func _init(
	p_definition_id: StringName,
	p_display_name: String,
	p_visual_ref: String,
	p_behaviors: Dictionary,
	p_occupied_cells: Vector2i,
	p_blocks_movement: bool
) -> void:
	definition_id = p_definition_id
	display_name = p_display_name
	visual_ref = p_visual_ref
	behaviors = p_behaviors.duplicate(true)
	occupied_cells = p_occupied_cells
	blocks_movement = p_blocks_movement
