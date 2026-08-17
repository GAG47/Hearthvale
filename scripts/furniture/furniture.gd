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


func get_definition() -> Definition:
	return definition


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
			instance_id,
			"%s 无法执行该行为。" % definition.display_name
		)
	var result := behavior.apply_action(action)
	if result.success:
		state_changed.emit()
	return result


func get_visual_ref() -> String:
	var openable_state := get_openable_state()
	if openable_state != null and openable_state.is_open:
		var config: Dictionary = definition.behaviors["openable"]
		return config["open_visual_ref"] as String
	return definition.visual_ref


func get_openable_state() -> OpenableState:
	return furniture_state.behavior_states.get(OPENABLE_BEHAVIOR_ID) as OpenableState


func get_occupied_grid_cells() -> Array[Vector2i]:
	var top_left := local_position - Vector2(definition.occupied_cells * GridSpace.CELL_SIZE) * 0.5
	var anchor_cell := GridSpace.local_position_to_cell(top_left)
	var cells: Array[Vector2i] = []
	for y in range(definition.occupied_cells.y):
		for x in range(definition.occupied_cells.x):
			cells.append(anchor_cell + Vector2i(x, y))
	return cells


func blocks_movement() -> bool:
	return definition.blocks_movement


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
							% [instance_id, OPENABLE_BEHAVIOR_ID]
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
