extends Entity

const ACTION_TEST := &"test_action"

var explicit_use_slots: Array[UseSlotDefinition] = []
var blocks_movement := true


func _init(p_state: EntityState) -> void:
	super(p_state)


func get_supported_actions(_actor: Actor) -> Array[StringName]:
	return [ACTION_TEST]


func get_explicit_use_slot_definitions() -> Array[UseSlotDefinition]:
	return explicit_use_slots.duplicate()


func is_blocking_movement() -> bool:
	return blocks_movement


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self or action.action_id != ACTION_TEST:
		return super(action)
	return ActionRuleDecision.permit()


func apply_action(action: WorldAction) -> ActionResult:
	if action.target != self or action.action_id != ACTION_TEST:
		return super(action)
	return ActionResult.succeeded(action.action_id, entity_id, "Test Entity action executed.")
