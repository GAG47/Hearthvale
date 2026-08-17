@tool
class_name FurnitureDefinition
extends Resource

@export var display_name := ""
@export var visual: Texture2D
@export var behaviors: Array[FurnitureBehavior] = []
@export var occupied_cells := Vector2i.ONE
@export var blocks_movement := true
