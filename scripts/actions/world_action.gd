class_name WorldAction
extends RefCounted

var action_id: StringName
var actor: Node2D
var target: WorldObject


func _init(p_action_id: StringName, p_actor: Node2D, p_target: WorldObject) -> void:
	action_id = p_action_id
	actor = p_actor
	target = p_target


func execute() -> ActionResult:
	if not is_instance_valid(target):
		return ActionResult.failed(action_id, &"", "行为目标已经不存在。")

	var decision := target.check_action(self)
	if not decision.allowed:
		return ActionResult.failed(action_id, target.object_id, decision.reason)

	return target.apply_action(self)
