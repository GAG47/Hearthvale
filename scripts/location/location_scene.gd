class_name LocationScene
extends Node2D

@export var location_id := &""
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)

var location: Location


func _enter_tree() -> void:
	if location == null or not location.is_valid() or location.instance_id != location_id:
		push_error("Only a valid Location may activate a built Location Scene.")


func prepare_activation(requested_location: Location) -> bool:
	if is_inside_tree():
		push_error("A loaded Location cannot be prepared for activation again.")
		return false
	if requested_location == null or not requested_location.is_valid():
		push_error("Location activation requires a valid Location.")
		return false
	if location != requested_location or location_id != requested_location.instance_id:
		push_error("Built Scene does not represent the requested Location instance.")
		return false
	return true


func configure(p_location: Location) -> void:
	location = p_location
	location_id = p_location.instance_id if p_location != null else &""
	grid_size = p_location.definition.grid_size if p_location != null else Vector2i.ONE


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, LocationGridSpace.grid_size_to_local_size(grid_size))
