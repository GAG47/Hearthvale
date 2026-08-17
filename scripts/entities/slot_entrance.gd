@tool
class_name SlotEntrance
extends Resource

@export var local_cell := Vector2i.ZERO


func _init(p_local_cell: Vector2i = Vector2i.ZERO) -> void:
	local_cell = p_local_cell
