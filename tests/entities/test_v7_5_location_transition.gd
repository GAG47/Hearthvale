extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const CHEST_INSTANCE_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	var registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	_expect(world_definition != null, "WorldDefinition Autoload must exist.")
	_expect(world_state != null, "WorldState Autoload must exist.")
	_expect(registry != null, "EntityRegistry Autoload must exist.")
	if world_definition == null or world_state == null or registry == null:
		_finish()
		return
	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var yard_id := world_definition.get_project_location_id(&"tavern_yard")

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller := game.get_node_or_null("PlayerController") as PlayerController
	var player := registry.get_entity(PLAYER_INSTANCE_ID) as Actor
	var chest := registry.get_entity(CHEST_INSTANCE_ID) as Furniture
	_expect(controller != null and player != null and chest != null, "Game must initialize runtime Entities.")
	if controller == null or player == null or chest == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var tavern := game.get("current_location") as GridScene
	var tavern_representation := controller.controlled_representation
	_expect(tavern != null and tavern.location_id == tavern_id, "Tavern must be current.")
	_expect(is_instance_valid(tavern_representation), "Player Representation must be active.")

	var missing_location_edge := LocationEdgeDefinition.new(
		&"d0000000-0000-4000-8000-000000000001",
		&"test_missing_location",
		&"d0000000-0000-4000-8000-000000000002",
		&"entry"
	)
	_expect_prepare_failure(
		game, controller, world_state, player,
		missing_location_edge.target_location_id, tavern_id, missing_location_edge,
		"missing Location instance"
	)

	var missing_entry_edge := LocationEdgeDefinition.new(
		&"d0000000-0000-4000-8000-000000000003",
		&"test_missing_entry",
		yard_id,
		&"does_not_exist"
	)
	_expect_prepare_failure(
		game, controller, world_state, player,
		yard_id, tavern_id, missing_entry_edge,
		"missing target Entry Anchor"
	)

	var real_yard_edge := world_definition.get_edge(tavern_id, &"back_door")
	var original_representation_registry: Variant = game.get("representation_registry")
	game.set("representation_registry", EntityRepresentationRegistry.new())
	_expect_prepare_failure(
		game, controller, world_state, player,
		yard_id, tavern_id, real_yard_edge,
		"missing Entity Representation Factory"
	)
	game.set("representation_registry", original_representation_registry)

	var yard_state := world_state.get_location_state(yard_id)
	yard_state.ground_overrides[Vector2i.ZERO] = &"d0000000-0000-4000-8000-000000000004"
	_expect_prepare_failure(
		game, controller, world_state, player,
		yard_id, tavern_id, real_yard_edge,
		"invalid sparse Ground override"
	)
	yard_state.ground_overrides.erase(Vector2i.ZERO)

	var playable_position := tavern_representation.position
	Input.action_press(&"ui_left")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_left")
	await physics_frame
	_expect(
		tavern_representation.position.x < playable_position.x,
		"Old Location must remain playable after Prepare failures."
	)

	var state_count := world_state.get_entity_states().size()
	var location_state_count := world_state.get_location_states().size()
	var chest_state := chest.furniture_state
	var openable_state := chest.get_openable_state()
	openable_state.is_open = true
	var old_tavern := game.get("current_location") as GridScene
	var old_representation := controller.controlled_representation
	var changed := _attempt_replace(game, yard_id, tavern_id, real_yard_edge)
	_expect(changed, "A fully prepared data-driven Location change must Commit.")
	await process_frame
	var yard := game.get("current_location") as GridScene
	var yard_representation := controller.controlled_representation
	_expect(yard != null and yard.location_id == yard_id, "Commit must update current_location.")
	_expect(player.current_location_id == yard_id, "Commit must migrate ActorState location.")
	_expect(player.local_position == Vector2(384.0, 80.0), "Commit must use Entry Anchor position.")
	_expect(player.facing == ActorState.Facing.DOWN, "Commit must use Entry Anchor facing.")
	_expect(
		is_instance_valid(yard_representation)
		and yard_representation != old_representation
		and yard_representation.actor == player,
		"Commit must switch control to the prepared ActorRepresentation."
	)
	_expect(not is_instance_valid(old_tavern), "Commit must release the old Location Scene.")
	_expect(not is_instance_valid(old_representation), "Commit must release the old Representation.")
	_expect(
		yard.get_node_or_null("GroundLayer") is TileMapLayer
		and yard.get_node_or_null("DecorationLayer") is Node2D
		and yard.get_node_or_null("StructureLayer") is TileMapLayer
		and yard.get_node_or_null("EntityRepresentationRoot") is Node2D,
		"Prepared Location Scene must contain all built Representation layers."
	)
	_expect(
		world_state.get_entity_states().size() == state_count
		and world_state.get_location_states().size() == location_state_count,
		"Commit must not recreate persistent EntityState or LocationState objects."
	)
	_expect(
		chest.furniture_state == chest_state
		and chest.get_openable_state() == openable_state
		and openable_state.is_open,
		"Leaving a Location must preserve Entity State objects."
	)

	var yard_start := yard_representation.position
	Input.action_press(&"ui_down")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_down")
	await physics_frame
	_expect(yard_representation.position.y > yard_start.y, "Movement must work after Commit.")

	var return_edge := world_definition.get_edge(yard_id, &"tavern_door")
	var old_yard := yard
	var returned := _attempt_replace(game, tavern_id, yard_id, return_edge)
	_expect(returned, "A return Location change must Commit.")
	await process_frame
	var returned_tavern := game.get("current_location") as GridScene
	var returned_chest := _find_furniture_representation(returned_tavern, CHEST_INSTANCE_ID)
	_expect(returned_tavern.location_id == tavern_id, "Return Commit must restore Tavern.")
	_expect(player.current_location_id == tavern_id, "Return Commit must migrate ActorState back.")
	_expect(player.local_position == Vector2(576.0, 432.0), "Return must use back-door Entry Anchor.")
	_expect(player.facing == ActorState.Facing.UP, "Return must use back-door Entry facing.")
	_expect(not is_instance_valid(old_yard), "Return Commit must unload the prior Scene.")
	_expect(
		is_instance_valid(returned_chest)
		and returned_chest.furniture == chest
		and chest.furniture_state == chest_state,
		"Scene rebuild must reuse the same Furniture and FurnitureState."
	)
	_expect(
		_get_furniture_visual_path(returned_chest) == "res://assets/furniture/chest_open.svg",
		"Rebuilt FurnitureRepresentation must restore current State visuals."
	)

	game.queue_free()
	await process_frame
	_finish()


