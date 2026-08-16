extends Entity

const ACTION_TEST := &"test_action"
var definition: Definition


func _init(p_state: EntityState) -> void:
	super(p_state)
	if p_state != null:
		definition = ActorDefinition.new(p_state.definition_id, "Test Action Entity", {})


func get_definition() -> Definition:
	return definition


func get_supported_actions(_actor: Actor) -> Array[StringName]:
	return [ACTION_TEST]


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self or action.action_id != ACTION_TEST:
		return super(action)
	return ActionRuleDecision.permit()


func apply_action(action: WorldAction) -> ActionResult:
	if action.target != self or action.action_id != ACTION_TEST:
		return super(action)
	return ActionResult.succeeded(action.action_id, instance_id, "Test Entity action executed.")
