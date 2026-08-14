extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CHEST_DEFINITION_ID := &"7f45a0d2-2ff2-4f1c-8b7a-3d7d0dd5b8a1"
const MISSING_SCENE_LOCATION_ID := &"v7_5_missing_scene"
const WRONG_ROOT_LOCATION_ID := &"v7_5_wrong_root"
const MISMATCHED_LOCATION_ID := &"v7_5_mismatched_location"

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

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var controller := game.get_node_or_null("PlayerController") as PlayerController
	var controlled_actor_id: StringName = game.get("controlled_actor_id")
	var player := registry.get_entity(controlled_actor_id) as Actor
	var chest := _find_furniture_by_definition(registry, CHEST_DEFINITION_ID)
	_expect(controller != null, "Game must contain PlayerController.")
	_expect(player != null, "Game must register the Player Actor.")
	_expect(chest != null, "Game must register the Chest Furniture.")
	if controller == null or player == null or chest == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var tavern := game.get("current_location") as GridScene
	var tavern_representation := controller.controlled_representation
	_expect(tavern != null and tavern.location_id == &"tavern", "Tavern must be current.")
	_expect(
		is_instance_valid(tavern_representation),
		"PlayerController must initially control Tavern ActorRepresentation."
	)
	if tavern == null or not is_instance_valid(tavern_representation):
		game.queue_free()
		await process_frame
		_finish()
		return

	var missing_definition_edge := LocationEdgeDefinition.new(
		&"test_missing_definition",
		&"v7_5_missing_definition",
		&"entry"
	)
	_expect_prepare_failure(
		game,
		controller,
		world_state,
		player,
		missing_definition_edge.to_location,
		&"tavern",
		missing_definition_edge,
		"missing LocationDefinition"
	)

	_add_test_definition(
		world_definition,
		LocationDefinition.new(
			MISSING_SCENE_LOCATION_ID,
			"Missing Scene",
			"res://tests/entities/fixtures/locations/does_not_exist.tscn"
		)
	)
	_expect_prepare_failure(
		game,
		controller,
		world_state,
		player,
		MISSING_SCENE_LOCATION_ID,
		&"tavern",
		null,
		"unloadable target Scene"
	)
	_remove_test_definition(world_definition, MISSING_SCENE_LOCATION_ID)

	_add_test_definition(
		world_definition,
		LocationDefinition.new(
			WRONG_ROOT_LOCATION_ID,
			"Wrong Root",
			"res://scenes/main.tscn"
		)
	)
	_expect_prepare_failure(
		game,
		controller,
		world_state,
		player,
		WRONG_ROOT_LOCATION_ID,
		&"tavern",
		null,
		"target Scene that does not instantiate as GridScene"
	)
	_remove_test_definition(world_definition, WRONG_ROOT_LOCATION_ID)

	_add_test_definition(
		world_definition,
		LocationDefinition.new(
			MISMATCHED_LOCATION_ID,
			"Mismatched Location",
			"res://scenes/tavern_yard.tscn"
		)
	)
	_expect_prepare_failure(
		game,
		controller,
		world_state,
		player,
		MISMATCHED_LOCATION_ID,
		&"tavern",
		null,
		"Scene location_id mismatch"
	)
	_remove_test_definition(world_definition, MISMATCHED_LOCATION_ID)

	var missing_entry_edge := LocationEdgeDefinition.new(
		&"test_missing_entry",
		&"tavern_yard",
		&"does_not_exist"
	)
	_expect_prepare_failure(
		game,
		controller,
		world_state,
		player,
		&"tavern_yard",
		&"tavern",
		missing_entry_edge,
		"missing target Entry"
	)

	var yard_edge := LocationEdgeDefinition.new(
		&"back_door",
		&"tavern_yard",
		&"tavern_entrance"
	)
	var original_right_visual: String = player.definition.visuals["right"]
	player.definition.visuals["right"] = "res://assets/actors/does_not_exist.svg"
	await _expect_requested_prepare_failure(
		game,
		controller,
		world_state,
		player,
		&"back_door",
		"ActorRepresentation visual preparation"
	)
	player.definition.visuals["right"] = original_right_visual

	var playable_position := tavern_representation.position
	Input.action_press(&"ui_left")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_left")
	await physics_frame
	_expect(
		tavern_representation.position.x < playable_position.x,
		"The old Location must remain playable after Prepare failures."
	)

	var state_count := world_state.get_entity_states().size()
	var chest_state := chest.furniture_state
	var openable_state := chest.get_openable_state()
	_expect(openable_state != null, "Chest must keep its OpenableState.")
	if openable_state != null:
		openable_state.is_open = true
	tavern_representation.facing = ActorState.Facing.LEFT
	tavern_representation.sync_state_from_representation()
	var old_tavern := game.get("current_location") as GridScene
	var old_tavern_representation := controller.controlled_representation
	var yard_changed := _attempt_replace(
		game,
		&"tavern_yard",
		&"tavern",
		yard_edge
	)
	_expect(yard_changed, "A fully prepared Tavern to Yard change must Commit.")
	await process_frame
	var yard := game.get("current_location") as GridScene
	var yard_representation := controller.controlled_representation
	_expect(yard != null and yard.location_id == &"tavern_yard", "Commit must update current_location.")
	_expect(player.current_location_id == &"tavern_yard", "Commit must migrate ActorState location.")
	_expect(player.local_position == Vector2(384.0, 80.0), "Commit must use target Entry position.")
	_expect(player.facing == ActorState.Facing.LEFT, "Commit must preserve ActorState facing.")
	_expect(
		is_instance_valid(yard_representation)
		and yard_representation != old_tavern_representation
		and controller.controlled_actor == player
		and yard_representation.actor == player,
		"Commit must switch PlayerController to the prepared ActorRepresentation."
	)
	_expect(not is_instance_valid(old_tavern), "Commit must release the old Location.")
	_expect(not is_instance_valid(old_tavern_representation), "Commit must release old Representation.")
	_expect(
		_get_actor_visual_path(yard_representation) == player.definition.visuals["left"],
		"Prepared ActorRepresentation must preserve the four-direction visual."
	)
	var camera := controller.get_node_or_null("Camera2D") as Camera2D
	_expect(
		controller.global_position == yard_representation.global_position,
		"Camera owner must follow the newly controlled ActorRepresentation."
	)
	_expect(
		camera != null and camera.limit_right == 768 and camera.limit_bottom == 576,
		"Commit must update Camera bounds for the target Location."
	)
	_expect(
		world_state.get_entity_states().size() == state_count,
		"Successful Commit must not create EntityStates."
	)
	_expect(
		chest.furniture_state == chest_state
		and chest.get_openable_state() == openable_state
		and openable_state != null
		and openable_state.is_open,
		"Leaving Tavern must preserve FurnitureState and BehaviorState objects."
	)

	var yard_start := yard_representation.position
	Input.action_press(&"ui_down")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_down")
	await physics_frame
	_expect(yard_representation.position.y > yard_start.y, "Movement must work after Commit.")

	var tavern_edge := LocationEdgeDefinition.new(
		&"tavern_door",
		&"tavern",
		&"back_door"
	)
	var openable_config: Dictionary = chest.definition.behaviors["openable"]
	var original_open_visual: String = openable_config["open_visual_ref"]
	openable_config["open_visual_ref"] = "res://assets/furniture/does_not_exist.svg"
	_expect_prepare_failure(
		game,
		controller,
		world_state,
		player,
		&"tavern",
		&"tavern_yard",
		tavern_edge,
		"FurnitureRepresentation visual preparation"
	)
	openable_config["open_visual_ref"] = original_open_visual

	var old_yard := game.get("current_location") as GridScene
	var old_yard_representation := controller.controlled_representation
	var tavern_changed := _attempt_replace(
		game,
		&"tavern",
		&"tavern_yard",
		tavern_edge
	)
	_expect(tavern_changed, "A fully prepared Yard to Tavern change must Commit.")
	await process_frame
	var returned_tavern := game.get("current_location") as GridScene
	var returned_representation := controller.controlled_representation
	var returned_chest_representation := _find_furniture_representation(
		returned_tavern,
		chest.entity_id
	)
	_expect(returned_tavern != null and returned_tavern.location_id == &"tavern", "Return Commit must update current_location.")
	_expect(player.current_location_id == &"tavern", "Return Commit must migrate ActorState.")
	_expect(player.local_position == Vector2(576.0, 432.0), "Return Commit must use back_door Entry.")
	_expect(
		is_instance_valid(returned_representation)
		and returned_representation != old_yard_representation,
		"Return Commit must bind another prepared ActorRepresentation."
	)
	_expect(not is_instance_valid(old_yard), "Return Commit must release Yard.")
	_expect(not is_instance_valid(old_yard_representation), "Return Commit must release Yard Representation.")
	_expect(
		is_instance_valid(returned_chest_representation)
		and returned_chest_representation.furniture == chest,
		"Return Commit must activate prepared FurnitureRepresentation."
	)
	_expect(
		chest.furniture_state == chest_state
		and chest.get_openable_state() == openable_state
		and openable_state != null
		and openable_state.is_open,
		"Returning to Tavern must keep the same opened OpenableState."
	)
	_expect(
		_get_furniture_visual_path(returned_chest_representation)
		== "res://assets/furniture/chest_open.svg",
		"Recreated Chest Representation must restore the open visual."
	)
	_expect(
		world_state.get_entity_states().size() == state_count,
		"Location round trip must not reinitialize EntityState or BehaviorState."
	)
	returned_representation.position = Vector2(432.0, 208.0)
	returned_representation.facing = ActorState.Facing.RIGHT
	returned_representation.sync_state_from_representation()
	var close_result := controller.request_interaction()
	_expect(
		close_result.success and close_result.action_id == &"close",
		"Interaction must use the recreated FurnitureRepresentation index after Commit."
	)
	var reopen_result := controller.request_interaction()
	_expect(
		reopen_result.success
		and reopen_result.action_id == &"open"
		and openable_state != null
		and openable_state.is_open,
		"Furniture Behavior must remain usable after the Location round trip."
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
		"%s failure must leave Location, WorldState, ActorState and PlayerController unchanged."
		% case_name
	)
	var old_location: GridScene = snapshot["current_location"]
	var old_representation: ActorRepresentation = snapshot["controlled_representation"]
	_expect(
		is_instance_valid(old_location)
		and old_location.is_inside_tree()
		and is_instance_valid(old_representation)
		and old_representation.is_inside_tree()
		and old_representation.is_in_group(&"player"),
		"%s failure must keep the old Location and Player Representation active."
		% case_name
	)


