@tool
class_name ActorPlacement
extends EntityPlacement

@export_file("*.json") var definition_path := ""
@export var initial_facing: ActorState.Facing = ActorState.Facing.DOWN
