class_name LocationEdgeDefinition
extends RefCounted

var _edge_id: StringName
var _edge_key: StringName
var _target_location_id: StringName
var _target_entry_id: StringName

var edge_id: StringName:
	get:
		return _edge_id
var edge_key: StringName:
	get:
		return _edge_key
var target_location_id: StringName:
	get:
		return _target_location_id
var target_entry_id: StringName:
	get:
		return _target_entry_id


func _init(
	p_edge_id: StringName,
	p_edge_key: StringName,
	p_target_location_id: StringName,
	p_target_entry_id: StringName
) -> void:
	_edge_id = p_edge_id
	_edge_key = p_edge_key
	_target_location_id = p_target_location_id
	_target_entry_id = p_target_entry_id


func to_data() -> Dictionary:
	return {
		"edge_id": String(edge_id),
		"edge_key": String(edge_key),
		"target_location_id": String(target_location_id),
		"target_entry_id": String(target_entry_id),
	}
