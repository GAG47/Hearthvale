extends SceneTree

const REGISTRY_SCRIPT := preload("res://scripts/entities/entity_registry.gd")
const TEST_ACTION_ENTITY := preload("res://tests/entities/helpers/test_action_entity.gd")

const ACTOR_ID := &"11111111-1111-4111-8111-111111111111"
const FURNITURE_ID := &"00000000-0000-4000-8000-000000000001"
const GENERIC_ENTITY_ID := &"22222222-2222-4222-8222-222222222222"
const OTHER_ENTITY_ID := &"33333333-3333-4333-8333-333333333333"
const LOCATION_ID := &"50000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0


func _init() -> void:
	_disable_project_autoloads()
	call_deferred("_run_tests")


func _run_tests() -> void:
	var registry := REGISTRY_SCRIPT.new()
	registry.name = "EntityRegistry"
	root.add_child(registry)
	var world_definition := WorldDefinitionRuntime.new()
	world_definition.name = "WorldDefinition"
	root.add_child(world_definition)
	var world_state := WorldStateRuntime.new()
	world_state.name = "WorldState"
	root.add_child(world_state)
	_expect(registry.get_entities().is_empty(), "A new EntityRegistry must not create Entities.")
	_expect(not registry.register_entity(null), "A null Entity must be rejected.")

	var actor_definition := _create_actor_definition("Test Actor")
	var actor := Actor.new(
		actor_definition,
		ActorState.new(ACTOR_ID, LOCATION_ID, Vector2(32.0, 32.0), ActorState.Facing.RIGHT)
	)
	_expect(actor is Entity, "Actor must extend Entity.")
	_expect(actor.definition == actor_definition, "Actor must directly hold its Definition Resource.")
	_expect(registry.register_entity(actor), "A valid Actor must register.")
	_expect(registry.has_entity(ACTOR_ID), "has_entity must find the Actor.")
	_expect(registry.get_entity(ACTOR_ID) == actor, "get_entity must return the same Actor.")
	_expect(not registry.register_entity(actor), "A duplicate instance_id must be rejected.")

	var invalid_entity := TEST_ACTION_ENTITY.new(
		ActorState.new(&"not-a-uuid", LOCATION_ID, Vector2.ZERO)
	)
	_expect(not registry.register_entity(invalid_entity), "An invalid Entity UUID must be rejected.")
	_expect(not registry.register_entity(TEST_ACTION_ENTITY.new(null)), "An Entity without EntityState must be rejected.")
	var missing_definition := Actor.new(
		null,
		ActorState.new(OTHER_ENTITY_ID, LOCATION_ID, Vector2.ZERO)
	)
	_expect(not registry.register_entity(missing_definition), "An Entity without a Definition Resource must be rejected.")

	var furniture_definition := _create_furniture_definition("Test Furniture")
	var furniture := Furniture.new(
		furniture_definition,
		FurnitureState.new(FURNITURE_ID, LOCATION_ID, Vector2(96.0, 96.0))
	)
	_expect(furniture is Entity, "Furniture must extend Entity.")
	_expect(furniture.definition == furniture_definition, "Furniture must directly hold its Definition Resource.")
	_expect(registry.register_entity(furniture), "A valid Furniture must register.")
	_expect(registry.get_entity(FURNITURE_ID) == furniture, "Registry must return Furniture.")

	var generic_entity := TEST_ACTION_ENTITY.new(
		ActorState.new(GENERIC_ENTITY_ID, LOCATION_ID, Vector2(64.0, 32.0), ActorState.Facing.RIGHT)
	)
	_expect(registry.register_entity(generic_entity), "EntityRegistry must accept another valid Entity subtype.")
	var generic_result := WorldAction.new(&"test_action", actor, generic_entity).execute()
	_expect(generic_result.success and generic_result.target_id == GENERIC_ENTITY_ID, "WorldAction must execute the generic Entity Action protocol.")
	var unsupported_result := WorldAction.new(&"talk", actor, actor).execute()
	_expect(not unsupported_result.success and unsupported_result.failure_code == &"target_action_unsupported", "Entity's default Action protocol must reject unsupported actions.")

	var named_definition := _create_furniture_definition("测试柜")
	var openable := OpenableBehavior.new()
	openable.open_visual = load("res://assets/furniture/chest_open.svg") as Texture2D
	named_definition.behaviors = [openable]
	var named_furniture := Furniture.new(
		named_definition,
		FurnitureState.new(OTHER_ENTITY_ID, LOCATION_ID, Vector2(80.0, 48.0))
	)
	var open_result := WorldAction.new(&"open", actor, named_furniture).execute()
	_expect(open_result.success and open_result.message == "测试柜打开了。", "OpenableBehavior feedback must derive from FurnitureDefinition.display_name.")
	_expect(named_furniture.get_openable_state() != null and named_furniture.get_openable_state().is_open, "OpenableBehavior must write the instance's OpenableState.")

	var entities := registry.get_entities()
	_expect(entities.size() == 3, "get_entities must include every registered Entity subtype.")
	_expect(entities.has(furniture) and entities.has(actor) and entities.has(generic_entity) and entities == registry.get_entities(), "get_entities must return stable instance_id order.")
	_expect(registry.get_entities_in_location(LOCATION_ID).size() == 3, "Location queries must include every registered Entity subtype.")
	_expect(registry.get_entities_in_location(&"unknown").is_empty(), "An unknown Location query must return no Entities.")
	registry.free()
	world_state.free()
	world_definition.free()
	_finish()


func _create_actor_definition(display_name: String) -> ActorDefinition:
	var definition := ActorDefinition.new()
	definition.display_name = display_name
	return definition


func _create_furniture_definition(display_name: String) -> FurnitureDefinition:
	var definition := FurnitureDefinition.new()
	definition.display_name = display_name
	definition.visual = load("res://assets/furniture/sign.svg") as Texture2D
	definition.footprint_cells = [Vector2i.ZERO]
	definition.blocks_movement = true
	return definition


func _disable_project_autoloads() -> void:
	for autoload_name in ["WorldDefinition", "WorldState", "EntityRegistry", "WorldTime"]:
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
