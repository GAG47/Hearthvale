@tool
class_name LocationExit
extends Area2D

@export var cell_rect := Rect2i(0, 0, 1, 1):
	set(value):
		cell_rect = value
		queue_redraw()
		_update_collision()
@export_file("*.tscn") var target_scene_path := ""
@export var target_entry := &""
@export var exit_direction := Vector2.DOWN:
	set(value):
		exit_direction = value.normalized()
		queue_redraw()
@export var marker_color := Color("#d4b866"):
	set(value):
		marker_color = value
		queue_redraw()


func _ready() -> void:
	_update_collision()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _draw() -> void:
	var pixel_rect := _get_pixel_rect()
	var center := pixel_rect.get_center()
	var direction := exit_direction if not exit_direction.is_zero_approx() else Vector2.DOWN
	var side := direction.orthogonal()

	draw_rect(pixel_rect, Color(marker_color, 0.32))
	draw_line(center - direction * 7.0, center + direction * 7.0, marker_color, 3.0)
	draw_colored_polygon(
		PackedVector2Array([
			center + direction * 11.0,
			center + direction * 3.0 + side * 6.0,
			center + direction * 3.0 - side * 6.0,
		]),
		marker_color
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("request_location_change"):
		game.request_location_change(target_scene_path, target_entry)


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
