class_name LocationState
extends RefCounted

var instance_id: StringName
var definition_id: StringName

# Sparse differences from LocationDefinition. Unchanged world data is never copied here.
var ground_overrides: Dictionary[Vector2i, StringName] = {}
var decoration_overrides: Dictionary[Vector2i, StringName] = {}
var structure_overrides: Dictionary[Vector2i, StringName] = {}
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
	var serialized_edges: Array = []
	for edge in added_edges:
		serialized_edges.append(edge.to_data())
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"ground_overrides": _serialize_layer_overrides(ground_overrides),
		"decoration_overrides": _serialize_layer_overrides(decoration_overrides),
		"structure_overrides": _serialize_layer_overrides(structure_overrides),
		"removed_edge_ids": _string_keys(removed_edge_ids),
		"disabled_edge_ids": _string_keys(disabled_edge_ids),
		"added_edges": serialized_edges,
	}


static func _serialize_layer_overrides(overrides: Dictionary[Vector2i, StringName]) -> Array:
	var serialized: Array = []
	for cell in overrides:
		serialized.append({
			"cell": [cell.x, cell.y],
			"definition_id": String(overrides[cell]),
		})
	return serialized


static func _string_keys(values: Dictionary[StringName, bool]) -> Array[String]:
	var result: Array[String] = []
	for key in values:
		if values[key]:
			result.append(String(key))
	result.sort()
	return result
