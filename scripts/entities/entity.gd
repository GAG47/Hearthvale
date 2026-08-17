@abstract
class_name Entity
extends RefCounted

var state: EntityState

var instance_id: StringName:
	get:
		return state.instance_id if state != null else &""

var definition_id: StringName:
	get:
		return state.definition_id if state != null else &""

var current_location_id: StringName:
	get:
		return state.current_location_id if state != null else &""

var local_position: Vector2:
	get:
		return state.local_position if state != null else Vector2.ZERO

var current_cell: Vector2i:
	get:
		return GridSpace.local_position_to_cell(local_position)


func _init(p_state: EntityState) -> void:
	state = p_state


func get_definition() -> Definition:
	return null


func get_supported_actions(_actor: Actor) -> Array[StringName]:
	return []


func get_primary_action(actor: Actor) -> StringName:
	var actions := get_supported_actions(actor)
	return actions[0] if not actions.is_empty() else &""


func check_action(action: WorldAction) -> ActionRuleDecision:
	return ActionRuleDecision.reject(
		"目标实体不支持“%s”行为。" % action.action_id,
		&"target_action_unsupported"
	)


func apply_action(action: WorldAction) -> ActionResult:
	return ActionResult.failed(
		action.action_id,
		instance_id,
		"目标实体无法执行该行为。",
		&"target_action_unsupported"
	)


func get_occupied_grid_cells() -> Array[Vector2i]:
	return [current_cell]


func blocks_movement() -> bool:
	return false
