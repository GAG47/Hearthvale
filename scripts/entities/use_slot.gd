@tool
class_name UseSlot
extends Resource

@export var local_cell := Vector2i.ZERO
@export var required_facing: ActorState.Facing = ActorState.Facing.NONE
@export var supported_actions: Array[StringName] = []
@export var slot_entrances: Array[SlotEntrance] = []


func _init(
	p_local_cell: Vector2i = Vector2i.ZERO,
	p_required_facing: ActorState.Facing = ActorState.Facing.NONE,
	p_supported_actions: Array[StringName] = [],
	p_slot_entrances: Array[SlotEntrance] = []
) -> void:
	local_cell = p_local_cell
	required_facing = p_required_facing
	supported_actions = p_supported_actions.duplicate()
	slot_entrances = p_slot_entrances.duplicate()


func supports_action(action_id: StringName) -> bool:
	return not action_id.is_empty() and supported_actions.has(action_id)


func is_facing_allowed(facing: ActorState.Facing) -> bool:
	return required_facing == ActorState.Facing.NONE or required_facing == facing


func get_slot_entrances() -> Array[SlotEntrance]:
	var entrances: Array[SlotEntrance] = []
	for entrance in slot_entrances:
		if entrance != null:
			entrances.append(entrance)
	if entrances.is_empty():
		entrances.append(SlotEntrance.new(local_cell))
	return entrances


func get_entrances() -> Array[SlotEntrance]:
	return get_slot_entrances()
