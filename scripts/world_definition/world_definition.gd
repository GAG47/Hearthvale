class_name WorldDefinitionRuntime
extends Node

var definitions_valid := false

var _locations: Dictionary[StringName, LocationDefinition] = {}
var _edges_by_location: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	var definitions := _create_current_world_definitions()
	definitions_valid = validate_definitions(definitions)
	if not definitions_valid:
		push_error("WorldDefinition initialization failed; Location queries are unavailable.")
		return
	_index_definitions(definitions)
	if not validate_world_scene_graph():
		definitions_valid = false
		push_error(
			"WorldDefinition Scene consistency validation failed; Location queries are unavailable."
		)


func has_location(location_id: StringName) -> bool:
	return definitions_valid and _locations.has(location_id)


func get_location(location_id: StringName) -> LocationDefinition:
	if not definitions_valid:
		push_error("Cannot query location_id '%s': WorldDefinition is invalid." % location_id)
		return null
	if not _locations.has(location_id):
		push_error("WorldDefinition has no LocationDefinition for location_id '%s'." % location_id)
		return null
	return _locations[location_id]


func get_locations() -> Array[LocationDefinition]:
	var definitions: Array[LocationDefinition] = []
	var location_ids := _locations.keys()
	location_ids.sort()
	for location_id in location_ids:
		definitions.append(_locations[location_id])
	return definitions


func get_scene_path(location_id: StringName) -> String:
	var definition := get_location(location_id)
	return definition.scene_path if definition != null else ""


func get_outgoing_edges(location_id: StringName) -> Array[LocationEdgeDefinition]:
	var definition := get_location(location_id)
	return definition.outgoing_edges.duplicate() if definition != null else []


func get_edge(location_id: StringName, edge_key: StringName) -> LocationEdgeDefinition:
	if get_location(location_id) == null:
		return null
	var edges: Dictionary = _edges_by_location[location_id]
	if not edges.has(edge_key):
		push_error(
			"Location '%s' has no outgoing edge with edge_key '%s'."
			% [location_id, edge_key]
		)
		return null
	return edges[edge_key] as LocationEdgeDefinition


func validate_loaded_location(location: GridScene, requested_location_id: StringName) -> bool:
	var definition := get_location(requested_location_id)
	if definition == null:
		return false
	if location == null:
		push_error(
			"Location '%s' expected Scene '%s', but it did not instantiate as GridScene."
			% [requested_location_id, definition.scene_path]
		)
		return false
	if location.location_id != requested_location_id:
		push_error(
			"Requested location_id '%s' from Scene '%s', but the loaded GridScene declares location_id '%s'."
			% [requested_location_id, definition.scene_path, location.location_id]
		)
		return false
	if not location.scene_file_path.is_empty() and location.scene_file_path != definition.scene_path:
		push_error(
			"Location '%s' is defined by Scene '%s', but loaded Scene source is '%s'."
			% [requested_location_id, definition.scene_path, location.scene_file_path]
		)
		return false

	var valid := _validate_location_entries(location)
	var scene_exit_edge_keys: Dictionary[StringName, bool] = {}
	for location_exit in _find_location_exits(location):
		if not location_exit.edge_key.is_empty():
			scene_exit_edge_keys[location_exit.edge_key] = true
		if get_edge(requested_location_id, location_exit.edge_key) == null:
			push_error(
				"Scene '%s' for location_id '%s' contains LocationExit edge_key '%s', but that outgoing edge is not defined."
				% [definition.scene_path, requested_location_id, location_exit.edge_key]
			)
			valid = false

	for edge in definition.outgoing_edges:
		if not scene_exit_edge_keys.has(edge.edge_key):
			push_error(
				"LocationDefinition for location_id '%s' contains outgoing edge_key '%s', but Scene '%s' has no corresponding LocationExit."
				% [requested_location_id, edge.edge_key, definition.scene_path]
			)
			valid = false
	return valid


