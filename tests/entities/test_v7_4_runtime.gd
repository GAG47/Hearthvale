extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_DEFINITION_PATH := "res://data/actors/player.json"
const MARTHA_DEFINITION_PATH := "res://data/actors/martha.json"
const ACTOR_REPRESENTATION_SCENE_PATH := "res://scenes/actors/actor_representation.tscn"
const FURNITURE_REPRESENTATION_SCENE_PATH := (
	"res://scenes/furniture/furniture_representation.tscn"
)
const CHEST_ENTITY_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"
const SIGN_ENTITY_ID := &"1d67bbf9-edc2-4264-a861-8bd3e3e61e15"
const BED_ENTITY_ID := &"a6ae5842-8c6d-4df2-9b80-a271b5496716"
const SECOND_CHEST_ENTITY_ID := &"44444444-4444-4444-8444-444444444444"
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0
var _last_action_result: ActionResult


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	var world_definition := root.get_node_or_null("WorldDefinition") as WorldDefinitionRuntime
	_expect(registry != null, "The EntityRegistry Autoload must exist.")
	_expect(world_state != null, "The WorldState Autoload must exist.")
	if registry == null or world_state == null or world_definition == null:
		_finish()
		return

	_expect(
		registry.get_entities().is_empty(),
		"EntityRegistry must not create Entities during its own startup."
	)

	var player_definition := ActorDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	var martha_definition := ActorDefinitionLoader.load_from_file(MARTHA_DEFINITION_PATH)
	_expect(player_definition != null, "player.json must remain loadable.")
	_expect(martha_definition != null, "martha.json must remain loadable.")
	if player_definition == null or martha_definition == null:
		_finish()
		return

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var controller := game.get_node_or_null("PlayerController") as PlayerController
	_expect(controller != null, "Main must contain a PlayerController.")
	if controller == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	controller.action_completed.connect(_on_action_completed)
	var player := registry.get_entity(PLAYER_INSTANCE_ID) as Actor
	_expect(player != null, "Game must register the Player Actor as an Entity.")
	if player == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_expect(player is Entity, "Actor must extend Entity.")
	_expect(
		game.get("controlled_actor_instance_id") == PLAYER_INSTANCE_ID,
		"Game controlled_actor_instance_id must be the independent Player instance UUID."
	)
	_expect(
		world_state.get_entity_state(player.instance_id) == player.state,
		"WorldState and Player Actor must hold the same ActorState object."
	)
	_expect(player.state is ActorState, "Player must hold ActorState through Entity.state.")
	_expect(
		player.definition.definition_id == player_definition.definition_id
		and player.definition.display_name == player_definition.display_name
		and player.definition.visuals == player_definition.visuals,
		"The runtime Player ActorDefinition must preserve all player.json fields."
	)
	_expect(
		player.definition.visuals == {
			"up": "res://assets/actors/player_up.svg",
			"down": "res://assets/actors/player_down.svg",
			"left": "res://assets/actors/player_left.svg",
			"right": "res://assets/actors/player_right.svg",
		},
		"The Player ActorDefinition must preserve all four directional visuals."
	)
	var tavern_id := world_definition.get_project_location_id(&"tavern")
	var yard_id := world_definition.get_project_location_id(&"tavern_yard")
	_expect(player.current_location_id == tavern_id, "Player must start in Tavern.")
	_expect(
		player.local_position == Vector2(384.0, 256.0),
		"Player must preserve its existing initial local_position."
	)
	_expect(player.facing == ActorState.Facing.DOWN, "Player must start facing DOWN.")
	_expect(
		not registry.has_entity(martha_definition.definition_id),
		"Martha must remain definition-only in the current runtime."
	)
	_expect(
		not world_state.has_entity_state(martha_definition.definition_id),
		"Martha must not receive an ActorState."
	)
	_expect(registry.get_entities().size() == 4, "Player and three Furniture Entities must exist.")
	_expect(world_state.get_entity_states().size() == 4, "WorldState must hold four EntityStates.")

	var chest := _expect_furniture(registry, world_state, CHEST_ENTITY_ID, &"a0000000-0000-4000-8000-000000000001")
	var sign := _expect_furniture(registry, world_state, SIGN_ENTITY_ID, &"a0000000-0000-4000-8000-000000000002")
	var bed := _expect_furniture(registry, world_state, BED_ENTITY_ID, &"a0000000-0000-4000-8000-000000000003")
	if chest == null or sign == null or bed == null:
		game.queue_free()
		await process_frame
		_finish()
		return
	_expect(chest.get_primary_action(player) == &"open", "Closed Chest must initially offer open.")
	_expect(sign.get_primary_action(player) == &"inspect", "Sign must offer inspect.")
	_expect(bed.get_primary_action(player) == &"sleep", "Bed must offer sleep.")
	var chest_openable_state := chest.get_openable_state()
	_expect(chest_openable_state != null, "Openable Furniture must own an OpenableState.")
	_expect(
		chest.furniture_state.behavior_states.size() == 1
		and chest.furniture_state.behavior_states[&"openable"] == chest_openable_state,
		"FurnitureState must compose OpenableState under behavior_states.openable."
	)
	_expect(
		sign.furniture_state.behavior_states.is_empty()
		and bed.furniture_state.behavior_states.is_empty(),
		"Stateless Behaviors must not create empty BehaviorState objects."
	)
	_expect(
		not _object_has_property(chest.furniture_state, &"is_open"),
		"FurnitureState must not expose the old direct is_open field."
	)
	var second_chest := Furniture.new(
		chest.definition,
		FurnitureState.new(
			SECOND_CHEST_ENTITY_ID,
			chest.definition.definition_id,
			tavern_id,
			Vector2.ZERO
		)
	)
	var second_openable_state := second_chest.get_openable_state()
	_expect(
		second_openable_state != null and second_openable_state != chest_openable_state,
		"Each Furniture instance must own an independent OpenableState."
	)

	var representation := controller.controlled_representation
	_expect(controller.controlled_actor == player, "PlayerController must control Player Actor.")
	_expect(is_instance_valid(representation), "PlayerController must bind ActorRepresentation.")
	if not is_instance_valid(representation):
		game.queue_free()
		await process_frame
		_finish()
		return

	_expect(representation.actor == player, "ActorRepresentation must bind the logical Actor.")
	_expect(
		representation.scene_file_path == ACTOR_REPRESENTATION_SCENE_PATH,
		"Player must use the shared ActorRepresentation Scene."
	)
	_expect(representation.is_in_group(&"player"), "Controlled Representation must carry player group.")
	_expect(
		representation.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"ActorRepresentation collision must be preserved."
	)
	_expect(
		representation.collision_layer == 1 and representation.collision_mask == 1,
		"ActorRepresentation collision layer and mask must be preserved."
	)
	_expect(representation.get_node_or_null("Camera2D") == null, "Camera must remain outside ActorRepresentation.")
	_expect(
		_get_actor_visual_path(representation) == player_definition.visuals["down"],
		"Player must initially display visuals.down."
	)

	var tavern := game.get("current_location") as GridScene
	var initial_furniture_representations := _get_furniture_representations(tavern)
	_expect(initial_furniture_representations.size() == 3, "Tavern must spawn three FurnitureRepresentations.")
	for furniture_representation in initial_furniture_representations:
		_expect(
			furniture_representation.furniture is Furniture
			and furniture_representation.furniture is Entity,
			"FurnitureRepresentation must bind an existing logical Furniture Entity."
		)
		_expect(
			furniture_representation.scene_file_path == FURNITURE_REPRESENTATION_SCENE_PATH,
			"All Furniture must use the shared FurnitureRepresentation Scene."
		)

	var camera := controller.get_node_or_null("Camera2D") as Camera2D
	_expect(camera != null, "PlayerController must own Camera2D.")
	_expect(
		ProjectSettings.get_setting("physics/common/physics_interpolation", false),
		"2D physics interpolation must remain enabled."
	)
	if camera != null:
		_expect(camera.process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS, "Camera must update on physics frames.")
		_expect(camera.position_smoothing_enabled, "Camera smoothing must remain enabled.")
		_expect(is_equal_approx(camera.position_smoothing_speed, 8.0), "Camera smoothing speed must remain 8.0.")

	await _expect_input_facing_visual(representation, &"ui_up", ActorState.Facing.UP, "up")
	await _expect_input_facing_visual(representation, &"ui_down", ActorState.Facing.DOWN, "down")
	await _expect_input_facing_visual(representation, &"ui_left", ActorState.Facing.LEFT, "left")
	await _expect_input_facing_visual(representation, &"ui_right", ActorState.Facing.RIGHT, "right")
	representation.facing = ActorState.Facing.DOWN

	var initial_position := representation.position
	Input.action_press(&"ui_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_right")
	await physics_frame
	_expect(representation.position.x > initial_position.x, "PlayerController must apply movement input.")
	_expect(representation.facing == ActorState.Facing.RIGHT, "Movement must update ActorState.facing.")
	_expect(player.local_position == representation.position, "Movement must synchronize ActorState.local_position.")

	_place_actor(representation, Vector2i(13, 6), ActorState.Facing.RIGHT)
	var pre_collision_position := representation.position
	Input.action_press(&"ui_right")
	await create_timer(0.3).timeout
	Input.action_release(&"ui_right")
	await physics_frame
	_expect(representation.position.x > pre_collision_position.x, "Player must approach blocking Furniture.")
	_expect(representation.position.x < 450.0, "ActorRepresentation must collide with Chest FurnitureRepresentation.")

	_test_interactions(controller, representation, game, chest)
	var chest_state := chest.furniture_state
	var old_chest_representation := _find_furniture_representation(tavern, CHEST_ENTITY_ID)
	_expect(
		chest_openable_state != null and chest_openable_state.is_open,
		"Chest OpenableState must retain its opened state."
	)
	_expect(
		second_openable_state != null and not second_openable_state.is_open,
		"Opening one Furniture instance must not modify another OpenableState."
	)
	_expect(
		_get_furniture_visual_path(old_chest_representation) == "res://assets/furniture/chest_open.svg",
		"OpenableBehavior state changes must refresh FurnitureRepresentation."
	)

	var selected := _select_from(representation, Vector2i(13, 6), ActorState.Facing.RIGHT)
	_expect(selected == chest, "InteractionTargetSelector must return the logical Furniture Entity.")
	var selected_variant: Variant = selected
	_expect(not selected_variant is Node, "InteractionTargetSelector must not return a Representation Node.")

	var old_actor_representation := representation
	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)

	var yard_representation := controller.controlled_representation
	_expect(player.current_location_id == yard_id, "Location change must update ActorState.")
	_expect(
		is_instance_valid(yard_representation) and yard_representation != old_actor_representation,
		"Location change must bind a new ActorRepresentation."
	)
	_expect(
		controller.controlled_actor == player and yard_representation.actor == player,
		"Location change must keep the same logical Actor."
	)
	_expect(not is_instance_valid(old_actor_representation), "Old ActorRepresentation must be released.")
	_expect(
		_get_actor_visual_path(yard_representation)
		== _get_visual_path_for_facing(player_definition, yard_representation.facing),
		"A recreated ActorRepresentation must restore ActorState.facing."
	)
	_expect(player.local_position == Vector2(384.0, 80.0), "ActorState must use the target entry position.")
	_expect(controller.global_position == yard_representation.global_position, "Camera owner must follow the new Representation.")
	if camera != null:
		_expect(camera.limit_right == 768 and camera.limit_bottom == 576, "Camera bounds must update in Tavern Yard.")

	var yard := game.get("current_location") as GridScene
	_expect(_get_actor_representations(yard).size() == 1, "Tavern Yard must contain only Player ActorRepresentation.")
	_expect(_get_furniture_representations(yard).is_empty(), "Tavern FurnitureRepresentations must unload outside Tavern.")
	_expect(not is_instance_valid(old_chest_representation), "Old Chest FurnitureRepresentation must be released.")
	_expect(registry.get_entity(CHEST_ENTITY_ID) == chest, "Chest Entity must survive Location unload.")
	_expect(world_state.get_entity_state(CHEST_ENTITY_ID) == chest_state, "Chest State must survive Location unload without copying.")
	_expect(
		chest_openable_state != null and chest_openable_state.is_open,
		"Chest OpenableState must survive Location unload."
	)

	var yard_position := yard_representation.position
	Input.action_press(&"ui_down")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_down")
	await physics_frame
	_expect(yard_representation.position.y > yard_position.y, "Movement must continue after rebind.")

	game.call("request_location_change", &"tavern_door")
	await _wait_for_transition(game)
	var returned_tavern := game.get("current_location") as GridScene
	var returned_chest_representation := _find_furniture_representation(returned_tavern, CHEST_ENTITY_ID)
	_expect(player.current_location_id == tavern_id, "Player ActorState must return to Tavern.")
	_expect(is_instance_valid(returned_chest_representation), "Tavern reload must recreate Chest Representation.")
	_expect(returned_chest_representation.furniture == chest, "Recreated Representation must bind the same Chest Entity.")
	_expect(
		chest.furniture_state == chest_state
		and chest.get_openable_state() == chest_openable_state
		and chest_openable_state != null
		and chest_openable_state.is_open,
		"Recreated Chest must retain the same FurnitureState and OpenableState."
	)
	_expect(
		_get_furniture_visual_path(returned_chest_representation) == "res://assets/furniture/chest_open.svg",
		"Recreated Chest Representation must restore the open visual from FurnitureState."
	)
	_expect(registry.get_entities().size() == 4, "Location reload must not create duplicate Entities.")
	_expect(world_state.get_entity_states().size() == 4, "Location reload must not create duplicate States.")

	game.queue_free()
	await process_frame
	_finish()


