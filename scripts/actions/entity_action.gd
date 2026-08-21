class_name EntityAction
extends RefCounted

var action_id: StringName
var actor: Actor
var target: Entity
var location_registry: LocationRegistry
var logical_movement: LogicalMovement
var game_clock: GameClock


func _init(
	p_action_id: StringName,
	p_actor: Actor,
	p_target: Entity,
	p_location_registry: LocationRegistry = null,
	p_logical_movement: LogicalMovement = null,
	p_game_clock: GameClock = null
) -> void:
	action_id = p_action_id
	actor = p_actor
	target = p_target
	location_registry = p_location_registry
	logical_movement = p_logical_movement
	game_clock = p_game_clock


func execute() -> ActionResult:
	var spatial_decision := ActionSpatialRule.evaluate(self)
	if not spatial_decision.allowed:
		var target_id := target.instance_id if target != null else &""
		return ActionResult.failed(
			action_id,
			target_id,
			spatial_decision.reason,
			spatial_decision.failure_code
		)

	var decision := target.check_action(self)
	if not decision.allowed:
		return ActionResult.failed(action_id, target.instance_id, decision.reason, decision.failure_code)

	return target.apply_action(self)
