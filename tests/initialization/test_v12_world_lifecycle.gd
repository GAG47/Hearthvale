extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const NEW_GAME_SETUP: NewGameSetup = preload("res://data/world/new_game_setup.tres")
const PLAYER_ID := &"90000000-0000-4000-8000-000000000001"
const TAVERN_ID := &"50000000-0000-4000-8000-000000000001"

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_new_game_setup_and_specs()
	_test_explicit_runtime_objects()

	var game := MAIN_SCENE.instantiate() as Game
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_physics_process(false)
	_test_initial_running_world(game)
	_test_player_intent_phase(game)
	_test_prepare_failure_is_safe(game)
	_test_exit_pending_transition(game)
	_test_end_and_reinitialize(game)
	_test_late_initialization_failure_teardown(game)
	_test_source_boundaries()

	game.end_world()
	game.queue_free()
	await process_frame
	_finish()


func _test_new_game_setup_and_specs() -> void:
	_expect(NEW_GAME_SETUP != null and NEW_GAME_SETUP.validate(), "Project NewGameSetup must validate.")
	_expect(NEW_GAME_SETUP.location_specs.size() == 3, "NewGameSetup must contain three Location specs.")
	_expect(NEW_GAME_SETUP.entity_specs.size() == 4, "NewGameSetup must use one unified Entity spec array.")
	_expect(
		NEW_GAME_SETUP.entity_specs.has(NEW_GAME_SETUP.controlled_actor_spec),
		"controlled_actor_spec must directly reference an Actor spec in entity_specs."
	)
	var actor_spec := NEW_GAME_SETUP.controlled_actor_spec
	var actor_state := actor_spec.create_initial_state()
	var actor := actor_spec.create_entity(actor_state)
	_expect(actor_state is ActorState and actor is Actor, "Actor spec must polymorphically create ActorState and Actor.")
	var furniture_spec: NewGameFurnitureSpec
	for spec in NEW_GAME_SETUP.entity_specs:
		if spec is NewGameFurnitureSpec:
			furniture_spec = spec
			break
	var furniture_state := furniture_spec.create_initial_state() if furniture_spec != null else null
	var furniture := furniture_spec.create_entity(furniture_state) if furniture_spec != null else null
	_expect(
		furniture_state is FurnitureState and furniture is Furniture,
		"Furniture spec must polymorphically create FurnitureState and Furniture."
	)

	var duplicate_setup := NewGameSetup.new()
	duplicate_setup.initial_total_minutes = NEW_GAME_SETUP.initial_total_minutes
	duplicate_setup.location_specs = [
		NEW_GAME_SETUP.location_specs[0],
		NEW_GAME_SETUP.location_specs[0],
	]
	duplicate_setup.entity_specs = NEW_GAME_SETUP.entity_specs.duplicate()
	duplicate_setup.controlled_actor_spec = NEW_GAME_SETUP.controlled_actor_spec
	_expect(not duplicate_setup.validate(), "NewGameSetup must reject duplicate Location instance IDs.")


func _test_explicit_runtime_objects() -> void:
	var state_registry := StateRegistry.new()
	var entity_registry := EntityRegistry.new()
	var location_registry := LocationRegistry.new()
	var time_state := GameTimeState.new(100)
	_expect(state_registry.register_game_time_state(time_state), "StateRegistry must register explicit GameTimeState.")
	var clock := GameClock.new(time_state)
	clock.advance(0.5)
	_expect(time_state.total_minutes == 100, "GameClock must not advance before a full simulation minute.")
	clock.advance(0.5)
	_expect(time_state.total_minutes == 101, "GameClock.advance must consume simulation delta explicitly.")
	var movement := LogicalMovement.new(location_registry, entity_registry)
	_expect(movement.has_dependencies(), "LogicalMovement must receive both registries explicitly.")

	var location_state := LocationState.new(TAVERN_ID)
	var actor_state := ActorState.new(
		&"f1000000-0000-4000-8000-000000000001",
		TAVERN_ID,
		Vector2i.ZERO
	)
	state_registry.register_location_state(location_state)
	state_registry.register_entity_state(actor_state)
	state_registry.clear()
	entity_registry.clear()
	location_registry.clear()
	_expect(
		state_registry.get_game_time_state() == null
		and state_registry.get_location_states().is_empty()
		and state_registry.get_entity_states().is_empty(),
		"StateRegistry.clear must release every State index."
	)
	_expect(entity_registry.get_entities().is_empty(), "EntityRegistry.clear must release its Entity index.")
	_expect(location_registry.get_all().is_empty(), "LocationRegistry.clear must release its Location index.")


