extends SceneTree

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_definition(
		"res://data/furniture/simple_bed.tres",
		"床",
		SleepableBehavior,
		Vector2i(1, 2),
		"res://assets/furniture/bed.svg"
	)
	_test_definition(
		"res://data/furniture/wooden_chest.tres",
		"储物箱",
		OpenableBehavior,
		Vector2i.ONE,
		"res://assets/furniture/chest_closed.svg"
	)
	_test_definition(
		"res://data/furniture/sign.tres",
		"告示牌",
		InspectableBehavior,
		Vector2i.ONE,
		"res://assets/furniture/sign.svg"
	)
	var chest := load("res://data/furniture/wooden_chest.tres") as FurnitureDefinition
	var openable := chest.behaviors[0] as OpenableBehavior
	_expect(
		openable != null
		and openable.open_visual.resource_path == "res://assets/furniture/chest_open.svg",
		"Chest OpenableBehavior must directly reference its open Texture2D."
	)
	var sign := load("res://data/furniture/sign.tres") as FurnitureDefinition
	var inspectable := sign.behaviors[0] as InspectableBehavior
	_expect(
		inspectable != null and inspectable.text == "今日麦酒三铜币。",
		"Sign InspectableBehavior must preserve its typed text field."
	)
	_expect(
		not FileAccess.file_exists("res://scripts/furniture/furniture_definition_loader.gd")
		and not FileAccess.file_exists("res://data/furniture/wooden_chest.json"),
		"Furniture Project Definitions must have a single Resource source."
	)
	_finish()


func _test_definition(
	path: String,
	expected_name: String,
	expected_behavior_script: Script,
	expected_cells: Vector2i,
	expected_visual_path: String
) -> void:
	var definition := load(path) as FurnitureDefinition
	_expect(definition != null, "%s must load as FurnitureDefinition." % path)
	if definition == null:
		return
	_expect(definition is Resource, "%s must be a Godot Resource." % path)
	_expect(definition.display_name == expected_name, "%s must preserve display_name." % path)
	_expect(definition.occupied_cells == expected_cells, "%s must preserve occupied_cells." % path)
	_expect(definition.visual.resource_path == expected_visual_path, "%s must directly reference its Texture2D." % path)
	_expect(definition.behaviors.size() == 1, "%s must preserve one Behavior Resource." % path)
	_expect(definition.use_slots.is_empty(), "%s must remain valid without explicit UseSlot data." % path)
	if not definition.behaviors.is_empty():
		_expect(is_instance_of(definition.behaviors[0], expected_behavior_script), "%s must preserve its concrete Behavior Resource." % path)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("FurnitureDefinition Resource: %d checks passed." % _checks)
		quit(0)
		return
	push_error("FurnitureDefinition Resource: %d of %d checks failed." % [_failures, _checks])
	quit(1)
