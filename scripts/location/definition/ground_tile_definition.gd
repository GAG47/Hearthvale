@tool
class_name GroundTileDefinition
extends Resource

@export var key: StringName
@export var walkable := false
@export var movement_cost := 1.0
@export var source_id := -1
@export var atlas_coords := Vector2i(-1, -1)
@export var alternative_tile := 0
