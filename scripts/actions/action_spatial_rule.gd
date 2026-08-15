class_name ActionSpatialRule
extends RefCounted


static func evaluate(action: WorldAction) -> ActionRuleDecision:
	if action.actor == null:
		return ActionRuleDecision.reject("行为发起者已经不存在。", &"actor_invalid")
	if action.target == null:
		return ActionRuleDecision.reject("行为目标已经不存在。", &"target_invalid")
	if action.actor.current_location_id.is_empty() or action.target.current_location_id.is_empty():
		return ActionRuleDecision.reject("行为发起者或目标不属于有效地点。", &"location_missing")
	if action.actor.current_location_id != action.target.current_location_id:
		return ActionRuleDecision.reject("行为发起者与目标不在同一个地点。", &"target_not_in_same_location")
	if not action.target.get_supported_actions(action.actor).has(action.action_id):
		# Capability errors belong to Entity.check_action(), not the spatial rule.
		return ActionRuleDecision.permit()
	var tree := Engine.get_main_loop() as SceneTree
	var location_space := (
		tree.root.get_node_or_null("LocationSpace") as LocationSpaceRuntime
		if tree != null
		else null
	)
	var location := action.logical_location
	if location == null and location_space != null and location_space.has_location(action.actor.current_location_id):
		location = location_space.get_location(action.actor.current_location_id)
	if location == null or location.location_id != action.actor.current_location_id:
		return ActionRuleDecision.reject("当前地点的逻辑空间不可用。", &"location_space_unavailable")
	if not location.is_actor_at_valid_use_slot(action.actor, action.target, action.action_id):
		return ActionRuleDecision.reject("目标不在当前可交互空间内。", &"target_out_of_interaction_space")

	return ActionRuleDecision.permit()
