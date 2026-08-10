class_name CharacterRegistryRuntime
extends Node

const PLAYER_CHARACTER_ID := &"5e05b833-0645-4c13-8713-4c8767a7efe3"
const MARTHA_CHARACTER_ID := &"90da2d88-d049-4519-9e5c-e35136ff6a7d"

var _characters: Dictionary[StringName, Character] = {}

var world_definition: WorldDefinitionRuntime
var world_state: WorldStateRuntime


func _ready() -> void:
	world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	world_state = get_node_or_null("/root/WorldState") as WorldStateRuntime
	if world_definition == null or world_state == null:
		push_error("CharacterRegistry requires WorldDefinition and WorldState Autoloads.")
		return

	var initial_states := _create_initial_character_states()
	for definition in _create_preset_character_definitions():
		var state := world_state.get_character_state(definition.character_id)
		if state == null:
			state = initial_states.get(definition.character_id) as CharacterState
		if state == null:
			push_error(
				"Preset Character '%s' has no existing or initial CharacterState."
				% definition.character_id
			)
			continue
		register_character(definition, state)


func register_character(definition: CharacterDefinition, state: CharacterState) -> bool:
	if not _validate_character(definition, state):
		return false
	if _characters.has(definition.character_id):
		push_error("CharacterRegistry already contains character_id '%s'." % definition.character_id)
		return false
	if not world_state.register_character_state(state):
		return false

	_characters[definition.character_id] = Character.new(definition, state)
	return true


func has_character(character_id: StringName) -> bool:
	return _characters.has(character_id)


func get_character(character_id: StringName) -> Character:
	if not _characters.has(character_id):
		push_error("CharacterRegistry has no Character with character_id '%s'." % character_id)
		return null
	return _characters[character_id]


func get_characters() -> Array[Character]:
	var characters: Array[Character] = []
	var character_ids := _characters.keys()
	character_ids.sort()
	for character_id in character_ids:
		characters.append(_characters[character_id])
	return characters


func get_characters_in_location(location_id: StringName) -> Array[Character]:
	var characters: Array[Character] = []
	for character in get_characters():
		if character.state.current_location_id == location_id:
			characters.append(character)
	return characters


func _validate_character(definition: CharacterDefinition, state: CharacterState) -> bool:
	if definition == null or state == null:
		push_error("Character registration requires CharacterDefinition and CharacterState.")
		return false
	if definition.character_id != state.character_id:
		push_error(
			"CharacterDefinition ID '%s' does not match CharacterState ID '%s'."
			% [definition.character_id, state.character_id]
		)
		return false
	if not UuidValidator.is_valid_v4(definition.character_id):
		push_error("Character character_id '%s' is not a valid UUID v4." % definition.character_id)
		return false
	if definition.display_name.is_empty():
		push_error("Character '%s' requires a non-empty display_name." % definition.character_id)
		return false
	if not world_definition.has_location(state.current_location_id):
		push_error(
			"Character '%s' state references unknown current_location_id '%s'."
			% [definition.character_id, state.current_location_id]
		)
		return false
	if not ResourceLoader.exists(definition.presentation_ref, "PackedScene"):
		push_error(
			"Character '%s' presentation_ref '%s' does not exist as a PackedScene."
			% [definition.character_id, definition.presentation_ref]
		)
		return false

	var packed_scene := load(definition.presentation_ref) as PackedScene
	var presentation := packed_scene.instantiate() as CharacterPresentation
	if presentation == null:
		push_error(
			"Character '%s' presentation_ref '%s' does not instantiate as CharacterPresentation."
			% [definition.character_id, definition.presentation_ref]
		)
		return false
	presentation.free()
	return true


func _create_preset_character_definitions() -> Array[CharacterDefinition]:
	return [
		CharacterDefinition.new(
			PLAYER_CHARACTER_ID,
			"玩家",
			"res://scenes/player.tscn"
		),
		CharacterDefinition.new(
			MARTHA_CHARACTER_ID,
			"Martha",
			"res://scenes/characters/villager.tscn"
		),
	]


func _create_initial_character_states() -> Dictionary[StringName, CharacterState]:
	return {
		PLAYER_CHARACTER_ID: CharacterState.new(
			PLAYER_CHARACTER_ID,
			&"tavern",
			Vector2(384.0, 256.0),
			CharacterState.Facing.DOWN
		),
		MARTHA_CHARACTER_ID: CharacterState.new(
			MARTHA_CHARACTER_ID,
			&"tavern_yard",
			Vector2(288.0, 288.0),
			CharacterState.Facing.LEFT
		),
	}
