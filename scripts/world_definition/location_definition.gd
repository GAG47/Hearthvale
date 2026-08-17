class_name LocationDefinition
extends Definition

var _display_name: String
var _grid_size: Vector2i
var _outgoing_edges: Array[LocationEdgeDefinition]
var _ground_layer: Dictionary[Vector2i, StringName]
var _decoration_layer: Dictionary[Vector2i, StringName]
var _structure_layer: Dictionary[Vector2i, StringName]
var _entries: Array[LocationEntry]
var _exits: Array[LocationExit]

var display_name: String:
	get:
		return _display_name
var grid_size: Vector2i:
	get:
		return _grid_size
var outgoing_edges: Array[LocationEdgeDefinition]:
	get:
		return _outgoing_edges.duplicate()
var ground_layer: Dictionary[Vector2i, StringName]:
	get:
		return _ground_layer.duplicate()
var decoration_layer: Dictionary[Vector2i, StringName]:
	get:
		return _decoration_layer.duplicate()
var structure_layer: Dictionary[Vector2i, StringName]:
	get:
		return _structure_layer.duplicate()
var entries: Array[LocationEntry]:
	get:
		return _entries.duplicate()
var exits: Array[LocationExit]:
	get:
		return _exits.duplicate()


func _init(
	p_definition_id: StringName,
	p_display_name: String,
	p_grid_size: Vector2i,
	p_outgoing_edges: Array[LocationEdgeDefinition] = [],
	p_ground_layer: Dictionary[Vector2i, StringName] = {},
	p_decoration_layer: Dictionary[Vector2i, StringName] = {},
	p_structure_layer: Dictionary[Vector2i, StringName] = {},
	p_entries: Array[LocationEntry] = [],
	p_exits: Array[LocationExit] = []
) -> void:
	super(p_definition_id)
	_display_name = p_display_name
	_grid_size = p_grid_size
	_outgoing_edges = p_outgoing_edges.duplicate()
	_ground_layer = p_ground_layer.duplicate()
	_decoration_layer = p_decoration_layer.duplicate()
	_structure_layer = p_structure_layer.duplicate()
	_entries = p_entries.duplicate()
	_exits = p_exits.duplicate()


func get_definition_type() -> StringName:
	return &"location"
