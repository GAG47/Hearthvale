extends Node2D

const PLAYER_DEFINITION: ActorDefinition = preload("res://data/actors/player.tres")
const PLAYER_INSTANCE_ID := &"90000000-0000-4000-8000-000000000001"
const PLAYER_INITIAL_LOCATION_KEY := &"tavern"
const PLAYER_INITIAL_LOCAL_POSITION := Vector2(384.0, 256.0)
const PLAYER_INITIAL_FACING := ActorState.Facing.DOWN
const FURNITURE_INSTANCES: Array[Dictionary] = [
	{
		"instance_id": &"5543caf7-2a10-4a40-84de-3a39ffdf670e",
		"definition": preload("res://data/furniture/wooden_chest.tres"),
		"location_key": &"tavern",
		"local_position": Vector2(464.0, 208.0),
	},
	{
		"instance_id": &"1d67bbf9-edc2-4264-a861-8bd3e3e61e15",
		"definition": preload("res://data/furniture/sign.tres"),
		"location_key": &"tavern",
		"local_position": Vector2(432.0, 240.0),
	},
	{
		"instance_id": &"a6ae5842-8c6d-4df2-9b80-a271b5496716",
		"definition": preload("res://data/furniture/simple_bed.tres"),
		"location_key": &"tavern",
		"local_position": Vector2(656.0, 128.0),
	},
]

var current_location: GridScene
var transition_in_progress := false
var controlled_actor_instance_id := &""
var representation_registry := EntityRepresentationRegistry.create_default()
var location_scene_builder := LocationSceneBuilder.new()

@onready var world_root: Node2D = $WorldRoot
@onready var player_controller: PlayerController = $PlayerController
@onready var location_label: Label = $HUD/TopBar/LocationLabel
@onready var date_label: Label = $HUD/TimePanel/TimeLayout/DateLabel
@onready var weekday_season_label: Label = $HUD/TimePanel/TimeLayout/WeekdaySeasonLabel
@onready var clock_label: Label = $HUD/TimePanel/TimeLayout/ClockLabel
@onready var action_result_label: Label = $HUD/ActionResultLabel
@onready var action_result_timer: Timer = $HUD/ActionResultTimer

var world_time: WorldTimeRuntime
var world_definition: WorldDefinitionRuntime
var world_state: WorldStateRuntime
var entity_registry: EntityRegistryRuntime


func _ready() -> void:
	action_result_timer.timeout.connect(_on_action_result_timer_timeout)
	player_controller.action_completed.connect(_on_player_action_completed)

	world_time = get_node_or_null("/root/WorldTime") as WorldTimeRuntime
	if world_time == null:
		push_error("WorldTime Autoload is required before loading Game.")
	else:
		world_time.time_changed.connect(_on_world_time_changed)
		_refresh_time_display()

	world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	if world_definition == null:
		push_error("WorldDefinition Autoload is required before loading Game.")
		return
	world_state = get_node_or_null("/root/WorldState") as WorldStateRuntime
	if world_state == null:
		push_error("WorldState Autoload is required before loading Game.")
		return
	entity_registry = get_node_or_null("/root/EntityRegistry") as EntityRegistryRuntime
	if entity_registry == null:
		push_error("EntityRegistry Autoload is required before loading Game.")
		return
	if not _initialize_furniture_entities():
		return
	var controlled_actor := _initialize_player_actor()
	if controlled_actor == null:
		return
	_replace_location(controlled_actor.current_location_id)


func request_location_change(edge_key: StringName) -> void:
	if (
		transition_in_progress
		or current_location == null
		or not is_instance_valid(player_controller.controlled_representation)
		or edge_key.is_empty()
	):
		return
	var from_location_id := current_location.location_id
	var edge := world_definition.get_edge(from_location_id, edge_key)
	if edge == null:
		return

	transition_in_progress = true
	player_controller.stop()
	player_controller.set_physics_process(false)
	_perform_location_change.call_deferred(from_location_id, edge)


func _initialize_player_actor() -> Actor:
	if PLAYER_DEFINITION == null:
		push_error("Game requires the Player ActorDefinition Resource.")
		return null
	var initial_location_id := world_definition.get_project_location_id(PLAYER_INITIAL_LOCATION_KEY)

	var state := ActorState.new(
		PLAYER_INSTANCE_ID,
		initial_location_id,
		PLAYER_INITIAL_LOCAL_POSITION,
		PLAYER_INITIAL_FACING
	)
	if not world_state.register_entity_state(state):
		push_error(
			"Game could not register the Player ActorState for instance_id '%s'."
			% state.instance_id
		)
		return null

	var actor := Actor.new(PLAYER_DEFINITION, state)
	if not entity_registry.register_entity(actor):
		push_error(
			"Game could not register the Player Actor for instance_id '%s'."
			% state.instance_id
		)
		return null

	controlled_actor_instance_id = state.instance_id
	return actor


