class_name ActorRepresentation
extends CharacterBody2D

const VISUAL_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var actor: Actor
var current_location: GridScene
var _visual_textures: Dictionary[String, Texture2D] = {}
var _state_driven := true

var instance_id: StringName:
	get:
		return actor.instance_id if actor != null else &""

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
		return GridSpace.local_position_to_cell(representation_local_position)


func get_entity() -> Entity:
	return actor


func _physics_process(_delta: float) -> void:
	if actor == null:
		return
	var movement := _get_logical_movement()
	if movement != null and movement.is_participant(actor):
		_state_driven = true
	if not _state_driven:
		return
	position = actor.local_position
	_update_facing_visual()


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
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("ActorRepresentation requires a Sprite2D child.")
		return false
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		push_error("ActorRepresentation requires CollisionShape2D with a Shape2D.")
		return false
	var loaded_visual_textures := _load_visual_textures(p_actor)
	if loaded_visual_textures.size() != VISUAL_DIRECTIONS.size():
		return false

	actor = p_actor
	current_location = location
	_visual_textures = loaded_visual_textures
	position = target_local_position
	var movement := _get_logical_movement()
	_state_driven = movement == null or not movement.is_actor_externally_controlled(actor)
	_update_facing_visual()
	return true


func finish_location_departure() -> void:
	sync_state_from_representation()
	current_location = null


func sync_state_from_representation() -> void:
	if _state_driven or actor == null or not is_instance_valid(current_location):
		return
	actor.state.current_location_id = current_location.location_id
	actor.state.local_position = position


func set_state_driven(enabled: bool) -> void:
	_state_driven = enabled
	if _state_driven and actor != null:
		position = actor.local_position
		_update_facing_visual()


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
	var direction := _get_facing_direction()
	if not _visual_textures.has(direction):
		push_error(
			"Actor '%s' has no loaded visual for direction '%s'."
			% [actor.instance_id, direction]
		)
		return
	sprite.texture = _visual_textures[direction]


func _load_visual_textures(p_actor: Actor) -> Dictionary[String, Texture2D]:
	var textures: Dictionary[String, Texture2D] = {}
	for direction: String in VISUAL_DIRECTIONS:
		var visual := p_actor.definition.get_visual(direction)
		if visual == null:
			push_error(
				"Actor '%s' Definition has no Texture2D for direction '%s'."
				% [p_actor.instance_id, direction]
			)
			return textures
		textures[direction] = visual
	return textures


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


func _get_logical_movement() -> LogicalMovementRuntime:
	var tree := Engine.get_main_loop() as SceneTree
	return (
		tree.root.get_node_or_null("LogicalMovement") as LogicalMovementRuntime
		if tree != null
		else null
	)


func _exit_tree() -> void:
	if not _state_driven:
		sync_state_from_representation()
