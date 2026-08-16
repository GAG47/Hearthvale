class_name LocationState
extends RefCounted

var instance_id: StringName
var definition_id: StringName

# Sparse differences from LocationDefinition. Unchanged world data is never copied here.
var ground_overrides: Dictionary[Vector2i, StringName] = {}
var removed_structure_ids: Dictionary[StringName, bool] = {}
var added_structures: Array[StructurePlacement] = []
var removed_decoration_ids: Dictionary[StringName, bool] = {}
var added_decorations: Array[DecorationPlacement] = []
var removed_edge_ids: Dictionary[StringName, bool] = {}
var disabled_edge_ids: Dictionary[StringName, bool] = {}
var added_edges: Array[LocationEdgeDefinition] = []

var location_id: StringName:
	get:
		return instance_id


func _init(p_instance_id: StringName, p_definition_id: StringName) -> void:
	instance_id = p_instance_id
	definition_id = p_definition_id


func to_data() -> Dictionary:
	var serialized_ground: Array = []
	for cell in ground_overrides:
		serialized_ground.append({
			"cell": [cell.x, cell.y],
			"definition_id": String(ground_overrides[cell]),
		})
	var serialized_structures: Array = []
	for placement in added_structures:
		serialized_structures.append(placement.to_data())
	var serialized_decorations: Array = []
	for placement in added_decorations:
		serialized_decorations.append(placement.to_data())
	var serialized_edges: Array = []
	for edge in added_edges:
		serialized_edges.append(edge.to_data())
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"ground_overrides": serialized_ground,
		"removed_structure_ids": _string_keys(removed_structure_ids),
		"added_structures": serialized_structures,
		"removed_decoration_ids": _string_keys(removed_decoration_ids),
		"added_decorations": serialized_decorations,
		"removed_edge_ids": _string_keys(removed_edge_ids),
		"disabled_edge_ids": _string_keys(disabled_edge_ids),
		"added_edges": serialized_edges,
	}


static func _string_keys(values: Dictionary[StringName, bool]) -> Array[String]:
	var result: Array[String] = []
	for key in values:
		if values[key]:
			result.append(String(key))
	result.sort()
	return result
