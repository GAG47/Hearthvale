extends SceneTree

const GAME_SCRIPT := preload("res://scripts/game.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const INITIAL_DATA_PATH := "res://data/world/initial_entities.json"
const PLAYER_DEFINITION_PATH := "res://data/actors/player.json"
const MARTHA_DEFINITION_PATH := "res://data/actors/martha.json"
const CHEST_DEFINITION_PATH := "res://data/furniture/wooden_chest.json"
const CLI_SUCCESS_PATH := "user://v9_1_bake_cli_success.json"
const PLAYER_DEFINITION_ID := &"5e05b833-0645-4c13-8713-4c8767a7efe3"
const MARTHA_DEFINITION_ID := &"90da2d88-d049-4519-9e5c-e35136ff6a7d"
const CHEST_DEFINITION_ID := &"7f45a0d2-2ff2-4f1c-8b7a-3d7d0dd5b8a1"
const BASELINE_ENTITY_ID := &"33333333-3333-4333-8333-333333333333"

var _checks := 0
var _failures := 0


class PreparedTestEntity:
	extends Entity


class CountingFactory:
	extends EntityFactory

	var create_count := 0
	var fail_at := 0
	var saw_registry_mutation_during_prepare := false
	var observed_world_state: WorldStateRuntime
	var observed_entity_registry: EntityRegistryRuntime
	var expected_state_count := 0
	var expected_entity_count := 0


	func supports(entity_type: StringName) -> bool:
		return entity_type == &"atomic_test"


	func create(entity_data: Dictionary) -> Entity:
		if (
			observed_world_state.get_entity_states().size() != expected_state_count
			or observed_entity_registry.get_entities().size() != expected_entity_count
		):
			saw_registry_mutation_during_prepare = true
		create_count += 1
		if fail_at > 0 and create_count == fail_at:
			return null
		var entity_id := UuidGenerator.generate_v4()
		var state := ActorState.new(
			entity_id,
			StringName(entity_data["location_id"] as String),
			Vector2(float(create_count * 16), 32.0),
			ActorState.Facing.DOWN
		)
		return PreparedTestEntity.new(state)


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	_expect(world_definition != null, "WorldDefinition Autoload must exist.")
	if world_definition == null:
		_finish()
		return

	_test_definition_identity()
	_test_atomic_initialization_success(world_definition)
	_test_atomic_initialization_failure(world_definition)
	_test_baking_cli_exit_codes()
	await _test_player_identity_and_runtime()
	_finish()


func _test_definition_identity() -> void:
	var player_definition := ActorDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	var martha_definition := ActorDefinitionLoader.load_from_file(MARTHA_DEFINITION_PATH)
	var chest_definition := FurnitureDefinitionLoader.load_from_file(CHEST_DEFINITION_PATH)
	_expect(player_definition != null, "Player ActorDefinition must load.")
	_expect(martha_definition != null, "Martha ActorDefinition must load.")
	_expect(chest_definition != null, "Chest FurnitureDefinition must load.")
	if player_definition != null:
		_expect(player_definition.definition_id == PLAYER_DEFINITION_ID, "Player must preserve definition_id.")
		_expect(UuidValidator.is_valid_v4(player_definition.definition_id), "Player definition_id must be UUID v4.")
	if martha_definition != null:
		_expect(martha_definition.definition_id == MARTHA_DEFINITION_ID, "Martha must preserve definition_id.")
	if chest_definition != null:
		_expect(chest_definition.definition_id == CHEST_DEFINITION_ID, "Furniture must preserve definition_id.")
		_expect(UuidValidator.is_valid_v4(chest_definition.definition_id), "Furniture definition_id must be UUID v4.")

	var actor_data := {
		"entity_type": "actor",
		"definition_path": MARTHA_DEFINITION_PATH,
		"location_id": "town_street",
		"local_position": [400.0, 200.0],
		"initial_facing": "left",
	}
	var actor := ActorEntityFactory.new().create(actor_data) as Actor
	_expect(actor != null, "ActorEntityFactory must create Actor.")
	if actor != null:
		_expect(actor.definition.definition_id == MARTHA_DEFINITION_ID, "Actor must use loaded Definition identity.")
		_expect(actor.definition.definition_id != actor.entity_id, "Actor definition_id and entity_id must differ.")
		_expect(actor.state.entity_id == actor.entity_id, "ActorState must use runtime entity_id.")
	var factory_source := FileAccess.get_file_as_string("res://scripts/actors/actor_entity_factory.gd")
	_expect(not factory_source.contains("ActorDefinition.new"), "ActorEntityFactory must not clone ActorDefinition.")


func _test_atomic_initialization_success(world_definition: WorldDefinitionRuntime) -> void:
	var game := GAME_SCRIPT.new()
	var world_state := WorldStateRuntime.new()
	var entity_registry := EntityRegistryRuntime.new()
	game.world_definition = world_definition
	game.world_state = world_state
	game.entity_registry = entity_registry
	game.entity_factory_registry = EntityFactoryRegistry.create_default()
	var loaded_data: Variant = InitialEntityDataLoader.load_from_file(INITIAL_DATA_PATH)
	_expect(loaded_data is Array, "Initial Entity Data must load for atomic initialization.")
	if loaded_data is Array:
		_expect(
			game._initialize_world_entities_from_data(loaded_data),
			"Complete Prepare must Commit all initial Entities."
		)
		_expect(world_state.get_entity_states().size() == loaded_data.size(), "Commit must register every EntityState.")
		_expect(entity_registry.get_entities().size() == loaded_data.size(), "Commit must register every Entity.")
		for entity in entity_registry.get_entities():
			_expect(world_state.get_entity_state(entity.entity_id) == entity.state, "Committed Entity and State must stay paired.")
			if entity is Furniture:
				var furniture := entity as Furniture
				_expect(furniture.definition.definition_id != furniture.entity_id, "Furniture IDs must represent distinct identities.")
	game.free()
	world_state.free()
	entity_registry.free()


func _test_atomic_initialization_failure(world_definition: WorldDefinitionRuntime) -> void:
	var game := GAME_SCRIPT.new()
	var world_state := WorldStateRuntime.new()
	var entity_registry := EntityRegistryRuntime.new()
	var baseline_state := ActorState.new(
		BASELINE_ENTITY_ID,
		&"tavern",
		Vector2(32.0, 32.0),
		ActorState.Facing.DOWN
	)
	var baseline_entity := PreparedTestEntity.new(baseline_state)
	_expect(world_state.register_entity_state(baseline_state), "Failure test baseline State must register.")
	_expect(entity_registry.register_entity(baseline_entity), "Failure test baseline Entity must register.")
	var before_states := world_state.get_entity_states()
	var before_entities := entity_registry.get_entities()

	var factory := CountingFactory.new()
	factory.fail_at = 2
	factory.observed_world_state = world_state
	factory.observed_entity_registry = entity_registry
	factory.expected_state_count = before_states.size()
	factory.expected_entity_count = before_entities.size()
	var factory_registry := EntityFactoryRegistry.new()
	factory_registry.register_factory(factory)
	game.world_definition = world_definition
	game.world_state = world_state
	game.entity_registry = entity_registry
	game.entity_factory_registry = factory_registry
	var creation_data := _make_atomic_creation_data(3)
	_expect(
		not game._initialize_world_entities_from_data(creation_data),
		"A middle Entity creation failure must fail the whole initialization."
	)
	_expect(factory.create_count == 2, "Prepare must stop at the failing Entity.")
	_expect(
		not factory.saw_registry_mutation_during_prepare,
		"Prepare must not mutate either Registry before all Entities are ready."
	)
	_expect(world_state.get_entity_states() == before_states, "Failed initialization must preserve WorldState exactly.")
	_expect(entity_registry.get_entities() == before_entities, "Failed initialization must preserve EntityRegistry exactly.")
	_expect(
		world_state.get_entity_state(BASELINE_ENTITY_ID) == baseline_state
		and entity_registry.get_entity(BASELINE_ENTITY_ID) == baseline_entity,
		"Failed initialization must preserve pre-existing Entity/State pairs."
	)
	game.free()
	world_state.free()
	entity_registry.free()


func _make_atomic_creation_data(count: int) -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for index in range(count):
		data.append({
			"entity_type": "atomic_test",
			"definition_path": "res://unused.json",
			"location_id": "tavern",
			"local_position": [float(index * 16), 32.0],
		})
	return data


func _test_baking_cli_exit_codes() -> void:
	var success_output: Array = []
	var success_code := OS.execute(
		OS.get_executable_path(),
		_make_bake_cli_arguments("--output=%s" % CLI_SUCCESS_PATH),
		success_output,
		true
	)
	_expect(success_code == 0, "Bake Initial World CLI must return exit code 0 on success.")
	_expect(FileAccess.file_exists(CLI_SUCCESS_PATH), "Successful Baking CLI must write its requested output.")

	var failure_output: Array = []
	var failure_code := OS.execute(
		OS.get_executable_path(),
		_make_bake_cli_arguments("--output="),
		failure_output,
		true
	)
	_expect(failure_code == 1, "Bake Initial World CLI must return exit code 1 on failure.")


func _make_bake_cli_arguments(output_argument: String) -> PackedStringArray:
	return PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://tools/bake_initial_world.gd",
		"--",
		output_argument,
	])


