class_name LogicalLocation
extends RefCounted

var data: LogicalLocationData
var entity_registry: EntityRegistryRuntime

var _entity_ids_by_cell: Dictionary[Vector2i, Array] = {}
var _occupied_cells_by_entity_id: Dictionary[StringName, Array] = {}


func _init(
	p_data: LogicalLocationData,
	p_entity_registry: EntityRegistryRuntime
) -> void:
	data = p_data
	entity_registry = p_entity_registry


var location_id: StringName:
	get:
		return data.location_id if data != null else &""

var bounds: Rect2i:
	get:
		return data.bounds if data != null else Rect2i()


func contains_cell(cell: Vector2i) -> bool:
	return data != null and data.contains_cell(cell)


func is_statically_walkable(cell: Vector2i) -> bool:
	return data != null and data.is_statically_walkable(cell)


func get_movement_cost(cell: Vector2i) -> int:
	return data.get_movement_cost(cell) if data != null else 0


func is_currently_walkable(cell: Vector2i, ignored_entity_id := &"") -> bool:
	if not is_statically_walkable(cell):
		return false
	for entity in get_entities_at(cell):
		if entity.entity_id != ignored_entity_id and entity.is_blocking_movement():
			return false
	return true


func get_entry(entry_id: StringName) -> Dictionary:
	return data.get_entry(entry_id) if data != null else {}


func get_exit(edge_key: StringName) -> Dictionary:
	return data.get_exit(edge_key) if data != null else {}


func get_entities_at(cell: Vector2i) -> Array[Entity]:
	var entities: Array[Entity] = []
	if entity_registry == null or not _entity_ids_by_cell.has(cell):
		return entities
	var entity_ids: Array = _entity_ids_by_cell[cell]
	for entity_id_value: Variant in entity_ids:
		var entity_id: StringName = entity_id_value
		if not entity_registry.has_entity(entity_id):
			continue
		var entity := entity_registry.get_entity(entity_id)
		if entity.current_location_id == location_id:
			entities.append(entity)
	return entities


func get_entity_occupied_cells(entity: Entity) -> Array[Vector2i]:
	if entity == null or entity.current_location_id != location_id:
		return []
	if _occupied_cells_by_entity_id.has(entity.entity_id):
		var cached: Array = _occupied_cells_by_entity_id[entity.entity_id]
		var typed_cells: Array[Vector2i] = []
		for cell_value: Variant in cached:
			typed_cells.append(cell_value)
		return typed_cells
	return entity.get_occupied_grid_cells()


func get_entities_in_location() -> Array[Entity]:
	return (
		entity_registry.get_entities_in_location(location_id)
		if entity_registry != null
		else []
	)


func get_entities_supporting_action(
	action_id: StringName,
	actor: Actor = null
) -> Array[Entity]:
	var entities: Array[Entity] = []
	for entity in get_entities_in_location():
		if entity != actor and entity.get_supported_actions(actor).has(action_id):
			entities.append(entity)
	return entities


func get_entity_use_slots(
	entity: Entity,
	action_id := &"",
	actor: Actor = null
) -> Array[EntityUseSlot]:
	if entity == null or entity.current_location_id != location_id:
		return []
	var supported_actions := entity.get_supported_actions(actor)
	if not action_id.is_empty() and not supported_actions.has(action_id):
		return []

	var occupied_cells := entity.get_occupied_grid_cells()
	if occupied_cells.is_empty():
		return []
	var footprint_origin := _get_footprint_origin(occupied_cells)
	if entity is Furniture and not (entity as Furniture).definition.use_slots.is_empty():
		return _get_explicit_use_slots(
			entity as Furniture,
			footprint_origin,
			action_id
		)
	return _get_default_use_slots(entity, occupied_cells, supported_actions, action_id)


func get_valid_entity_use_slots(
	entity: Entity,
	action_id := &"",
	actor: Actor = null
) -> Array[EntityUseSlot]:
	var slots: Array[EntityUseSlot] = []
	var ignored_entity_id := actor.entity_id if actor != null else &""
	for slot in get_entity_use_slots(entity, action_id, actor):
		if is_currently_walkable(slot.cell, ignored_entity_id):
			slots.append(slot)
	return slots


func is_actor_at_valid_use_slot(
	actor: Actor,
	entity: Entity,
	action_id: StringName
) -> bool:
	if actor == null or entity == null or actor.current_location_id != location_id:
		return false
	for slot in get_valid_entity_use_slots(entity, action_id, actor):
		if slot.cell == actor.current_cell and slot.required_facing == actor.facing:
			return true
	return false


