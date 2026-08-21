class_name Game
extends Node2D

enum Lifecycle {
	EMPTY,
	INITIALIZING,
	RUNNING,
	ENDING,
}

const DEFAULT_NEW_GAME_SETUP: NewGameSetup = preload(
	"res://data/world/new_game_setup.tres"
)

var lifecycle := Lifecycle.EMPTY
var current_location: LocationScene
var transition_in_progress := false
var controlled_actor_instance_id := &""

var state_registry: StateRegistry
var entity_registry: EntityRegistry
var location_registry: LocationRegistry
var game_clock: GameClock
var logical_movement: LogicalMovement

var representation_registry := EntityRepresentationRegistry.create_default()
var location_scene_builder := LocationSceneBuilder.new()
var _pending_location_transition: Dictionary = {}

@onready var location_scene_root: Node2D = $LocationSceneRoot
@onready var player_controller: PlayerController = $PlayerController
@onready var location_label: Label = $HUD/TopBar/LocationLabel
@onready var date_label: Label = $HUD/TimePanel/TimeLayout/DateLabel
@onready var weekday_season_label: Label = $HUD/TimePanel/TimeLayout/WeekdaySeasonLabel
@onready var clock_label: Label = $HUD/TimePanel/TimeLayout/ClockLabel
@onready var action_result_label: Label = $HUD/ActionResultLabel
@onready var action_result_timer: Timer = $HUD/ActionResultTimer


func _ready() -> void:
	action_result_timer.timeout.connect(_on_action_result_timer_timeout)
	player_controller.action_completed.connect(_on_player_action_completed)
	initialize_world(DEFAULT_NEW_GAME_SETUP)


func _physics_process(delta: float) -> void:
	if lifecycle != Lifecycle.RUNNING:
		return

	# 1. Player Intent Phase.
	player_controller.consume_world_intent(game_clock)
	# 2. World Simulation Clock Phase.
	game_clock.advance(delta)
	# 3. Reserved future world-system phase (no V12 system is added here).
	# 4. Logical Movement Phase.
	logical_movement.advance(delta)
	# 5. Pending Cross-System Transition Phase.
	_process_pending_location_transition()


func initialize_world(new_game_setup: NewGameSetup) -> bool:
	if lifecycle != Lifecycle.EMPTY:
		push_error("Game can only initialize a World from EMPTY lifecycle.")
		return false
	lifecycle = Lifecycle.INITIALIZING

	if new_game_setup == null or not new_game_setup.validate():
		return _abort_world_initialization("Game rejected an invalid NewGameSetup.")

	state_registry = StateRegistry.new()
	entity_registry = EntityRegistry.new()
	location_registry = LocationRegistry.new()

	if not _create_authoritative_states(new_game_setup):
		return _abort_world_initialization("Game could not create all authoritative State.")
	if not _create_locations(new_game_setup):
		return _abort_world_initialization("Game could not create all Locations.")
	if not _create_entities(new_game_setup):
		return _abort_world_initialization("Game could not create all Entities.")
	if not _validate_runtime_relationships(new_game_setup):
		return _abort_world_initialization("Game rejected invalid runtime relationships.")

	game_clock = GameClock.new(state_registry.get_game_time_state())
	logical_movement = LogicalMovement.new(location_registry, entity_registry)
	if not game_clock.is_bound() or not logical_movement.has_dependencies():
		return _abort_world_initialization("Game could not bind World runtime systems.")

	controlled_actor_instance_id = new_game_setup.controlled_actor_spec.instance_id
	var controlled_actor := entity_registry.get_entity(controlled_actor_instance_id) as Actor
	if controlled_actor == null:
		return _abort_world_initialization("Game could not resolve the controlled Actor.")
	if not player_controller.bind_world(
		controlled_actor,
		location_registry,
		logical_movement,
		game_clock
	):
		return _abort_world_initialization("Game could not bind PlayerController to the World.")

	_connect_world_signals()
	var prepared_initial_location := _prepare_location_change(
		controlled_actor.current_location_id,
		&"",
		null
	)
	if prepared_initial_location.is_empty():
		return _abort_world_initialization("Game could not prepare the initial Location Representation.")
	_commit_location_change(prepared_initial_location)
	_refresh_time_display()
	lifecycle = Lifecycle.RUNNING
	return true


func end_world() -> void:
	if lifecycle == Lifecycle.EMPTY or lifecycle == Lifecycle.ENDING:
		return
	lifecycle = Lifecycle.ENDING

	_pending_location_transition.clear()
	transition_in_progress = false
	if player_controller != null:
		player_controller.clear_pending_intent()
	if logical_movement != null:
		logical_movement.cancel_all()
	if player_controller != null:
		player_controller.unbind_world()

	if is_instance_valid(current_location):
		if current_location.get_parent() != null:
			current_location.get_parent().remove_child(current_location)
		current_location.free()
	current_location = null

	_disconnect_world_signals()
	logical_movement = null
	game_clock = null
	if entity_registry != null:
		entity_registry.clear()
	if location_registry != null:
		location_registry.clear()
	if state_registry != null:
		state_registry.clear()
	entity_registry = null
	location_registry = null
	state_registry = null
	controlled_actor_instance_id = &""
	if location_label != null:
		location_label.text = "Hearthvale"
	if action_result_label != null:
		action_result_label.text = ""
	lifecycle = Lifecycle.EMPTY


