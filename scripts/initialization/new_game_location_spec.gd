@tool
class_name NewGameLocationSpec
extends Resource

@export var instance_id: StringName
@export var definition: LocationDefinition


func validate() -> bool:
	if not UuidValidator.is_valid_v4(instance_id):
		push_error("NewGameLocationSpec instance_id '%s' is not a valid UUID v4." % instance_id)
		return false
	if definition == null:
		push_error("NewGameLocationSpec '%s' requires a LocationDefinition." % instance_id)
		return false
	return definition.validate(true)
