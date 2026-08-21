class_name SleepableBehavior
extends FurnitureBehavior

const ACTION_SLEEP := &"sleep"
const SLEEP_WAKE_HOUR := 8
const SLEEP_WAKE_MINUTE := 0


func handles_action(action_id: StringName) -> bool:
	return action_id == ACTION_SLEEP


func get_supported_actions(_furniture: Furniture, _actor: Actor) -> Array[StringName]:
	return [ACTION_SLEEP]


func check_action(action: EntityAction) -> ActionRuleDecision:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionRuleDecision.reject("行为目标不是有效家具。")
	if action.action_id != ACTION_SLEEP:
		return ActionRuleDecision.reject(
			"%s 不提供“%s”行为。"
			% [furniture.definition.display_name, action.action_id]
		)
	if action.game_clock == null:
		return ActionRuleDecision.reject("游戏时间系统当前不可用。", &"game_clock_unavailable")
	return ActionRuleDecision.permit()


func apply_action(action: EntityAction) -> ActionResult:
	var game_clock := action.game_clock
	if game_clock == null:
		return ActionResult.failed(
			action.action_id,
			action.target.instance_id,
			"游戏时间系统当前不可用。",
			&"game_clock_unavailable"
		)
	if not game_clock.advance_to_next_day_at(SLEEP_WAKE_HOUR, SLEEP_WAKE_MINUTE):
		return ActionResult.failed(
			action.action_id,
			action.target.instance_id,
			"睡眠未能推进游戏时间。",
			&"game_clock_advance_failed"
		)
	return ActionResult.succeeded(action.action_id, action.target.instance_id, "你睡到了第二天 08:00。")
