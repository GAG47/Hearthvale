@tool
class_name UseSlot
extends Resource

enum FacingMask {
	UP = 1,
	DOWN = 2,
	LEFT = 4,
	RIGHT = 8,
}

const ALL_FACINGS := FacingMask.UP | FacingMask.DOWN | FacingMask.LEFT | FacingMask.RIGHT

@export var local_cell := Vector2i.ZERO
@export_flags("UP", "DOWN", "LEFT", "RIGHT") var allowed_facings: int = 0
@export var supported_actions: Array[StringName] = []
@export var slot_entrances: Array[SlotEntrance] = []


func _init(
	p_local_cell: Vector2i = Vector2i.ZERO,
	p_allowed_facings: int = 0,
	p_supported_actions: Array[StringName] = [],
	p_slot_entrances: Array[SlotEntrance] = []
) -> void:
	local_cell = p_local_cell
	allowed_facings = p_allowed_facings
	supported_actions = p_supported_actions.duplicate()
	slot_entrances = p_slot_entrances.duplicate()


func supports_action(action_id: StringName) -> bool:
	return not action_id.is_empty() and supported_actions.has(action_id)


func is_facing_allowed(facing: ActorState.Facing) -> bool:
	if allowed_facings == 0:
		return facing != ActorState.Facing.NONE
	return (allowed_facings & facing_mask(facing)) != 0


func has_facing_restriction() -> bool:
	return allowed_facings != 0


static func facing_mask(facing: ActorState.Facing) -> int:
	match facing:
		ActorState.Facing.UP:
			return FacingMask.UP
		ActorState.Facing.DOWN:
			return FacingMask.DOWN
		ActorState.Facing.LEFT:
			return FacingMask.LEFT
		ActorState.Facing.RIGHT:
			return FacingMask.RIGHT
		_:
			return 0


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
