extends Node2D

const PLAYER_DEFINITION_PATH := "res://data/actors/player.json"
const PLAYER_INITIAL_LOCATION_ID := &"tavern"
const PLAYER_INITIAL_LOCAL_POSITION := Vector2(384.0, 256.0)
const PLAYER_INITIAL_FACING := ActorState.Facing.DOWN
const ACTOR_PRESENTATION_SCENE := preload(
	"res://scenes/actors/actor_presentation.tscn"
)
const FURNITURE_PRESENTATION_SCENE := preload(
	"res://scenes/furniture/furniture_presentation.tscn"
)
const FURNITURE_INSTANCES: Array[Dictionary] = [
	{
		"entity_id": &"5543caf7-2a10-4a40-84de-3a39ffdf670e",
		"definition_path": "res://data/furniture/wooden_chest.json",
		"location_id": &"tavern",
		"local_position": Vector2(464.0, 208.0),
	},
	{
		"entity_id": &"1d67bbf9-edc2-4264-a861-8bd3e3e61e15",
		"definition_path": "res://data/furniture/sign.json",
		"location_id": &"tavern",
		"local_position": Vector2(432.0, 240.0),
	},
	{
		"entity_id": &"a6ae5842-8c6d-4df2-9b80-a271b5496716",
		"definition_path": "res://data/furniture/simple_bed.json",
		"location_id": &"tavern",
		"local_position": Vector2(656.0, 128.0),
	},
]

var current_location: GridScene
var transition_in_progress := false
var controlled_actor_id := &""

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
		or not is_instance_valid(player_controller.controlled_presentation)
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
	var definition := ActorDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	if definition == null:
		push_error("Game could not load the Player ActorDefinition.")
		return null

	var state := ActorState.new(
		definition.entity_id,
		PLAYER_INITIAL_LOCATION_ID,
		PLAYER_INITIAL_LOCAL_POSITION,
		PLAYER_INITIAL_FACING
	)
	if not world_state.register_entity_state(state):
		push_error(
			"Game could not register the Player ActorState for entity_id '%s'."
			% definition.entity_id
		)
		return null

	var actor := Actor.new(definition, state)
	if not entity_registry.register_entity(actor):
		push_error(
			"Game could not register the Player Actor for entity_id '%s'."
			% definition.entity_id
		)
		return null

	controlled_actor_id = definition.entity_id
	return actor


func _initialize_furniture_entities() -> bool:
	for instance_data in FURNITURE_INSTANCES:
		var definition_path: String = instance_data["definition_path"]
		var definition := FurnitureDefinitionLoader.load_from_file(definition_path)
		if definition == null:
			push_error("Game could not load FurnitureDefinition '%s'." % definition_path)
			return false
		var state := FurnitureState.new(
			instance_data["entity_id"],
			instance_data["location_id"],
			instance_data["local_position"]
		)
		if not world_state.register_entity_state(state):
			push_error("Game could not register FurnitureState '%s'." % state.entity_id)
			return false
		var furniture := Furniture.new(definition, state)
		if not entity_registry.register_entity(furniture):
			push_error("Game could not register Furniture '%s'." % state.entity_id)
			return false
	return true


