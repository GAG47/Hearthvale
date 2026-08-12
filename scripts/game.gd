extends Node2D

const PLAYER_DEFINITION_PATH := "res://data/characters/player.json"
const PLAYER_INITIAL_LOCATION_ID := &"tavern"
const PLAYER_INITIAL_LOCAL_POSITION := Vector2(384.0, 256.0)
const PLAYER_INITIAL_FACING := CharacterState.Facing.DOWN
const CHARACTER_PRESENTATION_SCENE := preload(
	"res://scenes/characters/character_presentation.tscn"
)

var current_location: GridScene
var transition_in_progress := false
var controlled_character_id := &""

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
var character_registry: CharacterRegistryRuntime


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
	character_registry = get_node_or_null("/root/CharacterRegistry") as CharacterRegistryRuntime
	if character_registry == null:
		push_error("CharacterRegistry Autoload is required before loading Game.")
		return

	var controlled_character := _initialize_player_character()
	if controlled_character == null:
		return
	_replace_location(controlled_character.state.current_location_id)


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


func _initialize_player_character() -> Character:
	var definition := CharacterDefinitionLoader.load_from_file(PLAYER_DEFINITION_PATH)
	if definition == null:
		push_error("Game could not load the Player CharacterDefinition.")
		return null

	var state := CharacterState.new(
		definition.character_id,
		PLAYER_INITIAL_LOCATION_ID,
		PLAYER_INITIAL_LOCAL_POSITION,
		PLAYER_INITIAL_FACING
	)
	if not world_state.register_character_state(state):
		push_error(
			"Game could not register the Player CharacterState for character_id '%s'."
			% definition.character_id
		)
		return null

	var character := Character.new(definition, state)
	if not character_registry.register_character(character):
		push_error(
			"Game could not register the Player Character for character_id '%s'."
			% definition.character_id
		)
		return null

	controlled_character_id = definition.character_id
	return character


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
	var definition := world_definition.get_location(location_id)
	if definition == null:
		return false
	var scene_path := world_definition.get_scene_path(location_id)
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error(
			"Location '%s' scene_path '%s' could not be loaded as a PackedScene."
			% [location_id, scene_path]
		)
		return false

	var next_location := packed_scene.instantiate() as GridScene
	if next_location == null:
		push_error(
			"Location '%s' scene_path '%s' did not instantiate as GridScene."
			% [location_id, scene_path]
		)
		return false
	if not world_definition.validate_loaded_location(next_location, location_id):
		next_location.free()
		return false

	var entry: LocationEntry
	if edge != null:
		entry = world_definition.get_target_entry(next_location, from_location_id, edge)
	if edge != null and entry == null:
		next_location.free()
		return false

	var moving_character := player_controller.controlled_character
	if current_location != null:
		player_controller.release_controlled_presentation()
		world_root.remove_child(current_location)
		current_location.queue_free()

	if edge != null and moving_character != null:
		moving_character.state.current_location_id = location_id
		moving_character.state.local_position = entry.position

	current_location = next_location
	world_root.add_child(current_location)
	if not current_location.world_identity_registered:
		world_root.remove_child(current_location)
		current_location.queue_free()
		current_location = null
		return false

	if not _spawn_character_presentations():
		return false
	if not is_instance_valid(player_controller.controlled_presentation):
		push_error(
			"Location '%s' loaded without the controlled CharacterPresentation."
			% location_id
		)
		return false

	player_controller.set_camera_bounds(current_location.get_world_rect())
	location_label.text = definition.display_name
	action_result_label.text = ""
	return true


func _spawn_character_presentations() -> bool:
	var valid := true
	for world_character in character_registry.get_characters_in_location(current_location.location_id):
		var presentation := CHARACTER_PRESENTATION_SCENE.instantiate() as CharacterPresentation
		if presentation == null:
			push_error(
				"The shared CharacterPresentation Scene did not instantiate as CharacterPresentation."
			)
			valid = false
			continue
		if not presentation.bind_character(world_character, current_location):
			presentation.free()
			valid = false
			continue

		presentation.name = "Character_%s" % String(world_character.character_id).substr(0, 8)
		current_location.add_child(presentation)
		if world_character.character_id == controlled_character_id:
			if is_instance_valid(player_controller.controlled_presentation):
				push_error(
					"Location '%s' contains more than one controlled CharacterPresentation."
					% current_location.location_id
				)
				valid = false
			elif not player_controller.take_control(world_character, presentation):
				valid = false
	return valid


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
