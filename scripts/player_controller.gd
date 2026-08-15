class_name PlayerController
extends Node2D

signal action_completed(result: ActionResult)

@export var move_speed := 140.0

@onready var camera: Camera2D = $Camera2D

var controlled_actor: Actor
var controlled_representation: ActorRepresentation


func _physics_process(_delta: float) -> void:
	if controlled_actor == null or not is_instance_valid(controlled_representation):
		return

	if Input.is_action_just_pressed(&"interact"):
		request_interaction()

	var input_direction := _get_input_direction()
	controlled_representation.velocity = input_direction * move_speed
	if not input_direction.is_zero_approx():
		_update_facing(input_direction)

	controlled_representation.move_and_slide()
	controlled_representation.sync_state_from_representation()
	_sync_camera_position()


func take_control(actor: Actor, representation: Node) -> bool:
	if not can_take_control(actor, representation):
		return false
	release_controlled_representation()
	_assign_control(actor, representation as ActorRepresentation)
	return true


func can_take_control(actor: Actor, representation: Node) -> bool:
	if actor == null or not is_instance_valid(representation) or not representation is ActorRepresentation:
		push_error("PlayerController requires an Actor and ActorRepresentation.")
		return false
	var actor_representation := representation as ActorRepresentation
	if actor_representation.get_entity() != actor:
		push_error(
			"PlayerController cannot bind Actor '%s' to a Representation for Actor '%s'."
			% [actor.entity_id, actor_representation.entity_id]
		)
		return false
	return true


func activate_prepared_control(actor: Actor, representation: Node) -> void:
	var actor_representation := representation as ActorRepresentation
	_release_controlled_representation(false)
	_assign_control(actor, actor_representation)


func finish_controlled_location_departure() -> void:
	if is_instance_valid(controlled_representation):
		controlled_representation.finish_location_departure()


func release_controlled_representation() -> void:
	_release_controlled_representation(true)


func _release_controlled_representation(sync_state: bool) -> void:
	if is_instance_valid(controlled_representation):
		controlled_representation.velocity = Vector2.ZERO
		if sync_state:
			controlled_representation.sync_state_from_representation()
		controlled_representation.remove_from_group(&"player")
	controlled_representation = null


func _assign_control(actor: Actor, representation: ActorRepresentation) -> void:
	controlled_actor = actor
	controlled_representation = representation
	controlled_representation.add_to_group(&"player")
	_sync_camera_position(true)


func stop() -> void:
	if is_instance_valid(controlled_representation):
		controlled_representation.velocity = Vector2.ZERO


func set_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()


func request_interaction() -> ActionResult:
	if controlled_actor == null or not is_instance_valid(controlled_representation):
		var unavailable_result := ActionResult.failed(
			&"interact",
			&"",
			"当前没有可控制的角色表现。",
			&"controlled_representation_unavailable"
		)
		action_completed.emit(unavailable_result)
		return unavailable_result

	controlled_representation.sync_state_from_representation()
	var target := InteractionTargetSelector.select_target(controlled_actor)
	if target == null:
		var no_target_result := ActionResult.failed(&"interact", &"", "前方没有可交互的对象。")
		action_completed.emit(no_target_result)
		return no_target_result

	var action_id := target.get_primary_action(controlled_actor)
	if action_id.is_empty():
		var no_action_result := ActionResult.failed(
			&"interact",
			target.entity_id,
			"目标实体当前没有可用行为。"
		)
		action_completed.emit(no_action_result)
		return no_action_result

	var location_space := get_node_or_null("/root/LocationSpace") as LocationSpaceRuntime
	var logical_location := (
		location_space.get_location(controlled_actor.current_location_id)
		if location_space != null and location_space.has_location(controlled_actor.current_location_id)
		else null
	)
	var action := WorldAction.new(action_id, controlled_actor, target, logical_location)
	var result := action.execute()
	action_completed.emit(result)
	return result


func _get_input_direction() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0

	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	if not is_zero_approx(direction.y):
		return Vector2(0.0, signf(direction.y))
	return Vector2.ZERO


func _update_facing(direction: Vector2) -> void:
	var next_facing := controlled_representation.facing
	if absf(direction.x) > absf(direction.y):
		next_facing = (
			ActorState.Facing.RIGHT if direction.x > 0.0 else ActorState.Facing.LEFT
		)
	else:
		next_facing = (
			ActorState.Facing.DOWN if direction.y > 0.0 else ActorState.Facing.UP
		)

	if next_facing != controlled_representation.facing:
		controlled_representation.facing = next_facing


func _sync_camera_position(reset_smoothing := false) -> void:
	if not is_instance_valid(controlled_representation):
		return
	global_position = controlled_representation.global_position
	if reset_smoothing:
		reset_physics_interpolation()
		camera.reset_smoothing()
