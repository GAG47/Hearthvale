extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PLAYER_DEFINITION_PATH := "res://data/characters/player.json"
const MARTHA_DEFINITION_PATH := "res://data/characters/martha.json"

var _checks := 0
var _failures := 0
var _last_action_result: ActionResult


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var registry := root.get_node_or_null("CharacterRegistry") as CharacterRegistryRuntime
	var world_state := root.get_node_or_null("WorldState") as WorldStateRuntime
	_expect(registry != null, "The CharacterRegistry Autoload must exist.")
	_expect(world_state != null, "The WorldState Autoload must exist.")
	if registry == null or world_state == null:
		_finish()
		return

	_expect(
		registry.get_characters().is_empty(),
		"CharacterRegistry must not create Characters during its own startup."
	)

	var player_definition := CharacterDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	var martha_definition := CharacterDefinitionLoader.load_from_file(MARTHA_DEFINITION_PATH)
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
	var player := registry.get_character(player_definition.character_id)
	_expect(player != null, "Game must register the Player Character.")
	_expect(
		game.get("controlled_character_id") == player_definition.character_id,
		"Game controlled_character_id must come from player.json."
	)
	_expect(
		world_state.get_character_state(player_definition.character_id) == player.state,
		"WorldState must hold the Player CharacterState."
	)
	_expect(
		player.definition.character_id == player_definition.character_id
		and player.definition.display_name == player_definition.display_name
		and player.definition.presentation_ref == player_definition.presentation_ref,
		"The runtime Player Definition must preserve all player.json fields."
	)
	_expect(player.state.current_location_id == &"tavern", "Player must start in Tavern.")
	_expect(
		player.state.local_position == Vector2(384.0, 256.0),
		"Player must preserve its existing initial local_position."
	)
	_expect(
		player.state.facing == CharacterState.Facing.DOWN,
		"Player must preserve its existing initial facing."
	)
	_expect(not registry.has_character(martha_definition.character_id), "Martha must not be registered.")
	_expect(
		not world_state.has_character_state(martha_definition.character_id),
		"Martha must not receive a CharacterState."
	)
	_expect(registry.get_characters().size() == 1, "Only Player must exist at runtime.")

	var presentation := controller.controlled_presentation
	_expect(controller.controlled_character == player, "PlayerController must control Player Character.")
	_expect(is_instance_valid(presentation), "PlayerController must bind Player Presentation.")
	if not is_instance_valid(presentation):
		game.queue_free()
		await process_frame
		_finish()
		return

	_expect(presentation.character == player, "Player Presentation must bind Player Character.")
	_expect(presentation is CharacterPresentation, "Player must use CharacterPresentation.")
	var presentation_script := presentation.get_script() as Script
	_expect(
		presentation_script != null
		and presentation_script.get_global_name() == &"CharacterPresentation",
		"Player Presentation must use the ordinary CharacterPresentation script."
	)
	_expect(presentation.is_in_group(&"player"), "Controlled Presentation must carry control group.")
	_expect(
		presentation.get_node_or_null("CollisionShape2D") is CollisionShape2D,
		"Player Presentation collision must be preserved."
	)
	_expect(
		presentation.collision_layer == 1 and presentation.collision_mask == 1,
		"Player Presentation collision layer and mask must be preserved."
	)
	_expect(
		presentation.get_node_or_null("Camera2D") == null,
		"Camera must not remain in Player Presentation."
	)

	var camera := controller.get_node_or_null("Camera2D") as Camera2D
	_expect(camera != null, "PlayerController must own Camera2D.")
	if camera != null:
		_expect(camera.position_smoothing_enabled, "Camera smoothing must remain enabled.")
		_expect(
			is_equal_approx(camera.position_smoothing_speed, 8.0),
			"Camera smoothing speed must remain unchanged."
		)

	var initial_position := presentation.position
	Input.action_press(&"ui_right")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_right")
	await physics_frame
	_expect(presentation.position.x > initial_position.x, "PlayerController must apply movement input.")
	_expect(
		presentation.facing == CharacterState.Facing.RIGHT,
		"PlayerController must update facing from movement input."
	)
	_expect(
		player.state.local_position == presentation.position,
		"Player movement must synchronize CharacterState.local_position."
	)

	_place_presentation(presentation, Vector2i(13, 6), CharacterState.Facing.RIGHT)
	var pre_collision_position := presentation.position
	Input.action_press(&"ui_right")
	await create_timer(0.3).timeout
	Input.action_release(&"ui_right")
	await physics_frame
	_expect(
		presentation.position.x > pre_collision_position.x,
		"PlayerController movement must approach blocking WorldObjects."
	)
	_expect(
		presentation.position.x < 450.0,
		"Player Presentation must collide with the Tavern Chest."
	)

	_test_interactions(controller, presentation, game)

	var old_presentation := presentation
	game.call("request_location_change", &"back_door")
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame

	var yard_presentation := controller.controlled_presentation
	_expect(
		player.state.current_location_id == &"tavern_yard",
		"Location change must update Player CharacterState."
	)
	_expect(
		is_instance_valid(yard_presentation) and yard_presentation != old_presentation,
		"Location change must bind a new Player Presentation."
	)
	_expect(
		controller.controlled_character == player
		and yard_presentation.character == player,
		"Location change must keep control of the same Character."
	)
	_expect(not is_instance_valid(old_presentation), "Old Player Presentation must be released.")
	_expect(yard_presentation.is_in_group(&"player"), "New Presentation must receive control group.")
	_expect(
		player.state.local_position == Vector2(384.0, 80.0),
		"New Presentation must restore the target Location entry position."
	)
	_expect(
		controller.global_position == yard_presentation.global_position,
		"PlayerController Camera owner must follow the new Presentation."
	)
	if camera != null:
		_expect(
			camera.limit_right == 768 and camera.limit_bottom == 576,
			"Camera bounds must update for Tavern Yard."
		)

	var yard_presentations := _get_character_presentations(game.get("current_location") as GridScene)
	_expect(yard_presentations.size() == 1, "Tavern Yard must contain only Player Presentation.")
	_expect(
		yard_presentations.is_empty()
		or yard_presentations[0].character_id != martha_definition.character_id,
		"Martha Presentation must not spawn in Tavern Yard."
	)

	var yard_position := yard_presentation.position
	Input.action_press(&"ui_down")
	await physics_frame
	await physics_frame
	Input.action_release(&"ui_down")
	await physics_frame
	_expect(
		yard_presentation.position.y > yard_position.y,
		"Movement must continue after PlayerController rebinds."
	)
	var no_target_result := controller.request_interaction()
	_expect(
		no_target_result != null and not no_target_result.success,
		"Interaction requests must continue after PlayerController rebinds."
	)
	_expect(
		_last_action_result == no_target_result,
		"PlayerController must continue emitting action_completed after rebind."
	)

	game.queue_free()
	await process_frame
	_finish()


