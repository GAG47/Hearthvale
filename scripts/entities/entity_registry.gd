class_name EntityRegistryRuntime
extends Node

signal entities_committed(entities: Array[Entity])

var _entities: Dictionary[StringName, Entity] = {}


func register_entity(entity: Entity) -> bool:
	if not can_register_entity(entity):
		return false

	_entities[entity.entity_id] = entity
	var committed: Array[Entity] = [entity]
	entities_committed.emit(committed)
	return true


func can_register_entity(entity: Entity) -> bool:
	if not _validate_entity(entity):
		return false
	if _entities.has(entity.entity_id):
		push_error("EntityRegistry already contains entity_id '%s'." % entity.entity_id)
		return false
	return true


func can_register_entities(entities: Array[Entity]) -> bool:
	var prepared_ids: Dictionary[StringName, bool] = {}
	for entity in entities:
		if not can_register_entity(entity):
			return false
		if prepared_ids.has(entity.entity_id):
			push_error(
				"EntityRegistry prepared Entities contain duplicate entity_id '%s'."
				% entity.entity_id
			)
			return false
		prepared_ids[entity.entity_id] = true
	return true


func register_entities(entities: Array[Entity]) -> bool:
	if not can_register_entities(entities):
		return false
	commit_prepared_entities(entities)
	return true


func commit_prepared_entities(entities: Array[Entity]) -> void:
	for entity in entities:
		_entities[entity.entity_id] = entity
	if not entities.is_empty():
		entities_committed.emit(entities)


func has_entity(entity_id: StringName) -> bool:
	return _entities.has(entity_id)


func get_entity(entity_id: StringName) -> Entity:
	if not _entities.has(entity_id):
		push_error("EntityRegistry has no Entity with entity_id '%s'." % entity_id)
		return null
	return _entities[entity_id]


func get_entities() -> Array[Entity]:
	var entities: Array[Entity] = []
	var entity_ids := _entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		entities.append(_entities[entity_id])
	return entities


func get_entities_in_location(location_id: StringName) -> Array[Entity]:
	var entities: Array[Entity] = []
	for entity in get_entities():
		if entity.current_location_id == location_id:
			entities.append(entity)
	return entities


func _validate_entity(entity: Entity) -> bool:
	if entity == null:
		push_error("Entity registration requires an Entity.")
		return false
	if entity.state == null:
		push_error("Entity registration requires an EntityState.")
		return false
	if not UuidValidator.is_valid_v4(entity.entity_id):
		push_error(
			"Entity entity_id '%s' is not a valid UUID v4." % entity.entity_id
		)
		return false
	if entity.state.entity_id != entity.entity_id:
		push_error(
			"Entity ID '%s' does not match EntityState ID '%s'."
			% [entity.entity_id, entity.state.entity_id]
		)
		return false
	return true
