class_name GridScene
extends Node2D

const CELL_SIZE := 32

@export var display_name := "Location"
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)

var _world_objects_by_cell: Dictionary = {}


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid_size * CELL_SIZE))


func register_world_object(world_object: WorldObject) -> void:
	if not is_instance_valid(world_object):
		return
	if world_object.location != self:
		push_error("GridScene can only register WorldObjects that belong to this Location.")
		return

	for cell in world_object.get_occupied_grid_cells():
		var objects: Array[WorldObject]
		if _world_objects_by_cell.has(cell):
			objects = _world_objects_by_cell[cell]
		else:
			objects = []
			_world_objects_by_cell[cell] = objects
		if not objects.has(world_object):
			objects.append(world_object)


func unregister_world_object(world_object: WorldObject) -> void:
	for cell in _world_objects_by_cell.keys():
		var objects: Array[WorldObject] = _world_objects_by_cell[cell]
		objects.erase(world_object)
		if objects.is_empty():
			_world_objects_by_cell.erase(cell)


func get_world_objects_at(cell: Vector2i) -> Array[WorldObject]:
	if not _world_objects_by_cell.has(cell):
		return []
	var objects: Array[WorldObject] = _world_objects_by_cell[cell]
	return objects.duplicate()
