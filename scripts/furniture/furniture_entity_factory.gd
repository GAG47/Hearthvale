class_name FurnitureEntityFactory
extends EntityFactory

const ENTITY_TYPE := &"furniture"


func supports(entity_type: StringName) -> bool:
	return entity_type == ENTITY_TYPE


func create(entity_data: Dictionary) -> Entity:
	var entity_type := read_non_empty_string(entity_data, "entity_type")
	var definition_path := read_non_empty_string(entity_data, "definition_path")
	var location_id_text := read_non_empty_string(entity_data, "location_id")
	var position_value: Variant = read_local_position(entity_data)
	if (
		entity_type != String(ENTITY_TYPE)
		or definition_path.is_empty()
		or location_id_text.is_empty()
		or position_value == null
	):
		return null

	var definition := FurnitureDefinitionLoader.load_from_file(definition_path)
	if definition == null:
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