func request_location_change(edge_key: StringName) -> void:
	if (
		lifecycle != Lifecycle.RUNNING
		or transition_in_progress
		or not _pending_location_transition.is_empty()
		or current_location == null
		or edge_key.is_empty()
	):
		return
	var from_location_id := current_location.location_id
	var edge := location_registry.get_edge(from_location_id, edge_key)
	if edge == null:
		return
	_pending_location_transition = {
		"from_location_id": from_location_id,
		"edge": edge,
	}
	player_controller.stop()
	if player_controller.controlled_actor != null:
		logical_movement.set_direction_intent(
			player_controller.controlled_actor,
			Vector2i.ZERO
		)


func has_pending_location_transition() -> bool:
	return not _pending_location_transition.is_empty()


func _create_authoritative_states(new_game_setup: NewGameSetup) -> bool:
	var game_time_state := GameTimeState.new(new_game_setup.initial_total_minutes)
	if not state_registry.register_game_time_state(game_time_state):
		return false
	for spec in new_game_setup.location_specs:
		if not state_registry.register_location_state(LocationState.new(spec.instance_id)):
			return false
	for spec in new_game_setup.entity_specs:
		var state := spec.create_initial_state()
		if state == null or not state_registry.register_entity_state(state):
			return false
	return true


func _create_locations(new_game_setup: NewGameSetup) -> bool:
	for spec in new_game_setup.location_specs:
		var state := state_registry.get_location_state(spec.instance_id)
		var location := Location.new(spec.definition, state, entity_registry)
		if not location_registry.register(location):
			return false
	return true


func _create_entities(new_game_setup: NewGameSetup) -> bool:
	for spec in new_game_setup.entity_specs:
		var state := state_registry.get_entity_state(spec.instance_id)
		var entity := spec.create_entity(state)
		if entity == null or not entity_registry.register_entity(entity):
			return false
	return true


func _validate_runtime_relationships(new_game_setup: NewGameSetup) -> bool:
	if state_registry.get_location_states().size() != new_game_setup.location_specs.size():
		return false
	if state_registry.get_entity_states().size() != new_game_setup.entity_specs.size():
		return false
	if location_registry.get_all().size() != new_game_setup.location_specs.size():
		return false
	if entity_registry.get_entities().size() != new_game_setup.entity_specs.size():
		return false
	for location in location_registry.get_all():
		if (
			location.state != state_registry.get_location_state(location.instance_id)
			or location.entity_registry != entity_registry
		):
			return false
	for spec in new_game_setup.entity_specs:
		if not entity_registry.has_entity(spec.instance_id):
			return false
		var entity := entity_registry.get_entity(spec.instance_id)
		if (
			entity.state != state_registry.get_entity_state(spec.instance_id)
			or entity.current_location_id != spec.initial_location.instance_id
			or not location_registry.has_location(entity.current_location_id)
		):
			return false
	return true


func _process_pending_location_transition() -> void:
	if _pending_location_transition.is_empty() or lifecycle != Lifecycle.RUNNING:
		return
	var transition := _pending_location_transition
	_pending_location_transition = {}
	transition_in_progress = true
	var from_location_id := transition["from_location_id"] as StringName
	var edge := transition["edge"] as LocationEdgeDefinition
	var changed := _replace_location(edge.target_location_id, from_location_id, edge)
	if not changed:
		action_result_label.text = "此路不通。"
		push_error(
			"Could not follow Location edge '%s/%s' to location_id '%s' at target_entry_id '%s'."
			% [from_location_id, edge.edge_key, edge.target_location_id, edge.target_entry_id]
		)
	transition_in_progress = false


func _replace_location(
	location_id: StringName,
	from_location_id: StringName = &"",
	edge: LocationEdgeDefinition = null
) -> bool:
	var prepared_change := _prepare_location_change(location_id, from_location_id, edge)
	if prepared_change.is_empty():
		return false
	_commit_location_change(prepared_change)
	return true


