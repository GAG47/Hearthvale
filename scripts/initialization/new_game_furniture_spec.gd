@tool
class_name NewGameFurnitureSpec
extends NewGameEntitySpec

@export var definition: FurnitureDefinition


func validate() -> bool:
	if not super():
		return false
	if definition == null:
		push_error("NewGameFurnitureSpec '%s' requires a FurnitureDefinition." % instance_id)
		return false
	if definition.footprint_cells.is_empty():
		push_error("NewGameFurnitureSpec '%s' requires a non-empty footprint." % instance_id)
		return false
	return true


func create_initial_state() -> EntityState:
	return FurnitureState.new(instance_id, initial_location.instance_id, local_cell)


func create_entity(state: EntityState) -> Entity:
	if not state is FurnitureState or state.instance_id != instance_id:
		push_error("NewGameFurnitureSpec '%s' requires its matching FurnitureState." % instance_id)
		return null
	return Furniture.new(definition, state as FurnitureState)


func get_initial_footprint_cells() -> Array[Vector2i]:
	return definition.footprint_cells.duplicate() if definition != null else []


func blocks_initial_movement() -> bool:
	return definition != null and definition.blocks_movement
