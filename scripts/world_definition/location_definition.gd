class_name LocationDefinition
extends RefCounted

var location_id: StringName
var display_name: String
var scene_path: String
var logical_data_path: String
var outgoing_edges: Array[LocationEdgeDefinition]


func _init(
	p_location_id: StringName,
	p_display_name: String,
	p_scene_path: String,
	p_outgoing_edges: Array[LocationEdgeDefinition] = [],
	p_logical_data_path := ""
) -> void:
	location_id = p_location_id
	display_name = p_display_name
	scene_path = p_scene_path
	logical_data_path = (
		p_logical_data_path
		if not p_logical_data_path.is_empty()
		else "res://data/locations/%s.tres" % p_location_id
	)
	outgoing_edges = p_outgoing_edges.duplicate()