func _expect_requested_prepare_failure(
	game: Node,
	controller: PlayerController,
	world_state: WorldStateRuntime,
	player: Actor,
	edge_key: StringName,
	case_name: String
) -> void:
	var snapshot := _capture_world(game, controller, world_state, player)
	game.call("request_location_change", edge_key)
	for _frame in range(10):
		await process_frame
		await physics_frame
		if not game.get("transition_in_progress"):
			break
	_expect(
		not game.get("transition_in_progress"),
		"%s request must finish after Prepare failure." % case_name
	)
	_expect(
		_capture_world(game, controller, world_state, player) == snapshot,
		"%s request failure must leave Location, WorldState, ActorState and PlayerController unchanged."
		% case_name
	)
	var old_location: GridScene = snapshot["current_location"]
	var old_representation: ActorRepresentation = snapshot["controlled_representation"]
	_expect(
		is_instance_valid(old_location)
		and old_location.is_inside_tree()
		and is_instance_valid(old_representation)
		and old_representation.is_inside_tree()
		and old_representation.is_in_group(&"player")
		and controller.is_physics_processing(),
		"%s request failure must restore input processing and keep the old world playable."
		% case_name
	)


func _capture_world(
	game: Node,
	controller: PlayerController,
	world_state: WorldStateRuntime,
	player: Actor
) -> Dictionary:
	var state_facts: Dictionary = {}
	for state in world_state.get_entity_states():
		var fact := {
			"state": state,
			"location_id": state.current_location_id,
			"local_position": state.local_position,
		}
		if state is ActorState:
			fact["facing"] = (state as ActorState).facing
		elif state is FurnitureState:
			var behavior_facts: Dictionary = {}
			for behavior_id in (state as FurnitureState).behavior_states:
				var behavior_state := (state as FurnitureState).behavior_states[behavior_id]
				var behavior_fact := {"state": behavior_state}
				if behavior_state is OpenableState:
					behavior_fact["is_open"] = (behavior_state as OpenableState).is_open
				behavior_facts[behavior_id] = behavior_fact
			fact["behavior_states"] = behavior_facts
		state_facts[state.entity_id] = fact

	var active_locations: Dictionary = {}
	var active_registry: Dictionary = world_state.get("_active_locations")
	for location_id in active_registry:
		var reference := active_registry[location_id] as WeakRef
		active_locations[location_id] = reference.get_ref() if reference != null else null

	return {
		"current_location": game.get("current_location"),
		"controlled_actor": controller.controlled_actor,
		"controlled_representation": controller.controlled_representation,
		"controller_processing": controller.is_physics_processing(),
		"player_state": player.state,
		"state_facts": state_facts,
		"active_locations": active_locations,
	}


