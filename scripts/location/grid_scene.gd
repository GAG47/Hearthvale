class_name GridScene
extends Node2D

const CELL_SIZE := 32

@export var location_id := &""
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)

var _world_objects_by_cell: Dictionary = {}
var world_identity_registered := false
var world_state: WorldStateRuntime
var world_definition: WorldDefinitionRuntime


func _enter_tree() -> void:
	world_definition = get_node_or_null("/root/WorldDefinition") as WorldDefinitionRuntime
	if world_definition == null:
		push_error("WorldDefinition Autoload is required before loading a Location.")
		return
	if not world_definition.validate_loaded_location(self, location_id):
		return

	world_state = get_node_or_null("/root/WorldState") as WorldStateRuntime
	if world_state == null:
		push_error("WorldState Autoload is required before loading a Location.")
		return
	world_identity_registered = world_state.register_location(self)


func _exit_tree() -> void:
	if world_identity_registered:
		world_state.unregister_location(self)
		world_identity_registered = false


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(grid_size * CELL_SIZE))


func get_location_entries() -> Array[LocationEntry]:
	var entries: Array[LocationEntry] = []
	var entry_root := get_node_or_null("EntryPoints")
	if entry_root == null:
		return entries
	for child in entry_root.get_children():
		if child is LocationEntry:
			entries.append(child as LocationEntry)
	return entries


func get_location_entry(entry_id: StringName) -> LocationEntry:
	for entry in get_location_entries():
		if entry.entry_id == entry_id:
			return entry
	return null


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
