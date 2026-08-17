class_name Actor
extends Entity

var definition: ActorDefinition

var facing: ActorState.Facing:
	get:
		return (state as ActorState).facing


func _init(p_definition: ActorDefinition, p_state: ActorState) -> void:
	super(p_state)
	definition = p_definition


func get_definition() -> Resource:
	return definition


func get_explicit_use_slots() -> Array[UseSlot]:
	return definition.use_slots.duplicate() if definition != null else []


func get_front_cell() -> Vector2i:
	return current_cell + get_facing_cell_offset()


func get_facing_cell_offset() -> Vector2i:
	match facing:
		ActorState.Facing.UP:
			return Vector2i.UP
		ActorState.Facing.LEFT:
			return Vector2i.LEFT
		ActorState.Facing.RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN
