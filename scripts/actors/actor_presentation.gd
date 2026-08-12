class_name ActorPresentation
extends CharacterBody2D

const VISUAL_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var actor: Actor
var current_location: GridScene
var _visual_textures: Dictionary[String, Texture2D] = {}

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
		var presentation_local_position := current_location.to_local(global_position)
		return Vector2i(
			floori(presentation_local_position.x / GridScene.CELL_SIZE),
			floori(presentation_local_position.y / GridScene.CELL_SIZE)
		)


func bind_actor(p_actor: Actor, location: GridScene) -> bool:
	if p_actor == null or location == null:
		push_error("ActorPresentation requires an Actor and a loaded GridScene.")
		return false
	if p_actor.definition.entity_id != p_actor.entity_id:
		push_error(
			"ActorDefinition ID '%s' does not match ActorState ID '%s'."
			% [p_actor.definition.entity_id, p_actor.entity_id]
		)
		return false
	if p_actor.current_location_id != location.location_id:
		push_error(
			"Actor '%s' state belongs to Location '%s', but its presentation was requested in Location '%s'."
			% [
				p_actor.entity_id,
				p_actor.current_location_id,
				location.location_id,
			]
			)
		return false
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("ActorPresentation requires a Sprite2D child.")
		return false
	var loaded_visual_textures := _load_visual_textures(p_actor)
	if loaded_visual_textures.size() != VISUAL_DIRECTIONS.size():
		return false

	actor = p_actor
	current_location = location
	_visual_textures = loaded_visual_textures
	position = actor.local_position
	_update_facing_visual()
	return true


func sync_state_from_presentation() -> void:
	if actor == null or not is_instance_valid(current_location):
		return
	actor.state.current_location_id = current_location.location_id
	actor.state.local_position = position


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
			% [actor.entity_id, direction]
		)
		return
	sprite.texture = _visual_textures[direction]


func _load_visual_textures(p_actor: Actor) -> Dictionary[String, Texture2D]:
	var textures: Dictionary[String, Texture2D] = {}
	for direction: String in VISUAL_DIRECTIONS:
		if not p_actor.definition.visuals.has(direction):
			push_error(
				"Actor '%s' visuals is missing direction '%s'."
				% [p_actor.entity_id, direction]
			)
			return textures
		var visual_path: String = p_actor.definition.visuals[direction]
		if not ResourceLoader.exists(visual_path):
			push_error(
				"Actor '%s' visuals.%s '%s' does not exist."
				% [p_actor.entity_id, direction, visual_path]
			)
			return textures
		var visual_resource := ResourceLoader.load(visual_path)
		if not visual_resource is Texture2D:
			push_error(
				"Actor '%s' visuals.%s '%s' did not load as a Texture2D."
				% [p_actor.entity_id, direction, visual_path]
			)
			return textures
		textures[direction] = visual_resource
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


func _exit_tree() -> void:
	sync_state_from_presentation()
