class_name FurnitureRepresentation
extends Node2D

var furniture: Furniture
var current_location: LocationScene

var instance_id: StringName:
	get:
		return furniture.instance_id if furniture != null else &""


func get_entity() -> Entity:
	return furniture


func prepare_furniture(
	p_furniture: Furniture,
	location: LocationScene,
	target_cell: Vector2i
) -> bool:
	if p_furniture == null or location == null:
		push_error("FurnitureRepresentation preparation requires Furniture and target LocationScene.")
		return false
	if p_furniture.definition == null or p_furniture.state == null:
		push_error("FurnitureRepresentation requires FurnitureDefinition and FurnitureState.")
		return false
	if p_furniture.get_footprint_local_cells().is_empty():
		push_error("FurnitureRepresentation requires footprint_cells in its Definition.")
		return false
	if p_furniture.current_location_id != location.location_id:
		push_error(
			"Furniture '%s' belongs to Location '%s', but its representation was requested in '%s'."
			% [p_furniture.instance_id, p_furniture.current_location_id, location.location_id]
		)
		return false

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("FurnitureRepresentation requires a Sprite2D child.")
		return false
	var blocking_body := get_node_or_null("BlockingBody") as StaticBody2D
	if blocking_body == null:
		push_error("FurnitureRepresentation requires a BlockingBody StaticBody2D.")
		return false
	var visual_texture := _load_visual_texture(p_furniture)
	if visual_texture == null:
		return false

	furniture = p_furniture
	current_location = location
	position = _get_footprint_center_position(target_cell)
	_configure_blocking_collision(blocking_body)
	sprite.texture = visual_texture
	furniture.state_changed.connect(_on_furniture_state_changed)
	return true


func _configure_blocking_collision(
	blocking_body: StaticBody2D
) -> void:
	blocking_body.collision_layer = 1 if furniture.definition.blocks_movement else 0
	blocking_body.collision_mask = 1 if furniture.definition.blocks_movement else 0
	for child in blocking_body.get_children():
		if child is CollisionShape2D:
			child.free()

	var footprint_bounds := furniture.definition.get_footprint_bounds()
	var footprint_center := Vector2(footprint_bounds.size * LocationGridSpace.CELL_SIZE) * 0.5
	var collision_index := 0
	for local_cell in furniture.get_footprint_local_cells():
		var collision := CollisionShape2D.new()
		collision.name = (
			"CollisionShape2D" if collision_index == 0 else "CollisionShape2D_%d" % collision_index
		)
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2.ONE * LocationGridSpace.CELL_SIZE
		collision.shape = rectangle
		var cell_center := (
			Vector2(local_cell - footprint_bounds.position) * LocationGridSpace.CELL_SIZE
			+ Vector2.ONE * LocationGridSpace.CELL_SIZE * 0.5
		)
		collision.position = cell_center - footprint_center
		collision.disabled = not furniture.definition.blocks_movement
		blocking_body.add_child(collision)
		collision_index += 1


func _update_visual() -> bool:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("FurnitureRepresentation requires a Sprite2D child.")
		return false
	var visual_texture := _load_visual_texture(furniture)
	if visual_texture == null:
		return false
	sprite.texture = visual_texture
	return true


func _load_visual_texture(p_furniture: Furniture) -> Texture2D:
	var visual := p_furniture.get_visual()
	if visual == null:
		push_error("Furniture '%s' Definition has no current Texture2D." % p_furniture.instance_id)
		return null
	return visual


func _on_furniture_state_changed() -> void:
	_update_visual()


func _get_footprint_center_position(origin_cell: Vector2i) -> Vector2:
	var bounds := furniture.definition.get_footprint_bounds()
	var first_cell := origin_cell + bounds.position
	return (
		LocationGridSpace.cell_to_local_position(first_cell)
		+ Vector2(bounds.size * LocationGridSpace.CELL_SIZE) * 0.5
	)
