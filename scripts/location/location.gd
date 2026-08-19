class_name Location
extends RefCounted

var definition: LocationDefinition
var state: LocationState
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
	p_entity_registry: EntityRegistryRuntime
) -> void:
	definition = p_definition
	state = p_state
	entity_registry = p_entity_registry


func is_valid() -> bool:
	return (
		definition != null
		and state != null
		and entity_registry != null
		and UuidValidator.is_valid_v4(state.instance_id)
	)


func get_ground_tile(cell: Vector2i) -> GroundTileDefinition:
	if state.ground_overrides.has(cell):
		return state.ground_overrides[cell]
	return definition.ground_layer.get(cell) as GroundTileDefinition


func get_current_ground_layer() -> Dictionary[Vector2i, GroundTileDefinition]:
	var layer: Dictionary[Vector2i, GroundTileDefinition] = {}
	var current_cells: Dictionary[Vector2i, bool] = {}
	for cell in definition.ground_layer:
		current_cells[cell] = true
	for cell in state.ground_overrides:
		current_cells[cell] = true
	for cell in current_cells:
		var tile := get_ground_tile(cell)
		if tile != null:
			layer[cell] = tile
	return layer


func get_decoration_tile(cell: Vector2i) -> DecorationTileDefinition:
	if state.decoration_overrides.has(cell):
		return state.decoration_overrides[cell]
	return definition.decoration_layer.get(cell) as DecorationTileDefinition


func get_current_decoration_layer() -> Dictionary[Vector2i, DecorationTileDefinition]:
	var layer: Dictionary[Vector2i, DecorationTileDefinition] = {}
	var current_cells: Dictionary[Vector2i, bool] = {}
	for cell in definition.decoration_layer:
		current_cells[cell] = true
	for cell in state.decoration_overrides:
		current_cells[cell] = true
	for cell in current_cells:
		var tile := get_decoration_tile(cell)
		if tile != null:
			layer[cell] = tile
	return layer


func get_structure_tile(cell: Vector2i) -> StructureTileDefinition:
	if state.structure_overrides.has(cell):
		return state.structure_overrides[cell]
	return definition.structure_layer.get(cell) as StructureTileDefinition


func get_current_structure_layer() -> Dictionary[Vector2i, StructureTileDefinition]:
	var layer: Dictionary[Vector2i, StructureTileDefinition] = {}
	var current_cells: Dictionary[Vector2i, bool] = {}
	for cell in definition.structure_layer:
		current_cells[cell] = true
	for cell in state.structure_overrides:
		current_cells[cell] = true
	for cell in current_cells:
		var tile := get_structure_tile(cell)
		if tile != null:
			layer[cell] = tile
	return layer


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


func get_entry(entry_id: StringName) -> LocationEntry:
	for entry in definition.entries:
		if entry.entry_id == entry_id:
			return entry
	return null


func get_current_entries() -> Array[LocationEntry]:
	return definition.entries.duplicate()


func get_current_exits() -> Array[LocationExit]:
	return definition.exits.duplicate()


func get_entities() -> Array[Entity]:
	return entity_registry.get_entities_in_location(instance_id)


func get_entities_at(cell: Vector2i) -> Array[Entity]:
	var entities: Array[Entity] = []
	for entity in get_entities():
		if entity.get_occupied_grid_cells().has(cell):
			entities.append(entity)
	return entities


func get_use_slots(entity: Entity, action_id: StringName) -> Array[UseSlot]:
	return entity.get_use_slots(action_id) if entity != null else []


func get_use_slot_world_cell(entity: Entity, slot: UseSlot) -> Vector2i:
	return entity.get_use_slot_world_cell(slot) if entity != null else Vector2i.ZERO


func get_slot_entrances(slot: UseSlot) -> Array[SlotEntrance]:
	return slot.get_slot_entrances() if slot != null else []


func get_slot_entrance_world_cell(entity: Entity, entrance: SlotEntrance) -> Vector2i:
	return entity.get_slot_entrance_world_cell(entrance) if entity != null else Vector2i.ZERO


func get_valid_use_slots(entity: Entity, action_id: StringName) -> Array[UseSlot]:
	var slots: Array[UseSlot] = []
	for slot in get_use_slots(entity, action_id):
		if is_use_slot_valid(entity, slot):
			slots.append(slot)
	return slots


func get_valid_slot_entrances(entity: Entity, slot: UseSlot) -> Array[SlotEntrance]:
	var entrances: Array[SlotEntrance] = []
	for entrance in get_slot_entrances(slot):
		if is_slot_entrance_valid(entity, entrance):
			entrances.append(entrance)
	return entrances


func is_use_slot_valid(entity: Entity, slot: UseSlot) -> bool:
	if entity == null or slot == null or entity.current_location_id != instance_id:
		return false
	return _is_cell_standable(get_use_slot_world_cell(entity, slot), entity)


func is_slot_entrance_valid(entity: Entity, entrance: SlotEntrance) -> bool:
	if entity == null or entrance == null or entity.current_location_id != instance_id:
		return false
	return _is_cell_standable(get_slot_entrance_world_cell(entity, entrance))


func is_cell_walkable(cell: Vector2i) -> bool:
	return is_cell_statically_walkable(cell)


func is_cell_statically_walkable(cell: Vector2i, ignored_entity: Entity = null) -> bool:
	if not _has_walkable_terrain(cell):
		return false
	for entity in get_entities_at(cell):
		if entity == ignored_entity or entity is Actor:
			continue
		if entity.blocks_movement():
			return false
	return true


func select_arrival_cell(entry: LocationEntry, moving_actor: Actor = null) -> Dictionary:
	if entry == null:
		return {}
	for cell in entry.arrival_cells:
		if is_cell_statically_walkable(cell, moving_actor):
			return {"cell": cell}
	return {}


func _is_cell_standable(cell: Vector2i, ignored_entity: Entity = null) -> bool:
	return is_cell_statically_walkable(cell, ignored_entity)


func _has_walkable_terrain(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= definition.grid_size.x or cell.y >= definition.grid_size.y:
		return false
	var ground := get_ground_tile(cell)
	if ground == null or not ground.walkable:
		return false
	var structure := get_structure_tile(cell)
	if structure != null and structure.blocks_movement:
		return false
	return true
