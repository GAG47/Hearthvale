@tool
class_name GridScene
extends Node2D

const CELL_SIZE := 32

@export var display_name := "Location"
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)
		queue_redraw()
@export var floor_color := Color("#9a7954"):
	set(value):
		floor_color = value
		queue_redraw()
@export var grid_color := Color(0.12, 0.10, 0.08, 0.16):
	set(value):
		grid_color = value
		queue_redraw()


func _draw() -> void:
	var size := Vector2(grid_size * CELL_SIZE)
	draw_rect(Rect2(Vector2.ZERO, size), floor_color)

	for x in range(grid_size.x + 1):
		var line_x := float(x * CELL_SIZE)
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, size.y), grid_color, 1.0)

	for y in range(grid_size.y + 1):
		var line_y := float(y * CELL_SIZE)
		draw_line(Vector2(0.0, line_y), Vector2(size.x, line_y), grid_color, 1.0)


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid_size * CELL_SIZE))
