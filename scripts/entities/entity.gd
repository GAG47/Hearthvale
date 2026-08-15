@abstract
class_name Entity
extends RefCounted

var state: EntityState
var _entity_id: StringName

var entity_id: StringName:
	get:
		return _entity_id

var current_location_id: StringName:
	get:
		return state.current_location_id if state != null else &""

var local_position: Vector2:
	get:
		return state.local_position if state != null else Vector2.ZERO

var current_cell: Vector2i:
	get:
		return Vector2i(
			floori(local_position.x / LogicalLocationData.CELL_SIZE),
			floori(local_position.y / LogicalLocationData.CELL_SIZE)
		)


func _init(p_state: EntityState) -> void:
	state = p_state
	_entity_id = state.entity_id if state != null else &""


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
		entity_id,
		"目标实体无法执行该行为。",
		&"target_action_unsupported"
	)


func get_occupied_grid_cells() -> Array[Vector2i]:
	return get_occupied_grid_cells_at(local_position)


func get_occupied_grid_cells_at(target_local_position: Vector2) -> Array[Vector2i]:
	return [_local_position_to_cell(target_local_position)]


func is_blocking_movement() -> bool:
	return true


func _local_position_to_cell(target_local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(target_local_position.x / LogicalLocationData.CELL_SIZE),
		floori(target_local_position.y / LogicalLocationData.CELL_SIZE)
	)
