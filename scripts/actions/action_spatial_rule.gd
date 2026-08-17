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

	var location := _get_location(action.actor.current_location_id)
	if location != null:
		for slot in location.get_use_slots(action.target, action.action_id):
			if location.get_use_slot_world_cell(action.target, slot) != action.actor.current_cell:
				continue
			if not slot.is_facing_allowed(action.actor.facing):
				continue
			if location.is_use_slot_valid(action.target, slot):
				return ActionRuleDecision.permit()
		return ActionRuleDecision.reject("目标不在当前可交互空间内。", &"target_out_of_interaction_space")

	# Isolated logic tests can intentionally disable the project Autoloads. In that
	# case retain the same slot and facing contract without world-space facts.
	for slot in action.target.get_use_slots(action.action_id):
		if (
			action.target.get_use_slot_world_cell(slot) == action.actor.current_cell
			and slot.is_facing_allowed(action.actor.facing)
		):
			return ActionRuleDecision.permit()
	return ActionRuleDecision.reject("目标不在当前可交互空间内。", &"target_out_of_interaction_space")


static func _get_location(location_id: StringName) -> LocationRuntime:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var world_definition := tree.root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	return world_definition.get_location(location_id) if world_definition != null else null
