class_name OpenableBehavior
extends FurnitureBehavior

const ACTION_OPEN := &"open"
const ACTION_CLOSE := &"close"


func handles_action(action_id: StringName) -> bool:
	return action_id == ACTION_OPEN or action_id == ACTION_CLOSE


func get_supported_actions(furniture: Furniture, _actor: Actor) -> Array[StringName]:
	return [ACTION_CLOSE if furniture.furniture_state.is_open else ACTION_OPEN]


func check_action(action: WorldAction) -> ActionRuleDecision:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionRuleDecision.reject("行为目标不是这个储物箱。")
	match action.action_id:
		ACTION_OPEN:
			return ActionRuleDecision.permit() if not furniture.furniture_state.is_open else ActionRuleDecision.reject("箱子已经打开。")
		ACTION_CLOSE:
			return ActionRuleDecision.permit() if furniture.furniture_state.is_open else ActionRuleDecision.reject("箱子已经关闭。")
		_:
			return ActionRuleDecision.reject("储物箱不提供“%s”行为。" % action.action_id)


func apply_action(action: WorldAction) -> ActionResult:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionResult.failed(action.action_id, &"", "行为目标不是这个储物箱。")
	match action.action_id:
		ACTION_OPEN:
			furniture.furniture_state.is_open = true
			return ActionResult.succeeded(action.action_id, furniture.entity_id, "箱子打开了。")
		ACTION_CLOSE:
			furniture.furniture_state.is_open = false
			return ActionResult.succeeded(action.action_id, furniture.entity_id, "箱子关闭了。")
		_:
			return ActionResult.failed(action.action_id, furniture.entity_id, "储物箱无法执行该行为。")