func _test_initial_running_world(game: Game) -> void:
	_expect(game.lifecycle == Game.Lifecycle.RUNNING, "Main Game must commit its initial World before RUNNING.")
	var running_state_registry := game.state_registry
	_expect(
		not game.initialize_world(NEW_GAME_SETUP)
		and game.lifecycle == Game.Lifecycle.RUNNING
		and game.state_registry == running_state_registry,
		"initialize_world must reject RUNNING without replacing the active World."
	)
	_expect(game.current_location != null and game.current_location.location_id == TAVERN_ID, "Player must start in Tavern.")
	var player := game.entity_registry.get_entity(PLAYER_ID) as Actor
	_expect(
		player != null
		and player.current_cell == Vector2i(12, 8)
		and player.facing == ActorState.Facing.DOWN,
		"Controlled Actor initial Cell and facing must be preserved."
	)
	_expect(
		game.state_registry.get_entity_states().size() == game.entity_registry.get_entities().size(),
		"Every runtime Entity must reuse an already registered authoritative State."
	)
	_expect(
		game.player_controller.controlled_actor == player
		and is_instance_valid(game.player_controller.controlled_representation),
		"PlayerController must bind the ordinary controlled Actor and its Representation."
	)


func _test_player_intent_phase(game: Game) -> void:
	var player := game.player_controller.controlled_actor
	game.logical_movement.cancel_all()
	Input.action_press(&"ui_right")
	_expect(
		game.logical_movement.get_direction_intent(player) == Vector2i.ZERO,
		"Held input alone must not enter the World while Game fixed tick is stopped."
	)
	game.call("_physics_process", 0.0)
	_expect(
		game.logical_movement.get_direction_intent(player) == Vector2i.RIGHT,
		"Game Player Intent Phase must translate held input into Movement intent."
	)
	Input.action_release(&"ui_right")
	game.call("_physics_process", 0.0)
	_expect(
		game.logical_movement.get_direction_intent(player) == Vector2i.ZERO,
		"A later Game fixed tick must consume released movement state."
	)
	game.logical_movement.cancel_all()


func _test_prepare_failure_is_safe(game: Game) -> void:
	var old_location := game.current_location
	var player := game.player_controller.controlled_actor
	var old_location_id := player.current_location_id
	var old_cell := player.current_cell
	var edge := game.location_registry.get_edge(TAVERN_ID, &"back_door")
	var default_representation_registry := game.representation_registry
	game.representation_registry = EntityRepresentationRegistry.new()
	var changed: bool = game.call(
		"_replace_location",
		edge.target_location_id,
		TAVERN_ID,
		edge
	) == true
	game.representation_registry = default_representation_registry
	_expect(not changed, "Location prepare must fail without a matching Representation Factory.")
	_expect(
		game.current_location == old_location
		and player.current_location_id == old_location_id
		and player.current_cell == old_cell,
		"Location prepare failure must preserve the current committed World."
	)


func _test_exit_pending_transition(game: Game) -> void:
	var player := game.player_controller.controlled_actor
	player.state.local_cell = Vector2i(11, 1)
	game.logical_movement.cancel_all()
	_expect(
		game.logical_movement.set_direction_intent(player, Vector2i.UP),
		"Exit test direction intent must be accepted."
	)
	game.logical_movement.advance(0.0)
	game.logical_movement.advance(player.definition.move_step_duration)
	_expect(player.current_cell == Vector2i(11, 0), "Movement must commit the Exit Cell first.")
	_expect(
		game.has_pending_location_transition()
		and game.current_location.location_id == TAVERN_ID,
		"step_completed callback must record, but not commit, the Location transition."
	)
	_expect(
		game.logical_movement.get_direction_intent(player) == Vector2i.ZERO
		and not game.logical_movement.is_participant(player),
		"Exit callback must prevent a held direction from creating another request in the same advance."
	)
	game.call("_process_pending_location_transition")
	_expect(
		game.current_location.location_id != TAVERN_ID
		and player.current_location_id == game.current_location.location_id,
		"Pending transition phase must commit only after LogicalMovement.advance returns."
	)