func _prepare_location_change(
	location_id: StringName,
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> Dictionary:
	var location := location_registry.get_location(location_id) if location_registry != null else null
	if location == null:
		return {}

	var entry: LocationEntry
	if edge != null:
		entry = location_registry.get_target_entry(location, from_location_id, edge)
	if edge != null and entry == null:
		return {}

	var moving_actor := player_controller.controlled_actor
	if moving_actor == null and entity_registry.has_entity(controlled_actor_instance_id):
		moving_actor = entity_registry.get_entity(controlled_actor_instance_id) as Actor
	if moving_actor == null:
		push_error("Location '%s' cannot prepare without the controlled Actor." % location_id)
		return {}
	var spawn_cell := moving_actor.current_cell
	if entry != null:
		var found_arrival := false
		for candidate_cell in entry.arrival_cells:
			if not location.is_cell_statically_walkable(candidate_cell, moving_actor):
				continue
			if logical_movement.is_actor_cell_occupied(
				location.instance_id,
				candidate_cell,
				moving_actor
			):
				continue
			spawn_cell = candidate_cell
			found_arrival = true
			break
		if not found_arrival:
			push_error(
				"Location Entry '%s/%s' has no currently available arrival Cell."
				% [location_id, entry.entry_id]
			)
			return {}
	var spawn_facing := entry.facing if entry != null else moving_actor.facing
	var prepared_scene := location_scene_builder.prepare_scene(
		location,
		representation_registry,
		moving_actor,
		spawn_cell,
		logical_movement
	)
	if prepared_scene.is_empty():
		return {}
	var next_location := prepared_scene["scene"] as LocationScene
	if not next_location.prepare_activation(location):
		next_location.free()
		return {}
	var representations: Dictionary = prepared_scene["representations"]
	var prepared_player_representation := representations.get(controlled_actor_instance_id) as Node

	if prepared_player_representation == null:
		push_error("Location '%s' could not prepare the controlled Representation." % location_id)
		next_location.free()
		return {}
	if not player_controller.can_take_control(moving_actor, prepared_player_representation):
		next_location.free()
		return {}

	return {
		"definition": location.definition,
		"location": next_location,
		"moving_actor": moving_actor,
		"spawn_cell": spawn_cell,
		"spawn_facing": spawn_facing,
		"player_representation": prepared_player_representation,
	}


func _commit_location_change(prepared_change: Dictionary) -> void:
	var definition: LocationDefinition = prepared_change["definition"]
	var next_location: LocationScene = prepared_change["location"]
	var moving_actor: Actor = prepared_change["moving_actor"]
	var spawn_cell: Vector2i = prepared_change["spawn_cell"]
	var spawn_facing: ActorState.Facing = prepared_change["spawn_facing"]
	var next_player_representation: Node = prepared_change["player_representation"]
	var previous_location := current_location

	player_controller.finish_controlled_location_departure()
	moving_actor.state.current_location_id = next_location.location_id
	moving_actor.state.local_cell = spawn_cell
	(moving_actor.state as ActorState).facing = spawn_facing
	(next_player_representation as ActorRepresentation).refresh_visual()

	location_scene_root.add_child(next_location)
	player_controller.activate_prepared_control(moving_actor, next_player_representation)
	current_location = next_location
	player_controller.set_camera_bounds(current_location.get_local_rect())
	location_label.text = definition.display_name
	action_result_label.text = ""

	if is_instance_valid(previous_location):
		location_scene_root.remove_child(previous_location)
		previous_location.free()


func _connect_world_signals() -> void:
	if game_clock != null and not game_clock.time_changed.is_connected(_on_game_time_changed):
		game_clock.time_changed.connect(_on_game_time_changed)
	if logical_movement != null and not logical_movement.step_completed.is_connected(_on_logical_movement_step_completed):
		logical_movement.step_completed.connect(_on_logical_movement_step_completed)


func _disconnect_world_signals() -> void:
	if game_clock != null and game_clock.time_changed.is_connected(_on_game_time_changed):
		game_clock.time_changed.disconnect(_on_game_time_changed)
	if logical_movement != null and logical_movement.step_completed.is_connected(_on_logical_movement_step_completed):
		logical_movement.step_completed.disconnect(_on_logical_movement_step_completed)


func _abort_world_initialization(message: String) -> bool:
	push_error(message)
	end_world()
	return false


func _on_player_action_completed(result: ActionResult) -> void:
	action_result_label.text = result.message
	action_result_label.modulate = Color("#f3dfad") if result.success else Color("#f1a38f")
	action_result_timer.start()


func _on_logical_movement_step_completed(actor: Actor) -> void:
	if (
		lifecycle != Lifecycle.RUNNING
		or actor == null
		or actor != player_controller.controlled_actor
		or current_location == null
		or actor.current_location_id != current_location.location_id
	):
		return
	var location := location_registry.get_location(actor.current_location_id)
	if location == null or current_location.location != location:
		return
	var location_exit := location.get_exit_at(actor.current_cell)
	if location_exit != null:
		request_location_change(location_exit.edge_key)


func _on_action_result_timer_timeout() -> void:
	action_result_label.text = ""


func _on_game_time_changed(_previous_total_minutes: int, _current_total_minutes: int) -> void:
	_refresh_time_display()


func _refresh_time_display() -> void:
	if game_clock == null:
		return
	date_label.text = "Year %d · Month %d · Day %d" % [
		game_clock.get_year(),
		game_clock.get_month(),
		game_clock.get_day(),
	]
	weekday_season_label.text = "%s · %s" % [
		game_clock.get_weekday_name(),
		game_clock.get_season_name(),
	]
	clock_label.text = "%02d:%02d" % [game_clock.get_hour(), game_clock.get_minute()]


func _exit_tree() -> void:
	end_world()
