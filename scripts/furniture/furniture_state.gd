class_name FurnitureState
extends EntityState

var is_open: bool


func _init(
	p_entity_id: StringName,
	p_current_location_id: StringName,
	p_local_position: Vector2,
	p_is_open := false
) -> void:
	super(p_entity_id, p_current_location_id, p_local_position)
	is_open = p_is_open