func can_place_entity_at(entity: Entity, target_local_position: Vector2) -> bool:
	if entity == null:
		return false
	var occupied_cells := entity.get_occupied_grid_cells_at(target_local_position)
	if occupied_cells.is_empty():
		return false
	for cell in occupied_cells:
		if not is_currently_walkable(cell, entity.entity_id):
			return false
	return true


func rebuild_spatial_index() -> void:
	_entity_ids_by_cell.clear()
	_occupied_cells_by_entity_id.clear()
	for entity in get_entities_in_location():
		index_entity(entity)


func index_entity(entity: Entity) -> void:
	if entity == null or entity.current_location_id != location_id:
		return
	remove_entity(entity.entity_id)
	var occupied_cells := entity.get_occupied_grid_cells()
	_occupied_cells_by_entity_id[entity.entity_id] = occupied_cells.duplicate()
	for cell in occupied_cells:
		var entity_ids: Array
		if _entity_ids_by_cell.has(cell):
			entity_ids = _entity_ids_by_cell[cell]
		else:
			entity_ids = []
			_entity_ids_by_cell[cell] = entity_ids
		if not entity_ids.has(entity.entity_id):
			entity_ids.append(entity.entity_id)
			entity_ids.sort()


func remove_entity(entity_id: StringName) -> void:
	if not _occupied_cells_by_entity_id.has(entity_id):
		return
	var occupied_cells: Array = _occupied_cells_by_entity_id[entity_id]
	for cell_value: Variant in occupied_cells:
		var cell: Vector2i = cell_value
		if not _entity_ids_by_cell.has(cell):
			continue
		var entity_ids: Array = _entity_ids_by_cell[cell]
		entity_ids.erase(entity_id)
		if entity_ids.is_empty():
			_entity_ids_by_cell.erase(cell)
	_occupied_cells_by_entity_id.erase(entity_id)


func get_world_rect() -> Rect2:
	return Rect2(
		Vector2(bounds.position * LogicalLocationData.CELL_SIZE),
		Vector2(bounds.size * LogicalLocationData.CELL_SIZE)
	)


func _get_explicit_use_slots(
	furniture: Furniture,
	footprint_origin: Vector2i,
	action_id: StringName
) -> Array[EntityUseSlot]:
	var slots: Array[EntityUseSlot] = []
	for definition in furniture.definition.use_slots:
		if definition == null:
			continue
		if not action_id.is_empty() and not definition.supported_actions.has(action_id):
			continue
		slots.append(
			EntityUseSlot.new(
				furniture.entity_id,
				footprint_origin + definition.relative_cell,
				definition.required_facing,
				definition.supported_actions,
				true
			)
		)
	return slots


func _get_default_use_slots(
	entity: Entity,
	occupied_cells: Array[Vector2i],
	supported_actions: Array[StringName],
	action_id: StringName
) -> Array[EntityUseSlot]:
	var slot_actions := supported_actions
	if not action_id.is_empty():
		slot_actions = [action_id]
	var occupied_lookup: Dictionary[Vector2i, bool] = {}
	for cell in occupied_cells:
		occupied_lookup[cell] = true
	var slots_by_key: Dictionary[String, EntityUseSlot] = {}
	var directions: Array[Dictionary] = [
		{"offset": Vector2i.UP, "facing": ActorState.Facing.DOWN},
		{"offset": Vector2i.LEFT, "facing": ActorState.Facing.RIGHT},
		{"offset": Vector2i.RIGHT, "facing": ActorState.Facing.LEFT},
		{"offset": Vector2i.DOWN, "facing": ActorState.Facing.UP},
	]
	for occupied_cell in occupied_cells:
		for direction in directions:
			var slot_cell: Vector2i = occupied_cell + direction["offset"]
			if occupied_lookup.has(slot_cell):
				continue
			var required_facing: ActorState.Facing = direction["facing"]
			var key := "%d:%d:%d" % [slot_cell.y, slot_cell.x, required_facing]
			if not slots_by_key.has(key):
				slots_by_key[key] = EntityUseSlot.new(
					entity.entity_id,
					slot_cell,
					required_facing,
					slot_actions,
					false
				)
	var keys := slots_by_key.keys()
	keys.sort()
	var slots: Array[EntityUseSlot] = []
	for key_value: Variant in keys:
		slots.append(slots_by_key[key_value])
	return slots


func _get_footprint_origin(cells: Array[Vector2i]) -> Vector2i:
	var origin := cells[0]
	for cell in cells:
		origin = origin.min(cell)
	return origin
