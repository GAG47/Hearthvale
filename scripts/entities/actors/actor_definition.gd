@tool
class_name ActorDefinition
extends Resource

const VISUAL_DIRECTIONS: Array[StringName] = [&"up", &"down", &"left", &"right"]

@export var display_name := ""
@export var visual_up: Texture2D
@export var visual_down: Texture2D
@export var visual_left: Texture2D
@export var visual_right: Texture2D
@export var move_speed := 140.0
@export var use_slots: Array[UseSlot] = []


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
