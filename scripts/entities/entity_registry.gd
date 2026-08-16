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
	if not UuidValidator.is_valid_v4(entity.definition_id):
		push_error(
			"Entity definition_id '%s' is not a valid UUID v4." % entity.definition_id
		)
		return false
	var definition := entity.get_definition()
	if definition == null or definition.definition_id != entity.definition_id:
		push_error(
			"Entity instance_id '%s' does not match its Definition and EntityState definition_id '%s'."
			% [entity.instance_id, entity.definition_id]
		)
		return false
	var definition_registry: DefinitionRegistryRuntime
	if is_inside_tree():
		definition_registry = get_node_or_null("/root/DefinitionRegistry") as DefinitionRegistryRuntime
	if definition_registry != null:
		if not definition_registry.has_definition(entity.definition_id):
			push_error(
				"Entity instance_id '%s' references unregistered definition_id '%s'."
				% [entity.instance_id, entity.definition_id]
			)
			return false
		if definition_registry.get_definition(entity.definition_id) != definition:
			push_error(
				"Entity instance_id '%s' must use the DefinitionRegistry object for definition_id '%s'."
				% [entity.instance_id, entity.definition_id]
			)
			return false
	return true