func _expect_furniture(
	registry: EntityRegistryRuntime,
	world_state: WorldStateRuntime,
	instance_id: StringName,
	expected_definition_id: StringName
) -> Furniture:
	var furniture := registry.get_entity(instance_id) as Furniture
	_expect(furniture != null, "Furniture '%s' must be registered." % instance_id)
	if furniture == null:
		return null
	_expect(furniture is Entity, "Furniture must extend Entity.")
	_expect(furniture.state is FurnitureState, "Furniture must hold FurnitureState.")
	_expect(furniture.definition.definition_id == expected_definition_id, "Furniture must use its data Definition.")
	_expect(
		world_state.get_entity_state(instance_id) == furniture.state,
		"WorldState and Furniture must hold the same EntityState object."
	)
	return furniture


func _test_interactions(
	controller: PlayerController,
	representation: ActorRepresentation,
	game: Node,
	chest: Furniture
) -> void:
	_place_actor(representation, Vector2i(12, 7), ActorState.Facing.RIGHT)
	var sign_result := controller.request_interaction()
	_expect(sign_result.success and sign_result.action_id == &"inspect", "Sign inspect must use WorldAction.")
	_expect(sign_result.message == "今日麦酒三铜币。", "Sign inspect result must remain unchanged.")
	_expect(_last_action_result == sign_result, "PlayerController must emit Sign ActionResult.")
	_expect(game.get_node("HUD/ActionResultLabel").text == sign_result.message, "HUD must receive ActionResult.")

	_place_actor(representation, Vector2i(13, 6), ActorState.Facing.RIGHT)
	var open_result := controller.request_interaction()
	_expect(open_result.success and open_result.action_id == &"open", "Chest open must use OpenableBehavior.")
	_expect(open_result.message == "储物箱打开了。", "Open feedback must use display_name.")
	_expect(
		chest.get_openable_state() != null and chest.get_openable_state().is_open,
		"Chest open must change OpenableState, not FurnitureState fields or Behavior config."
	)
	var close_result := controller.request_interaction()
	_expect(close_result.success and close_result.action_id == &"close", "Opened Chest must offer close.")
	_expect(close_result.message == "储物箱关闭了。", "Close feedback must use display_name.")
	var reopen_result := controller.request_interaction()
	_expect(reopen_result.success and reopen_result.action_id == &"open", "Closed Chest must offer open again.")

	_place_actor(representation, Vector2i(19, 3), ActorState.Facing.RIGHT)
	var bed_result := controller.request_interaction()
	_expect(bed_result.success and bed_result.action_id == &"sleep", "Bed sleep must use SleepableBehavior.")
	_expect(bed_result.message == "你睡到了第二天 08:00。", "Bed sleep result must remain unchanged.")
	_expect(_last_action_result == bed_result, "PlayerController must emit Bed ActionResult.")