func validate_world_scene_graph() -> bool:
	if not definitions_valid:
		push_error("Cannot validate Location Scenes while WorldDefinition is invalid.")
		return false

	var valid := true
	var loaded_locations: Dictionary[StringName, GridScene] = {}
	for definition_value in _locations.values():
		var definition := definition_value as LocationDefinition
		var packed_scene := load(definition.scene_path) as PackedScene
		if packed_scene == null:
			push_error(
				"Location '%s' scene_path '%s' could not be loaded during Scene consistency validation."
				% [definition.location_id, definition.scene_path]
			)
			valid = false
			continue

		var location := packed_scene.instantiate() as GridScene
		if location == null:
			push_error(
				"Location '%s' scene_path '%s' did not instantiate as GridScene during Scene consistency validation."
				% [definition.location_id, definition.scene_path]
			)
			valid = false
			continue

		loaded_locations[definition.location_id] = location
		if not validate_loaded_location(location, definition.location_id):
			valid = false

	for definition_value in _locations.values():
		var definition := definition_value as LocationDefinition
		for edge in definition.outgoing_edges:
			var target_location := loaded_locations.get(edge.to_location) as GridScene
			if target_location == null:
				push_error(
					"Location edge '%s/%s' targets location_id '%s' with to_entry '%s', but the target Scene was not available for validation."
					% [
						definition.location_id,
						edge.edge_key,
						edge.to_location,
						edge.to_entry,
					]
				)
				valid = false
				continue
			if get_target_entry(target_location, definition.location_id, edge) == null:
				valid = false

	for location in loaded_locations.values():
		(location as GridScene).free()
	return valid


