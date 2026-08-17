class_name EntityRegistryRuntime
extends Node

var _entities: Dictionary[StringName, Entity] = {}


func register_entity(entity: Entity) -> bool:
	if not _validate_entity(entity):
		return false
	if _entities.has(entity.instance_id):
		push_error("EntityRegistry already contains instance_id '%s'." % entity.instance_id)
		return false

	_entities[entity.instance_id] = entity
	return true


func has_entity(instance_id: StringName) -> bool:
	return _entities.has(instance_id)


func get_entity(instance_id: StringName) -> Entity:
	if not _entities.has(instance_id):
		push_error("EntityRegistry has no Entity with instance_id '%s'." % instance_id)
		return null
	return _entities[instance_id]


func get_entities() -> Array[Entity]:
	var entities: Array[Entity] = []
	var instance_ids := _entities.keys()
	instance_ids.sort()
	for instance_id in instance_ids:
		entities.append(_entities[instance_id])
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
	if not UuidValidator.is_valid_v4(entity.instance_id):
		push_error(
			"Entity instance_id '%s' is not a valid UUID v4." % entity.instance_id
		)
		return false
	if entity.get_definition() == null:
		push_error("Entity instance_id '%s' requires a Definition Resource." % entity.instance_id)
		return false
	return true
