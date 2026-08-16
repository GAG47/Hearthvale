class_name WorldDefinitionRuntime
extends Node

const PROJECT_WORLD_DATA_PATH := "res://data/world/project_world.json"
const ACTOR_DEFINITION_PATHS: Array[String] = [
	"res://data/actors/player.json",
	"res://data/actors/martha.json",
]
const FURNITURE_DEFINITION_PATHS: Array[String] = [
	"res://data/furniture/wooden_chest.json",
	"res://data/furniture/sign.json",
	"res://data/furniture/simple_bed.json",
]

var definitions_valid := false
var definition_registry: DefinitionRegistryRuntime

var _definition_ids_by_location: Dictionary[StringName, StringName] = {}
var _location_ids_by_project_key: Dictionary[StringName, StringName] = {}
var _project_location_instance_specs: Array[Dictionary] = []


func _ready() -> void:
	definition_registry = get_node_or_null("/root/DefinitionRegistry") as DefinitionRegistryRuntime
	if definition_registry == null:
		push_error("WorldDefinition requires the DefinitionRegistry Autoload.")
		return
	if not _register_project_entity_definitions():
		return
	var project_world := ProjectWorldDataLoader.load_from_file(PROJECT_WORLD_DATA_PATH)
	if project_world.is_empty():
		return
	for definition in project_world["definitions"]:
		if not definition_registry.register_project_definition(definition):
			return
	for spec in project_world["instances"]:
		_project_location_instance_specs.append(spec.duplicate())
		_definition_ids_by_location[spec["instance_id"]] = spec["definition_id"]
		_location_ids_by_project_key[spec["key"]] = spec["instance_id"]
	definitions_valid = validate_world_data()
	if not definitions_valid:
		push_error("WorldDefinition initialization failed; Location queries are unavailable.")


func has_location(location_id: StringName) -> bool:
	return definitions_valid and _definition_ids_by_location.has(location_id)


func get_project_location_id(key: StringName) -> StringName:
	if not _location_ids_by_project_key.has(key):
		push_error("WorldDefinition has no project Location key '%s'." % key)
		return &""
	return _location_ids_by_project_key[key]


func get_project_location_instance_specs() -> Array[Dictionary]:
	return _project_location_instance_specs.duplicate(true)


func get_location_definition(location_id: StringName) -> LocationDefinition:
	if not has_location(location_id):
		push_error("WorldDefinition has no Location instance_id '%s'." % location_id)
		return null
	return (
		definition_registry.get_definition(_definition_ids_by_location[location_id])
		as LocationDefinition
	)


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
	var location := LocationRuntime.new(
		location_definition,
		state,
		definition_registry,
		entity_registry
	)
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
) -> LocationEntryAnchor:
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
			"Location edge '%s/%s' targets instance_id '%s' with entry_id '%s', but no such Entry Anchor exists."
			% [from_location_id, edge.edge_key, edge.target_location_id, edge.target_entry_id]
		)
	return entry


func register_generated_location(
	definition: LocationDefinition,
	state: LocationState
) -> bool:
	if definition == null or state == null or state.definition_id != definition.definition_id:
		push_error("Generated Location registration requires matching Definition and State.")
		return false
	if not UuidValidator.is_valid_v4(state.instance_id) or has_location(state.instance_id):
		push_error("Generated Location instance_id '%s' is invalid or already used." % state.instance_id)
		return false
	var world_state := get_node_or_null("/root/WorldState") as WorldStateRuntime
	if world_state == null or world_state.has_location_state(state.instance_id):
		return false
	if not _validate_location_definition(definition, false):
		return false
	if not definition_registry.register_generated_definition(definition):
		return false
	if not world_state.register_location_state(state):
		return false
	_definition_ids_by_location[state.instance_id] = definition.definition_id
	return true


func validate_world_data() -> bool:
	var valid := true
	var known_locations: Dictionary[StringName, bool] = {}
	for spec in _project_location_instance_specs:
		var instance_id: StringName = spec["instance_id"]
		var definition_id: StringName = spec["definition_id"]
		if (
			not UuidValidator.is_valid_v4(instance_id)
			or not UuidValidator.is_valid_v4(definition_id)
			or known_locations.has(instance_id)
		):
			push_error("Invalid or duplicate project Location instance_id '%s'." % instance_id)
			valid = false
			continue
		known_locations[instance_id] = true
		var definition := definition_registry.get_definition(definition_id) as LocationDefinition
		if definition == null or not _validate_location_definition(definition, true):
			valid = false

	for spec in _project_location_instance_specs:
		var definition := (
			definition_registry.get_definition(spec["definition_id"]) as LocationDefinition
		)
		if definition == null:
			continue
		for edge in definition.outgoing_edges:
			if not known_locations.has(edge.target_location_id):
				push_error(
					"Location Definition '%s' edge '%s' targets unknown Location instance_id '%s'."
					% [definition.definition_id, edge.edge_key, edge.target_location_id]
				)
				valid = false
				continue
			var target_definition_id := _definition_ids_by_location[edge.target_location_id]
			var target_definition := (
				definition_registry.get_definition(target_definition_id) as LocationDefinition
			)
			if target_definition == null or not _has_entry(target_definition, edge.target_entry_id):
				push_error(
					"Location Definition '%s' edge '%s' targets missing Entry '%s'."
					% [definition.definition_id, edge.edge_key, edge.target_entry_id]
				)
				valid = false
	return valid


