class_name FurnitureState
extends EntityState

var behavior_states: Dictionary[StringName, BehaviorState] = {}


func _init(
	p_instance_id: StringName,
	p_current_location_id: StringName,
	p_local_cell: Vector2i,
	p_behavior_states: Dictionary[StringName, BehaviorState] = {}
) -> void:
	super(p_instance_id, p_current_location_id, p_local_cell)
	for behavior_id in p_behavior_states:
		behavior_states[behavior_id] = p_behavior_states[behavior_id]
