extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MARTHA_DEFINITION: ActorDefinition = preload("res://data/actors/martha.tres")
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const NPC_INSTANCE_ID := &"e4000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var game := MAIN_SCENE.instantiate() as Game
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_physics_process(false)
	var location_registry := game.location_registry
	var state_registry := game.state_registry
	var entity_registry := game.entity_registry
	var movement := game.logical_movement
	_expect(location_registry != null, "V11.4 tests require LocationRegistry.")
	_expect(state_registry != null, "V11.4 tests require StateRegistry.")
	_expect(entity_registry != null, "V11.4 tests require EntityRegistry.")
	_expect(movement != null, "V11.4 tests require LogicalMovement.")
	if (
		location_registry == null
		or state_registry == null
		or entity_registry == null
		or movement == null
	):
		_finish()
		return

	movement.cancel_all()

	var controller := game.get_node_or_null("PlayerController") as PlayerController
	var player := entity_registry.get_entity(PLAYER_INSTANCE_ID) as Actor
	var initial_scene := game.get("current_location") as LocationScene
	_expect(controller != null and player != null, "Game must initialize its controlled Actor.")
	_expect(initial_scene != null, "Game must initialize its current LocationScene.")
	if controller == null or player == null or initial_scene == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	var initial_location := initial_scene.location
	var initial_location_id := initial_location.instance_id
	var npc_definition := MARTHA_DEFINITION.duplicate(true) as ActorDefinition
	npc_definition.move_step_duration = 0.05
	var npc_state := ActorState.new(
		NPC_INSTANCE_ID,
		initial_location_id,
		Vector2i(12, 1),
		ActorState.Facing.UP
	)
	var npc := Actor.new(npc_definition, npc_state)
	_expect(state_registry.register_entity_state(npc_state), "NPC State must register.")
	_expect(entity_registry.register_entity(npc), "NPC must register.")
	_expect(initial_location.get_exit_at(Vector2i(12, 0)) != null, "NPC target Cell must be an Exit.")
	_expect(movement.request_step(npc, Vector2i.UP), "NPC Exit step must be accepted.")
	movement.advance(0.0)
	movement.advance(npc.definition.move_step_duration)
	await process_frame
	_expect(npc.current_cell == Vector2i(12, 0), "NPC Exit step must commit its target Cell.")
	_expect(
		game.get("current_location") == initial_scene
		and not game.get("transition_in_progress"),
		"A non-controlled Actor completing an Exit step must not change the player Location."
	)

	player.state.local_cell = Vector2i(11, 1)
	var representation := controller.controlled_representation
	if is_instance_valid(representation):
		representation.position = LocationGridSpace.cell_to_center_position(player.current_cell)
	_expect(initial_location.get_exit_at(Vector2i(11, 0)) != null, "Player target Cell must be an Exit.")
	_expect(movement.request_step(player, Vector2i.UP), "Controlled Actor Exit step must be accepted.")
	movement.advance(0.0)
	movement.advance(player.definition.move_step_duration)
	_expect(player.current_cell == Vector2i(11, 0), "Exit signal must follow committed ActorState.local_cell.")
	_expect(game.has_pending_location_transition(), "Exit callback must only record a pending transition.")
	_expect(
		movement.get_direction_intent(player) == Vector2i.ZERO,
		"Exit callback must clear held direction before Movement advance can create another step."
	)
	game.call("_process_pending_location_transition")
	var next_scene := game.get("current_location") as LocationScene
	_expect(
		next_scene != null and next_scene.location_id != initial_location_id,
		"A controlled Actor completing an Exit step must use the existing Location Change flow."
	)
	_expect(
		player.current_location_id == next_scene.location_id,
		"Location Change must commit the controlled Actor to the target Location."
	)

	game.end_world()
	game.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V11.4 Cell Exit Transition: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V11.4 Cell Exit Transition: %d of %d checks failed." % [_failures, _checks])
	quit(1)