func _test_player_identity_and_runtime() -> void:
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	var entity_registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_expect(world_state != null and entity_registry != null, "Player test requires runtime registries.")
	if world_state == null or entity_registry == null:
		return
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controlled_actor_id: StringName = game.get("controlled_actor_id")
	var player := entity_registry.get_entity(controlled_actor_id) as Actor
	var definition := ActorDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	_expect(player != null and definition != null, "Current startup must create the Player Actor.")
	if player != null and definition != null:
		_expect(UuidValidator.is_valid_v4(player.entity_id), "Player entity_id must be UUID v4.")
		_expect(player.entity_id != definition.definition_id, "Player entity_id must differ from Definition identity.")
		_expect(player.definition.definition_id == definition.definition_id, "Player must use the loaded ActorDefinition.")
		_expect(world_state.get_entity_state(player.entity_id) == player.state, "Player State must register by entity_id.")
		var controller := game.get_node_or_null("PlayerController") as PlayerController
		_expect(controller != null and controller.controlled_actor == player, "PlayerController must still control Player.")
		_expect(
			controller != null and is_instance_valid(controller.controlled_representation),
			"Player Representation must still be created."
		)
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V9.1 Entity Lifecycle Cleanup: %d checks passed." % _checks)
		quit(0)
		return
	push_error(
		"V9.1 Entity Lifecycle Cleanup: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
