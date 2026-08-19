class_name ActorRepresentation
extends Node2D

const VISUAL_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var actor: Actor
var current_location: LocationScene
var _visual_textures: Dictionary[String, Texture2D] = {}

var instance_id: StringName:
	get:
		return actor.instance_id if actor != null else &""

var facing: ActorState.Facing:
	get:
		return actor.facing if actor != null else ActorState.Facing.DOWN

var current_cell: Vector2i:
	get:
		return actor.current_cell if actor != null else Vector2i.ZERO


func get_entity() -> Entity:
	return actor


func _ready() -> void:
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	if actor == null:
		return
	position = _get_actor_display_position(actor.current_cell)
	_update_facing_visual()


func prepare_actor(
	p_actor: Actor,
	location: LocationScene,
	target_cell: Vector2i
) -> bool:
	if p_actor == null or location == null:
		push_error("ActorRepresentation preparation requires an Actor and target LocationScene.")
		return false
	if p_actor.definition == null or p_actor.state == null:
		push_error("ActorRepresentation requires an ActorDefinition and ActorState.")
		return false
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("ActorRepresentation requires a Sprite2D child.")
		return false
	var loaded_visual_textures := _load_visual_textures(p_actor)
	if loaded_visual_textures.size() != VISUAL_DIRECTIONS.size():
		return false

	actor = p_actor
	current_location = location
	_visual_textures = loaded_visual_textures
	position = _get_actor_display_position(target_cell)
	_update_facing_visual()
	return true


func finish_location_departure() -> void:
	current_location = null


func refresh_visual() -> void:
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


func _get_actor_display_position(fallback_cell: Vector2i) -> Vector2:
	var movement := _get_logical_movement()
	var request := movement.get_request(actor) if movement != null else null
	if request != null and request.phase == ActorMovementRequest.Phase.EXTENDED:
		return LocationGridSpace.cell_to_center_position(request.tail_cell).lerp(
			LocationGridSpace.cell_to_center_position(request.head_cell),
			request.get_step_progress()
		)
	return LocationGridSpace.cell_to_center_position(fallback_cell)


func _get_logical_movement() -> LogicalMovement:
	var tree := Engine.get_main_loop() as SceneTree
	return (
		tree.root.get_node_or_null("LogicalMovement") as LogicalMovement
		if tree != null
		else null
	)
