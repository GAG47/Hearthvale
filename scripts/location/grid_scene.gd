class_name GridScene
extends Node2D

@export var location_id := &""
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)

var world_identity_registered := false
var world_state: WorldStateRuntime
var location: LocationRuntime
var _activation_prepared := false


func _enter_tree() -> void:
	if _activation_prepared:
		world_state.activate_prepared_location(self)
		world_identity_registered = true
		_activation_prepared = false
		return

	world_state = get_node_or_null("/root/WorldState") as WorldStateRuntime
	if world_state == null:
		push_error("WorldState Autoload is required before loading a Location.")
		return
	if location == null or not location.is_valid() or location.instance_id != location_id:
		push_error("Only a valid Location Runtime may activate a built Location Scene.")
		return
	world_identity_registered = world_state.register_location(self)


func prepare_activation(
	p_world_state: WorldStateRuntime,
	requested_location: LocationRuntime
) -> bool:
	if is_inside_tree():
		push_error("A loaded Location cannot be prepared for activation again.")
		return false
	if p_world_state == null or requested_location == null or not requested_location.is_valid():
		push_error("Location activation requires a Location Runtime and WorldState.")
		return false
	if location != requested_location or location_id != requested_location.instance_id:
		push_error("Built Scene does not represent the requested Location instance.")
		return false
	if not p_world_state.can_register_location(self):
		return false

	world_state = p_world_state
	_activation_prepared = true
	return true


func configure(p_location: LocationRuntime) -> void:
	location = p_location
	location_id = p_location.instance_id if p_location != null else &""
	grid_size = p_location.definition.grid_size if p_location != null else Vector2i.ONE


func _exit_tree() -> void:
	if world_identity_registered:
		world_state.unregister_location(self)
		world_identity_registered = false


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, GridSpace.grid_size_to_local_size(grid_size))
