class_name FurnitureRepresentationFactory
extends EntityRepresentationFactory

const REPRESENTATION_SCENE: PackedScene = preload(
	"res://scenes/furniture/furniture_representation.tscn"
)


func supports(entity: Entity) -> bool:
	return entity is Furniture


func prepare(
	entity: Entity,
	target_location,
	target_cell: Vector2i
) -> Node:
	if not entity is Furniture or not target_location is GridScene:
		push_error("FurnitureRepresentationFactory requires Furniture and target GridScene.")
		return null

	var scene_instance := REPRESENTATION_SCENE.instantiate()
	var representation := scene_instance as FurnitureRepresentation
	if representation == null:
		push_error("The shared FurnitureRepresentation Scene did not instantiate correctly.")
		if is_instance_valid(scene_instance):
			scene_instance.free()
		return null

	var furniture := entity as Furniture
	var location := target_location as GridScene
	if not representation.prepare_furniture(
		furniture,
		location,
		target_cell
	):
		representation.free()
		return null
	representation.name = "Furniture_%s" % String(furniture.instance_id).substr(0, 8)
	return representation
