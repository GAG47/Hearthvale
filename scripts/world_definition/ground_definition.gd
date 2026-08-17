class_name GroundDefinition
extends Definition

var _key: StringName
var _walkable: bool
var _movement_cost: float
var _presentation: Dictionary

var key: StringName:
	get:
		return _key
var walkable: bool:
	get:
		return _walkable
var movement_cost: float:
	get:
		return _movement_cost
var presentation: Dictionary:
	get:
		return _presentation.duplicate(true)


func _init(
	p_definition_id: StringName,
	p_key: StringName,
	p_walkable: bool,
	p_movement_cost: float,
	p_presentation: Dictionary
) -> void:
	super(p_definition_id)
	_key = p_key
	_walkable = p_walkable
	_movement_cost = p_movement_cost
	_presentation = p_presentation.duplicate(true)


func get_definition_type() -> StringName:
	return &"ground"
