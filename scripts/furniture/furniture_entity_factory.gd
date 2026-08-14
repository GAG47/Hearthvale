class_name FurnitureEntityFactory
extends EntityFactory

const ENTITY_TYPE := &"furniture"


func supports(entity_type: StringName) -> bool:
	return entity_type == ENTITY_TYPE


func create(entity_data: Dictionary) -> Entity:
	var entity_type := read_non_empty_string(entity_data, "entity_type")
	var definition_uid := read_non_empty_string(entity_data, "definition_uid")
	var location_id_text := read_non_empty_string(entity_data, "location_id")
	var position_value: Variant = read_local_position(entity_data)
	if (
		entity_type != String(ENTITY_TYPE)
		or definition_uid.is_empty()
		or location_id_text.is_empty()
		or position_value == null
	):
		return null

	var definition_resource := ResourceLoader.load(definition_uid)
	if not definition_resource is FurnitureDefinition:
		push_error(
			"FurnitureEntityFactory definition_uid '%s' did not load a FurnitureDefinition."
			% definition_uid
		)
		return null
	var definition := definition_resource as FurnitureDefinition
	var definition_warnings := definition.get_validation_warnings()
	if not definition_warnings.is_empty():
		push_error(
			"FurnitureEntityFactory loaded an invalid FurnitureDefinition: %s"
			% definition_warnings[0]
		)
		return null
	var entity_id := UuidGenerator.generate_v4()
	if not UuidValidator.is_valid_v4(entity_id):
		push_error("FurnitureEntityFactory could not generate a UUID v4.")
		return null
	var state := FurnitureState.new(
		entity_id,
		StringName(location_id_text),
		position_value as Vector2
	)
	return Furniture.new(definition, state)
