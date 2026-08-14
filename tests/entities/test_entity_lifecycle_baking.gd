extends SceneTree

const BAKE_TOOL := preload("res://tools/bake_initial_world.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const INITIAL_DATA_PATH := "res://data/world/initial_entities.json"
const MARTHA_DEFINITION_PATH := "res://data/actors/martha.json"
const CHEST_DEFINITION_PATH := "res://data/furniture/wooden_chest.json"
const MARTHA_DEFINITION_ID := &"90da2d88-d049-4519-9e5c-e35136ff6a7d"
const CHEST_DEFINITION_ID := &"7f45a0d2-2ff2-4f1c-8b7a-3d7d0dd5b8a1"
const SIGN_DEFINITION_ID := &"9c4b72f1-bd0e-4f67-a5d2-6e5b1f9c3a20"
const BED_DEFINITION_ID := &"c2a6e4b8-1d73-4c5f-9a0e-7b3d8f21e654"
const BAKED_TEST_PATH := "user://v9_initial_entities_test.json"
const INVALID_TEST_PATH := "user://v9_invalid_output_guard.json"

var _checks := 0
var _failures := 0


class MatchingBaker:
	extends EntityBaker


	func supports(_placement: EntityPlacement) -> bool:
		return true


	func bake(_placement: EntityPlacement, _location_id: StringName) -> Dictionary:
		return {}


class MatchingEntityFactory:
	extends EntityFactory


	func supports(_entity_type: StringName) -> bool:
		return true


	func create(_entity_data: Dictionary) -> Entity:
		return null


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	var entity_registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_expect(world_definition != null, "WorldDefinition Autoload must exist.")
	_expect(world_state != null, "WorldState Autoload must exist.")
	_expect(entity_registry != null, "EntityRegistry Autoload must exist.")
	if world_definition == null or world_state == null or entity_registry == null:
		_finish()
		return

	_test_placement_and_baker_registry()
	var baked_entities := _test_real_world_baking(world_definition)
	_test_invalid_baking_preserves_output()
	_test_entity_factories(baked_entities)
	_test_source_boundaries()
	await _test_runtime_creation_and_representation(world_definition, world_state, entity_registry)
	_finish()


func _test_placement_and_baker_registry() -> void:
	var actor_placement := ActorPlacement.new()
	actor_placement.name = "MarthaPlacement"
	actor_placement.definition_path = MARTHA_DEFINITION_PATH
	actor_placement.position = Vector2(400.0, 200.0)
	actor_placement.initial_facing = ActorState.Facing.LEFT
	var furniture_placement := FurniturePlacement.new()
	furniture_placement.name = "ChestPlacement"
	furniture_placement.definition_path = CHEST_DEFINITION_PATH
	furniture_placement.position = Vector2(320.0, 180.0)

	var actor_baker := ActorBaker.new()
	var furniture_baker := FurnitureBaker.new()
	_expect(actor_baker.supports(actor_placement), "ActorBaker must support ActorPlacement.")
	_expect(not actor_baker.supports(furniture_placement), "ActorBaker must reject FurniturePlacement.")
	_expect(furniture_baker.supports(furniture_placement), "FurnitureBaker must support FurniturePlacement.")
	_expect(not furniture_baker.supports(actor_placement), "FurnitureBaker must reject ActorPlacement.")

	var default_registry := EntityBakerRegistry.create_default()
	_expect(default_registry.get_baker(actor_placement) is ActorBaker, "ActorPlacement must have one ActorBaker.")
	_expect(
		default_registry.get_baker(furniture_placement) is FurnitureBaker,
		"FurniturePlacement must have one FurnitureBaker."
	)
	var unsupported_placement := EntityPlacement.new()
	unsupported_placement.name = "UnsupportedPlacement"
	_expect(default_registry.get_baker(unsupported_placement) == null, "Zero Baker matches must fail.")
	var ambiguous_registry := EntityBakerRegistry.new()
	ambiguous_registry.register_baker(MatchingBaker.new())
	ambiguous_registry.register_baker(MatchingBaker.new())
	_expect(
		ambiguous_registry.get_baker(actor_placement) == null,
		"Multiple Baker matches must fail without registration-order priority."
	)

	var actor_data := actor_baker.bake(actor_placement, &"town_street")
	_expect(actor_data["entity_type"] == "actor", "Actor Baking must emit explicit entity_type.")
	_expect(actor_data["definition_path"] == MARTHA_DEFINITION_PATH, "Actor Baking must preserve definition_path.")
	_expect(actor_data["location_id"] == "town_street", "Actor Baking must use owning Location ID.")
	_expect(actor_data["local_position"] == [400.0, 200.0], "Actor Baking must serialize Node2D.position.")
	_expect(actor_data["initial_facing"] == "left", "Actor Baking must serialize initial_facing.")

	var furniture_data := furniture_baker.bake(furniture_placement, &"tavern")
	_expect(furniture_data["entity_type"] == "furniture", "Furniture Baking must emit explicit entity_type.")
	_expect(furniture_data["definition_path"] == CHEST_DEFINITION_PATH, "Furniture Baking must preserve definition_path.")
	_expect(furniture_data["location_id"] == "tavern", "Furniture Baking must use owning Location ID.")
	_expect(furniture_data["local_position"] == [320.0, 180.0], "Furniture Baking must serialize Node2D.position.")
	_expect(not furniture_data.has("entity_id"), "Baking Data must not contain a runtime UUID.")

	actor_placement.free()
	furniture_placement.free()
	unsupported_placement.free()


func _test_real_world_baking(world_definition: WorldDefinitionRuntime) -> Array[Dictionary]:
	var locations := world_definition.get_locations()
	_expect(locations.size() == 3, "Baking must enumerate the formal LocationDefinition source.")
	_expect(
		BAKE_TOOL.bake_definitions(locations, EntityBakerRegistry.create_default(), BAKED_TEST_PATH),
		"Bake Initial World must bake real Location Scenes."
	)
	var loaded_data: Variant = InitialEntityDataLoader.load_from_file(BAKED_TEST_PATH)
	_expect(loaded_data is Array, "Baked test output must load as Initial Entity Data.")
	if not loaded_data is Array:
		return []
	var entities: Array[Dictionary] = []
	for entity_value: Variant in loaded_data:
		entities.append(entity_value as Dictionary)
	_expect(entities.size() == 3, "Real Tavern Scene must bake three FurniturePlacements.")
	var expected_paths := [
		"res://data/furniture/wooden_chest.json",
		"res://data/furniture/sign.json",
		"res://data/furniture/simple_bed.json",
	]
	var expected_positions := [
		[464.0, 208.0],
		[432.0, 240.0],
		[656.0, 128.0],
	]
	for index in range(entities.size()):
		var entity_data := entities[index]
		_expect(entity_data["entity_type"] == "furniture", "Real Placement must bake as Furniture.")
		_expect(entity_data["definition_path"] == expected_paths[index], "Scene order must remain stable.")
		_expect(entity_data["location_id"] == "tavern", "Placement Location must come from GridScene.")
		_expect(entity_data["local_position"] == expected_positions[index], "Placement position must bake exactly.")
		_expect(not entity_data.has("entity_id"), "Real Baking output must not contain UUIDs.")

	var committed_data: Variant = InitialEntityDataLoader.load_from_file(INITIAL_DATA_PATH)
	_expect(committed_data is Array and committed_data == entities, "Committed initial_entities.json must match Baking output.")
	return entities


func _test_invalid_baking_preserves_output() -> void:
	var sentinel := "existing valid output\n"
	var file := FileAccess.open(INVALID_TEST_PATH, FileAccess.WRITE)
	file.store_string(sentinel)
	file.close()
	var invalid_definitions: Array[LocationDefinition] = [
		LocationDefinition.new(
			&"v9_invalid_placement",
			"Invalid Placement",
			"res://tests/entities/fixtures/locations/v9_invalid_placement.tscn"
		),
	]
	_expect(
		not BAKE_TOOL.bake_definitions(
			invalid_definitions,
			EntityBakerRegistry.create_default(),
			INVALID_TEST_PATH
		),
		"Invalid Placement must fail the whole Baking operation."
	)
	_expect(
		FileAccess.get_file_as_string(INVALID_TEST_PATH) == sentinel,
		"Invalid Placement must not overwrite an existing valid output."
	)


func _test_entity_factories(baked_entities: Array[Dictionary]) -> void:
	var registry := EntityFactoryRegistry.create_default()
	_expect(registry.get_factory(&"actor") is ActorEntityFactory, "Actor type must resolve ActorEntityFactory.")
	_expect(
		registry.get_factory(&"furniture") is FurnitureEntityFactory,
		"Furniture type must resolve FurnitureEntityFactory."
	)
	_expect(registry.get_factory(&"unknown") == null, "Unknown entity_type must fail Factory lookup.")
	var ambiguous_registry := EntityFactoryRegistry.new()
	ambiguous_registry.register_factory(MatchingEntityFactory.new())
	ambiguous_registry.register_factory(MatchingEntityFactory.new())
	_expect(
		ambiguous_registry.get_factory(&"actor") == null,
		"Multiple EntityFactory matches must fail without registration-order priority."
	)

	var actor_data := {
		"entity_type": "actor",
		"definition_path": MARTHA_DEFINITION_PATH,
		"location_id": "town_street",
		"local_position": [400.0, 200.0],
		"initial_facing": "left",
	}
	var actor := registry.get_factory(&"actor").create(actor_data) as Actor
	_expect(actor != null, "ActorEntityFactory must create Actor.")
	if actor != null:
		_expect(UuidValidator.is_valid_v4(actor.entity_id), "ActorEntityFactory must generate UUID v4.")
		_expect(actor.definition.definition_id == MARTHA_DEFINITION_ID, "Actor Factory must preserve Definition identity.")
		_expect(actor.definition.definition_id != actor.entity_id, "Actor Definition and Entity IDs must be independent.")
		_expect(actor.definition.display_name == "Martha", "ActorEntityFactory must load ActorDefinition.")
		_expect(actor.state is ActorState, "ActorEntityFactory must create ActorState.")
		_expect(actor.current_location_id == &"town_street", "ActorState must use creation location_id.")
		_expect(actor.local_position == Vector2(400.0, 200.0), "ActorState must use creation position.")
		_expect(actor.facing == ActorState.Facing.LEFT, "ActorState must use creation facing.")

	_expect(not baked_entities.is_empty(), "Furniture Factory test requires baked data.")
	if baked_entities.is_empty():
		return
	var furniture := registry.get_factory(&"furniture").create(baked_entities[0]) as Furniture
	_expect(furniture != null, "FurnitureEntityFactory must create Furniture.")
	if furniture != null:
		_expect(UuidValidator.is_valid_v4(furniture.entity_id), "FurnitureEntityFactory must generate UUID v4.")
		_expect(furniture.definition.definition_id == CHEST_DEFINITION_ID, "Furniture Factory must load Definition.")
		_expect(furniture.definition.definition_id != furniture.entity_id, "Furniture Definition and Entity IDs must be independent.")
		_expect(furniture.state is FurnitureState, "Furniture Factory must create FurnitureState.")
		_expect(furniture.current_location_id == &"tavern", "FurnitureState must use creation location_id.")
		_expect(furniture.local_position == Vector2(464.0, 208.0), "FurnitureState must use creation position.")
		_expect(
			furniture.get_openable_state() is OpenableState,
			"Furniture's existing Behavior initialization must create OpenableState."
		)


func _test_source_boundaries() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_expect(not game_source.contains("FURNITURE_INSTANCES"), "Game must not contain fixed Furniture instances.")
	_expect(not game_source.contains("wooden_chest.json"), "Game must not contain Furniture Definition paths.")
	_expect(not game_source.contains("5543caf7"), "Game must not contain the old fixed Furniture UUID.")
	var initial_source := FileAccess.get_file_as_string(INITIAL_DATA_PATH)
	_expect(not initial_source.contains("entity_id"), "Initial Entity Data must not store runtime UUIDs.")
	var baker_source := FileAccess.get_file_as_string("res://scripts/baking/entity_baker.gd")
	_expect(not baker_source.contains("EntityState"), "EntityBaker must not create EntityState.")
	_expect(not baker_source.contains("Representation"), "EntityBaker must not create Representation.")
	var factory_source := FileAccess.get_file_as_string("res://scripts/entities/entity_factory.gd")
	_expect(not factory_source.contains("Representation"), "EntityFactory must not create Representation.")


func _test_runtime_creation_and_representation(
	world_definition: WorldDefinitionRuntime,
	world_state: WorldStateRuntime,
	entity_registry: EntityRegistryRuntime
) -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var chest := _find_furniture(entity_registry, CHEST_DEFINITION_ID)
	var sign := _find_furniture(entity_registry, SIGN_DEFINITION_ID)
	var bed := _find_furniture(entity_registry, BED_DEFINITION_ID)
	_expect(chest != null and sign != null and bed != null, "Game must create all baked Furniture Entities.")
	if chest == null or sign == null or bed == null:
		game.queue_free()
		await process_frame
		return
	for furniture in [chest, sign, bed]:
		_expect(UuidValidator.is_valid_v4(furniture.entity_id), "Runtime Furniture must receive UUID v4.")
		_expect(
			world_state.get_entity_state(furniture.entity_id) == furniture.state,
			"Created FurnitureState must register through WorldState."
		)
		_expect(
			entity_registry.get_entity(furniture.entity_id) == furniture,
			"Created Furniture must register through EntityRegistry."
		)

	var tavern := game.get("current_location") as GridScene
	_expect(tavern != null, "Game must activate Tavern.")
	_expect(_count_placements(tavern) == 0, "Runtime Location must remove Placements.")
	var representations := _get_furniture_representations(tavern)
	_expect(representations.size() == 3, "V8 must create three FurnitureRepresentations.")
	for representation in representations:
		_expect(representation.get_entity() is Furniture, "Representation must bind an existing Entity.")

	var chest_representation := _find_furniture_representation(tavern, chest.entity_id)
	_expect(chest_representation != null, "Chest Representation must exist.")
	if chest_representation != null:
		chest_representation.position = Vector2(528.0, 208.0)
		chest_representation.sync_state_from_representation()
	var yard_edge := world_definition.get_edge(&"tavern", &"back_door")
	var left_tavern: Variant = game.call("_replace_location", &"tavern_yard", &"tavern", yard_edge)
	_expect(left_tavern == true, "Location change must continue through V7.5 Prepare and Commit.")
	var tavern_edge := world_definition.get_edge(&"tavern_yard", &"tavern_door")
	var returned: Variant = game.call("_replace_location", &"tavern", &"tavern_yard", tavern_edge)
	_expect(returned == true, "Location return must continue through V7.5 Prepare and Commit.")
	var returned_tavern := game.get("current_location") as GridScene
	var returned_chest := _find_furniture_representation(returned_tavern, chest.entity_id)
	_expect(
		returned_chest != null and returned_chest.position == Vector2(528.0, 208.0),
		"Location reload must restore FurnitureState, not reread Placement position."
	)
	_expect(_count_placements(returned_tavern) == 0, "Reloaded Location must remove Placements.")

	game.queue_free()
	await process_frame


func _find_furniture(
	registry: EntityRegistryRuntime,
	definition_id: StringName
) -> Furniture:
	for entity in registry.get_entities():
		if entity is Furniture and (entity as Furniture).definition.definition_id == definition_id:
			return entity as Furniture
	return null


func _get_furniture_representations(location: GridScene) -> Array[FurnitureRepresentation]:
	var representations: Array[FurnitureRepresentation] = []
	if location == null:
		return representations
	for child in location.get_children():
		if child is FurnitureRepresentation:
			representations.append(child as FurnitureRepresentation)
	return representations


func _find_furniture_representation(
	location: GridScene,
	entity_id: StringName
) -> FurnitureRepresentation:
	for representation in _get_furniture_representations(location):
		if representation.entity_id == entity_id:
			return representation
	return null


func _count_placements(node: Node) -> int:
	var count := 1 if node is EntityPlacement else 0
	for child in node.get_children():
		count += _count_placements(child)
	return count


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V9 Entity Lifecycle and Baking: %d checks passed." % _checks)
		quit(0)
		return
	push_error(
		"V9 Entity Lifecycle and Baking: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
