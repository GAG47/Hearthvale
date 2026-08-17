@tool
class_name LocationDefinition
extends Resource

@export var display_name := ""
@export var grid_size := Vector2i.ZERO
@export var outgoing_edges: Array[LocationEdgeDefinition] = []
@export var ground_layer: Dictionary[Vector2i, GroundTileDefinition] = {}
@export var decoration_layer: Dictionary[Vector2i, DecorationTileDefinition] = {}
@export var structure_layer: Dictionary[Vector2i, StructureTileDefinition] = {}
@export var entries: Array[LocationEntry] = []
@export var exits: Array[LocationExit] = []