func _attempt_replace(
	game: Node,
	target_location_id: StringName,
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> bool:
	var result: Variant = game.call(
		"_replace_location",
		target_location_id,
		from_location_id,
		edge
	)
	return result == true


func _add_test_definition(
	world_definition: WorldDefinitionRuntime,
	definition: LocationDefinition
) -> void:
	var locations: Dictionary = world_definition.get("_locations")
	locations[definition.location_id] = definition


func _remove_test_definition(
	world_definition: WorldDefinitionRuntime,
	location_id: StringName
) -> void:
	var locations: Dictionary = world_definition.get("_locations")
	locations.erase(location_id)


func _find_furniture_representation(
	location: GridScene,
	entity_id: StringName
) -> FurnitureRepresentation:
	if not is_instance_valid(location):
		return null
	for child in location.get_children():
		if child is FurnitureRepresentation and (child as FurnitureRepresentation).entity_id == entity_id:
			return child as FurnitureRepresentation
	return null


func _find_furniture_by_definition(
	registry: EntityRegistryRuntime,
	definition_id: StringName
) -> Furniture:
	for entity in registry.get_entities():
		if entity is Furniture and (entity as Furniture).definition.definition_id == definition_id:
			return entity as Furniture
	return null


func _get_actor_visual_path(representation: ActorRepresentation) -> String:
	if not is_instance_valid(representation):
		return ""
	var sprite := representation.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.texture.resource_path if sprite != null and sprite.texture != null else ""


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
	push_error(
		"V7.5 Location Prepare to Commit: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
