extends SceneTree

const LOADER := preload("res://scripts/furniture/furniture_definition_loader.gd")

var _checks := 0
var _failures := 0


func _init() -> void:
	_disable_project_autoloads()
	_test_definition(
		"res://data/furniture/simple_bed.json",
		&"c2a6e4b8-1d73-4c5f-9a0e-7b3d8f21e654",
		"床",
		"sleepable",
		Vector2i(1, 2)
	)
	_test_definition(
		"res://data/furniture/wooden_chest.json",
		&"7f45a0d2-2ff2-4f1c-8b7a-3d7d0dd5b8a1",
		"储物箱",
		"openable",
		Vector2i.ONE
	)
	_test_definition(
		"res://data/furniture/sign.json",
		&"9c4b72f1-bd0e-4f67-a5d2-6e5b1f9c3a20",
		"告示牌",
		"inspectable",
		Vector2i.ONE
	)
	for fixture in [
		"missing_definition_id.json",
		"invalid_definition_id.json",
		"missing_behaviors.json",
		"visual_not_texture.json",
		"unsupported_behavior.json",
		"invalid_occupied_cells.json",
	]:
		_expect(
			LOADER.load_from_file("res://tests/entities/fixtures/furniture/" + fixture) == null,
			"%s must fail validation." % fixture
		)
	_finish()


func _test_definition(
	path: String,
	expected_id: StringName,
	expected_name: String,
	expected_behavior: String,
	expected_cells: Vector2i
) -> void:
	var definition := LOADER.load_from_file(path)
	_expect(definition != null, "%s must load." % path)
	if definition == null:
		return
	_expect(definition.definition_id == expected_id, "%s definition_id must match." % path)
	_expect(UuidValidator.is_valid_v4(definition.definition_id), "%s definition_id must be UUID v4." % path)
	_expect(definition.display_name == expected_name, "%s display_name must match." % path)
	_expect(definition.behaviors.has(expected_behavior), "%s behavior must load." % path)
	_expect(definition.occupied_cells == expected_cells, "%s occupied cells must match." % path)
	_expect(ResourceLoader.load(definition.visual_ref) is Texture2D, "%s visual must be Texture2D." % path)


func _disable_project_autoloads() -> void:
	for autoload_name in [
		"WorldDefinition",
		"WorldState",
		"EntityRegistry",
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
		print("FurnitureDefinitionLoader: %d checks passed." % _checks)
		quit(0)
		return
	push_error("FurnitureDefinitionLoader: %d of %d checks failed." % [_failures, _checks])
	quit(1)
