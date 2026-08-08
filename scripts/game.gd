extends Node2D

const INITIAL_SCENE_PATH := "res://scenes/tavern.tscn"
const INITIAL_ENTRY := &"start"

var current_location: GridScene
var transition_in_progress := false

@onready var world_root: Node2D = $WorldRoot
@onready var player: PlayerCharacter = $Player
@onready var location_label: Label = $HUD/TopBar/LocationLabel


func _ready() -> void:
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
	player.set_camera_bounds(current_location.get_world_rect())
	location_label.text = current_location.display_name
	return true
