class_name LocationDefinition
extends Definition

var _display_name: String
var _grid_size: Vector2i
var _outgoing_edges: Array[LocationEdgeDefinition]
var _ground_layer: Dictionary[Vector2i, StringName]
var _decoration_placements: Array[DecorationPlacement]
var _structure_placements: Array[StructurePlacement]
var _anchors: Array[LocationAnchor]

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
var decoration_placements: Array[DecorationPlacement]:
	get:
		return _decoration_placements.duplicate()
var structure_placements: Array[StructurePlacement]:
	get:
		return _structure_placements.duplicate()
var anchors: Array[LocationAnchor]:
	get:
		return _anchors.duplicate()


func _init(
	p_definition_id: StringName,
	p_display_name: String,
	p_grid_size: Vector2i,
	p_outgoing_edges: Array[LocationEdgeDefinition] = [],
	p_ground_layer: Dictionary[Vector2i, StringName] = {},
	p_decoration_placements: Array[DecorationPlacement] = [],
	p_structure_placements: Array[StructurePlacement] = [],
	p_anchors: Array[LocationAnchor] = []
) -> void:
	super(p_definition_id)
	_display_name = p_display_name
	_grid_size = p_grid_size
	_outgoing_edges = p_outgoing_edges.duplicate()
	_ground_layer = p_ground_layer.duplicate()
	_decoration_placements = p_decoration_placements.duplicate()
	_structure_placements = p_structure_placements.duplicate()
	_anchors = p_anchors.duplicate()


func get_definition_type() -> StringName:
	return &"location"
