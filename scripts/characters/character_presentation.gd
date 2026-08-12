class_name CharacterPresentation
extends CharacterBody2D

var character: Character
var current_location: GridScene

var character_id: StringName:
	get:
		return character.character_id if character != null else &""

var facing: CharacterState.Facing:
	get:
		return character.state.facing if character != null else CharacterState.Facing.DOWN
	set(value):
		if character != null:
			character.state.facing = value
		queue_redraw()

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


func bind_character(p_character: Character, location: GridScene) -> bool:
	if p_character == null or location == null:
		push_error("CharacterPresentation requires a Character and a loaded GridScene.")
		return false
	if p_character.definition.character_id != p_character.state.character_id:
		push_error(
			"Character Definition ID '%s' does not match CharacterState ID '%s'."
			% [p_character.definition.character_id, p_character.state.character_id]
		)
		return false
	if p_character.state.current_location_id != location.location_id:
		push_error(
			"Character '%s' state belongs to Location '%s', but its presentation was requested in Location '%s'."
			% [
				p_character.character_id,
				p_character.state.current_location_id,
				location.location_id,
			]
		)
		return false

	character = p_character
	current_location = location
	position = character.state.local_position
	queue_redraw()
	return true


func sync_state_from_presentation() -> void:
	if character == null or not is_instance_valid(current_location):
		return
	character.state.current_location_id = current_location.location_id
	character.state.local_position = position


func get_front_cell() -> Vector2i:
	return current_cell + get_facing_cell_offset()


func get_facing_cell_offset() -> Vector2i:
	match facing:
		CharacterState.Facing.UP:
			return Vector2i.UP
		CharacterState.Facing.LEFT:
			return Vector2i.LEFT
		CharacterState.Facing.RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN


func get_facing_vector() -> Vector2:
	return Vector2(get_facing_cell_offset())


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


func _exit_tree() -> void:
	sync_state_from_presentation()
