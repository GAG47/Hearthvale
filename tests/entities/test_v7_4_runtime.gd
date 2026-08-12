extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_DEFINITION_PATH := "res://data/actors/player.json"
const MARTHA_DEFINITION_PATH := "res://data/actors/martha.json"
const ACTOR_PRESENTATION_SCENE_PATH := "res://scenes/actors/actor_presentation.tscn"
const FURNITURE_PRESENTATION_SCENE_PATH := (
	"res://scenes/furniture/furniture_presentation.tscn"
)
const CHEST_ENTITY_ID := &"5543caf7-2a10-4a40-84de-3a39ffdf670e"
const SIGN_ENTITY_ID := &"1d67bbf9-edc2-4264-a861-8bd3e3e61e15"
const BED_ENTITY_ID := &"a6ae5842-8c6d-4df2-9b80-a271b5496716"
const SECOND_CHEST_ENTITY_ID := &"44444444-4444-4444-8444-444444444444"

var _checks := 0
var _failures := 0
var _last_action_result: ActionResult


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var registry := root.get_node_or_null("EntityRegistry") as EntityRegistryRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	_expect(registry != null, "The EntityRegistry Autoload must exist.")
	_expect(world_state != null, "The WorldState Autoload must exist.")
	if registry == null or world_state == null:
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
	var player := registry.get_entity(player_definition.entity_id) as Actor
	_expect(player != null, "Game must register the Player Actor as an Entity.")
	if player == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_expect(player is Entity, "Actor must extend Entity.")
	_expect(
		game.get("controlled_actor_id") == player_definition.entity_id,
		"Game controlled_actor_id must come from player.json."
	)
	_expect(
		world_state.get_entity_state(player.entity_id) == player.state,
		"WorldState and Player Actor must hold the same ActorState object."
	)
	_expect(player.state is ActorState, "Player must hold ActorState through Entity.state.")
	_expect(
		player.definition.entity_id == player_definition.entity_id
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
	_expect(player.current_location_id == &"tavern", "Player must start in Tavern.")
	_expect(
		player.local_position == Vector2(384.0, 256.0),
		"Player must preserve its existing initial local_position."
	)
	_expect(player.facing == ActorState.Facing.DOWN, "Player must start facing DOWN.")
	_expect(
		not registry.has_entity(martha_definition.entity_id),
		"Martha must remain definition-only in the current runtime."
	)
	_expect(
		not world_state.has_entity_state(martha_definition.entity_id),
		"Martha must not receive an ActorState."
	)
	_expect(registry.get_entities().size() == 4, "Player and three Furniture Entities must exist.")
	_expect(world_state.get_entity_states().size() == 4, "WorldState must hold four EntityStates.")

	var chest := _expect_furniture(registry, world_state, CHEST_ENTITY_ID, &"wooden_chest")
	var sign := _expect_furniture(registry, world_state, SIGN_ENTITY_ID, &"sign")
	var bed := _expect_furniture(registry, world_state, BED_ENTITY_ID, &"simple_bed")
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
		FurnitureState.new(SECOND_CHEST_ENTITY_ID, &"tavern", Vector2.ZERO)
	)
	var second_openable_state := second_chest.get_openable_state()
	_expect(
		second_openable_state != null and second_openable_state != chest_openable_state,
		"Each Furniture instance must own an independent OpenableState."
	)

	var presentation := controller.controlled_presentation
	_expect(controller.controlled_actor == player, "PlayerController must control Player Actor.")
	_expect(is_instance_valid(presentation), "PlayerController must bind ActorPresentation.")
	if not is_instance_valid(presentation):
		game.queue_free()
		await process_frame
		_finish()
		return

	_expect(presentation.actor == player, "ActorPresentation must bind the logical Actor.")
	_expect(
		presentation.scene_file_path == ACTOR_PRESENTATION_SCENE_PATH,
		"Player must use the shared ActorPresentation Scene."
	)
	_expect(presentation.is_in_group(&"player"), "Controlled Presentation must carry player group.")
	_expect(
		presentation.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"ActorPresentation collision must be preserved."
	)
	_expect(
		presentation.collision_layer == 1 and presentation.collision_mask == 1,
		"ActorPresentation collision layer and mask must be preserved."
	)
	_expect(presentation.get_node_or_null("Camera2D") == null, "Camera must remain outside ActorPresentation.")
	_expect(
		_get_actor_visual_path(presentation) == player_definition.visuals["down"],
		"Player must initially display visuals.down."
	)

	var tavern := game.get("current_location") as GridScene
	var initial_furniture_presentations := _get_furniture_presentations(tavern)
	_expect(initial_furniture_presentations.size() == 3, "Tavern must spawn three FurniturePresentations.")
	for furniture_presentation in initial_furniture_presentations:
		_expect(
			furniture_presentation.furniture is Furniture
			and furniture_presentation.furniture is Entity,
			"FurniturePresentation must bind an existing logical Furniture Entity."
		)
		_expect(
			furniture_presentation.scene_file_path == FURNITURE_PRESENTATION_SCENE_PATH,
			"All Furniture must use the shared FurniturePresentation Scene."
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

	await _expect_input_facing_visual(presentation, &"ui_up", ActorState.Facing.UP, "up")
	await _expect_input_facing_visual(presentation, &"ui_down", ActorState.Facing.DOWN, "down")
	await _expect_input_facing_visual(presentation, &"ui_left", ActorState.Facing.LEFT, "left")
	await _expect_input_facing_visual(presentation, &"ui_right", ActorState.Facing.RIGHT, "right")
	presentation.facing = ActorState.Facing.DOWN

	var initial_position := presentation.position
	Input.action_press(&"ui_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_right")
	await physics_frame
	_expect(presentation.position.x > initial_position.x, "PlayerController must apply movement input.")
	_expect(presentation.facing == ActorState.Facing.RIGHT, "Movement must update ActorState.facing.")
	_expect(player.local_position == presentation.position, "Movement must synchronize ActorState.local_position.")

	_place_actor(presentation, Vector2i(13, 6), ActorState.Facing.RIGHT)
	var pre_collision_position := presentation.position
	Input.action_press(&"ui_right")
	await create_timer(0.3).timeout
	Input.action_release(&"ui_right")
	await physics_frame
	_expect(presentation.position.x > pre_collision_position.x, "Player must approach blocking Furniture.")
	_expect(presentation.position.x < 450.0, "ActorPresentation must collide with Chest FurniturePresentation.")

	_test_interactions(controller, presentation, game, chest)
	var chest_state := chest.furniture_state
	var old_chest_presentation := _find_furniture_presentation(tavern, CHEST_ENTITY_ID)
	_expect(
		chest_openable_state != null and chest_openable_state.is_open,
		"Chest OpenableState must retain its opened state."
	)
	_expect(
		second_openable_state != null and not second_openable_state.is_open,
		"Opening one Furniture instance must not modify another OpenableState."
	)
	_expect(
		_get_furniture_visual_path(old_chest_presentation) == "res://assets/furniture/chest_open.svg",
		"OpenableBehavior state changes must refresh FurniturePresentation."
	)

	var selected := _select_from(presentation, Vector2i(13, 6), ActorState.Facing.RIGHT)
	_expect(selected == chest, "InteractionTargetSelector must return the logical Furniture Entity.")
	var selected_variant: Variant = selected
	_expect(not selected_variant is Node, "InteractionTargetSelector must not return a Presentation Node.")

	var old_actor_presentation := presentation
	game.call("request_location_change", &"back_door")
	await _wait_for_transition(game)

	var yard_presentation := controller.controlled_presentation
	_expect(player.current_location_id == &"tavern_yard", "Location change must update ActorState.")
	_expect(
		is_instance_valid(yard_presentation) and yard_presentation != old_actor_presentation,
		"Location change must bind a new ActorPresentation."
	)
	_expect(
		controller.controlled_actor == player and yard_presentation.actor == player,
		"Location change must keep the same logical Actor."
	)
	_expect(not is_instance_valid(old_actor_presentation), "Old ActorPresentation must be released.")
	_expect(
		_get_actor_visual_path(yard_presentation)
		== _get_visual_path_for_facing(player_definition, yard_presentation.facing),
		"A recreated ActorPresentation must restore ActorState.facing."
	)
	_expect(player.local_position == Vector2(384.0, 80.0), "ActorState must use the target entry position.")
	_expect(controller.global_position == yard_presentation.global_position, "Camera owner must follow the new Presentation.")
	if camera != null:
		_expect(camera.limit_right == 768 and camera.limit_bottom == 576, "Camera bounds must update in Tavern Yard.")

	var yard := game.get("current_location") as GridScene
	_expect(_get_actor_presentations(yard).size() == 1, "Tavern Yard must contain only Player ActorPresentation.")
	_expect(_get_furniture_presentations(yard).is_empty(), "Tavern FurniturePresentations must unload outside Tavern.")
	_expect(not is_instance_valid(old_chest_presentation), "Old Chest FurniturePresentation must be released.")
	_expect(registry.get_entity(CHEST_ENTITY_ID) == chest, "Chest Entity must survive Location unload.")
	_expect(world_state.get_entity_state(CHEST_ENTITY_ID) == chest_state, "Chest State must survive Location unload without copying.")
	_expect(
		chest_openable_state != null and chest_openable_state.is_open,
		"Chest OpenableState must survive Location unload."
	)

	var yard_position := yard_presentation.position
	Input.action_press(&"ui_down")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_down")
	await physics_frame
	_expect(yard_presentation.position.y > yard_position.y, "Movement must continue after rebind.")

	game.call("request_location_change", &"tavern_door")
	await _wait_for_transition(game)
	var returned_tavern := game.get("current_location") as GridScene
	var returned_chest_presentation := _find_furniture_presentation(returned_tavern, CHEST_ENTITY_ID)
	_expect(player.current_location_id == &"tavern", "Player ActorState must return to Tavern.")
	_expect(is_instance_valid(returned_chest_presentation), "Tavern reload must recreate Chest Presentation.")
	_expect(returned_chest_presentation.furniture == chest, "Recreated Presentation must bind the same Chest Entity.")
	_expect(
		chest.furniture_state == chest_state
		and chest.get_openable_state() == chest_openable_state
		and chest_openable_state != null
		and chest_openable_state.is_open,
		"Recreated Chest must retain the same FurnitureState and OpenableState."
	)
	_expect(
		_get_furniture_visual_path(returned_chest_presentation) == "res://assets/furniture/chest_open.svg",
		"Recreated Chest Presentation must restore the open visual from FurnitureState."
	)
	_expect(registry.get_entities().size() == 4, "Location reload must not create duplicate Entities.")
	_expect(world_state.get_entity_states().size() == 4, "Location reload must not create duplicate States.")

	game.queue_free()
	await process_frame
	_finish()


func _expect_furniture(
	registry: EntityRegistryRuntime,
	world_state: WorldStateRuntime,
	entity_id: StringName,
	expected_definition_id: StringName
) -> Furniture:
	var furniture := registry.get_entity(entity_id) as Furniture
	_expect(furniture != null, "Furniture '%s' must be registered." % entity_id)
	if furniture == null:
		return null
	_expect(furniture is Entity, "Furniture must extend Entity.")
	_expect(furniture.state is FurnitureState, "Furniture must hold FurnitureState.")
	_expect(furniture.definition.definition_id == expected_definition_id, "Furniture must use its data Definition.")
	_expect(
		world_state.get_entity_state(entity_id) == furniture.state,
		"WorldState and Furniture must hold the same EntityState object."
	)
	return furniture


func _test_interactions(
	controller: PlayerController,
	presentation: ActorPresentation,
	game: Node,
	chest: Furniture
) -> void:
	_place_actor(presentation, Vector2i(12, 7), ActorState.Facing.RIGHT)
	var sign_result := controller.request_interaction()
	_expect(sign_result.success and sign_result.action_id == &"inspect", "Sign inspect must use WorldAction.")
	_expect(sign_result.message == "今日麦酒三铜币。", "Sign inspect result must remain unchanged.")
	_expect(_last_action_result == sign_result, "PlayerController must emit Sign ActionResult.")
	_expect(game.get_node("HUD/ActionResultLabel").text == sign_result.message, "HUD must receive ActionResult.")

	_place_actor(presentation, Vector2i(13, 6), ActorState.Facing.RIGHT)
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

	_place_actor(presentation, Vector2i(19, 3), ActorState.Facing.RIGHT)
	var bed_result := controller.request_interaction()
	_expect(bed_result.success and bed_result.action_id == &"sleep", "Bed sleep must use SleepableBehavior.")
	_expect(bed_result.message == "你睡到了第二天 08:00。", "Bed sleep result must remain unchanged.")
	_expect(_last_action_result == bed_result, "PlayerController must emit Bed ActionResult.")


func _select_from(
	presentation: ActorPresentation,
	cell: Vector2i,
	facing: ActorState.Facing
) -> Entity:
	_place_actor(presentation, cell, facing)
	return InteractionTargetSelector.select_target(presentation)


func _place_actor(
	presentation: ActorPresentation,
	cell: Vector2i,
	facing: ActorState.Facing
) -> void:
	presentation.position = Vector2(cell * GridScene.CELL_SIZE) + Vector2.ONE * 16.0
	presentation.facing = facing
	presentation.sync_state_from_presentation()


func _get_actor_presentations(location: GridScene) -> Array[ActorPresentation]:
	var presentations: Array[ActorPresentation] = []
	if not is_instance_valid(location):
		return presentations
	for child in location.get_children():
		if child is ActorPresentation:
			presentations.append(child as ActorPresentation)
	return presentations


func _get_furniture_presentations(location: GridScene) -> Array[FurniturePresentation]:
	var presentations: Array[FurniturePresentation] = []
	if not is_instance_valid(location):
		return presentations
	for child in location.get_children():
		if child is FurniturePresentation:
			presentations.append(child as FurniturePresentation)
	return presentations


func _find_furniture_presentation(
	location: GridScene,
	entity_id: StringName
) -> FurniturePresentation:
	for presentation in _get_furniture_presentations(location):
		if presentation.entity_id == entity_id:
			return presentation
	return null


func _get_actor_visual_path(presentation: ActorPresentation) -> String:
	var sprite := presentation.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.texture.resource_path if sprite != null and sprite.texture != null else ""


func _get_furniture_visual_path(presentation: FurniturePresentation) -> String:
	if not is_instance_valid(presentation):
		return ""
	var sprite := presentation.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.texture.resource_path if sprite != null and sprite.texture != null else ""


func _expect_input_facing_visual(
	presentation: ActorPresentation,
	input_action: StringName,
	expected_facing: ActorState.Facing,
	expected_direction: String
) -> void:
	Input.action_press(input_action)
	await physics_frame
	Input.action_release(input_action)
	_expect(
		presentation.facing == expected_facing
		and _get_actor_visual_path(presentation)
		== presentation.actor.definition.visuals[expected_direction],
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
