class_name Chest
extends WorldObject

enum State {
	CLOSED,
	OPEN,
}

const ACTION_OPEN := &"open"
const ACTION_CLOSE := &"close"
const CLOSED_TEXTURE := preload("res://assets/objects/chest_closed.svg")
const OPEN_TEXTURE := preload("res://assets/objects/chest_open.svg")

var state := State.CLOSED

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super()
	_update_visual()


func get_available_actions(_actor: Node2D) -> Array[StringName]:
	var actions: Array[StringName] = []
	actions.append(ACTION_CLOSE if state == State.OPEN else ACTION_OPEN)
	return actions


func check_action(action: WorldAction) -> ActionRuleDecision:
	if action.target != self:
		return ActionRuleDecision.reject("行为目标不是这个储物箱。")

	match action.action_id:
		ACTION_OPEN:
			return ActionRuleDecision.permit() if state == State.CLOSED else ActionRuleDecision.reject("箱子已经打开。")
		ACTION_CLOSE:
			return ActionRuleDecision.permit() if state == State.OPEN else ActionRuleDecision.reject("箱子已经关闭。")
		_:
			return ActionRuleDecision.reject("储物箱不提供“%s”行为。" % action.action_id)


func apply_action(action: WorldAction) -> ActionResult:
	match action.action_id:
		ACTION_OPEN:
			state = State.OPEN
			_update_visual()
			return ActionResult.succeeded(action.action_id, object_id, "箱子打开了。")
		ACTION_CLOSE:
			state = State.CLOSED
			_update_visual()
			return ActionResult.succeeded(action.action_id, object_id, "箱子关闭了。")
		_:
			return ActionResult.failed(action.action_id, object_id, "储物箱无法执行该行为。")


func is_open() -> bool:
	return state == State.OPEN


func _update_visual() -> void:
	if sprite != null:
		sprite.texture = OPEN_TEXTURE if state == State.OPEN else CLOSED_TEXTURE
