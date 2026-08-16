class_name LocationRuntime
extends RefCounted

var definition: LocationDefinition
var state: LocationState
var definition_registry: DefinitionRegistryRuntime
var entity_registry: EntityRegistryRuntime

var instance_id: StringName:
	get:
		return state.instance_id if state != null else &""

var location_id: StringName:
	get:
		return instance_id


func _init(
	p_definition: LocationDefinition,
	p_state: LocationState,
	p_definition_registry: DefinitionRegistryRuntime,
	p_entity_registry: EntityRegistryRuntime
) -> void:
	definition = p_definition
	state = p_state
	definition_registry = p_definition_registry
	entity_registry = p_entity_registry


func is_valid() -> bool:
	return (
		definition != null
		and state != null
		and definition_registry != null
		and entity_registry != null
		and UuidValidator.is_valid_v4(state.instance_id)
		and state.definition_id == definition.definition_id
	)


func get_ground_definition_id(cell: Vector2i) -> StringName:
	if state.ground_overrides.has(cell):
		return state.ground_overrides[cell]
	return definition.ground_layer.get(cell, &"") as StringName


func get_ground_definition(cell: Vector2i) -> GroundDefinition:
	var definition_id := get_ground_definition_id(cell)
	if definition_id.is_empty():
		return null
	return definition_registry.get_definition(definition_id) as GroundDefinition


func get_current_decorations() -> Array[DecorationPlacement]:
	var placements: Array[DecorationPlacement] = []
	for placement in definition.decoration_placements:
		if not state.removed_decoration_ids.get(placement.placement_id, false):
			placements.append(placement)
	placements.append_array(state.added_decorations)
	return placements


func get_current_structures() -> Array[StructurePlacement]:
	var placements: Array[StructurePlacement] = []
	for placement in definition.structure_placements:
		if not state.removed_structure_ids.get(placement.placement_id, false):
			placements.append(placement)
	placements.append_array(state.added_structures)
	return placements


func get_structure_cells(placement: StructurePlacement) -> Array[Vector2i]:
	if placement == null:
		return []
	var structure_definition := (
		definition_registry.get_definition(placement.definition_id) as StructureDefinition
	)
	return placement.get_world_cells(structure_definition)


func get_structures_at(cell: Vector2i) -> Array[StructurePlacement]:
	var placements: Array[StructurePlacement] = []
	for placement in get_current_structures():
		if get_structure_cells(placement).has(cell):
			placements.append(placement)
	return placements


func get_current_edges() -> Array[LocationEdgeDefinition]:
	var edges: Array[LocationEdgeDefinition] = []
	for edge in definition.outgoing_edges:
		if (
			not state.removed_edge_ids.get(edge.edge_id, false)
			and not state.disabled_edge_ids.get(edge.edge_id, false)
		):
			edges.append(edge)
	for edge in state.added_edges:
		if not state.disabled_edge_ids.get(edge.edge_id, false):
			edges.append(edge)
	return edges


func get_edge(edge_key: StringName) -> LocationEdgeDefinition:
	for edge in get_current_edges():
		if edge.edge_key == edge_key:
			return edge
	return null


func get_entry(entry_id: StringName) -> LocationEntryAnchor:
	for anchor in definition.anchors:
		if anchor is LocationEntryAnchor and (anchor as LocationEntryAnchor).entry_id == entry_id:
			return anchor as LocationEntryAnchor
	return null


func get_exit_anchors() -> Array[LocationExitAnchor]:
	var exits: Array[LocationExitAnchor] = []
	for anchor in definition.anchors:
		if anchor is LocationExitAnchor:
			exits.append(anchor as LocationExitAnchor)
	return exits


func get_entities() -> Array[Entity]:
	return entity_registry.get_entities_in_location(instance_id)


func get_entities_at(cell: Vector2i) -> Array[Entity]:
	var entities: Array[Entity] = []
	for entity in get_entities():
		if entity.get_occupied_grid_cells().has(cell):
			entities.append(entity)
	return entities


func is_cell_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= definition.grid_size.x or cell.y >= definition.grid_size.y:
		return false
	var ground := get_ground_definition(cell)
	if ground == null or not ground.walkable:
		return false
	for placement in get_structures_at(cell):
		var structure := (
			definition_registry.get_definition(placement.definition_id) as StructureDefinition
		)
		if structure != null and structure.blocks_movement:
			return false
	for entity in get_entities_at(cell):
		if entity is Furniture and (entity as Furniture).definition.blocks_movement:
			return false
	return true
