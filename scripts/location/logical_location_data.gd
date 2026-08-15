class_name LogicalLocationData
extends Resource

const CELL_SIZE := 32
const CURRENT_COMPILER_VERSION := 2

@export var location_id := &""
@export var bounds := Rect2i()
@export var walkability := PackedByteArray()
@export var movement_costs := PackedInt32Array()
@export var entries: Dictionary = {}
@export var exits: Dictionary = {}
@export var source_fingerprint := ""
@export var compiler_version := 0


func contains_cell(cell: Vector2i) -> bool:
	return bounds.has_point(cell)


func is_statically_walkable(cell: Vector2i) -> bool:
	var index := _get_cell_index(cell)
	return index >= 0 and index < walkability.size() and walkability[index] != 0


func get_movement_cost(cell: Vector2i) -> int:
	var index := _get_cell_index(cell)
	if index < 0 or index >= movement_costs.size() or not is_statically_walkable(cell):
		return 0
	return movement_costs[index]


func get_entry(entry_id: StringName) -> Dictionary:
	if not entries.has(entry_id):
		return {}
	var entry_value: Variant = entries[entry_id]
	return (entry_value as Dictionary).duplicate(true) if entry_value is Dictionary else {}


func get_exit(edge_key: StringName) -> Dictionary:
	if not exits.has(edge_key):
		return {}
	var exit_value: Variant = exits[edge_key]
	return (exit_value as Dictionary).duplicate(true) if exit_value is Dictionary else {}


func has_valid_grid_shape() -> bool:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return false
	var expected_size := bounds.size.x * bounds.size.y
	return walkability.size() == expected_size and movement_costs.size() == expected_size


func get_runtime_validation_warnings(expected_location_id := &"") -> PackedStringArray:
	var warnings := PackedStringArray()
	if location_id.is_empty():
		warnings.append("LogicalLocationData location_id must not be empty.")
	elif not expected_location_id.is_empty() and location_id != expected_location_id:
		warnings.append(
			"LogicalLocationData location_id '%s' does not match expected Location '%s'."
			% [location_id, expected_location_id]
		)
	if compiler_version != CURRENT_COMPILER_VERSION:
		warnings.append(
			"LogicalLocationData compiler_version %d does not match current version %d."
			% [compiler_version, CURRENT_COMPILER_VERSION]
		)
	if not has_valid_grid_shape():
		warnings.append("LogicalLocationData grid arrays do not match its positive bounds.")
		return warnings

	for index in range(walkability.size()):
		var walkable := walkability[index]
		var movement_cost := movement_costs[index]
		if walkable != 0 and walkable != 1:
			warnings.append("LogicalLocationData walkability must contain only 0 or 1 values.")
			break
		if (walkable == 1 and movement_cost <= 0) or (walkable == 0 and movement_cost != 0):
			warnings.append(
				"LogicalLocationData movement costs must be positive for walkable Cells and zero for blocked Cells."
			)
			break

	_validate_entries(warnings)
	_validate_exits(warnings)
	return warnings


func _validate_entries(warnings: PackedStringArray) -> void:
	for key: Variant in entries.keys():
		var value: Variant = entries[key]
		if not key is StringName or (key as StringName).is_empty() or not value is Dictionary:
			warnings.append("LogicalLocationData entries must map non-empty StringName IDs to Dictionaries.")
			continue
		var entry: Dictionary = value
		if (
			not entry.has("entry_id")
			or not entry["entry_id"] is StringName
			or entry["entry_id"] != key
			or not entry.has("cell")
			or not entry["cell"] is Vector2i
			or not entry.has("facing")
			or not entry["facing"] is int
			or entry["facing"] < ActorState.Facing.UP
			or entry["facing"] > ActorState.Facing.RIGHT
			or not entry.has("local_position")
			or not entry["local_position"] is Vector2
		):
			warnings.append("LogicalLocationData Entry '%s' has an invalid structure." % key)
			continue
		var cell: Vector2i = entry["cell"]
		if not contains_cell(cell) or not is_statically_walkable(cell):
			warnings.append("LogicalLocationData Entry '%s' must use a walkable Cell." % key)


func _validate_exits(warnings: PackedStringArray) -> void:
	for key: Variant in exits.keys():
		var value: Variant = exits[key]
		if not key is StringName or (key as StringName).is_empty() or not value is Dictionary:
			warnings.append("LogicalLocationData exits must map non-empty StringName keys to Dictionaries.")
			continue
		var location_exit: Dictionary = value
		if (
			not location_exit.has("edge_key")
			or not location_exit["edge_key"] is StringName
			or location_exit["edge_key"] != key
			or not location_exit.has("cell_rect")
			or not location_exit["cell_rect"] is Rect2i
		):
			warnings.append("LogicalLocationData Exit '%s' has an invalid structure." % key)


func _get_cell_index(cell: Vector2i) -> int:
	if not contains_cell(cell):
		return -1
	var relative := cell - bounds.position
	return relative.y * bounds.size.x + relative.x
