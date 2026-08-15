class_name ActorRepresentation
extends CharacterBody2D

var actor: Actor
var current_location: GridScene

var entity_id: StringName:
	get:
		return actor.entity_id if actor != null else &""

var facing: ActorState.Facing:
	get:
		return actor.facing if actor != null else ActorState.Facing.DOWN
	set(value):
		if actor != null:
			(actor.state as ActorState).facing = value
			_update_facing_visual()

var world_position: Vector2:
	get:
		return global_position

var current_cell: Vector2i:
	get:
		if current_location == null:
			return Vector2i.ZERO
		var representation_local_position := current_location.to_local(global_position)
		return Vector2i(
			floori(representation_local_position.x / GridScene.CELL_SIZE),
			floori(representation_local_position.y / GridScene.CELL_SIZE)
		)


func get_entity() -> Entity:
	return actor


func prepare_actor(
	p_actor: Actor,
	location: GridScene,
	target_local_position: Vector2
) -> bool:
	if p_actor == null or location == null:
		push_error("ActorRepresentation preparation requires an Actor and target GridScene.")
		return false
	if p_actor.definition == null or p_actor.state == null:
		push_error("ActorRepresentation requires an ActorDefinition and ActorState.")
		return false
	var definition_warnings := p_actor.definition.get_validation_warnings()
	if not definition_warnings.is_empty():
		push_error("ActorRepresentation received an invalid ActorDefinition: %s" % definition_warnings[0])
		return false
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("ActorRepresentation requires a Sprite2D child.")
		return false
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		push_error("ActorRepresentation requires CollisionShape2D with a Shape2D.")
		return false
	actor = p_actor
	current_location = location
	position = target_local_position
	_update_facing_visual()
	return true


func finish_location_departure() -> void:
	sync_state_from_representation()
	current_location = null


func sync_state_from_representation() -> bool:
	if actor == null or not is_instance_valid(current_location):
		return false
	var location_space := get_node_or_null("/root/LocationSpace") as LocationSpaceRuntime
	if location_space == null:
		push_error("ActorRepresentation position sync requires LocationSpace.")
		return false
	if location_space.try_move_entity(actor, current_location.location_id, position):
		return true
	position = actor.local_position
	return false


func get_front_cell() -> Vector2i:
	return current_cell + get_facing_cell_offset()


func get_facing_cell_offset() -> Vector2i:
	match facing:
		ActorState.Facing.UP:
			return Vector2i.UP
		ActorState.Facing.LEFT:
			return Vector2i.LEFT
		ActorState.Facing.RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN


func get_facing_vector() -> Vector2:
	return Vector2(get_facing_cell_offset())


func _update_facing_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or actor == null:
		return
	var direction := StringName(_get_facing_direction())
	var visual := actor.definition.get_visual(direction)
	if visual == null:
		push_error(
			"Actor '%s' has no Texture2D visual for direction '%s'."
			% [actor.entity_id, direction]
		)
		return
	sprite.texture = visual


func _get_facing_direction() -> String:
	match facing:
		ActorState.Facing.UP:
			return "up"
		ActorState.Facing.LEFT:
			return "left"
		ActorState.Facing.RIGHT:
			return "right"
		_:
			return "down"


func _exit_tree() -> void:
	sync_state_from_representation()
