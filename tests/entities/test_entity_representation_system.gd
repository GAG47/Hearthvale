extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_DEFINITION_PATH := "res://data/actors/player.json"
const CHEST_DEFINITION_PATH := "res://data/furniture/wooden_chest.json"

var _checks := 0
var _failures := 0


class MatchingFactory:
	extends EntityRepresentationFactory

	var supported_instance_id: StringName


	func _init(p_supported_instance_id: StringName) -> void:
		supported_instance_id = p_supported_instance_id


	func supports(entity: Entity) -> bool:
		return entity != null and entity.instance_id == supported_instance_id


	func prepare(
		_entity: Entity,
		_target_location,
		target_local_position: Vector2
	) -> Node:
		var representation := Node2D.new()
		representation.position = target_local_position
		return representation


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var actor_definition := ActorDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	var furniture_definition := FurnitureDefinitionLoader.load_from_file(CHEST_DEFINITION_PATH)
	_expect(actor_definition != null, "Player ActorDefinition must load for Factory tests.")
	_expect(furniture_definition != null, "Chest FurnitureDefinition must load for Factory tests.")
	if actor_definition == null or furniture_definition == null:
		_finish()
		return

	var actor := Actor.new(
		actor_definition,
		ActorState.new(
			&"11111111-1111-4111-8111-111111111111",
			actor_definition.definition_id,
			&"55555555-5555-4555-8555-555555555555",
			Vector2(96.0, 128.0),
			ActorState.Facing.LEFT
		)
	)
	var furniture := Furniture.new(
		furniture_definition,
		FurnitureState.new(
			&"77777777-7777-4777-8777-777777777777",
			furniture_definition.definition_id,
			&"55555555-5555-4555-8555-555555555555",
			Vector2(160.0, 192.0)
		)
	)
	var target_location := GridScene.new()
	target_location.location_id = &"55555555-5555-4555-8555-555555555555"

	_test_concrete_factories(actor, furniture, target_location)
	_test_registry_matching(actor, furniture)
	_test_source_boundaries()
	target_location.free()

	await _test_missing_factory_prepare_safety()
	_finish()


func _test_concrete_factories(
	actor: Actor,
	furniture: Furniture,
	target_location: GridScene
) -> void:
	var actor_factory := ActorRepresentationFactory.new()
	var furniture_factory := FurnitureRepresentationFactory.new()
	_expect(actor_factory.supports(actor), "Actor Factory must support Actor.")
	_expect(not actor_factory.supports(furniture), "Actor Factory must reject Furniture.")
	_expect(furniture_factory.supports(furniture), "Furniture Factory must support Furniture.")
	_expect(not furniture_factory.supports(actor), "Furniture Factory must reject Actor.")

	var actor_target_position := Vector2(224.0, 256.0)
	var actor_node := actor_factory.prepare(actor, target_location, actor_target_position)
	_expect(actor_node is ActorRepresentation, "Actor Factory must prepare ActorRepresentation.")
	if actor_node is ActorRepresentation:
		var representation := actor_node as ActorRepresentation
		_expect(representation.get_entity() == actor, "Actor Representation must expose its Entity.")
		_expect(representation.current_location == target_location, "Actor preparation must bind target Location.")
		_expect(representation.position == actor_target_position, "Actor preparation must use target position.")
		_expect(
			representation.scene_file_path == "res://scenes/actors/actor_representation.tscn",
			"Actor Factory must own shared Scene instantiation."
		)
	if is_instance_valid(actor_node):
		actor_node.free()

	var furniture_target_position := Vector2(288.0, 320.0)
	var furniture_node := furniture_factory.prepare(
		furniture,
		target_location,
		furniture_target_position
	)
	_expect(
		furniture_node is FurnitureRepresentation,
		"Furniture Factory must prepare FurnitureRepresentation."
	)
	if furniture_node is FurnitureRepresentation:
		var representation := furniture_node as FurnitureRepresentation
		_expect(
			representation.get_entity() == furniture,
			"Furniture Representation must expose its Entity."
		)
		_expect(
			representation.current_location == target_location,
			"Furniture preparation must bind target Location."
		)
		_expect(
			representation.position == furniture_target_position,
			"Furniture preparation must use target position."
		)
		_expect(
			representation.scene_file_path
			== "res://scenes/furniture/furniture_representation.tscn",
			"Furniture Factory must own shared Scene instantiation."
		)
	if is_instance_valid(furniture_node):
		furniture_node.free()


