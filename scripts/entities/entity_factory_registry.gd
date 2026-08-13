class_name EntityFactoryRegistry
extends RefCounted

var _factories: Array[EntityFactory] = []


static func create_default() -> EntityFactoryRegistry:
	var registry := EntityFactoryRegistry.new()
	registry.register_factory(ActorEntityFactory.new())
	registry.register_factory(FurnitureEntityFactory.new())
	return registry


func register_factory(factory: EntityFactory) -> bool:
	if factory == null:
		push_error("EntityFactoryRegistry cannot register a null Factory.")
		return false
	if _factories.has(factory):
		push_error("EntityFactoryRegistry cannot register the same Factory twice.")
		return false
	_factories.append(factory)
	return true


func get_factory(entity_type: StringName) -> EntityFactory:
	if entity_type.is_empty():
		push_error("EntityFactoryRegistry requires a non-empty entity_type.")
		return null

	var matched_factory: EntityFactory
	var match_count := 0
	for factory in _factories:
		if factory.supports(entity_type):
			matched_factory = factory
			match_count += 1

	if match_count == 0:
		push_error("Entity type '%s' has no registered EntityFactory." % entity_type)
		return null
	if match_count > 1:
		push_error(
			"Entity type '%s' matches %d EntityFactories; exactly one is required."
			% [entity_type, match_count]
		)
		return null
	return matched_factory
