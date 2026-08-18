extends SceneTree

const PLAYER_PATH := "res://data/actors/player.tres"
const MARTHA_PATH := "res://data/actors/martha.tres"

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_definition(
		PLAYER_PATH,
		"玩家",
		{
			&"up": "res://assets/actors/player_up.svg",
			&"down": "res://assets/actors/player_down.svg",
			&"left": "res://assets/actors/player_left.svg",
			&"right": "res://assets/actors/player_right.svg",
		}
	)
	_test_definition(
		MARTHA_PATH,
		"Martha",
		{
			&"up": "res://assets/actors/martha_up.svg",
			&"down": "res://assets/actors/martha_down.svg",
			&"left": "res://assets/actors/martha_left.svg",
			&"right": "res://assets/actors/martha_right.svg",
		}
	)
	_expect(
		not FileAccess.file_exists("res://scripts/actors/actor_definition_loader.gd")
		and not FileAccess.file_exists("res://data/actors/player.json")
		and not FileAccess.file_exists("res://data/actors/martha.json"),
		"Actor Project Definitions must have a single Resource source."
	)
	_finish()


func _test_definition(path: String, expected_name: String, expected_visuals: Dictionary) -> void:
	var definition := load(path) as ActorDefinition
	_expect(definition != null, "%s must load as ActorDefinition." % path)
	if definition == null:
		return
	_expect(definition is Resource, "%s must be a Godot Resource." % path)
	_expect(definition.display_name == expected_name, "%s must preserve display_name." % path)
	_expect(is_equal_approx(definition.move_speed, 140.0), "%s must store the shared base move_speed." % path)
	_expect(not _has_property(definition, &"definition_id"), "%s must not store a Definition UUID." % path)
	_expect(definition.use_slots.is_empty(), "%s must support an empty typed UseSlot Resource list." % path)
	for direction in ActorDefinition.VISUAL_DIRECTIONS:
		var visual := definition.get_visual(direction)
		_expect(visual is Texture2D, "%s visual_%s must directly reference Texture2D." % [path, direction])
		_expect(visual.resource_path == expected_visuals[direction], "%s visual_%s must preserve its asset." % [path, direction])


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("ActorDefinition Resource: %d checks passed." % _checks)
		quit(0)
		return
	push_error("ActorDefinition Resource: %d of %d checks failed." % [_failures, _checks])
	quit(1)
