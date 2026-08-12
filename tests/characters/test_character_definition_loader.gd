extends SceneTree

const LOADER := preload("res://scripts/characters/character_definition_loader.gd")

const PLAYER_PATH := "res://data/characters/player.json"
const MARTHA_PATH := "res://data/characters/martha.json"
const FIXTURE_DIRECTORY := "res://tests/characters/fixtures/"

var _checks := 0
var _failures := 0


func _init() -> void:
	_disable_project_autoloads()

	_test_valid_definition(
		PLAYER_PATH,
		&"5e05b833-0645-4c13-8713-4c8767a7efe3",
		"玩家",
		"res://scenes/player.tscn"
	)
	_test_valid_definition(
		MARTHA_PATH,
		&"90da2d88-d049-4519-9e5c-e35136ff6a7d",
		"Martha",
		"res://scenes/characters/villager.tscn"
	)

	_test_invalid_definition("res://tests/characters/fixtures/does_not_exist.json")
	for fixture_name in [
		"malformed_json.json",
		"root_not_dictionary.json",
		"missing_character_id.json",
		"character_id_wrong_type.json",
		"invalid_v4_uuid.json",
		"missing_display_name.json",
		"display_name_wrong_type.json",
		"empty_display_name.json",
		"whitespace_display_name.json",
		"missing_presentation_ref.json",
		"presentation_ref_wrong_type.json",
		"empty_presentation_ref.json",
		"missing_presentation_resource.json",
	]:
		_test_invalid_definition(FIXTURE_DIRECTORY + fixture_name)

	if _failures == 0:
		print("CharacterDefinitionLoader: %d checks passed." % _checks)
		quit(0)
		return

	push_error(
		"CharacterDefinitionLoader: %d of %d checks failed." % [_failures, _checks]
	)
	quit(1)


func _disable_project_autoloads() -> void:
	for autoload_name in [
		"WorldDefinition",
		"WorldState",
		"CharacterRegistry",
		"WorldTime",
	]:
		ProjectSettings.set_setting("autoload/%s" % autoload_name, null)


func _test_valid_definition(
	path: String,
	expected_character_id: StringName,
	expected_display_name: String,
	expected_presentation_ref: String
) -> void:
	var definition := LOADER.load_from_file(path)
	_expect(definition != null, "%s should load successfully." % path)
	if definition == null:
		return

	_expect(
		definition.character_id == expected_character_id,
		"%s should preserve character_id." % path
	)
	_expect(
		definition.display_name == expected_display_name,
		"%s should preserve display_name." % path
	)
	_expect(
		definition.presentation_ref == expected_presentation_ref,
		"%s should preserve presentation_ref." % path
	)


func _test_invalid_definition(path: String) -> void:
	var definition := LOADER.load_from_file(path)
	_expect(definition == null, "%s should fail to load." % path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)
