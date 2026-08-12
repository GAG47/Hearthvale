@abstract
class_name FurnitureBehavior
extends RefCounted


@abstract
func handles_action(action_id: StringName) -> bool


@abstract
func get_supported_actions(furniture: Furniture, actor: Actor) -> Array[StringName]


@abstract
func check_action(action: WorldAction) -> ActionRuleDecision


@abstract
func apply_action(action: WorldAction) -> ActionResult
