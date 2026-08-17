class_name GridSpace
extends RefCounted

const CELL_SIZE := 32


static func cell_to_local_position(cell: Vector2i, local_offset: Vector2 = Vector2.ZERO) -> Vector2:
	return Vector2(cell * CELL_SIZE) + local_offset


static func local_position_to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(local_position.x / CELL_SIZE),
		floori(local_position.y / CELL_SIZE)
	)


static func grid_size_to_local_size(grid_size: Vector2i) -> Vector2:
	return Vector2(grid_size * CELL_SIZE)
