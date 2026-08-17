class_name WorldDefinitionRuntime
extends Node

const PROJECT_WORLD: ProjectWorld = preload("res://data/world/project_world.tres")

var definitions_valid := false

var _definitions_by_location: Dictionary[StringName, LocationDefinition] = {}
var _location_ids_by_project_key: Dictionary[StringName, StringName] = {}
var _project_location_instance_specs: Array[ProjectLocationInstanceSpec] = []


func _ready() -> void:
	if PROJECT_WORLD == null:
		push_error("WorldDefinition requires the ProjectWorld Resource.")
		return
	for spec in PROJECT_WORLD.location_instances:
		_project_location_instance_specs.append(spec)
		if spec == null:
			continue
		_definitions_by_location[spec.instance_id] = spec.definition
		_location_ids_by_project_key[spec.key] = spec.instance_id
	definitions_valid = validate_world_data()
	if not definitions_valid:
		push_error("WorldDefinition initialization failed; Location queries are unavailable.")


func has_location(location_id: StringName) -> bool:
	return definitions_valid and _definitions_by_location.has(location_id)


func get_project_location_id(key: StringName) -> StringName:
	if not _location_ids_by_project_key.has(key):
		push_error("WorldDefinition has no project Location key '%s'." % key)
		return &""
	return _location_ids_by_project_key[key]


func get_project_location_instance_specs() -> Array[ProjectLocationInstanceSpec]:
	return _project_location_instance_specs.duplicate()


func get_location_definition(location_id: StringName) -> LocationDefinition:
	if not has_location(location_id):
		push_error("WorldDefinition has no Location instance_id '%s'." % location_id)
		return null
	return _definitions_by_location[location_id]


func get_location(location_id: StringName) -> LocationRuntime:
	var location_definition := get_location_definition(location_id)
	if location_definition == null:
		return null
	var world_state := get_node_or_null("/root/WorldState") as WorldStateRuntime
	var entity_registry := get_node_or_null("/root/EntityRegistry") as EntityRegistryRuntime
	if world_state == null or entity_registry == null:
		push_error("Location Runtime requires WorldState and EntityRegistry.")
		return null
	var state := world_state.get_location_state(location_id)
	if state == null:
		push_error("Location instance_id '%s' has no LocationState." % location_id)
		return null
	var location := LocationRuntime.new(location_definition, state, entity_registry)
	return location if location.is_valid() else null


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
	target_location: LocationRuntime,
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


func validate_world_data() -> bool:
	var valid := true
	var known_locations: Dictionary[StringName, bool] = {}
	var known_keys: Dictionary[StringName, bool] = {}
	for spec in _project_location_instance_specs:
		if (
			spec == null
			or spec.key.is_empty()
			or not UuidValidator.is_valid_v4(spec.instance_id)
			or spec.definition == null
			or known_locations.has(spec.instance_id)
			or known_keys.has(spec.key)
		):
			var invalid_id := spec.instance_id if spec != null else &""
			push_error("Invalid or duplicate project Location instance_id '%s'." % invalid_id)
			valid = false
			continue
		known_locations[spec.instance_id] = true
		known_keys[spec.key] = true
		if not _validate_location_definition(spec.definition, true):
			valid = false

	for spec in _project_location_instance_specs:
		if spec == null or spec.definition == null:
			continue
		for edge in spec.definition.outgoing_edges:
			if edge == null:
				continue
			if not known_locations.has(edge.target_location_id):
				push_error(
					"Location '%s' edge '%s' targets unknown Location instance_id '%s'."
					% [spec.key, edge.edge_key, edge.target_location_id]
				)
				valid = false
				continue
			var target_definition := _definitions_by_location[edge.target_location_id]
			if target_definition == null or not _has_entry(target_definition, edge.target_entry_id):
				push_error(
					"Location '%s' edge '%s' targets missing Entry '%s'."
					% [spec.key, edge.edge_key, edge.target_entry_id]
				)
				valid = false
	return valid


