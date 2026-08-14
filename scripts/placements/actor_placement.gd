@tool
class_name ActorPlacement
extends EntityPlacement

@export var definition: ActorDefinition:
	set(value):
		_disconnect_definition()
		definition = value
		_connect_definition()
		_refresh_preview()

@export var initial_facing: ActorState.Facing = ActorState.Facing.DOWN:
	set(value):
		initial_facing = value
		_refresh_preview()


func get_preview_texture() -> Texture2D:
	if definition == null:
		return null
	return definition.get_visual(_facing_to_direction(initial_facing))


func _draw() -> void:
	var texture := get_preview_texture()
	if texture == null:
		return
	draw_texture(texture, -texture.get_size() * 0.5)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if definition == null:
		warnings.append("ActorPlacement requires an ActorDefinition Resource.")
		return warnings
	warnings.append_array(definition.get_validation_warnings())
	var preview_texture := get_preview_texture()
	if preview_texture == null:
		warnings.append(
			"ActorPlacement initial_facing requires the matching ActorDefinition visual."
		)
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


static func _facing_to_direction(facing: ActorState.Facing) -> StringName:
	match facing:
		ActorState.Facing.UP:
			return &"up"
		ActorState.Facing.LEFT:
			return &"left"
		ActorState.Facing.RIGHT:
			return &"right"
		_:
			return &"down"
