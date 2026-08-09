class_name ActionRuleDecision
extends RefCounted

var allowed: bool
var reason: String


func _init(p_allowed := false, p_reason := "") -> void:
	allowed = p_allowed
	reason = p_reason


static func permit() -> ActionRuleDecision:
	return ActionRuleDecision.new(true)


static func reject(reason: String) -> ActionRuleDecision:
	return ActionRuleDecision.new(false, reason)
