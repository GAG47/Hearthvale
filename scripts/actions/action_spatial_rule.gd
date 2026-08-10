class_name ActionSpatialRule
extends RefCounted


static func evaluate(action: WorldAction) -> ActionRuleDecision:
	if not is_instance_valid(action.actor):
		return ActionRuleDecision.reject("行为发起者已经不存在。", &"actor_invalid")
	if not is_instance_valid(action.target):
		return ActionRuleDecision.reject("行为目标已经不存在。", &"target_invalid")
	if action.actor.current_location_id.is_empty() or not is_instance_valid(action.target.location):
		return ActionRuleDecision.reject("行为发起者或目标不属于有效地点。", &"location_missing")
	if action.actor.current_location_id != action.target.location.location_id:
		return ActionRuleDecision.reject("行为发起者与目标不在同一个地点。", &"target_not_in_same_location")

	var target_cells := action.target.get_occupied_grid_cells()
	if not target_cells.has(action.actor.current_cell) and not target_cells.has(action.actor.get_front_cell()):
		return ActionRuleDecision.reject("目标不在当前可交互空间内。", &"target_out_of_interaction_space")

	return ActionRuleDecision.permit()
