extends SceneTree

const REGISTRY_SCRIPT := preload("res://scripts/characters/character_registry.gd")

const FIRST_ID := &"11111111-1111-4111-8111-111111111111"
const SECOND_ID := &"00000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0


func _init() -> void:
	_disable_project_autoloads()
	_run_tests()
	_finish()


func _run_tests() -> void:
	var registry := REGISTRY_SCRIPT.new()
	_expect(registry.get_characters().is_empty(), "A new Registry must not create Characters.")
	_expect(not registry.register_character(null), "A null Character must be rejected.")

	var missing_definition := Character.new(
		null,
		CharacterState.new(FIRST_ID, &"nowhere", Vector2.ZERO)
	)
	_expect(
		not registry.register_character(missing_definition),
		"A Character without a Definition must be rejected."
	)

	var first := _create_character(FIRST_ID, &"nowhere")
	_expect(
		registry.register_character(first),
		"A logically valid Character must register without Location or Presentation validation."
	)
	_expect(registry.has_character(FIRST_ID), "has_character must find a registered Character.")
	_expect(registry.get_character(FIRST_ID) == first, "get_character must return the same Character.")
	_expect(
		not registry.register_character(first),
		"A duplicate character_id must be rejected."
	)

	var mismatched := Character.new(
		CharacterDefinition.new(FIRST_ID, "Mismatch", "res://missing-presentation.tscn"),
		CharacterState.new(SECOND_ID, &"nowhere", Vector2.ZERO)
	)
	_expect(
		not registry.register_character(mismatched),
		"Definition and State IDs must match."
	)

	var invalid_definition_id := Character.new(
		CharacterDefinition.new(&"not-a-uuid", "Invalid", "res://missing-presentation.tscn"),
		CharacterState.new(&"not-a-uuid", &"nowhere", Vector2.ZERO)
	)
	_expect(
		not registry.register_character(invalid_definition_id),
		"An invalid Definition UUID must be rejected."
	)

	var invalid_state_id := Character.new(
		CharacterDefinition.new(SECOND_ID, "Invalid State", "res://missing-presentation.tscn"),
		CharacterState.new(&"not-a-uuid", &"nowhere", Vector2.ZERO)
	)
	_expect(
		not registry.register_character(invalid_state_id),
		"An invalid State UUID must be rejected."
	)

	var second := _create_character(SECOND_ID, &"elsewhere")
	_expect(registry.register_character(second), "A second unique Character must register.")
	var characters := registry.get_characters()
	_expect(characters.size() == 2, "get_characters must return every Character.")
	_expect(
		characters.size() == 2 and characters[0] == second and characters[1] == first,
		"get_characters must return Characters in stable character_id order."
	)

	var nowhere_characters := registry.get_characters_in_location(&"nowhere")
	_expect(
		nowhere_characters.size() == 1 and nowhere_characters[0] == first,
		"get_characters_in_location must query CharacterState without a second index."
	)
	_expect(
		registry.get_characters_in_location(&"unknown").is_empty(),
		"An unknown Location query must return no Characters."
	)
	registry.free()


func _create_character(character_id: StringName, location_id: StringName) -> Character:
	return Character.new(
		CharacterDefinition.new(
			character_id,
			"Test Character",
			"res://missing-presentation.tscn"
		),
		CharacterState.new(character_id, location_id, Vector2(32.0, 64.0))
	)


func _disable_project_autoloads() -> void:
	for autoload_name in [
		"WorldDefinition",
		"WorldState",
		"CharacterRegistry",
		"WorldTime",
	]:
		ProjectSettings.set_setting("autoload/%s" % autoload_name, null)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("CharacterRegistry: %d checks passed." % _checks)
		quit(0)
		return

	push_error("CharacterRegistry: %d of %d checks failed." % [_failures, _checks])
	quit(1)
