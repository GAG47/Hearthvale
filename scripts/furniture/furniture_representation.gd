class_name FurnitureRepresentation
extends Node2D

var furniture: Furniture
var current_location: GridScene

var entity_id: StringName:
	get:
		return furniture.entity_id if furniture != null else &""


func get_entity() -> Entity:
	return furniture


func prepare_furniture(
	p_furniture: Furniture,
	location: GridScene,
	target_local_position: Vector2
) -> bool:
	if p_furniture == null or location == null:
		push_error("FurnitureRepresentation preparation requires Furniture and target GridScene.")
		return false
	if p_furniture.definition == null or p_furniture.state == null:
		push_error("FurnitureRepresentation requires FurnitureDefinition and FurnitureState.")
		return false
	if (
		p_furniture.definition.occupied_cells.x <= 0
		or p_furniture.definition.occupied_cells.y <= 0
	):
		push_error("FurnitureRepresentation requires positive occupied_cells in its Definition.")
		return false
	if p_furniture.current_location_id != location.location_id:
		push_error(
			"Furniture '%s' belongs to Location '%s', but its representation was requested in '%s'."
			% [p_furniture.entity_id, p_furniture.current_location_id, location.location_id]
		)
		return false

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("FurnitureRepresentation requires a Sprite2D child.")
		return false
	var blocking_body := get_node_or_null("BlockingBody") as StaticBody2D
	var collision := get_node_or_null("BlockingBody/CollisionShape2D") as CollisionShape2D
	if blocking_body == null or collision == null or not collision.shape is RectangleShape2D:
		push_error(
			"FurnitureRepresentation requires BlockingBody/CollisionShape2D with RectangleShape2D."
		)
		return false
	var visual_texture := _load_visual_texture(p_furniture)
	if visual_texture == null:
		return false

	furniture = p_furniture
	current_location = location
	position = target_local_position
	_configure_blocking_collision(blocking_body, collision)
	sprite.texture = visual_texture
	furniture.state_changed.connect(_on_furniture_state_changed)
	return true


func get_occupied_grid_cells() -> Array[Vector2i]:
	return furniture.get_occupied_grid_cells() if furniture != null else []


func sync_state_from_representation() -> void:
	if furniture == null or not is_instance_valid(current_location):
		return
	furniture.state.current_location_id = current_location.location_id
	furniture.state.local_position = position


func _ready() -> void:
	if furniture != null and is_instance_valid(current_location):
		current_location.register_furniture_representation(self)


func _exit_tree() -> void:
	if is_instance_valid(current_location):
		current_location.unregister_furniture_representation(self)
	sync_state_from_representation()


func _configure_blocking_collision(
	blocking_body: StaticBody2D,
	collision: CollisionShape2D
) -> void:
	blocking_body.collision_layer = 1 if furniture.definition.blocks_movement else 0
	blocking_body.collision_mask = 1 if furniture.definition.blocks_movement else 0
	collision.disabled = not furniture.definition.blocks_movement
	var rectangle := collision.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = (
			Vector2(furniture.definition.occupied_cells * GridScene.CELL_SIZE)
			- Vector2(4.0, 4.0)
		)


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
	var visual_ref := p_furniture.get_visual_ref()
	if not ResourceLoader.exists(visual_ref):
		push_error(
			"Furniture '%s' visual_ref '%s' does not exist."
			% [p_furniture.entity_id, visual_ref]
		)
		return null
	var visual_resource := ResourceLoader.load(visual_ref)
	if not visual_resource is Texture2D:
		push_error(
			"Furniture '%s' visual_ref '%s' is not a Texture2D."
			% [p_furniture.entity_id, visual_ref]
		)
		return null
	return visual_resource


func _on_furniture_state_changed() -> void:
	_update_visual()