func _select_from(
	representation: ActorRepresentation,
	cell: Vector2i,
	facing: ActorState.Facing
) -> Entity:
	_place_actor(representation, cell, facing)
	return InteractionTargetSelector.select_target(representation.actor)


func _place_actor(
	representation: ActorRepresentation,
	cell: Vector2i,
	facing: ActorState.Facing
) -> void:
	representation.position = GridSpace.cell_to_local_position(cell, Vector2.ONE * 16.0)
	representation.facing = facing
	representation.sync_state_from_representation()


func _get_actor_representations(location: GridScene) -> Array[ActorRepresentation]:
	var representations: Array[ActorRepresentation] = []
	if not is_instance_valid(location):
		return representations
	var representation_root := location.get_node_or_null("EntityRepresentationRoot")
	if representation_root == null:
		return representations
	for child in representation_root.get_children():
		if child is ActorRepresentation:
			representations.append(child as ActorRepresentation)
	return representations


func _get_furniture_representations(location: GridScene) -> Array[FurnitureRepresentation]:
	var representations: Array[FurnitureRepresentation] = []
	if not is_instance_valid(location):
		return representations
	var representation_root := location.get_node_or_null("EntityRepresentationRoot")
	if representation_root == null:
		return representations
	for child in representation_root.get_children():
		if child is FurnitureRepresentation:
			representations.append(child as FurnitureRepresentation)
	return representations


