extends SceneTree

const REGISTRY_SCRIPT := preload("res://scripts/entities/entity_registry.gd")

const ACTOR_ID := &"11111111-1111-4111-8111-111111111111"
const FURNITURE_ID := &"00000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0


func _init() -> void:
	_disable_project_autoloads()
	_run_tests()
	_finish()


func _run_tests() -> void:
	var registry := REGISTRY_SCRIPT.new()
	_expect(registry.get_entities().is_empty(), "A new EntityRegistry must not create Entities.")
	_expect(not registry.register_entity(null), "A null Entity must be rejected.")

	var actor := _create_actor(ACTOR_ID, &"tavern")
	_expect(actor is Entity, "Actor must extend Entity.")
	_expect(registry.register_entity(actor), "A valid Actor must register.")
	_expect(registry.has_entity(ACTOR_ID), "has_entity must find the Actor.")
	_expect(registry.get_entity(ACTOR_ID) == actor, "get_entity must return the same Actor.")
	_expect(not registry.register_entity(actor), "A duplicate entity_id must be rejected.")

	var mismatched_actor := Actor.new(
		ActorDefinition.new(ACTOR_ID, "Mismatch", _create_test_visuals()),
		ActorState.new(FURNITURE_ID, &"tavern", Vector2.ZERO)
	)
	_expect(
		not registry.register_entity(mismatched_actor),
		"ActorDefinition and ActorState entity IDs must match."
	)

	var invalid_actor := Actor.new(
		ActorDefinition.new(&"not-a-uuid", "Invalid", _create_test_visuals()),
		ActorState.new(&"not-a-uuid", &"tavern", Vector2.ZERO)
	)
	_expect(
		not registry.register_entity(invalid_actor),
		"An invalid Actor entity UUID must be rejected."
	)

	var furniture := _create_furniture(FURNITURE_ID, &"tavern")
	_expect(furniture is Entity, "Furniture must extend Entity.")
	_expect(registry.register_entity(furniture), "A valid Furniture must register.")
	_expect(registry.get_entity(FURNITURE_ID) == furniture, "Registry must return Furniture.")

	var entities := registry.get_entities()
	_expect(entities.size() == 2, "get_entities must include Actor and Furniture.")
	_expect(
		entities.size() == 2 and entities[0] == furniture and entities[1] == actor,
		"get_entities must return stable entity_id order."
	)
	var tavern_entities := registry.get_entities_in_location(&"tavern")
	_expect(tavern_entities.size() == 2, "Location queries must include both Entity subtypes.")
	_expect(
		registry.get_entities_in_location(&"unknown").is_empty(),
		"An unknown Location query must return no Entities."
	)
	registry.free()


func _create_actor(entity_id: StringName, location_id: StringName) -> Actor:
	return Actor.new(
		ActorDefinition.new(entity_id, "Test Actor", _create_test_visuals()),
		ActorState.new(entity_id, location_id, Vector2(32.0, 64.0))
	)


func _create_furniture(entity_id: StringName, location_id: StringName) -> Furniture:
	var definition := FurnitureDefinition.new(
		&"test_furniture",
		"Test Furniture",
		"res://assets/furniture/sign.svg",
		{},
		Vector2i.ONE,
		true
	)
	return Furniture.new(
		definition,
		FurnitureState.new(entity_id, location_id, Vector2(96.0, 96.0))
	)


func _create_test_visuals() -> Dictionary[String, String]:
	return {
		"up": "res://assets/actors/player_up.svg",
		"down": "res://assets/actors/player_down.svg",
		"left": "res://assets/actors/player_left.svg",
		"right": "res://assets/actors/player_right.svg",
	}


func _disable_project_autoloads() -> void:
	for autoload_name in [
		"WorldDefinition",
		"WorldState",
		"EntityRegistry",
		"WorldTime",
	]:
		ProjectSettings.set_setting("autoload/%s" % autoload_name, null)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("EntityRegistry: %d checks passed." % _checks)
		quit(0)
		return
	push_error("EntityRegistry: %d of %d checks failed." % [_failures, _checks])
	quit(1)
