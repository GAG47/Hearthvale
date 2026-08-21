@tool
class_name LocationDefinition
extends Resource

@export var display_name := ""
@export var grid_size := Vector2i.ZERO
@export var outgoing_edges: Array[LocationEdgeDefinition] = []
@export var ground_layer: Dictionary[Vector2i, GroundTileDefinition] = {}
@export var decoration_layer: Dictionary[Vector2i, DecorationTileDefinition] = {}
@export var structure_layer: Dictionary[Vector2i, StructureTileDefinition] = {}
@export var entries: Array[LocationEntry] = []
@export var exits: Array[LocationExit] = []


func validate(require_complete_ground := false) -> bool:
	var valid := true
	var definition_name := resource_path
	if definition_name.is_empty():
		definition_name = display_name
	if display_name.strip_edges().is_empty() or grid_size.x <= 0 or grid_size.y <= 0:
		push_error("LocationDefinition '%s' has an invalid name or grid size." % definition_name)
		return false
	if require_complete_ground and ground_layer.size() != grid_size.x * grid_size.y:
		push_error("LocationDefinition '%s' Ground Layer does not cover its complete grid." % definition_name)
		valid = false
	for cell in ground_layer:
		if not _cell_in_grid(cell) or ground_layer[cell] == null:
			push_error("Location Ground cell %s has an invalid GroundTileDefinition reference." % cell)
			valid = false
	for cell in decoration_layer:
		if not _cell_in_grid(cell) or decoration_layer[cell] == null:
			push_error("Location Decoration cell %s has an invalid DecorationTileDefinition reference." % cell)
			valid = false
	for cell in structure_layer:
		if not _cell_in_grid(cell) or structure_layer[cell] == null:
			push_error("Location Structure cell %s has an invalid StructureTileDefinition reference." % cell)
			valid = false

	var edge_ids: Dictionary[StringName, bool] = {}
	var edge_keys: Dictionary[StringName, bool] = {}
	for edge in outgoing_edges:
		if (
			edge == null
			or not UuidValidator.is_valid_v4(edge.edge_id)
			or edge.edge_key.is_empty()
			or not UuidValidator.is_valid_v4(edge.target_location_id)
			or edge.target_entry_id.is_empty()
			or edge_ids.has(edge.edge_id)
			or edge_keys.has(edge.edge_key)
		):
			push_error("LocationDefinition '%s' has an invalid or duplicate edge." % definition_name)
			valid = false
			continue
		edge_ids[edge.edge_id] = true
		edge_keys[edge.edge_key] = true

	var entry_ids: Dictionary[StringName, bool] = {}
	for entry in entries:
		if entry == null or entry.entry_id.is_empty() or entry_ids.has(entry.entry_id) or entry.arrival_cells.is_empty():
			push_error("LocationDefinition '%s' has an invalid LocationEntry." % definition_name)
			valid = false
			continue
		for arrival_cell in entry.arrival_cells:
			if not _cell_in_grid(arrival_cell):
				push_error(
					"LocationDefinition '%s' Entry '%s' has an invalid arrival Cell %s."
					% [definition_name, entry.entry_id, arrival_cell]
				)
				valid = false
		entry_ids[entry.entry_id] = true

	var exit_keys: Dictionary[StringName, bool] = {}
	for location_exit in exits:
		if (
			location_exit == null
			or location_exit.edge_key.is_empty()
			or exit_keys.has(location_exit.edge_key)
			or not edge_keys.has(location_exit.edge_key)
			or not _rect_in_grid(location_exit.cell_rect)
		):
			push_error("LocationDefinition '%s' has an invalid LocationExit." % definition_name)
			valid = false
			continue
		exit_keys[location_exit.edge_key] = true
	for edge_key in edge_keys:
		if not exit_keys.has(edge_key):
			push_error("Location edge_key '%s' has no local LocationExit." % edge_key)
			valid = false
	return valid


func has_entry(entry_id: StringName) -> bool:
	for entry in entries:
		if entry != null and entry.entry_id == entry_id:
			return true
	return false


func is_cell_in_grid(cell: Vector2i) -> bool:
	return _cell_in_grid(cell)


func is_cell_terrain_walkable(cell: Vector2i) -> bool:
	if not _cell_in_grid(cell):
		return false
	var ground := ground_layer.get(cell) as GroundTileDefinition
	if ground == null or not ground.walkable:
		return false
	var structure := structure_layer.get(cell) as StructureTileDefinition
	return structure == null or not structure.blocks_movement


func _cell_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func _rect_in_grid(rect: Rect2i) -> bool:
	return (
		rect.size.x > 0
		and rect.size.y > 0
		and _cell_in_grid(rect.position)
		and rect.end.x <= grid_size.x
		and rect.end.y <= grid_size.y
	)
