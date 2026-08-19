@tool
class_name FurnitureDefinition
extends Resource

@export var display_name := ""
@export var visual: Texture2D
@export var behaviors: Array[FurnitureBehavior] = []
@export var footprint_cells: Array[Vector2i] = [Vector2i.ZERO]
@export var blocks_movement := true
@export var use_slots: Array[UseSlot] = []


func get_footprint_bounds() -> Rect2i:
	if footprint_cells.is_empty():
		return Rect2i()
	var min_cell := footprint_cells[0]
	var max_cell := footprint_cells[0]
	for cell in footprint_cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)
