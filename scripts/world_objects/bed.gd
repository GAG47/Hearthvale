class_name Bed
extends WorldObject

const ACTION_SLEEP := &"sleep"
const SLEEP_WAKE_HOUR := 8
const SLEEP_WAKE_MINUTE := 0


func get_supported_actions(_actor: Character) -> Array[StringName]:
	var actions: Array[StringName] = []
	actions.append(ACTION_SLEEP)
	return actions


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self:
		return ActionRuleDecision.reject("行为目标不是这张床。")
	if action.action_id != ACTION_SLEEP:
		return ActionRuleDecision.reject("床不提供“%s”行为。" % action.action_id)
	if get_node_or_null("/root/WorldTime") == null:
		return ActionRuleDecision.reject("世界时间系统当前不可用。", &"world_time_unavailable")
	return ActionRuleDecision.permit()


func apply_action(action: WorldAction) -> ActionResult:
	var world_time := get_node_or_null("/root/WorldTime") as WorldTimeRuntime
	if world_time == null:
		return ActionResult.failed(
			action.action_id,
			object_id,
			"世界时间系统当前不可用。",
			&"world_time_unavailable"
		)
	if not world_time.advance_to_next_day_at(SLEEP_WAKE_HOUR, SLEEP_WAKE_MINUTE):
		return ActionResult.failed(
			action.action_id,
			object_id,
			"睡眠未能推进世界时间。",
			&"world_time_advance_failed"
		)
	return ActionResult.succeeded(action.action_id, object_id, "你睡到了第二天 08:00。")
