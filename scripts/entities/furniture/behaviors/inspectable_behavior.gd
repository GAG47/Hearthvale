class_name InspectableBehavior
extends FurnitureBehavior

const ACTION_INSPECT := &"inspect"

@export_multiline var text := ""


func _init(p_text := "") -> void:
	text = p_text


func handles_action(action_id: StringName) -> bool:
	return action_id == ACTION_INSPECT


func get_supported_actions(_furniture: Furniture, _actor: Actor) -> Array[StringName]:
	return [ACTION_INSPECT]


func check_action(action: EntityAction) -> ActionRuleDecision:
	var furniture := action.target as Furniture
	if furniture == null:
		return ActionRuleDecision.reject("行为目标不是有效家具。")
	if action.action_id != ACTION_INSPECT:
		return ActionRuleDecision.reject(
			"%s 不提供“%s”行为。"
			% [furniture.definition.display_name, action.action_id]
		)
	return ActionRuleDecision.permit()


func apply_action(action: EntityAction) -> ActionResult:
	return ActionResult.succeeded(action.action_id, action.target.instance_id, text)
