class_name StructureTileDefinition
extends Definition

var _key: StringName
var _blocks_movement: bool
var _source_id: int
var _atlas_coords: Vector2i
var _alternative_tile: int

var key: StringName:
	get:
		return _key
var blocks_movement: bool:
	get:
		return _blocks_movement
var source_id: int:
	get:
		return _source_id
var atlas_coords: Vector2i:
	get:
		return _atlas_coords
var alternative_tile: int:
	get:
		return _alternative_tile


func _init(
	p_definition_id: StringName,
	p_key: StringName,
	p_blocks_movement: bool,
	p_source_id: int,
	p_atlas_coords: Vector2i,
	p_alternative_tile: int
) -> void:
	super(p_definition_id)
	_key = p_key
	_blocks_movement = p_blocks_movement
	_source_id = p_source_id
	_atlas_coords = p_atlas_coords
	_alternative_tile = p_alternative_tile


func get_definition_type() -> StringName:
	return &"structure_tile"
