class_name ActorMovementRequest
extends RefCounted

enum Phase {
	CONTRACTED,
	REQUESTING,
	EXTENDED,
}

enum IntentKind {
	TARGET,
	DIRECTION,
}

var actor: Actor
var target_cell: Vector2i
var location_id: StringName
var intent_kind := IntentKind.TARGET
var direction_intent := Vector2i.ZERO
var phase := Phase.CONTRACTED
var tail_cell: Vector2i
var head_cell: Vector2i
var step_elapsed := 0.0
var step_duration := 0.0
var original_priority_started_at := 0
var original_priority_instance_id := &""
var current_priority_started_at := 0
var current_priority_instance_id := &""
var parent_actor_id := &""
var children_actor_ids: Dictionary[StringName, bool] = {}
var candidate_cells: Array[Vector2i] = []
var searched_cells: Dictionary[Vector2i, bool] = {}
var cancel_after_step := false


func _init(
	p_actor: Actor,
	p_target_cell: Vector2i,
	p_started_at: int,
	p_intent_kind: IntentKind = IntentKind.TARGET,
	p_direction_intent: Vector2i = Vector2i.ZERO
) -> void:
	actor = p_actor
	target_cell = p_target_cell
	location_id = p_actor.current_location_id
	intent_kind = p_intent_kind
	direction_intent = p_direction_intent
	tail_cell = p_actor.current_cell
	head_cell = tail_cell
	original_priority_started_at = p_started_at
	original_priority_instance_id = p_actor.instance_id
	parent_actor_id = p_actor.instance_id
	reset_current_priority()


func reset_current_priority() -> void:
	current_priority_started_at = original_priority_started_at
	current_priority_instance_id = original_priority_instance_id


func inherit_priority_from(parent_request: ActorMovementRequest) -> void:
	current_priority_started_at = parent_request.current_priority_started_at
	current_priority_instance_id = parent_request.current_priority_instance_id


func is_root() -> bool:
	return actor != null and parent_actor_id == actor.instance_id


func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [tail_cell]
	if phase == Phase.EXTENDED and head_cell != tail_cell:
		cells.append(head_cell)
	return cells


func get_step_progress() -> float:
	if phase != Phase.EXTENDED:
		return 0.0
	if step_duration <= 0.0:
		return 1.0
	return clampf(step_elapsed / step_duration, 0.0, 1.0)
