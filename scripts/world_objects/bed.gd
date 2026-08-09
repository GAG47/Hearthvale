class_name Bed
extends WorldObject

const ACTION_SLEEP := &"sleep"


func get_available_actions(_actor: Node2D) -> Array[StringName]:
	var actions: Array[StringName] = []
	actions.append(ACTION_SLEEP)
	return actions


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self:
		return ActionRuleDecision.reject("行为目标不是这张床。")
	if action.action_id != ACTION_SLEEP:
		return ActionRuleDecision.reject("床不提供“%s”行为。" % action.action_id)
	return ActionRuleDecision.reject("当前还不能睡觉。")


func apply_action(action: WorldAction) -> ActionResult:
	return ActionResult.failed(action.action_id, object_id, "当前还不能睡觉。")