func _validate_location_definition(
	definition: LocationDefinition,
	require_complete_ground: bool
) -> bool:
	var valid := true
	var definition_name := definition.resource_path
	if definition_name.is_empty():
		definition_name = definition.display_name
	if (
		definition.display_name.strip_edges().is_empty()
		or definition.grid_size.x <= 0
		or definition.grid_size.y <= 0
	):
		push_error("LocationDefinition '%s' has an invalid name or grid size." % definition_name)
		return false
	if require_complete_ground and definition.ground_layer.size() != definition.grid_size.x * definition.grid_size.y:
		push_error("LocationDefinition '%s' Ground Layer does not cover its complete grid." % definition_name)
		valid = false
	for cell in definition.ground_layer:
		if not _cell_in_grid(cell, definition.grid_size) or definition.ground_layer[cell] == null:
			push_error("Location Ground cell %s has an invalid GroundTileDefinition reference." % cell)
			valid = false
	for cell in definition.decoration_layer:
		if not _cell_in_grid(cell, definition.grid_size) or definition.decoration_layer[cell] == null:
			push_error("Location Decoration cell %s has an invalid DecorationTileDefinition reference." % cell)
			valid = false
	for cell in definition.structure_layer:
		if not _cell_in_grid(cell, definition.grid_size) or definition.structure_layer[cell] == null:
			push_error("Location Structure cell %s has an invalid StructureTileDefinition reference." % cell)
			valid = false

	var edge_ids: Dictionary[StringName, bool] = {}
	var edge_keys: Dictionary[StringName, bool] = {}
	for edge in definition.outgoing_edges:
		if (
			edge == null
			or not UuidValidator.is_valid_v4(edge.edge_id)
			or edge.edge_key.is_empty()
			or not UuidValidator.is_valid_v4(edge.target_location_id)
			or edge.target_entry_id.is_empty()
			or edge_ids.has(edge.edge_id)
			or edge_keys.has(edge.edge_key)
		):
			push_error("LocationDefinition '%s' has an invalid or duplicate edge." % definition_name)
			valid = false
			continue
		edge_ids[edge.edge_id] = true
		edge_keys[edge.edge_key] = true

	var entry_ids: Dictionary[StringName, bool] = {}
	var exit_keys: Dictionary[StringName, bool] = {}
	for entry in definition.entries:
		if (
			entry == null
			or entry.entry_id.is_empty()
			or entry_ids.has(entry.entry_id)
			or not _cell_in_grid(entry.cell, definition.grid_size)
		):
			push_error("LocationDefinition '%s' has an invalid LocationEntry." % definition_name)
			valid = false
			continue
		entry_ids[entry.entry_id] = true
	for location_exit in definition.exits:
		if (
			location_exit == null
			or location_exit.edge_key.is_empty()
			or exit_keys.has(location_exit.edge_key)
			or not edge_keys.has(location_exit.edge_key)
			or not _rect_in_grid(location_exit.cell_rect, definition.grid_size)
		):
			push_error("LocationDefinition '%s' has an invalid LocationExit." % definition_name)
			valid = false
			continue
		exit_keys[location_exit.edge_key] = true
	for edge_key in edge_keys:
		if not exit_keys.has(edge_key):
			push_error("Location edge_key '%s' has no local LocationExit." % edge_key)
			valid = false
	return valid


static func _cell_in_grid(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


static func _rect_in_grid(rect: Rect2i, grid_size: Vector2i) -> bool:
	return (
		rect.size.x > 0
		and rect.size.y > 0
		and _cell_in_grid(rect.position, grid_size)
		and rect.end.x <= grid_size.x
		and rect.end.y <= grid_size.y
	)


static func _has_entry(definition: LocationDefinition, entry_id: StringName) -> bool:
	for entry in definition.entries:
		if entry != null and entry.entry_id == entry_id:
			return true
	return false
