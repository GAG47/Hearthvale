class_name EntityRepresentationRegistry
extends RefCounted

var _factories: Array[EntityRepresentationFactory] = []


static func create_default() -> EntityRepresentationRegistry:
	var registry := EntityRepresentationRegistry.new()
	registry.register_factory(ActorRepresentationFactory.new())
	registry.register_factory(FurnitureRepresentationFactory.new())
	return registry


func register_factory(factory: EntityRepresentationFactory) -> bool:
	if factory == null:
		push_error("EntityRepresentationRegistry cannot register a null Factory.")
		return false
	if _factories.has(factory):
		push_error("EntityRepresentationRegistry cannot register the same Factory twice.")
		return false
	_factories.append(factory)
	return true


func get_factory(entity: Entity) -> EntityRepresentationFactory:
	if entity == null:
		push_error("EntityRepresentationRegistry requires an Entity.")
		return null

	var matched_factory: EntityRepresentationFactory
	var match_count := 0
	for factory in _factories:
		if factory.supports(entity):
			matched_factory = factory
			match_count += 1

	if match_count == 0:
		push_error(
			"Entity '%s' has no registered Representation Factory."
			% entity.instance_id
		)
		return null
	if match_count > 1:
		push_error(
			"Entity '%s' matches %d Representation Factories; exactly one is required."
			% [entity.instance_id, match_count]
		)
		return null
	return matched_factory
