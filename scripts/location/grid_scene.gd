class_name GridScene
extends Node2D

const CELL_SIZE := 32

@export var location_id := &""
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)

var _furniture_presentations_by_cell: Dictionary = {}
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


func register_furniture_presentation(presentation: FurniturePresentation) -> void:
	if not is_instance_valid(presentation):
		return
	if presentation.current_location != self:
		push_error("GridScene can only register FurniturePresentations bound to this Location.")
		return

	for cell in presentation.get_occupied_grid_cells():
		var presentations: Array[FurniturePresentation]
		if _furniture_presentations_by_cell.has(cell):
			presentations = _furniture_presentations_by_cell[cell]
		else:
			presentations = []
			_furniture_presentations_by_cell[cell] = presentations
		if not presentations.has(presentation):
			presentations.append(presentation)


func unregister_furniture_presentation(presentation: FurniturePresentation) -> void:
	for cell in _furniture_presentations_by_cell.keys():
		var presentations: Array[FurniturePresentation] = _furniture_presentations_by_cell[cell]
		presentations.erase(presentation)
		if presentations.is_empty():
			_furniture_presentations_by_cell.erase(cell)


func get_furniture_presentations_at(cell: Vector2i) -> Array[FurniturePresentation]:
	if not _furniture_presentations_by_cell.has(cell):
		return []
	var presentations: Array[FurniturePresentation] = _furniture_presentations_by_cell[cell]
	return presentations.duplicate()