func _find_furniture_representation(
	location: GridScene,
	instance_id: StringName
) -> FurnitureRepresentation:
	for representation in _get_furniture_representations(location):
		if representation.instance_id == instance_id:
			return representation
	return null


func _get_actor_visual_path(representation: ActorRepresentation) -> String:
	var sprite := representation.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.texture.resource_path if sprite != null and sprite.texture != null else ""


func _get_furniture_visual_path(representation: FurnitureRepresentation) -> String:
	if not is_instance_valid(representation):
		return ""
	var sprite := representation.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.texture.resource_path if sprite != null and sprite.texture != null else ""


func _expect_input_facing_visual(
	representation: ActorRepresentation,
	input_action: StringName,
	expected_facing: ActorState.Facing,
	expected_direction: String
) -> void:
	Input.action_press(input_action)
	await physics_frame
	Input.action_release(input_action)
	_expect(
		representation.facing == expected_facing
		and _get_actor_visual_path(representation)
		== representation.actor.definition.visuals[expected_direction],
		"Input '%s' must set facing %s and immediately select visuals.%s."
		% [input_action, expected_facing, expected_direction]
	)
	await physics_frame


func _get_visual_path_for_facing(
	definition: ActorDefinition,
	facing: ActorState.Facing
) -> String:
	match facing:
		ActorState.Facing.UP:
			return definition.visuals["up"]
		ActorState.Facing.LEFT:
			return definition.visuals["left"]
		ActorState.Facing.RIGHT:
			return definition.visuals["right"]
		_:
			return definition.visuals["down"]


func _wait_for_transition(game: Node) -> void:
	for _frame in range(8):
		await process_frame
		await physics_frame
		if not game.get("transition_in_progress"):
			return


func _object_has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false


func _on_action_completed(result: ActionResult) -> void:
	_last_action_result = result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V7.4.1 Entity architecture cleanup: %d checks passed." % _checks)
		quit(0)
		return

	push_error(
		"V7.4.1 Entity architecture cleanup: %d of %d checks failed."
		% [_failures, _checks]
	)
	quit(1)
