class_name ActionSpatialRule
extends RefCounted


static func evaluate(action: EntityAction) -> ActionRuleDecision:
	if action.actor == null:
		return ActionRuleDecision.reject("行为发起者已经不存在。", &"actor_invalid")
	if action.target == null:
		return ActionRuleDecision.reject("行为目标已经不存在。", &"target_invalid")
	if action.actor.current_location_id.is_empty() or action.target.current_location_id.is_empty():
		return ActionRuleDecision.reject("行为发起者或目标不属于有效地点。", &"location_missing")
	if action.actor.current_location_id != action.target.current_location_id:
		return ActionRuleDecision.reject("行为发起者与目标不在同一个地点。", &"target_not_in_same_location")
	if (
		action.logical_movement != null
		and action.logical_movement.get_actor_phase(action.actor) == ActorMovementRequest.Phase.EXTENDED
	):
		return ActionRuleDecision.reject(
			"行为发起者正在格子之间移动。",
			&"actor_in_cell_transition"
		)

	var location := (
		action.location_registry.get_location(action.actor.current_location_id)
		if action.location_registry != null
		else null
	)
	if location == null:
		return ActionRuleDecision.reject("行为所在地点当前不可用。", &"location_unavailable")
	for slot in location.get_use_slots(action.target, action.action_id):
		if (
			location.get_use_slot_location_cell(action.target, slot) == action.actor.current_cell
			and slot.is_facing_allowed(action.actor.facing)
			and location.is_use_slot_valid(action.target, slot)
		):
			return ActionRuleDecision.permit()
	return ActionRuleDecision.reject("目标不在当前可交互空间内。", &"target_out_of_interaction_space")
