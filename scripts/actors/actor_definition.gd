@tool
class_name ActorDefinition
extends Resource

const VISUAL_DIRECTIONS: Array[StringName] = [&"up", &"down", &"left", &"right"]

@export var display_name := "":
	set(value):
		display_name = value
		emit_changed()

@export var visual_up: Texture2D:
	set(value):
		visual_up = value
		emit_changed()

@export var visual_down: Texture2D:
	set(value):
		visual_down = value
		emit_changed()

@export var visual_left: Texture2D:
	set(value):
		visual_left = value
		emit_changed()

@export var visual_right: Texture2D:
	set(value):
		visual_right = value
		emit_changed()


func get_visual(direction: StringName) -> Texture2D:
	match direction:
		&"up":
			return visual_up
		&"down":
			return visual_down
		&"left":
			return visual_left
		&"right":
			return visual_right
		_:
			return null


func get_validation_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if display_name.strip_edges().is_empty():
		warnings.append("ActorDefinition display_name must not be empty.")
	for direction in VISUAL_DIRECTIONS:
		if get_visual(direction) == null:
			warnings.append("ActorDefinition visual_%s must reference a Texture2D." % direction)
	return warnings
