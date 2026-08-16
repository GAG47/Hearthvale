extends SceneTree

const LOADER := preload("res://scripts/actors/actor_definition_loader.gd")

const PLAYER_PATH := "res://data/actors/player.json"
const MARTHA_PATH := "res://data/actors/martha.json"
const FIXTURE_DIRECTORY := "res://tests/entities/fixtures/actors/"
const VISUAL_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]

var _checks := 0
var _failures := 0


func _init() -> void:
	_disable_project_autoloads()

	_test_valid_definition(
		PLAYER_PATH,
		&"5e05b833-0645-4c13-8713-4c8767a7efe3",
		"玩家",
		{
			"up": "res://assets/actors/player_up.svg",
			"down": "res://assets/actors/player_down.svg",
			"left": "res://assets/actors/player_left.svg",
			"right": "res://assets/actors/player_right.svg",
		}
	)
	_test_valid_definition(
		MARTHA_PATH,
		&"90da2d88-d049-4519-9e5c-e35136ff6a7d",
		"Martha",
		{
			"up": "res://assets/actors/martha_up.svg",
			"down": "res://assets/actors/martha_down.svg",
			"left": "res://assets/actors/martha_left.svg",
			"right": "res://assets/actors/martha_right.svg",
		}
	)

	_test_invalid_definition(FIXTURE_DIRECTORY + "does_not_exist.json")
	for fixture_name in [
		"malformed_json.json",
		"root_not_dictionary.json",
		"missing_definition_id.json",
		"definition_id_wrong_type.json",
		"invalid_v4_uuid.json",
		"missing_display_name.json",
		"display_name_wrong_type.json",
		"empty_display_name.json",
		"whitespace_display_name.json",
		"missing_visuals.json",
		"visuals_wrong_type.json",
		"missing_visual_up.json",
		"missing_visual_down.json",
		"missing_visual_left.json",
		"missing_visual_right.json",
		"visual_up_wrong_type.json",
		"visual_down_empty.json",
		"visual_left_whitespace.json",
		"visual_right_missing_resource.json",
		"visual_right_not_texture.json",
	]:
		_test_invalid_definition(FIXTURE_DIRECTORY + fixture_name)

	if _failures == 0:
		print("ActorDefinitionLoader: %d checks passed." % _checks)
		quit(0)
		return

	push_error(
		"ActorDefinitionLoader: %d of %d checks failed." % [_failures, _checks]
	)
	quit(1)


func _disable_project_autoloads() -> void:
	for autoload_name in [
		"DefinitionRegistry",
		"WorldDefinition",
		"WorldState",
		"EntityRegistry",
		"WorldTime",
	]:
		ProjectSettings.set_setting("autoload/%s" % autoload_name, null)


func _test_valid_definition(
	path: String,
	expected_definition_id: StringName,
	expected_display_name: String,
	expected_visuals: Dictionary
) -> void:
	var definition := LOADER.load_from_file(path)
	_expect(definition != null, "%s should load successfully." % path)
	if definition == null:
		return

	_expect(
		definition.definition_id == expected_definition_id,
		"%s should preserve definition_id." % path
	)
	_expect(
		definition.display_name == expected_display_name,
		"%s should preserve display_name." % path
	)
	_expect(
		definition.visuals.size() == VISUAL_DIRECTIONS.size(),
		"%s should contain exactly four directional visuals." % path
	)
	for direction: String in VISUAL_DIRECTIONS:
		_expect(
			definition.visuals.has(direction),
			"%s should preserve visuals.%s." % [path, direction]
		)
		if not definition.visuals.has(direction):
			continue
		_expect(
			definition.visuals[direction] == expected_visuals[direction],
			"%s should preserve visuals.%s path." % [path, direction]
		)
		var visual_resource := ResourceLoader.load(definition.visuals[direction])
		_expect(
			visual_resource is Texture2D,
			"%s visuals.%s should load as Texture2D." % [path, direction]
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