func _initialize_furniture_entities() -> bool:
	for instance_data in FURNITURE_INSTANCES:
		var definition := instance_data["definition"] as FurnitureDefinition
		if definition == null:
			push_error("Game requires every Furniture Definition Resource.")
			return false
		var location_id := world_definition.get_project_location_id(instance_data["location_key"])
		var state := FurnitureState.new(
			instance_data["instance_id"],
			location_id,
			instance_data["local_position"]
		)
		if not world_state.register_entity_state(state):
			push_error("Game could not register FurnitureState '%s'." % state.instance_id)
			return false
		var furniture := Furniture.new(definition, state)
		if not entity_registry.register_entity(furniture):
			push_error("Game could not register Furniture '%s'." % state.instance_id)
			return false
	return true


func _perform_location_change(
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> void:
	var movement := get_node_or_null("/root/LogicalMovement") as LogicalMovementRuntime
	while (
		movement != null
		and player_controller.controlled_actor != null
		and movement.is_participant(player_controller.controlled_actor)
	):
		await get_tree().physics_frame
	var changed := _replace_location(edge.target_location_id, from_location_id, edge)
	if is_instance_valid(player_controller.controlled_representation):
		player_controller.set_physics_process(true)

	if not changed:
		action_result_label.text = "此路不通。"
		push_error(
			"Could not follow Location edge '%s/%s' to location_id '%s' at target_entry_id '%s'."
			% [from_location_id, edge.edge_key, edge.target_location_id, edge.target_entry_id]
		)

	await get_tree().physics_frame
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
	var location := world_definition.get_location(location_id)
	if location == null:
		return {}

	var entry: LocationEntry
	if edge != null:
		entry = world_definition.get_target_entry(location, from_location_id, edge)
	if edge != null and entry == null:
		return {}

	var moving_actor := player_controller.controlled_actor
	if moving_actor == null and entity_registry.has_entity(controlled_actor_instance_id):
		moving_actor = entity_registry.get_entity(controlled_actor_instance_id) as Actor
	if moving_actor == null:
		push_error("Location '%s' cannot prepare without the controlled Actor." % location_id)
		return {}
	var spawn_position := moving_actor.local_position
	if entry != null:
		var arrival := location.select_arrival_cell(entry, moving_actor)
		if arrival.is_empty():
			push_error(
				"Location Entry '%s/%s' has no currently available arrival Cell."
				% [location_id, entry.entry_id]
			)
			return {}
		spawn_position = GridSpace.cell_to_local_position(arrival["cell"])
	var spawn_facing := entry.facing if entry != null else moving_actor.facing
	var prepared_scene := location_scene_builder.prepare_scene(
		location,
		representation_registry,
		moving_actor,
		spawn_position
	)
	if prepared_scene.is_empty():
		return {}
	var next_location: GridScene = prepared_scene["scene"]
	if not next_location.prepare_activation(world_state, location):
		next_location.free()
		return {}
	var representations: Dictionary = prepared_scene["representations"]
	var prepared_player_representation := representations.get(controlled_actor_instance_id) as Node

	if prepared_player_representation == null:
		push_error(
			"Location '%s' could not prepare the controlled Representation."
			% location_id
		)
		next_location.free()
		return {}
	if not player_controller.can_take_control(moving_actor, prepared_player_representation):
		next_location.free()
		return {}

	return {
		"definition": location.definition,
		"location_runtime": location,
		"location": next_location,
		"moving_actor": moving_actor,
		"spawn_position": spawn_position,
		"spawn_facing": spawn_facing,
		"player_representation": prepared_player_representation,
	}


func _commit_location_change(prepared_change: Dictionary) -> void:
	var definition: LocationDefinition = prepared_change["definition"]
	var next_location: GridScene = prepared_change["location"]
	var moving_actor: Actor = prepared_change["moving_actor"]
	var spawn_position: Vector2 = prepared_change["spawn_position"]
	var spawn_facing: ActorState.Facing = prepared_change["spawn_facing"]
	var next_player_representation: Node = prepared_change["player_representation"]
	var previous_location := current_location

	player_controller.finish_controlled_location_departure()
	moving_actor.state.current_location_id = next_location.location_id
	moving_actor.state.local_position = spawn_position
	(moving_actor.state as ActorState).facing = spawn_facing
	if next_player_representation is ActorRepresentation:
		(next_player_representation as ActorRepresentation).facing = spawn_facing

	world_root.add_child(next_location)
	player_controller.activate_prepared_control(moving_actor, next_player_representation)
	current_location = next_location
	player_controller.set_camera_bounds(current_location.get_world_rect())
	location_label.text = definition.display_name
	action_result_label.text = ""

	if is_instance_valid(previous_location):
		world_root.remove_child(previous_location)
		previous_location.queue_free()


func _on_player_action_completed(result: ActionResult) -> void:
	action_result_label.text = result.message
	action_result_label.modulate = Color("#f3dfad") if result.success else Color("#f1a38f")
	action_result_timer.start()


func _on_action_result_timer_timeout() -> void:
	action_result_label.text = ""


func _on_world_time_changed(_previous_total_minutes: int, _current_total_minutes: int) -> void:
	_refresh_time_display()


func _refresh_time_display() -> void:
	if world_time == null:
		return
	date_label.text = "Year %d · Month %d · Day %d" % [
		world_time.get_year(),
		world_time.get_month(),
		world_time.get_day(),
	]
	weekday_season_label.text = "%s · %s" % [
		world_time.get_weekday_name(),
		world_time.get_season_name(),
	]
	clock_label.text = "%02d:%02d" % [world_time.get_hour(), world_time.get_minute()]
