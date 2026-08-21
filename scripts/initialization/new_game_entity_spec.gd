@tool
@abstract
class_name NewGameEntitySpec
extends Resource

@export var instance_id: StringName
@export var initial_location: NewGameLocationSpec
@export var local_cell := Vector2i.ZERO


func validate() -> bool:
	if not UuidValidator.is_valid_v4(instance_id):
		push_error("NewGameEntitySpec instance_id '%s' is not a valid UUID v4." % instance_id)
		return false
	if initial_location == null or initial_location.definition == null:
		push_error("NewGameEntitySpec '%s' requires an initial Location spec." % instance_id)
		return false
	if not initial_location.definition.is_cell_in_grid(local_cell):
		push_error("NewGameEntitySpec '%s' has an out-of-bounds initial Cell %s." % [instance_id, local_cell])
		return false
	return true


@abstract func create_initial_state() -> EntityState


@abstract func create_entity(state: EntityState) -> Entity


func get_initial_footprint_cells() -> Array[Vector2i]:
	return [Vector2i.ZERO]


func blocks_initial_movement() -> bool:
	return false
