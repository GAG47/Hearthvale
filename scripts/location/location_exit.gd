@tool
class_name LocationExit
extends Resource

@export var edge_key: StringName
@export var cell_rect: Rect2i


func _init(
	p_edge_key: StringName = &"",
	p_cell_rect: Rect2i = Rect2i()
) -> void:
	edge_key = p_edge_key
	cell_rect = p_cell_rect