func _test_interactions(
	controller: PlayerController,
	presentation: CharacterPresentation,
	game: Node
) -> void:
	_place_presentation(presentation, Vector2i(12, 7), CharacterState.Facing.RIGHT)
	var sign_result := controller.request_interaction()
	_expect(
		sign_result.success and sign_result.action_id == &"inspect",
		"Sign interaction must continue through the WorldAction chain."
	)
	_expect(_last_action_result == sign_result, "PlayerController must emit Sign ActionResult.")
	_expect(
		game.get_node("HUD/ActionResultLabel").text == sign_result.message,
		"Game HUD must receive PlayerController ActionResult."
	)

	_place_presentation(presentation, Vector2i(13, 6), CharacterState.Facing.RIGHT)
	var chest_result := controller.request_interaction()
	_expect(
		chest_result.success and chest_result.action_id == &"open",
		"Chest interaction must continue through the WorldAction chain."
	)
	_expect(_last_action_result == chest_result, "PlayerController must emit Chest ActionResult.")

	_place_presentation(presentation, Vector2i(19, 3), CharacterState.Facing.RIGHT)
	var bed_result := controller.request_interaction()
	_expect(
		bed_result.success and bed_result.action_id == &"sleep",
		"Bed interaction must continue through the WorldAction chain."
	)
	_expect(_last_action_result == bed_result, "PlayerController must emit Bed ActionResult.")


func _place_presentation(
	presentation: CharacterPresentation,
	cell: Vector2i,
	facing: CharacterState.Facing
) -> void:
	presentation.position = Vector2(cell * GridScene.CELL_SIZE) + Vector2.ONE * 16.0
	presentation.facing = facing
	presentation.sync_state_from_presentation()


func _get_character_presentations(location: GridScene) -> Array[CharacterPresentation]:
	var presentations: Array[CharacterPresentation] = []
	if not is_instance_valid(location):
		return presentations
	for child in location.get_children():
		if child is CharacterPresentation:
			presentations.append(child as CharacterPresentation)
	return presentations


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
		print("V7.3 Character runtime: %d checks passed." % _checks)
		quit(0)
		return

	push_error("V7.3 Character runtime: %d of %d checks failed." % [_failures, _checks])
	quit(1)
