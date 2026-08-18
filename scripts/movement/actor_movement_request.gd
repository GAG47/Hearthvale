class_name ActorMovementRequest
extends RefCounted

enum Phase {
	CONTRACTED,
	REQUESTING,
	EXTENDED,
}

var actor: Actor
var target_cell: Vector2i
var location_id: StringName
var phase := Phase.CONTRACTED
var tail_cell: Vector2i
var head_cell: Vector2i
var step_start_position := Vector2.ZERO
var step_target_position := Vector2.ZERO
var started_at := 0
var effective_priority_started_at := 0
var effective_priority_instance_id := &""
var candidates: Array[Vector2i] = []
var coordination_approved := false


func _init(p_actor: Actor, p_target_cell: Vector2i, p_started_at: int) -> void:
	actor = p_actor
	target_cell = p_target_cell
	location_id = p_actor.current_location_id
	tail_cell = p_actor.current_cell
	head_cell = tail_cell
	started_at = p_started_at
	reset_effective_priority()


func reset_effective_priority() -> void:
	effective_priority_started_at = started_at
	effective_priority_instance_id = actor.instance_id if actor != null else &""


func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [tail_cell]
	if phase == Phase.EXTENDED and head_cell != tail_cell:
		cells.append(head_cell)
	return cells
