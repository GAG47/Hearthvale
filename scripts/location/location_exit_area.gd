class_name LocationExitArea
extends Area2D

var cell_rect := Rect2i(0, 0, 1, 1)
var edge_key := &""

var location: LocationScene
var location_registry: LocationRegistry


func configure(exit: LocationExit) -> void:
	edge_key = exit.edge_key
	cell_rect = exit.cell_rect


func _ready() -> void:
	_update_collision()
	location = _find_location()
	if location == null:
		push_error("LocationExitArea edge_key '%s' must belong to a LocationScene." % edge_key)
		return
	location_registry = get_node_or_null("/root/LocationRegistry") as LocationRegistry
	if location_registry == null:
		push_error(
			"LocationExitArea '%s/%s' requires the LocationRegistry Autoload."
			% [location.location_id, edge_key]
		)
		return
	if location_registry.get_edge(location.location_id, edge_key) == null:
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("request_location_change"):
		game.request_location_change(edge_key)


func _find_location() -> LocationScene:
	var current := get_parent()
	while current != null:
		if current is LocationScene:
			return current as LocationScene
		current = current.get_parent()
	return null


func _update_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	add_child(collision)
	var pixel_rect := Rect2(
		LocationGridSpace.cell_to_local_position(cell_rect.position),
		LocationGridSpace.grid_size_to_local_size(cell_rect.size)
	)
	var rectangle := RectangleShape2D.new()
	rectangle.size = pixel_rect.size
	collision.position = pixel_rect.get_center()
	collision.shape = rectangle
