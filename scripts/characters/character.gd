class_name Character
extends RefCounted

var definition: CharacterDefinition
var state: CharacterState

var character_id: StringName:
	get:
		return definition.character_id

var current_location_id: StringName:
	get:
		return state.current_location_id

var local_position: Vector2:
	get:
		return state.local_position

var facing: CharacterState.Facing:
	get:
		return state.facing

var current_cell: Vector2i:
	get:
		return Vector2i(
			floori(state.local_position.x / GridScene.CELL_SIZE),
			floori(state.local_position.y / GridScene.CELL_SIZE)
		)


func _init(p_definition: CharacterDefinition, p_state: CharacterState) -> void:
	definition = p_definition
	state = p_state


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
