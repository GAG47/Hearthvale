@abstract
class_name Entity
extends RefCounted

var state: EntityState

var instance_id: StringName:
	get:
		return state.instance_id if state != null else &""

var current_location_id: StringName:
	get:
		return state.current_location_id if state != null else &""

var current_cell: Vector2i:
	get:
		return state.local_cell if state != null else Vector2i.ZERO


func _init(p_state: EntityState) -> void:
	state = p_state


func get_definition() -> Resource:
	return null


func get_explicit_use_slots() -> Array[UseSlot]:
	return []


func get_use_slots(action_id: StringName) -> Array[UseSlot]:
	if action_id.is_empty():
		return []
	var explicit_slots: Array[UseSlot] = []
	for slot in get_explicit_use_slots():
		if slot != null and slot.supports_action(action_id):
			explicit_slots.append(slot)
	if not explicit_slots.is_empty():
		return explicit_slots
	return _build_default_use_slots(action_id)


func get_footprint_origin_cell() -> Vector2i:
	return current_cell


func get_footprint_local_cells() -> Array[Vector2i]:
	return [Vector2i.ZERO]


func get_use_slot_world_cell(slot: UseSlot) -> Vector2i:
	return get_footprint_origin_cell() + slot.local_cell if slot != null else Vector2i.ZERO


func get_slot_entrance_world_cell(entrance: SlotEntrance) -> Vector2i:
	return get_footprint_origin_cell() + entrance.local_cell if entrance != null else Vector2i.ZERO


func has_use_slot_at(action_id: StringName, world_cell: Vector2i) -> bool:
	for slot in get_use_slots(action_id):
		if get_use_slot_world_cell(slot) == world_cell:
			return true
	return false


func has_facing_use_slot_at(
	action_id: StringName,
	world_cell: Vector2i,
	facing: ActorState.Facing
) -> bool:
	for slot in get_use_slots(action_id):
		if get_use_slot_world_cell(slot) == world_cell and slot.is_facing_allowed(facing):
			return true
	return false


func get_supported_actions(_actor: Actor) -> Array[StringName]:
	return []


func get_primary_action(actor: Actor) -> StringName:
	var actions := get_supported_actions(actor)
	if actor != null:
		for action_id in actions:
			if has_facing_use_slot_at(action_id, actor.current_cell, actor.facing):
				return action_id
	return actions[0] if not actions.is_empty() else &""


func check_action(action: WorldAction) -> ActionRuleDecision:
	return ActionRuleDecision.reject(
		"目标实体不支持“%s”行为。" % action.action_id,
		&"target_action_unsupported"
	)


func apply_action(action: WorldAction) -> ActionResult:
	return ActionResult.failed(
		action.action_id,
		instance_id,
		"目标实体无法执行该行为。",
		&"target_action_unsupported"
	)


func get_occupied_grid_cells() -> Array[Vector2i]:
	return [current_cell]


func blocks_movement() -> bool:
	return false


func _build_default_use_slots(action_id: StringName) -> Array[UseSlot]:
	var footprint_cells := get_footprint_local_cells()
	if footprint_cells.is_empty():
		return []
	var footprint_lookup: Dictionary[Vector2i, bool] = {}
	for cell in footprint_cells:
		footprint_lookup[cell] = true

	var slots: Array[UseSlot] = []
	var slots_by_cell: Dictionary[Vector2i, UseSlot] = {}
	var directions := [
		[Vector2i.UP, UseSlot.facing_mask(ActorState.Facing.DOWN)],
		[Vector2i.DOWN, UseSlot.facing_mask(ActorState.Facing.UP)],
		[Vector2i.LEFT, UseSlot.facing_mask(ActorState.Facing.RIGHT)],
		[Vector2i.RIGHT, UseSlot.facing_mask(ActorState.Facing.LEFT)],
	]
	for cell in footprint_cells:
		for direction_data in directions:
			var neighbor: Vector2i = cell + direction_data[0]
			if footprint_lookup.has(neighbor):
				continue
			var allowed_facing: int = direction_data[1]
			if slots_by_cell.has(neighbor):
				slots_by_cell[neighbor].allowed_facings |= allowed_facing
				continue
			var external_slot := _create_default_slot(neighbor, action_id, allowed_facing)
			slots_by_cell[neighbor] = external_slot
			slots.append(external_slot)

	if not blocks_movement():
		for cell in footprint_cells:
			if slots_by_cell.has(cell):
				continue
			var foot_slot := _create_default_slot(cell, action_id, UseSlot.ALL_FACINGS)
			slots_by_cell[cell] = foot_slot
			slots.append(foot_slot)
	return slots


static func _create_default_slot(
	local_cell: Vector2i,
	action_id: StringName,
	allowed_facings: int
) -> UseSlot:
	var slot := UseSlot.new()
	slot.local_cell = local_cell
	slot.allowed_facings = allowed_facings
	slot.supported_actions = [action_id]
	return slot
