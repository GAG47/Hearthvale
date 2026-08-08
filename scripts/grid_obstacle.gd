@tool
class_name GridObstacle
extends StaticBody2D

@export var cell_rect := Rect2i(0, 0, 1, 1):
	set(value):
		cell_rect = value
		queue_redraw()
		_update_collision()
@export var fill_color := Color("#554638"):
	set(value):
		fill_color = value
		queue_redraw()
@export var edge_color := Color("#2e2722"):
	set(value):
		edge_color = value
		queue_redraw()


func _ready() -> void:
	_update_collision()


func _draw() -> void:
	var pixel_rect := _get_pixel_rect()
	draw_rect(pixel_rect, fill_color)
	draw_rect(pixel_rect.grow(-2.0), edge_color, false, 3.0)


func _update_collision() -> void:
	if not is_inside_tree():
		return

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)

	var pixel_rect := _get_pixel_rect()
	var rectangle := RectangleShape2D.new()
	rectangle.size = pixel_rect.size
	collision.position = pixel_rect.get_center()
	collision.shape = rectangle


func _get_pixel_rect() -> Rect2:
	return Rect2(
		Vector2(cell_rect.position * GridScene.CELL_SIZE),
		Vector2(cell_rect.size * GridScene.CELL_SIZE)
	)
