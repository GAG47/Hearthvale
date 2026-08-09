class_name WorldStateRuntime
extends Node

var _object_states: Dictionary[StringName, WorldObjectState] = {}
# Scene paths are retained only as development diagnostics for duplicate logical IDs.
# They never address or key world facts.
var _development_location_sources: Dictionary = {}
var _known_object_definitions: Dictionary = {}
var _active_locations: Dictionary = {}
var _active_world_objects: Dictionary = {}


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


func register_world_object(world_object: WorldObject) -> bool:
	if not is_instance_valid(world_object) or world_object.object_id.is_empty():
		push_error("Every WorldObject requires a non-empty stable object_id.")
		return false
	if not is_instance_valid(world_object.location) or not world_object.location.world_identity_registered:
		push_error("WorldObject '%s' requires a valid registered Location." % world_object.object_id)
		return false

	var object_id := world_object.object_id
	var location_id := world_object.location.location_id
	var object_type := _get_world_object_type(world_object)
	if _known_object_definitions.has(object_id):
		var definition: Dictionary = _known_object_definitions[object_id]
		if definition["location_id"] != location_id or definition["object_type"] != object_type:
			push_error(
				"Duplicate object_id '%s' conflicts with its existing definition (%s / %s)."
				% [object_id, definition["location_id"], definition["object_type"]]
			)
			return false
	else:
		_known_object_definitions[object_id] = {
			"location_id": location_id,
			"object_type": object_type,
		}

	var active_world_object := _get_active_node(_active_world_objects, object_id)
	if active_world_object != null and active_world_object != world_object:
		push_error("Duplicate active object_id '%s'." % object_id)
		return false

	_active_world_objects[object_id] = weakref(world_object)
	return true


func unregister_world_object(world_object: WorldObject) -> void:
	if not is_instance_valid(world_object):
		return
	var active_world_object := _get_active_node(_active_world_objects, world_object.object_id)
	if active_world_object == world_object:
		_active_world_objects.erase(world_object.object_id)


func get_or_create_chest_state(object_id: StringName, initial_status: ChestState.Status) -> ChestState:
	if not _definition_matches(object_id, &"Chest"):
		return null

	if _object_states.has(object_id):
		var existing_state := _object_states[object_id] as ChestState
		if existing_state == null:
			push_error("World state for '%s' is not a ChestState." % object_id)
		return existing_state

	var chest_state := ChestState.new(initial_status)
	_object_states[object_id] = chest_state
	return chest_state


func get_object_state(object_id: StringName) -> WorldObjectState:
	return _object_states.get(object_id) as WorldObjectState


func get_chest_state(object_id: StringName) -> ChestState:
	return _object_states.get(object_id) as ChestState


func has_object_state(object_id: StringName) -> bool:
	return _object_states.has(object_id)


func _definition_matches(object_id: StringName, expected_type: StringName) -> bool:
	if not _known_object_definitions.has(object_id):
		push_error("WorldObject '%s' has not registered a stable definition." % object_id)
		return false
	var definition: Dictionary = _known_object_definitions[object_id]
	if definition["object_type"] != expected_type:
		push_error(
			"WorldObject '%s' is '%s', not '%s'."
			% [object_id, definition["object_type"], expected_type]
		)
		return false
	return true


func _get_active_node(registry: Dictionary, stable_id: StringName) -> Node:
	if not registry.has(stable_id):
		return null
	var reference := registry[stable_id] as WeakRef
	if reference == null:
		return null
	return reference.get_ref() as Node


func _get_world_object_type(world_object: WorldObject) -> StringName:
	var script := world_object.get_script() as Script
	return script.get_global_name() if script != null else &""
