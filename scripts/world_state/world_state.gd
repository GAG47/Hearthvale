class_name WorldStateRuntime
extends Node

# Authoritative world facts that survive Location Scene lifecycles.
var _entity_states: Dictionary[StringName, EntityState] = {}
var _location_states: Dictionary[StringName, LocationState] = {}
var _world_time_state: WorldTimeState

# Runtime Location registration. These Scene nodes are representations, not world facts.
var _active_locations: Dictionary = {}


func _ready() -> void:
	var world_definition := get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	if world_definition == null:
		return
	for spec in world_definition.get_project_location_instance_specs():
		register_location_state(LocationState.new(spec.instance_id))


func register_location(location: GridScene) -> bool:
	if not can_register_location(location):
		return false
	_activate_location(location)
	return true


func can_register_location(location: GridScene) -> bool:
	if not is_instance_valid(location) or location.location_id.is_empty():
		push_error("Every Location requires a non-empty stable location_id.")
		return false

	var location_id := location.location_id
	var active_location := _get_active_node(_active_locations, location_id)
	if active_location != null and active_location != location:
		push_error("Duplicate active location_id '%s'." % location_id)
		return false
	return true


func activate_prepared_location(location: GridScene) -> void:
	_activate_location(location)


func unregister_location(location: GridScene) -> void:
	if not is_instance_valid(location):
		return
	var active_location := _get_active_node(_active_locations, location.location_id)
	if active_location == location:
		_active_locations.erase(location.location_id)


func _activate_location(location: GridScene) -> void:
	var location_id := location.location_id
	_active_locations[location_id] = weakref(location)


func register_entity_state(state: EntityState) -> bool:
	if state == null or not UuidValidator.is_valid_v4(state.instance_id):
		var invalid_id := state.instance_id if state != null else &""
		push_error("EntityState instance_id '%s' is not a valid UUID v4." % invalid_id)
		return false
	if _entity_states.has(state.instance_id):
		if _entity_states[state.instance_id] == state:
			return true
		push_error("Entity '%s' already has a different registered EntityState." % state.instance_id)
		return false

	_entity_states[state.instance_id] = state
	return true


func register_location_state(state: LocationState) -> bool:
	if state == null or not UuidValidator.is_valid_v4(state.instance_id):
		var invalid_id := state.instance_id if state != null else &""
		push_error("LocationState instance_id '%s' is not a valid UUID v4." % invalid_id)
		return false
	if _location_states.has(state.instance_id):
		if _location_states[state.instance_id] == state:
			return true
		push_error("Location '%s' already has a different registered LocationState." % state.instance_id)
		return false
	_location_states[state.instance_id] = state
	return true


func get_location_state(instance_id: StringName) -> LocationState:
	return _location_states.get(instance_id) as LocationState


func has_location_state(instance_id: StringName) -> bool:
	return _location_states.has(instance_id)


func get_location_states() -> Array[LocationState]:
	var states: Array[LocationState] = []
	var instance_ids := _location_states.keys()
	instance_ids.sort()
	for instance_id in instance_ids:
		states.append(_location_states[instance_id])
	return states


func get_entity_state(instance_id: StringName) -> EntityState:
	return _entity_states.get(instance_id) as EntityState


func has_entity_state(instance_id: StringName) -> bool:
	return _entity_states.has(instance_id)


func get_entity_states() -> Array[EntityState]:
	var states: Array[EntityState] = []
	var instance_ids := _entity_states.keys()
	instance_ids.sort()
	for instance_id in instance_ids:
		states.append(_entity_states[instance_id])
	return states


func get_world_time_state() -> WorldTimeState:
	return _world_time_state


func register_world_time_state(state: WorldTimeState) -> bool:
	if state == null:
		push_error("World time state registration requires a valid WorldTimeState.")
		return false
	if _world_time_state != null:
		if _world_time_state == state:
			return true
		push_error("WorldState already has a different registered WorldTimeState.")
		return false

	_world_time_state = state
	return true


func _get_active_node(registry: Dictionary, stable_id: StringName) -> Node:
	if not registry.has(stable_id):
		return null
	var reference := registry[stable_id] as WeakRef
	if reference == null:
		return null
	return reference.get_ref() as Node
