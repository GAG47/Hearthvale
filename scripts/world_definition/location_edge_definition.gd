class_name LocationEdgeDefinition
extends RefCounted

var edge_key: StringName
var to_location: StringName
var to_entry: StringName


func _init(p_edge_key: StringName, p_to_location: StringName, p_to_entry: StringName) -> void:
	edge_key = p_edge_key
	to_location = p_to_location
	to_entry = p_to_entry
