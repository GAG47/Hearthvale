extends SceneTree

const REGISTRY_SCRIPT := preload("res://scripts/entities/entity_registry.gd")
const TEST_ACTION_ENTITY := preload("res://tests/entities/helpers/test_action_entity.gd")

const ACTOR_ID := &"11111111-1111-4111-8111-111111111111"
const FURNITURE_ID := &"00000000-0000-4000-8000-000000000001"
const GENERIC_ENTITY_ID := &"22222222-2222-4222-8222-222222222222"
const OTHER_ENTITY_ID := &"33333333-3333-4333-8333-333333333333"

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

	var mismatched_state := ActorState.new(
		GENERIC_ENTITY_ID, &"tavern", Vector2(64.0, 32.0), ActorState.Facing.RIGHT
	)
	var mismatched_entity := TEST_ACTION_ENTITY.new(mismatched_state)
	mismatched_state.entity_id = OTHER_ENTITY_ID
	_expect(
		not registry.register_entity(mismatched_entity),
		"Entity and EntityState IDs must match."
	)

	var invalid_entity := TEST_ACTION_ENTITY.new(
		ActorState.new(&"not-a-uuid", &"tavern", Vector2.ZERO)
	)
	_expect(
		not registry.register_entity(invalid_entity),
		"An invalid Entity UUID must be rejected."
	)
	_expect(
		not registry.register_entity(TEST_ACTION_ENTITY.new(null)),
		"An Entity without EntityState must be rejected."
	)

	var furniture := _create_furniture(FURNITURE_ID, &"tavern")
	_expect(furniture is Entity, "Furniture must extend Entity.")
	_expect(registry.register_entity(furniture), "A valid Furniture must register.")
	_expect(registry.get_entity(FURNITURE_ID) == furniture, "Registry must return Furniture.")

	var generic_entity := TEST_ACTION_ENTITY.new(
		ActorState.new(
			GENERIC_ENTITY_ID,
			&"tavern",
			Vector2(64.0, 32.0),
			ActorState.Facing.RIGHT
		)
	)
	_expect(
		registry.register_entity(generic_entity),
		"EntityRegistry must accept an otherwise unknown valid Entity subtype."
	)
	var action_result := WorldAction.new(&"test_action", actor, generic_entity).execute()
	_expect(
		action_result.success and action_result.target_id == GENERIC_ENTITY_ID,
		"WorldAction must execute the generic Entity Action protocol."
	)
	var unsupported_result := WorldAction.new(&"talk", actor, actor).execute()
	_expect(
		not unsupported_result.success
		and unsupported_result.failure_code == &"target_action_unsupported",
		"Entity's default Action protocol must reject unsupported actions."
	)
	var openable_definition := FurnitureDefinition.new()
	openable_definition.display_name = "测试柜"
	openable_definition.visual = load("res://assets/furniture/chest_closed.svg") as Texture2D
	openable_definition.behaviors = {
		"openable": {
			"open_visual": load("res://assets/furniture/chest_open.svg") as Texture2D,
		},
	}
	openable_definition.occupied_cells = Vector2i.ONE
	openable_definition.blocks_movement = true
	var named_furniture := Furniture.new(
		openable_definition,
		FurnitureState.new(OTHER_ENTITY_ID, &"tavern", Vector2(80.0, 48.0))
	)
	var open_result := WorldAction.new(&"open", actor, named_furniture).execute()
	_expect(
		open_result.success and open_result.message == "测试柜打开了。",
		"OpenableBehavior feedback must derive from FurnitureDefinition.display_name."
	)
	_expect(
		named_furniture.get_openable_state() != null
		and named_furniture.get_openable_state().is_open,
		"OpenableBehavior must write the instance's OpenableState."
	)

	var entities := registry.get_entities()
	_expect(entities.size() == 3, "get_entities must include every Entity subtype.")
	_expect(
		entities.size() == 3
		and entities.has(furniture)
		and entities.has(actor)
		and entities.has(generic_entity)
		and entities == registry.get_entities(),
		"get_entities must return stable entity_id order."
	)
	var tavern_entities := registry.get_entities_in_location(&"tavern")
	_expect(tavern_entities.size() == 3, "Location queries must include every Entity subtype.")
	_expect(
		registry.get_entities_in_location(&"unknown").is_empty(),
		"An unknown Location query must return no Entities."
	)
	registry.free()


func _create_actor(entity_id: StringName, location_id: StringName) -> Actor:
	return Actor.new(
		load("res://data/actors/player.tres") as ActorDefinition,
		ActorState.new(
			entity_id,
			location_id,
			Vector2(32.0, 32.0),
			ActorState.Facing.RIGHT
		)
	)


func _create_furniture(entity_id: StringName, location_id: StringName) -> Furniture:
	var definition := load("res://data/furniture/sign.tres") as FurnitureDefinition
	return Furniture.new(
		definition,
		FurnitureState.new(entity_id, location_id, Vector2(96.0, 96.0))
	)


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
