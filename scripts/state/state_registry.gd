class_name StateRegistry
extends RefCounted

# Authoritative world facts that survive Location Scene lifecycles.
var _entity_states: Dictionary[StringName, EntityState] = {}
var _location_states: Dictionary[StringName, LocationState] = {}
var _game_time_state: GameTimeState


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


func get_game_time_state() -> GameTimeState:
	return _game_time_state


func register_game_time_state(state: GameTimeState) -> bool:
	if state == null:
		push_error("Game time state registration requires a valid GameTimeState.")
		return false
	if _game_time_state != null:
		if _game_time_state == state:
			return true
		push_error("StateRegistry already has a different registered GameTimeState.")
		return false

	_game_time_state = state
	return true


func clear() -> void:
	_entity_states.clear()
	_location_states.clear()
	_game_time_state = null
