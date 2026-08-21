class_name LocationRegistry
extends RefCounted

var _locations: Dictionary[StringName, Location] = {}


func register(location: Location) -> bool:
	if location == null or not location.is_valid():
		push_error("LocationRegistry can only register a valid Location.")
		return false
	if _locations.has(location.instance_id):
		if _locations[location.instance_id] == location:
			return true
		push_error("Location '%s' already has a different registered Location." % location.instance_id)
		return false
	_locations[location.instance_id] = location
	return true


func get_all() -> Array[Location]:
	var locations: Array[Location] = []
	var ids := _locations.keys()
	ids.sort()
	for location_id in ids:
		locations.append(_locations[location_id])
	return locations


func has_location(location_id: StringName) -> bool:
	return _locations.has(location_id)


func get_location(location_id: StringName) -> Location:
	return _locations.get(location_id) as Location


func get_outgoing_edges(location_id: StringName) -> Array[LocationEdgeDefinition]:
	var location := get_location(location_id)
	return location.get_current_edges() if location != null else []


func get_edge(location_id: StringName, edge_key: StringName) -> LocationEdgeDefinition:
	var location := get_location(location_id)
	if location == null:
		return null
	var edge := location.get_edge(edge_key)
	if edge == null:
		push_error(
			"Location '%s' has no enabled outgoing edge with edge_key '%s'."
			% [location_id, edge_key]
		)
	return edge


func get_target_entry(
	target_location: Location,
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> LocationEntry:
	if target_location == null or edge == null:
		return null
	if target_location.instance_id != edge.target_location_id:
		push_error(
			"Location edge '%s/%s' targets instance_id '%s', but prepared Location is '%s'."
			% [from_location_id, edge.edge_key, edge.target_location_id, target_location.instance_id]
		)
		return null
	var entry := target_location.get_entry(edge.target_entry_id)
	if entry == null:
		push_error(
			"Location edge '%s/%s' targets instance_id '%s' with entry_id '%s', but no such LocationEntry exists."
			% [from_location_id, edge.edge_key, edge.target_location_id, edge.target_entry_id]
		)
	return entry


func clear() -> void:
	_locations.clear()
