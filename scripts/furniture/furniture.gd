class_name Furniture
extends Entity

signal state_changed

const BEHAVIOR_ORDER: Array[String] = ["sleepable", "openable", "inspectable"]
const OPENABLE_BEHAVIOR_ID := &"openable"

var definition: FurnitureDefinition
var behaviors: Array[FurnitureBehavior] = []

var furniture_state: FurnitureState:
	get:
		return state as FurnitureState


func _init(p_definition: FurnitureDefinition, p_state: FurnitureState) -> void:
	super(p_state)
	definition = p_definition
	_create_behaviors()


func get_supported_actions(actor: Actor) -> Array[StringName]:
	var actions: Array[StringName] = []
	for behavior in behaviors:
		for action_id in behavior.get_supported_actions(self, actor):
			if not actions.has(action_id):
				actions.append(action_id)
	return actions


func get_primary_action(actor: Actor) -> StringName:
	var actions := get_supported_actions(actor)
	return actions[0] if not actions.is_empty() else &""


func get_explicit_use_slot_definitions() -> Array[UseSlotDefinition]:
	return definition.use_slots.duplicate() if definition != null else []


func check_action(action: WorldAction) -> ActionRuleDecision:
	var behavior := _get_behavior_for_action(action.action_id)
	if behavior == null:
		return ActionRuleDecision.reject(
			"%s 不提供“%s”行为。" % [definition.display_name, action.action_id]
		)
	return behavior.check_action(action)


func apply_action(action: WorldAction) -> ActionResult:
	var behavior := _get_behavior_for_action(action.action_id)
	if behavior == null:
		return ActionResult.failed(
			action.action_id,
			entity_id,
			"%s 无法执行该行为。" % definition.display_name
		)
	var result := behavior.apply_action(action)
	if result.success:
		state_changed.emit()
	return result


func get_visual() -> Texture2D:
	var openable_state := get_openable_state()
	if openable_state != null and openable_state.is_open:
		var config: Dictionary = definition.behaviors["openable"]
		return config["open_visual"] as Texture2D
	return definition.visual


func get_openable_state() -> OpenableState:
	return furniture_state.behavior_states.get(OPENABLE_BEHAVIOR_ID) as OpenableState


func get_occupied_grid_cells() -> Array[Vector2i]:
	return get_occupied_grid_cells_at(local_position)


func get_occupied_grid_cells_at(target_local_position: Vector2) -> Array[Vector2i]:
	var top_left := (
		target_local_position
		- Vector2(definition.occupied_cells * LogicalLocationData.CELL_SIZE) * 0.5
	)
	var anchor_cell := Vector2i(
		floori(top_left.x / LogicalLocationData.CELL_SIZE),
		floori(top_left.y / LogicalLocationData.CELL_SIZE)
	)
	var cells: Array[Vector2i] = []
	for offset in get_footprint_offsets():
		cells.append(anchor_cell + offset)
	return cells


func get_footprint_offsets() -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for y in range(definition.occupied_cells.y):
		for x in range(definition.occupied_cells.x):
			offsets.append(Vector2i(x, y))
	return offsets


func is_blocking_movement() -> bool:
	return definition != null and definition.blocks_movement


func _create_behaviors() -> void:
	for behavior_id in BEHAVIOR_ORDER:
		if not definition.behaviors.has(behavior_id):
			continue
		match behavior_id:
			"sleepable":
				behaviors.append(SleepableBehavior.new())
			"openable":
				if furniture_state.behavior_states.has(OPENABLE_BEHAVIOR_ID):
					if not furniture_state.behavior_states[OPENABLE_BEHAVIOR_ID] is OpenableState:
						push_error(
							"Furniture '%s' behavior state '%s' must be OpenableState."
							% [entity_id, OPENABLE_BEHAVIOR_ID]
						)
						continue
				else:
					furniture_state.behavior_states[OPENABLE_BEHAVIOR_ID] = OpenableState.new()
				behaviors.append(OpenableBehavior.new())
			"inspectable":
				var config: Dictionary = definition.behaviors[behavior_id]
				behaviors.append(InspectableBehavior.new(config["text"] as String))


func _get_behavior_for_action(action_id: StringName) -> FurnitureBehavior:
	for behavior in behaviors:
		if behavior.handles_action(action_id):
			return behavior
	return null
