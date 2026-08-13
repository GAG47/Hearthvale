class_name EntityBakerRegistry
extends RefCounted

var _bakers: Array[EntityBaker] = []


static func create_default() -> EntityBakerRegistry:
	var registry := EntityBakerRegistry.new()
	registry.register_baker(ActorBaker.new())
	registry.register_baker(FurnitureBaker.new())
	return registry


func register_baker(baker: EntityBaker) -> bool:
	if baker == null:
		push_error("EntityBakerRegistry cannot register a null Baker.")
		return false
	if _bakers.has(baker):
		push_error("EntityBakerRegistry cannot register the same Baker twice.")
		return false
	_bakers.append(baker)
	return true


func get_baker(placement: EntityPlacement) -> EntityBaker:
	if placement == null:
		push_error("EntityBakerRegistry requires an EntityPlacement.")
		return null

	var matched_baker: EntityBaker
	var match_count := 0
	for baker in _bakers:
		if baker.supports(placement):
			matched_baker = baker
			match_count += 1

	if match_count == 0:
		push_error("EntityPlacement '%s' has no registered Baker." % placement.name)
		return null
	if match_count > 1:
		push_error(
			"EntityPlacement '%s' matches %d Bakers; exactly one is required."
			% [placement.name, match_count]
		)
		return null
	return matched_baker
