@abstract
class_name Character
extends CharacterBody2D

enum Facing {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

var current_location: GridScene
var facing := Facing.DOWN

var world_position: Vector2:
	get:
		return global_position

var current_cell: Vector2i:
	get:
		if current_location == null:
			return Vector2i.ZERO
		var local_position := current_location.to_local(global_position)
		return Vector2i(
			floori(local_position.x / GridScene.CELL_SIZE),
			floori(local_position.y / GridScene.CELL_SIZE)
		)


func enter_location(location: GridScene) -> void:
	current_location = location


func get_front_cell() -> Vector2i:
	return current_cell + get_facing_cell_offset()


func get_facing_cell_offset() -> Vector2i:
	match facing:
		Facing.UP:
			return Vector2i.UP
		Facing.LEFT:
			return Vector2i.LEFT
		Facing.RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN


func get_facing_vector() -> Vector2:
	return Vector2(get_facing_cell_offset())
