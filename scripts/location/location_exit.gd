class_name LocationExit
extends RefCounted

var _edge_key: StringName
var _cell_rect: Rect2i

var edge_key: StringName:
	get:
		return _edge_key
var cell_rect: Rect2i:
	get:
		return _cell_rect


func _init(p_edge_key: StringName, p_cell_rect: Rect2i) -> void:
	_edge_key = p_edge_key
	_cell_rect = p_cell_rect