func get_target_entry(
	target_location: GridScene,
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> LocationEntry:
	if target_location == null or edge == null:
		return null
	if target_location.location_id != edge.to_location:
		push_error(
			"Location edge '%s/%s' targets location_id '%s' and to_entry '%s', but loaded location_id is '%s'."
			% [
				from_location_id,
				edge.edge_key,
				edge.to_location,
				edge.to_entry,
				target_location.location_id,
			]
		)
		return null

	var entry := target_location.get_location_entry(edge.to_entry)
	if entry == null:
		push_error(
			"Location edge '%s/%s' targets location_id '%s' with to_entry '%s', but Scene '%s' has no such LocationEntry."
			% [
				from_location_id,
				edge.edge_key,
				edge.to_location,
				edge.to_entry,
				target_location.scene_file_path,
			]
		)
	return entry


static func validate_definitions(definitions: Array[LocationDefinition]) -> bool:
	var valid := true
	var known_locations: Dictionary[StringName, LocationDefinition] = {}

	for definition in definitions:
		if definition == null:
			push_error("WorldDefinition contains a null LocationDefinition.")
			valid = false
			continue
		if definition.location_id.is_empty():
			push_error("Every LocationDefinition requires a non-empty location_id.")
			valid = false
			continue
		if known_locations.has(definition.location_id):
			push_error("Duplicate LocationDefinition location_id '%s'." % definition.location_id)
			valid = false
			continue
		known_locations[definition.location_id] = definition

		if definition.display_name.is_empty():
			push_error("Location '%s' requires a non-empty display_name." % definition.location_id)
			valid = false
		if definition.scene_path.is_empty():
			push_error("Location '%s' requires a non-empty scene_path." % definition.location_id)
			valid = false
		elif not ResourceLoader.exists(definition.scene_path, "PackedScene"):
			push_error(
				"Location '%s' scene_path '%s' does not exist as a PackedScene."
				% [definition.location_id, definition.scene_path]
			)
			valid = false
		elif load(definition.scene_path) as PackedScene == null:
			push_error(
				"Location '%s' scene_path '%s' could not be loaded as a PackedScene."
				% [definition.location_id, definition.scene_path]
			)
			valid = false

		var known_edge_keys: Dictionary[StringName, bool] = {}
		for edge in definition.outgoing_edges:
			if edge == null:
				push_error("Location '%s' contains a null outgoing edge." % definition.location_id)
				valid = false
				continue
			if edge.edge_key.is_empty():
				push_error(
					"Location '%s' has an outgoing edge with an empty edge_key (to_location '%s', to_entry '%s')."
					% [definition.location_id, edge.to_location, edge.to_entry]
				)
				valid = false
			elif known_edge_keys.has(edge.edge_key):
				push_error(
					"Location '%s' defines duplicate edge_key '%s' (to_location '%s', to_entry '%s')."
					% [definition.location_id, edge.edge_key, edge.to_location, edge.to_entry]
				)
				valid = false
			else:
				known_edge_keys[edge.edge_key] = true
			if edge.to_location.is_empty():
				push_error(
					"Location '%s' edge_key '%s' requires a non-empty to_location (to_entry '%s')."
					% [definition.location_id, edge.edge_key, edge.to_entry]
				)
				valid = false
			if edge.to_entry.is_empty():
				push_error(
					"Location '%s' edge_key '%s' to_location '%s' requires a non-empty to_entry."
					% [definition.location_id, edge.edge_key, edge.to_location]
				)
				valid = false

	for definition in definitions:
		if definition == null or definition.location_id.is_empty():
			continue
		for edge in definition.outgoing_edges:
			if edge == null or edge.to_location.is_empty():
				continue
			if not known_locations.has(edge.to_location):
				push_error(
					"Location '%s' edge_key '%s' targets unknown to_location '%s' with to_entry '%s'."
					% [definition.location_id, edge.edge_key, edge.to_location, edge.to_entry]
				)
				valid = false

	return valid


func _index_definitions(definitions: Array[LocationDefinition]) -> void:
	for definition in definitions:
		_locations[definition.location_id] = definition
		var edges: Dictionary[StringName, LocationEdgeDefinition] = {}
		for edge in definition.outgoing_edges:
			edges[edge.edge_key] = edge
		_edges_by_location[definition.location_id] = edges


func _create_current_world_definitions() -> Array[LocationDefinition]:
	var tavern_edges: Array[LocationEdgeDefinition] = [
		LocationEdgeDefinition.new(&"front_door", &"town_street", &"tavern_entrance"),
		LocationEdgeDefinition.new(&"back_door", &"tavern_yard", &"tavern_entrance"),
	]
	var street_edges: Array[LocationEdgeDefinition] = [
		LocationEdgeDefinition.new(&"tavern_door", &"tavern", &"front_door"),
	]
	var yard_edges: Array[LocationEdgeDefinition] = [
		LocationEdgeDefinition.new(&"tavern_door", &"tavern", &"back_door"),
	]

	var definitions: Array[LocationDefinition] = [
		LocationDefinition.new(&"tavern", "酒馆", "res://scenes/tavern.tscn", tavern_edges),
		LocationDefinition.new(
			&"town_street",
			"小镇街道",
			"res://scenes/town_street.tscn",
			street_edges
		),
		LocationDefinition.new(
			&"tavern_yard",
			"酒馆后院",
			"res://scenes/tavern_yard.tscn",
			yard_edges
		),
	]
	return definitions


func _validate_location_entries(location: GridScene) -> bool:
	var valid := true
	var known_entry_ids: Dictionary[StringName, bool] = {}
	for entry in location.get_location_entries():
		if entry.entry_id.is_empty():
			push_error(
				"Location '%s' Scene '%s' contains a LocationEntry with an empty entry_id."
				% [location.location_id, location.scene_file_path]
			)
			valid = false
		elif known_entry_ids.has(entry.entry_id):
			push_error(
				"Location '%s' Scene '%s' contains duplicate LocationEntry entry_id '%s'."
				% [location.location_id, location.scene_file_path, entry.entry_id]
			)
			valid = false
		else:
			known_entry_ids[entry.entry_id] = true
	return valid


func _find_location_exits(root: Node) -> Array[LocationExit]:
	var exits: Array[LocationExit] = []
	_collect_location_exits(root, exits)
	return exits


func _collect_location_exits(node: Node, exits: Array[LocationExit]) -> void:
	for child in node.get_children():
		if child is LocationExit:
			exits.append(child as LocationExit)
		_collect_location_exits(child, exits)
