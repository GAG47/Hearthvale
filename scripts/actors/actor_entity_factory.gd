class_name ActorEntityFactory
extends EntityFactory

const ENTITY_TYPE := &"actor"


func supports(entity_type: StringName) -> bool:
	return entity_type == ENTITY_TYPE


func create(entity_data: Dictionary) -> Entity:
	var entity_type := read_non_empty_string(entity_data, "entity_type")
	var definition_uid := read_non_empty_string(entity_data, "definition_uid")
	var location_id_text := read_non_empty_string(entity_data, "location_id")
	var position_value: Variant = read_local_position(entity_data)
	var facing_text := read_non_empty_string(entity_data, "initial_facing")
	if (
		entity_type != String(ENTITY_TYPE)
		or definition_uid.is_empty()
		or location_id_text.is_empty()
		or position_value == null
		or facing_text.is_empty()
	):
		return null
	var facing_value: Variant = _string_to_facing(facing_text)
	if facing_value == null:
		push_error("Actor entity creation has invalid initial_facing '%s'." % facing_text)
		return null

	var definition_resource := ResourceLoader.load(definition_uid)
	if not definition_resource is ActorDefinition:
		push_error(
			"ActorEntityFactory definition_uid '%s' did not load an ActorDefinition."
			% definition_uid
		)
		return null
	var definition := definition_resource as ActorDefinition
	var definition_warnings := definition.get_validation_warnings()
	if not definition_warnings.is_empty():
		push_error("ActorEntityFactory loaded an invalid ActorDefinition: %s" % definition_warnings[0])
		return null
	var entity_id := UuidGenerator.generate_v4()
	if not UuidValidator.is_valid_v4(entity_id):
		push_error("ActorEntityFactory could not generate a UUID v4.")
		return null
	var state := ActorState.new(
		entity_id,
		StringName(location_id_text),
		position_value as Vector2,
		facing_value as ActorState.Facing
	)
	return Actor.new(definition, state)


static func _string_to_facing(value: String) -> Variant:
	match value:
		"up":
			return ActorState.Facing.UP
		"down":
			return ActorState.Facing.DOWN
		"left":
			return ActorState.Facing.LEFT
		"right":
			return ActorState.Facing.RIGHT
		_:
			return null
