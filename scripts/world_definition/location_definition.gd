class_name LocationDefinition
extends RefCounted

var location_id: StringName
var display_name: String
var scene_path: String
var outgoing_edges: Array[LocationEdgeDefinition]


func _init(
	p_location_id: StringName,
	p_display_name: String,
	p_scene_path: String,
	p_outgoing_edges: Array[LocationEdgeDefinition] = []
) -> void:
	location_id = p_location_id
	display_name = p_display_name
	scene_path = p_scene_path
	outgoing_edges = p_outgoing_edges.duplicate()
