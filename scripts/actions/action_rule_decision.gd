class_name ActionRuleDecision
extends RefCounted

var allowed: bool
var reason: String
var failure_code: StringName


func _init(p_allowed := false, p_reason := "", p_failure_code := &"") -> void:
	allowed = p_allowed
	reason = p_reason
	failure_code = p_failure_code


static func permit() -> ActionRuleDecision:
	return ActionRuleDecision.new(true)


static func reject(reason: String, failure_code: StringName = &"") -> ActionRuleDecision:
	return ActionRuleDecision.new(false, reason, failure_code)
