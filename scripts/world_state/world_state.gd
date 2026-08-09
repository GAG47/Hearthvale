class_name WorldStateRuntime
extends Node

# Authoritative world facts that survive Location Scene lifecycles.
var _object_states: Dictionary[StringName, WorldObjectState] = {}

# Runtime registration and development diagnostics. These are not world facts.
# Scene paths are retained only as development diagnostics for duplicate logical IDs.
# They never address or key world facts.
var _development_location_sources: Dictionary = {}
var _fixed_object_definition_records: Dictionary = {}
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
	if world_object.initial_location_id.is_empty():
		push_error("Fixed WorldObject '%s' requires an initial_location_id in its Definition." % world_object.object_id)
		return false
	if world_object.initial_location_id != world_object.location.location_id:
		push_error(
			"Fixed WorldObject '%s' declares initial_location_id '%s' but actually belongs to Location '%s'."
			% [
				world_object.object_id,
				world_object.initial_location_id,
				world_object.location.location_id,
			]
		)
		return false

	var object_id := world_object.object_id
	var initial_location_id := world_object.initial_location_id
	var object_type := _get_world_object_type(world_object)
	if _fixed_object_definition_records.has(object_id):
		var definition: Dictionary = _fixed_object_definition_records[object_id]
		if definition["initial_location_id"] != initial_location_id or definition["object_type"] != object_type:
			push_error(
				"Duplicate object_id '%s' conflicts with its existing definition (%s / %s)."
				% [object_id, definition["initial_location_id"], definition["object_type"]]
			)
			return false
	else:
		_fixed_object_definition_records[object_id] = {
			"initial_location_id": initial_location_id,
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


func get_object_state(object_id: StringName) -> WorldObjectState:
	return _object_states.get(object_id) as WorldObjectState


func register_object_state(object_id: StringName, state: WorldObjectState) -> bool:
	if object_id.is_empty() or state == null:
		push_error("Object state registration requires a stable object_id and a valid WorldObjectState.")
		return false
	if not _fixed_object_definition_records.has(object_id):
		push_error("Cannot register state for unknown WorldObject '%s'." % object_id)
		return false
	if _object_states.has(object_id):
		if _object_states[object_id] == state:
			return true
		push_error("WorldObject '%s' already has a different registered state." % object_id)
		return false

	_object_states[object_id] = state
	return true


func has_object_state(object_id: StringName) -> bool:
	return _object_states.has(object_id)


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
