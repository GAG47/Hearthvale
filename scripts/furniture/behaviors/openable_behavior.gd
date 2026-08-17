class_name OpenableBehavior
extends FurnitureBehavior

const ACTION_OPEN := &"open"
const ACTION_CLOSE := &"close"

@export var open_visual: Texture2D


func handles_action(action_id: StringName) -> bool:
	return action_id == ACTION_OPEN or action_id == ACTION_CLOSE


func get_supported_actions(furniture: Furniture, _actor: Actor) -> Array[StringName]:
	var openable_state := furniture.get_openable_state()
	if openable_state == null:
		return []
	return [ACTION_CLOSE if openable_state.is_open else ACTION_OPEN]


func check_action(action: WorldAction) -> ActionRuleDecision:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionRuleDecision.reject("行为目标不是有效家具。")
	var openable_state := furniture.get_openable_state()
	if openable_state == null:
		return ActionRuleDecision.reject(
			"%s 没有有效的 OpenableState。" % furniture.definition.display_name,
			&"behavior_state_unavailable"
		)
	var display_name := furniture.definition.display_name
	match action.action_id:
		ACTION_OPEN:
			return ActionRuleDecision.permit() if not openable_state.is_open else ActionRuleDecision.reject("%s 已经打开。" % display_name)
		ACTION_CLOSE:
			return ActionRuleDecision.permit() if openable_state.is_open else ActionRuleDecision.reject("%s 已经关闭。" % display_name)
		_:
			return ActionRuleDecision.reject("%s 不提供“%s”行为。" % [display_name, action.action_id])


func apply_action(action: WorldAction) -> ActionResult:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionResult.failed(action.action_id, &"", "行为目标不是有效家具。")
	var openable_state := furniture.get_openable_state()
	if openable_state == null:
		return ActionResult.failed(
			action.action_id,
			furniture.instance_id,
			"%s 没有有效的 OpenableState。" % furniture.definition.display_name,
			&"behavior_state_unavailable"
		)
	var display_name := furniture.definition.display_name
	match action.action_id:
		ACTION_OPEN:
			openable_state.is_open = true
			return ActionResult.succeeded(
				action.action_id, furniture.instance_id, "%s打开了。" % display_name
			)
		ACTION_CLOSE:
			openable_state.is_open = false
			return ActionResult.succeeded(
				action.action_id, furniture.instance_id, "%s关闭了。" % display_name
			)
		_:
			return ActionResult.failed(
				action.action_id,
				furniture.instance_id,
				"%s 无法执行该行为。" % display_name
			)
