class_name CharacterRegistryRuntime
extends Node

var _characters: Dictionary[StringName, Character] = {}


func register_character(character: Character) -> bool:
	if not _validate_character(character):
		return false
	if _characters.has(character.character_id):
		push_error("CharacterRegistry already contains character_id '%s'." % character.character_id)
		return false

	_characters[character.character_id] = character
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


func _validate_character(character: Character) -> bool:
	if character == null:
		push_error("Character registration requires a Character.")
		return false
	if character.definition == null or character.state == null:
		push_error("Character registration requires CharacterDefinition and CharacterState.")
		return false
	if not UuidValidator.is_valid_v4(character.definition.character_id):
		push_error(
			"CharacterDefinition character_id '%s' is not a valid UUID v4."
			% character.definition.character_id
		)
		return false
	if not UuidValidator.is_valid_v4(character.state.character_id):
		push_error(
			"CharacterState character_id '%s' is not a valid UUID v4."
			% character.state.character_id
		)
		return false
	if character.definition.character_id != character.state.character_id:
		push_error(
			"CharacterDefinition ID '%s' does not match CharacterState ID '%s'."
			% [character.definition.character_id, character.state.character_id]
		)
		return false
	return true
