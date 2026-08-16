class_name SleepableBehavior
extends FurnitureBehavior

const ACTION_SLEEP := &"sleep"
const SLEEP_WAKE_HOUR := 8
const SLEEP_WAKE_MINUTE := 0


func handles_action(action_id: StringName) -> bool:
	return action_id == ACTION_SLEEP


func get_supported_actions(_furniture: Furniture, _actor: Actor) -> Array[StringName]:
	return [ACTION_SLEEP]


func check_action(action: WorldAction) -> ActionRuleDecision:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionRuleDecision.reject("行为目标不是有效家具。")
	if action.action_id != ACTION_SLEEP:
		return ActionRuleDecision.reject(
			"%s 不提供“%s”行为。"
			% [furniture.definition.display_name, action.action_id]
		)
	if _get_world_time() == null:
		return ActionRuleDecision.reject("世界时间系统当前不可用。", &"world_time_unavailable")
	return ActionRuleDecision.permit()


func apply_action(action: WorldAction) -> ActionResult:
	var world_time := _get_world_time()
	if world_time == null:
		return ActionResult.failed(
			action.action_id,
			action.target.instance_id,
			"世界时间系统当前不可用。",
			&"world_time_unavailable"
		)
	if not world_time.advance_to_next_day_at(SLEEP_WAKE_HOUR, SLEEP_WAKE_MINUTE):
		return ActionResult.failed(
			action.action_id,
			action.target.instance_id,
			"睡眠未能推进世界时间。",
			&"world_time_advance_failed"
		)
	return ActionResult.succeeded(action.action_id, action.target.instance_id, "你睡到了第二天 08:00。")


func _get_world_time() -> WorldTimeRuntime:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("WorldTime") as WorldTimeRuntime if tree != null else null
