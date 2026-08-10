class_name PlayerCharacter
extends CharacterPresentation

signal action_completed(result: ActionResult)

@export var move_speed := 140.0

@onready var camera: Camera2D = $Camera2D


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"interact"):
		request_interaction()

	var input_direction := _get_input_direction()
	velocity = input_direction * move_speed

	if not input_direction.is_zero_approx():
		_update_facing(input_direction)

	move_and_slide()
	sync_state_from_presentation()


func stop() -> void:
	velocity = Vector2.ZERO


func set_camera_bounds(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()


func request_interaction() -> ActionResult:
	sync_state_from_presentation()
	var target := InteractionTargetSelector.select_target(self)
	if target == null:
		var no_target_result := ActionResult.failed(&"interact", &"", "前方没有可交互的对象。")
		action_completed.emit(no_target_result)
		return no_target_result

	var action_id := target.get_primary_action(character)
	if action_id.is_empty():
		var no_action_result := ActionResult.failed(&"interact", target.object_id, "%s 当前没有可用行为。" % target.display_name)
		action_completed.emit(no_action_result)
		return no_action_result

	var action := WorldAction.new(action_id, character, target)
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
	var next_facing := facing
	if absf(direction.x) > absf(direction.y):
		next_facing = CharacterState.Facing.RIGHT if direction.x > 0.0 else CharacterState.Facing.LEFT
	else:
		next_facing = CharacterState.Facing.DOWN if direction.y > 0.0 else CharacterState.Facing.UP

	if next_facing != facing:
		facing = next_facing
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0.0, 7.0), 11.0, Color(0.08, 0.07, 0.07, 0.30))
	draw_circle(Vector2.ZERO, 11.0, Color("#315a79"))
	draw_circle(Vector2.ZERO, 8.0, Color("#4f86a6"))

	var facing_vector := get_facing_vector()
	var side := facing_vector.orthogonal()
	draw_colored_polygon(
		PackedVector2Array([
			facing_vector * 13.0,
			facing_vector * 4.0 + side * 5.0,
			facing_vector * 4.0 - side * 5.0,
		]),
		Color("#f3ddb2")
	)
