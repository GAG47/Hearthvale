class_name Chest
extends WorldObject

const ACTION_OPEN := &"open"
const ACTION_CLOSE := &"close"
const CLOSED_TEXTURE := preload("res://assets/objects/chest_closed.svg")
const OPEN_TEXTURE := preload("res://assets/objects/chest_open.svg")

@export var initial_status: ChestState.Status = ChestState.Status.CLOSED

@onready var sprite: Sprite2D = $Sprite2D

var chest_state: ChestState


func _ready() -> void:
	super()
	if world_identity_registered:
		_bind_world_state()
	_update_visual()


func _bind_world_state() -> void:
	var existing_state := world_state.get_object_state(object_id)
	if existing_state != null:
		chest_state = existing_state as ChestState
		if chest_state == null:
			push_error("World state for Chest '%s' is not a ChestState." % object_id)
		return

	var initial_chest_state := ChestState.new(initial_status)
	if world_state.register_object_state(object_id, initial_chest_state):
		chest_state = initial_chest_state


func get_supported_actions(_actor: Character) -> Array[StringName]:
	var actions: Array[StringName] = []
	if chest_state != null:
		actions.append(ACTION_CLOSE if chest_state.status == ChestState.Status.OPEN else ACTION_OPEN)
	return actions


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self:
		return ActionRuleDecision.reject("行为目标不是这个储物箱。")
	if chest_state == null:
		return ActionRuleDecision.reject("储物箱没有有效的世界状态。", &"world_state_unavailable")

	match action.action_id:
		ACTION_OPEN:
			return ActionRuleDecision.permit() if chest_state.status == ChestState.Status.CLOSED else ActionRuleDecision.reject("箱子已经打开。")
		ACTION_CLOSE:
			return ActionRuleDecision.permit() if chest_state.status == ChestState.Status.OPEN else ActionRuleDecision.reject("箱子已经关闭。")
		_:
			return ActionRuleDecision.reject("储物箱不提供“%s”行为。" % action.action_id)


func apply_action(action: WorldAction) -> ActionResult:
	match action.action_id:
		ACTION_OPEN:
			chest_state.status = ChestState.Status.OPEN
			_update_visual()
			return ActionResult.succeeded(action.action_id, object_id, "箱子打开了。")
		ACTION_CLOSE:
			chest_state.status = ChestState.Status.CLOSED
			_update_visual()
			return ActionResult.succeeded(action.action_id, object_id, "箱子关闭了。")
		_:
			return ActionResult.failed(action.action_id, object_id, "储物箱无法执行该行为。")


func is_open() -> bool:
	return chest_state != null and chest_state.status == ChestState.Status.OPEN


func _update_visual() -> void:
	if sprite != null:
		sprite.texture = OPEN_TEXTURE if is_open() else CLOSED_TEXTURE
