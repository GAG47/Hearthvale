class_name ActionResult
extends RefCounted

var success: bool
var action_id: StringName
var target_id: StringName
var message: String


func _init(
	p_success := false,
	p_action_id := &"",
	p_target_id := &"",
	p_message := ""
) -> void:
	success = p_success
	action_id = p_action_id
	target_id = p_target_id
	message = p_message


static func succeeded(action_id: StringName, target_id: StringName, message: String) -> ActionResult:
	return ActionResult.new(true, action_id, target_id, message)


static func failed(action_id: StringName, target_id: StringName, reason: String) -> ActionResult:
	return ActionResult.new(false, action_id, target_id, reason)
