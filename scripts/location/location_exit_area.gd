class_name LocationExitArea
extends Area2D

var cell_rect := Rect2i(0, 0, 1, 1)
var edge_key := &""

var location: GridScene
var world_definition: WorldDefinitionRuntime


func configure(exit: LocationExit) -> void:
	edge_key = exit.edge_key
	cell_rect = exit.cell_rect


func _ready() -> void:
	_update_collision()
	location = _find_location()
	if location == null:
		push_error("LocationExitArea edge_key '%s' must belong to a GridScene." % edge_key)
		return
	world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	if world_definition == null:
		push_error(
			"LocationExitArea '%s/%s' requires the WorldDefinition Autoload."
			% [location.location_id, edge_key]
		)
		return
	if world_definition.get_edge(location.location_id, edge_key) == null:
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("request_location_change"):
		game.request_location_change(edge_key)


func _find_location() -> GridScene:
	var current := get_parent()
	while current != null:
		if current is GridScene:
			return current as GridScene
		current = current.get_parent()
	return null


func _update_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	add_child(collision)
	var pixel_rect := Rect2(
		GridSpace.cell_to_local_position(cell_rect.position),
		GridSpace.grid_size_to_local_size(cell_rect.size)
	)
	var rectangle := RectangleShape2D.new()
	rectangle.size = pixel_rect.size
	collision.position = pixel_rect.get_center()
	collision.shape = rectangle