func _expect_prepare_failure(
	game: Node,
	controller: PlayerController,
	world_state: WorldStateRuntime,
	player: Actor,
	target_location_id: StringName,
	from_location_id: StringName,
	edge: LocationEdgeDefinition,
	case_name: String
) -> void:
	var snapshot := _capture_world(game, controller, world_state, player)
	var changed := _attempt_replace(game, target_location_id, from_location_id, edge)
	_expect(not changed, "%s must fail during Prepare." % case_name)
	_expect(
		_capture_world(game, controller, world_state, player) == snapshot,
		"%s failure must leave active world facts unchanged." % case_name
	)
	var old_location: GridScene = snapshot["current_location"]
	var old_representation: ActorRepresentation = snapshot["controlled_representation"]
	_expect(
		is_instance_valid(old_location)
		and old_location.is_inside_tree()
		and is_instance_valid(old_representation)
		and old_representation.is_inside_tree(),
		"%s failure must keep the old world playable." % case_name
	)


func _capture_world(
	game: Node,
	controller: PlayerController,
	world_state: WorldStateRuntime,
	player: Actor
) -> Dictionary:
	var active_locations: Dictionary = {}
	var active_registry: Dictionary = world_state.get("_active_locations")
	for location_id in active_registry:
		var reference := active_registry[location_id] as WeakRef
		active_locations[location_id] = reference.get_ref() if reference != null else null
	return {
		"current_location": game.get("current_location"),
		"controlled_actor": controller.controlled_actor,
		"controlled_representation": controller.controlled_representation,
		"player_state": player.state,
		"player_location": player.current_location_id,
		"player_position": player.local_position,
		"player_facing": player.facing,
		"active_locations": active_locations,
	}


func _attempt_replace(
	game: Node,
	target_location_id: StringName,
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> bool:
	return game.call("_replace_location", target_location_id, from_location_id, edge) == true


func _find_furniture_representation(
	location: GridScene,
	instance_id: StringName
) -> FurnitureRepresentation:
	if not is_instance_valid(location):
		return null
	var representation_root := location.get_node_or_null("EntityRepresentationRoot")
	if representation_root == null:
		return null
	for child in representation_root.get_children():
		if child is FurnitureRepresentation and (child as FurnitureRepresentation).instance_id == instance_id:
			return child as FurnitureRepresentation
	return null


func _get_furniture_visual_path(representation: FurnitureRepresentation) -> String:
	if not is_instance_valid(representation):
		return ""
	var sprite := representation.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.texture.resource_path if sprite != null and sprite.texture != null else ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V7.5 Location Prepare to Commit: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V7.5 Location Prepare to Commit: %d of %d checks failed." % [_failures, _checks])
	quit(1)
