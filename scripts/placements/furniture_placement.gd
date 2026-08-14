@tool
class_name FurniturePlacement
extends EntityPlacement

const PREVIEW_FILL_COLOR := Color(0.2, 0.65, 1.0, 0.18)
const PREVIEW_OUTLINE_COLOR := Color(0.2, 0.75, 1.0, 0.9)

@export var definition: FurnitureDefinition:
	set(value):
		_disconnect_definition()
		definition = value
		_connect_definition()
		_refresh_preview()


func get_preview_texture() -> Texture2D:
	return definition.visual if definition != null else null


func get_preview_cell_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if (
		definition == null
		or definition.occupied_cells.x <= 0
		or definition.occupied_cells.y <= 0
	):
		return rects
	var occupied_size := Vector2(definition.occupied_cells * GridScene.CELL_SIZE)
	var top_left := position - occupied_size * 0.5
	var anchor_cell := Vector2i(
		floori(top_left.x / GridScene.CELL_SIZE),
		floori(top_left.y / GridScene.CELL_SIZE)
	)
	for y in range(definition.occupied_cells.y):
		for x in range(definition.occupied_cells.x):
			var cell := anchor_cell + Vector2i(x, y)
			var world_top_left := Vector2(cell * GridScene.CELL_SIZE)
			rects.append(
				Rect2(world_top_left - position, Vector2.ONE * GridScene.CELL_SIZE)
			)
	return rects


func _draw() -> void:
	for rect in get_preview_cell_rects():
		draw_rect(rect, PREVIEW_FILL_COLOR, true)
		draw_rect(rect, PREVIEW_OUTLINE_COLOR, false, 2.0)
	var texture := get_preview_texture()
	if texture != null:
		draw_texture(texture, -texture.get_size() * 0.5)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if definition == null:
		warnings.append("FurniturePlacement requires a FurnitureDefinition Resource.")
		return warnings
	if definition.visual == null:
		warnings.append("FurniturePlacement requires FurnitureDefinition.visual.")
	if definition.occupied_cells.x <= 0 or definition.occupied_cells.y <= 0:
		warnings.append("FurniturePlacement requires positive occupied_cells.")
	return warnings


func _connect_definition() -> void:
	if definition != null and not definition.changed.is_connected(_on_definition_changed):
		definition.changed.connect(_on_definition_changed)


func _disconnect_definition() -> void:
	if definition != null and definition.changed.is_connected(_on_definition_changed):
		definition.changed.disconnect(_on_definition_changed)


func _on_definition_changed() -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	queue_redraw()
	update_configuration_warnings()
