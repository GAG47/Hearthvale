@abstract
class_name Entity
extends RefCounted

var state: EntityState

var entity_id: StringName:
	get:
		return state.entity_id if state != null else &""

var current_location_id: StringName:
	get:
		return state.current_location_id if state != null else &""

var local_position: Vector2:
	get:
		return state.local_position if state != null else Vector2.ZERO

var current_cell: Vector2i:
	get:
		return Vector2i(
			floori(local_position.x / GridScene.CELL_SIZE),
			floori(local_position.y / GridScene.CELL_SIZE)
		)


func _init(p_state: EntityState) -> void:
	state = p_state


func get_occupied_grid_cells() -> Array[Vector2i]:
	return [current_cell]