func _perform_location_change(
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> void:
	var changed := _replace_location(edge.to_location, from_location_id, edge)
	if is_instance_valid(player_controller.controlled_presentation):
		player_controller.set_physics_process(true)

	if not changed:
		push_error(
			"Could not follow Location edge '%s/%s' to location_id '%s' at to_entry '%s'."
			% [from_location_id, edge.edge_key, edge.to_location, edge.to_entry]
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
	var definition := world_definition.get_location(location_id)
	if definition == null:
		return {}
	var scene_path := definition.scene_path
	var packed_scene := ResourceLoader.load(scene_path) as PackedScene
	if packed_scene == null:
		push_error(
			"Location '%s' scene_path '%s' could not be loaded as a PackedScene."
			% [location_id, scene_path]
		)
		return {}

	var scene_instance := packed_scene.instantiate()
	var next_location := scene_instance as GridScene
	if next_location == null:
		push_error(
			"Location '%s' scene_path '%s' did not instantiate as GridScene."
			% [location_id, scene_path]
		)
		if is_instance_valid(scene_instance):
			scene_instance.free()
		return {}
	if not next_location.prepare_activation(world_definition, world_state, location_id):
		next_location.free()
		return {}

	var entry: LocationEntry
	if edge != null:
		entry = world_definition.get_target_entry(next_location, from_location_id, edge)
	if edge != null and entry == null:
		next_location.free()
		return {}

	var moving_actor := player_controller.controlled_actor
	if moving_actor == null and entity_registry.has_entity(controlled_actor_id):
		moving_actor = entity_registry.get_entity(controlled_actor_id) as Actor
	if moving_actor == null:
		push_error("Location '%s' cannot prepare without the controlled Actor." % location_id)
		next_location.free()
		return {}
	var spawn_position := entry.position if entry != null else moving_actor.local_position

	var target_entities := entity_registry.get_entities_in_location(location_id)
	if not target_entities.has(moving_actor):
		target_entities.append(moving_actor)
	var prepared_player_presentation: ActorPresentation
	for entity in target_entities:
		if entity is Actor:
			var actor := entity as Actor
			var actor_position := spawn_position if actor == moving_actor else actor.local_position
			var actor_presentation := _prepare_actor_presentation(
				actor,
				next_location,
				actor_position
			)
			if actor_presentation == null:
				next_location.free()
				return {}
			next_location.add_child(actor_presentation)
			if actor.entity_id == controlled_actor_id:
				if prepared_player_presentation != null:
					push_error(
						"Location '%s' prepared more than one controlled ActorPresentation."
						% location_id
					)
					next_location.free()
					return {}
				prepared_player_presentation = actor_presentation
		elif entity is Furniture:
			var furniture_presentation := _prepare_furniture_presentation(
				entity as Furniture,
				next_location
			)
			if furniture_presentation == null:
				next_location.free()
				return {}
			next_location.add_child(furniture_presentation)

	if prepared_player_presentation == null:
		push_error(
			"Location '%s' could not prepare the controlled ActorPresentation."
			% location_id
		)
		next_location.free()
		return {}
	if not player_controller.can_take_control(moving_actor, prepared_player_presentation):
		next_location.free()
		return {}

	return {
		"definition": definition,
		"location": next_location,
		"moving_actor": moving_actor,
		"spawn_position": spawn_position,
		"player_presentation": prepared_player_presentation,
	}


func _commit_location_change(prepared_change: Dictionary) -> void:
	var definition: LocationDefinition = prepared_change["definition"]
	var next_location: GridScene = prepared_change["location"]
	var moving_actor: Actor = prepared_change["moving_actor"]
	var spawn_position: Vector2 = prepared_change["spawn_position"]
	var next_player_presentation: ActorPresentation = prepared_change["player_presentation"]
	var previous_location := current_location
	var previous_player_presentation := player_controller.controlled_presentation

	if is_instance_valid(previous_player_presentation):
		previous_player_presentation.finish_location_departure()
	moving_actor.state.current_location_id = next_location.location_id
	moving_actor.state.local_position = spawn_position

	world_root.add_child(next_location)
	player_controller.activate_prepared_control(moving_actor, next_player_presentation)
	current_location = next_location
	player_controller.set_camera_bounds(current_location.get_world_rect())
	location_label.text = definition.display_name
	action_result_label.text = ""

	if is_instance_valid(previous_location):
		world_root.remove_child(previous_location)
		previous_location.queue_free()


func _prepare_actor_presentation(
	actor: Actor,
	target_location: GridScene,
	target_local_position: Vector2
) -> ActorPresentation:
	var scene_instance := ACTOR_PRESENTATION_SCENE.instantiate()
	var presentation := scene_instance as ActorPresentation
	if presentation == null:
		push_error("The shared ActorPresentation Scene did not instantiate correctly.")
		if is_instance_valid(scene_instance):
			scene_instance.free()
		return null
	if not presentation.prepare_actor(actor, target_location, target_local_position):
		presentation.free()
		return null
	presentation.name = "Actor_%s" % String(actor.entity_id).substr(0, 8)
	return presentation


func _prepare_furniture_presentation(
	furniture: Furniture,
	target_location: GridScene
) -> FurniturePresentation:
	var scene_instance := FURNITURE_PRESENTATION_SCENE.instantiate()
	var presentation := scene_instance as FurniturePresentation
	if presentation == null:
		push_error("The shared FurniturePresentation Scene did not instantiate correctly.")
		if is_instance_valid(scene_instance):
			scene_instance.free()
		return null
	if not presentation.prepare_furniture(furniture, target_location):
		presentation.free()
		return null
	presentation.name = "Furniture_%s" % String(furniture.entity_id).substr(0, 8)
	return presentation


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
