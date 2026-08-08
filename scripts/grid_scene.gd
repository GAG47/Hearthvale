class_name GridScene
extends Node2D

const CELL_SIZE := 32

@export var display_name := "Location"
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid_size * CELL_SIZE))
