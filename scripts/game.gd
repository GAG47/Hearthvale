extends Node2D

var current_location: GridScene
var transition_in_progress := false
var player: PlayerCharacter

@onready var world_root: Node2D = $WorldRoot
@onready var location_label: Label = $HUD/TopBar/LocationLabel
@onready var date_label: Label = $HUD/TimePanel/TimeLayout/DateLabel
@onready var weekday_season_label: Label = $HUD/TimePanel/TimeLayout/WeekdaySeasonLabel
@onready var clock_label: Label = $HUD/TimePanel/TimeLayout/ClockLabel
@onready var action_result_label: Label = $HUD/ActionResultLabel
@onready var action_result_timer: Timer = $HUD/ActionResultTimer

var world_time: WorldTimeRuntime
var world_definition: WorldDefinitionRuntime
var character_registry: CharacterRegistryRuntime


func _ready() -> void:
	action_result_timer.timeout.connect(_on_action_result_timer_timeout)
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
	character_registry = get_node_or_null("/root/CharacterRegistry") as CharacterRegistryRuntime
	if character_registry == null:
		push_error("CharacterRegistry Autoload is required before loading Game.")
		return
	var controlled_character := character_registry.get_character(
		CharacterRegistryRuntime.PLAYER_CHARACTER_ID
	)
	if controlled_character == null:
		return
	_replace_location(controlled_character.state.current_location_id)


func request_location_change(edge_key: StringName) -> void:
	if (
		transition_in_progress
		or current_location == null
		or not is_instance_valid(player)
		or edge_key.is_empty()
	):
		return
	var from_location_id := current_location.location_id
	var edge := world_definition.get_edge(from_location_id, edge_key)
	if edge == null:
		return

	transition_in_progress = true
	player.stop()
	player.set_physics_process(false)
	_perform_location_change.call_deferred(from_location_id, edge)


func _perform_location_change(
	from_location_id: StringName,
	edge: LocationEdgeDefinition
) -> void:
	var changed := _replace_location(edge.to_location, from_location_id, edge)
	if is_instance_valid(player):
		player.set_physics_process(true)

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

	var moving_character: Character
	if is_instance_valid(player):
		moving_character = player.character

	if current_location != null:
		world_root.remove_child(current_location)
		current_location.queue_free()
		player = null

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
	if not is_instance_valid(player):
		push_error(
			"Location '%s' loaded without the controlled PlayerCharacter presentation."
			% location_id
		)
		return false

	player.set_camera_bounds(current_location.get_world_rect())
	location_label.text = definition.display_name
	action_result_label.text = ""
	return true


func _spawn_character_presentations() -> bool:
	var valid := true
	for world_character in character_registry.get_characters_in_location(current_location.location_id):
		var packed_scene := load(world_character.definition.presentation_ref) as PackedScene
		if packed_scene == null:
			push_error(
				"Character '%s' presentation_ref '%s' could not be loaded."
				% [world_character.character_id, world_character.definition.presentation_ref]
			)
			valid = false
			continue

		var presentation := packed_scene.instantiate() as CharacterPresentation
		if presentation == null:
			push_error(
				"Character '%s' presentation_ref '%s' is not a CharacterPresentation."
				% [world_character.character_id, world_character.definition.presentation_ref]
			)
			valid = false
			continue
		if not presentation.bind_character(world_character, current_location):
			presentation.free()
			valid = false
			continue

		presentation.name = "Character_%s" % String(world_character.character_id).substr(0, 8)
		current_location.add_child(presentation)
		if presentation is PlayerCharacter:
			if is_instance_valid(player):
				push_error(
					"Location '%s' contains more than one PlayerCharacter presentation."
					% current_location.location_id
				)
				valid = false
			else:
				player = presentation as PlayerCharacter
				player.action_completed.connect(_on_player_action_completed)
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
