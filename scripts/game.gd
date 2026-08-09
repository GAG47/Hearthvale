extends Node2D

const INITIAL_SCENE_PATH := "res://scenes/tavern.tscn"
const INITIAL_ENTRY := &"start"

var current_location: GridScene
var transition_in_progress := false

@onready var world_root: Node2D = $WorldRoot
@onready var player: PlayerCharacter = $Player
@onready var location_label: Label = $HUD/TopBar/LocationLabel
@onready var date_label: Label = $HUD/TimePanel/TimeLayout/DateLabel
@onready var weekday_season_label: Label = $HUD/TimePanel/TimeLayout/WeekdaySeasonLabel
@onready var clock_label: Label = $HUD/TimePanel/TimeLayout/ClockLabel
@onready var action_result_label: Label = $HUD/ActionResultLabel
@onready var action_result_timer: Timer = $HUD/ActionResultTimer

var world_time: WorldTimeRuntime


func _ready() -> void:
	player.action_completed.connect(_on_player_action_completed)
	action_result_timer.timeout.connect(_on_action_result_timer_timeout)
	world_time = get_node_or_null("/root/WorldTime") as WorldTimeRuntime
	if world_time == null:
		push_error("WorldTime Autoload is required before loading Game.")
	else:
		world_time.time_changed.connect(_on_world_time_changed)
		_refresh_time_display()
	_replace_location(INITIAL_SCENE_PATH, INITIAL_ENTRY)


func request_location_change(scene_path: String, entry_name: StringName) -> void:
	if transition_in_progress or scene_path.is_empty() or entry_name.is_empty():
		return

	transition_in_progress = true
	player.stop()
	player.set_physics_process(false)
	_perform_location_change.call_deferred(scene_path, entry_name)


func _perform_location_change(scene_path: String, entry_name: StringName) -> void:
	var changed := _replace_location(scene_path, entry_name)
	player.set_physics_process(true)

	if not changed:
		push_error("Could not enter location '%s' at '%s'." % [scene_path, entry_name])

	await get_tree().physics_frame
	transition_in_progress = false


func _replace_location(scene_path: String, entry_name: StringName) -> bool:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return false

	var next_location := packed_scene.instantiate() as GridScene
	if next_location == null:
		return false

	if current_location != null:
		world_root.remove_child(current_location)
		current_location.queue_free()

	current_location = next_location
	world_root.add_child(current_location)

	var entry := current_location.get_node_or_null("EntryPoints/%s" % entry_name) as Marker2D
	if entry == null:
		world_root.remove_child(current_location)
		current_location.queue_free()
		current_location = null
		return false

	player.global_position = entry.global_position
	player.enter_location(current_location)
	player.set_camera_bounds(current_location.get_world_rect())
	location_label.text = current_location.display_name
	action_result_label.text = ""
	return true


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
