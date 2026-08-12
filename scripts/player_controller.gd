class_name PlayerController
extends Node2D

signal action_completed(result: ActionResult)

@export var move_speed := 140.0

@onready var camera: Camera2D = $Camera2D

var controlled_character: Character
var controlled_presentation: CharacterPresentation


func _physics_process(_delta: float) -> void:
	if controlled_character == null or not is_instance_valid(controlled_presentation):
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


func take_control(character: Character, presentation: CharacterPresentation) -> bool:
	if character == null or not is_instance_valid(presentation):
		push_error("PlayerController requires a Character and CharacterPresentation.")
		return false
	if presentation.character != character:
		push_error(
			"PlayerController cannot bind Character '%s' to a Presentation for Character '%s'."
			% [character.character_id, presentation.character_id]
		)
		return false

	release_controlled_presentation()
	controlled_character = character
	controlled_presentation = presentation
	controlled_presentation.add_to_group(&"player")
	_sync_camera_position(true)
	return true


func release_controlled_presentation() -> void:
	if is_instance_valid(controlled_presentation):
		controlled_presentation.velocity = Vector2.ZERO
		controlled_presentation.sync_state_from_presentation()
		controlled_presentation.remove_from_group(&"player")
	controlled_presentation = null


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
	if controlled_character == null or not is_instance_valid(controlled_presentation):
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

	var action_id := target.get_primary_action(controlled_character)
	if action_id.is_empty():
		var no_action_result := ActionResult.failed(
			&"interact",
			target.object_id,
			"%s 当前没有可用行为。" % target.display_name
		)
		action_completed.emit(no_action_result)
		return no_action_result

	var action := WorldAction.new(action_id, controlled_character, target)
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
			CharacterState.Facing.RIGHT if direction.x > 0.0 else CharacterState.Facing.LEFT
		)
	else:
		next_facing = (
			CharacterState.Facing.DOWN if direction.y > 0.0 else CharacterState.Facing.UP
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
