@abstract
class_name WorldObject
extends Node2D

@export var object_id := &""
@export var display_name := "世界对象"
@export var anchor_cell := Vector2i.ZERO
@export var occupied_cells := Vector2i.ONE
@export var blocks_movement := true

var location: GridScene
var world_identity_registered := false
var world_state: WorldStateRuntime


func _ready() -> void:
	location = _find_location()
	position = _get_local_center()
	_configure_blocking_collision()

	if location == null:
		push_error("WorldObject '%s' must belong to a GridScene Location." % object_id)
	else:
		world_state = get_node_or_null("/root/WorldState") as WorldStateRuntime
		if world_state == null:
			push_error("WorldState Autoload is required before loading a WorldObject.")
		else:
			world_identity_registered = world_state.register_world_object(self)
	if world_identity_registered:
		location.register_world_object(self)


func _exit_tree() -> void:
	if is_instance_valid(location):
		location.unregister_world_object(self)
	if world_identity_registered:
		world_state.unregister_world_object(self)
		world_identity_registered = false


func get_supported_actions(_actor: Character) -> Array[StringName]:
	return []


func get_primary_action(actor: Character) -> StringName:
	var actions := get_supported_actions(actor)
	return actions[0] if not actions.is_empty() else &""


func get_occupied_grid_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(occupied_cells.y):
		for x in range(occupied_cells.x):
			cells.append(anchor_cell + Vector2i(x, y))
	return cells


func check_action(action: WorldAction) -> ActionRuleDecision:
	return ActionRuleDecision.reject("%s 不提供“%s”行为。" % [display_name, action.action_id])


func apply_action(action: WorldAction) -> ActionResult:
	return ActionResult.failed(action.action_id, object_id, "%s 无法执行该行为。" % display_name)


func _find_location() -> GridScene:
	var current := get_parent()
	while current != null:
		if current is GridScene:
			return current as GridScene
		current = current.get_parent()
	return null


func _get_local_center() -> Vector2:
	return Vector2(anchor_cell * GridScene.CELL_SIZE) + Vector2(occupied_cells * GridScene.CELL_SIZE) * 0.5


func _configure_blocking_collision() -> void:
	var blocking_body := get_node_or_null("BlockingBody") as StaticBody2D
	var collision := get_node_or_null("BlockingBody/CollisionShape2D") as CollisionShape2D
	if blocking_body == null or collision == null:
		if blocks_movement:
			push_error("Blocking WorldObject '%s' requires BlockingBody/CollisionShape2D." % object_id)
		return

	blocking_body.collision_layer = 1 if blocks_movement else 0
	blocking_body.collision_mask = 1 if blocks_movement else 0
	collision.disabled = not blocks_movement

	var rectangle := collision.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(occupied_cells * GridScene.CELL_SIZE) - Vector2(4.0, 4.0)