func _test_end_and_reinitialize(game: Game) -> void:
	var old_state_registry := game.state_registry
	var old_entity_registry := game.entity_registry
	var old_location_registry := game.location_registry
	var old_movement := game.logical_movement
	var old_clock := game.game_clock
	var old_player := game.player_controller.controlled_actor
	game.player_controller.queue_interaction_request()
	game.end_world()
	_expect(game.lifecycle == Game.Lifecycle.EMPTY, "end_world must finish in EMPTY.")
	_expect(
		game.current_location == null
		and game.state_registry == null
		and game.entity_registry == null
		and game.location_registry == null
		and game.logical_movement == null
		and game.game_clock == null,
		"end_world must release every current World reference."
	)
	_expect(
		old_state_registry.get_entity_states().is_empty()
		and old_entity_registry.get_entities().is_empty()
		and old_location_registry.get_all().is_empty(),
		"end_world must clear all previous World indexes."
	)
	_expect(
		old_movement.get_direction_intent(old_player) == Vector2i.ZERO
		and game.player_controller.controlled_actor == null
		and not game.player_controller.has_pending_interaction_request(),
		"end_world must clear Movement and PlayerController binding/intent."
	)
	_expect(
		not old_movement.step_completed.is_connected(game._on_logical_movement_step_completed)
		and not old_clock.time_changed.is_connected(game._on_game_time_changed),
		"end_world must disconnect previous World signals."
	)
	_expect(game.initialize_world(NEW_GAME_SETUP), "A Game returned to EMPTY must initialize again.")
	game.set_physics_process(false)
	_expect(
		game.lifecycle == Game.Lifecycle.RUNNING
		and game.state_registry != old_state_registry
		and game.entity_registry != old_entity_registry
		and game.location_registry != old_location_registry,
		"Second initialization must create an independent World runtime."
	)


func _test_late_initialization_failure_teardown(game: Game) -> void:
	game.end_world()
	game.representation_registry = EntityRepresentationRegistry.new()
	_expect(
		not game.initialize_world(NEW_GAME_SETUP),
		"A Representation prepare failure must abort initialization."
	)
	_expect(
		game.lifecycle == Game.Lifecycle.EMPTY
		and game.current_location == null
		and game.state_registry == null
		and game.entity_registry == null
		and game.location_registry == null
		and game.logical_movement == null
		and game.game_clock == null
		and game.player_controller.controlled_actor == null,
		"Late initialization failure must use full end_world teardown."
	)
	game.representation_registry = EntityRepresentationRegistry.create_default()
	_expect(game.initialize_world(NEW_GAME_SETUP), "Game must initialize after a failed initialization teardown.")
	game.set_physics_process(false)


func _test_source_boundaries() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	for autoload_name in [
		"LocationRegistry",
		"StateRegistry",
		"EntityRegistry",
		"LogicalMovement",
		"GameClock",
	]:
		_expect(
			not project_source.contains('%s="*res://' % autoload_name),
			"%s must not remain an Autoload." % autoload_name
		)
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_expect(
		not game_source.contains("call_deferred")
		and not game_source.contains("await get_tree().physics_frame"),
		"Location transition must not retain deferred or physics-frame waits."
	)
	_expect(
		game_source.find("player_controller.consume_world_intent")
		< game_source.find("game_clock.advance(delta)")
		and game_source.find("game_clock.advance(delta)")
		< game_source.find("logical_movement.advance(delta)"),
		"Game source must expose the fixed phase order directly."
	)
	var registry_source := FileAccess.get_file_as_string(
		"res://scripts/location/location_registry.gd"
	)
	_expect(
		not registry_source.contains("NewGameSetup")
		and not registry_source.contains("NewGameLocationSpec")
		and not registry_source.contains("preload"),
		"LocationRegistry must not read or orchestrate New Game data."
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("Test failure: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("V12 World Lifecycle: %d checks passed." % _checks)
		quit(0)
		return
	push_error("V12 World Lifecycle: %d of %d checks failed." % [_failures, _checks])
	quit(1)
