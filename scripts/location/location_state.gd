class_name LocationState
extends RefCounted

var instance_id: StringName

# Sparse differences from LocationDefinition. Unchanged world data is never copied here.
var ground_overrides: Dictionary[Vector2i, GroundTileDefinition] = {}
var decoration_overrides: Dictionary[Vector2i, DecorationTileDefinition] = {}
var structure_overrides: Dictionary[Vector2i, StructureTileDefinition] = {}
var removed_edge_ids: Dictionary[StringName, bool] = {}
var disabled_edge_ids: Dictionary[StringName, bool] = {}
var added_edges: Array[LocationEdgeDefinition] = []

var location_id: StringName:
	get:
		return instance_id


func _init(p_instance_id: StringName) -> void:
	instance_id = p_instance_id
