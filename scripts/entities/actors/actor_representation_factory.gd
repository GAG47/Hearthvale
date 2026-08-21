class_name ActorRepresentationFactory
extends EntityRepresentationFactory

const REPRESENTATION_SCENE: PackedScene = preload(
	"res://scenes/actors/actor_representation.tscn"
)


func supports(entity: Entity) -> bool:
	return entity is Actor


func prepare(
	entity: Entity,
	target_location,
	target_cell: Vector2i,
	logical_movement: LogicalMovement = null
) -> Node:
	if not entity is Actor or not target_location is LocationScene:
		push_error("ActorRepresentationFactory requires an Actor and target LocationScene.")
		return null

	var scene_instance := REPRESENTATION_SCENE.instantiate()
	var representation := scene_instance as ActorRepresentation
	if representation == null:
		push_error("The shared ActorRepresentation Scene did not instantiate correctly.")
		if is_instance_valid(scene_instance):
			scene_instance.free()
		return null

	var actor := entity as Actor
	var location := target_location as LocationScene
	if not representation.prepare_actor(actor, location, target_cell, logical_movement):
		representation.free()
		return null
	representation.name = "Actor_%s" % String(actor.instance_id).substr(0, 8)
	return representation
