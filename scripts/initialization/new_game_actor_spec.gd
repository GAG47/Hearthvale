@tool
class_name NewGameActorSpec
extends NewGameEntitySpec

@export var definition: ActorDefinition
@export var initial_facing := ActorState.Facing.DOWN


func validate() -> bool:
	if not super():
		return false
	if definition == null:
		push_error("NewGameActorSpec '%s' requires an ActorDefinition." % instance_id)
		return false
	if initial_facing not in [
		ActorState.Facing.UP,
		ActorState.Facing.DOWN,
		ActorState.Facing.LEFT,
		ActorState.Facing.RIGHT,
	]:
		push_error("NewGameActorSpec '%s' has an invalid initial facing." % instance_id)
		return false
	return true


func create_initial_state() -> EntityState:
	return ActorState.new(instance_id, initial_location.instance_id, local_cell, initial_facing)


func create_entity(state: EntityState) -> Entity:
	if not state is ActorState or state.instance_id != instance_id:
		push_error("NewGameActorSpec '%s' requires its matching ActorState." % instance_id)
		return null
	return Actor.new(definition, state as ActorState)
