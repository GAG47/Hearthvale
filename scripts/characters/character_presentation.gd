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
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("CharacterPresentation requires a Sprite2D child.")
		return false
	var direction_indicator := get_node_or_null("DirectionIndicator") as Polygon2D
	if direction_indicator == null:
		push_error("CharacterPresentation requires a DirectionIndicator child.")
		return false
	var visual_ref := p_character.definition.visual_ref
	if not ResourceLoader.exists(visual_ref):
		push_error(
			"Character '%s' visual_ref '%s' does not exist."
			% [p_character.character_id, visual_ref]
		)
		return false
	var visual_resource := ResourceLoader.load(visual_ref)
	if not visual_resource is Texture2D:
		push_error(
			"Character '%s' visual_ref '%s' did not load as a Texture2D."
			% [p_character.character_id, visual_ref]
		)
		return false

	character = p_character
	current_location = location
	position = character.state.local_position
	sprite.texture = visual_resource
	_update_facing_visual()
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


func _update_facing_visual() -> void:
	var direction_indicator := get_node_or_null("DirectionIndicator") as Polygon2D
	if direction_indicator == null:
		return
	var facing_vector := get_facing_vector()
	direction_indicator.position = facing_vector * 12.0
	direction_indicator.rotation = facing_vector.angle() - Vector2.DOWN.angle()


func _exit_tree() -> void:
	sync_state_from_presentation()
