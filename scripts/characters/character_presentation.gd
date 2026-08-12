class_name CharacterPresentation
extends CharacterBody2D

const VISUAL_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var character: Character
var current_location: GridScene
var _visual_textures: Dictionary[String, Texture2D] = {}

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
	var loaded_visual_textures := _load_visual_textures(p_character)
	if loaded_visual_textures.size() != VISUAL_DIRECTIONS.size():
		return false

	character = p_character
	current_location = location
	_visual_textures = loaded_visual_textures
	position = character.state.local_position
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
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or character == null:
		return
	var direction := _get_facing_direction()
	if not _visual_textures.has(direction):
		push_error(
			"Character '%s' has no loaded visual for direction '%s'."
			% [character.character_id, direction]
		)
		return
	sprite.texture = _visual_textures[direction]


func _load_visual_textures(p_character: Character) -> Dictionary[String, Texture2D]:
	var textures: Dictionary[String, Texture2D] = {}
	for direction: String in VISUAL_DIRECTIONS:
		if not p_character.definition.visuals.has(direction):
			push_error(
				"Character '%s' visuals is missing direction '%s'."
				% [p_character.character_id, direction]
			)
			return textures
		var visual_path: String = p_character.definition.visuals[direction]
		if not ResourceLoader.exists(visual_path):
			push_error(
				"Character '%s' visuals.%s '%s' does not exist."
				% [p_character.character_id, direction, visual_path]
			)
			return textures
		var visual_resource := ResourceLoader.load(visual_path)
		if not visual_resource is Texture2D:
			push_error(
				"Character '%s' visuals.%s '%s' did not load as a Texture2D."
				% [p_character.character_id, direction, visual_path]
			)
			return textures
		textures[direction] = visual_resource
	return textures


func _get_facing_direction() -> String:
	match facing:
		CharacterState.Facing.UP:
			return "up"
		CharacterState.Facing.LEFT:
			return "left"
		CharacterState.Facing.RIGHT:
			return "right"
		_:
			return "down"


func _exit_tree() -> void:
	sync_state_from_presentation()