func _test_registry_matching(actor: Actor, furniture: Furniture) -> void:
	var default_registry := EntityRepresentationRegistry.create_default()
	_expect(
		default_registry.get_factory(actor) is ActorRepresentationFactory,
		"Default Registry must resolve Actor to Actor Factory."
	)
	_expect(
		default_registry.get_factory(furniture) is FurnitureRepresentationFactory,
		"Default Registry must resolve Furniture to Furniture Factory."
	)

	var empty_registry := EntityRepresentationRegistry.new()
	_expect(empty_registry.get_factory(actor) == null, "Zero Factory matches must fail.")

	var exact_registry := EntityRepresentationRegistry.new()
	var exact_factory := MatchingFactory.new(actor.instance_id)
	_expect(exact_registry.register_factory(exact_factory), "A valid Factory must register.")
	_expect(
		exact_registry.get_factory(actor) == exact_factory,
		"Exactly one Factory match must be returned."
	)

	var ambiguous_registry := EntityRepresentationRegistry.new()
	ambiguous_registry.register_factory(MatchingFactory.new(actor.instance_id))
	ambiguous_registry.register_factory(MatchingFactory.new(actor.instance_id))
	_expect(
		ambiguous_registry.get_factory(actor) == null,
		"Multiple Factory matches must fail instead of using registration order."
	)


func _test_source_boundaries() -> void:
	var game_source := _read_text("res://scripts/game.gd")
	_expect(not game_source.is_empty(), "Game source must be readable for boundary checks.")
	_expect(
		not game_source.contains("entity is Actor")
		and not game_source.contains("entity is Furniture"),
		"Game must not branch on concrete Entity types for Representation creation."
	)
	_expect(
		not game_source.contains("ActorRepresentationFactory")
		and not game_source.contains("FurnitureRepresentationFactory"),
		"Game must not know concrete Representation Factory types."
	)
	_expect(
		not game_source.contains("actor_representation.tscn")
		and not game_source.contains("furniture_representation.tscn"),
		"Game must not own Representation Scene references."
	)
	_expect(
		game_source.contains("EntityRepresentationRegistry.create_default()"),
		"Game must obtain the internally configured default Registry."
	)
	for entity_source_path in [
		"res://scripts/entities/entity.gd",
		"res://scripts/actors/actor.gd",
		"res://scripts/furniture/furniture.gd",
	]:
		_expect(
			not _read_text(entity_source_path).contains("Representation"),
			"Entity logic must not reference Representation: %s" % entity_source_path
		)


func _test_missing_factory_prepare_safety() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	var entity_registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_expect(world_definition != null, "WorldDefinition Autoload must exist.")
	_expect(world_state != null, "WorldState Autoload must exist.")
	_expect(entity_registry != null, "EntityRegistry Autoload must exist.")
	if world_definition == null or world_state == null or entity_registry == null:
		return

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller := game.get_node_or_null("PlayerController") as PlayerController
	var player := controller.controlled_actor if controller != null else null
	_expect(controller != null and player != null, "Game must initialize controlled Actor.")
	if controller == null or player == null:
		game.queue_free()
		await process_frame
		return

	var old_location: GridScene = game.get("current_location")
	var old_representation := controller.controlled_representation
	var old_state_location := player.current_location_id
	var old_state_position := player.local_position
	var old_state_facing := player.facing
	var old_active_locations: Dictionary = world_state.get("_active_locations")
	var old_active_reference := old_active_locations[old_location.location_id] as WeakRef
	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var edge := world_definition.get_edge(tavern_id, &"back_door")
	game.set("representation_registry", EntityRepresentationRegistry.new())
	var change_result: Variant = game.call(
		"_replace_location",
		edge.target_location_id,
		tavern_id,
		edge
	)

	_expect(change_result != true, "A missing Representation Factory must fail Location Prepare.")
	_expect(game.get("current_location") == old_location, "Prepare failure must preserve current Location.")
	_expect(
		controller.controlled_representation == old_representation,
		"Prepare failure must preserve controlled Representation."
	)
	_expect(controller.controlled_actor == player, "Prepare failure must preserve controlled Actor.")
	_expect(
		player.current_location_id == old_state_location
		and player.local_position == old_state_position
		and player.facing == old_state_facing,
		"Prepare failure must preserve authoritative ActorState."
	)
	var current_active_locations: Dictionary = world_state.get("_active_locations")
	var current_active_reference := (
		current_active_locations[old_location.location_id] as WeakRef
	)
	_expect(
		old_active_reference != null
		and current_active_reference != null
		and current_active_reference.get_ref() == old_active_reference.get_ref(),
		"Prepare failure must preserve WorldState active Location."
	)
	_expect(
		is_instance_valid(old_location)
		and old_location.is_inside_tree()
		and is_instance_valid(old_representation)
		and old_representation.is_inside_tree(),
		"Prepare failure must keep the old world playable."
	)

	game.queue_free()
	await process_frame


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V8 Entity Representation System: %d checks passed." % _checks)
		quit(0)
		return
	push_error(
		"V8 Entity Representation System: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
