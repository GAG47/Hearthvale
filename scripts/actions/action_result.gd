class_name ActionResult
extends RefCounted

var success: bool
var action_id: StringName
var target_id: StringName
var message: String
var failure_code: StringName


func _init(
	p_success := false,
	p_action_id := &"",
	p_target_id := &"",
	p_message := "",
	p_failure_code := &""
) -> void:
	success = p_success
	action_id = p_action_id
	target_id = p_target_id
	message = p_message
	failure_code = p_failure_code


static func succeeded(action_id: StringName, target_id: StringName, message: String) -> ActionResult:
	return ActionResult.new(true, action_id, target_id, message)


static func failed(
	action_id: StringName,
	target_id: StringName,
	reason: String,
	failure_code: StringName = &""
) -> ActionResult:
	return ActionResult.new(false, action_id, target_id, reason, failure_code)