func _validate_location_definition(definition: LocationDefinition, require_complete_ground: bool) -> bool:
	var valid := true
	if (
		not UuidValidator.is_valid_v4(definition.definition_id)
		or definition.display_name.strip_edges().is_empty()
		or definition.grid_size.x <= 0
		or definition.grid_size.y <= 0
	):
		push_error("LocationDefinition '%s' has invalid identity, name, or grid size." % definition.definition_id)
		return false
	if require_complete_ground and definition.ground_layer.size() != definition.grid_size.x * definition.grid_size.y:
		push_error(
			"LocationDefinition '%s' Ground Layer does not cover its complete grid."
			% definition.definition_id
		)
		valid = false
	for cell in definition.ground_layer:
		if not _cell_in_grid(cell, definition.grid_size):
			valid = false
		var ground := definition_registry.get_definition(definition.ground_layer[cell])
		if not ground is GroundDefinition:
			push_error("Location Ground cell %s does not reference GroundDefinition." % cell)
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
			push_error("LocationDefinition '%s' has an invalid or duplicate edge." % definition.definition_id)
			valid = false
			continue
		edge_ids[edge.edge_id] = true
		edge_keys[edge.edge_key] = true

	var placement_ids: Dictionary[StringName, bool] = {}
	for placement in definition.structure_placements:
		if (
			placement == null
			or not UuidValidator.is_valid_v4(placement.placement_id)
			or placement_ids.has(placement.placement_id)
			or not StructurePlacement.VALID_ORIENTATIONS.has(placement.orientation)
		):
			push_error("LocationDefinition '%s' has an invalid StructurePlacement." % definition.definition_id)
			valid = false
			continue
		placement_ids[placement.placement_id] = true
		var structure := definition_registry.get_definition(placement.definition_id)
		if not structure is StructureDefinition or structure.occupied_cells.is_empty():
			push_error("StructurePlacement '%s' does not reference StructureDefinition." % placement.placement_id)
			valid = false

	for placement in definition.decoration_placements:
		if (
			placement == null
			or not UuidValidator.is_valid_v4(placement.placement_id)
			or placement_ids.has(placement.placement_id)
		):
			push_error("LocationDefinition '%s' has an invalid DecorationPlacement." % definition.definition_id)
			valid = false
			continue
		placement_ids[placement.placement_id] = true
		if not definition_registry.get_definition(placement.definition_id) is DecorationDefinition:
			push_error("DecorationPlacement '%s' does not reference DecorationDefinition." % placement.placement_id)
			valid = false

	var entry_ids: Dictionary[StringName, bool] = {}
	var exit_keys: Dictionary[StringName, bool] = {}
	for anchor in definition.anchors:
		if anchor is LocationEntryAnchor:
			var entry := anchor as LocationEntryAnchor
			if entry.entry_id.is_empty() or entry_ids.has(entry.entry_id) or not _cell_in_grid(entry.cell, definition.grid_size):
				push_error("LocationDefinition '%s' has an invalid Entry Anchor." % definition.definition_id)
				valid = false
			entry_ids[entry.entry_id] = true
		elif anchor is LocationExitAnchor:
			var exit := anchor as LocationExitAnchor
			if exit.edge_key.is_empty() or exit_keys.has(exit.edge_key) or not edge_keys.has(exit.edge_key):
				push_error("LocationDefinition '%s' has an invalid Exit Anchor." % definition.definition_id)
				valid = false
			exit_keys[exit.edge_key] = true
		else:
			push_error("LocationDefinition '%s' has an unsupported Anchor." % definition.definition_id)
			valid = false
	for edge_key in edge_keys:
		if not exit_keys.has(edge_key):
			push_error("Location edge_key '%s' has no local Exit Anchor." % edge_key)
			valid = false
	return valid


func _register_project_entity_definitions() -> bool:
	for path in ACTOR_DEFINITION_PATHS:
		var definition := ActorDefinitionLoader.load_from_file(path)
		if definition == null or not definition_registry.register_project_definition(definition):
			return false
	for path in FURNITURE_DEFINITION_PATHS:
		var definition := FurnitureDefinitionLoader.load_from_file(path)
		if definition == null or not definition_registry.register_project_definition(definition):
			return false
	return true


static func _cell_in_grid(cell: Vector2i, grid_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


static func _has_entry(definition: LocationDefinition, entry_id: StringName) -> bool:
	for anchor in definition.anchors:
		if anchor is LocationEntryAnchor and (anchor as LocationEntryAnchor).entry_id == entry_id:
			return true
	return false
