class_name WorldSign
extends WorldObject

const ACTION_INSPECT := &"inspect"

@export_multiline var sign_text := "今日麦酒三铜币。"


func get_available_actions(_actor: Node2D) -> Array[StringName]:
	var actions: Array[StringName] = []
	actions.append(ACTION_INSPECT)
	return actions


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self:
		return ActionRuleDecision.reject("行为目标不是这块告示牌。")
	if action.action_id != ACTION_INSPECT:
		return ActionRuleDecision.reject("告示牌不提供“%s”行为。" % action.action_id)
	return ActionRuleDecision.permit()


func apply_action(action: WorldAction) -> ActionResult:
	return ActionResult.succeeded(action.action_id, object_id, sign_text)
