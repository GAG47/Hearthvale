@abstract
class_name EntityRepresentationFactory
extends RefCounted


@abstract func supports(entity: Entity) -> bool


@abstract func prepare(
	entity: Entity,
	target_location,
	target_local_position: Vector2
) -> Node
