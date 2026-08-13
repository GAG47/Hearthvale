class_name PlayerController
extends Node2D

signal action_completed(result: ActionResult)

@export var move_speed := 140.0

@onready var camera: Camera2D = $Camera2D

var controlled_actor: Actor
var controlled_presentation: ActorPresentation


func _physics_process(_delta: float) -> void:
	if controlled_actor == null or not is_instance_valid(controlled_presentation):
		return

	if Input.is_action_just_pressed(&"interact"):
		request_interaction()

	var input_direction := _get_input_direction()
	controlled_presentation.velocity = input_direction * move_speed
	if not input_direction.is_zero_approx():
		_update_facing(input_direction)

	controlled_presentation.move_and_slide()
	controlled_presentation.sync_state_from_presentation()
	_sync_camera_position()


func take_control(actor: Actor, presentation: ActorPresentation) -> bool:
	if not can_take_control(actor, presentation):
		return false
	release_controlled_presentation()
	_assign_control(actor, presentation)
	return true


func can_take_control(actor: Actor, presentation: ActorPresentation) -> bool:
	if actor == null or not is_instance_valid(presentation):
		push_error("PlayerController requires an Actor and ActorPresentation.")
		return false
	if presentation.actor != actor:
		push_error(
			"PlayerController cannot bind Actor '%s' to a Presentation for Actor '%s'."
			% [actor.entity_id, presentation.entity_id]
		)
		return false
	return true


func activate_prepared_control(actor: Actor, presentation: ActorPresentation) -> void:
	_release_controlled_presentation(false)
	_assign_control(actor, presentation)


func release_controlled_presentation() -> void:
	_release_controlled_presentation(true)


func _release_controlled_presentation(sync_state: bool) -> void:
	if is_instance_valid(controlled_presentation):
		controlled_presentation.velocity = Vector2.ZERO
		if sync_state:
			controlled_presentation.sync_state_from_presentation()
		controlled_presentation.remove_from_group(&"player")
	controlled_presentation = null


func _assign_control(actor: Actor, presentation: ActorPresentation) -> void:
	controlled_actor = actor
	controlled_presentation = presentation
	controlled_presentation.add_to_group(&"player")
	_sync_camera_position(true)


func stop() -> void:
	if is_instance_valid(controlled_presentation):
		controlled_presentation.velocity = Vector2.ZERO


func set_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()


func request_interaction() -> ActionResult:
	if controlled_actor == null or not is_instance_valid(controlled_presentation):
		var unavailable_result := ActionResult.failed(
			&"interact",
			&"",
			"当前没有可控制的角色表现。",
			&"controlled_presentation_unavailable"
		)
		action_completed.emit(unavailable_result)
		return unavailable_result

	controlled_presentation.sync_state_from_presentation()
	var target := InteractionTargetSelector.select_target(controlled_presentation)
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

	var action := WorldAction.new(action_id, controlled_actor, target)
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
	var next_facing := controlled_presentation.facing
	if absf(direction.x) > absf(direction.y):
		next_facing = (
			ActorState.Facing.RIGHT if direction.x > 0.0 else ActorState.Facing.LEFT
		)
	else:
		next_facing = (
			ActorState.Facing.DOWN if direction.y > 0.0 else ActorState.Facing.UP
		)

	if next_facing != controlled_presentation.facing:
		controlled_presentation.facing = next_facing


func _sync_camera_position(reset_smoothing := false) -> void:
	if not is_instance_valid(controlled_presentation):
		return
	global_position = controlled_presentation.global_position
	if reset_smoothing:
		reset_physics_interpolation()
		camera.reset_smoothing()
