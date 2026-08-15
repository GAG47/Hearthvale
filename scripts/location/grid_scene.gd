class_name GridScene
extends Node2D

const CELL_SIZE := LogicalLocationData.CELL_SIZE

@export var location_id := &""
@export var grid_size := Vector2i(24, 16):
	set(value):
		grid_size = value.max(Vector2i.ONE)

var world_identity_registered := false
var world_state: WorldStateRuntime
var world_definition: WorldDefinitionRuntime
var _activation_prepared := false


func _enter_tree() -> void:
	_remove_entity_placements(self)
	if _activation_prepared:
		world_state.activate_prepared_location(self)
		world_identity_registered = true
		_activation_prepared = false
		return

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


func prepare_activation(
	p_world_definition: WorldDefinitionRuntime,
	p_world_state: WorldStateRuntime,
	requested_location_id: StringName
) -> bool:
	if is_inside_tree():
		push_error("A loaded Location cannot be prepared for activation again.")
		return false
	if p_world_definition == null or p_world_state == null:
		push_error("Location activation requires WorldDefinition and WorldState.")
		return false
	if not p_world_definition.validate_loaded_location(self, requested_location_id):
		return false
	if not p_world_state.can_register_location(self):
		return false

	_remove_entity_placements(self)
	world_definition = p_world_definition
	world_state = p_world_state
	_activation_prepared = true
	return true


func _remove_entity_placements(node: Node) -> void:
	for child in node.get_children():
		if child is EntityPlacement:
			child.free()
			continue
		_remove_entity_placements(child)


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
