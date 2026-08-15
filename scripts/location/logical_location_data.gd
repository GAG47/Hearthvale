class_name LogicalLocationData
extends Resource

const CELL_SIZE := 32

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


func _get_cell_index(cell: Vector2i) -> int:
	if not contains_cell(cell):
		return -1
	var relative := cell - bounds.position
	return relative.y * bounds.size.x + relative.x
