class_name EntityUseSlot
extends RefCounted

var entity_id: StringName
var cell: Vector2i
var required_facing: ActorState.Facing
var supported_actions: Array[StringName]
var explicitly_defined: bool


func _init(
	p_entity_id: StringName,
	p_cell: Vector2i,
	p_required_facing: ActorState.Facing,
	p_supported_actions: Array[StringName],
	p_explicitly_defined: bool
) -> void:
	entity_id = p_entity_id
	cell = p_cell
	required_facing = p_required_facing
	supported_actions = p_supported_actions.duplicate()
	explicitly_defined = p_explicitly_defined


func supports_action(action_id: StringName) -> bool:
	return supported_actions.has(action_id)
