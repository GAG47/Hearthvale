@tool
class_name UseSlotDefinition
extends Resource

@export var relative_cell := Vector2i.ZERO:
	set(value):
		relative_cell = value
		emit_changed()

@export var required_facing := ActorState.Facing.DOWN:
	set(value):
		required_facing = value
		emit_changed()

@export var supported_actions: Array[StringName] = []:
	set(value):
		supported_actions = value.duplicate()
		emit_changed()


func get_validation_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if supported_actions.is_empty():
		warnings.append("UseSlotDefinition supported_actions must not be empty.")
	for action_id in supported_actions:
		if action_id.is_empty():
			warnings.append("UseSlotDefinition supported_actions must not contain an empty ID.")
	return warnings
