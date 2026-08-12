class_name WorldStateRuntime
extends Node

# Authoritative world facts that survive Location Scene lifecycles.
var _entity_states: Dictionary[StringName, EntityState] = {}
var _world_time_state: WorldTimeState

# Runtime Location registration and development diagnostics. These are not world facts.
var _development_location_sources: Dictionary = {}
var _active_locations: Dictionary = {}


func register_location(location: GridScene) -> bool:
	if not is_instance_valid(location) or location.location_id.is_empty():
		push_error("Every Location requires a non-empty stable location_id.")
		return false

	var location_id := location.location_id
	var source := location.scene_file_path
	if _development_location_sources.has(location_id):
		var known_source: String = _development_location_sources[location_id]
		if not source.is_empty() and not known_source.is_empty() and source != known_source:
			push_error(
				"Duplicate location_id '%s' is defined by both '%s' and '%s'."
				% [location_id, known_source, source]
			)
			return false
		if known_source.is_empty() and not source.is_empty():
			_development_location_sources[location_id] = source
	else:
		_development_location_sources[location_id] = source

	var active_location := _get_active_node(_active_locations, location_id)
	if active_location != null and active_location != location:
		push_error("Duplicate active location_id '%s'." % location_id)
		return false

	_active_locations[location_id] = weakref(location)
	return true


func unregister_location(location: GridScene) -> void:
	if not is_instance_valid(location):
		return
	var active_location := _get_active_node(_active_locations, location.location_id)
	if active_location == location:
		_active_locations.erase(location.location_id)


func register_entity_state(state: EntityState) -> bool:
	if state == null or not UuidValidator.is_valid_v4(state.entity_id):
		var invalid_id := state.entity_id if state != null else &""
		push_error("EntityState entity_id '%s' is not a valid UUID v4." % invalid_id)
		return false
	if _entity_states.has(state.entity_id):
		if _entity_states[state.entity_id] == state:
			return true
		push_error("Entity '%s' already has a different registered EntityState." % state.entity_id)
		return false

	_entity_states[state.entity_id] = state
	return true


func get_entity_state(entity_id: StringName) -> EntityState:
	return _entity_states.get(entity_id) as EntityState


func has_entity_state(entity_id: StringName) -> bool:
	return _entity_states.has(entity_id)


func get_entity_states() -> Array[EntityState]:
	var states: Array[EntityState] = []
	var entity_ids := _entity_states.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		states.append(_entity_states[entity_id])
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
